; Constants
title_plot_reversed          = &7b  ; Zero page flag for title_plot_star: non-zero plots each row right to left
star_x                       = &80  ; Zero page: each star's byte column (three stars)
star_y                       = &83  ; Zero page: each star's pixel row
star_frame                   = &86  ; Zero page: each star's animation frame, 0-6
star_frame_step              = &89  ; Zero page: each star's frame step, +1 or -1
star_place                   = &8c  ; Zero page: each star's place in star_places_x
game_next_level_intercept    = &15b5  ; The game's BREAK intercept that runs Coder for the next level
spr_no_small_digit           = &69  ; The game's sprite &69, drawn where a hero has no ten-thousands digit
opcode_jmp                   = &4c  ; The JMP opcode, which arms the MOS BREAK intercept
screen_start                 = &3000  ; The start of MODE 2 screen memory
osbyte_escape_break_effect   = &c8
osbyte_set_cursor_editing    = &04
osbyte_flush_buffer          = &15
osbyte_scan_keyboard_from_16 = &7a

; Memory locations
plot_x                   = &70  ; Star position: screen byte column.
plot_y                   = &71  ; Star position: pixel row.
sprite_width             = &72  ; Width of the frame being plotted, in screen bytes.
sprite_height            = &73  ; Height of the frame being plotted, in pixel rows.
screen_ptr               = &74  ; Screen address being written, low byte.
screen_ptr_hi            = &75  ; Screen address being written, high byte.
row_start_ptr            = &76  ; Screen address of the row being plotted, low byte.
row_start_ptr_hi         = &77  ; Screen address of the row being plotted, high byte.
sprite_data_ptr          = &78  ; Address of the next frame byte to plot, low byte.
sprite_data_ptr_hi       = &79  ; Address of the next frame byte to plot, high byte.
sprite_number            = &7a  ; Star frame to plot, 0-6.
os_zp_fa                 = &fa  ; MOS zero-page workspace, mixed into the choice of a star's place.
os_irq_a                 = &fc  ; The MOS's copy of A at the last interrupt, mixed into the choice of a star's place.
os_break_intercept       = &0287  ; MOS BREAK intercept: a JMP here is called during a reset. Dunjunz points it at the game's next-level intercept and arms it before running Coder.
hero_score_ten_thousands = &08b0  ; Each hero's score ten-thousands digit, as a small digit sprite; &69 for none.
hero_absent              = &08b4  ; Non-zero for each hero switched off on the menu.
levels_started           = &08bc  ; Number of levels started, kept by Coder in page &08, which survives the reset between levels.
level_digits             = &08bd  ; The level number as ASCII digits for the level's filename: one digit and a space, or two digits.
mos_row_offsets          = &c375  ; MOS 1.20's table of the offsets of the screen's character rows, high byte then low byte.
system_via_t1c_l         = &fe44
oswrch                   = &ffee
osbyte                   = &fff4
oscli                    = &fff7


    org &26c0

.dasmos_start
; ***************************************************************************************
; Load the title screen while output is off
;
; *DUNJUNZ is the Model B side's loader and title screen. It is run at title_start
; (&2700), whose banner describes the whole run: set up page &08 for Coder and the game,
; show the title picture with its twinkling stars until a key is pressed, then select the
; game's display and run Coder, which never returns. This first routine is one of its
; steps. Load the title picture, SCREEN, straight into MODE 2 screen memory at &3280 with
; VDU output disabled, then enable output again. Called once, by title_start, after it
; has selected MODE 2 and made all sixteen colours black, so the picture arrives unseen
; and appears all at once when title_start restores the colours. VDU 21 keeps any filing
; system message off the picture.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.load_title_screen
    lda #&15                            ; VDU 21: disable VDU output
    jsr oswrch                          ; ...so the load prints nothing over the picture
    ldx #<(load_screen_command)         ; *LOAD SCREEN: the title picture...
    ldy #>(load_screen_command)         ; ...(X, Y) = the command line
    jsr oscli                           ; ...straight into screen memory at &3280
    lda #6                              ; VDU 6: enable VDU output
    jsr oswrch                          ; ...so the VDU calls that follow take effect
    rts                                 ; Return with the picture in place, still unseen
; ***************************************************************************************
; Disable VDU output and run Coder
;
; The hand-over to Coder: VDU 21, then *CODER, which loads the level loader at &5000 and
; runs it; it does not return. Called last by title_start, once the game's display is
; selected and the BREAK intercept is armed. Coder starts with VDU output disabled, so no
; filing system message reaches the screen, and enables it again with VDU 6.
.leave_title
    lda #&15                            ; VDU 21: disable VDU output
    jsr oswrch                          ; ...so loading Coder prints nothing on the game screen
    ldx #<(coder_command)               ; *CODER: load and run the level loader
    ldy #>(coder_command)               ; ...(X, Y) = the command line
    jsr oscli                           ; ...never returns: Coder takes over the machine
; ***************************************************************************************
; Unused
;
; Leftover bytes.
    equb &0d, &36, &17, &00, &0d, &1e, &00, &2a
    equb &05, &14, &00, &15, &00, &00, &00, &00
    equb &2a, &00, &00, &04, &08, &00, &2a, &04
    equb &08, &2a, &15, &3c, &3d, &00, &33, &3c
    equb &39, &00                       ; Not used
; ***************************************************************************************
; Set up, show the title and run Coder
;
; The entry point of *DUNJUNZ (load &26C0, run at &2700), the loader and title screen. It
; is run when the disc is turned over to this side (the other side's BOOT asks for that
; and SPACE), and again after every game over, by the game's restart intercept (*DISC,
; *DUNJUNZ) during the reset that ends the game. The run is a straight line in four
; phases, marked by block comments below. Set-up: disable ESCAPE and make the cursor keys
; return codes. Page &08, which the reset between levels leaves alone: levels_started = 0
; and level_digits = "0 ", which Coder advances to 1 and "1 " before loading Level1; for
; each hero, hero_score_ten_thousands = &69 (no digit) and hero_absent = 0 (playing), so
; every game starts with all four heroes switched on in the menu. The BREAK intercept's
; address is set to &15B5 and left disabled. Title: select MODE 2 (*TV 255,1) with all
; sixteen colours black, load SCREEN unseen, restore the colours, and twinkle_stars until
; a key other than SHIFT or CTRL is pressed. Hand-over: select the game's display (*TV
; 252,1, MODE 2, cursor off), *DISC, arm the BREAK intercept as JMP &15B5, and
; leave_title disables VDU output and runs *CODER, which never returns. Coder starts with
; ESCAPE disabled, VDU output disabled, the page &08 values above and the intercept
; armed. Coder cancels the intercept among its first instructions, so it is armed only
; while *CODER loads. A BREAK in that time jumps to &15B5, which holds the game's
; next_level_intercept only if the game has already been played since power-on, as after
; a game over.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.title_start
    lda #osbyte_escape_break_effect     ; OSBYTE &C8: ESCAPE disabled...
    ldx #1                              ; ...X = 1: ESCAPE disabled, BREAK as normal...
    ldy #0                              ; ...Y = 0: X replaces the old setting
    jsr osbyte                          ; ...so the ESCAPE key cannot stop the program  osbyte: escape break effect
    lda #osbyte_set_cursor_editing      ; OSBYTE 4, 1: no cursor editing...
    ldx #1                              ; ...X = 1: the arrow keys and COPY give codes
    jsr osbyte                          ; ...instead of moving an editing cursor  Set cursor editing keys
; Page &08 values for Coder and the game: the level counter and filename digits Coder advances, and each hero's score digit and menu switch.
    lda #0                              ; Levels started = 0, for Coder
    sta levels_started                  ; ...in page &08, which survives a reset
    lda #'0'                            ; Level digits = "0 "...
    sta level_digits                    ; ...first digit '0'...
    lda #' '                            ; ...second digit a space
    sta level_digits + 1                ; ...for the level filename
    ldx #3                              ; For each hero...
.init_hero_tables
    lda #spr_no_small_digit             ; ...no ten-thousands digit (sprite &69)...
    sta hero_score_ten_thousands,x      ; ...in the score digit table at &08B0...
    lda #0                              ; ...and switched on...
    sta hero_absent,x                   ; ...at &08B4 (the menu tables)
    dex                                 ; Next hero, counting 3 down to 0
    bpl init_hero_tables                ; Until all four heroes are set
; Point the BREAK intercept at the game's next-level code, but leave it disabled until Coder is about to run.
    lda #<(game_next_level_intercept)   ; BREAK intercept address = &15B5 (the game's next-level intercept)...
    sta os_break_intercept + 1          ; ...as the JMP's address, low byte
    lda #>(game_next_level_intercept)   ; ...then its page, &15...
    sta os_break_intercept + 2          ; ...completing the JMP's address
    lda #0                              ; ...disabled for now: &0287 is not a JMP
    sta os_break_intercept              ; ...so a BREAK now does not run the game's code
; Title: select MODE 2 with every colour black, load the picture, restore the colours, then twinkle stars on it until a key is pressed.
    ldx #<(tv_title_command)            ; *TV 255,1: vertical shift -1 line, interlace off
    ldy #>(tv_title_command)            ; ...(X, Y) = the command line
    jsr oscli                           ; ...taking effect at the MODE change below
    jsr mode2_cursor_off                ; MODE 2, cursor off, for the title picture
    ldx #&0f                            ; Make all sixteen colours black, hiding the load...
.black_colours
    lda #&13                            ; ...VDU 19, colour, 0, 0, 0, 0...
    jsr oswrch                          ; ...VDU 19: redefine a logical colour...
    txa                                 ; ...logical colour X...
    jsr oswrch                          ; ...the colour being redefined
    lda #0                              ; ...zero for the four remaining bytes
    jsr oswrch                          ; ...physical colour 0: black
    jsr oswrch                          ; ...then the three bytes VDU 19 also takes
    jsr oswrch                          ; ...second of the three
    jsr oswrch                          ; ...third of the three
    dex                                 ; Next logical colour
    bpl black_colours                   ; Until colours 15 to 0 are all black
    jsr load_title_screen               ; Load the title picture, unseen in black
    nop                                 ; Padding: four NOPs that do nothing
    nop                                 ; ...the second of the four
    nop                                 ; ...the third of the four
    nop                                 ; ...the last of the four
    lda #&14                            ; VDU 20: default colours, showing the picture
    jsr oswrch                          ; ...so the loaded picture appears all at once
    lda #0                              ; Plot the stars left to right
    sta title_plot_reversed             ; ...so title_plot_star steps right across a row
    lda #osbyte_flush_buffer            ; OSBYTE &15: flush the buffer X
    jsr osbyte                          ; ...X is whatever OSCLI left: buffer unknown  Flush specific buffer X
    jsr twinkle_stars                   ; Twinkle stars until a key is pressed
; Hand-over: a key was pressed, so select the game's display and DFS, arm the BREAK intercept and run Coder.
    ldx #<(tv_game_command)             ; *TV 252,1: vertical shift -4 lines, interlace off
    ldy #>(tv_game_command)             ; ...(X, Y) = the command line
    jsr oscli                           ; ...taking effect at the MODE change below
    jsr mode2_cursor_off                ; MODE 2, cursor off: clears the title from the screen
    ldx #<(disc_command)                ; *DISC: select DFS...
    ldy #>(disc_command)                ; ...(X, Y) = the command line
    jsr oscli                           ; ...so *CODER is looked for on the disc
    lda #opcode_jmp                     ; Arm the BREAK intercept: &0287 = JMP, so a BREAK...
    sta os_break_intercept              ; ...now runs the game's next-level code at &15B5
    jsr leave_title                     ; Disable output and run Coder (no return)
    equb &ea                            ; Padding
    equb &ea                            ; ...never run: leave_title does not return
    equb &ea                            ; ...never run
    equb &ea                            ; ...never run
; The OSCLI command lines, each ended by a carriage return.
.load_screen_command
    equs "LOAD SCREEN", &0d             ; The title picture, for load_title_screen
.disc_command
    equs "DISC", &0d                    ; Select DFS, before *CODER
.coder_command
    equs "CODER", &0d                   ; Run the level loader
.tv_game_command
    equs "TV252 1", &0d                 ; Vertical shift -4, interlace off: the game
.tv_title_command
    equs "TV255 1", &0d                 ; Vertical shift -1, interlace off: the title
; ***************************************************************************************
; Select MODE 2 and turn the cursor off
;
; VDU 22,2 then VDU 23,0,10,&20,0,0,0,0,0,0 (6845 register 10: no cursor), from
; cursor_off_vdu. Called twice by title_start, each time just after a *TV, whose vertical
; shift the mode change brings into effect: once for the title picture and once for the
; game's display. Both times it clears the screen.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
.mode2_cursor_off
    lda #&16                            ; VDU 22, 2: MODE 2
    jsr oswrch                          ; ...selects a mode, clearing the screen...
    lda #2                              ; ...mode 2: 16 colours, 20 columns
    jsr oswrch                          ; ...sent as the mode number
    ldx #0                              ; Send VDU 23,0,10,&20,...: cursor off
.send_cursor_off_vdu
    lda cursor_off_vdu,x                ; Next byte of cursor_off_vdu...
    jsr oswrch                          ; ...to the VDU drivers
    inx                                 ; ...on to the next
    cpx #&0b                            ; ...until all eleven are sent
    bne send_cursor_off_vdu             ; Not yet: send the next
    rts                                 ; Return with MODE 2 clear and no cursor
; ***************************************************************************************
; Unused
;
; Leftover bytes.
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &0a, &00, &00, &00, &0a
    equb &00, &00, &00, &0a, &00, &00, &00, &0a
    equb &00                            ; Not used
; VDU 23,0,10,&20,0,0,0,0,0,0, sent byte by byte by mode2_cursor_off: &20 to 6845 register 10, the cursor start line, whose bits 5-6 = 01 turn the cursor off.
.cursor_off_vdu
    equb &17, &00, &0a, &20, &00, &00, &00, &00, &00, &00, &00  ; VDU 23,0,10,&20,0,0,0,0,0,0: cursor off
    equb &00, &00, &05, &07, &00        ; Not used
; ***************************************************************************************
; Plot a star frame on the title screen
;
; Exclusive-OR one frame of the star animation, 7 bytes (14 pixels) by 28 pixel rows,
; onto the MODE 2 title screen with its top left at byte column plot_x and pixel row
; plot_y. Because it is an exclusive-OR, plotting the same frame twice erases it and
; restores the picture beneath, which is how advance_stars and twinkle_stars remove a
; star. Called only through plot_star. The method is the game's plot_sprite, with the
; frame fixed at 7 by 28: title_screen_address gives the top left; each row steps 8 bytes
; (one character cell) per byte across, right or, if title_plot_reversed is non-zero,
; left; the next row starts one byte below the last row's start, and every eighth row
; &278 (640 - 8) further on, into the next character row. title_start sets
; title_plot_reversed to 0, so the stars are always plotted left to right. Leaves
; sprite_data_ptr just past the frame and screen_ptr below it.
;
; On Entry:
;     PLOT_X: byte column
;     PLOT_Y: pixel row
;     SPRITE_NUMBER: frame, 0-6
.title_plot_star
    lda #7                              ; Every star frame is seven bytes wide...
    sta sprite_width                    ; ...(14 MODE 2 pixels)...
    lda #&1c                            ; ...and 28 pixel rows high...
    sta sprite_height                   ; ...three and a half character rows
    ldx sprite_number                   ; Point at the frame's data...
    lda star_frames_lo,x                ; ...low byte from star_frames_lo
    sta sprite_data_ptr                 ; ...for the byte loop below
    lda star_frames_hi,x                ; ...high byte from star_frames_hi
    sta sprite_data_ptr_hi              ; ...the frames run on from &2A00
    jsr title_screen_address            ; Screen address of the star's top left
    ldx sprite_height                   ; For each pixel row of the frame...
.plot_star_row
    lda screen_ptr                      ; ...remember where the row starts...
    sta row_start_ptr                   ; ...to step down one pixel row from later
    lda screen_ptr_hi                   ; ...and the page of the row's start...
    sta row_start_ptr_hi                ; ...into row_start_ptr_hi
    txa                                 ; ...and keep the row count...
    pha                                 ; ...on the stack while X counts bytes
    ldx sprite_width                    ; ...for each byte across...
.plot_star_byte
    lda (sprite_data_ptr),y             ; ...exclusive-OR the frame onto the screen...
    eor (screen_ptr),y                  ; ...flip the screen pixels the frame sets...
    sta (screen_ptr),y                  ; ...so plotting twice erases the star
    lda title_plot_reversed             ; ...and step a character cell (8 bytes) right or left
    bne plot_star_left                  ; Non-zero: step left instead
    clc                                 ; Step right: screen_ptr + 8...
    lda screen_ptr                      ; ...screen pointer low byte...
    adc #8                              ; ...plus 8: the next cell to the right
    sta screen_ptr                      ; ...where the next frame byte goes
    bcc plot_star_next_data             ; No carry: pointer done
    inc screen_ptr_hi                   ; Carry into the high byte
    bne plot_star_next_data             ; ...always taken: screen pages are never 0
.plot_star_left
    sec                                 ; Step left: screen_ptr - 8...
    lda screen_ptr                      ; ...screen pointer low byte...
    sbc #8                              ; ...minus 8: the next cell to the left
    sta screen_ptr                      ; ...where the next frame byte goes
    bcs plot_star_next_data             ; No borrow: pointer done
    dec screen_ptr_hi                   ; Borrow from the high byte
.plot_star_next_data
    inc sprite_data_ptr                 ; Next byte of the frame
    bne plot_star_next_byte             ; No carry: pointer done
    inc sprite_data_ptr_hi              ; Carry into the high byte
.plot_star_next_byte
    dex                                 ; Next byte across
    bne plot_star_byte                  ; More bytes in this row: plot the next
    clc                                 ; Down one pixel row from the row's start...
    lda row_start_ptr                   ; ...from the row's start, low byte...
    adc #1                              ; ...plus one: the next byte in the cell
    sta screen_ptr                      ; ...is the next row's first byte
    lda row_start_ptr_hi                ; ...the row start's page...
    adc #0                              ; ...with the carry
    sta screen_ptr_hi                   ; ...completing the next row's address
    lda screen_ptr                      ; ...crossing into the next character row every eight (640 - 8 bytes on)
    and #7                              ; ...pixel row within the character row
    bne plot_star_next_row              ; Not 0: still in the same character row
    clc                                 ; Row 0: moved into the next character row...
    lda screen_ptr                      ; ...so add 640 - 8 to the pointer...
    adc #&78 ; 'x'                      ; ...low byte of &278...
    sta screen_ptr                      ; ...the top of the cell below
    lda screen_ptr_hi                   ; ...and screen_ptr's page...
    adc #2                              ; ...plus &02 with the carry
    sta screen_ptr_hi                   ; ...completing the address in the next character row
.plot_star_next_row
    pla                                 ; Recover the row count...
    tax                                 ; ...back into X as the rows left...
    dex                                 ; ...one row fewer to go
    bne plot_star_row                   ; More rows: plot the next
    rts                                 ; Return with the frame flipped onto the screen
; ***************************************************************************************
; Calculate a title screen address
;
; The MODE 2 screen address of byte column plot_x and pixel row plot_y: &3000 + the
; character row's offset (plot_y DIV 8, x 640) + plot_y MOD 8 + 8 x plot_x. The row
; offsets are read from MOS 1.20's table at &C375, so this loader relies on that ROM. It
; is a copy of the game's screen_address. Called only by title_plot_star, for a star's
; top left.
;
; On Entry:
;     PLOT_X: byte column
;     PLOT_Y: pixel row
;
; On Exit:
;     SCREEN_PTR: screen address
;     Y: 0
.title_screen_address
    lda plot_y                          ; Character row x 2...
    lsr a                               ; ...divide plot_y by 4...
    lsr a                               ; ...(character row x 2)...
    and #&fe                            ; ...even, to index the table's byte pairs
    tay                                 ; ...as Y, indexing the row offset table
    lda mos_row_offsets,y               ; High byte of row x 640, from the MOS table...
    clc                                 ; ...plus &3000, the screen start
    adc #>(screen_start)                ; ...the screen starts at &3000
    sta screen_ptr_hi                   ; ...as the high byte
    lda mos_row_offsets + 1,y           ; Low byte of row x 640
    sta screen_ptr                      ; ...as the low byte
    lda plot_y                          ; Plus the pixel row within the character row
    and #7                              ; ...plot_y MOD 8...
    adc screen_ptr                      ; ...added to the low byte (no carry out)
    sta screen_ptr                      ; ...the row's byte within each cell
    clc                                 ; Plus 8 x byte column: high part...
    lda plot_x                          ; ...plot_x DIV 32, the page share of 8 x plot_x...
    and #&e0                            ; ...top three bits, worth &100 each x 8...
    rol a                               ; ...rotated through carry four times...
    rol a                               ; ...towards the bottom...
    rol a                               ; ...of the byte...
    rol a                               ; ...as bits 2-0: the high byte's share
    clc                                 ; ...to add to the high byte...
    adc screen_ptr_hi                   ; ...plus the row's page...
    sta screen_ptr_hi                   ; ...in the screen pointer
    lda plot_x                          ; ...then the low byte of 8 x plot_x...
    asl a                               ; ...plot_x x 2...
    asl a                               ; ...plot_x x 4...
    asl a                               ; ...x 8: eight bytes per character cell
    clc                                 ; ...to add to the low byte...
    adc screen_ptr                      ; ...plus the row's low byte...
    sta screen_ptr                      ; ...in the screen pointer
    bcc title_screen_address_done       ; No carry: address done
    inc screen_ptr_hi                   ; Carry into the high byte
.title_screen_address_done
    ldy #0                              ; Y = 0 for the plotter's (ptr),Y accesses
    rts                                 ; Return with screen_ptr set and Y = 0
; ***************************************************************************************
; Unused
;
; Leftover bytes.
    equb &0d, &18, &a5, &74, &69, &78, &85, &74
    equb &a5, &75, &69, &02, &85, &75, &68  ; Not used
; Low bytes of the seven star frames' addresses (&2A00 + &C4 x frame), indexed by frame 0-6 and read by title_plot_star.
.star_frames_lo
    equb &00, &c4, &88, &4c, &10, &d4, &98  ; Frames 0-6, low bytes
    equb &15, &4a, &29, &fe, &a8, &b9, &75, &c3, &18  ; Not used
; High bytes of the seven star frames' addresses, indexed by frame 0-6 and read by title_plot_star.
.star_frames_hi
    equb &2a, &2a, &2b, &2c, &2d, &2d, &2e  ; Frames 0-6, high bytes
    equb &22, &74, &a5, &71, &29, &07, &65, &74
    equb &85, &2a, &2a, &2b, &2c, &2d, &2d, &2e
    equb &22, &2a, &2a, &18, &65, &75, &85, &75
    equb &a5, &70, &0a, &0a, &0a, &18, &65, &74
    equb &85, &74, &90, &02, &e6, &75, &a0, &00
    equb &00                            ; Not used
; ***************************************************************************************
; Twinkle stars on the title screen until a key is pressed
;
; The title screen's wait for a key. Called once by title_start, after the picture is
; shown. Up to three stars twinkle at once, each at one of the eight places in
; star_places_x and star_places_y, picked at random. A star grows through frames 0-6 and
; shrinks back through 5-0, then disappears and frees its place. Each pass of the loop:
; when the low two bits of the System VIA's timer 1 are 0 (about one pass in four),
; start_star starts a star if one is free; advance_stars moves every star on a frame and
; pauses, which sets the pace; then OSBYTE &7A scans the keyboard from key 16, so SHIFT
; and CTRL alone do not end the title. When a key is pressed the stars still showing are
; erased, though the MODE change that title_start makes next clears the screen anyway.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.twinkle_stars
    ldx #2                              ; No stars showing
    lda #0                              ; ...0 for every star
.clear_star_showing
    sta star_showing,x                  ; ...in star X's star_showing flag...
    dex                                 ; ...then the star below
    bpl clear_star_showing              ; Until stars 2 to 0 are cleared
.twinkle_loop
    lda system_via_t1c_l                ; One time in four (System VIA timer 1, low bits)...
    and #3                              ; ...lowest two bits, 0-3...
    bne twinkle_advance                 ; Not 0: no new star this time
    jsr start_star                      ; ...start a star, if one of the three is free
.twinkle_advance
    jsr advance_stars                   ; Grow or shrink every star a frame, then pause
    lda #osbyte_scan_keyboard_from_16   ; OSBYTE &7A: any key other than SHIFT or CTRL?
    jsr osbyte                          ; ...X = the key number, &FF if none  Scan keyboard from key 16
    cpx #&ff                            ; ...&FF: no key held down?
    beq twinkle_loop                    ; No key: keep twinkling
    ldy #2                              ; Yes: erase the stars still showing...
.erase_stars
    lda star_showing,y                  ; ...star Y showing?
    beq erase_next_star                 ; No: nothing to erase
    jsr plot_star                       ; Yes: plot it again to erase it
.erase_next_star
    dey                                 ; Next star down
    bpl erase_stars                     ; Until stars 2 to 0 are done
    rts                                 ; Return: a key is down and the stars are gone
; ***************************************************************************************
; Start a star at a free place
;
; Take the first of the three stars not showing, if any, mark it in star_showing, give it
; frame 0 and step +1, choose a free place at random, mark the place taken and plot the
; first frame. Called by twinkle_stars about one pass in four. The random number is
; System VIA timer 1's low byte exclusive-ORed with &FA and &FC (the MOS's copy of A at
; the last interrupt), taking the low three bits; a place already taken is retried, which
; always ends because at most three of the eight places are taken.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.start_star
    ldy #0                              ; Find a star not showing...
.find_free_star
    lda star_showing,y                  ; ...star Y showing?
    beq star_found                      ; No: use this one
    iny                                 ; Yes: try the next
    cpy #3                              ; ...of the three
    bne find_free_star                  ; Not all tried: carry on looking
    rts                                 ; All three showing: return
.star_found
    lda #1                              ; Mark it showing
    sta star_showing,y                  ; ...setting its star_showing flag to 1
    lda #1                              ; Frame step +1...
    sta star_frame_step,y               ; ...the star starts by growing
    lda #0                              ; ...from frame 0
    sta star_frame,y                    ; ...the smallest, in star_frame
.pick_place
    lda system_via_t1c_l                ; Pick a place at random (timer, &FA and &FC mixed)...
    eor os_zp_fa                        ; ...mixed with OS workspace...
    eor os_irq_a                        ; ...and the last interrupt's A...
    and #7                              ; ...one of the eight places
    tax                                 ; ...as the place index
    lda star_places_x,x                 ; ...that no other star is using
    bmi pick_place                      ; Taken (&FF): pick again; three stars leave five free
    sta star_x,y                        ; The star's byte column, from the place...
    lda star_places_y,x                 ; ...its pixel row...
    sta star_y,y                        ; ...as the star's row
    stx star_place,y                    ; ...remembering the place, to free it later
    lda #&ff                            ; Mark the place taken
    sta star_places_x,x                 ; ...by setting its column to &FF
    jsr plot_star                       ; Plot the first frame
    rts                                 ; Return with the new star on the screen
; ***************************************************************************************
; Advance each star by one frame
;
; One frame of the twinkle, called by twinkle_stars on every pass. For each of the three
; stars in turn: if it is showing, erase its frame (plotting it again) and add its step
; to star_frame; past frame 6 it shows frame 5 and its step becomes -1, and below frame 0
; it is finished, cleared in star_showing and its place freed in star_places_x; otherwise
; plot the new frame. Then pause: 5 x 255 loops after a star that is showing or has just
; finished, 20 x 255 for a star not showing. These pauses set the speed of the twinkle.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.advance_stars
    ldy #0                              ; For each star...
.advance_star
    lda star_showing,y                  ; ...is star Y showing?
    beq star_not_showing                ; No: just pause, for longer
    jsr plot_star                       ; Erase its frame (plotting it again)
    clc                                 ; Step the frame
    lda star_frame,y                    ; ...the star's current frame...
    adc star_frame_step,y               ; ...plus the step, +1 or -1...
    sta star_frame,y                    ; ...as the frame to show next
    bmi star_finished                   ; Shrunk below frame 0: the star has gone
    cmp #7                              ; Grown past frame 6, the largest?
    bcc plot_new_frame                  ; No: plot it
    lda #5                              ; Yes: frame 5 instead...
    sta star_frame,y                    ; ...so frame 6 shows once at the peak...
    lda #&ff                            ; ...and from now on...
    sta star_frame_step,y               ; ...step -1, so the star shrinks
    bmi plot_new_frame                  ; ...and plot it (always branches)
.star_finished
    lda #0                              ; Gone: not showing...
    sta star_showing,y                  ; ...cleared in star_showing...
    lda star_x,y                        ; ...and free its place
    ldx star_place,y                    ; ...by putting its column back...
    sta star_places_x,x                 ; ...over the &FF in star_places_x
    bpl star_pause                      ; ...then pause (always branches: place 0-7)
.plot_new_frame
    jsr plot_star                       ; Plot the new frame
.star_pause
    tya                                 ; Pause, setting the twinkle's speed...
    pha                                 ; ...keeping Y, the star...
    ldx #5                              ; ...5 x 255 loops after a star is drawn
.star_pause_outer
    ldy #&ff                            ; ...X x 255 iterations...
.star_pause_inner
    dey                                 ; ...count the inner loop...
    bne star_pause_inner                ; Inner loop not done: keep waiting
    dex                                 ; ...count the outer loop...
    bne star_pause_outer                ; Outer loop not done: keep waiting
    pla                                 ; ...recover the star...
    tay                                 ; ...back into Y as the star index
    iny                                 ; Next star up
    cpy #3                              ; ...of the three
    bne advance_star                    ; More stars: advance the next
    rts                                 ; Return with every star moved on a frame
; ***************************************************************************************
; Plot star Y's current frame
;
; Call title_plot_star with the star's position (star_x, star_y) and frame (star_frame),
; keeping Y. Being an exclusive-OR, the same call both draws and erases a star:
; start_star, advance_stars and twinkle_stars use it for both.
;
; On Entry:
;     Y: star, 0-2
;
; On Exit:
;     Y: preserved
.plot_star
    lda star_x,y                        ; plot_x = star's column
    sta plot_x                          ; ...the left edge of the frame
    lda star_y,y                        ; plot_y = star's row
    sta plot_y                          ; ...the top of the frame
    lda star_frame,y                    ; sprite_number = star's frame
    sta sprite_number                   ; ...selecting one of the seven sizes
    tya                                 ; Plot it, keeping Y
    pha                                 ; ...on the stack
    jsr title_plot_star                 ; ...exclusive-OR the frame on screen
    pla                                 ; ...recover the star...
    tay                                 ; ...back into Y, as on entry
    rts                                 ; Return with the frame flipped and Y kept
.star_not_showing
    tya                                 ; Star not showing: pause for longer...
    pha                                 ; ...keeping Y, the star...
    ldx #&14                            ; ...20 x 255 loops instead of 5 x 255
    bne star_pause_outer                ; ...always taken: X = 20, into the pause loop
    equb &38, &38, &3e, &3e             ; Not used
; One flag per star, indexed by star 0-2: 1 while the star is showing, 0 when it is not. Cleared by twinkle_stars at the start (the bytes in the file are never read), set by start_star, cleared by advance_stars when a star shrinks away.
.star_showing
    equb &38, &38, &3e                  ; Stars 0-2, cleared before use
    equb &3e, &38, &38                  ; Not used
; The byte columns (0-79) of the eight places a star can appear, indexed by place 0-7. start_star copies a place's column to star_x and writes &FF there to mark the place taken; advance_stars writes the column back from star_x when the star has gone.
.star_places_x
    equb &2f, &20, &05, &00, &1f, &46, &46, &14  ; Places 0-7: byte columns
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Not used
; The pixel rows of the eight places' top edges, indexed by place 0-7 and read by start_star into star_y.
.star_places_y
    equb &0f, &0f, &24, &42, &33, &0f, &48, &15  ; Places 0-7: pixel rows
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Not used
; The seven frames of the star, 7 bytes by 28 rows each, at &C4-byte intervals.
; ***************************************************************************************
; Star frames
;
; Seven 7-byte by 28-row MODE 2 frames of the title screen's twinkling star, from small
; (frame 0) to large (frame 6).
.star_frame_data
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &15, &1f, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Frame 0: 7 bytes by 28 rows
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &2a, &0a, &2a, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Frame 1: 7 bytes by 28 rows
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &15, &2a, &00, &3f, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Frame 2: 7 bytes by 28 rows
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &2a, &2a, &00, &2a, &2a, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Frame 3: 7 bytes by 28 rows
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &15, &15, &2a, &00, &3f, &15, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Frame 4: 7 bytes by 28 rows
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &2a, &2a, &2a, &00, &2a, &2a, &2a
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Frame 5: 7 bytes by 28 rows
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &2a, &3f, &2a, &00, &3f, &2a, &2a
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00
    equb &00, &00, &00, &2a, &00, &00, &00  ; Frame 6: 7 bytes by 28 rows
.dasmos_end

save "Dunjunz", dasmos_start, dasmos_end, &2700, &26c0
