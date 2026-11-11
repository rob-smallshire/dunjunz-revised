; ***************************************************************************************
; Choose the heroes, their controls and the sound
;
; The screen before each game where the players choose who plays, and how. It is called
; once per game, when a new game starts, after reset_hero has given every hero their
; starting attributes and before the first level. Set a text window the full width of
; the screen (MODE 2's 20 columns) and clear it, having first found the joysticks
; (find_sticks, which copies their driver out of the screen memory the clear wipes), print
; the menu (print_menu) and read keys and sticks until SPACE.
;
; Keys 1-4 toggle a hero between playing on the keyboard (KEYS) and not playing (NO), by
; flipping their hero_absent flag; either way the hero leaves any stick. Pressing fire on
; a stick gives it the first hero, from the one it plays now, that no other stick plays,
; and that hero plays (JOY1-JOY4); each further press moves it on, and past the Fighter it
; plays nobody, leaving its last hero on the keyboard. A stick nobody presses fire on
; plays nobody, so an empty port does no harm. Keys 5 and 6 switch the sound on and off
; with OSBYTE &D2. After each change the whole menu is reprinted. SPACE returns, so the
; game starts, only if at least one hero is playing, and "SPACE TO PLAY" is shown in
; yellow only then, in black (unseen) otherwise; if no stick plays, read_controls
; becomes an RTS. Before each key is read, the keyboard buffer is flushed and CAPS LOCK is
; forced on with SHIFT LOCK off.
;
; The ON/OFF entry is set from the sound suppression in force (OSBYTE &D2), which
; outlasts a game; in the 1987 release it showed only the menu text as loaded. hero_absent
; is read by remove_absent_heroes at each level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.hero_menu
    jsr find_sticks                     ; Find the joysticks and set up their driver, before the screen holding it is cleared
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
    lda #osbyte_sound_suppression       ; Show the sound as it is: OSBYTE &D2...
    ldx #0                              ; ...X = 0, Y = &FF: read the setting into X
    ldy #&ff                            ; ...unchanged
    jsr osbyte                          ; X non-zero if the sound is off
    ldy #menu_sound_entry + 1 - menu_text  ; The second letter of the menu's ON/OFF entry
    txa                                 ; Sound off?
    bne menu_starts_off                 ; Yes: show OFF
    jsr set_menu_on                     ; No: show ON
    jmp menu_sound_shown                ; ...and on
.menu_starts_off
    jsr set_menu_off                    ; Show OFF
.menu_sound_shown
    jsr print_menu                      ; Print the menu
    jmp menu_key_loop                   ; Read keys until the players start the game
; ***************************************************************************************
; Print the menu text
;
; Bring each hero's entry up to date (show_hero_entries), then print the positioned
; strings of menu_text, in their current state, through print_menu_string, up to the
; &FF that ends them. Called by hero_menu to show the menu and after every change.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.print_menu
    jsr show_hero_entries               ; Each hero's KEYS, NO or JOYn
    jsr any_hero_playing                ; Anyone playing?
    lda #space_to_play_colour           ; Yes: SPACE TO PLAY in yellow...
    inx                                 ; (X = 0 now if nobody)
    bne space_colour_chosen
    lda #0                              ; ...no: in black, unseen, as SPACE does nothing
.space_colour_chosen
    sta menu_space_colour               ; The colour in its VDU 17
    ldy #0                              ; Y walks through menu_text from its start
.print_menu_loop
    lda menu_text,y                     ; The next string's column, or &FF at the end
    bmi print_menu_done                 ; The end: done
    jsr print_menu_string               ; Print one menu string
    jmp print_menu_loop                 ; And the next
.print_menu_done
    rts
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
; Show how each hero plays
;
; Write each hero's entry in menu_text from hero_absent and hero_stick: "NO  " if the
; hero is not playing, "JOYn" if stick n-1 plays them, otherwise "KEYS".
;
; On Exit:
;     A: corrupted
;     X: &FF
;     Y: corrupted
.show_hero_entries
    ldx #3                              ; Heroes 3 to 0
.show_hero_entry
    stx plot_x                          ; Keep the hero number
    ldy menu_hero_entry_offsets,x       ; Y = the hero's entry in menu_text
    lda hero_absent,x                   ; Not playing?
    beq hero_entry_playing              ; Playing: on the keyboard or a stick
    ldx #entry_no - entry_words         ; Not playing: "NO  "
    bne copy_hero_entry                 ; Always
.hero_entry_playing
    lda hero_stick,x                    ; On a stick?
    bmi hero_entry_keys                 ; No: "KEYS"
    clc                                 ; Stick 0-3...
    adc #'1'                            ; ...as the digit 1-4...
    sta entry_joy + 3                   ; ...after "JOY"
    ldx #entry_joy - entry_words        ; "JOYn"
    bne copy_hero_entry                 ; Always
.hero_entry_keys
    ldx #entry_keys - entry_words       ; "KEYS"
.copy_hero_entry
    lda #4                              ; Four characters
    sta plot_y                          ; ...counted in plot_y
.copy_hero_entry_char
    lda entry_words,x                   ; Next character of the word...
    sta menu_text,y                     ; ...into the entry
    inx                                 ; Next character
    iny                                 ; Next place in the entry
    dec plot_y                          ; One fewer to copy
    bne copy_hero_entry_char            ; Until all four are copied
    ldx plot_x                          ; The hero number again
    dex                                 ; Next hero down
    bpl show_hero_entry                 ; Until hero 0 is done
    rts
; The words a hero's entry can show, four characters each; "KEYS" first, at offset 0.
.entry_words
.entry_keys
    equs "KEYS"
.entry_no
    equs "NO  "
.entry_joy
    equs "JOY?"                         ; The digit is filled in for each hero
; The offset in menu_text of each hero's entry.
.menu_hero_entry_offsets
    equb menu_hero_entries - menu_text, menu_hero_entries + 7 - menu_text
    equb menu_hero_entries + 14 - menu_text, menu_hero_entries + 21 - menu_text
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
; ***************************************************************************************
; Wait for a key, letting sticks join meanwhile
;
; Poll the sticks (poll_sticks) and the keyboard, two centiseconds at a time, until a
; key is pressed.
;
; On Exit:
;     A: the key's ASCII code
;     X: corrupted
;     Y: corrupted
.menu_read_key
    jsr poll_sticks                     ; Let a stick join, or move on
    lda #osbyte_inkey                   ; OSBYTE &81: INKEY(2)...
    ldx #2                              ; ...X = 2: wait up to two centiseconds...
    ldy #0                              ; ...Y = 0
    jsr osbyte                          ; Y = 0 and X = the key, or Y non-zero for none
    cpy #0                              ; A key?
    bne menu_read_key                   ; No: keep polling
    txa                                 ; Yes: its code in A
    rts
; ***************************************************************************************
; Let a stick join, or move it on
;
; Read the sticks through read_controls (the driver find_sticks installed) and look for a
; fresh press of fire on each usable stick, against stick_fire_before. A press moves the
; stick on to its next hero (advance_stick).
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: &FF
.poll_sticks
    jsr read_controls                   ; The sticks' switch bytes, in stick_switch
    ldy #max_sticks - 1                 ; Sticks 3 to 0
.poll_stick
    lda stick_switch,y                  ; This stick's fire...
    and #switch_fire                    ; ...1 if pressed
    tax                                 ; Kept in X
    eor stick_fire_before,y             ; Changed since the last poll?
    beq next_poll_stick                 ; No: nothing to do
    txa                                 ; Yes: remember it...
    sta stick_fire_before,y             ; ...for the next poll
    beq next_poll_stick                 ; Released: nothing more
    lda stick_usable,y                  ; Pressed: is the stick one the game can use?
    beq next_poll_stick                 ; No: ignore it
    jsr advance_stick                   ; Yes: move it on to its next hero
.next_poll_stick
    dey                                 ; Next stick down
    bpl poll_stick                      ; Until stick 0 is done
    rts
; ***************************************************************************************
; Move a stick on to its next hero
;
; Take stick Y from the hero it plays, if any (who stays playing, on the keyboard), and
; give it the next hero after them that no other stick plays, who then plays; past the
; Fighter the stick plays nobody. Reprint the menu.
;
; On Entry:
;     Y: the stick, 0-3
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
.advance_stick
    tya                                 ; Keep the stick...
    pha                                 ; ...across print_menu
    ldx #3                              ; Which hero does it play now? Heroes 3 to 0
.find_stick_hero
    tya                                 ; The stick...
    cmp hero_stick,x                    ; ...plays this hero?
    beq stick_hero_found                ; Yes
    dex                                 ; No: next hero down
    bpl find_stick_hero                 ; Until hero 0; X = &FF if none
.stick_hero_found
    txa                                 ; A hero?
    bmi next_stick_hero                 ; No: start from hero 0
    lda #no_stick                       ; Yes: the hero goes back to the keyboard
    sta hero_stick,x
.next_stick_hero
    inx                                 ; The next hero
    cpx #4                              ; Past the Fighter?
    bcs advance_stick_done              ; Yes: the stick plays nobody
    lda hero_stick,x                    ; Another stick plays this hero?
    bpl next_stick_hero                 ; Yes: try the next
    tya                                 ; No: the stick plays them...
    sta hero_stick,x
    lda #0                              ; ...and they play
    sta hero_absent,x
.advance_stick_done
    jsr print_menu                      ; Show it
    pla                                 ; The stick again
    tay
    rts
; Read one key and act on it, then come back for the next, until SPACE starts the game.
.menu_key_loop
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard any keys already waiting  Flush selected class of buffer
    lda #osbyte_kbd_status              ; OSBYTE &CA: set the keyboard lock states...
    ldx #&20 ; ' '                      ; X = &20: CAPS LOCK on, SHIFT LOCK off
    ldy #0                              ; Y = 0: replace the status with X
    jsr osbyte                          ; Set it, whatever the Ranger's lock keys left  osbyte: kbd status
    jsr menu_read_key                   ; Wait for a key, letting sticks join meanwhile
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
; Keys 1-4: switch hero X between playing on the keyboard and absent; either way, off any stick.
    lda hero_absent,x                   ; Toggle the hero between playing and absent...
    eor #1                              ; ...by flipping the absent flag
    sta hero_absent,x                   ; ...the hero's new absent flag
    lda #no_stick                       ; Off any stick: on the keyboard, or not playing
    sta hero_stick,x
.menu_reprint
    jsr print_menu                      ; Reprint the menu with the change
    jmp menu_key_loop                   ; Wait for the next key
; SPACE: return, so the game starts, if at least one hero is playing; otherwise ignore it.
.menu_space
    jsr any_hero_playing                ; SPACE: is any hero playing?
    inx                                 ; X = 0 if nobody
    bne menu_done                       ; Someone: return, and the game starts
    jmp menu_key_loop                   ; Nobody playing: ignore SPACE
.menu_done
    jmp sticks_for_play                 ; Leave the sticks ready for play, and return
; ***************************************************************************************
; Is any hero playing?
;
; On Exit:
;     X: a hero who plays (hero_absent 0), or &FF if none does
.any_hero_playing
    ldx #3                              ; Heroes 3 to 0
.check_hero_playing
    lda hero_absent,x                   ; Playing (absent flag 0)?
    beq hero_playing_found              ; Yes: X is them
    dex                                 ; No: the previous hero
    bpl check_hero_playing              ; Until hero 0; X = &FF if none
.hero_playing_found
    rts
; Keys 5 and 6: sound on or off, through OSBYTE &D2, and the menu's entry to match.
.menu_sound_key
    ldy #menu_sound_entry + 1 - menu_text  ; Sound: Y = offset of the second letter of ON/OFF
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
    jmp menu_reprint                    ; Reprint the menu with the change
; ***************************************************************************************
; Hero menu text
;
; Entries of: column, row, text, carriage return; printed in order by print_menu, each at
; its own text position (the heroes on every other row, as the font's letters fill their
; rows and run together otherwise), up to the &FF at the end. The four heroes' entries (from
; menu_hero_entries, seven bytes apart) are rewritten by show_hero_entries, the sound
; entry's ON/OFF by set_menu_on and set_menu_off, and the SPItFIRE line by find_sticks,
; so the table holds the players' choices as well as showing them.
.menu_text
    equb &06, &00                       ; Column 6, row 0
    equs "DUNJUNZ", &0d
    equb &00, &02                       ; Column 0, row 2
    equs "HERO", &0d
    equb &0c, &02                       ; Column 12, row 2
    equs "PLAYING", &0d
    equb &00, &04                       ; Column 0, row 4
    equs "1 RANGER", &0d
    equb &00, &06                       ; Column 0, row 6
    equs "2 MAGIC-USER", &0d
    equb &00, &08                       ; Column 0, row 8
    equs "3 BARBARIAN", &0d
    equb &00, &0a                       ; Column 0, row 10
    equs "4 FIGHTER", &0d
    equb &0e, &04                       ; Column 14, row 4
.menu_hero_entries
    equs "KEYS", &0d                    ; The Ranger's entry, then each hero's, seven bytes apart
    equb &0e, &06                       ; Column 14, row 6
    equs "KEYS", &0d
    equb &0e, &08                       ; Column 14, row 8
    equs "KEYS", &0d
    equb &0e, &0a                       ; Column 14, row 10
    equs "KEYS", &0d
    equb &00, &0c                       ; Column 0, row 12 (the full width: the cursor wraps)
    equs "KEYBOARD: 1234 JOINS", &0d
    equb &00, &0e                       ; Column 0, row 14
    equs "JOYSTICK: FIRE JOINS", &0d
    equb &00, &10                       ; Column 0, row 16
    equs "SOUND ON(5) OFF(6)", &0d
    equb &07, &12                       ; Column 7, row 18
.menu_sound_entry
    equs "ON ", &0d
    equb &00, &14                       ; Column 0, row 20
.menu_spitfire_line
    equs "                   ", &0d     ; Blank, or what find_sticks found of SPItFIRE
    equb &03, &16                       ; Column 3, row 22, the window's last
    equb &11                            ; VDU 17: text colour...
.menu_space_colour
    equb space_to_play_colour           ; ...yellow, or black when nobody plays (print_menu)
    equs "SPACE TO PLAY"
    equb &11, menu_colour, &0d          ; Back to the menu's green
    equb &ff                            ; The end
