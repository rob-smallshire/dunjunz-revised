"""The revised game loads over Econet from a Level 3 File Server.

A file server is built from beebium's own model-b-l3fs-aun preset, its hard
disc given a $.Dunjunz directory holding the revised disc's files (copied
with oaknut-disc, readable by everyone). The server runs in one beebium,
reaching "Ready", and a client station on AUN logs on as SYST, selects the
directory and runs the title. The game starts level 1 and moves on to level
2, which it loads over the network with the game's workspace handed back to
the network filing system and claimed again.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import pytest

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.lockstep import SPACE, hold_key
from dunjunz_revised.machines import MACHINES, launched

SERVER_PRESET = "model-b-l3fs-aun"
SERVER_READY_SECONDS = 60
GAME_FILENAMES = ["!BOOT", "Dunjunz", "Screen", "GAME", "Setup"] + [f"Level{n}" for n in range(1, 26)]
MAP_BYTES = 0xC9
LEVEL_WALLS_OFFSET = 0xE0

# Each client, and the commands that select the network filing system and log on.
CLIENTS = {
    "anfs418": ["*I AM SYST"],
    "nfs365": ["*I AM SYST"],
    "dnfs120_econet": ["*NET", "*I AM SYST"],
}


def oaknut_disc(*args: str) -> None:
    executable = Path(sys.executable).with_name("oaknut-disc")
    subprocess.run([str(executable), *args], check=True, capture_output=True, text=True)


@pytest.fixture(scope="session")
def file_server_preset_filepath(disc_filepaths, tmp_path_factory) -> Path:
    from beebium.client.installation import ServerInstallation

    source = ServerInstallation.default().preset_dirpath / f"{SERVER_PRESET}.beebium-preset"
    work_dirpath = tmp_path_factory.mktemp("l3fs")
    with zipfile.ZipFile(source) as z:
        z.extractall(work_dirpath)
    preset = json.loads((work_dirpath / "preset.json").read_text())
    image = next(e["config"]["image"] for e in preset["extensions"] if e["name"] == "scsi-hard-disc")
    image_filepath = work_dirpath / image
    for name in GAME_FILENAMES:
        oaknut_disc("cp", f"{REVISED_DISC_FILEPATH}:$.{name}", f"{image_filepath}:afs:$.Dunjunz.{name}",
                    "--access", "WR/R")
    preset_filepath = work_dirpath / "server.beebium-preset"
    with zipfile.ZipFile(preset_filepath, "w") as z:
        for member in work_dirpath.iterdir():
            if member != preset_filepath:
                z.write(member, member.name)
    return preset_filepath


def run_to(bbc, address, seconds, press_space=False):
    bp = bbc.debugger.add_breakpoint(address)
    try:
        for _ in range(int(seconds / 0.5)):
            bbc.run_for_emulated_seconds(0.5)
            if bbc.cpu.pc == address:
                return True
            bbc.debugger.run()
            if press_space:
                hold_key(bbc, *SPACE)
        return False
    finally:
        bp.remove()


@pytest.mark.parametrize("client_key", list(CLIENTS))
def test_levels_load_over_econet(file_server_preset_filepath, client_key):
    from beebium.client import Beebium

    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with Beebium.launch(variant="model-b", preset=file_server_preset_filepath) as server:
        server.system.set_speed_multiplier(0.0)
        server.debugger.ensure_running()
        deadline = time.time() + SERVER_READY_SECONDS
        while "Ready" not in server.video.screen_text().text:
            assert time.time() < deadline, "the file server did not start"
            time.sleep(1)
        with launched(MACHINES[client_key]) as bbc:
            bbc.run_for_emulated_seconds(3)
            for command in CLIENTS[client_key] + ["*DIR Dunjunz", "*RUN DUNJUNZ"]:
                bbc.keyboard.type(command + "\r")
                bbc.run_for_emulated_seconds(4)
            assert run_to(bbc, labels["update_game"], 120, press_space=True), \
                f"level 1 not reached; PC &{bbc.cpu.pc:04X}"
            bbc.cpu.pc = labels["next_level"]
            assert run_to(bbc, labels["update_game"], 60), f"level 2 not reached; PC &{bbc.cpu.pc:04X}"
            assert bbc.memory.address.peek[0x08BC] == 2
            walls = bytes(bbc.memory.address.peek[labels["room_walls"]:labels["room_walls"] + MAP_BYTES])
            level2 = (REVISED_BUILD_DIRPATH / "Level2").read_bytes()
            assert walls[8:] == level2[LEVEL_WALLS_OFFSET + 8:LEVEL_WALLS_OFFSET + MAP_BYTES]
