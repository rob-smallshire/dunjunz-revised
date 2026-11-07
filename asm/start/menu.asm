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
.hero_menu
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
    jsr print_menu                      ; Print the menu
    jmp menu_key_loop                   ; Read keys until the players start the game
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
.print_menu
    ldx #&0f                            ; Fifteen strings, then one more by falling through
    ldy #0                              ; Y walks through menu_text from its start
.print_menu_loop
    jsr print_menu_string               ; Print one menu string
    dex                                 ; One fewer to print
    bne print_menu_loop                 ; More to print: loop
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
.print_menu_string
    lda #&1f                            ; VDU 31: move the text cursor...
    jsr oswrch                          ; Send VDU 31
    lda menu_text,y                     ; ...to the string's column...
    jsr oswrch                          ; Send the column
    iny                                 ; Step to the row byte
    lda menu_text,y                     ; ...and the string's row...
    jsr oswrch                          ; Send the row
.print_menu_string_loop
    iny                                 ; Print the characters...
    lda menu_text,y                     ; ...the next character...
    jsr oswrch                          ; ...sent to the screen...
    cmp #&0d                            ; ...up to and including the carriage return
    bne print_menu_string_loop          ; Not the CR yet: next character
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
.set_menu_no
    lda #'N'                            ; "NO ": N first...
    sta menu_text,y                     ; ...into the entry's first letter
    lda #'O'                            ; ...then O...
    sta menu_text + 1,y                 ; ...into the second letter
    lda #' '                            ; A space third, over YES's S...
    sta menu_text + 2,y                 ; ...into the third letter
    rts                                 ; Return: the entry reads NO
; ***************************************************************************************
; Change a menu entry to YES
;
; Write "YES" over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; on. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
.set_menu_yes
    lda #'Y'                            ; "YES": Y first...
    sta menu_text,y                     ; ...into the entry's first letter
    lda #'E'                            ; ...then E...
    sta menu_text + 1,y                 ; ...into the second letter
    lda #'S'                            ; ...then S...
    sta menu_text + 2,y                 ; ...into the third letter
    rts                                 ; Return: the entry reads YES
; ***************************************************************************************
; Change the sound entry to OFF
;
; Write "FF" at menu_text+Y, after the sound entry's "O", when key 6 turns the sound off.
;
; On Entry:
;     Y: offset of the entry's second character
.set_menu_off
    lda #'F'                            ; "FF" after the O
    sta menu_text,y                     ; ...over the N of ON...
    sta menu_text + 1,y                 ; ...and the space after it
    rts                                 ; Return: the entry reads OFF
; ***************************************************************************************
; Change the sound entry to ON
;
; Write "N " at menu_text+Y, after the sound entry's "O", when key 5 turns the sound on.
;
; On Entry:
;     Y: offset of the entry's second character
.set_menu_on
    lda #'N'                            ; "N " after the O
    sta menu_text,y                     ; ...over OFF's first F
    lda #' '                            ; ...then a space...
    sta menu_text + 1,y                 ; ...over OFF's second F
    rts                                 ; Return: the entry reads ON
; Read one key and act on it, then come back for the next, until SPACE starts the game.
.menu_key_loop
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard any keys already waiting  Flush selected class of buffer
    lda #osbyte_kbd_status              ; OSBYTE &CA: set the keyboard lock states...
    ldx #&20 ; ' '                      ; X = &20: CAPS LOCK on, SHIFT LOCK off
    ldy #0                              ; Y = 0: replace the status with X
    jsr osbyte                          ; Set it, whatever the Ranger's lock keys left  osbyte: kbd status
    jsr osrdch                          ; Wait for a key
    cmp #' '                            ; SPACE, to start the game?
    beq menu_space                      ; Yes: start, if anyone is playing
    cmp #'1'                            ; Ignore anything but 1-6
    bcc menu_key_loop                   ; Below '1': ignore it
    cmp #'7'                            ; ...or above '6' (at or past '7')?
    bcs menu_key_loop                   ; Yes: ignore it
    sec                                 ; Key number 0-5 = key - '1'...
    sbc #'1'                            ; ...so keys '1'-'6' become 0-5...
    tax                                 ; ...in X: a hero 0-3, or 4-5 for the sound
    cmp #4                              ; Key 5 or 6?
    bcs menu_sound_key                  ; Yes: the sound switch
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
    bne menu_hero_off                   ; Now absent (flag 1)?
    jsr set_menu_yes                    ; No: playing, so the entry reads YES
    jmp menu_reprint                    ; ...and reprint the menu
.menu_hero_off
    jsr set_menu_no                     ; Absent: the entry reads NO
.menu_reprint
    jsr print_menu                      ; Reprint the menu with the change
    jmp menu_key_loop                   ; Wait for the next key
; SPACE: return, so the game starts, if at least one hero is playing; otherwise ignore it.
.menu_space
    ldx #3                              ; SPACE: is any hero playing?
.menu_space_check_hero
    lda hero_absent,x                   ; Is this hero playing (absent flag 0)?
    beq menu_done                       ; Yes: return, and the game starts
    dex                                 ; Absent: try the previous hero
    bpl menu_space_check_hero           ; Heroes left to check: loop
    jmp menu_key_loop                   ; Nobody playing: ignore SPACE
.menu_done
    rts                                 ; Return: the game goes on to its first level
; Keys 5 and 6: sound on or off, through OSBYTE &D2, and the menu's entry to match.
.menu_sound_key
    ldy #&99                            ; Sound: Y = offset of the second letter of ON/OFF
    cmp #5                              ; Key 6 (A = key - "1")?
    beq menu_sound_off                  ; Yes: sound off
    jsr set_menu_on                     ; Key 5: ON...
    ldx #0                              ; ...with X = 0 to enable the sound
    beq menu_set_sound                  ; Always: set the sound
.menu_sound_off
    jsr set_menu_off                    ; Key 6: OFF...
    ldx #1                              ; ...with X = 1 to suppress it
.menu_set_sound
    lda #osbyte_sound_suppression       ; OSBYTE &D2: sound suppression
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Turn the sound on or off as chosen  osbyte: sound suppression
    jsr print_menu                      ; Reprint the menu with the change
    jmp menu_key_loop                   ; Wait for the next key
    equb &00, &00, &00, &00, &00, &00, &00, &00
; The hero menu: sixteen strings, each a text column and row followed by the characters and a carriage return. The YES/NO and ON/OFF entries are rewritten as the players toggle them.
; ***************************************************************************************
; Hero menu text
;
; Sixteen entries of: column, row, text, carriage return; printed in order by print_menu,
; each at its own text position. The four heroes' YES/NO entries (text at menu_text + &51
; + 6 x hero) are rewritten by set_menu_yes and set_menu_no, and the sound entry's ON/OFF
; (second letter at menu_text + &99) by set_menu_on and set_menu_off, so the table holds
; the players' choices as well as showing them.
.menu_text
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
