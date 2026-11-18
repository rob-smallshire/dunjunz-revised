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
  levels), then shows the chosen layout's keys while the game loads.
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

### Still to decide

- The 1-3 player layouts' keys.
- Whether a `Keys` file of the players' own layouts is wanted later, and
  an editor for it in the title. The DFS disc's catalogue is full (31
  files); `Dunjunz` is a copy of `!BOOT`, and dropping it would make room.
