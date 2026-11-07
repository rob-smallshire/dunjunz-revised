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
uv run python -m dunjunz_revised.workspace_probe KEY ...   # static workspace borrowing test
uvx bump-my-version bump minor                    # release: 2026.1 -> 2026.2, commit + tag (user pushes)
```

## Source of truth

- `asm/original/game.asm` and `title.asm` are the acornaeology reassembly
  of the Model B disc side (`~/Code/acornaeology/dunjunz`, commit
  `fd674e9`). They must keep reassembling to `reference/disc/` exactly. The
  revised game is developed from them, and every change is a commit.
- The peer agent `dunjunz-disassembly` owns the disassembly. Ask it about
  the original code's behaviour. Report back any finding that belongs in
  its `docs/findings.md`.
- Versions are YEAR.N with no patch part. `tools/dunjunz_revised/_version.py`
  is read by the build. Never hard-code the version in assembly.

## Machines

`tools/dunjunz_revised/machines.py` defines the tested configurations as
beebium presets built from bundled ROMs. Econet uses AUN (no hardware).
Beebium has no MMFS or Master yet; beebjit has a Master.

## Conventions

- Hex as &XXXX in prose and comments, 0xXXXX in Python.
- Comment every instruction; banner every routine and data region.
- Suffixes `_filename`, `_filepath`, `_dirname`, `_dirpath`, never `_dir`
  or `_file`.
- No mention of AI assistance in comments or commit messages. No emojis
  in commits. Never `git push`.
