; ***************************************************************************************
; Load the end of the game
;
; Load Setup again, with the end of the game stored after the set-up code and the play
; code over the font (asm/ending/ending.asm), at ENDING_FILE_ADDRESS instead of
; SETUP_ADDRESS, so that the end of the game lands at ENDING_ADDRESS, over the code for
; play, which is finished with. Nothing is stashed: the workspace is cleared and the
; filing system may use it as it likes, and the end of the game carries copies of what
; it needs from there, as assembled: the font with its WRCHV handler (which play code lies
; over), and the sprite tables. Once the workspace is claimed again they are copied back
; (ending_copies). What play left there is not restored, and is not needed. The screen
; stays on show, untouched. It lies with the code the end of the game keeps, as it runs
; through the load.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.load_ending
    lda #>(ENDING_FILE_ADDRESS)         ; Setup's load address, now high in memory...
    sta setup_osfile_block + 3          ; ...its high byte (the low bytes are both 0)
    lda #&15                            ; VDU 21: disable VDU output
    jsr oswrch                          ; ...during the load
    jsr clear_fs_workspace              ; Clear the workspace for the filing system
    jsr reselect_filing_system          ; The filing system takes its workspace back
    lda #osfile_load                    ; OSFILE &FF: load Setup and the end of the game...
    ldx #<(setup_osfile_block)          ; ...with setup_osfile_block
    ldy #>(setup_osfile_block)          ; ...
    jsr osfile                          ; Load it
    jsr claim_static_workspace          ; Take the workspace for the game again
    ldx #0                              ; Copy back what the end of the game needs
.next_ending_copy
    ldy #0                              ; Each copy's six bytes into plot_x onwards:
.load_ending_copy
    lda ending_copies,x                 ; ...from, to, and how many
    sta plot_x,y                        ; ...(plot_x, plot_y; sprite_width, sprite_height;
    inx                                 ; ...screen_ptr, screen_ptr_hi)
    iny                                 ; ...
    cpy #6                              ; ...
    bne load_ending_copy                ; ...
    txa                                 ; Keep the table's place...
    pha                                 ; ...
    jsr copy_bytes                      ; Copy them
    pla                                 ; ...
    tax                                 ; ...
    cpx #ending_copies_end - ending_copies  ; Both copies done?
    bne next_ending_copy                ; No: the next
    lda #6                              ; VDU 6: enable VDU output
    jmp oswrch                          ; ...and return
; The copies: from, to, and how many bytes.
.ending_copies
    equw ending_font_image, font_start, font_end - font_start
    equw ending_tables_image, sprite_addr_lo, sprite_tables_end - sprite_addr_lo
.ending_copies_end
; Copy screen_ptr (16 bits) bytes from (plot_x) to (sprite_width), a byte at a time.
.copy_bytes
    ldy #0                              ; The pointers themselves advance
.copy_byte
    lda (plot_x),y                      ; A byte...
    sta (sprite_width),y                ; ...copied
    inc plot_x                          ; Next source byte...
    bne copy_byte_to                    ; ...
    inc plot_y                          ; ...
.copy_byte_to
    inc sprite_width                    ; ...and destination byte
    bne copy_byte_count                 ; ...
    inc sprite_height                   ; ...
.copy_byte_count
    lda screen_ptr                      ; One fewer to copy...
    bne copy_byte_count_low             ; ...
    dec screen_ptr_hi                   ; ...
.copy_byte_count_low
    dec screen_ptr                      ; ...
    lda screen_ptr                      ; ...any left?
    ora screen_ptr_hi                   ; ...
    bne copy_byte                       ; Yes: the next
    rts                                 ; Return
