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

## Players' own keys, chosen on the title screen

Proposed 2026-11-18. The 1987 keys stay the default. The Ranger's are the
awkward ones: up is CAPS LOCK, down SHIFT LOCK, left SHIFT, right Z and
fire TAB, so some emulators cannot play the Ranger at all. This lets each
of four players set their own keys once, and keeps those keys whichever
hero they play, so one player can play any hero without learning new keys.

### What the players see

- The title says "SPACE to play, K for keys" in place of "Press any key",
  drawn by the build in the picture's own lettering, as the version is
  (`title_picture.py`; the font needs a few more letters). Any key other
  than K still plays, as before, so nobody used to "Press any key" is
  caught out.
- K opens the key editor: for each of the sets 1-4, "press the key for up",
  then down, left, right, fire and magic, read with OSBYTE &79 from key 0,
  so that SHIFT, CTRL and the lock keys can be chosen too. A key already
  given to another action or set is refused. A key to put back the 1987
  keys clears the file's keys. On leaving, the editor saves the keys and
  reloads the picture.
- On the hero menu, the heroes are switched on and off with their
  initials, R, M, B and F, in place of 1-4 (the help line reads
  "KEYBOARD: RMBF JOINS"). Only the menu reads these keys, so it does not
  matter that some are heroes' keys in play.
- With a `Keys` file, the four sets of keys go to the heroes in the order
  they are switched on, and the PLAYING column shows which: KEY1, KEY2,
  KEY3 or KEY4, four characters like the other entries (NO, JOY1-JOY4), so
  the menu's layout is unchanged. A lone player gets KEY1 whichever hero
  they choose. Switching a hero off frees their set for the next hero
  switched on. This is the keyboard's version of what a joystick already
  does (pressing fire on a stick takes the next free hero).
- Without a `Keys` file, nothing changes but the letters: the column shows
  KEYS, as now, and each hero has their 1987 keys, whatever the order they
  are switched on in. Handing out the 1987 keys in order instead would
  give a lone Fighter the Ranger's CAPS LOCK and SHIFT LOCK keys.

### The Keys file

24 bytes: for sets 1-4, the INKEY numbers of up, down, left, right,
fire and magic. Magic is used only when the set's hero is the Ranger or
the Magic-User. Saved and loaded in the current directory, like the
game's other files, so it works on every filing system; a shared,
read-only directory on a file server makes the save fail, which the
editor reports.

The DFS disc has no room in its catalogue: it holds the 31 files a DFS
catalogue allows (`!BOOT`, `Dunjunz`, `Screen`, `GAME`, `Setup`,
`Level1`-`Level24`, `Stones`, `README`). The ADFS disc has room. On DFS:

- `Dunjunz` is a copy of `!BOOT`. The game could reload the title with
  `*RUN !BOOT` instead of `*RUN DUNJUNZ` (`run_title_command` in
  `loader.asm`), freeing the slot; but `*DUNJUNZ` would no longer start
  the game from the command line.
- Or the keys could be kept on a disc of the player's own, in another
  drive, selected before the game starts.
- Merging `Screen` into the title does not work: the title's MODE 2
  clears the screen memory the picture would be loaded into.

### Where the code goes, and what it costs in play

Nothing in play: everything runs before the first frame.

- **The editor** belongs to the title, `DUNJUNZ`, which is a separate
  program. The title runs from &26C0 to &2FBD (2,301 bytes); it can start
  as low as &1C00 (the highest PAGE supported), which leaves about 2.7K
  for the editor below it.
- **The menu** runs from screen rows 23-24 (&6980-&6E17), which it does not
  draw on; 104 bytes are left before &6E80. It reads R, M, B and F for 1-4,
  prints KEY1-KEY4 for KEYS, and records the order: one byte per hero,
  the set they have (0 for their 1987 keys), at &08B8-&08BB in page &08, which survives the reset between
  levels and is unused (&08AD-&08AF and &08BF are also free; that is too
  little to hand 24 bytes of keys from the title to the game, which is
  why the game reads the file itself).
- **Whether there are players' keys** is known to the title, which looks
  for `Keys` when it starts (OSFILE 5) and after the editor saves. It
  leaves a flag at &08BF, which the menu reads to choose between KEY1-KEY4
  and KEYS, and Setup to know whether to load the file.
- **Setup** applies the keys. The 20 direction and fire keys are in the
  per-level workspace (`hero_key_up` to `hero_key_fire`, &0770-&0783),
  which `setup_level` refreshes from `workspace_template` at every level.
  At level 1, after the copy, if the flag is set, Setup loads `Keys` into screen memory (OSFILE
  5 reports a missing file by returning 0, not by an error, on DFS, ADFS
  and NFS; to be confirmed in beebium on each filing system tested) and copies each playing hero's set into their key slots, and
  their magic key into `hero_magic_key` (resident, written once). At later
  levels it copies the template except &0770-&0783, so the keys last the
  game. Setup is loaded with each level and runs in screen memory, so this
  costs disc space, not memory in play.

### Still to decide

- Whether joysticks should also take numbered sets, so that a stick
  and a key set are chosen the same way; today a stick takes a hero on a
  press of fire, and keeps it whatever the keys do.
- The letter for the editor: K is the Barbarian's up key in 1987, which
  does not matter on the title, but E would read just as well (R is now
  the Ranger's letter on the menu).
- Whether the sound switch should move from keys 5 and 6 to a letter too,
  to match R, M, B and F.
- Whether the disc's `README` (`*TYPE README`) should mention the editor;
  it lists the 1987 keys, read from the build.
