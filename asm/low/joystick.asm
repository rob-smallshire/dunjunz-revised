; ***************************************************************************************
; Add 1000 to a hero's score
;
; Carry a point into the thousands of hero X's score. add_ten_points calls it whenever
; the hundreds digit passes 9, and on return its draw_score redraws the four large digits
; (thousands to units) in the hero's panel section. The panel has room for only those
; four, so when the thousands digit passes 9 it goes back to 0 and the ten-thousands
; digit (hero_score_ten_thousands, a small digit sprite) goes up. That digit sticks at 9,
; so beyond 99,999 the large digits wrap while the small one stays at 9. Each change of
; the ten-thousands digit is drawn at draw_ten_thousands: the small digit &18 rows below
; the hero's panel row, under the score, followed by four of sprite &71. Sprite &71, the
; small 8, is a solid bar two pixels wide, the same shape a small 0 would have, so the
; line reads as a small N0000. remove_absent_heroes enters at draw_ten_thousands with the
; digit in A, to redraw the line on the fresh screen of each level. Uses plot_x, plot_y
; and sprite_number.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.add_thousand_points_joystick
    inc hero_score_thousands,x          ; One more thousand: the hundreds digit carried
    lda hero_score_thousands,x          ; ...and check the new digit
    cmp #spr_digit_9 + 1                ; Past 9: another ten thousand?
    bne add_thousand_points_done_joystick  ; No: return; draw_score shows the new digit
    lda #spr_digit_0                    ; Yes: thousands 0...
    sta hero_score_thousands,x          ; ...stored for this hero
    inc page6_score_ten_thousands_joystick,x  ; ...and carry into the small ten-thousands digit
    lda page6_score_ten_thousands_joystick,x  ; ...and check the new digit
    cmp #spr_small_digit_9 + 1          ; Past small 9: a score of 100,000?
    bne draw_ten_thousands_joystick     ; No: draw it under the score
    lda #spr_small_digit_9              ; Yes: it sticks at 9
    sta page6_score_ten_thousands_joystick,x  ; ...stored for this hero
.draw_ten_thousands_joystick
    sta sprite_number                   ; Plot the ten-thousands digit under the score...
    lda #panel_left                     ; ...at the panel's left column
    sta plot_x                          ; ...as the plot column
    lda workspace_template + 208,x      ; ...hero_panel_y, read from workspace_template
    clc                                 ; ...(carry clear for the add)
    adc #&18                            ; ...+ &18: below the score's rows, &0C-&15
    sta plot_y                          ; ...as the plot row
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack while plotting
    jsr plot_sprite                     ; Plot the ten-thousands digit
    lda #spr_small_digit_8              ; ...then four small 0s after it: sprite &71...
    sta sprite_number                   ; ...(small 8, a solid bar, the shape of a small 0)
    ldy #4                              ; ...four of them, for the 0000
.draw_ten_thousands_loop_joystick
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack while plotting
    inc plot_x                          ; Two byte columns right...
    inc plot_x                          ; ...a small digit's width on
    jsr plot_sprite                     ; Plot a 0 there
    pla                                 ; Recover the count...
    tay                                 ; ...of 0s still to plot, in Y
    dey                                 ; One fewer 0 to plot
    bne draw_ten_thousands_loop_joystick  ; More 0s: loop
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again, as on entry
.add_thousand_points_done_joystick
    rts                                 ; Return to draw_score (or remove_absent_heroes)
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
; Data of sprite &15, &1A, &77: 4 bytes x 12 rows.
.sprite_blank_joystick
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00                            ; Not referenced
; ***************************************************************************************
; Choose the heroes and the sound
;
; The screen before each game where the players choose who plays. It is called once per
; game, when a new game starts, after reset_hero has given every hero their starting
; attributes and before the first level. Set a text window the full width of the screen
; (MODE 2's 20 columns) and clear it, print the menu (print_menu) and read keys until
; SPACE. Keys 1-4 toggle a hero between YES and NO by flipping their hero_absent flag and
; rewriting the menu entry; 5 and 6 switch the sound on and off with OSBYTE &D2. After
; each change the whole menu is reprinted. SPACE returns, so the game starts, only if at
; least one hero is playing. Before each key is read, the keyboard buffer is flushed and
; CAPS LOCK is forced on with SHIFT LOCK off.
;
; Neither hero_absent nor the menu text is set up here: the menu opens with whatever they
; held, which after a game over in the same load is the last game's choices. The ON/OFF
; entry shows only what was last chosen on the menu, not the sound suppression actually
; in force. hero_absent is read by remove_absent_heroes at each level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.hero_menu_joystick
    lda #&1c                            ; VDU 28: the menu's window, the screen's full width...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
    lda #&16                            ; Bottom row of the window
    jsr oswrch                          ; Send the bottom row
    lda #&13                            ; Right column 19, MODE 2's last
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Send VDU 12: clear the window
    jsr print_menu_joystick             ; Print the menu
    jmp menu_key_loop_joystick          ; Read keys until the players start the game
; ***************************************************************************************
; Print the menu text
;
; Print the sixteen positioned strings of menu_text, in their current state, through
; print_menu_string: fifteen in a loop and the sixteenth by falling into
; print_menu_string, whose return is this routine's. Called by hero_menu to show the menu
; and after every change.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.print_menu_joystick
    ldx #&0f                            ; Fifteen strings, then one more by falling through
    ldy #0                              ; Y walks through menu_text from its start
.print_menu_loop_joystick
    jsr print_menu_string_joystick      ; Print one menu string
    dex                                 ; One fewer to print
    bne print_menu_loop_joystick        ; More to print: loop
; ***************************************************************************************
; Print one menu string
;
; Move the text cursor to the column and row in the two bytes at menu_text+Y, then print
; the following characters up to and including a carriage return.
;
; On Entry:
;     Y: offset of the string in menu_text
;
; On Exit:
;     Y: offset of the next string
.print_menu_string_joystick
    lda #&1f                            ; VDU 31: move the text cursor...
    jsr oswrch                          ; Send VDU 31
    lda menu_text_joystick,y            ; ...to the string's column...
    jsr oswrch                          ; Send the column
    iny                                 ; Step to the row byte
    lda menu_text_joystick,y            ; ...and the string's row...
    jsr oswrch                          ; Send the row
.print_menu_string_loop_joystick
    iny                                 ; Print the characters...
    lda menu_text_joystick,y            ; ...the next character...
    jsr oswrch                          ; ...sent to the screen...
    cmp #&0d                            ; ...up to and including the carriage return
    bne print_menu_string_loop_joystick ; Not the CR yet: next character
    iny                                 ; Point at the next string
    rts                                 ; Return with Y at the next string's column byte
; ***************************************************************************************
; Change a menu entry to NO
;
; Write "NO " over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; off. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
.set_menu_no_joystick
    lda #'N'                            ; "NO ": N first...
    sta menu_text_joystick,y            ; ...into the entry's first letter
    lda #'O'                            ; ...then O...
    sta menu_text_joystick + 1,y        ; ...into the second letter
    lda #' '                            ; A space third, over YES's S...
    sta menu_text_joystick + 2,y        ; ...into the third letter
    rts                                 ; Return: the entry reads NO
; ***************************************************************************************
; Change a menu entry to YES
;
; Write "YES" over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; on. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
.set_menu_yes_joystick
    lda #'Y'                            ; "YES": Y first...
    sta menu_text_joystick,y            ; ...into the entry's first letter
    lda #'E'                            ; ...then E...
    sta menu_text_joystick + 1,y        ; ...into the second letter
    lda #'S'                            ; ...then S...
    sta menu_text_joystick + 2,y        ; ...into the third letter
    rts                                 ; Return: the entry reads YES
; ***************************************************************************************
; Change the sound entry to OFF
;
; Write "FF" at menu_text+Y, after the sound entry's "O", when key 6 turns the sound off.
;
; On Entry:
;     Y: offset of the entry's second character
.set_menu_off_joystick
    lda #'F'                            ; "FF" after the O
    sta menu_text_joystick,y            ; ...over the N of ON...
    sta menu_text_joystick + 1,y        ; ...and the space after it
    rts                                 ; Return: the entry reads OFF
; ***************************************************************************************
; Change the sound entry to ON
;
; Write "N " at menu_text+Y, after the sound entry's "O", when key 5 turns the sound on.
;
; On Entry:
;     Y: offset of the entry's second character
.set_menu_on_joystick
    lda #'N'                            ; "N " after the O
    sta menu_text_joystick,y            ; ...over OFF's first F
    lda #' '                            ; ...then a space...
    sta menu_text_joystick + 1,y        ; ...over OFF's second F
    rts                                 ; Return: the entry reads ON
; Read one key and act on it, then come back for the next, until SPACE starts the game.
.menu_key_loop_joystick
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard any keys already waiting  Flush selected class of buffer
    lda #osbyte_kbd_status              ; OSBYTE &CA: set the keyboard lock states...
    ldx #&20 ; ' '                      ; X = &20: CAPS LOCK on, SHIFT LOCK off
    ldy #0                              ; Y = 0: replace the status with X
    jsr osbyte                          ; Set it, whatever the Ranger's lock keys left  osbyte: kbd status
    jsr osrdch                          ; Wait for a key
    cmp #' '                            ; SPACE, to start the game?
    beq menu_space_joystick             ; Yes: start, if anyone is playing
    cmp #'1'                            ; Ignore anything but 1-6
    bcc menu_key_loop_joystick          ; Below '1': ignore it
    cmp #'7'                            ; ...or above '6' (at or past '7')?
    bcs menu_key_loop_joystick          ; Yes: ignore it
    sec                                 ; Key number 0-5 = key - '1'...
    sbc #'1'                            ; ...so keys '1'-'6' become 0-5...
    tax                                 ; ...in X: a hero 0-3, or 4-5 for the sound
    cmp #4                              ; Key 5 or 6?
    bcs menu_sound_key_joystick         ; Yes: the sound switch
; Keys 1-4: switch hero X between playing and absent, and show it as YES or NO.
    asl a                               ; 1-4: Y = offset of the hero's YES/NO, 6 x X + &51...
    sta plot_x                          ; Keep 2 x the hero number
    asl a                               ; 4 x the hero number...
    clc                                 ; ...(carry clear for the add)
    adc plot_x                          ; ...+ 2 x: 6 x the hero number
    adc #&51 ; 'Q'                      ; ...+ &51: this hero's YES/NO text
    tay                                 ; Y = its offset in menu_text
    lda hero_absent,x                   ; Toggle the hero between playing and absent...
    eor #1                              ; ...by flipping the absent flag
    sta hero_absent,x                   ; ...the hero's new absent flag
    bne menu_hero_off_joystick          ; Now absent (flag 1)?
    jsr set_menu_yes_joystick           ; No: playing, so the entry reads YES
    jmp menu_reprint_joystick           ; ...and reprint the menu
.menu_hero_off_joystick
    jsr set_menu_no_joystick            ; Absent: the entry reads NO
.menu_reprint_joystick
    jsr print_menu_joystick             ; Reprint the menu with the change
    jmp menu_key_loop_joystick          ; Wait for the next key
; SPACE: return, so the game starts, if at least one hero is playing; otherwise ignore it.
.menu_space_joystick
    ldx #3                              ; SPACE: is any hero playing?
.menu_space_check_hero_joystick
    lda hero_absent,x                   ; Is this hero playing (absent flag 0)?
    beq menu_done_joystick              ; Yes: return, and the game starts
    dex                                 ; Absent: try the previous hero
    bpl menu_space_check_hero_joystick  ; Heroes left to check: loop
    jmp menu_key_loop_joystick          ; Nobody playing: ignore SPACE
.menu_done_joystick
    rts                                 ; Return: the game goes on to its first level
; Keys 5 and 6: sound on or off, through OSBYTE &D2, and the menu's entry to match.
.menu_sound_key_joystick
    ldy #&99                            ; Sound: Y = offset of the second letter of ON/OFF
    cmp #5                              ; Key 6 (A = key - "1")?
    beq menu_sound_off_joystick         ; Yes: sound off
    jsr set_menu_on_joystick            ; Key 5: ON...
    ldx #0                              ; ...with X = 0 to enable the sound
    beq menu_set_sound_joystick         ; Always: set the sound
.menu_sound_off_joystick
    jsr set_menu_off_joystick           ; Key 6: OFF...
    ldx #1                              ; ...with X = 1 to suppress it
.menu_set_sound_joystick
    lda #osbyte_sound_suppression       ; OSBYTE &D2: sound suppression
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Turn the sound on or off as chosen  osbyte: sound suppression
    jsr print_menu_joystick             ; Reprint the menu with the change
    jmp menu_key_loop_joystick          ; Wait for the next key
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &4f                       ; Not referenced
; The hero menu: sixteen strings, each a text column and row followed by the characters and a carriage return. The YES/NO and ON/OFF entries are rewritten as the players toggle them.
; ***************************************************************************************
; Hero menu text
;
; Sixteen entries of: column, row, text, carriage return; printed in order by print_menu,
; each at its own text position. The four heroes' YES/NO entries (text at menu_text + &51
; + 6 x hero) are rewritten by set_menu_yes and set_menu_no, and the sound entry's ON/OFF
; (second letter at menu_text + &99) by set_menu_on and set_menu_off, so the table holds
; the players' choices as well as showing them.
.menu_text_joystick
    equb &06, &00                       ; Column 6, row 0
    equs "DUNJUNZ", &0d
    equb &00, &02                       ; Column 0, row 2
    equs "HERO", &0d
    equb &0c, &02                       ; Column 12, row 2
    equs "PLAYING", &0d
    equb &00, &04                       ; Column 0, row 4
    equs "1 RANGER", &0d
    equb &00, &05                       ; Column 0, row 5
    equs "2 MAGIC-USER", &0d
    equb &00, &06                       ; Column 0, row 6
    equs "3 BARBARIAN", &0d
    equb &00, &07                       ; Column 0, row 7
    equs "4 FIGHTER", &0d
    equb &0e, &04                       ; Column 14, row 4
    equs "YES", &0d
    equb &0e, &05                       ; Column 14, row 5
    equs "YES", &0d
    equb &0e, &06                       ; Column 14, row 6
    equs "YES", &0d
    equb &0e, &07                       ; Column 14, row 7
    equs "YES", &0d
    equb &00, &09                       ; Column 0, row 9
    equs "TYPE NUMBER", &0d
    equb &00, &0a                       ; Column 0, row 10
    equs "TO TOGGLE", &0d
    equb &00, &0d                       ; Column 0, row 13
    equs "SOUND ON(5) OFF(6)", &0d
    equb &07, &0f                       ; Column 7, row 15
    equs "ON ", &0d
    equb &03, &14                       ; Column 3, row 20
    equs "SPACE TO PLAY", &0d
    equb &00, &0d, &a9, &63             ; Not referenced
; ***************************************************************************************
; Take the heroes nobody plays out of the level
;
; The last step of setting up each level, called by level_loop after draw_status_panel
; and just before play_level. For each hero in turn:
;
; First redraw the small ten-thousands line under the score, if it has one (through
; draw_ten_thousands), since start_level cleared the screen and draw_status_panel draws
; only the four large digits.
;
; Then, if the hero was switched off on the menu (hero_absent), take them out of play,
; since reset_workspace has just given every hero their starting state: direction 0;
; step_out_of_play, so move_heroes passes over them; frame 8 and dead health, so that
; play_level treats them as dead with their death animation over, and level_loop counts
; them among the dead (and resets them) when the level ends; map x &1F; and a
; nobody_returns entry in returning_hero_queue, which reset_monsters has just emptied.
; The absent heroes' entries go at the front of the queue, in hero order; a Cross of
; Resurrection sends such an entry to the back and takes the next. Their panel section
; keeps the health and score just drawn.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.remove_absent_heroes_joystick
    ldx #0                              ; Hero 0 first...
    ldy #0                              ; ...Y = the queue entry for the next absent hero
.remove_absent_heroes_loop_joystick
    lda hero_score_ten_thousands,x      ; Score of 10000 or more?
    cmp #spr_small_digit_1              ; ...ten-thousands sprite small 1 or above?
    bcc remove_absent_heroes_check_joystick  ; No: nothing under the score; check absence
    txa                                 ; Yes: redraw it, lost when the screen was cleared
    pha                                 ; Keep the hero number...
    tya                                 ; ...and the queue entry...
    pha                                 ; ...on the stack
    lda hero_score_ten_thousands,x      ; The digit's sprite...
    jsr draw_ten_thousands_joystick     ; ...drawn under the score with its 0000
    pla                                 ; Recover the queue entry...
    tay                                 ; ...for the next absent hero, in Y
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again
; Take the hero out of play if nobody is playing them, so that they count as dead, and a Cross of Resurrection passes over their queue entry.
.remove_absent_heroes_check_joystick
    lda hero_absent,x                   ; Switched off on the menu?
    beq remove_absent_heroes_next_joystick  ; No: playing; next hero
    lda #0                              ; Yes: take them out of play...
    sta hero_direction,x                ; ...direction 0: not in play
    lda #step_out_of_play               ; ...step &63, so move_heroes passes them over...
    sta hero_step,x                     ; ...as the hero's step count
    lda #8                              ; ...frame 8: their death animation is over...
    sta hero_frame,x                    ; ...as the hero's frame
    lda #spr_digit_0 - 1                ; ...health tens below 0: dead...
    sta hero_health_tens,x              ; ...as the health tens digit
    dec hero_score_units,x              ; ...units back below 0, undoing the panel's point
    lda #&1f                            ; ...map x &1F, the dungeon's last column...
    sta hero_x,x                        ; ...as the hero's map x
    lda #nobody_returns                 ; ...and a nobody_returns entry in the queue...
    sta returning_hero_queue,y          ; ...which a Cross of Resurrection skips
    iny                                 ; The next absent hero takes the next entry
.remove_absent_heroes_next_joystick
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four heroes done?
    bne remove_absent_heroes_loop_joystick  ; No: next hero
    rts                                 ; Return to level_loop: the level is ready to play
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00                       ; Zeros
; Each hero's score ten-thousands digit where add_thousand_points still keeps it, at its cassette address. Every other routine uses hero_score_ten_thousands at &08B0, and Coder reloads this page for every level, so the digit is lost between levels.
.page6_score_ten_thousands_joystick
    equs "iiii"
    equb &00, &00, &00, &00             ; Not referenced
; Leftover contents of the MOS 1.20 line-input buffer (&0700) from the machine the image was saved on.
; ***************************************************************************************
; Leftovers in the line-input buffer
;
; Not used by the game. &0700 is the MOS 1.20 line-input buffer, and these bytes are what
; it held when this image was saved: the command *SA. Control 400+3FF, then a fragment of
; BBC BASIC assembler (label+2:LDA#255:.label JSR&30).
.line_buffer_leftovers_joystick
    equs "*SA. Control 400+3FF"
    equb &0d, &0d, &0d                  ; Not referenced
    equs "740"
    equb &0d                            ; Not referenced
    equb &0d, &54, &50, &0d, &0d, &50, &0d  ; Not referenced
    equs "Alabel+2:LDA#255:.label JSR&30"
; ***************************************************************************************
; Load the game file and run it (not used)
;
; Point BYTEV at joystick_bytev (&0780), then build an OSFILE control block at &6B00
; naming boot_filename with load address &2000, call the filing system's FILEV handler to
; load the file, and jump to &2000. &0740 is the execution address in the *SAVE command
; left at &0700, so this is the image's own entry point when it is *RUN, but nothing in
; this release reaches it.
.boot_loader_joystick
    lda #<(joystick_bytev)              ; BYTEV = &0780, joystick_bytev...
    sta bytev                           ; ...joystick_bytev's low byte into BYTEV
    lda #>(joystick_bytev)              ; ...its high byte
    sta bytev + 1                       ; ...so INKEY scans reach the joystick handler
    ldx #<(boot_osfile_block)           ; X/Y = &6B00, the control block...
    ldy #>(boot_osfile_block)           ; ...Y = &6B, its page
    lda #<(boot_filename_joystick)      ; Filename address: boot_filename...
    sta boot_osfile_block               ; ...into the block's filename pointer, low byte
    lda #>(boot_filename_joystick)      ; ...boot_filename's high byte
    sta boot_osfile_block + 1           ; ...into the filename pointer's high byte
    lda #0                              ; Load address &00002000...
    sta boot_osfile_block + 2           ; ...load address byte 0 = 0
    sta boot_osfile_block + 4           ; ...byte 2 = 0
    sta boot_osfile_block + 5           ; ...byte 3 = 0
    lda #&20 ; ' '                      ; ...byte 1 = &20
    sta boot_osfile_block + 3           ; ...so the file loads at &00002000
    lda filev                           ; Copy FILEV into the JSR below...
    sta boot_load_call_joystick + 1     ; ...FILEV low byte into the JSR's operand
    lda filev + 1                       ; ...FILEV high byte
    sta boot_load_call_joystick + 2     ; ...so the JSR calls the filing system directly
    lda #&ff                            ; OSFILE &FF: load the file at the block's address
.boot_load_call_joystick
    jsr &3000                           ; Call FILEV (operand patched above)
    jmp &2000                           ; Enter the loaded game at &2000
    equb &00, &00, &00, &00             ; Not referenced
; ***************************************************************************************
; BYTEV handler: read a joystick for the Barbarian's keys
;
; Installed on BYTEV by Coder, in the joystick image of &0400-&07FF only. Answers
; test_key's OSBYTE &81 scans of the Barbarian's (hero 2's) keys from the analogue port,
; so that a joystick plays the Barbarian: left (. &98) and right (/ &97) from channel 1,
; up (K &B9) and down (, &99) from channel 2, and fire (SPACE &9D) from either fire
; button. A direction counts only at the stick's extreme, when the channel's high byte is
; &FF or 0, so the stick works as a switch. Every other call goes to the MOS 1.20 OSBYTE
; routine at &E772 directly, skipping any other BYTEV claimant. The handler's own OSBYTE
; &80 reads come back through BYTEV into it and are passed on the same way. The
; Barbarian's five keys are never scanned while it is installed, so that hero can be
; played only with the joystick. test_key counts a key as held only when X and Y both
; come back &FF, so a not-pressed answer needs only X = 0.
;
; On Entry:
;     A: OSBYTE number
;     X: OSBYTE X
;
; On Exit:
;     X: &FF if the key is pressed, 0 if not
;     Y: &FF if the key is pressed
.joystick_bytev
    cmp #&81                            ; OSBYTE &81 (INKEY)?
    bne joystick_pass_on                ; No: let the MOS handle it
    cpx #inkey_key_full_stop            ; The Barbarian's left key (.)?
    beq joystick_left                   ; Yes: read the stick for left
    cpx #inkey_key_comma                ; The Barbarian's down key (,)?
    beq joystick_down                   ; Yes: read the stick for down
    cpx #inkey_key_k                    ; The Barbarian's up key (K)?
    beq joystick_up                     ; Yes: read the stick for up
    cpx #inkey_key_slash                ; The Barbarian's right key (/)?
    beq joystick_right                  ; Yes: read the stick for right
    cpx #inkey_key_space                ; The Barbarian's fire key (SPACE)?
    beq joystick_fire                   ; Yes: read the fire buttons
    jmp mos_osbyte_default              ; Any other key: scan the keyboard as usual
.joystick_left
    ldx #1                              ; Left: channel 1 high byte &FF?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #&ff                            ; ...high byte &FF: pushed fully left?
    bne joystick_not_pressed            ; No: not pressed
    ldx #&ff                            ; Yes: pressed (Y is already &FF)
    rts                                 ; Return X = Y = &FF: left is pressed
.joystick_right
    ldx #1                              ; Right: channel 1 high byte 0?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #0                              ; ...high byte 0: pushed fully right?
    bne joystick_not_pressed            ; No: not pressed
    dey                                 ; Yes: pressed (Y = &FF)
    ldx #&ff                            ; ...X = Y = &FF, as INKEY reports a key held
    rts                                 ; Return X = Y = &FF: right is pressed
.joystick_up
    ldx #2                              ; Up: channel 2 high byte &FF?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #&ff                            ; ...high byte &FF: pushed fully up?
    bne joystick_not_pressed            ; No: not pressed
    ldx #&ff                            ; Yes: pressed (Y is already &FF)
    rts                                 ; Return X = Y = &FF: up is pressed
.joystick_down
    ldx #2                              ; Down: channel 2 high byte 0?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #0                              ; ...high byte 0: pushed fully down?
    bne joystick_not_pressed            ; No: not pressed
    dey                                 ; Yes: pressed (Y = &FF)
    ldx #&ff                            ; ...X = Y = &FF, as INKEY reports a key held
    rts                                 ; Return X = Y = &FF: down is pressed
.joystick_fire
    ldx #0                              ; Fire: either fire button?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...OSBYTE &80, X = 0: the fire buttons in X
    jsr osbyte                          ; Read ADC channel X or buffer status
    txa                                 ; ...the button bits...
    and #3                              ; ...bits 0-1: either button held?
    beq joystick_not_pressed            ; No: not pressed
    ldx #&ff                            ; Yes: X = &FF, fire pressed...
    ldy #&ff                            ; ...X = Y = &FF, as INKEY reports a key held
    rts                                 ; Return X = Y = &FF: fire is pressed
.joystick_not_pressed
    ldx #0                              ; Not pressed: X = 0, which test_key reads as not held
    rts                                 ; Return X = 0: the key is not pressed
.joystick_pass_on
    jmp mos_osbyte_default              ; Not INKEY: on to the MOS 1.20 OSBYTE routine
    equb &00, &00, &00, &00             ; Not referenced
; Name of the file boot_loader loads, CR-terminated.
; ***************************************************************************************
; Name of the file boot_loader loads
.boot_filename_joystick
    equs "Dun1"
    equb &0d, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00             ; Not referenced
