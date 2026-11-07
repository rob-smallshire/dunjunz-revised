; ***************************************************************************************
; Workspace template
;
; The starting contents of page &0D, the heroes' and missiles' workspace, which
; reset_workspace copies there whole at the start of every level. Byte +n becomes &0D00 +
; n. It sets the heroes in the four cells of the start, facing four ways and not
; stepping; every missile slot empty; each hero's direction and fire keys (hero_key_up
; etc. at +&70, as negative INKEY numbers for test_key); health digits 9 and 9 + 1 (+&90,
; +&95), which read 99 once draw_status_panel has taken a point; every view on the start
; room (+&A0); the heroes' and missiles' sprite bases (+&B0, +&B5); the bit masks
; test_wall and test_object_free use (+&C0); and the panel rows (+&D0). The bytes between
; variables are copied with the rest.
.workspace_template
    equb &00                            ; scratch: working byte
    equb &00                            ; scratch2: working byte
    equb &1f                            ; cell_x: set before use
    equb &1f                            ; cell_y: set before use
    equb &d2                            ; cell_room: set before use
    equb &d2                            ; Copied to &0D05: no variable starts here
    equb &cc                            ; previous_x: set before use
    equb &b1                            ; previous_y: set before use
    equb &07                            ; previous_offset_x: set before use
    equb &07                            ; previous_offset_y: set before use
    equb &01, &01, &00, &2c, &34, &3c   ; Copied to &0D0A: no variable starts here
    equb &0b, &0b, &0c, &0c             ; hero_x: the heroes start at x 11, 11, 12, 12...
    equb &2f                            ; Copied to &0D14: no variable starts here
    equb &0b, &0c, &0b, &0c             ; hero_y: ...and y 11, 12, 11, 12, the four cells of the start
    equb &26                            ; Copied to &0D19: no variable starts here
    equb &01, &03, &05, &07             ; hero_direction: facing up, right, down and left
    equb &2d, &2f                       ; Copied to &0D1E: no variable starts here
    equb &01, &01, &01, &01             ; hero_frame: walking frame 1 for every hero
    equb &5d                            ; Copied to &0D24: no variable starts here
    equb &00, &00, &00, &00             ; hero_step: not stepping
    equb &16                            ; Copied to &0D29: no variable starts here
    equb &00, &00, &00, &00             ; hero_offset_x: no offset
    equb &1d, &1f                       ; Copied to &0D2E: no variable starts here
    equb &00, &00, &00, &00             ; hero_offset_y: no offset
    equb &03, &05, &07, &05, &07, &36, &35, &37
    equb &3c, &3e, &3d, &3f             ; Copied to &0D34: no variable starts here
    equb &01, &82, &81, &83, &88, &8a, &89, &8b
    equb &84, &86, &85, &87             ; missile_x: unused while the slots are empty
    equb &8c, &8e, &8d, &8f, &08, &48, &8a, &48
    equb &98, &48, &ae, &ff             ; missile_y: unused while the slots are empty
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00             ; missile_direction: every slot empty
    equb &15, &85, &7a, &8a, &48, &20, &00, &09
    equb &68, &aa, &bd, &08             ; missile_sprite_base: set when a missile is fired
    equb inkey_key_caps_lock, inkey_key_right, inkey_key_k, inkey_key_g  ; hero_key_up: heroes 0-3, read through test_key
    equb inkey_key_shift_lock, inkey_key_up, inkey_key_comma, inkey_key_b  ; hero_key_down: likewise, one per hero
    equb inkey_key_z, inkey_key_copy, inkey_key_slash, inkey_key_i  ; hero_key_right: likewise
    equb inkey_key_shift, inkey_key_delete, inkey_key_full_stop, inkey_key_u  ; hero_key_left: likewise
    equb inkey_key_tab, inkey_key_down, inkey_key_space, inkey_key_o  ; hero_key_fire: likewise
    equb &0d, &c9, &05, &d0, &09, &18, &bd, &04
    equb &0d, &69, &03, &9d             ; Copied to &0D84: no variable starts here
    equb spr_digit_9, spr_digit_9, spr_digit_9, spr_digit_9  ; hero_health_tens: the 9 digit sprite...
    equb &d0                            ; Copied to &0D94: no variable starts here
    equb spr_digit_9 + 1, spr_digit_9 + 1, spr_digit_9 + 1, spr_digit_9 + 1  ; hero_health_units: ...9 + 1: health 99 once a point is taken
    equb &18, &bd, &08, &0d, &6d, &40, &0d  ; Copied to &0D99: no variable starts here
    equb <(room_walls + &28), >(room_walls + &28), <(room_walls + &28), >(room_walls + &28), <(room_walls + &28), >(room_walls + &28), <(room_walls + &28), >(room_walls + &28)  ; view_room: every view starts on the heroes' room, &0C28
    equb &00, &00, &bd, &04, &0d, &85, &71, &8a  ; Copied to &0DA8: no variable starts here
    equb spr_arrow_up - 1, spr_fireball_up - 1, spr_axe_up - 1, spr_sword_up - 1  ; hero_missile_sprites: arrows, fireballs, axes, swords
    equb &68                            ; Copied to &0DB4: no variable starts here
    equb spr_ranger_up_0 - 1, spr_magic_user_up_0 - 1, spr_barbarian_up_0 - 1, spr_fighter_up_0 - 1  ; hero_sprites: Ranger, Magic-User, Barbarian, Fighter
    equb &00, &0d, &d9                  ; Copied to &0DB9: no variable starts here
    equb &00, &00, &00, &00             ; hero_has_boots: none
    equb &80, &40, &20, &10, &08, &04, &02, &01  ; bit_masks: &80 down to &01
    equb &b9, &30, &0d, &9d, &08, &0d, &4c, &d4  ; Copied to &0DC8: no variable starts here
    equb &18, &46, &74, &a2             ; hero_panel_y: the four sections of the status panel
    equb &e8, &e0, &04, &d0, &0a, &a2, &00, &ad
    equb &40, &0d, &49, &01, &8d, &40, &0d, &8e
    equb &ff, &0d, &68, &a8, &68, &aa, &68, &28
    equb &60, &de, &dd, &df, &f0, &f2, &f1, &f3
    equb &f8, &fa, &f9, &fb, &f4, &f6, &f5, &f7
    equb &fc                            ; Copied to &0DD4: no variable starts here
    equb &1e                            ; teleport_last: object &1E, the last
    equb &fd                            ; Copied to &0DFE: no variable starts here
    equb &00                            ; victory_sprite_copy: set before use
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
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00                       ; Not referenced
