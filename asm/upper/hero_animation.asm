; ***************************************************************************************
; Animate a hero who is out of play
;
; Play a dying hero's sparkles and skull, or a returning hero's skull and sparkles in
; reverse, at the cell where they fell. move_heroes calls this each frame, in the hero's
; turn, for a hero out of play (direction 0) unless nobody plays them (step &63). While
; out of play the hero's offset bytes are reused: hero_offset_y is a two-frame timer and
; hero_offset_x the step through the sequence (+1 or -1), both set by lose_health_point
; for a death and by collect_objects for a Cross of Resurrection.
;
; Every other frame, plot hero_appearance_sprites entry hero_frame at the hero's cell,
; with no pixel offset, then step hero_frame by hero_offset_x: forwards (+1) for a hero
; dying, stopping at the skull (entry 8), which is then redrawn every other frame until a
; Cross brings the hero back; backwards (-1) for a hero returning through a Cross of
; Resurrection, from entry 8. A dying hero starts from their walking frame (0 or 1),
; which lose_health_point does not reset, so the first sparkle may be skipped. A
; returning hero is put back in play as hero_frame reaches 0, so entry 0 is never shown
; on the way back: they come back in the cell where they fell, facing down, standing
; squarely in it, with health 32 (set to 33 and drawn by taking a point). move_heroes
; draws them on their next turn.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
.animate_absent_hero
    dec hero_offset_y,x                 ; Every other frame: count down the timer...
    beq absent_frame_due                ; Timer run out: show the next sprite
    rts                                 ; Not yet: nothing to draw this frame
; Due: plot the sprite for the hero's place in the sequence at their cell.
.absent_frame_due
    lda #2                              ; Restart the two-frame timer...
    sta hero_offset_y,x                 ; ...which an absent hero keeps in hero_offset_y
    jsr get_hero_cell                   ; Plot the current appearance sprite at the hero's cell
    lda #0                              ; No pixel offsets (those bytes hold timer and step)...
    sta plot_offset_x                   ; ...none across...
    sta plot_offset_y                   ; ...and none down
    lda hero_frame,x                    ; The hero's place in the appearance sequence...
    tay                                 ; ...as an index...
    lda hero_appearance_sprites,y       ; ...picks the sparkle or skull to show
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack: plot_at_cell changes X
    jsr plot_at_cell                    ; Plot it in every view that shows the hero
    pla                                 ; Recover the hero number...
    tax                                 ; ...back in X
; Step to the next place, holding a dying hero at the skull (place 8).
    clc                                 ; Step to the next (+1 dying, -1 returning), stopping at 8
    lda hero_frame,x                    ; Current place in the sequence...
    adc hero_offset_x,x                 ; ...plus the step kept in hero_offset_x
    cmp #9                              ; Past the skull (place 8)?
    bcc check_hero_returned             ; No: keep the new place
    lda #8                              ; Yes: a dead hero stays on the skull
.check_hero_returned
    cmp #0                              ; Place 0? Only a returning hero gets there
    bne store_hero_frame                ; No: store the new place for the next plot
; A returning hero has reached place 0: put them back in play, facing down, squarely in their cell, with 32 health.
    lda #5                              ; Yes: back in play before place 0 is shown...
    sta hero_direction,x                ; ...facing down (direction 5)
    lda #0                              ; ...with no step or offsets...
    sta hero_step,x                     ; ...not mid-step...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...no vertical offset...
    sta hero_frame,x                    ; ...and animation frame 0
    lda #spr_digit_3                    ; ...and health 33, drawn by taking a point
    sta hero_health_tens,x              ; ...tens digit 3...
    sta hero_health_units,x             ; ...units digit 3...
    jsr lose_health_point               ; ...less a point, which also draws it: 32
    rts                                 ; Return with the hero back in play
.store_hero_frame
    sta hero_frame,x                    ; Store the new place, to show in two frames
    rts                                 ; Return; the hero stays out of play
; ***************************************************************************************
; Draw a hero
;
; Plot sprite_number at hero X's cell, shifted by their pixel offsets (half a cell along
; while a step is under way), in every view that shows it. move_heroes calls it each
; frame for every hero in play, at draw_moved_hero, with the hero's sprite for their
; direction and frame; lose_health_point calls it with the blank to erase a hero who has
; just died. cell_x and cell_y are left as plot_at_cell leaves them, as positions within
; the view, so callers needing the map cell load it again.
;
; On Entry:
;     X: hero number (0-3)
;     SPRITE_NUMBER: sprite to plot
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
.draw_hero
    jsr get_hero_cell                   ; The hero's map cell...
    lda hero_offset_x,x                 ; ...and the pixel offsets of a step in progress
    sta plot_offset_x                   ; ...the column offset (0 or +-2) as plot_offset_x...
    lda hero_offset_y,x                 ; ...and the row offset (0 or +-6)...
    sta plot_offset_y                   ; ...as plot_offset_y
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack: each plot leaves X = 0
    jsr plot_at_cell                    ; Plot the hero in every view showing it
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again for the caller
    rts                                 ; Return with X = the hero again
; ***************************************************************************************
; Animate the hero who fired a missile
;
; Toggle the animation frame (0 or 1) of the hero whose missile is in slot X, so the
; hero's sprite changes as they throw. move_missiles calls this on a missile's first
; move, while bit 7 of its direction still marks it as just fired; move_heroes flipped
; the frame when it fired, so this flips it back, and the throw shows for one frame. The
; firer is told by the missile's sprite base (one less than its up sprite): arrows the
; Ranger, fireballs the Magic-User, axes the Barbarian, and anything else the Fighter.
; The hero is not redrawn here; the new frame shows when move_heroes next draws them.
;
; On Entry:
;     X: missile slot (0-11)
;
; On Exit:
;     A: corrupted
;     X: preserved
.flip_firer_frame
    lda missile_sprite_base,x           ; Which hero fired it? Its sprite base says
    cmp #spr_arrow_up - 1               ; ...the arrows' base, one below the up arrow?
    bne firer_fireball                  ; Not arrows: try fireballs
    lda hero_frame                      ; The Ranger's animation frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame                      ; ...so the Ranger's sprite changes as they fire
    rts                                 ; Return; X is still the missile slot
.firer_fireball
    cmp #spr_fireball_up - 1            ; ...the fireballs' base?
    bne firer_axe                       ; Not fireballs: try axes
    lda hero_frame + 1                  ; The Magic-User's animation frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame + 1                  ; ...so the Magic-User's sprite changes as they cast
    rts                                 ; Return; X is still the missile slot
.firer_axe
    cmp #spr_axe_up - 1                 ; ...the axes' base?
    bne firer_sword                     ; Not axes: so it must be swords
    lda hero_frame + 2                  ; The Barbarian's animation frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame + 2                  ; ...so the Barbarian's sprite changes as they throw
    rts                                 ; Return; X is still the missile slot
.firer_sword
    lda hero_frame + 3                  ; Otherwise swords: the Fighter's frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame + 3                  ; ...so the Fighter's sprite changes as they throw
    rts                                 ; Return; X is still the missile slot
; ***************************************************************************************
; Copy a hero's position to cell_x, cell_y
;
; Load hero X's map cell into cell_x and cell_y, ready for plot_at_cell. Used by
; draw_hero and animate_absent_hero.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     CELL_X: hero_x
;     CELL_Y: hero_y
;     A: hero_y
;     X: preserved
.get_hero_cell
    lda hero_x,x                        ; The hero's map x...
    sta cell_x                          ; ...as cell_x, for plot_at_cell
    lda hero_y,x                        ; ...and map y...
    sta cell_y                          ; ...as cell_y
    rts                                 ; Return with the hero's cell in cell_x, cell_y
    equb &73                            ; Not referenced
