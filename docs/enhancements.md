# Possible enhancements

Ideas for later, beyond the 1987 game's behaviour. None is planned yet;
each needs the owner's go-ahead. Decided work belongs in `plan.md`.

## Transparent sprites for the heroes

`plot_sprite` copies each byte to the screen, so a sprite's black pixels
hide whatever is under it: a hero standing on a trapdoor, key or object
covers the whole cell. Treating colour 0 as transparent needs no mask
tables, because a MODE 2 byte's two pixels are interleaved bits: the left
pixel is non-black if any bit of &AA is set, the right if any bit of &55
is set, so the mask is &AA, &55, both or neither, and the plot becomes
`screen = (screen AND NOT mask) OR byte`.

- Cost: a masked variant of the plot loop (about 30-40 bytes) and about
  20 cycles more per byte, so it should be used for the heroes (and perhaps
  missiles) only.
- Order: what shows through must be drawn first. Trapdoors already are
  (`draw_trapdoors` starts the frame); keys and objects are drawn after
  the heroes, and would have to move earlier.
- It changes the look of the game only where sprites overlap.

## A controls screen

The controls are in the README only. The Model B disc shows none; the
1987 Master disc's BASIC loader had a MODE 7 controls page. A help page
before the hero menu, or the key-redefinition phase planned for joysticks
(`plan.md`, milestone 6), could show them.

## Keyboard layouts for 1-4 players, and fire to join

Proposed 2026-11-18; being tried on the `title-keys` branch.

### The problem

The 1987 keys are laid out for four players at one Model B keyboard, one
cluster each, placed by position, not by label: the Ranger's at the far
left (up CAPS LOCK over down SHIFT LOCK, left SHIFT, right Z, fire TAB,
magic CTRL), the Magic-User's at the far right (up is the key labelled
→, down ↑ below it, left DELETE, right COPY, fire ↓, magic RETURN), the
Barbarian's right of centre (up K over down comma, left full stop, right
slash, fire SPACE) and the Fighter's in the middle, across both hands (up
G over down B, left U, right I, fire O). They work on a real BBC Micro,
which the game is still played on. Played alone or by two, though, they
fit badly, and in emulators the Ranger's lock keys cannot be held: a PC's
CAPS LOCK is a toggle that is often reported only when it changes.

The right keys depend on how many share the keyboard, not on which hero
they play. A lone player wants a two-handed layout in predictable places
(ZXMKL, a convention in newer BBC Micro games); two players want one set
each side; four want the 1987 layout.

### The design

- **The title asks how many share the keyboard.** It reads "Press 1-4 for
  keyboard players / or fire for joysticks only" where "Press any key"
  was (done on the branch: `title_picture.py`). 1-4 chooses that layout;
  fire on a stick chooses none; any other key counts as 4, so a player
  who presses SPACE out of habit gets the 1987 keys. The title leaves the
  count at &08BF in page &08 (free; it survives the reset between
  levels), then shows the chosen layout's keys in MODE 7 and waits for a
  key, before loading the game (which loads over all of screen memory, so
  nothing can be shown while it loads). Across the top, seven rows of
  the 1987 DUNJUNZ logo in teletext mosaic graphics, shaded yellow, red
  and magenta, row by row, with white stars twinkling in the blank cells
  around it, as on the title picture: five sites (left of the D, under
  each "un", above the first, after the Z), each with codes for white,
  separated graphics where there is room, and back to the logo's colour.
  Each twinkles, a dot growing through two crosses to a sparkle and back,
  at its own period (41 to 67 ticks of 3 cs), so they never keep step.
  The logo is converted without hold or fill codes, so that the stars'
  codes can go in any blank cell, and the page's text packs runs of spaces
  as their lengths to make room. Under it the header, indented
  clear of the logo, and a steady "Press any key", centred, always on
  the bottom row. The sets spread out over the rows between, the spare
  rows shared out evenly above, between and below them (`set_gaps`). Each set takes three rows, its
  KEY1-KEY4 heading beginning the first, its keys set out as they point:
  left beside right, and up over fire over down beside them, in aligned
  columns of actions (green) and keys (white), each colour code standing
  in for the space before it. The widest row (the Magic-User's cursor
  keys) fills all 40 columns, ending without a carriage return, as the
  cursor moves to the next row by itself. That leaves no room for a code
  before the heading, so it is white, the colour a row starts in.
- **Each layout has one set of keys per player:** up, down, left, right,
  fire and magic (used only by the Ranger and the Magic-User). The
  4-player layout is the 1987 keys, unchanged. The 1-3 player layouts are
  new, made for a real keyboard first: no lock keys, one set each side
  for two. Every layout is checked for phantom keys (three held keys at
  three corners of a rectangle in the keyboard matrix make the fourth
  read as held, if the matrix has no diodes, as is believed), with each
  player holding a direction and fire together.
- **Everyone joins the hero menu the same way: press fire.** A stick's
  fire or a key set's fire takes the first free hero; each further press
  moves on to the next free one, and past the Fighter to nobody. This is
  what sticks do now; key sets do the same. The PLAYING column shows
  KEY1-KEY4 or JOY1-JOY4. With 4 chosen, four players who each press
  their own fire once, in hero order, are exactly as in 1987, and a lone
  player who wants the Fighter's keys presses O until they have the
  Fighter.
- **RETURN starts the game**, in place of SPACE, which is the Barbarian's
  fire key. No layout may use RETURN, 5 or 6 (sound) as fire. Keys 1-4
  no longer switch heroes.
- **Where the choice is kept:** `hero_stick` (zero page, kept through
  play) holds 0-3 for a stick and &FF for none; KEY1-KEY4 would be
  &80-&83, which `map_controls` already skips as negative, so play's stick
  handling is unchanged.
- **Setup applies the keys at level 1.** The 20 direction and fire keys
  are in the per-level workspace (`hero_key_up` to `hero_key_fire`,
  &0770-&0783), which `setup_level` refreshes from `workspace_template`
  at every level. At level 1, after the copy, Setup copies each hero's
  set from the chosen layout into their slots, and their magic key into
  `hero_magic_key` (resident, written once); at later levels it copies
  the template except &0770-&0783, so the keys last the game. A hero on a
  stick gets keys that are never pressed, so that another player's keys
  cannot move them (today a hero on a stick still answers to their 1987
  keys). Setup is loaded with each level and runs in screen memory, so
  none of this costs memory in play.

### The layouts

Any set can join any hero, so every set has a magic key, used only when
its hero is the Ranger or the Magic-User.

The 4-player layout (decided 2026-11-18) is the 1987 keys, with magic keys
added for the Barbarian's and the Fighter's sets, which had none:

| Set | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| 1 (1987 Ranger) | CAPS LOCK | SHIFT LOCK | SHIFT | Z | TAB | CTRL |
| 2 (1987 Magic-User) | → | ↑ | DELETE | COPY | ↓ | RETURN |
| 3 (1987 Barbarian) | K | , | . | / | SPACE | L |
| 4 (1987 Fighter) | G | B | U | I | O | J |

Set 4's magic was to be P, but P pauses the game in play, so casting would
pause it; J, under the right hand beside the Fighter's U and I, replaced it.
No set may use P or ESCAPE (held to end the game), and no fire key may be
RETURN, 5 or 6, which the hero menu reads.

The 1-player layout (decided 2026-11-18) is two-handed, ZXMKL with SPACE:

| Set | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| 1 | K | M | Z | X | L | SPACE |

The 2-player layout (decided 2026-11-18) has one set each side:

| Set | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| 1 | R | D | A | S | T | C |
| 2 | K | M | B | N | ; | SPACE |

Set 2's fire was to be L, but A, S, K and L are the corners of a rectangle
in the keyboard matrix (rows 4-5, columns 1 and 6), so player 1 holding
left (A) while player 2 moved up and fired (K, L) would make player 1's
right (S) read as held too, if the keyboard ghosts; ; breaks the
rectangle. With it, no combination of each player holding a direction and
fire, or one casting while the other moves and fires, makes a phantom of
any key the game reads.

The 3-player layout (decided 2026-11-18) is the 4-player one without the
Ranger's set: the keys three players of the 1987 game without the Ranger
already know, and no lock keys.

| Set | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| 1 (1987 Magic-User) | → | ↑ | DELETE | COPY | ↓ | RETURN |
| 2 (1987 Barbarian) | K | , | . | / | SPACE | L |
| 3 (1987 Fighter) | G | B | U | I | O | J |

Whether the keyboard ghosts is not known; it matters only on a real BBC
Micro (an emulator reads the host's keys). The 1987 sets are prone to it if
it does: every key of the Magic-User's set is in column 9 of the matrix, so
that player holding a direction and fire, with any key in the same row as
either, would make a fourth key read as held (the Magic-User moving down
and firing while the Fighter moves left would read the Fighter's right
too). The check finds 10 such combinations of three keys in play for 3
players, and many more in the 1987 4-player layout, which was played on
real machines for years; the 1-player and 2-player layouts have none. To
test on a real BBC Micro: hold the Magic-User's ↑ and ↓ and the Fighter's U,
and see whether `INKEY(-38)` (I) is TRUE.

### Where the code goes

- **The title** (`DUNJUNZ`, a separate program) reads the choice and
  shows the keys. It runs from &26C0 to &2FBD and can start as low as
  &1C00, the highest PAGE supported, about 2.7K more. Reading fire needs
  OSBYTE &80 for analogue sticks and, for SPItFIRE, the detection the
  hero menu does with OSWORD &3F.
- **The layouts** are needed by the title (to show them), the menu (the
  fire keys only, 10 bytes) and Setup (all of them, 60 bytes), from one
  source.
- **The menu** runs from screen rows 23-24 (&6980-&6E17), which it does
  not draw on; 104 bytes are left before &6E80. Polling the key sets'
  fire keys, with press detection like the sticks', adds code; the 1-4
  toggles it no longer needs take some away.

### Tests

The comparisons with 1987 start a game by pressing 1-4 in the menu and
holding SPACE from the title to the first frame (`lockstep.py`). They
would choose 4 on the title instead, press each set's fire in hero
order (TAB, cursor down, SPACE, O) and start with RETURN.

### Still to do

- The title's "fire for joysticks only" reads only the analogue port's fire
  buttons (OSBYTE &80 in `twinkle_stars`), not SPItFIRE's, so with SPItFIRE
  sticks a player must press a key on the title instead (any other key gives
  four keyboard players); the sticks still join on the hero menu. Reading
  SPItFIRE there needs the OSWORD &3F calls the hero menu makes
  (`asm/start/joysticks.asm`), and room: the title, at &2000, has about 20
  bytes left below the screen, but could start at &1C00. Left for now, as
  only one SPItFIRE board exists (2026-11-19).

### Still to decide

- Whether a `Keys` file of the players' own layouts is wanted later, and
  an editor for it in the title. The DFS disc's catalogue is full (31
  files); `Dunjunz` is a copy of `!BOOT`, and dropping it would make room.

## An enhanced game, with extras in paged RAM

Researched 2026-11-21; nothing is decided yet. The idea: Dunjunz Revised
as it is, plus extras for machines with RAM to spare: the Master 128
version's music (with music on and off on 7 and 8 in the hero menu,
beside sound on and off on 5 and 6), keyboard layouts for three and four
players that use the Master 128's numeric keypad, and in time play over
Econet. The machines in mind are a Model B with at least 8 KB of sideways
RAM, a B+ (64 KB or 128 KB) and a Master 128. Facts about the 1987 Master
version are from the disassembly (`docs/analysis/the-master-128-version.md`
in `~/Code/acornaeology/dunjunz`); facts about the machines are from
beebium's code and the New Advanced User Guide, as beebium-core-developer
reported them (emulated, documented or believed, as marked).

### One game, not separate ones

Main memory is full in play (see `memory.md`), and stays as it is. The
extras are assembled at &8000 and live in paged RAM, wherever the machine
has some; the game keeps a short routine in main memory that pages them
in, calls them and pages them out, and a few hooks (level start, game
over, pause) that do nothing when no paged RAM was found. So the game,
its tests and its comparisons with the 1987 game are unchanged without
the extras, and only finding the RAM differs from machine to machine. Two
games would double the play code to fit, test and keep in step.

A Master's lower PAGE (&0E00) does not help: the layout is fixed for PAGE
up to &1C00, so a Master frees only &1700-&1BFF, 1,280 bytes. The 1987
music's player and tune alone are 4,186 bytes (`Code2`).

### Where the paged RAM is

| Machine | Paged RAM | How it is paged and written | Notes |
|---|---|---|---|
| Model B, Watford ROM/RAM board | banks 0-7 (in beebium's preset) | Paged by ROMSEL as usual; writes go to the socket chosen by a write latch (a write to &FF30+N chooses socket N), whatever is paged in (emulated) | The latch cannot be read back, so the loader sets it, writes, and leaves it; nothing else may move it later |
| Model B, ATPL Sidewise | slot 15 only | Every write to &8000-&BFFF lands in slot 15, whatever is paged (emulated); switch S6 protects it | Test slot 15 only with it paged in |
| Model B, Integra-B | banks 4-7, and maybe 8-15 in pairs | ROMSEL; bit 6 pages 12 KB of private RAM and bit 7 the shadow screen (emulated) | IBOS may have claimed banks (*SRDATA): ask it, don't assume (believed) |
| Model B, other boards | any | ROMSEL; a per-slot protect switch on some (emulated for beebium's notional board) | Find a bank by its missing ROM header and a write that reads back (believed) |
| B+ 64 KB | 12 KB at &8000-&AFFF | ROMSEL bit 7 (emulated); ROMSEL cannot be read (believed) | To measure: whether MOS 2.00 or the filing systems use it, and whether &F4 keeps bit 7 |
| B+ 128 KB | the 12 KB, and four 16 KB banks: 12, 13, 0 and 1 (emulated, with S13 at its default) | ROMSEL | OSBYTE &44 lists the RAM banks (documented); check what it returns on the B+ |
| Master 128 | banks 4-7 | ROMSEL, plain RAM (emulated); OSBYTE &44 and &45 say which are RAM and which are in use (documented) | ANDY (&8000-&8FFF) is the MOS's; HAZEL (&C000-&DBFF) is the filing systems', and ADFS takes much more of it than DFS (believed), so the 1987 version's use of HAZEL is not safe under ADFS |
| Master Compact | banks 4-7 (documented) | | No numeric keypad; beebium has no Compact |

### Finding a bank politely

Only a bank that holds no ROM image is used: not one the MOS registered
at reset, nor one loaded since without a reset. Two routines show how;
ours would follow their method, written afresh.

**Cleo** (`~/Code/beebium/discs/games/cleo_modelb_230926b.ssd`, its
`LOADER` at &1900, the routine at &1B2D) works on every Model B and B+
sideways RAM that beebium emulates:

1. With interrupts off, it counts the banks that take a write in each of
   three ways: plain ROMSEL paging; the Watford way, a write to &FF30+N
   before writing bank N; and the Solidisk way, &FE62 = 15 then &FE60 = N.
   It keeps whichever finds the most (&FE62 is set back to 0 otherwise).
2. A write test flips bit 0 of &8006 (the ROM type byte), compares, and
   puts the byte back.
3. Each bank that takes a write is classed: in use, if the MOS's ROM type
   table (&02A1+N) has an entry; an unregistered image, if it has a ROM
   header (the "(C)" string at the offset &8007 gives); otherwise free.
4. Aliases: every bank that takes a write gets its own tag in &8007 (bank
   OR &C0), then each is read back; a bank that does not show its tag
   aliases another (or answered from a floating bus) and is dropped. Every
   &8007 is then restored.
5. Free banks are taken first, then unregistered images, then registered
   ROMs (Cleo needs four banks). The enhanced game would take only free
   ones.

**Tricky's routine** (stardot, "SWRAM detection for writing",
<https://stardot.org.uk/forums/viewtopic.php?p=446835>) does the same
with &8008, the version byte, and a test value per bank chosen to differ
from every bank's byte, so aliases on a Model B are not counted twice.

Pitfalls raised on stardot, and what covers them:

- On a Master, an empty bank (a cartridge slot) can read back the value
  just written, or video data, from a floating bus, so it looks like RAM
  (hoglet, <https://stardot.org.uk/forums/viewtopic.php?t=16335&start=30>).
  Cleo's second pass, with a different tag for each bank read back after
  all are written, catches this; on a Master, OSBYTE &44 avoids probing at
  all.
- Flash chips can read back a write before it is stored: wait about
  200 µs before reading back (sweh).
- An NMI can arrive during the test; the test byte should be one the NMI
  code never touches (&8006-&8008, not &BFFF).
- The Solidisk registers upset some MMC interfaces (Tricky, KenLowe), so
  the Solidisk way is worth trying only when the others find nothing.
- On the ATPL Sidewise every write lands in slot 15, so testing any other
  bank writes slot 15's &8006 (Cleo restores it with the other bank's
  byte). Slot 15 must be tested last, or its byte saved first.
- The Watford board's write latch cannot be read back, so the routine
  can only set it back to 0, its state at power on, when it is done.
- IFEL boards allow writes only from code in a ROM on the board, so they
  are not found (Tricky).

### When every bank is in use

If every RAM bank holds a ROM image, the loader lists them, each with its
title and copyright string from its header (the title at &8009, the
copyright at the offset &8007 gives), and the player chooses one to give
up, or plays without the extras. Some banks are never offered, as the
game or the machine needs them:

- **The current filing system.** A filing system ROM claims FILEV-FSCV
  through the MOS's extended vectors: the vectors (&0212-&021F) hold
  &FF1B-&FF2D, and the extended vector table at &0D9F, three bytes a
  vector (address, then bank), gives its bank: &0DBC for FILEV. Measured
  in beebium (2026-11-21) on every machine in `machines.py`: bank 14 on
  the Model B configurations (with DFS 2.26 and ADFS 1.30 both fitted, 14
  is the DFS, the current one), 11 on the B+ and the B+ 128K. It finds a
  filing system loaded into sideways RAM too, such as MMFS, the bank most
  likely to be offered otherwise. Page &0D is the filing system's, and the
  game leaves it alone, so it can be read at any time.
- **Any bank another vector leads to.** The same table shows any ROM that
  has claimed another vector (WRCHV, BYTEV and so on, such as a printer
  buffer ROM); overwriting it would crash the machine at once.
- **The current language** (its bank at &028C; BASIC, bank 15, on every
  preset).

A bank given up must also be taken out of the MOS's ROM type table
(&02A1+n set to 0) before it is overwritten, or the MOS will go on calling
it with service calls. The player's choice can be kept for the rest of the
session: the bank then holds the extras, without a ROM header, and the
search finds it free next time.

The B+ 64K's 12 KB at &8000-&AFFF (ROMSEL bit 7) is not a bank, and Cleo
does not look at it; finding it is a check of the machine (OSBYTE 0 on a
B+ gives 2) and the same write test with bit 7 set.

Tests in beebium can boot each board's preset, run the search, and check
both the bank found and that every other bank's bytes are unchanged.

### The music

The 1987 Master version plays it from the interval-timer event: one step
every 12 centiseconds, a 7.7 s opening of rhythm only, then 4 min 27 s
that loop, carried on from level to level and stopped while a level
loads and at game over. Its OSWORD 7 calls come from the event. An
event handler that saves &F4, pages the bank in (&F4 and &FE30), runs the
step and restores both is expected to be safe on every machine, as the
MOS restores ROMSEL from &F4 (believed). The exceptions: on the Master
ROMSEL is readable, and bit 7 (ANDY) must be kept as found; on the B+ it
depends on whether &F4 keeps bit 7; on the Integra-B, bits 6 and 7 must be
kept as IBOS had them; on the Watford board the write latch must not be
touched. Sound off (6, OSBYTE &D2) should silence the music too (not yet
tested). The 1987 version also took the bell off firing, probably so as
not to clash with the tune.

### Master 128 keyboard layouts

These need no paged RAM: only the layouts' tables and the title's pages
of keys. The title has a few bytes left below the screen, but could start
at &1C00 instead of &2000. They are for the Master 128 only (`INKEY-256`
gives &FD; a Compact gives &F5 and has no keypad). The phantom-key tests
apply to them, with the keypad's INKEY numbers. The 1987 Master keys are a
starting point: the Magic-User on the keypad, the Barbarian on G, B, M, N
and SPACE, the Fighter on _, RETURN, COPY, DELETE and [.

### The disc

The extras must be on the DFS disc too: a Model B or a B+ loads from DFS,
and so do many Masters, so an ADFS-only enhanced game helps no one. The
DFS catalogue is full (31 files). The ways to make room:

- Drop `Dunjunz`, the copy of `!BOOT`, and have game over and the README
  use `*RUN !BOOT`. Costs nothing in loading.
- Put the extras at the front of `Setup`, so that they land in the
  blanked screen and are copied to paged RAM once; every level's load then
  reads them again, 4-6 KB more.
- Two levels to a file.

The first looks best.

### Play over Econet

The extras should be a general way to run code from paged RAM, not one
for music alone, because play over Econet would need the room. The
approach: every station runs the whole game and they exchange each
frame's keys, as the tests' lockstep does, with the game's randomness
from a generator every station seeds alike (as the tests already
arrange). The memory layout already leaves the NFS's workspace and page
&0D alone, and beebium runs several stations on AUN. To find out: whether
Econet can carry an exchange a frame (60 ms) between four stations, and
whether a station shows all four views or its own hero across the whole
screen (asked for on stardot).

### Testing

Beebium has presets for each Model B board above, the B+, the B+ 128K
and, from 0.21.0, the Master 128. The 0.21.0 Linux server wheels are not
on PyPI (they were over its size limit), and 0.22.0, which shrinks them,
is not released, so CI on ubuntu-26.04 cannot yet run a Master. Locally
it can.

### Still to find out

- Whether MOS 2.00, DFS, ADFS or the NFS on a B+ use the 12 KB of private
  RAM, and whether &F4 keeps bit 7 (a write watchpoint in beebium).
- How much of HAZEL ADFS 2.03 claims (service &23, or a watchpoint).
- What OSBYTE &44 returns on the B+ 128K.
- How IBOS keeps track of ROMSEL bits 6 and 7, and which banks it has
  claimed.
