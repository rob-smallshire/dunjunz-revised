# Open questions

Decisions needed from the project's owner, each with a recommendation.
Answers go into `bugs.md` or `plan.md` as they are made.

## Bugs whose fix needs a choice

These are definite bugs (`bugs.md`, "Fix"), but more than one fix is possible.

1. ~~A monster emerging from a trapdoor tests a stale cell.~~ Fixed
   (2026-11-08): a trapdoor a hero in play stands on stays shut; monsters
   may emerge onto each other, which keeps the start of a level as it was.
   Trapdoors are also now drawn first in each frame. See `bugs.md`.

2. ~~Each hero who leaves by the exit leaks a return address.~~ Fixed
   (2026-11-08): the descent is entered with JMP. See `bugs.md`.

3. ~~A hero standing on a key swaps keys every other frame.~~ Fixed
   (2026-11-08): one swap on arrival, which the 1987 instructions describe
   ("the key lying on the floor is picked up, and the original key being
   carried is dropped in its place"). See `bugs.md`.

4. ~~A key dropped at the exit can land in a wall.~~ Fixed (2026-11-08):
   all four neighbouring cells are tested for walls and keys; with none
   free, the key is lost off the map. See `bugs.md`.

5. ~~Teleport landings aren't checked.~~ Not a bug (2026-11-08): the
   levels depend on it. See `bugs.md` and `behaviours.md`.

## Behaviours to rule on

All ruled on (2026-11-08). Fixed: a missile stopping at a skull, a Cross
wasted with nobody waiting, a caster killed by the cost still casting, the
free point at each level, and a potion giving 00. Kept: the other seven.
See `bugs.md`, "Fix" and "Kept".

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
