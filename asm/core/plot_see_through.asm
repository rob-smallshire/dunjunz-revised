; ***************************************************************************************
; Plot a sprite see-through
;
; Plot sprite sprite_number with its top-left corner at byte column plot_x, pixel row
; plot_y, as plot_sprite does, but with its black see-through: wherever one of the
; sprite's pixels is black (colour 0), the screen's pixel there is left as it was. So a
; creature drawn over the floor shows the floor round it, and a key over a skull shows
; the skull. Only sprites four bytes wide are drawn this way, as everything drawn over
; something is; any other is passed to plot_sprite, solid.
;
; screen_ptr is kept at the top of the character row at the sprite's first column, Y
; steps across the four columns (8 bytes apart) of a pixel row from the row within the
; character row, and X steps through the sprite's data, read with an LDA abs,X whose
; address is set first. A black byte (both pixels black) is passed over; a byte with one
; black pixel keeps the screen's pixel there (MODE 2: bits 7, 5, 3, 1 are the left pixel,
; 6, 4, 2, 0 the right).
;
; On Entry:
;     PLOT_X: screen byte column (0-79)
;     PLOT_Y: pixel row
;     SPRITE_NUMBER: sprite to plot
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: 0
.plot_see_through
    ldx sprite_number                   ; The sprite...
    jsr sprite_size                     ; ...its size...
    lda sprite_width                    ; ...four bytes wide?
    cmp #4                              ; ...
    beq see_through_four_wide           ; Yes: see-through
    jmp plot_sprite                     ; No: solid
.see_through_four_wide
    lda sprite_addr_lo,x                ; Its data: low byte...
    sta see_through_data + 1            ; ...into the LDA abs,X...
    lda sprite_addr_hi,x                ; ...and high byte
    sta see_through_data + 2            ; ...likewise
    jsr screen_address                  ; screen_ptr = the top-left byte's address
    lda screen_ptr                      ; The pixel row within the character row...
    and #7                              ; ...(the low three bits)...
    sta row_start_ptr                   ; ...kept in row_start_ptr
    eor screen_ptr                      ; The character row's top at the first column...
    sta screen_ptr                      ; ...in screen_ptr (the high byte stands)
    ldx #0                              ; From the sprite's first byte
.see_through_row
    clc                                 ; Carry clear, for the column steps' ADC
    ldy row_start_ptr                   ; The first column's byte in this pixel row
.see_through_byte
.see_through_data
    lda &ffff,x                         ; The sprite's byte (address set above)...
    beq see_through_next                ; ...both pixels black: the screen's stay
    sta sprite_width                    ; Keep it (sprite_width is free as scratch here)
    and #&aa                            ; Its left pixel...
    bne see_through_left_set            ; ...coloured: look at the right pixel
    lda (screen_ptr),y                  ; Black: keep the screen's left pixel...
    and #&aa                            ; ...(its bits 7, 5, 3, 1)...
    ora sprite_width                    ; ...beside the sprite's right pixel
    bne see_through_store               ; Store it (always taken: the right pixel is coloured)
.see_through_left_set
    lda sprite_width                    ; The sprite's byte again...
    and #&55                            ; ...its right pixel...
    bne see_through_whole               ; ...coloured too: the whole byte
    lda (screen_ptr),y                  ; Black: keep the screen's right pixel...
    and #&55                            ; ...(its bits 6, 4, 2, 0)...
    ora sprite_width                    ; ...beside the sprite's left pixel
    bne see_through_store               ; Store it (always taken: the left pixel is coloured)
.see_through_whole
    lda sprite_width                    ; Both pixels coloured: the whole byte
.see_through_store
    sta (screen_ptr),y                  ; ...onto the screen
.see_through_next
    inx                                 ; The sprite's next byte
    tya                                 ; The next column, 8 bytes on (the carry is clear:
    adc #8                              ; ...from the CPY below, or set so at the row's start)
    tay                                 ; ...in Y
    cpy #32                             ; Past the fourth column (the row + 32)?
    bcc see_through_byte                ; No: the next byte of this row
    dec sprite_height                   ; One row fewer to plot
    beq see_through_done                ; None left: done
    inc row_start_ptr                   ; The next pixel row...
    lda row_start_ptr                   ; ...still within the character row?
    cmp #8                              ; ...
    bne see_through_row                 ; Yes: plot it
    lda #0                              ; No: the top row of the character row below...
    sta row_start_ptr                   ; ...
    clc                                 ; ...640 bytes on: low byte + &80...
    lda screen_ptr                      ; ...
    adc #&80                            ; ...
    sta screen_ptr                      ; ...
    lda screen_ptr_hi                   ; ...high byte + 2 and the carry
    adc #2                              ; ...
    sta screen_ptr_hi                   ; ...
    bne see_through_row                 ; Plot it (always taken: the screen is above &3000)
.see_through_done
    ldx #0                              ; Leave X and Y 0, as plot_sprite does
    ldy #0                              ; ...
    rts                                 ; Return: the sprite is on the screen
