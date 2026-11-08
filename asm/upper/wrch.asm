; ***************************************************************************************
; WRCHV handler: print letters and digits in the game font
;
; Installed on WRCHV while the game runs. A letter (either case) or a digit is printed in
; the game's own font: character 128 is defined as its eight-byte glyph with VDU 23 and
; printed instead. Every other character is printed unchanged. Both go to the MOS's own
; WRCH routine through saved_wrchv. (The 1987 release copied the glyph straight to &0C00,
; where MOS 1.20 keeps character 128's definition, and jumped into MOS 1.20 at &E0A4.)
; Lower-case letters share the capitals' glyphs. The handler keeps the
; character in plot_x, the sprite plotter's zero-page column, and it looks at every byte
; alone, with no notion of a VDU sequence: a VDU parameter byte that falls in '0'-'9',
; 'A'-'Z' or 'a'-'z' is sent as &80 too.
;
; On Entry:
;     A: character to print
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: preserved
;     PLOT_X: corrupted
.wrch_handler
    sta plot_x                          ; Keep the character in plot_x, borrowed as scratch
    txa                                 ; Save the caller's X...
    pha                                 ; ...on the stack
    tya                                 ; ...and the caller's Y
    pha                                 ; ...on the stack: OSWRCH must preserve both
    lda plot_x                          ; Classify the character by range
    cmp #'0'                            ; Below '0': a control code, space or punctuation?
    bcc pass_character                  ; Controls, space, punctuation: the MOS font
    cmp #':'                            ; Below ':', so a digit '0'-'9'?
    bcc digit_glyph                     ; A digit: use the game's digit glyph
    cmp #'A'                            ; Below 'A', so ':' to '@'?
    bcc pass_character                  ; Punctuation: the MOS font
    cmp #'['                            ; Below '[', so a capital 'A'-'Z'?
    bcc capital_letter                  ; A capital: use the game's letter glyph
    cmp #'a'                            ; Below 'a', so '[' to '`'?
    bcc pass_character                  ; Punctuation: the MOS font
    cmp #'{'                            ; '{' or above, past the lower-case letters?
    bcs pass_character                  ; '{' and above: the MOS font
    sec                                 ; Lower case: letter number 0-25...
    sbc #'a'                            ; ...so it is drawn with the capital's glyph
    jmp glyph_offset                    ; Join the capitals' path
.capital_letter
    sec                                 ; Capital: letter number 0-25...
    sbc #'A'                            ; ...0 for 'A'
.glyph_offset
    asl a                               ; Glyph offset = letter x 8 in font_letters: x 2...
    asl a                               ; ...x 4 (8 bytes a glyph)...
    asl a                               ; ...x 8: the glyph's offset (at most 200)
.copy_glyph
    tax                                 ; X indexes the glyph in font_letters
    jsr define_character_128            ; VDU 23,128 for the glyph's rows...
.send_letter_row
    lda font_letters,x                  ; ...each row of the letter's glyph...
    jsr mos_wrch                        ; ...sent to the MOS
    inx                                 ; Next row of the glyph
    dey                                 ; One row fewer to send
    bne send_letter_row                 ; Until all eight are sent
.restore_registers
    pla                                 ; Restore the caller's Y...
    tay                                 ; ...from the stack
    pla                                 ; ...and the caller's X
    tax                                 ; ...from the stack
    lda #&80                            ; Character 128, which now looks like the glyph...
    jmp (saved_wrchv)                   ; ...printed by the MOS
.digit_glyph
    sec                                 ; Digit: digit number 0-9...
    sbc #'0'                            ; ...0 for '0'
    asl a                               ; Glyph offset = digit x 8 in font_digits: x 2...
    asl a                               ; ...x 4 (8 bytes a glyph)...
    asl a                               ; ...x 8: the glyph's offset
    tax                                 ; X indexes the glyph in font_digits
    jsr define_character_128            ; VDU 23,128 for the glyph's rows...
.send_digit_row
    lda font_digits,x                   ; ...each row of the digit's glyph...
    jsr mos_wrch                        ; ...sent to the MOS
    inx                                 ; Next row of the glyph
    dey                                 ; One row fewer to send
    bne send_digit_row                  ; Until all eight are sent
    beq restore_registers               ; Done (always taken): print character 128
; Start redefining character 128: send VDU 23,128 through the MOS, and set Y to 8, the
; number of glyph rows to follow.
.define_character_128
    lda #23                             ; VDU 23: define a character...
    jsr mos_wrch                        ; ...sent to the MOS
    lda #&80                            ; ...character 128
    jsr mos_wrch                        ; ...sent to the MOS
    ldy #8                              ; Eight rows to follow
    rts                                 ; Return with Y = 8
.pass_character
    pla                                 ; Not a letter or digit: restore the caller's Y...
    tay                                 ; ...from the stack
    pla                                 ; ...and the caller's X
    tax                                 ; ...from the stack
    lda plot_x                          ; The character, unchanged, from plot_x...
    jmp (saved_wrchv)                   ; ...printed by the MOS
