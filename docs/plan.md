# Plan

Dunjunz Revised keeps the 1987 disc release's game for the Model B, with
its levels, keys and pause, and fixes it, makes it independent of the
filing system, and keeps it resident. The goals:

- runs on a stock Model B and every machine above it (B+, Master), with
  progressive enhancement for more capable machines to come later;
- loads only through the filing system: DFS 0.90, 1.2x and 2.2x,
  NFS and ANFS over Econet, and in time MMFS2 once it can be tested
  (its reported PAGE fits; not the original MMFS); works with a second processor
  attached. The layout assumes PAGE is at most &1C00;
- fits on one volume, an 80-track single-sided DFS disc (200 KB);
- behaves as the original does, without its bugs (see `bugs.md`);
- joysticks: SPItFIRE's four, or two on the analogue port (see milestone 6);
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
6. **Controls** (in progress on the `spitfire` branch; decided 2026-11-11).
   Joysticks join the keyboard; every key keeps working for every hero.
   - **SPItFIRE** (`~/Code/spitfire/docs/joystick-programming.md`): up to
     four sticks through its switch bytes (`ADVAL(12)` and `ADVAL(28)`),
     detected only through OSWORD &3F (reason 0 answers `&53` with no
     status flags; reasons 1 and 2 give the sticks of kind 1 whose switch
     byte carries directions). Today its ROM runs only on the Master Compact
     (MOS 5); the detection works on any model and finds nothing elsewhere.
   - **Without SPItFIRE**: two sticks through the BBC's analogue port
     (`ADVAL(1)`-`(4)`, thresholded at a quarter of full scale, and the fire
     bits of `ADVAL(0)`), which also gives a Master Compact's own digital
     port as joystick 1 (MOS 5 reports its directions in `ADVAL(0)`).
   - **Joining**: every hero starts off (the 1987 release started all four
     on), so one player can pick a hero alone. On the hero menu, keys 1-4
     toggle a hero between NO and the keyboard. Pressing fire on joystick j
     gives it the first hero not on a stick, and each further press moves it
     on to the next, switching off the one it leaves, then off. A hero who
     plays has their line in yellow; SPACE TO PLAY is yellow, or black while
     nobody plays; the sound line highlights ON or OFF. A stick that never presses fire is never used, so an empty port
     or a missing ADC does no harm.
   - **Magic** (Ranger and Magic-User): the stick's fire and a direction
     held together for about half a second (8 frames) casts, as holding the
     magic key does; CTRL and RETURN still cast for everyone. On the
     keyboard a held direction beats fire, so the combination meant nothing
     before.
   - **Ending a game**: ESCAPE held for about half a second (9 frames)
     goes back to the title, as game over does, and any key there to the
     hero menu (decided 2026-11-11). A shorter press does nothing.
   - **Space**: the menu copies the chosen driver into zero page &00-&5F
     (language workspace, unused while the game runs), or just an RTS when
     nobody joined with a stick, so keyboard play is unchanged.
   - Beebium emulates neither SPItFIRE nor the ADC, so the tests run a fake
     SPItFIRE in sideways RAM that answers OSWORD &3F and OSBYTE &80.

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
