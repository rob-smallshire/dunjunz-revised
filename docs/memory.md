# Memory and the filing system

How Dunjunz Revised shares a stock Model B's memory with whatever filing
system loaded it. The measurements were made in beebium with
`uv run dr-machines` (PAGE and the private workspace table at &0DF0) and
`uv run python -m dunjunz_revised.workspace_probe` (borrowing the static
workspace).

## Measurements

| Configuration | PAGE | Private workspace | Absolute workspace | Page &0D when idle |
|---|---|---|---|---|
| DFS 0.90 (8271) | &1900 | &1700-&18FF | &0E00-&16FF | `RTI` |
| DFS 0.98 (8271) | &1900 | | | `RTI` |
| DNFS 1.20, no Econet | &1900 | (table holds &97) | | `RTI` |
| DNFS 3.02, no Econet | &1800 | (table holds &97) | | `RTI` |
| DNFS 1.20 with Econet | &1B00 | &1700- | &0E00-&16FF | NFS NMI handler |
| DFS 2.26 (1770) | &1900 | &1700-&18FF | &0E00-&16FF | `RTI` |
| NFS 3.65 alone | &1200 | | | NFS NMI handler |
| ANFS 4.18 alone | &1900 | &1800- | | NFS NMI handler |
| ANFS 4.18 + DFS 2.26 | &1C00 | ANFS &1900, DFS &1A00-&1BFF | &0E00-&18FF | NFS NMI handler |
| NFS 3.65 + DFS 2.26 | &1B00 | DFS &1900-&1AFF | | NFS NMI handler |
| DFS 2.26 + ADFS 1.30 | &1F00 | DFS &1C00, ADFS &1E00 | | `RTI` |
| MMFS2 alone | &1900 (reported) | | | |
| MMFS2 + DFS | &1B00 (reported) | | | |
| MMFS, not supported (from its source) | &1D00 (reported) | &1700- | &0E00-&16FF (service 1 claims to &17) | |

MMFS and MMFS2 are not yet emulated by beebium. The MMFS2 figures are as
reported. Those for MMFS come from `~/Code/MMFS`
(`SERVICE01_claim_absworkspace` raises the limit to &17, and
`SERVICE0A_claim_statworkspace` saves to private workspace) and from
<https://www.bygonebytes.co.uk/mmfs.html>.

Two facts follow:

- **&0E00-&16FF is absolute workspace under every filing system in the
  target set.** No configuration measured puts private workspace below
  &1700.
- **With Econet present, page &0D holds the NFS's NMI handler at all
  times**, idle or not: the ADLC can raise an NMI whenever a frame
  arrives. The original game uses page &0D as workspace, which would crash
  a networked machine during play. Page &0D must be left alone.

## Borrowing the absolute workspace

Service call &0A ("claim static workspace", issued with OSBYTE &8F) asks
the filing system that owns the absolute workspace to save what it needs
into its private workspace. After that, &0E00 up to the lowest private
page can be overwritten. The filing system takes the space back when it is
selected again.

`workspace_probe.py` overwrote &0E00 up to the lowest private page with
&AA and then `*LOAD`ed a level:

| Configuration | No claim | &0A, no reselect | &0A, then service &12 | &0A, then `*DISC` |
|---|---|---|---|---|
| DFS 0.90 | Disk fault 18 | fails | hangs | loads |
| DFS 2.26 | Disc fault 18 | fails | loads | loads |
| ANFS 4.18 + DFS 2.26 | Disc fault 18 | | loads | loads |
| DNFS 1.20 with Econet | Disk fault 18 | | loads | loads |

Service &12 takes the filing-system number that OSARGS 0,0 returns, so it
is the agnostic way to reselect. DFS 0.90 does not survive it, so the
loader falls back on a small table from filing-system number to select
command (4 `DISC`, 5 `NET`) issued through OSCLI. Still to measure: NFS
and ANFS loading from a file server (beebium's L3FS preset can serve
one), MMFS2, and DFS 1.20 without Econet. That last one has to be measured
from its real private page, which its table entry doesn't give.

## The memory map

| Range | In play |
|---|---|
| &0000-&005F | The joysticks: which stick plays each hero, their switch bytes, and the driver at `read_controls` (language workspace, unused while the game runs; `asm/defs/joystick.asm`) |
| &0060-&03FF | MOS; the game's zero page is &70-&8F (&60-&6F is reserved for the tests' random number generator) |
| &0400-&06FF | Scores, the loader, the level loop (stored in GAME, copied by startup) |
| &0700-&07FF | The per-level workspace (`WORKSPACE`), refreshed by Setup for each level |
| &0800-&087F | MOS (sound) |
| &0880-&08AF | `map_controls`, copied by the hero menu into the MOS's printer buffer, which the game never prints to |
| &08B0-&08BF | State kept across games: ten-thousands digits, absent heroes, level counter and digits |
| &08C0-&08FF | MOS: envelopes 1-4, which the game defines |
| &0900-&0CFF | Plotter, hero tables, the wall map at &0C00 (character 128's definition too) |
| &0D00-&0DFF | **Untouched**: the filing system's or the NFS's NMI code |
| &0E00-&16FF | The status panel, font, start of level, sprites, the Chalice test, the game-over text: borrowed with service &0A |
| &1700-&1BFF | **Untouched**: private workspace (PAGE at most &1C00) |
| &1C00-&2FFF | The exit animation, doors and keys, sprites, the frame, the Chalice |
| &3000-&6E7F | Screen (25 rows) |
| &6E80-&7FFF | Heroes, missiles, objects, monsters, views, the font handler, the victory sequence |

`uv run dr-sizes` gives each module's place and size; `asm/dunjunz.asm`
assembles the regions and asserts each fits.

**Decision:** the layout assumes PAGE is at most &1C00, the highest in the
target set (ANFS 4.18 + DFS 2.26). MMFS2's reported PAGE (&1B00 at most)
fits, but it is not claimed as supported until it can be tested. The
original MMFS, at &1D00, does not fit.

### The files

- `GAME`, loaded once at &1C00-&7FFF. Its startup runs from screen memory
  (&6980): it closes any `*EXEC` file, notes the filing system (OSARGS 0,0),
  claims the absolute workspace (service &0A), copies the parts stored at
  &3000-&41FF to &0400, &0900 and &0E00, and runs `game_entry` and the hero
  menu, also from screen memory, so neither stays resident.
- `Setup`, loaded with every level at &5000 and run there: it unpacks the
  level, refreshes the workspace from its template and resets the monsters,
  before the screen is cleared and drawn.
- `Level1`-`Level25`, unencrypted, loaded at &6B00.

### Loading a level

`load_level` (in &0400-&06FF, never in the borrowed workspace):

1. Blank the display (6845 register 1 = 0) and disable VDU output.
2. Copy the game's &0E00-&16FF to the stash at &3000.
3. Reselect the filing system (`*DISC`, `*NET`, or service &12 for any
   other), which rebuilds its absolute workspace from its private workspace.
4. Load `Setup` with OSFILE, at an address with &FFFF in its top 16 bits so
   that, with a second processor, it lands in the I/O processor.
5. Claim the workspace again with service &0A and copy the game back.
6. Steps 2-5 again for the level file, then show the play screen.

Game over and victory give WRCHV back to the MOS, reselect the filing
system and `*RUN DUNJUNZ`.

The 6845 set-ups go through the MOS's WRCHV, saved in `saved_wrchv`:
`wrch_handler` would print a letter or digit among the parameters (80 is
"P") as character 128.

## Closing the boot file

A `!BOOT` run with `*EXEC` (boot option 3) leaves the file open until it
is read to its end. Its channel and buffer live in the filing system's
workspace, so the loader must close it (OSBYTE &77) before the game takes
that workspace over. The original game, booted this way, never reaches
play, so the baseline disc `*RUN`s a copy of `Dunjunz` as `!BOOT`
(option 2) instead.

## Interrupts at entry

Booted with SHIFT+BREAK, DFS 2.26 and DNFS 1.20 `*RUN` the option-2
`!BOOT` with interrupts disabled (P = &35 and &25 at the title's entry);
DFS 0.90 does not (&23). A `*RUN` typed at the keyboard enters with them
enabled under all three (measured by the disassembly). The 1987 Model B
disc has boot option 0, so it never took this path. `*RUN GAME` from the
title keeps the flags. MOS 1.20's OSRDCH doesn't enable interrupts, and a
fresh key press is found only through the System VIA's keyboard interrupt,
so the hero menu never saw one. The title's entry and `startup` both begin
with `cli`. The tests that hold SPACE from boot didn't show this, so
`tests/test_menu.py` taps each key and releases it, as a player does.

## Constraints on moving code

Found by searching the modules (`asm/dunjunz.asm` ASSERTs the first three):

- `room_walls` and `object_free_map` must start on a page boundary.
  `test_wall`, `test_object_free`, `draw_room` and `update_game` make a
  pointer from the table's high byte and the room's offset.
- The exit animation in `core/frame.asm` falls through from &1FFF into
  `extra/exit.asm` at &2000, and `frame.asm` branches to `restore_exit`
  there.
- `collect_objects` (`upper/objects.asm`) branches to `magic_sword` in
  `upper/hero_room.asm`.
- The sprite address tables are label expressions, so sprites can move.
  `test_sprites_match_the_original` reads all 120 sprites through the
  tables in both builds.
- `sprite_blank` (three sprites) is a run of zeros in the &0400 image.
- Module sizes and places: `uv run dr-sizes`.
