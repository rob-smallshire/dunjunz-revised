"""Test whether a filing system survives the game borrowing its static workspace.

    uv run python -m dunjunz_revised.workspace_probe MACHINE_KEY ...

For each machine (see machines.py), boot BASIC with build/dunjunz-original.ssd
in drive 0, make the disc filing system own the static workspace (*DISC,
*CAT), then optionally claim it with service call &0A (OSBYTE &8F), overwrite
&0E00 up to the lowest private workspace page, optionally reselect the
current filing system, by service call &12 with the number OSARGS 0,0
returns ("svc12") or by *DISC ("disc"), and *LOAD a level, comparing what
arrives with the original file. Findings are recorded in docs/memory.md.
"""

from __future__ import annotations

import sys
from pathlib import Path

from dunjunz_revised.build import ORIGINAL_DISC_FILEPATH, REFERENCE_DIRPATH
from dunjunz_revised.machines import MACHINES, launched

TRIALS = (  # (claim with &0A, reselect)
    (False, "svc12"),
    (True, "none"),
    (True, "svc12"),
    (True, "disc"),
)


def trial(key: str, claim: bool, reselect: str) -> str:
    machine = MACHINES[key]
    reference = (REFERENCE_DIRPATH / "Level7").read_bytes()
    with launched(machine) as bbc:
        bbc.run_for_emulated_seconds(3)
        bbc.disc.drive0.insert(ORIGINAL_DISC_FILEPATH, write_protect=True)
        peek = bbc.memory.address.peek
        private_pages = [peek[0x0DF0 + slot] for slot, _ in machine.roms]
        top = min([p for p in private_pages if 0x0E <= p < 0x80] + [peek[0x18]]) - 1

        def type_(text: str, seconds: float = 2.0) -> None:
            bbc.keyboard.type(text)
            bbc.run_for_emulated_seconds(seconds)

        type_("*DISC\r", 1)
        type_("*CAT\r", 3)
        if claim:
            type_("A%=&8F:X%=&0A:Y%=&FF:CALL&FFF4\r", 1)
        type_(f"FORI%=&E00TO&{top:02X}FF:?I%=&AA:NEXT\r", 6)
        if reselect == "svc12":
            type_("A%=0:Y%=0:F%=(USR&FFDA)AND&FF:A%=&8F:X%=&12:Y%=F%:CALL&FFF4\r", 2)
        elif reselect == "disc":
            type_("*DISC\r", 1)
        type_("*LOAD Level7 3000\r", 10)
        ok = bytes(peek[0x3000:0x3000 + len(reference)]) == reference
        last = bbc.video.screen_text().text.strip().splitlines()[-1].strip()
        return (f"{key:16} &0E00-&{top:02X}FF claim={'&0A' if claim else 'no '} "
                f"reselect={reselect:5} loaded={'yes' if ok else 'NO '} last line {last!r}")


def main() -> None:
    for key in sys.argv[1:] or MACHINES:
        for claim, reselect in TRIALS:
            print(trial(key, claim, reselect), flush=True)


if __name__ == "__main__":
    main()
