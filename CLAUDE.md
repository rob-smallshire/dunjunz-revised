# CLAUDE.md

Dunjunz Revised: Julian Avis's Dunjunz (Bug-Byte, 1986/87) for the BBC
Micro, fixed, resident and filing-system agnostic. 6502 in beebasm, built
by Python tools, tested in beebium. Goals and milestones: `docs/plan.md`.
Memory and filing-system design, with measurements: `docs/memory.md`. Bug
triage: `docs/bugs.md`. Record decisions in these as they are made.
Ideas not yet agreed: `docs/enhancements.md`. How the game behaves in
play, level by level: `docs/behaviours.md`.

## Commands

```bash
uv run dr-build                                   # assemble, verify the baseline, write build/dunjunz-revised-v<version>.ssd and .adl
uv run pytest                                     # tests (beebium)
uv run dr-machines                                # PAGE per machine configuration
uv run dr-sizes                                   # address range and size of each game module
uv run dr-sprites [--original]                    # every sprite as an HTML table: build/sprites-*.html
uv run dr-frame-time [--frames N] [--seed S]      # cycles per frame of scripted play, 1987 and revised
uv run dr-readme                                  # render README.md from README.md.j2 (dr-build does too)
uv run dr-banner                                  # remake the key page's banner (asm/defs/key_page_banner.asm) with sextants
uv run python -m dunjunz_revised.coverage 1500 1 2 3   # instructions never run in scripted play
uv run python -m dunjunz_revised.workspace_probe KEY ...   # static workspace borrowing test
uvx bump-my-version bump minor                    # release: 2026.1 -> 2026.2, commit + tag (user pushes)
```

## Source layout

- `asm/dunjunz.asm` is the game's top level. It sets out the memory regions
  (see `docs/memory.md`) and INCLUDEs the modules into them, with ASSERTs
  that each fits; paths are from the project root, where beebasm runs, and
  SAVEs go into a scratch disc image that the build reads back. It saves
  `GAME` (loaded at &1C00; its startup, game_entry and the hero menu run once
  from screen memory and copy the regions below &1C00 into place) and
  `Setup` (loaded with each level and run in screen memory). The end of the
  game (`asm/ending/`: game over and victory) is stored after Setup in its
  file and loaded over the code for play only once play is over
  (`load_ending`; see `docs/memory.md`).
- Module groups: `defs/` (constants, addresses, the workspace and level file
  layouts as label blocks), `low/` and `core/` (most of it, whichever region
  it now lives in), `extra/` (&1C00 up), `upper/` (&6E80 up), `start/`
  (run once), `setup/` (Setup), `ending/` (the end of the game). `asm/title.asm` is DUNJUNZ, the title.
- The title picture, `Screen`, is the 1987 one changed by the build
  (`tools/dunjunz_revised/title_picture.py`): "Press any key" replaced by
  the choice of keyboard players, in yellow, and the version drawn in on the
  bottom row, from `_version.py`. After the choice the title shows that
  layout's keys in MODE 7 before loading the game, under a banner of the
  1987 logo in teletext mosaic, with white stars twinkling around it
  (`tools/dunjunz_revised/key_page_banner.py` converts the logo with the
  `sextants` package and makes the stars' frames; the result is checked
  in). The page's text packs runs of spaces as their lengths
  (`tools/dunjunz_revised/page_text.py`). The end of a game offers
  R to play again with the same choices (`asm/ending/ending.asm`). The build also
  renders it to `docs/title-screen.png`. The README shows
  `docs/title-screen.gif` instead, which `uv run dr-title-gif`
  (`tools/dunjunz_revised/title_animation.py`) makes after a build by
  running the title's own star code in py65 over the picture, timed as on
  a BBC Micro; a release runs both.
- `README.md` is generated: edit `README.md.j2`, a Jinja2 template, which
  `tools/dunjunz_revised/generate_readme.py` renders (`uv run dr-readme`,
  and every `dr-build`) with what comes from the game, such as the keyboard
  layouts. `tests/test_readme.py` fails if the two differ.
- The keyboard layouts (1-4 players sharing the keyboard, chosen on the
  title; each set of keys joins the hero menu by its fire key) are kept in
  `tools/dunjunz_revised/key_layouts.py`, which the build writes into
  `asm/defs/key_layouts.asm` for the menu and Setup, and into both READMEs.
  Design and reasons: `docs/enhancements.md`.
- Joysticks (`docs/plan.md`, milestone 6): every key goes through `test_key`
  (`asm/core/test_key.asm`), which also takes the hero's stick bits from
  `control_bits`. The hero menu (`asm/start/joysticks.asm`) detects SPItFIRE
  with OSWORD &3F and copies a driver (`asm/joystick/`) into zero page at
  `read_controls`, which `update_game` calls each frame, and `map_controls`
  into the printer buffer at &0880; with no stick playing, `read_controls` is
  an RTS. `tests/test_joysticks.py` runs a fake SPItFIRE in sideways RAM
  (`tests/fake_spitfire.asm`, `tests/fake_spitfire.py`), which also stands in
  for the analogue port. b2 (`/Applications/b2 Debug.app`, `-c "Master
  Compact (MOS 5.00)"`) runs the game from an ADFS copy of the disc (b2's
  Compact boots ADFS). Its HTTP API (port 48075) peeks and pokes; its paste
  holds SPACE for up to a second before typing, which the menu takes as
  SPACE, and it rejects control characters such as RETURN.
- `uv run dr-sizes` shows where each module is; space is tight, so check it
  after every change. Modules were split to fit: move whole modules between
  regions rather than trimming blindly.
- Everything the tests read is a label: beebasm exports labels, not `=`
  constants, so variables are declared with `skip` in label blocks.

## Equivalence

`tests/test_equivalence.py` runs the original and the revised game frame by
frame (1500 frames, or to game over) with the same scripted keys and
compares their state and screen (`tools/dunjunz_revised/lockstep.py`);
`tests/test_levels.py` does the same across a level change, and
`tests/test_game_over.py` compares the game-over screen. Fixes that change
play are tested in `tests/test_fixes.py`, and the comparisons' scripts avoid
them (no magic). The System VIA timer reads that
supply the game's randomness are patched at run time into calls to a
generator at &0060-&006F, so the revised game must leave that zero page
alone. A state block that is rearranged needs its own entry in
`STATE_BLOCKS`. A deliberate change in behaviour, such as a bug fix, makes
the comparison fail from the first frame it affects. Such a change is
tested on its own, and the comparison is then made against the fixed
behaviour or restricted around it.

## Pace and drawing

`play_level` starts a frame every three vsyncs (120,000 cycles). In 1987 a
frame with four heroes usually takes longer (a median of about 133,000
cycles, 69% of it in `plot_sprite`), so busy rooms play slower. The
revision's plotter has a faster loop for sprites four bytes wide, so most
frames now fit the three vsyncs and the game keeps a steady pace. A change
to the drawing or the frame must not make frames slower: compare `uv run
dr-frame-time` before and after. Routines can be run on their own in py65
(`tools/dunjunz_revised/sixtyfive.py`), as `tests/test_plot.py` runs the
plotter, which is much quicker for working on them than beebium. The plan
for drawing, play apart from rendering, is in `docs/rendering.md`.

## The 1987 release

- `asm/original/game.asm` and `title.asm` are the acornaeology reassembly
  of the Model B disc side (`~/Code/acornaeology/dunjunz`, commit
  `fd674e9`), kept unchanged for the baseline disc. They must keep
  reassembling to `reference/disc/` exactly.
- The peer agent `dunjunz-disassembly` owns the disassembly. Ask it about
  the original code's behaviour. Report back any finding that belongs in
  its `docs/findings.md`.
- Versions are YEAR.N with no patch part. `tools/dunjunz_revised/_version.py`
  is read by the build. Never hard-code the version in assembly.

## Machines

`tools/dunjunz_revised/machines.py` defines the tested configurations as
beebium presets built from bundled ROMs. Econet uses AUN (no hardware).
`tests/test_filing_systems.py` loads levels under each; `tests/test_network.py`
runs a Level 3 File Server (beebium's L3FS preset, its disc given the game by
oaknut-disc) beside a client station. CI skips it for now (the clients never
reach level 1 on GitHub's runners), so run it locally before a release. The peer agent `beebium-architect`
answers questions about beebium. Beebium has no joystick (ADC) emulation.
Beebium has no MMFS2 or Master yet; beebjit has a Master. The memory
layout assumes PAGE is at most &1C00 (ANFS + DFS); see `docs/memory.md`.

## Conventions

- Hex as &XXXX in prose and comments, 0xXXXX in Python.
- Comment every instruction; banner every routine and data region.
- Suffixes `_filename`, `_filepath`, `_dirname`, `_dirpath`, never `_dir`
  or `_file`.
- No mention of AI assistance in comments or commit messages. No emojis
  in commits. Never `git push`.
