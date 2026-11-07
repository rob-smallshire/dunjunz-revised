; ***************************************************************************************
; WRCHV handler: print letters and digits in the game font
;
; Installed on WRCHV while the game runs. A letter (either case) or a digit is printed in
; the game's own font: its eight-byte glyph is copied over the definition of character
; 128 (user_char_128) and character 128 is printed instead. Every other character is
; printed unchanged. Both paths finish in the MOS 1.20 OSWRCH routine at
; mos_oswrch_default, jumped to directly rather than through the WRCHV value saved at
; start-up. Lower-case letters share the capitals' glyphs. The handler keeps the
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
    bne copy_glyph                      ; Branch to the next instruction either way
.copy_glyph
    tax                                 ; X indexes the glyph in font_letters
    clc                                 ; End offset = start + 8...
    adc #8                              ; ...one glyph's eight rows...
    sta plot_x                          ; ...in plot_x, the character no longer needed
    ldy #0                              ; Y indexes character 128's definition at &0C00
.copy_letter_glyph
    lda font_letters,x                  ; Copy a row of the letter's glyph...
    sta room_walls,y                    ; ...over character 128's definition
    iny                                 ; Next row of character 128
    inx                                 ; Next row of the glyph
    cpx plot_x                          ; All eight rows copied?
    bne copy_letter_glyph               ; No: copy the next row
.restore_registers
    pla                                 ; Restore the caller's Y...
    tay                                 ; ...from the stack
    pla                                 ; ...and the caller's X
    tax                                 ; ...from the stack
    lda #&80                            ; Character 128, which now looks like the glyph...
    jmp mos_oswrch_default              ; ...printed by the MOS 1.20 OSWRCH routine itself
.digit_glyph
    sec                                 ; Digit: digit number 0-9...
    sbc #'0'                            ; ...0 for '0'
    asl a                               ; Glyph offset = digit x 8 in font_digits: x 2...
    asl a                               ; ...x 4 (8 bytes a glyph)...
    asl a                               ; ...x 8: the glyph's offset
    tax                                 ; X indexes the glyph in font_digits
    clc                                 ; End offset = start + 8...
    adc #8                              ; ...one glyph's eight rows...
    sta plot_x                          ; ...in plot_x, the character no longer needed
    ldy #0                              ; Y indexes character 128's definition at &0C00
.copy_digit_glyph
    lda font_digits,x                   ; Copy a row of the digit's glyph...
    sta room_walls,y                    ; ...over character 128's definition
    iny                                 ; Next row of character 128
    inx                                 ; Next row of the glyph
    cpx plot_x                          ; All eight rows copied?
    bne copy_digit_glyph                ; No: copy the next row
    beq restore_registers               ; Done (always taken): print character 128
.pass_character
    pla                                 ; Not a letter or digit: restore the caller's Y...
    tay                                 ; ...from the stack
    pla                                 ; ...and the caller's X
    tax                                 ; ...from the stack
    lda plot_x                          ; The character, unchanged, from plot_x...
    jmp mos_oswrch_default              ; ...printed by the MOS 1.20 OSWRCH routine itself
    equb &00                            ; Not referenced
