"""The machine configurations Dunjunz Revised is tested on, as beebium presets.

Each configuration is a filing system (or a combination) on a stock Model B,
built as a preset on the fly from the ROMs beebium bundles. The first slot
listed is the highest priority, so it is the filing system selected at
power-on.

    uv run dr-machines            # report PAGE under each configuration
"""

from __future__ import annotations

import contextlib
import json
import tempfile
import zipfile
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Machine:
    key: str
    description: str
    fdc: str | None                       # "acorn-8271", "acorn-1770" or None
    roms: tuple[tuple[int, str], ...]     # (slot, bundled ROM image)
    econet: bool = False
    extensions: tuple[str, ...] = field(default=())

    def preset(self) -> dict:
        preset = {
            "model": "model-b",
            "name": self.description,
            "release_date": "1982",
            "description": self.description,
            "sideways_bank": {
                "slots": [{"slot": slot, "type": "rom", "image_uri": rom} for slot, rom in self.roms]
            },
        }
        if self.fdc is not None:
            preset["storage"] = {"fdc_socket": {"id": self.fdc}}
        if self.econet:
            preset["econet"] = {"station": "auto", "transport": {"name": "aun", "parameters": {"port": "0"}}}
        if self.extensions:
            preset["extensions"] = [{"name": name} for name in self.extensions]
        return preset


MACHINES = {
    m.key: m
    for m in (
        Machine("dfs090", "Model B, 8271, DFS 0.90", "acorn-8271", ((14, "acorn-dfs_0_90.rom"),)),
        Machine("dfs098", "Model B, 8271, DFS 0.98", "acorn-8271", ((14, "acorn-dfs_0_98.rom"),)),
        Machine("dnfs120", "Model B, 8271, DNFS 1.20", "acorn-8271", ((14, "acorn-dnfs_1_20.rom"),)),
        Machine("dnfs302", "Model B, 8271, DNFS 3.02", "acorn-8271", ((14, "acorn-dnfs_3_02.rom"),)),
        Machine("dnfs120_econet", "Model B, 8271, DNFS 1.20, Econet", "acorn-8271",
                ((14, "acorn-dnfs_1_20.rom"),), econet=True),
        Machine("dfs226", "Model B, 1770, DFS 2.26", "acorn-1770", ((14, "acorn-dfs_2_26.rom"),)),
        Machine("nfs365", "Model B, NFS 3.65 only", None, ((14, "acorn-nfs_3_65.rom"),), econet=True),
        Machine("anfs418", "Model B, ANFS 4.18 only", None, ((14, "acorn-anfs_4_18.rom"),), econet=True),
        Machine(
            "dfs226_anfs418", "Model B, 1770, ANFS 4.18 + DFS 2.26", "acorn-1770",
            ((14, "acorn-anfs_4_18.rom"), (13, "acorn-dfs_2_26.rom")), econet=True,
        ),
        Machine(
            "dfs226_nfs365", "Model B, 1770, NFS 3.65 + DFS 2.26", "acorn-1770",
            ((14, "acorn-nfs_3_65.rom"), (13, "acorn-dfs_2_26.rom")), econet=True,
        ),
        Machine(
            "dfs226_adfs130", "Model B, 1770, DFS 2.26 + ADFS 1.30", "acorn-1770",
            ((14, "acorn-dfs_2_26.rom"), (13, "acorn-adfs_1_30.rom")),
        ),
        Machine(
            "dfs226_copro", "Model B, 1770, DFS 2.26, 65C02 second processor", "acorn-1770",
            ((14, "acorn-dfs_2_26.rom"),), extensions=("acorn-65c02-coprocessor",),
        ),
    )
}


@contextlib.contextmanager
def preset_filepath(machine: Machine) -> Iterator[Path]:
    """A temporary preset file for a machine."""
    with tempfile.TemporaryDirectory() as tmp_dirpath:
        filepath = Path(tmp_dirpath) / f"{machine.key}.beebium-preset"
        with zipfile.ZipFile(filepath, "w") as z:
            z.writestr("preset.json", json.dumps(machine.preset()))
        yield filepath


@contextlib.contextmanager
def launched(machine: Machine, speed_multiplier: float = 0.0):
    """A running beebium for a machine, at unlimited speed by default."""
    from beebium.client import Beebium

    with preset_filepath(machine) as filepath, Beebium.launch(variant="model-b", preset=filepath) as bbc:
        bbc.system.set_speed_multiplier(speed_multiplier)
        yield bbc


def report_page() -> None:
    """Boot each machine to BASIC and report PAGE (the MOS's OSHWM)."""
    for machine in MACHINES.values():
        try:
            with launched(machine) as bbc:
                bbc.run_for_emulated_seconds(3)
                page = bbc.memory.address.peek[0x18] << 8
                oshwm = bbc.memory.address.peek[0x0244] << 8
                text = bbc.video.screen_text().text.strip().splitlines()
                banner = " / ".join(line.strip() for line in text[:4] if line.strip())
                print(f"{machine.key:16} PAGE &{page:04X}  OSHWM &{oshwm:04X}  {banner}")
        except Exception as e:  # report and carry on with the others
            print(f"{machine.key:16} failed: {e}")


def main() -> None:
    report_page()


if __name__ == "__main__":
    main()
