; The monster comes back facing up on the next trapdoor in turn, with the hit points the
; kill gave it back. It is not drawn until next frame. A trapdoor that a hero in play
; stands on stays shut: the monster waits, off the map at its last sparkle, and tries the
; next trapdoor on the next frame. Monsters may emerge onto each other.
;
; In the 1987 release the creature test here read cell_x and cell_y as plot_at_cell had
; left them, not the trapdoor's cell, so it missed a creature on the trapdoor, hurt a hero
; at the unrelated cell it named, and parked the monster at &FF,&FF for good if anything
; was there.
.monster_reappears
    inc next_trapdoor                   ; Each reappearance uses the next trapdoor in turn
    lda next_trapdoor                   ; Which trapdoor now?
    cmp #8                              ; Past the eighth (7)?
    bne emerge_at_trapdoor              ; No: emerge there
    lda #0                              ; Yes: wrap round to trapdoor 0...
    sta next_trapdoor                   ; ...for this monster and the next
.emerge_at_trapdoor
    ldy next_trapdoor                   ; Y = the trapdoor to emerge from
    jsr hero_on_trapdoor                ; Carry set if a hero in play stands on it
    bcs trapdoor_shut                   ; Yes: the trapdoor stays shut
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
    bcc emerge_done                     ; Always: carry is still clear
.trapdoor_shut
    lda #spr_sparkle_3                  ; Back to the last sparkle, so the next frame...
    sta monster_sprite,x                ; ...tries again, at the next trapdoor
    lda #off_map                        ; Off the map meanwhile, so it is neither drawn...
    sta monster_x,x                     ; ...nor found by find_creature: its x...
    sta monster_y,x                     ; ...and its y
.emerge_done
    txa                                 ; Stack the monster number...
    pha                                 ; ...for monster_done to pull
    jmp monster_done                    ; On to the next monster
; Hit points a monster starts with on this level: 6 + 2 x the level number (8 on level 1).
.monster_start_hit_points
    equb &08
; Initial contents of page &0D, copied there at the start of every level.
