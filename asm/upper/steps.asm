; ***************************************************************************************
; Start a hero's step between cells
;
; Called by move_heroes when a direction key starts a move within a room and the hero has
; no Boots of Speed. Set hero X's step counter to 1 and their pixel offsets to half a
; cell in the direction they face (hero_direction 1, 3, 5 or 7: up, right, down, left): 6
; rows up or down, or 2 byte columns left or right. move_heroes then draws the hero
; there, half way to the next cell, for one frame, still recorded in the old cell;
; continue_hero_step completes the move on the next frame.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: corrupted
;     X: preserved
.start_hero_step
    lda #1                              ; One frame to go before the hero is in the new cell
    sta hero_step,x                     ; ...as hero_step: continue_hero_step ends it
    lda hero_direction,x                ; Draw the hero half a cell along the way they face
    cmp #1                              ; Direction 1, facing up?
    bne hero_step_right                 ; No: try right
    lda #0                              ; Up: not across...
    sta hero_offset_x,x                 ; ...no horizontal offset
    lda #&fa                            ; -6: half a 12-row cell up...
    sta hero_offset_y,x                 ; ...as the vertical offset
    rts                                 ; Return: drawn half a cell up
.hero_step_right
    cmp #3                              ; Direction 3, facing right?
    bne hero_step_down                  ; No: try down
    lda #0                              ; Right: not up or down...
    sta hero_offset_y,x                 ; ...no vertical offset
    lda #2                              ; +2: half a 4-byte cell right...
    sta hero_offset_x,x                 ; ...as the horizontal offset
    rts                                 ; Return: drawn half a cell right
.hero_step_down
    cmp #5                              ; Direction 5, facing down?
    bne hero_step_left                  ; No: they face left
    lda #0                              ; Down: not across...
    sta hero_offset_x,x                 ; ...no horizontal offset
    lda #6                              ; +6: half a cell down...
    sta hero_offset_y,x                 ; ...as the vertical offset
    rts                                 ; Return: drawn half a cell down
.hero_step_left
    lda #0                              ; Left: not up or down...
    sta hero_offset_y,x                 ; ...no vertical offset
    lda #&fe                            ; -2: half a cell left...
    sta hero_offset_x,x                 ; ...as the horizontal offset
    rts                                 ; Return: drawn half a cell left
; ***************************************************************************************
; Continue a hero's step between cells
;
; Called by move_heroes, in place of reading the hero's keys, on the frame after a step
; starts. Toggle hero X's walking frame and count down their step. When it ends, move the
; hero one cell in the direction they face and clear the pixel offsets, so a step takes
; two frames. The offsets are then doubled. Since start_hero_step sets the counter to 1
; and nothing else gives an in-play hero a non-zero step, the step always ends here, so
; the doubling only ever doubles zero offsets.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: corrupted
;     X: preserved
.continue_hero_step
    lda hero_frame,x                    ; Swap the hero's walking frame...
    eor #1                              ; ...0 to 1 or 1 to 0...
    sta hero_frame,x                    ; ...so their legs move
    dec hero_step,x                     ; One frame fewer to the new cell
    bne double_offsets                  ; Not there yet (never taken: the step is 1)
    lda hero_direction,x                ; Arrived: move their cell on the way they face: up...
    cmp #1                              ; Direction 1, facing up?
    bne continue_right                  ; No: try right
    dec hero_y,x                        ; Yes: one row up
.continue_right
    cmp #3                              ; Direction 3, facing right?
    bne continue_down                   ; No: try down
    inc hero_x,x                        ; Yes: one column right
.continue_down
    cmp #5                              ; Direction 5, facing down?
    bne continue_left                   ; No: try left
    inc hero_y,x                        ; Yes: one row down
.continue_left
    cmp #7                              ; Direction 7, facing left?
    bne hero_no_offsets                 ; No: no move
    dec hero_x,x                        ; Yes: one column left
.hero_no_offsets
    lda #0                              ; Drawn squarely in the new cell:
    sta hero_offset_x,x                 ; ...no horizontal offset
    sta hero_offset_y,x                 ; ...no vertical offset
.double_offsets
    clc                                 ; Double the offsets, which are always zero by now
    lda hero_offset_x,x                 ; Horizontal offset x 2: the offset...
    adc hero_offset_x,x                 ; ...added to itself...
    sta hero_offset_x,x                 ; ...stored back, still 0
    clc                                 ; Ready for the vertical offset
    lda hero_offset_y,x                 ; Vertical offset x 2: the offset...
    adc hero_offset_y,x                 ; ...added to itself...
    sta hero_offset_y,x                 ; ...stored back, still 0
    rts                                 ; Return: the hero is squarely in the new cell
; ***************************************************************************************
; Start a monster's step between cells
;
; Called by update_monsters when a monster that is not stepping tries the next cell,
; before that cell is tested. Set monster X's step counter to 3 and its offsets to the
; first quarter of a cell in the direction it faces: 3 rows up or down, or one byte
; column left or right. If the cell turns out to be blocked, or on a room's edge,
; update_monsters clears all three again; otherwise the monster is drawn this frame a
; quarter of the way there, and continue_monster_step takes over on the next.
;
; On Entry:
;     X: monster number (1-30)
;
; On Exit:
;     A: corrupted
;     X: preserved
.start_monster_step
    lda #3                              ; Three more frames to reach the new cell...
    sta monster_step,x                  ; ...as the step count
    lda monster_sprite,x                ; Draw it a quarter cell along the way it faces: up...
    cmp #spr_monster_up_0               ; Sprite 9, facing up?
    bne monster_step_right              ; No: try right
    lda #0                              ; Up: not across...
    sta monster_offset_x,x              ; ...no horizontal offset
    lda #&fd                            ; -3: a quarter of a 12-row cell up...
    sta monster_offset_y,x              ; ...as the vertical offset
    rts                                 ; Return: drawn a quarter cell up
.monster_step_right
    cmp #spr_monster_right_0            ; Sprite &0B, facing right?
    bne monster_step_down               ; No: try down
    lda #0                              ; Right: not up or down...
    sta monster_offset_y,x              ; ...no vertical offset
    lda #1                              ; +1: a quarter of a 4-byte cell right...
    sta monster_offset_x,x              ; ...as the horizontal offset
    rts                                 ; Return: drawn a quarter cell right
.monster_step_down
    cmp #spr_monster_down_0             ; Sprite &0D, facing down?
    bne monster_step_left               ; No: it faces left
    lda #0                              ; Down: not across...
    sta monster_offset_x,x              ; ...no horizontal offset
    lda #3                              ; +3: a quarter of a cell down...
    sta monster_offset_y,x              ; ...as the vertical offset
    rts                                 ; Return: drawn a quarter cell down
.monster_step_left
    lda #0                              ; Left: not up or down...
    sta monster_offset_y,x              ; ...no vertical offset
    lda #&ff                            ; -1: a quarter of a cell left...
    sta monster_offset_x,x              ; ...as the horizontal offset
    rts                                 ; Return: drawn a quarter cell left
; ***************************************************************************************
; Continue a monster's step between cells
;
; Called by update_monsters each frame while monster X's step is under way (monster_step
; non-zero). Toggle its walking frame, so its legs move, and count down its step. On the
; first two calls the offsets grow by another quarter of a cell (a byte column or three
; rows), to a half and then three quarters. On the third the step ends: monster_x or
; monster_y moves one cell on the way it faces and the offsets are cleared, so it is
; drawn squarely in the new cell. With the frame start_monster_step began, a monster
; crosses an interior cell in four frames. Nothing tests the new cell again on arrival.
;
; On Entry:
;     X: monster number (1-30)
;
; On Exit:
;     A: corrupted
;     X: preserved
.continue_monster_step
    lda monster_frame,x                 ; Swap the monster's walking frame...
    eor #1                              ; ...0 to 1 or 1 to 0...
    sta monster_frame,x                 ; ...so its legs move as it slides
    dec monster_step,x                  ; One frame fewer to the new cell
    bne grow_offset_x                   ; Not there yet: slide a quarter cell further
    lda monster_sprite,x                ; Arrived: move its cell on the way it faces: up...
    cmp #spr_monster_up_0               ; Sprite 9, facing up?
    bne monster_continue_right          ; No: try right
    dec monster_y,x                     ; Yes: one row up
.monster_continue_right
    cmp #spr_monster_right_0            ; Sprite &0B, facing right?
    bne monster_continue_down           ; No: try down
    inc monster_x,x                     ; Yes: one column right
.monster_continue_down
    cmp #spr_monster_down_0             ; Sprite &0D, facing down?
    bne monster_continue_left           ; No: try left
    inc monster_y,x                     ; Yes: one row down
.monster_continue_left
    cmp #spr_monster_left_0             ; Sprite &0F, facing left?
    bne monster_no_offsets              ; No: no move
    dec monster_x,x                     ; Yes: one column left
.monster_no_offsets
    lda #0                              ; Drawn squarely in the new cell:
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset (zeros don't grow)
.grow_offset_x
    lda monster_offset_x,x              ; Slide across a further quarter cell (a byte column)
    beq grow_offset_y                   ; Zero: moving up or down, or arrived
    bpl grow_offset_x_right             ; Positive: moving right
    dec monster_offset_x,x              ; Negative: one more column left
    jmp grow_offset_y                   ; Now the vertical offset
.grow_offset_x_right
    inc monster_offset_x,x              ; One more column right
.grow_offset_y
    lda monster_offset_y,x              ; Slide down or up a further quarter cell (3 rows)
    beq monster_step_done               ; Zero: moving across, or arrived
    bpl grow_offset_y_down              ; Positive: moving down
    sec                                 ; Moving up: three more rows up...
    lda monster_offset_y,x              ; ...from the vertical offset...
    sbc #3                              ; ...three rows further up...
    sta monster_offset_y,x              ; ...to -6 or -9
    jmp monster_step_done               ; Offsets grown: return
.grow_offset_y_down
    clc                                 ; Moving down: three more rows down...
    lda monster_offset_y,x              ; ...from the vertical offset...
    adc #3                              ; ...three rows further down...
    sta monster_offset_y,x              ; ...to 6 or 9
.monster_step_done
    rts                                 ; Return: offsets grown, or the step ended
    equb &de, &35, &0d, &bd, &35, &0d, &d0, &00
    equb &60                            ; Not referenced
