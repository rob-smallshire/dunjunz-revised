; ***************************************************************************************
; Take one health point from a hero
;
; If hero X is in play, take one point from their health and redraw it in the status
; panel; if that point was their last, kill them.
;
; Every kind of harm is paid through here, one call per point: a hero walking into a
; monster (move_heroes, 1 point), a monster stepping onto a hero (hero_damage_taken
; points), a missile (its damage), an energy drainer (10, from collect_objects) and the
; cost of magic (6 for the Ranger, 3 for the Magic-User). Three callers use it only to
; draw a health they have set one point high: draw_status_panel (99 + 1 at each level),
; the potion, and a returning hero (33, drawn as 32).
;
; Health is two digit sprites, hero_health_tens and hero_health_units (&1E-&27 for 0-9),
; so the units digit wraps from 0 to 9 with a borrow from the tens. Health 00 is still
; alive; the hero dies when a point is taken from 00, which leaves the tens at &1D, one
; below the 0 sprite: the play loop tests that to count the dead. On death the hero's
; sprite is erased from every view, they leave play (direction 0), the death animation is
; started (frame step +1, counter 1, run by move_heroes) and their number + 1 is put in
; the first free entry of returning_hero_queue, for a Cross of Resurrection to bring
; back. The health is not redrawn on death. A hero out of play (dying, returning, or not
; playing) loses nothing, so a skull is safe to touch.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.lose_health_point
    lda hero_direction,x                ; Direction 0: out of play, dying or returning
    bne take_health_unit                ; In play: they can be hurt
    rts                                 ; Out of play: nothing to lose
.take_health_unit
    dec hero_health_units,x             ; Health down one: the units digit sprite
    lda hero_health_units,x             ; ...and look at the new units digit
    cmp #spr_digit_0 - 1                ; Gone below the 0 sprite?
    bne draw_health                     ; No: the tens are untouched, redraw the health
    lda #spr_digit_9                    ; Yes: units back to 9...
    sta hero_health_units,x             ; ...so 30 becomes 29
    dec hero_health_tens,x              ; ...and borrow from the tens
    lda hero_health_tens,x              ; ...and look at the new tens digit
    cmp #spr_digit_0 - 1                ; Below 0? The point was taken from 00
    bne draw_health                     ; No: still alive, redraw the health
; The point was taken from health 00: the hero dies. The tens digit is left at &1D, below the 0 sprite, which marks the hero as dead to the play loop.
    lda #spr_blank                      ; The hero has died: erase them...
    sta sprite_number                   ; ...with the blank sprite...
    jsr draw_hero                       ; ...at their cell in every view showing it
    lda #0                              ; ...take them out of play...
    sta hero_direction,x                ; ...so they neither move nor take more harm
    lda #1                              ; ...and start the death animation:
    sta hero_offset_x,x                 ; ...frame step +1: forwards to the skull...
    sta hero_offset_y,x                 ; ...frame counter 1: the first step comes next frame
; Put the hero in the first free (zero) entry of returning_hero_queue, as hero + 1, to wait for a Cross. The search has no limit; a free entry is always there, as the queue holds at most one entry per hero.
    ldy #0                              ; Queue them for a Cross: from the queue's front...
.find_queue_slot
    lda returning_hero_queue,y          ; ...look at this queue entry
    bne next_queue_slot                 ; Taken: try the next entry
    txa                                 ; Free: entry = hero number + 1...
    clc                                 ; ...(carry clear for the add)...
    adc #1                              ; ...(entries are hero + 1, so 0 can mean free)...
    sta returning_hero_queue,y          ; ...queued behind those already waiting
    rts                                 ; Return, health not redrawn
.next_queue_slot
    iny                                 ; Next queue entry
    bne find_queue_slot                 ; Keep looking (an empty entry is always found)
; Draw hero X's health, two digit sprites on the top row of their panel section, tens at panel_left and units three byte columns right. lose_health_point falls through to here and food calls it; plot_sprite corrupts X, so the hero is kept on the stack.
.draw_health
    lda hero_panel_y,x                  ; Health on the top row of the hero's panel section...
    sta plot_y                          ; ...as the plotting row
    lda #panel_left                     ; Tens in the panel's left column...
    sta plot_x                          ; ...as the plotting column
    lda hero_health_tens,x              ; The tens digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the health's tens digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the units digit
    lda hero_health_units,x             ; The units digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 3                 ; ...three byte columns right of the tens...
    sta plot_x                          ; ...on the same row
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the health's units digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the health drawn and X the hero
; ***************************************************************************************
; Add one point to a hero's score
;
; Add one to hero X's score and redraw it in the status panel. Points come one at a time
; from here: a monster killed by a missile or by magic, a hit on an energy drainer, food
; (five calls) and a door opened (seven); draw_status_panel calls it at each level just
; to draw the score, which adds a point. Bigger rewards go through add_ten_points.
;
; The score is kept as digit sprites, one table per digit (hero_score_thousands,
; _hundreds, _tens, _units; &1E-&27 for 0-9), so it can be plotted as it stands. A units
; digit past 9 is set back to 0 and the carry made by falling into add_ten_points, which
; goes on into the hundreds and, through add_thousand_points, the thousands and the small
; ten-thousands digit. draw_score then plots all four main digits.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.add_point
    inc hero_score_units,x              ; Score up one: the units digit sprite
    lda hero_score_units,x              ; ...and look at the new units digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne draw_score                      ; No: nothing to carry, redraw the score
    lda #spr_digit_0                    ; Yes: units back to 0...
    sta hero_score_units,x              ; ...and carry by falling into add_ten_points
; ***************************************************************************************
; Add ten points to a hero's score
;
; Add ten to hero X's score, carrying into the hundreds and through add_thousand_points,
; and redraw the score. collect_objects calls it for treasure (twice: 20 points), the
; Cross of Resurrection and every magic item; add_point falls into it to carry from the
; units. The units digit is not touched, which the potion relies on: it reads the units
; digit before calling this.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.add_ten_points
    inc hero_score_tens,x               ; Score up ten: the tens digit sprite
    lda hero_score_tens,x               ; ...and look at the new tens digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne draw_score                      ; No: nothing to carry, redraw the score
    lda #spr_digit_0                    ; Yes: tens back to 0...
    sta hero_score_tens,x               ; ...stored for this hero
    inc hero_score_hundreds,x           ; ...and carry into the hundreds
    lda hero_score_hundreds,x           ; ...and look at the new hundreds digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne draw_score                      ; No: redraw the score
    lda #spr_digit_0                    ; Yes: hundreds back to 0...
    sta hero_score_hundreds,x           ; ...stored for this hero
    jsr add_thousand_points             ; ...and carry into the thousands and beyond
; Draw hero X's score, four digit sprites (thousands, hundreds, tens, units, three byte columns apart from panel_left) twelve rows below the health. The ten-thousands digit is drawn by add_thousand_points when it changes.
.draw_score
    clc                                 ; Score: all four digits, twelve rows below the health
    lda hero_panel_y,x                  ; Row: the hero's panel section...
    adc #&0c                            ; ...twelve rows down, below the health
    sta plot_y                          ; ...as the plotting row
    lda #panel_left                     ; Thousands digit in the panel's left column
    sta plot_x                          ; ...as the plotting column
    lda hero_score_thousands,x          ; The thousands digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the thousands digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the hundreds digit
    lda hero_score_hundreds,x           ; The hundreds digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 3                 ; ...three byte columns right (&48)...
    sta plot_x                          ; ...as the plotting column
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the hundreds digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the tens digit
    lda hero_score_tens,x               ; The tens digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 6                 ; ...six byte columns right (&4B)...
    sta plot_x                          ; ...as the plotting column
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the tens digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the units digit
    lda hero_score_units,x              ; The units digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 9                 ; ...nine byte columns right (&4E)...
    sta plot_x                          ; ...as the plotting column
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the units digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the score drawn and X the hero
