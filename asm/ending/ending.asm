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
; and only then are keys flushed and read.
.ending_game_over
    ldx #views_window_vdu - vdu_strings ; A text window over the views, short of the panel...
    jsr send_vdu                        ; ...cleared
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
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard keys pressed during play  Flush selected class of buffer
    ldx #&46 ; 'F'                      ; Game over: wait up to &246 cs (5.8 s) for a key...
    ldy #2                              ; ...Y = &02: the time limit's high byte
    lda #osbyte_inkey                   ; ...OSBYTE &81: INKEY with a time limit
    jsr osbyte                          ; Read a key, waiting up to 582 centiseconds
    jmp restart_game                    ; ...then load the title and the game afresh

; ***************************************************************************************
; Victory
;
; A hero has reached the Chalice: play victory_sequence, set a text window over the views
; (columns 0-16, rows 0-24, leaving the status panel), clear it, print the ending text,
; flush the keyboard buffer, wait for a key and load the title and the game afresh
; (restart_game).
;
; The ending text is not part of the program: it is the 140 bytes at room_walls + &3A
; followed by the zero-terminated string at object_free_map + &3A, which on level 25 hold
; text instead of map data. Both lie clear of &0C00-&0C07, the definition of character
; 128 that wrch_handler rewrites for every letter or digit it prints.
.ending_victory
    jsr victory_sequence                ; Sparkles, rising tone, the Chalice dissolves
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

INCLUDE "asm/ending/victory_sequence.asm"
INCLUDE "asm/ending/game_over_text.asm"
