; ***************************************************************************************
; Is there a key in a cell?
;
; Say whether any key, 1 to 20, lies at cell_x, cell_y. Called by find_open_neighbour, so
; that a key dropped at the exit does not land on another.
;
; On Entry:
;     CELL_X: map x
;     CELL_Y: map y
;
; On Exit:
;     C: set if a key lies there
;     A: corrupted
;     X: corrupted
;     Y: preserved
.key_in_cell
    ldx #max_key                        ; Keys 20 to 1...
.check_key_in_cell
    lda key_x,x                         ; This key's x...
    cmp cell_x                          ; ...the cell's?
    bne next_key_in_cell                ; No: not here
    lda key_y,x                         ; ...and its y...
    cmp cell_y                          ; ...the cell's? Equal sets carry
    beq key_in_cell_done                ; Yes: return with carry set
.next_key_in_cell
    dex                                 ; Next key down
    bne check_key_in_cell               ; More keys: check the next
    clc                                 ; None here: carry clear
.key_in_cell_done
    rts                                 ; Return, carry set if a key lies in the cell
; Map offsets of the four cells next to a cell, for find_open_neighbour, indexed 0-3:
; left, below, right, above (tried from above down to left).
.neighbour_dx
    equb &ff, &00, &01, &00             ; Left, below, right, above: x offsets
.neighbour_dy
    equb &00, &01, &00, &ff             ; Left, below, right, above: y offsets
