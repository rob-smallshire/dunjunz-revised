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
| MMFS2 | &1B00 (reported) | | | |
| MMFS (from its source) | &1D00 (reported) | &1700- | &0E00-&16FF (service 1 claims to &17) | |

MMFS is not yet emulated by beebium; its figures come from `~/Code/MMFS`
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
one), MMFS, and DFS 1.20 without Econet. That last one has to be measured
from its real private page, which its table entry doesn't give.

## The plan for memory

| Range | Use in Dunjunz Revised |
|---|---|
| &0000-&03FF | MOS and the game's zero page, as in the original |
| &0400-&0CFF | Game, as in the original, keeping clear of what the MOS uses while sound and OSWRCH run |
| &0D00-&0DFF | **Untouched**: the filing system's or the NFS's NMI code |
| &0E00-&16FF | Game, borrowed with service &0A; stashed in screen memory while a level loads |
| &1700-max PAGE | **Untouched**: private workspace |
| max PAGE-&2FFF | Game |
| &3000-&6E7F | Screen (25 rows); holds the stash while a level loads |
| &6E80-&7FFF | Game |

So the revised game loses &0D00-&0DFF and &1700 up to the highest PAGE we
support, compared with the original's &0400-&2FFF. With PAGE at &1D00
(MMFS), that is 1.75 KB. Against it: about 1 KB unused in play (see the
acornaeology findings, "Space a revised version could recover"), the
victory sequence loaded only when needed, the decryption and checksum
code and the reset-between-levels machinery all gone, and more compact
code.

Loading a level, with the game resident:

1. Show LEVEL n. Copy the game's &0E00-&16FF to screen memory, below the
   level number.
2. Reselect the filing system (service &12, or the OSCLI fallback). It
   rebuilds its static workspace from its private workspace.
3. Load the level with OSFILE, at an address with &FFFF in its top 16 bits
   so that, with a second processor, it lands in the I/O processor.
4. Claim the static workspace again with service &0A and copy the game's
   &0E00-&16FF back.

The code that runs steps 1-4 must lie outside &0E00-&16FF.

## Closing the boot file

A `!BOOT` run with `*EXEC` (boot option 3) leaves the file open until it
is read to its end. Its channel and buffer live in the filing system's
workspace, so the loader must close it (OSBYTE &77) before the game takes
that workspace over. The original game, booted this way, never reaches
play, so the baseline disc `*RUN`s a copy of `Dunjunz` as `!BOOT`
(option 2) instead.
