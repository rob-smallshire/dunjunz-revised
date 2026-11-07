; ***************************************************************************************
; Add 1000 to a hero's score
;
; Carry a point into the thousands of hero X's score. add_ten_points calls it whenever
; the hundreds digit passes 9, and on return its draw_score redraws the four large digits
; (thousands to units) in the hero's panel section. The panel has room for only those
; four, so when the thousands digit passes 9 it goes back to 0 and the ten-thousands
; digit (hero_score_ten_thousands, a small digit sprite) goes up. That digit sticks at 9,
; so beyond 99,999 the large digits wrap while the small one stays at 9. Each change of
; the ten-thousands digit is drawn at draw_ten_thousands: the small digit &18 rows below
; the hero's panel row, under the score, followed by four of sprite &71. Sprite &71, the
; small 8, is a solid bar two pixels wide, the same shape a small 0 would have, so the
; line reads as a small N0000. remove_absent_heroes enters at draw_ten_thousands with the
; digit in A, to redraw the line on the fresh screen of each level. Uses plot_x, plot_y
; and sprite_number.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.add_thousand_points
    inc hero_score_thousands,x          ; One more thousand: the hundreds digit carried
    lda hero_score_thousands,x          ; ...and check the new digit
    cmp #spr_digit_9 + 1                ; Past 9: another ten thousand?
    bne add_thousand_points_done        ; No: return; draw_score shows the new digit
    lda #spr_digit_0                    ; Yes: thousands 0...
    sta hero_score_thousands,x          ; ...stored for this hero
    inc hero_score_ten_thousands,x      ; ...and carry into the small ten-thousands digit
    lda hero_score_ten_thousands,x      ; ...and check the new digit
    cmp #spr_small_digit_9 + 1          ; Past small 9: a score of 100,000?
    bne draw_ten_thousands              ; No: draw it under the score
    lda #spr_small_digit_9              ; Yes: it sticks at 9
    sta hero_score_ten_thousands,x      ; ...stored for this hero
.draw_ten_thousands
    sta sprite_number                   ; Plot the ten-thousands digit under the score...
    lda #panel_left                     ; ...at the panel's left column
    sta plot_x                          ; ...as the plot column
    lda workspace_template + 208,x      ; ...hero_panel_y, read from workspace_template
    clc                                 ; ...(carry clear for the add)
    adc #&18                            ; ...+ &18: below the score's rows, &0C-&15
    sta plot_y                          ; ...as the plot row
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack while plotting
    jsr plot_sprite                     ; Plot the ten-thousands digit
    lda #spr_small_digit_8              ; ...then four small 0s after it: sprite &71...
    sta sprite_number                   ; ...(small 8, a solid bar, the shape of a small 0)
    ldy #4                              ; ...four of them, for the 0000
.draw_ten_thousands_loop
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack while plotting
    inc plot_x                          ; Two byte columns right...
    inc plot_x                          ; ...a small digit's width on
    jsr plot_sprite                     ; Plot a 0 there
    pla                                 ; Recover the count...
    tay                                 ; ...of 0s still to plot, in Y
    dey                                 ; One fewer 0 to plot
    bne draw_ten_thousands_loop         ; More 0s: loop
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again, as on entry
.add_thousand_points_done
    rts                                 ; Return to draw_score (or remove_absent_heroes)
.sprite_blank
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; ***************************************************************************************
; Take the heroes nobody plays out of the level
;
; The last step of setting up each level, called by level_loop after draw_status_panel
; and just before play_level. For each hero in turn:
;
; First redraw the small ten-thousands line under the score, if it has one (through
; draw_ten_thousands), since start_level cleared the screen and draw_status_panel draws
; only the four large digits.
;
; Then, if the hero was switched off on the menu (hero_absent), take them out of play,
; since reset_workspace has just given every hero their starting state: direction 0;
; step_out_of_play, so move_heroes passes over them; frame 8 and dead health, so that
; play_level treats them as dead with their death animation over, and level_loop counts
; them among the dead (and resets them) when the level ends; map x &1F; and a
; nobody_returns entry in returning_hero_queue, which reset_monsters has just emptied.
; The absent heroes' entries go at the front of the queue, in hero order; a Cross of
; Resurrection sends such an entry to the back and takes the next. Their panel section
; keeps the health and score just drawn.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.remove_absent_heroes
    ldx #0                              ; Hero 0 first...
    ldy #0                              ; ...Y = the queue entry for the next absent hero
.remove_absent_heroes_loop
    lda hero_score_ten_thousands,x      ; Score of 10000 or more?
    cmp #spr_small_digit_1              ; ...ten-thousands sprite small 1 or above?
    bcc remove_absent_heroes_check      ; No: nothing under the score; check absence
    txa                                 ; Yes: redraw it, lost when the screen was cleared
    pha                                 ; Keep the hero number...
    tya                                 ; ...and the queue entry...
    pha                                 ; ...on the stack
    lda hero_score_ten_thousands,x      ; The digit's sprite...
    jsr draw_ten_thousands              ; ...drawn under the score with its 0000
    pla                                 ; Recover the queue entry...
    tay                                 ; ...for the next absent hero, in Y
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again
; Take the hero out of play if nobody is playing them, so that they count as dead, and a Cross of Resurrection passes over their queue entry.
.remove_absent_heroes_check
    lda hero_absent,x                   ; Switched off on the menu?
    beq remove_absent_heroes_next       ; No: playing; next hero
    lda #0                              ; Yes: take them out of play...
    sta hero_direction,x                ; ...direction 0: not in play
    lda #step_out_of_play               ; ...step &63, so move_heroes passes them over...
    sta hero_step,x                     ; ...as the hero's step count
    lda #8                              ; ...frame 8: their death animation is over...
    sta hero_frame,x                    ; ...as the hero's frame
    lda #spr_digit_0 - 1                ; ...health tens below 0: dead...
    sta hero_health_tens,x              ; ...as the health tens digit
    dec hero_score_units,x              ; ...units back below 0, undoing the panel's point
    lda #&1f                            ; ...map x &1F, the dungeon's last column...
    sta hero_x,x                        ; ...as the hero's map x
    lda #nobody_returns                 ; ...and a nobody_returns entry in the queue...
    sta returning_hero_queue,y          ; ...which a Cross of Resurrection skips
    iny                                 ; The next absent hero takes the next entry
.remove_absent_heroes_next
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four heroes done?
    bne remove_absent_heroes_loop       ; No: next hero
    rts                                 ; Return to level_loop: the level is ready to play
