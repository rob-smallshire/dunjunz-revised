; ***************************************************************************************
; Start the next level
;
; Count the level in levels_started and in level_digits, the ASCII digits of its filename
; ("1 " to "9 ", then "10" to "25"), and make it level_number. The 1987 disc release did
; this in Coder, which was loaded afresh for every level; the game is now resident, so it
; is done here, and game_entry comes here for the first level of a game.
;
; On Exit:
;     A: corrupted
.next_level
    inc levels_started                  ; One more level started (1 for the first)
    lda level_digits + 1                ; Advance level_digits, the filename's level number...
    cmp #' '                            ; Second digit a space (levels 1-9)?
    beq advance_single_digit            ; Yes: advance the single digit
    clc                                 ; No: advance the units digit...
    adc #1                              ; ...+1, the next units digit
    sta level_digits + 1                ; ...back into level_digits
    cmp #'9' + 1                        ; ...past '9': does it carry?
    bcc level_counted                   ; No: the number is ready
    lda #'0'                            ; Yes: units '0' and carry into the tens
    sta level_digits + 1                ; ...units digit back to '0'...
    inc level_digits                    ; ...and one more tens
    bne level_counted                   ; Always taken: the number is ready
.advance_single_digit
    inc level_digits                    ; Advance the single digit ('0 ' becomes '1 ')...
    lda level_digits                    ; ...to check it
    cmp #'9' + 1                        ; ...past '9': level 10, two digits now?
    bcc level_counted                   ; No: levels 1-9 are ready
    lda #'1'                            ; Yes: level 10, "10"
    sta level_digits                    ; ...'1' as the tens digit...
    lda #'0'                            ; ...and '0' as the units digit...
    sta level_digits + 1                ; ...in place of the space
.level_counted
    lda levels_started                  ; The level being started...
    sta level_number                    ; ...is level_number, 1-25, for the Chalice test
; Set the monsters' strength and play the level.
.level_loop
    lda levels_started                  ; Monster hit points = 6 + 2 x levels started...
    asl a                               ; ...2 x levels started...
    clc                                 ; ...ready to add...
    adc #6                              ; ...+ 6: 8 on level 1, 56 on level 25
    sta monster_start_hit_points        ; ...for every monster on this level
; Set the level up on the screen and play it: the level itself, the status panel, the absent heroes taken out, then play_level until no hero is left in play.
.play_this_level
    jsr start_level                     ; Load and draw the level
    jsr draw_status_panel               ; Draw every hero's panel section
    jsr remove_absent_heroes            ; Take out the heroes nobody plays
    lda #1                              ; Vsync count 1: play_level's first wait is two vsyncs
    sta os_vsync_counter                ; ...counted down at each vertical sync
    jsr play_level                      ; Play until no hero is left in play
; The level is over. Reset every hero who died, and end the game if all four did.
    ldx #0                              ; Count the dead, giving each their starting attributes
    stx count                           ; ...none dead so far
.check_hero_dead
    lda hero_health_tens,x              ; Dead (heroes nobody plays count as dead)?
    cmp #spr_digit_0 - 1                ; ...health tens one below 0?
    bne next_hero_dead                  ; No: survived, so not reset
    jsr reset_hero                      ; Yes: start them afresh on the next level
    inc count                           ; ...and count them
.next_hero_dead
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four checked?
    bne check_hero_dead                 ; No: next hero
    lda count                           ; Any hero survived?
    cmp #4                              ; ...fewer than four dead?
    bne next_level                      ; Yes: on to the next level
; Every hero is dead: print the game-over message over the views, then wait for a key, or for the time limit, before starting again. The MOS goes on counting the vsync counter down at every vertical sync, so if it has passed 0 by the time the message is printed, the wait for it to reach 0 lasts until it comes round, up to 256 vsyncs (about 5 s), and only then are keys flushed and read.
.game_over
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
    lda os_vsync_counter                ; Wait for the vsync counter, still running, to reach 0
    bne wait_vsync_game_over            ; Not yet: keep waiting
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard keys pressed during play  Flush selected class of buffer
    ldx #&46 ; 'F'                      ; Game over: wait up to &246 cs (5.8 s) for a key...
    ldy #2                              ; ...Y = &02: the time limit's high byte
    lda #osbyte_inkey                   ; ...OSBYTE &81: INKEY with a time limit
    jsr osbyte                          ; Read a key, waiting up to 582 centiseconds
    jmp restart_game                    ; ...then load the title and the game afresh
; ***************************************************************************************
; Counters
;
; The hero draw_status_panel is drawing, and the number of heroes found dead at the end
; of a level. In the 1987 release they were the full stop and the space after "YOU ALL"
; in the game-over message, which was therefore printed without its full stop.
.panel_hero
    equb 0
.count
    equb 0
