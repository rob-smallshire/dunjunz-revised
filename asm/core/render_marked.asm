; ***************************************************************************************
; Is a cell marked?
;
; Z clear if cell_x, cell_y is marked for drawing in the first view showing it (all the
; views showing a room are marked alike), Z set if it is not, or no view shows it.
; Preserves X.
.cell_marked
    jsr find_cell_byte                  ; The cell's byte, if on show...
    bcs cell_not_marked                 ; ...not on show: not marked
    lda dirty_cells,y                   ; Its bits...
    and render_bit                      ; ...this cell's: Z set if not marked
    rts                                 ; Return
.cell_not_marked
    lda #0                              ; Z set: not marked
    rts                                 ; Return
; ***************************************************************************************
; Mark one cell for drawing
;
; Set the cell's bit in dirty_cells, so that render draws it afresh at the end of the
; frame, in the first view showing its room (view_room); render draws a cell in every view
; showing it (plot_at_cell), so one mark serves them all. A cell no view shows is not marked:
; nothing of it is on show. dirty_cells holds eight bytes for each view, one for each row
; of the room, bit bit_masks[x AND 7] for the column.
;
; On Entry:
;     CELL_X, CELL_Y: map cell
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
.mark_cell
    jsr find_cell_byte                  ; The cell's byte in dirty_cells, if on show...
    bcs mark_cell_done                  ; ...not on show: nothing to mark
    lda dirty_cells,y                   ; Set its bit
    ora render_bit                      ; ...
    sta dirty_cells,y                   ; ...
.mark_cell_done
    rts                                 ; Return
