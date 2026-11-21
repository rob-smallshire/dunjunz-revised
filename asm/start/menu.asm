; ***************************************************************************************
; Choose the heroes, their controls and the sound
;
; The screen before each game where the players choose who plays, and how. It is called
; once per game, when a new game starts, after reset_hero has given every hero their
; starting attributes and before the first level. Set a text window the full width of
; the screen (MODE 2's 20 columns) and clear it, having first found the joysticks
; (find_sticks, which copies their driver out of the screen memory the clear wipes), print
; the menu (print_menu) and read keys and sticks until RETURN.
;
; Every player joins the same way, by pressing fire: on a stick, or the fire key of one of
; the keyboard's sets of keys (as many as the keyboard_players chosen on the title, from
; that layout: poll_key_sets). A press gives the stick or set the first hero, from the one
; it plays now, that nobody plays, and that hero plays (JOY1-JOY4, KEY1-KEY4); each
; further press moves it on, switching off the hero it leaves, and past the Fighter it
; plays nobody. Every hero starts off (the title sets hero_absent). A stick nobody presses
; fire on plays nobody, so an empty port does no harm. Keys 5 and 6 switch the sound on
; and off with OSBYTE &D2, and the sound line shows which in yellow. After each change the
; whole menu is reprinted. RETURN (no layout's fire key) returns, so the game starts,
; only if at least one hero is playing, and "RETURN TO PLAY" is shown in yellow only
; then, in black (unseen) otherwise; if no stick plays, read_controls
; becomes an RTS. Before each key is read, the keyboard buffer is flushed and CAPS LOCK is
; forced on with SHIFT LOCK off.
;
; The sound line's highlight is set from the sound suppression in force (OSBYTE &D2),
; which outlasts a game; in the 1987 release its ON/OFF entry showed only the menu text as
; loaded. hero_absent
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
    jsr show_hero_entries               ; Each hero's NO, KEYn or JOYn
    jsr any_hero_playing                ; Anyone playing?
    lda #menu_highlight_colour          ; Yes: RETURN TO PLAY in yellow...
    inx                                 ; (X = 0 now if nobody)
    bne space_colour_chosen
    lda #0                              ; ...no: in black, unseen, as RETURN does nothing
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
; hero is not playing, "JOYn" if stick n-1 plays them, "KEYn" if key set n-1 does. A hero who plays
; has their whole line in yellow; one who does not, in the menu's green.
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
    lda #menu_colour                    ; Not playing: the line in green...
    sta menu_text + HERO_LINE_COLOUR - HERO_LINE_ENTRY,y
    ldx #entry_no - entry_words         ; ...and "NO  "
    bne copy_hero_entry                 ; Always
.hero_entry_playing
    lda #menu_highlight_colour          ; Playing: the line in yellow
    sta menu_text + HERO_LINE_COLOUR - HERO_LINE_ENTRY,y
    lda hero_stick,x                    ; A stick (0-3) or a key set (&80-&83)?
    ldx #entry_joy - entry_words        ; A stick: "JOYn"
    cmp #key_set_0                      ; ...below key_set_0
    bcc hero_entry_digit
    ldx #entry_key - entry_words        ; A key set: "KEYn"
.hero_entry_digit
    and #3                              ; Stick or set 0-3...
    clc
    adc #'1'                            ; ...as the digit 1-4...
    sta entry_words + 3,x               ; ...after "JOY" or "KEY"
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
; The words a hero's entry can show, four characters each.
.entry_words
.entry_key
    equs "KEY?"                         ; The digit is filled in for each hero
.entry_no
    equs "NO  "
.entry_joy
    equs "JOY?"                         ; Likewise
; The offset in menu_text of each hero's entry.
.menu_hero_entry_offsets
    equb menu_hero_lines + HERO_LINE_ENTRY - menu_text
    equb menu_hero_lines + HERO_LINE_BYTES + HERO_LINE_ENTRY - menu_text
    equb menu_hero_lines + 2 * HERO_LINE_BYTES + HERO_LINE_ENTRY - menu_text
    equb menu_hero_lines + 3 * HERO_LINE_BYTES + HERO_LINE_ENTRY - menu_text
; ***************************************************************************************
; Show the sound off
;
; Highlight "OFF(6)" on the sound line, in yellow, and leave "ON(5)" in the menu's green,
; when key 6 turns the sound off or the menu finds it off.
.set_menu_off
    lda #menu_colour                    ; ON(5) plain
    ldx #menu_highlight_colour          ; OFF(6) highlighted
    bne set_sound_colours               ; Always
; ***************************************************************************************
; Show the sound on
;
; Highlight "ON(5)" on the sound line, in yellow, and leave "OFF(6)" in the menu's green,
; when key 5 turns the sound on or the menu finds it on.
.set_menu_on
    lda #menu_highlight_colour          ; ON(5) highlighted
    ldx #menu_colour                    ; OFF(6) plain
.set_sound_colours
    sta menu_sound_on_colour            ; The colours in their VDU 17s
    stx menu_sound_off_colour
    rts
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
    jsr poll_key_sets                   ; ...or a key set
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
; Let a key set join, or move it on
;
; Look for a fresh press of the fire key of each of the keyboard_players sets in the
; layout the title chose (menu_fire_keys), against key_fire_before. A press moves the set
; on to its next hero (advance_stick), as a stick's fire does.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: &FF
.poll_key_sets
    ldy keyboard_players                ; Sets N-1 to 0
.poll_key_set
    dey                                 ; The next set down
    bmi poll_key_sets_done              ; All done
    tya                                 ; Its fire key in this layout: menu_fire_keys...
    asl a                               ; ...+ 4 x set...
    asl a                               ; ...(carry clear: set 0-3)
    adc keyboard_players                ; ...+ players - 1
    tax
    lda menu_fire_keys - 1,x            ; The fire key's INKEY number
    tax                                 ; ...in X, for OSBYTE &81
    tya                                 ; Keep the set
    pha
    lda #osbyte_inkey                   ; OSBYTE &81 with Y = &FF: scan the one key
    ldy #&ff
    jsr osbyte                          ; X = &FF if held, 0 if not
    pla                                 ; The set again
    tay
    txa                                 ; Held...
    and #1                              ; ...1 if so
    tax
    eor key_fire_before,y               ; Changed since the last poll?
    beq poll_key_set                    ; No: nothing to do
    txa                                 ; Yes: remember it...
    sta key_fire_before,y               ; ...for the next poll
    beq poll_key_set                    ; Released: nothing more
    tya                                 ; Pressed: the set as a controller...
    ora #key_set_0                      ; ...key_set_0 + set
    tay
    jsr advance_stick                   ; Move it on to its next hero
    tya                                 ; The set again
    and #3
    tay
    bpl poll_key_set                    ; Always
.poll_key_sets_done
    rts
; The fire key of each set, by layout: set S of the layout for N players at
; menu_fire_keys + 4 S + N - 1 (asm/defs/key_layouts.asm).
.menu_fire_keys
    KEY_LAYOUT_FIRE_KEYS
; ***************************************************************************************
; Move a stick or key set on to its next hero
;
; Take stick or key set Y from the hero it plays, if any (who then plays no more), and
; give it the next hero after them that nobody plays, who then plays; past the Fighter it
; plays nobody. Reprint the menu.
;
; On Entry:
;     Y: the stick, 0-3, or the key set, key_set_0 + 0-3
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
    lda #no_stick                       ; Yes: off the stick...
    sta hero_stick,x
    lda #1                              ; ...and not playing
    sta hero_absent,x
.next_stick_hero
    inx                                 ; The next hero
    cpx #4                              ; Past the Fighter?
    bcs advance_stick_done              ; Yes: the stick plays nobody
    lda hero_absent,x                   ; Somebody plays this hero?
    beq next_stick_hero                 ; Yes: try the next
    tya                                 ; No: the stick plays them...
    sta hero_stick,x
    lda #0                              ; ...and they play
    sta hero_absent,x
.advance_stick_done
    jsr print_menu                      ; Show it
    pla                                 ; The stick again
    tay
    rts
; Read one key and act on it, then come back for the next, until RETURN starts the game.
.menu_key_loop
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard any keys already waiting  Flush selected class of buffer
    lda #osbyte_kbd_status              ; OSBYTE &CA: set the keyboard lock states...
    ldx #&20 ; ' '                      ; X = &20: CAPS LOCK on, SHIFT LOCK off
    ldy #0                              ; Y = 0: replace the status with X
    jsr osbyte                          ; Set it, whatever the Ranger's lock keys left  osbyte: kbd status
    jsr menu_read_key                   ; Wait for a key, letting sticks and key sets join meanwhile
    cmp #&0d                            ; RETURN, to start the game?
    beq menu_space                      ; Yes: start, if anyone is playing
    cmp #'6'                            ; Key 6?
    beq menu_sound_off                  ; Yes: sound off
    cmp #'5'                            ; Key 5?
    beq menu_sound_on                   ; Yes: sound on
    jmp menu_key_loop                   ; Anything else: ignore it
.menu_reprint
    jsr print_menu                      ; Reprint the menu with the change
    jmp menu_key_loop                   ; Wait for the next key
; RETURN: return, so the game starts, if at least one hero is playing; otherwise ignore it.
.menu_space
    jsr any_hero_playing                ; RETURN: is any hero playing?
    inx                                 ; X = 0 if nobody
    bne menu_done                       ; Someone: return, and the game starts
    jmp menu_key_loop                   ; Nobody playing: ignore RETURN
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
; Keys 5 and 6: sound on or off, through OSBYTE &D2, and the sound line's highlight to match.
.menu_sound_on
    jsr set_menu_on                     ; Key 5: ON highlighted...
    ldx #0                              ; ...with X = 0 to enable the sound
    beq menu_set_sound                  ; Always: set the sound
.menu_sound_off
    jsr set_menu_off                    ; Key 6: OFF highlighted...
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
; rows and run together otherwise), up to the &FF at the end. The four heroes' lines (from
; menu_hero_lines, HERO_LINE_BYTES apart) have their entries and colours rewritten by
; show_hero_entries, the colours of
; the sound line's ON(5) and OFF(6) by set_menu_on and set_menu_off, the colour of RETURN
; TO PLAY by print_menu, and the SPItFIRE line by find_sticks,
; so the table holds the players' choices as well as showing them.
.menu_text
    equb &06, &00                       ; Column 6, row 0
    equs "DUNJUNZ", &0d
    equb &00, &02                       ; Column 0, row 2
    equs "HERO", &0d
    equb &0c, &02                       ; Column 12, row 2
    equs "PLAYING", &0d
; Each hero's line, HERO_LINE_BYTES long: column and row, VDU 17 and the line's colour,
; the hero's number and name padded to column 14, their entry, and back to green.
.menu_hero_lines
    equb &00, &04                       ; Column 0, row 4
    equb &11, menu_colour               ; The line's colour (yellow while the hero plays)
    equs "RANGER        "
    equs "NO  "                         ; The entry: NO, KEYn or JOYn
    equb &11, menu_colour, &0d          ; Back to green
    equb &00, &06                       ; Column 0, row 6
    equb &11, menu_colour
    equs "MAGIC-USER    "
    equs "NO  "
    equb &11, menu_colour, &0d
    equb &00, &08                       ; Column 0, row 8
    equb &11, menu_colour
    equs "BARBARIAN     "
    equs "NO  "
    equb &11, menu_colour, &0d
    equb &00, &0a                       ; Column 0, row 10
    equb &11, menu_colour
    equs "FIGHTER       "
    equs "NO  "
    equb &11, menu_colour, &0d
.menu_hero_lines_end
ASSERT menu_hero_lines_end - menu_hero_lines = 4 * HERO_LINE_BYTES
    equb &00, &0c                       ; Column 0, row 12
    equs "FIRE TO JOIN, AGAIN", &0d         ; Each press of a fire key or button: the next free hero
    equb &00, &0e                       ; Column 0, row 14 (the full width: the cursor wraps)
    equs "FOR NEXT HERO OR OUT", &0d        ; ...and past the Fighter, playing nobody (advance_stick)
    equb &00, &11                       ; Column 0, row 17
    equs "SOUND "
    equb &11                            ; VDU 17: text colour...
.menu_sound_on_colour
    equb menu_highlight_colour          ; ...yellow while the sound is on, else green
    equs "ON(5) "
    equb &11                            ; VDU 17: text colour...
.menu_sound_off_colour
    equb menu_colour                    ; ...yellow while the sound is off, else green
    equs "OFF(6)"
    equb &11, menu_colour, &0d          ; Back to the menu's green
    equb &00, &14                       ; Column 0, row 20
.menu_spitfire_line
    equs "                   ", &0d     ; Blank, or what find_sticks found of SPItFIRE
    equb &02, &16                       ; Column 2, row 22, the window's last
    equb &11                            ; VDU 17: text colour...
.menu_space_colour
    equb menu_highlight_colour          ; ...yellow, or black when nobody plays (print_menu)
    equs "RETURN TO PLAY"
    equb &11, menu_colour, &0d          ; Back to the menu's green
    equb &ff                            ; The end
