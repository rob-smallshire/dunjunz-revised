; ***************************************************************************************
; The end of the game, loaded when it is needed
;
; Game over and victory end the game for good: after them the title and the game are
; loaded afresh. Their code and text are therefore not kept resident. They are assembled
; at ENDING_ADDRESS and stored at the end of the file Setup, after the code that sets up
; each level; load_ending loads Setup again at ENDING_FILE_ADDRESS, so that these bytes
; land where they were assembled, over the code for play, which is no longer needed.
; Setup's own bytes land below them, likewise over the code for play.
;
; The level loop jumps to ending_game_over when every hero has died, and
; check_for_victory jumps to ending_victory when a hero reaches the Chalice.

; ***************************************************************************************
; Game over
;
; Every hero is dead: print the game-over message over the views, then wait for a key, or
; for the time limit, before starting again. The MOS goes on counting the vsync counter
; down at every vertical sync, so if it has passed 0 by the time the message is printed,
; the wait for it to reach 0 lasts until it comes round, up to 256 vsyncs (about 5 s),
; and only then is "R TO PLAY AGAIN" shown and keys flushed and read: R within ten
; seconds plays again with the same choices (play_again); any other key, or none, loads
; the title.
.ending_game_over
    jsr ending_text_window              ; A text window over the views, cleared, in the game's font
    ldx #0                              ; Print from the message's start
.print_game_over
    lda game_over_message,x             ; Print game_over_message from its start (X = 0)...
    jsr osasci                          ; ...through OSASCI, so each CR starts a new line
    inx                                 ; Step to the message's next character
    cmp #0                              ; ...up to its zero byte
    bne print_game_over                 ; Not the end: next
.wait_vsync_game_over
    lda os_vsync_counter                ; Wait for the vsync counter, still running, to run out
    beq vsync_game_over_done            ; 0: done
    bpl wait_vsync_game_over            ; Still counting down: keep waiting
.vsync_game_over_done
    jsr show_play_again                 ; "R TO PLAY AGAIN" below the message
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard keys pressed during play  Flush selected class of buffer
    ldx #<PLAY_AGAIN_CENTISECONDS       ; Wait up to ten seconds for a key...
    ldy #>PLAY_AGAIN_CENTISECONDS       ; ...the time limit's high byte
    lda #osbyte_inkey                   ; ...OSBYTE &81: INKEY with a time limit
    jsr osbyte                          ; X = the key and Y = 0, or Y = &FF if none came
    jmp play_again_or_title             ; R: play again; otherwise the title

; ***************************************************************************************
; Victory
;
; A hero has reached the Chalice: play victory_sequence, set a text window over the views
; (columns 0-16, rows 0-24, leaving the status panel), clear it, print the ending text and
; "R TO PLAY AGAIN", flush the keyboard buffer and wait for a key: R plays again with the
; same choices (play_again); any other loads the title and the game afresh
; (restart_game). There is no time limit here, so the ending can be read.
;
; The ending text is not part of the program: it is the 140 bytes at room_walls + &3A
; followed by the zero-terminated string at object_free_map + &3A, which on level 25 hold
; text instead of map data. Both lie clear of &0C00-&0C07, the definition of character
; 128 that wrch_handler rewrites for every letter or digit it prints.
.ending_victory
    jsr victory_sequence                ; Sparkles, rising tone, the Chalice dissolves
    jsr ending_text_window              ; A text window over the views, cleared, in the game's font
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
; Wait for a fresh key press: R plays again, any other loads the title and the game afresh.
    jsr show_play_again                 ; "R TO PLAY AGAIN" below the ending text
    lda #osbyte_flush_buffer_class      ; OSBYTE &0F, X non-zero: flush the input buffer...
    ldx #1                              ; ...(X = 1: the input buffer)
    jsr osbyte                          ; ...so keys pressed in the sequence cannot skip the text  Flush selected class of buffer
    jsr osrdch                          ; Wait for a key once the ending text has been read
    tax                                 ; The key in X...
    ldy #0                              ; ...and Y = 0: a key came
    jmp play_again_or_title             ; R: play again; otherwise the title

; Point WRCHV at wrch_handler, so text is drawn in the game's font (play leaves WRCHV with
; the MOS), and set a text window over the views, short of the panel, cleared.
.ending_text_window
    lda #<(wrch_handler)                ; Point WRCHV at wrch_handler...
    sta wrchv                           ; ...its low byte...
    lda #>(wrch_handler)                ; ...and its high byte
    sta wrchv + 1                       ; ...
    ldx #views_window_vdu - vdu_strings ; A text window over the views, short of the panel...
    jmp send_vdu                        ; ...cleared, and return

; ***************************************************************************************
; Play again, or go back to the title
;
; After game over or victory, with the key read in X and Y = 0, or Y non-zero if none came
; in time: R (either case) starts a new game at once, keeping the players' choices; any
; other key, or none, loads the title (restart_game).
PLAY_AGAIN_CENTISECONDS = 1000          ; Game over waits ten seconds for R
PLAY_AGAIN_ROW = 24                     ; The window's bottom row, below the message
PLAY_AGAIN_COLOUR = 3                   ; Yellow, set apart from the message's green
.play_again_or_title
    tya                                 ; A key?
    bne no_play_again                   ; No: the title
    txa                                 ; R or r?
    and #&df                            ; ...either case
    cmp #'R'
    beq play_again                      ; Yes: play again
.no_play_again
    jmp restart_game                    ; No: load the title and the game afresh
; Start a new game with the same choices: what the title would set in page &08 for a new
; game (no level started yet, level digits "0 "), but hero_absent, keyboard_players and
; each hero's stick or set of keys (hero_stick) kept as they are, and play_again_flag set,
; so game_entry skips the hero menu. As the title does before loading the game, blank
; the display and turn off VDU output, so the game loading into screen memory is unseen. The game is loaded afresh, as the title would load it,
; through restart_game with "RUN GAME" in place of its "RUN DUNJUNZ": the copy in the
; loader is the one in memory now, and the game being loaded brings its own.
.play_again
    lda #0                              ; No level started yet
    sta levels_started
    lda #'0'                            ; Level digits "0 ", which next_level advances to "1 "
    sta level_digits
    lda #' '
    sta level_digits + 1
    lda #1                              ; Play again: game_entry skips the hero menu
    sta play_again_flag
    ldx #blank_display_vdu - vdu_strings ; Show nothing while the game loads into screen memory...
    jsr send_vdu                        ; ...as the title does: 6845 register 1 = 0 (startup shows it again)
    lda #21                             ; VDU 21: and print nothing while it loads
    jsr oswrch                          ; ...(startup's VDU 6 enables output again)
    ldx #run_game_text_end - run_game_text - 1  ; "RUN GAME" over the loader's "RUN DUNJUNZ"
.copy_run_game
    lda run_game_text,x
    sta run_title_command,x
    dex
    bpl copy_run_game
    jmp restart_game                    ; Load the game (does not return)
.run_game_text
    equs "RUN GAME", &0d
.run_game_text_end
; Show "R TO PLAY AGAIN" in the text window, in the game's font and in yellow, on the
; bottom row, below the message, without a newline, so the window does not scroll.
; Nothing is printed after it, so the colour is not put back.
.show_play_again
    ldx #0                              ; Counted, as VDU 31's column is a zero
.show_play_again_char
    lda play_again_text,x
    jsr oswrch
    inx
    cpx #play_again_text_end - play_again_text
    bne show_play_again_char            ; Until all are sent
.show_play_again_done
    rts
.play_again_text
    equb 17, PLAY_AGAIN_COLOUR          ; VDU 17: yellow text
    equb 31, 0, PLAY_AGAIN_ROW          ; VDU 31: column 0, the bottom row
    equs "R TO PLAY AGAIN"
.play_again_text_end

INCLUDE "asm/ending/victory_sequence.asm"
INCLUDE "asm/ending/game_over_text.asm"
