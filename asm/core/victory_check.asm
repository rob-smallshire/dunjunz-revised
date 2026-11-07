; ***************************************************************************************
; Check whether the Chalice has been found
;
; End the game in victory when a hero reaches the Chalice. Called by play_level first in
; every frame, before update_game. On levels other than 25 return at once. On level 25,
; test each hero's hero_door_x, hero_door_y, the cell move_heroes recorded as the one
; they last stepped or tried to step into (kept even when a wall stops them, so walking
; into the Chalice is enough). If it is one of the Chalice's four cells, x &1A-&1B and y
; 4-5, the game is won: play victory_sequence, set a text window over the views (columns
; 0-16, rows 0-24, leaving the status panel), clear it, print the ending text, flush the
; keyboard buffer, wait for a key and load the title and the game afresh (restart_game),
; so this never returns.
;
; The ending text is not part of the program: it is the 140 bytes at room_walls + &3A
; followed by the zero-terminated string at object_free_map + &3A, which on level 25 hold
; text instead of map data. Both lie clear of &0C00-&0C07, the definition of character
; 128 that wrch_handler rewrites for every letter or digit it prints. The Chalice's cells
; are fixed here, not read from the level's objects.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
.check_for_victory
    lda level_number                    ; Which level is this?
    cmp #last_level                     ; The Chalice lies only on level 25
    bne no_victory                      ; Another level: no Chalice to find
    ldx #0                              ; Has a hero reached a Chalice cell, x &1A-&1B, y 4-5?
.check_door_x
    lda hero_door_x,x                   ; The cell hero X last stepped or bumped into...
    cmp #chalice_x                      ; ...in the Chalice's left column?
    beq check_door_y                    ; Yes: check the row
    cmp #chalice_x + 1                  ; ...or its right column?
    beq check_door_y                    ; Yes: check the row
.next_hero_victory
    inx                                 ; Not at the Chalice: on to the next hero
    cpx #4                              ; Past hero 3?
    bne check_door_x                    ; No: check the next hero
.no_victory
    rts                                 ; No hero at the Chalice: on with the frame
.check_door_y
    lda hero_door_y,x                   ; ...and that cell's row...
    cmp #chalice_y                      ; ...in the Chalice's top row?
    beq start_victory                   ; Yes: the Chalice is found
    cmp #chalice_y + 1                  ; ...or its bottom row?
    beq start_victory                   ; Yes: the Chalice is found
    bne next_hero_victory               ; No: next hero
.start_victory
    jsr victory_sequence                ; Sparkles, rising tone, the Chalice dissolves
; The game is won. Over the views, print the ending text that level 25's maps hold, wait for a key, and start afresh.
    ldx #views_window_vdu - vdu_strings ; A text window over the views, short of the panel...
    jsr send_vdu                        ; ...cleared
; Print the ending text: 140 bytes of level 25's wall map, then its object-free map up to a zero.
    ldx #0                              ; The ending text: 140 bytes from room_walls + &3A...
.print_victory_text
    lda room_walls + 58,x               ; Next byte of level 25's wall map, which is text
    jsr osasci                          ; Print it in the game's font
    inx                                 ; On through the 140 bytes
    cpx #&8c                            ; All 140 printed?
    bne print_victory_text              ; No: print the next
    ldx #0                              ; ...then the ending message, at object_free_map + &3A
.print_ending_message
    lda object_free_map + 58,x          ; Next character of the ending message
    jsr osasci                          ; Print it, the zero included
    inx                                 ; On along the message (X stays non-zero)
    cmp #0                              ; The zero that ends the message?
    bne print_ending_message            ; No: print the next
; Wait for a fresh key press, then load the title and the game afresh.
    lda #osbyte_flush_buffer_class      ; OSBYTE &0F, X non-zero: flush the input buffer...
    jsr osbyte                          ; ...so keys pressed in the sequence cannot skip the text  Flush selected class of buffer
    jsr osrdch                          ; Wait for a key once the ending text has been read
    jmp restart_game                    ; ...then load the title and the game afresh
