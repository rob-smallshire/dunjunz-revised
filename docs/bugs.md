# Bug triage

The behaviours found in the disassembly
(`~/Code/acornaeology/dunjunz/docs/findings.md`) that bear on the Model B
disc version, sorted into three groups. **Fix** means we are sure it is
a bug. **Rule** means it changes how the game plays, so it waits for a
decision. **Moot** means the revision's design removes it.

Each fix gets an emulator test that shows the bug in the baseline
(`build/dunjunz-original.ssd`) and its absence in the revised game.

## Fix

| Behaviour | Where | Note |
|---|---|---|
| A monster emerging from a trapdoor tests a stale cell (`cell_x`/`cell_y`) for occupants, so it lands on creatures, hurts a hero standing elsewhere, or is parked off the map for good | `monster_reappears` &7CB3 | Confirmed in beebium |
| Casting magic returns from `move_heroes`, so heroes after the caster don't move for three frames | &761E | Confirmed in beebium |
| Each hero who leaves by the exit leaves a return address on the stack, adding a frame to the level's end | `check_exit` | A stack leak |
| Game over waits for the vsync counter to reach exactly 0, up to about 5 s with the keys ignored | &0EB9 | Confirmed in beebium |
| A P still held after unpausing pauses again | pause | Confirmed in beebium |
| Pause is missed while a lower-numbered key is held (OSBYTE &7A) | pause | Test P directly |
| "YOU ALL" loses its full stop: the message's bytes double as counters | &0FF1 | |
| The victory bell is set with a stale Y | &10E9, &1124 | |
| A hero standing on a key swaps keys every other frame (dying heroes too) | &1E84-&1E9C, &1DF8 | |
| A key dropped at the exit can land in a wall: the fallback cell is not tested | &20F7 | |
| A monster killed this frame can be hit again by another missile, scoring twice | &7147 | |
| A monster killed by magic comes back with the hit points it had left | &768A | |
| Teleport landings are not checked for walls, monsters or heroes | &73EA-&73F9 | |
| The hero menu's sound ON/OFF shows the last choice made, not the setting in force | menu | Keeping the YES/NO choices between games is worth keeping; only the mismatch is a bug |
| The ten-thousands score digit is lost at each new level | &040F | Moot once the game is resident, but use one table |

## Rule

Each of these could be a bug or the game as designed. Fixing any of them
changes how the game plays.

| Behaviour | Where |
|---|---|
| A monster on exactly 0 hit points survives (`BPL`): Ranger arrows take five hits on level 1, not four | &7594 |
| Survivors gain a free point at every new level (`draw_status_panel` draws scores with `add_point`) | &0F02 |
| A missile stops at a dead hero's skull | &71DD |
| A missile bounced by an energy drainer can hit its firer | &71A5 |
| Finding any object, even a teleporter or the exit, takes off the Boots of Speed | &734D |
| A Potion of Healing sets health from the score's units digit, so it can give 00 | &7503 |
| A Cross of Resurrection is used up, and scores 10, when nobody is waiting | &7411 |
| A caster killed by magic's cost still kills the room's monsters and scores | &7652 |
| Walking into a monster costs one point whatever the armour; dying monsters still block | &6FFC |
| Monsters cross room boundaries two cells in two frames | `continue_monster_step` |
| All 30 monsters emerge together at the start of a level; stacked monsters slide out together | `reset_monsters` |
| A refused move still turns the hero | &6ECB |

## Moot

| Behaviour | Why |
|---|---|
| The machine is reset between levels, through MOS 1.20's &D9CD and the BREAK intercept | The game stays resident |
| The level checksum resets the machine (&D9CD) | Levels are no longer encrypted or checksummed |
| The joystick BYTEV handler falls through to &E772, and ADC channel 1 is read twice | Replaced by an ADVAL-based driver |
| The WRCHV handler jumps to &E0A4, not the saved vector | Chain to the saved vector |
| `screen_address` reads the MOS 1.20 row table at &C375 | The game carries its own table |
| Character 128's definition is assumed to be at &0C00 | Define it with VDU 23 |
| The pause stall after a long pause (crack and hack only) | The disc version resets the counter already |
| The level 5 checksum (sideways RAM hack only) | |
