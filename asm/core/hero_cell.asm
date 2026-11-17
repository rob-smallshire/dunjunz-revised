; ***************************************************************************************
; Copy a hero's position to cell_x, cell_y
;
; Load hero X's map cell into cell_x and cell_y, ready for plot_at_cell. Used by
; draw_hero, draw_absent_heroes and check_keys. In page &09, where there is room.
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
