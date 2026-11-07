; ***************************************************************************************
; Test whether a key is pressed
;
; Report whether one key is held down at this moment. read_hero_keys calls it for each
; hero's direction and fire keys, from the hero_key tables, and check_magic for the
; Ranger's and Magic-User's magic keys. The key is scanned with OSBYTE &81 and a negative
; INKEY number (Y = &FF), which returns X = Y = &FF if it is held; the caller's X, the
; hero number, is kept on the stack across the call.
;
; On Entry:
;     A: INKEY key number (negative, as a byte)
;
; On Exit:
;     A: 0 if the key is pressed, 1 if not
;     Z: set if the key is pressed
;     X: preserved
;     Y: corrupted
.test_key
    tay                                 ; Park the INKEY number in Y for a moment
    txa                                 ; Keep the caller's X (the hero number)...
    pha                                 ; ...on the stack, as OSBYTE returns in X
    tya                                 ; The INKEY number...
    tax                                 ; ...in X, as OSBYTE &81 wants it
    lda #osbyte_inkey                   ; OSBYTE &81 with Y = &FF: scan the key
    ldy #&ff                            ; Y = &FF: scan the one key, not wait
    jsr osbyte                          ; Scan it: X = Y = &FF if the key is held.  Test whether the key with negative INKEY number X is pressed
    cpy #&ff                            ; Held only if both Y and X come back &FF
    bne key_not_pressed                 ; Y not &FF: the key is up
    cpx #&ff                            ; X = &FF too?
    bne key_not_pressed                 ; No: the key is up
    pla                                 ; Held: the caller's X back from the stack...
    tax                                 ; ...the hero number again
    lda #0                              ; A = 0, Z set: the key is held
    rts                                 ; Return with Z set: the key is held
.key_not_pressed
    pla                                 ; Up: the caller's X back from the stack...
    tax                                 ; ...the hero number again
    lda #1                              ; A = 1, Z clear: the key is up
    rts                                 ; Return with Z clear: the key is up
; The monster comes back facing up on the next trapdoor in turn, with the hit points the kill gave it back. It is not drawn until next frame. The creature test that follows reads cell_x and cell_y, which still hold the dying monster's position within its view, as the erase's plot_at_cell left them, not the trapdoor's cell. So a creature already on the trapdoor does not stop the monster emerging; one that happens to stand at the unrelated cell the leftovers name parks the monster at &FF,&FF, still alive, where nothing returns it to a trapdoor (and a hero there is hurt).
.monster_reappears
    inc next_trapdoor                   ; Each reappearance uses the next trapdoor in turn
    lda next_trapdoor                   ; Which trapdoor now?
    cmp #8                              ; Past the eighth (7)?
    bne emerge_at_trapdoor              ; No: emerge there
    lda #0                              ; Yes: wrap round to trapdoor 0...
    sta next_trapdoor                   ; ...for this monster and the next
.emerge_at_trapdoor
    ldy next_trapdoor                   ; Y = the trapdoor to emerge from
    lda trapdoor_x,y                    ; Put the monster on it, facing up, with no step
    sta monster_x,x                     ; ...the trapdoor's x as the monster's
    lda trapdoor_y,y                    ; The trapdoor's y...
    sta monster_y,x                     ; ...as the monster's
    lda #spr_monster_up_0               ; Facing up (sprite 9)...
    sta monster_sprite,x                ; ...ends the death: alive again, drawn next frame
    lda #0                              ; No step under way:
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    txa                                 ; Test for a creature at cell_x, cell_y...
    pha                                 ; ...stacking the number for monster_done
    stx scratch                         ; Non-zero scratch: skip this monster, check heroes
    jsr find_creature                   ; cell_x/y: plot_at_cell's leftovers, not the trapdoor
    cmp #0                              ; A = 0 if nothing is at that cell
    beq emerge_done                     ; Nothing there: the monster stays on the trapdoor
    pla                                 ; Something there: park it off the map, still alive
    pha                                 ; ...keeping it stacked for monster_done
    tax                                 ; ...its number in X, which find_creature changed
    lda #off_map                        ; Off the map...
    sta monster_x,x                     ; ...as its x
    sta monster_y,x                     ; ...and its y: no trapdoor will take it back
    jmp monster_done                    ; Pull the monster number and on to the next
.emerge_done
    jmp monster_done                    ; Pull the monster number and on to the next
    equb &00                            ; Not referenced
; Hit points a monster starts with on this level: 6 + 2 x the level number (8 on level 1).
.monster_start_hit_points
    equb &08
; Initial contents of page &0D, copied there at the start of every level.
