; Map x of each monster (entries 1-30; entry 0 unused). During a step it stays the cell the monster is leaving until the step ends, so find_creature, the missiles and the magic all meet the monster there. &FF (off_map) after reset_monsters, and for a monster monster_reappears has parked. Written by update_monsters, continue_monster_step and monster_reappears.
.monster_x
    equb &00, &04, &0b, &09, &1d, &08, &01, &06, &07, &0a, &01, &0b, &1a, &06, &0b, &16  ; Not read: reset_monsters and the trapdoors set the monsters
    equb &15, &0d, &1b, &14, &1a, &09, &1c, &0f, &1e, &02, &1a, &0b, &1c, &0e, &16, &00  ; ...entries 16-31, not read
    equb &00, &00, &00, &1a, &00, &00, &00, &00, &00  ; ...entries 32-40, not read
; Map y of each monster, kept like monster_x.
.monster_y
    equb &00, &24, &17, &25, &20, &24, &22, &14, &27, &0d, &20, &01, &26, &0a, &01, &12  ; Not read: reset_monsters and the trapdoors set the monsters
    equb &05, &20, &29, &0d, &26, &27, &08, &06, &1a, &14, &03, &1d, &07, &0d, &17, &00  ; ...entries 16-31, not read
    equb &00, &00, &00, &1b, &00, &00, &00, &00, &00  ; ...entries 32-40, not read
; Each monster's state as a sprite number: 9, &0B, &0D or &0F facing up, right, down or left; &15 (the blank) when just killed, then &16-&19, the sparkles of its death, one a frame. It reaches &1A only for the moment before monster_reappears resets it to 9.
.monster_sprite
    equb &00, &09, &0d, &0b, &0b, &0b, &09, &0f
    equb &0f, &0b, &0d, &0b, &0b, &0f, &0d, &0d
    equb &09, &0f, &0b, &0f, &0b, &0b, &0f, &09
    equb &0d, &0f, &0b, &09, &0d, &0b, &09, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; Each monster's animation frame (0 or 1), added to its facing sprite; toggled on each frame of a step.
.monster_frame
    equb &00, &00, &01, &00, &00, &01, &01, &00
    equb &01, &01, &00, &01, &01, &01, &00, &01
    equb &00, &01, &00, &01, &01, &00, &00, &01
    equb &01, &00, &00, &00, &01, &01, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; How far each monster is drawn across from its cell during a step, in byte columns: 0, or +/-1 to 3.
.monster_offset_x
    equb &00, &00, &00, &02, &02, &02, &00, &fd
    equb &fe, &01, &00, &02, &03, &00, &00, &00
    equb &00, &fe, &00, &00, &01, &00, &00, &00
    equb &00, &00, &03, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; How far each monster is drawn down from its cell during a step, in pixel rows: 0, or +/-3, 6 or 9.
.monster_offset_y
    equb &00, &fd, &00, &00, &00, &00, &fa, &00
    equb &00, &00, &03, &00, &00, &00, &06, &03
    equb &fd, &00, &00, &00, &00, &00, &00, &00
    equb &06, &00, &00, &f7, &00, &00, &f7, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; Frames left in each monster's step between cells: 3 when the step starts, counted down by continue_monster_step, 0 when the monster is not stepping. Not looked at while a monster is dying; monster_reappears clears it.
.monster_step
    equb &00, &03, &00, &02, &02, &02, &02, &01
    equb &02, &03, &03, &02, &01, &00, &02, &03
    equb &03, &02, &00, &00, &03, &00, &00, &00
    equb &02, &00, &01, &01, &00, &00, &01, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00
; Map x of each object on the level (entries 1-30), from the level file; &FF once collected. Entry 30 is the exit.
.object_x
    equb &00, &ff, &ff, &ff, &ff, &ff, &18, &04, &04, &05, &ff, &ff, &ff, &ff, &ff, &ff  ; Not read: unpack_level copies each level's objects here
    equb &ff, &ff, &ff, &ff, &ff, &01, &07, &04, &04, &ff, &ff, &ff, &ff, &ff  ; ...entries 16-29, not read
; Map x of the exit (object 30).
.exit_x
    equb &04                            ; ...the exit's entry
; Map y of each object.
.object_y
    equb &00, &ff, &ff, &ff, &ff, &ff, &15, &18, &19, &19, &ff, &ff, &ff, &ff, &ff, &ff  ; Not read: unpack_level copies each level's objects here
    equb &ff, &ff, &ff, &ff, &ff, &2a, &2a, &2b, &2e, &ff, &ff, &ff, &ff, &ff  ; ...entries 16-29, not read
; Map y of the exit (object 30).
.exit_y
    equb &2c                            ; ...the exit's entry
; Each object's type, which is also its sprite: &28 treasure, &29 food, &2A Cross of Resurrection, &2B teleporter, &51 exit, &53-&5E energy drainer (advancing with each hit), &5F Boots of Speed, &60 magic helmet, &61 potion of healing, &62 pile of weapons, &63 magic sword.
.object_type
    equb &00, &5f, &5f, &5f, &29, &63, &5f, &53, &2b, &53, &28, &28, &60, &60, &28, &2a  ; Not read: unpack_level copies each level's objects here
    equb &62, &28, &28, &29, &28, &2b, &2b, &2b, &2b, &29, &28, &28, &29, &28  ; ...entries 16-29, not read
    equb &51                            ; ...the exit's entry
