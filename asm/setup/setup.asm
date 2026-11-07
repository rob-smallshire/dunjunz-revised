; ***************************************************************************************
; Set up a level
;
; The Setup file, loaded with each level into screen memory at SETUP_ADDRESS while the
; display is blanked, and run there by start_level before the screen is cleared and the
; level drawn: copy the level file into the game's tables, put the workspace back to its
; starting values, and send the monsters to their trapdoors. None of this is needed in
; play, so it is not kept in memory between levels.
.setup_level
    jsr unpack_level                    ; Copy its objects, doors, keys and maps into play
    jsr reset_workspace                 ; Put the heroes, missiles and views back to the start
    jmp reset_monsters                  ; Monsters to the trapdoors; heroes carry no keys
; ***************************************************************************************
; Reset the game workspace for a new level
;
; Put the heroes, missiles and views back where every level starts. Called by start_level
; once a level, after unpack_level and before reset_monsters. Copy the 256 bytes of
; workspace_template (&7D00) over page &0D, the per-level workspace, then reset the exit
; animation's state, which lives in page &09: no hero going down the exit (exit_busy 0)
; or left shrunk (shrunk_hero &FF), the shrinking hero's pixel offsets (x 1, 1, 0, 0 and
; y 5, 3, 1, 0 for exit_shrinks_left 1-4), and trapdoor 0 as the next one a monster comes
; out of (next_trapdoor). Nothing here touches the heroes' health or scores, which carry
; over from level to level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
.reset_workspace
    ldx #0                              ; Copy workspace_template to page &0D
.copy_workspace_template
    lda workspace_template,x            ; Byte of the starting values...
    sta scratch,x                       ; ...becomes page &0D's byte
    inx                                 ; Next of page &0D's 256 bytes
    bne copy_workspace_template         ; Until all 256 are copied: heroes back at the start
    lda #0                              ; Reset the exit animation and the trapdoor turn
    sta exit_busy                       ; No hero is going down the exit
    sta exit_offset_x_3                 ; Shrinking hero's x offset at shrink 3: 0...
    sta exit_offsets_y                  ; ...at shrink 4 (exit_offsets_y doubles as x 4)...
    sta exit_offset_y_4                 ; ...and the y offset at shrink 4
    sta next_trapdoor                   ; First monster emerges from trapdoor 0
    lda #1                              ; Offsets of 1 for the exit animation
    sta exit_offset_x_1                 ; ...x offset at shrink 1...
    sta exit_offset_x_2                 ; ...x offset at shrink 2...
    sta exit_offset_y_3                 ; ...and y offset at shrink 3
    lda #&ff                            ; &FF: no hero is shrunk
    sta shrunk_hero                     ; ...so no hero's sprites need restoring
    lda #5                              ; Shrinking hero's y offset at shrink 1: 5...
    sta exit_offset_y_1                 ; ...for y offset 1
    lda #3                              ; ...and at shrink 2: 3
    sta exit_offset_y_2                 ; ...for y offset 2
    rts                                 ; Return to start_level
; ***************************************************************************************
; Copy the loaded level into the game's tables
;
; Bring the level just loaded into play. Called by start_level once the level file at
; &6B00 has been decrypted and checked, before reset_workspace. Copy objects 1-30
; (position and type; the type is also the sprite), doors 1-20 (position and sprite),
; keys 1-20, trapdoors 0-7, &C9 bytes each of the wall map (into room_walls, read by
; test_wall) and object-free map (into object_free_map, read by test_object_free), and
; the level's 4 x 12 wall block into wall_sprite, sprite 0, the wall in every room. Entry
; 0 of the object, door and key tables is not touched. room_walls is also character 128's
; definition, which the game's text output overwrites, so this must follow the printing
; of the level number. The file itself lies in screen rows 23-24 and is wiped by
; start_level's clear_text_area once unpacked.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
.unpack_level
    ldx #max_object                     ; Objects 30 to 1: position and type
.unpack_objects
    lda level_object_x,x                ; Object's x in the level file...
    sta object_x,x                      ; ...becomes its map x
    lda level_object_y,x                ; The object's y in the file...
    sta object_y,x                      ; ...becomes its map y
    lda level_object_type,x             ; Its type, which is also its sprite...
    sta object_type,x                   ; ...becomes its object type
    dex                                 ; Next object down
    bne unpack_objects                  ; Until object 1 is done (entry 0 is unused)
    ldx #max_door                       ; Doors 20 to 1: position and sprite
.unpack_doors
    lda level_door_x,x                  ; Door's x in the level file...
    sta door_x,x                        ; ...becomes its map x
    lda level_door_y,x                  ; The door's y in the file...
    sta door_y,x                        ; ...becomes its map y
    lda level_door_sprite,x             ; Its sprite, upright or across...
    sta door_sprite,x                   ; ...becomes its sprite
    dex                                 ; Next door down
    bne unpack_doors                    ; Until door 1 is done
    ldx #max_key                        ; Keys 20 to 1: position
.unpack_keys
    lda level_key_x,x                   ; Key's x in the level file...
    sta key_x,x                         ; ...becomes its map x
    lda level_key_y,x                   ; The key's y in the file...
    sta key_y,x                         ; ...becomes its map y
    dex                                 ; Next key down
    bne unpack_keys                     ; Until key 1 is done
    ldx #0                              ; Trapdoors 0 to 7: where dead monsters come back
.unpack_trapdoors
    lda level_trapdoor_x,x              ; Trapdoor's x in the level file...
    sta trapdoor_x,x                    ; ...becomes its map x
    lda level_trapdoor_y,x              ; The trapdoor's y in the file...
    sta trapdoor_y,x                    ; ...becomes its map y
    inx                                 ; Next trapdoor up, 0 to 7
    cpx #8                              ; All eight done?
    bne unpack_trapdoors                ; No: copy the next
    ldx #0                              ; Wall map and object-free map, &C9 bytes each
.unpack_walls
    lda level_walls,x                   ; Byte of the level's wall map...
    sta room_walls,x                    ; ...into room_walls, which test_wall reads
    lda level_object_free_map,x         ; Byte of the level's object-free map...
    sta object_free_map,x               ; ...into object_free_map, which test_object_free reads
    inx                                 ; Next byte of both maps
    cpx #map_bytes                      ; Both maps copied?
    bne unpack_walls                    ; No: copy the next
    ldx #0                              ; The level's own wall block, &30 bytes
.unpack_wall_sprite
    lda level_wall_sprite,x             ; Byte of the level's wall block...
    sta wall_sprite,x                   ; ...becomes sprite 0, the wall in every room
    inx                                 ; Next byte of the wall block
    cpx #&30 ; '0'                      ; All 4 x 12 bytes copied?
    bne unpack_wall_sprite              ; No: copy the next
    rts                                 ; Return to start_level with the level unpacked
; ***************************************************************************************
; Clear the monsters for a new level
;
; Start every monster dead and every hero empty-handed. Called by start_level after
; reset_workspace. Give monsters 1-30 the blank sprite (the first stage of dying) and an
; x off the map, so update_monsters brings each out of a trapdoor in turn, with
; monster_start_hit_points, the hit points level_loop set for this level. Then, for each
; of the four heroes, clear their returning_hero_queue entry, the key they carry
; (hero_key) and the swap flag (hero_key_dropped), and the cell kept for the door and
; Chalice checks (hero_door_x, hero_door_y), so nothing from the last level opens a door
; or wins the game. remove_absent_heroes refills the queue later for heroes nobody plays.
;
; On Exit:
;     A: 0
;     X: 4
;     Y: preserved
.reset_monsters
    ldx #max_monster                    ; Monsters 30 to 1...
.reset_each_monster
    lda #spr_blank                      ; ...dying, so that they emerge from the trapdoors...
    sta monster_sprite,x                ; ...as monster X's sprite...
    lda #off_map                        ; ...off the map...
    sta monster_x,x                     ; ...as monster X's x...
    lda monster_start_hit_points        ; ...with this level's hit points
    sta monster_hit_points,x            ; ...as monster X's hit points
    dex                                 ; Next monster down
    bne reset_each_monster              ; Until monster 1 is done
    ldx #0                              ; Each hero: clear queue place, key carried, door cell
    lda #0                              ; Zero for every entry cleared
.clear_hero_carrying
    sta returning_hero_queue,x          ; Queue entry X empty: nobody waits to return
    sta hero_key,x                      ; Hero X carries no key
    sta hero_key_dropped,x              ; ...and has swapped none
    sta hero_door_x,x                   ; No door-check cell...
    sta hero_door_y,x                   ; ...in x or y
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four done?
    bne clear_hero_carrying             ; No: clear the next
    rts                                 ; Return to start_level, monsters and heroes reset
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
