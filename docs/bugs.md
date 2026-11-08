# Bug triage

The behaviours found in the disassembly
(`~/Code/acornaeology/dunjunz/docs/findings.md`) that bear on the Model B
disc version, sorted into four groups. **Fix** means it is a bug, fixed
or to be fixed. **Kept** means it could be a bug or the game as designed,
and we decided to keep it, because fixing it would change how the game
plays. **Not a bug** means it looked like one but is kept, because the
levels or the play depend on it. **Moot** means the revision's design
removes it.

Each fix gets an emulator test that shows the bug in the baseline
(`build/dunjunz-original.ssd`) and its absence in the revised game.

## Fix

Those not yet marked fixed need a choice of how the game should behave, and are
settled with the project's owner first.

| Behaviour | Where | Note |
|---|---|---|
| A monster emerging from a trapdoor tests a stale cell (`cell_x`/`cell_y`) for occupants, so it lands on creatures, hurts a hero standing elsewhere, or is parked off the map for good | `monster_reappears` &7CB3 | Confirmed in beebium. **Fixed**: a trapdoor a hero in play stands on stays shut, and the monster tries the next one on the next frame; no hero is hurt; monsters may still emerge onto each other, so all 30 still emerge at the start; `test_a_trapdoor_a_hero_stands_on_stays_shut` |
| Casting magic returns from `move_heroes`, so heroes after the caster don't move for three frames | &761E | **Fixed**; `test_magic_does_not_stop_the_other_heroes` |
| Each hero who leaves by the exit leaves a return address on the stack, adding a frame to the level's end | `check_exit` | **Fixed**: check_exit jumps to hero_enters_exit; `test_leaving_by_the_exit_leaves_nothing_on_the_stack` |
| Game over waits for the vsync counter to reach exactly 0, up to about 5 s with the keys ignored | &0EB9 | **Fixed**; `test_game_over_wait_is_short` |
| A P still held after unpausing pauses again | pause | **Fixed**; `test_p_held_after_unpausing_does_not_pause_again` |
| Pause is missed while a lower-numbered key is held (OSBYTE &7A) | pause | **Fixed** with `test_key`; `test_pause_is_seen_while_a_lower_numbered_key_is_held` |
| "YOU ALL" loses its full stop: the message's bytes double as counters | &0FF1 | **Fixed**: the counters have bytes of their own |
| The victory bell is set with a stale Y | &10E9, &1124 | **Fixed** (untested: needs the victory sequence) |
| A hero standing on a key swaps keys every other frame (dying heroes too) | &1E84-&1E9C, &1DF8 | **Fixed**: one swap on arrival, as the instructions describe; `hero_key_dropped` holds the key dropped until the hero is off it, and draw_keys leaves that key undrawn meanwhile, or it would flicker over the hero; `test_standing_on_a_key_swaps_once`, `test_a_dropped_key_is_not_drawn_over_the_hero`. The comparisons stop at the original's first key-for-key swap |
| Trapdoors are redrawn after the heroes and missiles, so a hero or missile on one flickers with it | `update_monsters` &79C1 | **Fixed**: `draw_trapdoors` runs first in each frame; `test_a_hero_on_a_trapdoor_is_drawn_over_it`. The screen comparisons leave out the trapdoors' cells |
| A key dropped at the exit can land in a wall: the fallback cell is not tested | &20F7 | **Fixed**: all four neighbours are tested for walls and keys; with none free the key is lost (off the map); `test_a_key_dropped_at_the_exit_avoids_other_keys`, `test_a_key_with_nowhere_to_go_is_lost_not_put_in_a_wall` |
| A monster killed this frame can be hit again by another missile, scoring twice | &7147 | **Fixed** (untested) |
| A monster killed by magic comes back with the hit points it had left | &768A | **Fixed** (untested) |
| The hero menu's sound ON/OFF shows the last choice made, not the setting in force | menu | **Fixed**: shows the setting in force; `test_menu_shows_the_sound_off` |
| The ten-thousands score digit is lost at each new level | &040F | **Fixed**: one table |
| A missile stops at a dead hero's skull | &71DD | Ruled a bug (2026-11-08). **Fixed**: a hero out of play (a skull, or a hero dying or returning) lets a missile through; `test_a_missile_flies_through_a_skull`. The comparisons stop where the original stops a missile at a skull |
| A Cross of Resurrection is used up, and scores 10, when nobody is waiting | &7411 | Ruled a bug (2026-11-08). **Fixed**: with nobody waiting, the Cross stays where it is; it is taken, and scores, only when it brings a hero back; `test_a_cross_with_nobody_to_bring_back_stays`. The comparisons stop where the original wastes a Cross |
| A caster killed by magic's cost still kills the room's monsters and scores | &7652 | Ruled a bug (2026-11-08). **Fixed**: a caster the cost kills casts nothing; `test_a_caster_killed_by_the_cost_casts_nothing` |
| Survivors gain a free point at every new level (`draw_status_panel` draws scores with `add_point`) | &0F02 | Ruled a bug (2026-11-08). **Fixed**: the panel draws the score with `draw_score`, and a reset score is 0000; `test_a_survivor_keeps_their_score_at_the_next_level`. The level comparison gives the revised survivors the 1987 point |
| A Potion of Healing sets health from the score's units digit, so it can give 00 | &7503 | Ruled a bug (2026-11-08) in the 0 case only: the digit-twice health (11 to 99) is the potion's design. **Fixed**: a 0 counts as 1, so health 11; `test_a_potion_never_leaves_00_health`. The comparisons stop where the original's potion leaves 00 |

## Kept

Each of these could be a bug or the game as designed. We decided
(2026-11-08) to keep them all, because fixing any of them changes how the
game plays.

| Behaviour | Where | Why it stays |
|---|---|---|
| A monster on exactly 0 hit points survives (`BPL`): Ranger arrows take five hits on level 1, not four | &7594 | Probably an off-by-one, but the game was balanced and released with it |
| A missile bounced by an energy drainer can hit its firer | &71A5 | A fair hazard of shooting drainers |
| Finding any object, even a teleporter or the exit, takes off the Boots of Speed | &734D | Boots that wear out may be intended; removing them only on pickups was considered and not taken |
| Walking into a monster costs one point whatever the armour; dying monsters still block | &6FFC | A simple rule; the blocking lasts only a few frames |
| Monsters cross room boundaries two cells in two frames | `continue_monster_step` | Part of how monsters move; it shapes how the game feels |
| All 30 monsters emerge together at the start of a level; stacked monsters slide out together | `reset_monsters` | The opening rush, in every level |
| A refused move still turns the hero | &6ECB | How a hero aims without stepping |

## Not a bug

| Behaviour | Why it stays |
|---|---|
| Teleport landings are not checked for walls, doors, objects, keys or creatures (&73EA-&73F9) | The levels use it: landings inside closed doors (levels 6 and 12), a shortcut to the exit (level 6), arrivals on drainers, treasure and keys. Decided 2026-11-08. See `behaviours.md` |

## Moot

| Behaviour | Why |
|---|---|
| The machine is reset between levels, through MOS 1.20's &D9CD and the BREAK intercept | The game stays resident |
| The level checksum resets the machine (&D9CD) | Levels are no longer encrypted or checksummed |
| The joystick BYTEV handler falls through to &E772, and ADC channel 1 is read twice | Joystick support is left out for now (`plan.md`, milestone 6) |
| The WRCHV handler jumps to &E0A4, not the saved vector | Chain to the saved vector |
| `screen_address` reads the MOS 1.20 row table at &C375 | The game carries its own table |
| Character 128's definition is assumed to be at &0C00 | Define it with VDU 23 |
| The pause stall after a long pause (crack and hack only) | The disc version resets the counter already |
| The level 5 checksum (sideways RAM hack only) | |
