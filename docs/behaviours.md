# How the game behaves

Behaviours of the 1987 game, kept in Dunjunz Revised, that are worth
knowing when playing it, changing it or designing levels. The
disassembly's `docs/findings.md` (`~/Code/acornaeology/dunjunz`) has the
code-level detail; this file is about play.

## Teleporters

- **Where they lead.** A teleporter sends the hero to the previous
  teleporter in the level's object list; the first leads to the last, and a
  level's only teleporter leads to itself.
- **Where the hero lands.** On the cell directly above the destination,
  whatever is there. Nothing is checked: walls, closed doors, objects, keys,
  monsters and other heroes are all landed on. The hero is put above the
  destination, not on it, so as not to be sent straight back.
- **Inside a wall or door.** A move tests only the cell being entered, so a
  hero standing inside a wall or closed door can walk out of it.
- **What happens on arrival.** Objects are collected every frame for every
  hero in play, moved or not, so a hero landing on an object takes it on
  the next frame: treasure is scored, and an energy drainer takes 10 health
  every frame the hero stays on it. A key landed on is picked up (or
  swapped) on the next frame. A hero landing on the exit leaves the level.

Teleporters are on levels 5, 6, 9, 11, 12, 13, 14, 15, 16, 18, 22, 23 and
25. The landings that are not on open floor:

| Level | Teleporter (object, cell) | Above it | What it means in play |
|---|---|---|---|
| 5 | 22 at 4,25 | Energy drainer | Arriving costs health until the hero moves off |
| 6 | 3 at 2,44 | Closed door | The hero lands inside the door. Stepping back down onto teleporter 3 leads on to a teleporter whose landing is the exit (12,27): a shortcut to the exit. Teleporter 10, open only towards the exit cell, is practically unreachable |
| 11 | 9 (reached from 24) | Key at 9,20 | Picked up on arrival |
| 12 | 2 at 19,46 | Closed door | The destination is walled in behind the door; the hero lands inside the door and walks out into the room |
| 13 | 8 (reached from 20) | Key at 1,9 | Picked up on arrival |
| 15 | 28 at 28,42 | Energy drainer | The level's only teleporter leads to itself, so it drops the hero onto the drainer |
| 16 | 16 at 27,19 | Treasure | Taken on arrival |

## Keys and doors

- A hero carries one key at a time. Walking onto a key swaps it for the
  one carried, once, on arrival (fixed in the revision; the 1987 game
  swapped back and forth while the hero stood there).
- Keys lie under heroes' starting cells on several levels: level 1 (key 4
  under the Ranger, key 3 under the Fighter), 4 (three heroes), 11
  (Barbarian, Fighter), 14 (Ranger) and 22 (all four). They are picked up
  on the first frame.
- A hero leaving by the exit drops their key on the first free cell beside
  it (above, right, below, left); with none free it is lost.

## Trapdoors

- Killed monsters reappear at the level's eight trapdoors in turn. All 30
  monsters emerge at the start of a level, several to a trapdoor.
- In the revision a trapdoor a hero in play stands on stays shut, and the
  monster tries the next one on the next frame.
