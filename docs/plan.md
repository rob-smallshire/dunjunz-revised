# Plan

Dunjunz Revised keeps the 1987 disc release's game for the Model B, with
its levels, keys and pause, and fixes it, makes it independent of the
filing system, and keeps it resident. The goals:

- runs on a stock Model B and every machine above it (B+, Master), with
  progressive enhancement for more capable machines to come later;
- loads only through the filing system: DFS 0.90, 1.2x and 2.2x,
  NFS and ANFS over Econet, MMFS and MMFS2; works with a second processor
  attached;
- fits on one volume, an 80-track single-sided DFS disc (200 KB);
- behaves as the original does, without its bugs (see `bugs.md`);
- joysticks through OSBYTE &80 (ADVAL), including four on the SPItFIRE
  interface (channels 1-4 and 16-20, buttons on 0 and 16);
- "Dunjunz Revised 2026.1" on the disc title, `!BOOT` and the title screen.

## Milestones

1. **Baseline** (done). The acornaeology reassembly of the Model B disc
   side in `asm/original/`, verified byte-for-byte against the 1987 files.
   `build/dunjunz-original.ssd` boots it (DFS 0.90 only).
2. **Modular source, still identical.** Split `game.asm` into modules
   under `asm/`. Each module carries its annotations from the disassembly.
   The build still verifies the output against the original. This is
   where the revised source begins.
3. **Portable.** Replace the MOS 1.20 dependencies: our own row table,
   chain WRCHV, VDU 23 for character 128, no &D9CD. Test on DFS 0.90 for
   now.
4. **Resident, with levels from the filing system.** Rearrange memory as
   in `memory.md`. Leave page &0D alone. Store the levels unencrypted.
   Load the victory sequence when it's needed. Load levels through
   OSFILE with the borrow-and-reselect protocol. Measure the space as we
   go (`unused_space` equivalents for our own listing). Run the
   test matrix in `machines.py`.
5. **Fixes.** One at a time from `bugs.md`, each with a test against the
   baseline.
6. **Joysticks.** An ADVAL driver, chosen per hero on the hero menu, with
   SPItFIRE detected for heroes 3 and 4.
7. **Release.** Title screen and boot banner with the version, the disc
   title, and a CI and release workflow like Don't Dither!'s.

## Testing

- `tests/` runs the baseline and the revised game in beebium across the
  configurations in `tools/dunjunz_revised/machines.py`.
- Each bug fix is tested on a state set up by poking memory, as the
  acornaeology probes do, with expected values from the baseline.
- py65 for pure routines (the screen address, the level unpacker),
  checked against the baseline's code on the same inputs.
- NFS: beebium's AUN Econet and its L3 file server preset.
