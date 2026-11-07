# CLAUDE.md

Dunjunz Revised: Julian Avis's Dunjunz (Bug-Byte, 1986/87) for the BBC
Micro, fixed, resident and filing-system agnostic. 6502 in beebasm, built
by Python tools, tested in beebium. Goals and milestones: `docs/plan.md`.
Memory and filing-system design, with measurements: `docs/memory.md`. Bug
triage: `docs/bugs.md`. Record decisions there as they are made.

## Commands

```bash
uv run dr-build                                   # assemble, verify the baseline, write build/*.ssd
uv run pytest                                     # tests (beebium)
uv run dr-machines                                # PAGE per machine configuration
uv run dr-sizes                                   # address range and size of each game module
uv run python -m dunjunz_revised.workspace_probe KEY ...   # static workspace borrowing test
uvx bump-my-version bump minor                    # release: 2026.1 -> 2026.2, commit + tag (user pushes)
```

## Source layout

- `asm/dunjunz.asm` is the game's top level: it INCLUDEs the modules under
  `asm/` (paths from the project root, where beebasm runs) between the
  `org`/`copyblock` directives that place them. The modules are grouped by
  the memory each is assembled into: `defs/` (constants and addresses),
  `core/` (stored at &3000, runs at &08C0-&1FFF), `low/` (the keyboard and
  joystick images of &0400-&07FF), `extra/` (&2000-&2FFF), `coder/` (Coder
  at &5000 and the padding to &6E80) and `upper/` (&6E80-&7FFF). The title
  and loader are `asm/title.asm`.
- While `REVISED_MUST_MATCH_ORIGINAL` is set in `build.py`, the revised
  sources must assemble to the original bytes. A change that is meant to
  alter the output turns it off, and from then on the tests compare
  behaviour with the baseline instead.

## Equivalence

`tests/test_equivalence.py` runs the original and the revised game frame by
frame with the same scripted keys and compares their state and screen
(`tools/dunjunz_revised/lockstep.py`). The System VIA timer reads that
supply the game's randomness are patched at run time into calls to a
generator at &0060-&006F, so the revised game must leave that zero page
alone. A state block that is rearranged needs its own entry in
`STATE_BLOCKS`. A deliberate change in behaviour, such as a bug fix, makes
the comparison fail from the first frame it affects. Such a change is
tested on its own, and the comparison is then made against the fixed
behaviour or restricted around it.

## Source of truth

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
Beebium has no MMFS2 or Master yet; beebjit has a Master. The memory
layout assumes PAGE is at most &1C00 (ANFS + DFS); see `docs/memory.md`.

## Conventions

- Hex as &XXXX in prose and comments, 0xXXXX in Python.
- Comment every instruction; banner every routine and data region.
- Suffixes `_filename`, `_filepath`, `_dirname`, `_dirpath`, never `_dir`
  or `_file`.
- No mention of AI assistance in comments or commit messages. No emojis
  in commits. Never `git push`.
