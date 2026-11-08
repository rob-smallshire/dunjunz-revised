# Open questions

Decisions needed from the project's owner, each with a recommendation.
Answers go into `bugs.md` or `plan.md` as they are made.

## Bugs whose fix needs a choice

These are definite bugs (`bugs.md`, "Fix"), but more than one fix is possible.

1. **A monster emerging from a trapdoor tests a stale cell.**
   `monster_reappears` passes `find_creature` whatever `cell_x`/`cell_y`
   held. Pointing it at the trapdoor's cell isn't enough: when the trapdoor
   is occupied, the "park" branch puts the monster at &FF,&FF for good, and
   `find_creature` also hurts a hero standing there.
   *Recommendation:* test the trapdoor's own cell. If anything is there,
   leave the monster dead (blank sprite, off the map), so it tries again
   on a later frame at the next trapdoor. Don't hurt a hero who is merely
   standing on a trapdoor.

2. **Each hero who leaves by the exit leaks a return address**, adding a
   frame per hero to the level's end.
   *Recommendation:* drop the return address when the descent starts.
   The only visible effect is that the level ends a few frames sooner.

3. ~~A hero standing on a key swaps keys every other frame.~~ Fixed
   (2026-11-08): one swap on arrival, which the 1987 instructions describe
   ("the key lying on the floor is picked up, and the original key being
   carried is dropped in its place"). See `bugs.md`.

4. **A key dropped at the exit can land in a wall**: the fourth
   neighbouring cell isn't tested, and neither is any cell for keys or
   objects already there.
   *Recommendation:* test all four cells for walls and keys. If none is
   free, keep the key on the hero, who is leaving anyway, so it is lost
   from this level as it would be in a wall.

5. **Teleport landings aren't checked**: the hero is put above the
   destination teleporter whatever is there.
   *Recommendation:* try the cells above, right, below and left of the
   destination in turn; if all are blocked, don't teleport.

## Behaviours to rule on

`bugs.md`, "Rule". *Recommendation in brief:*

| Behaviour | Recommendation |
|---|---|
| A monster on exactly 0 hit points survives | Keep: it is the game's balance (five arrows on level 1) |
| Survivors gain a point at every new level | Keep: harmless, and players won't notice |
| A missile stops at a dead hero's skull | Fix: skulls are scenery |
| A bounced missile can hit its firer | Keep: it reads as intended |
| Any object found takes off the Boots of Speed | Ask: possibly intended, as boots wear out |
| A Potion of Healing can leave 00 health | Fix: a potion should never leave a hero worse off than one point from death; give at least 1 |
| A Cross is used up when nobody is waiting | Keep: it scores 10 |
| A caster killed by magic's cost still kills the room | Keep |
| Walking into a monster costs one point whatever the armour | Keep |
| Monsters cross room boundaries two cells in two frames | Keep: changing it changes how the game feels |
| All 30 monsters emerge together at the start | Keep |
| A refused move still turns the hero | Keep: it is how you aim |

## Joysticks

Deferred (2026-11-08): no joystick support for now. A later loading phase
will redefine keys and select a joystick driver; see `plan.md`,
milestone 6. Still needed then: SPItFIRE's and the Delta 14/B's button
layouts and detection, how one-button sticks cast magic, and ADC
emulation in beebium to test the drivers.

## Machines

- **Master 128:** untested. Beebium has no Master. The acornaeology
  repository's `tools/master_probe.py` runs beebjit; the next step is a
  Master boot test there. On the Master the filing system's workspace isn't
  in &0E00-&16FF, so the borrowing is harmless; page &0D and the MOS 3.20
  details need checking.
- **MMFS2:** untested. Beebium can't emulate it.
- **A second processor raises the I/O processor's OSHWM** from &1900 to
  &1F00 with DFS 2.26 in beebium, though DFS's private workspace stays at
  &1700. What claims &1900-&1EFF? The game runs in the I/O processor
  regardless, and loads levels there, so the title skips its PAGE check
  when a Tube is present, and the game also overwrites the Tube host code
  in &0400-&07FF, as the 1987 release did. A BREAK restores it.
- **Integra-B and other PAGE-raising set-ups:** the game needs PAGE at
  most &1C00. The loader could check OSHWM (OSBYTE &83) and say so,
  rather than fail obscurely. Done: the title refuses to run
  with PAGE above &1C00 (not checked when a Tube is present).
