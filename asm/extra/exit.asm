; ***************************************************************************************
; The exit animation, continued
;
; The game core ends at &1FFF in the middle of the exit animation's shrinking step
; (core/frame.asm), and execution runs on into these instructions at &2000. The two parts
; must stay adjacent while the layout is the original's.
.exit_shrink_continues
    adc #1                              ; ...+1: their first sprite...
    tay                                 ; ...in Y, for the height loop...
    tax                                 ; ...and in X, for the width loop
    adc #7                              ; ...+7: stop before base + 8, left frame 1
    sta scratch                         ; ...kept as the end
.shrink_hero_width
    dec sprite_widths,x                 ; One byte (two pixels) narrower
    inx                                 ; Next of the hero's seven sprites
    cpx scratch                         ; Reached the end?
    bne shrink_hero_width               ; No: narrow the next
    tya                                 ; Three rows shorter...
    tax                                 ; ...from the first sprite again
.shrink_hero_height
    sec                                 ; ...set carry to subtract
    lda sprite_heights,x                ; This sprite's height...
    sbc #3                              ; ...less three rows...
    sta sprite_heights,x                ; ...stored back in sprite_heights
    inx                                 ; Next of the hero's seven sprites
    cpx scratch                         ; Reached the end?
    bne shrink_hero_height              ; No: shorten the next
    jmp play_level                      ; ...three rows shorter. Next frame
; The hero has gone: put the exit back.
.restore_exit
    lda exit_saved_x                    ; Put the exit back where it was...
    sta exit_x                          ; ...exit_saved_x back as its x...
    lda exit_saved_y                    ; ...and its saved y...
    sta exit_y                          ; ...as its y, so the next hero can use it
    lda #0                              ; ...and end the animation
    sta exit_busy                       ; ...exit no longer busy
    jmp play_level                      ; Next frame: the descent is over
; ***************************************************************************************
; Start a hero going down the exit
;
; Start hero X's descent: the hero spins on the exit for four turns, shrinking after each
; of the first three. Called by play_level's check_exit for a hero who has just stepped
; onto the exit, after drop_key, and after the hero has been taken out of play and the
; exit hidden off the map.
;
; queue_exit_marker plays the exit sound and puts a nobody_returns marker in
; returning_hero_queue, as remove_absent_heroes does for a hero nobody plays. Any hero
; shrunk on an earlier descent (shrunk_hero) gets their full-size sprites back, as the
; sprites are shared with no copy. Then exit_busy is set, exiting_hero and shrunk_hero
; become X, exit_spin starts at -1 (the first frame's +2 gives the up-facing sprite) and
; exit_shrinks_left at 4; play_level's redraw_exit runs the spin from the next frame.
;
; check_exit jumps here, and it ends by jumping to play_level, so nothing is left on the
; stack. (The 1987 release entered it with JSR, leaking a return address; see play_level.)
;
; On Entry:
;     X: hero number (0-3)
.hero_enters_exit
    stx scratch2                        ; Keep the hero number
    jsr queue_exit_marker               ; Sound the exit; mark the hero queue
    lda #4                              ; exit_offsets_x entry 0 = 4...
    sta exit_offsets_x                  ; ...never read: shrinks run from 4 down to 1
    ldx shrunk_hero                     ; Restore the sprites of any hero shrunk before
    bmi start_hero_animation            ; None (&FF): go straight on
    jsr restore_hero_sprites            ; Give that hero back their full-size sprites
    jmp start_hero_animation            ; ...then start this hero's spin
; ***************************************************************************************
; Restore a hero's sprite sizes
;
; Give hero X back their full-size sprites after the exit animation has shrunk them. The
; descent narrows sprites base + 1 to base + 7 (base from hero_sprites) by a byte and
; shortens them by three rows after each of three turns, in sprite_widths and
; sprite_heights themselves. This sets the seven back to a whole cell, 4 bytes wide and
; 12 rows high, which is what every hero's walking sprites measure. Called by
; hero_enters_exit, before the next hero's descent shrinks their own sprites, and by
; play_level when the level ends, each time for shrunk_hero.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: 12
;     X: base + 1
;     Y: base + 8
.restore_hero_sprites
    clc                                 ; The hero's sprites base + 1 to base + 7
    lda hero_sprites,x                  ; ...the hero's sprite base...
    adc #1                              ; ...+1: their first sprite...
    tax                                 ; ...in X, kept to restart Y for the heights...
    tay                                 ; ...and in Y, to walk the widths
    adc #7                              ; ...+7: stop before base + 8, left frame 1
    sta scratch                         ; ...kept as the end
    lda #4                              ; Widths back to 4 bytes, a whole cell...
.restore_sprite_widths
    sta sprite_widths,y                 ; Sprite Y back to 4 bytes wide
    iny                                 ; Next of the seven, base + 1 to base + 7
    cpy scratch                         ; Reached the end?
    bne restore_sprite_widths           ; No: widen the next
    txa                                 ; ...from the first sprite again...
    tay                                 ; ...in Y, to walk the heights
    lda #&0c                            ; ...heights back to 12 rows, a whole cell
.restore_sprite_heights
    sta sprite_heights,y                ; Sprite Y back to 12 rows high
    iny                                 ; Next of the seven
    cpy scratch                         ; Reached the end?
    bne restore_sprite_heights          ; No: restore the next
    rts                                 ; Return with the hero's sprites full size again
; Set up the descent for the hero kept in scratch2.
.start_hero_animation
    lda #1                              ; Start the animation for this hero...
    sta exit_busy                       ; ...the exit is busy...
    lda scratch2                        ; ...the hero kept by hero_enters_exit...
    sta exiting_hero                    ; ...is the one going down...
    sta shrunk_hero                     ; ...and the one whose sprites will shrink
    lda #&ff                            ; ...turning from the start...
    sta exit_spin                       ; ...-1, so the first frame's +2 gives 1
    lda #4                              ; ...for four turns, shrinking after the first three
    sta exit_shrinks_left               ; ...in exit_shrinks_left, counting turns 4 to 1
    jmp play_level                      ; Back to play_level for the next frame
; ***************************************************************************************
; Drop the key a hero carries
;
; Leave hero X's key behind beside the exit, so the heroes still playing can use it.
; Called by play_level's check_exit as the hero steps onto the exit, before they are
; taken out of play.
;
; find_open_neighbour picks the first of the cells above, right of, below and left of the
; hero that has no wall and no key in it. The key's key_x/key_y are set to that cell, so
; update_game's draw_keys shows it from the next frame; hero_key is cleared and the key
; icon erased from the hero's panel section. If all four are walls or hold keys, the key
; is put off the map: lost for this level, as it would have been in a wall. A hero with
; no key moves key entry 0, which is never drawn or picked up.
;
; In the 1987 release the cell to the left was taken, untested, when the other three were
; walls, so a key could land in a wall; and no cell was tested for a key already there.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.drop_key
    jsr find_open_neighbour             ; A free cell beside the hero? Carry clear if so
    bcc drop_key_here                   ; Yes: cell_x, cell_y are on it
    lda #off_map                        ; None: the key goes off the map, lost...
    sta cell_x                          ; ...its x...
    sta cell_y                          ; ...and its y
.drop_key_here
    ldy hero_key,x                      ; Put the hero's key there (entry 0 if none)
    lda cell_x                          ; ...the free cell's x...
    sta key_x,y                         ; ...as the key's x...
    lda cell_y                          ; ...and its y...
    sta key_y,y                         ; ...as the key's y
    lda #0                              ; The hero carries no key
    sta hero_key,x                      ; ...in the hero's key slot
    lda #spr_blank_key_icon             ; Erase the key icon from the hero's panel
    sta sprite_number                   ; ...as the sprite to plot
    lda hero_panel_y,x                  ; ...from the hero's panel row...
    sec                                 ; ...set carry to subtract
    sbc #&0d                            ; ...less 13: the key icon's row...
    sta plot_y                          ; ...as plot_y, the icon's screen row
    lda #panel_left + 5                 ; ...in panel column panel_left + 5...
    sta plot_x                          ; ...as plot_x, the icon's column
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across plot_sprite
    jsr plot_sprite                     ; Plot the blank icon over the key icon
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, preserved for check_exit
    rts                                 ; Return with the key on the floor beside the exit
; ***************************************************************************************
; Find a free cell next to a hero
;
; Find where drop_key, its only caller, can put down a key next to the exit: the first of
; the cells above, to the right of, below and to the left of hero X, in that order, with
; no wall (test_wall) and no key (key_in_cell). Objects and creatures are not tested.
; neighbour_dx and neighbour_dy hold the four offsets, indexed 3 (above) down to 0 (left).
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     C: clear if a free cell was found, set if none
;     CELL_X: the free cell's x (the last tried if none)
;     CELL_Y: its y
;     A: corrupted
;     X: preserved
;     Y: corrupted
.find_open_neighbour
    ldy #3                              ; Neighbours 3 to 0: above, right, below, left
.try_neighbour
    clc                                 ; This neighbour's cell: the hero's x...
    lda hero_x,x                        ; ...
    adc neighbour_dx,y                  ; ...plus its x offset...
    sta cell_x                          ; ...as cell_x
    clc                                 ; ...and the hero's y...
    lda hero_y,x                        ; ...
    adc neighbour_dy,y                  ; ...plus its y offset...
    sta cell_y                          ; ...as cell_y
    txa                                 ; Keep the hero number...
    pha                                 ; ...and the neighbour number...
    tya                                 ; ...on the stack...
    pha                                 ; ...across the tests
    jsr test_wall                       ; A wall there? Z set if open
    sec                                 ; Carry set: taken, unless found free below
    bne neighbour_tested                ; Wall: taken
    jsr key_in_cell                     ; Open: a key there? Carry set if so
.neighbour_tested
    pla                                 ; Recover the neighbour number...
    tay                                 ; ...into Y...
    pla                                 ; ...and the hero number...
    tax                                 ; ...into X (the carry is kept)
    bcc neighbour_found                 ; Free: return with carry clear
    dey                                 ; Taken: the next neighbour
    bpl try_neighbour                   ; More to try: try it
.neighbour_found
    rts                                 ; Return, carry set if all four were taken
    ALIGN &100                          ; Page-aligned: pointers into it are its high byte and an offset
; Map of the cells that cannot hold an object, in the same layout as room_walls, from the level file: a bit is clear where an object lies (and on a few other cells), so the object list need only be searched when a hero steps onto a clear bit.
.object_free_map
    equb &00, &02, &07, &07, &1f, &3f, &7d, &7f, &00, &30, &78, &fd, &7f, &ff, &80, &00  ; Not read: unpack_level copies each level's object-free map here
    equb &00, &60, &e0, &c0, &df, &c0, &1f, &0f, &00, &58, &58, &58, &d8, &18, &f8, &80  ; ...entries 16-31, not read
    equb &76, &3e, &5f, &6e, &7e, &00, &7f, &7f, &00, &66, &66, &7e, &7e, &66, &66, &00  ; ...entries 32-47, not read
    equb &1f, &1f, &03, &03, &ff, &03, &03, &03, &80, &80, &80, &80, &80, &f6, &fe, &f6  ; ...entries 48-63, not read
    equb &7f, &00, &3f, &2f, &37, &37, &2f, &37, &c0, &03, &c4, &86, &40, &00, &80, &c1  ; ...entries 64-79, not read
    equb &03, &e3, &e0, &e1, &41, &41, &00, &ff, &fe, &fe, &00, &00, &00, &00, &00, &8a  ; ...entries 80-95, not read
    equb &00, &00, &00, &00, &7e, &7f, &7e, &00, &01, &01, &01, &3f, &3f, &bf, &3f, &3f  ; ...entries 96-111, not read
    equb &f7, &ff, &c1, &f7, &c1, &ff, &f7, &bf, &8e, &9e, &de, &9c, &9e, &8e, &8e, &80  ; ...entries 112-127, not read
    equb &7e, &3e, &7e, &00, &7c, &7a, &7e, &00, &2f, &1f, &00, &00, &00, &ce, &ae, &5e  ; ...entries 128-143, not read
    equb &1f, &1f, &1f, &1b, &17, &1f, &00, &01, &80, &80, &80, &80, &80, &80, &02, &02  ; ...entries 144-159, not read
    equb &7e, &7a, &7e, &00, &7e, &3e, &7f, &00, &be, &0e, &0e, &0f, &0e, &0e, &be, &00  ; ...entries 160-175, not read
    equb &01, &01, &0f, &df, &07, &03, &01, &00, &08, &08, &5a, &fe, &fe, &fc, &b8, &00  ; ...entries 176-191, not read
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00  ; ...entries 192-200, not read
; Data of sprite &53, &54, &55, &56, &57, &58, &59, &5A, &5B, &5C, &5D, &5E: 4 bytes x 12 rows.
.sprite_drainer
    equb &11, &33, &33, &22
    equb &33, &33, &33, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &33, &33, &33
    equb &11, &33, &33, &22
; Map x of each door (entries 1-20).
.door_x
    equb &ff, &ff, &ff, &04, &ff, &ff, &06, &ff, &11, &ff, &ff, &ff, &1a, &03, &03, &0b  ; Not read: unpack_level copies each level's doors here
    equb &ff, &03, &09, &12, &ff        ; ...entries 16-20, not read
; Map y of each door.
.door_y
    equb &ff, &ff, &ff, &0d, &ff, &ff, &11, &ff, &16, &ff, &ff, &ff, &1a, &23, &27, &25  ; Not read: unpack_level copies each level's doors here
    equb &ff, &2b, &2e, &2b, &ff        ; ...entries 16-20, not read
; Sprite of each door.
.door_sprite
    equb &ff, &1c, &1c, &1d, &1c, &1c, &1d, &1d, &1d, &1d, &1d, &1c, &1c, &1d, &1d, &1c  ; Not read: unpack_level copies each level's door sprites here
    equb &1d, &1d, &1c, &1c, &ff        ; ...entries 16-20, not read
; Map x of each key lying on the floor (entries 1-20); key n opens door n.
.key_x
    equb &13, &ff, &ff, &1b, &ff, &ff, &17, &ff, &1c, &ff, &ff, &ff, &02, &15, &04, &09  ; Not read: unpack_level copies each level's keys here
    equb &ff, &04, &19, &17, &ff        ; ...entries 16-20, not read
; Map y of each key on the floor.
.key_y
    equb &25, &ff, &ff, &06, &ff, &ff, &09, &ff, &18, &ff, &ff, &ff, &29, &04, &0c, &14  ; Not read: unpack_level copies each level's keys here
    equb &ff, &0f, &03, &04, &ff        ; ...entries 16-20, not read
; Data of sprite &51: 4 bytes x 12 rows.
.sprite_exit
    equb &03, &03, &03, &03
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &03, &03, &03, &03
; Data of sprite &52: 2 bytes x 3 rows.
.sprite_key_icon
    equb &00, &05
    equb &0f, &0f
    equb &0f, &05
