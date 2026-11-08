# Plan

Dunjunz Revised keeps the 1987 disc release's game for the Model B, with
its levels, keys and pause, and fixes it, makes it independent of the
filing system, and keeps it resident. The goals:

- runs on a stock Model B and every machine above it (B+, Master), with
  progressive enhancement for more capable machines to come later;
- loads only through the filing system: DFS 0.90, 1.2x and 2.2x,
  NFS and ANFS over Econet, and MMFS2 (not the original MMFS); works with a second processor
  attached. The layout assumes PAGE is at most &1C00;
- fits on one volume, an 80-track single-sided DFS disc (200 KB);
- behaves as the original does, without its bugs (see `bugs.md`);
- later: redefinable keys and a choice of joystick drivers (see milestone 6);
- "Dunjunz Revised 2026.1" on `!BOOT`'s banner and the title screen. The
  disc title, limited to 12 characters by DFS, is "DUNJUNZ 26.1": "DUNJUNZ"
  and the version with the year shortened (`build.disc_title`).

## Milestones

1. **Baseline** (done). The acornaeology reassembly of the Model B disc
   side in `asm/original/`, verified byte-for-byte against the 1987 files.
   `build/dunjunz-original.ssd` boots it (DFS 0.90 only).
2. **Modular source, still identical** (done). `asm/dunjunz.asm` and its
   modules, with the disassembly's annotations and without its stale
   cross-reference comments. The build verifies the output against the
   original.
3. **Portable** (done). Our own screen row table, WRCHV chained through
   `saved_wrchv`, VDU 23 for character 128, and no jumps into MOS 1.20.
4. **Resident, with levels from the filing system** (done). Memory as in
   `memory.md`: pages &0D and &0E and &1700-&1BFF left to the filing
   system, &0F00-&16FF borrowed with service call &0A. Levels unencrypted,
   loaded with OSFILE, with Setup (the level set-up code) beside them.
   Tested under nine disc and network filing system configurations, and
   over Econet from a Level 3 File Server (`tests/test_filing_systems.py`,
   `tests/test_network.py`). The victory sequence stays resident: it fits,
   and loading it mid-game would need screen memory that is on show.
5. **Fixes.** One at a time from `bugs.md`, each with a test against the
   baseline.
6. **Controls** (deferred; decided 2026-11-08). No joystick support for
   now: keyboard only, so the 1987 Model B disc's Barbarian-on-joystick
   mode (Coder's BYTEV handler) is gone. Later, a new phase in loading,
   before the game, will redefine the keys and pick one of several
   joystick drivers, which is loaded with the game:
   - standard Acorn: two sticks, one button each;
   - Voltmace Delta 14/B: extra buttons (magic could have its own);
   - SPItFIRE: four sticks of one button each (channels 1-4 and 16-20,
     buttons on 0 and 16, through a ROM on BYTEV; detectable).
   One-button sticks leave the Ranger's and Magic-User's magic to be
   settled: on the keyboard, or a gesture on the button.
7. **Release.** The version is on the title screen and in the disc title
   (done). Still to do: a CI and release workflow like Don't Dither!'s.

## Program structure

Decided 2026-11-07:

- **Front end**: the title screen and the hero menu. The menu moves out of
  the game to save space.
- **Resident game**: everything needed in play, loaded once, with levels
  loaded from the filing system.
- **Victory overlay**: loaded only when a hero reaches the Chalice.
- After game over, the front end and the game are loaded again, as the
  original's reset does. That is acceptable over Econet too.

## Testing

- `tests/` runs the baseline and the revised game in beebium across the
  configurations in `tools/dunjunz_revised/machines.py`.
- Each bug fix is tested on a state set up by poking memory, as the
  acornaeology probes do, with expected values from the baseline.
- py65 for pure routines (the screen address, the level unpacker),
  checked against the baseline's code on the same inputs.
- NFS: beebium's AUN Econet and its L3 file server preset.
