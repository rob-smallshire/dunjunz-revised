; ***************************************************************************************
; End the game when ESCAPE is held
;
; The last step of every frame's update (update_game jumps here). ESCAPE held for
; escape_hold_frames frames in a row (about half a second) ends the game: restart_game
; loads the title and the game afresh, as game over does, and the hero menu follows the
; title. A shorter press does nothing, so a stray knock of the key is harmless. The
; key's usual effect is disabled for the whole game (OSBYTE &C8), so it is read like the
; pause key, through test_keyboard.
.check_escape
    lda #inkey_key_escape               ; ESCAPE held?
    jsr test_keyboard                   ; Z set if so
    bne escape_released                 ; No: start the count again
    inc escape_frames                   ; Yes: one more frame
    lda escape_frames                   ; Held long enough?
    cmp #escape_hold_frames
    bcc escape_done                     ; Not yet
    jmp restart_game                    ; Yes: back to the title, then the hero menu
.escape_released
    lda #0                              ; Not held: no frames counted
    sta escape_frames
.escape_done
    rts                                 ; Back to play_level: this frame's update is done
