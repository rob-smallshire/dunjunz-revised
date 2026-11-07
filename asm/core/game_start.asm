; ***************************************************************************************
; Start the game
;
; The game's entry point, where the release's loader jumps once the game is in memory. It
; prepares the two MOS services the game leans on:
;
; First the bell (the BEL character's channel, envelope, pitch and duration, through
; OSBYTEs &D3-&D6): the bell is what sounds when a hero fires, and the victory sequence
; raises its pitch.
;
; Then the text: save the MOS's WRCHV in saved_wrchv, for draw_view_frames to put back
; while it sends the view frames' PLOT commands, and point WRCHV at wrch_handler, so that
; all the game's text is printed in its own font.
;
; This code lives in the per-level workspace: from &0D40 its bytes are the missile tables
; and other workspace in page &0D, which reset_workspace overwrites from
; workspace_template at the start of every level, so it can run only before the first
; level after the game is loaded. It does not return; what follows &0D6A, starting the
; game, is the release's own.
.game_entry
    lda #osbyte_bell_channel            ; OSBYTE &D3: bell channel...
    ldx #&11                            ; ...&11: channel 1, with SOUND's flush bit set
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: the firing bell sounds on channel 1  osbyte: bell channel
    lda #osbyte_bell_envelope           ; OSBYTE &D4: bell envelope...
    ldx #0                              ; ...0, a fixed amplitude
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: BEL plays at a fixed amplitude  osbyte: bell envelope
    lda #osbyte_bell_frequency          ; OSBYTE &D5: bell pitch...
    ldx #&64 ; 'd'                      ; ...&64, SOUND pitch 100
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: BEL plays at pitch &64  osbyte: bell frequency
    lda #osbyte_bell_duration           ; OSBYTE &D6: bell duration...
    ldx #1                              ; ...1, in twentieths of a second
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: BEL lasts a twentieth of a second  osbyte: bell duration
    lda wrchv                           ; Save the MOS's WRCHV...
    sta saved_wrchv                     ; ...its low byte into saved_wrchv...
    lda wrchv + 1                       ; ...and its high byte...
    sta saved_wrchv + 1                 ; ...in saved_wrchv, for drawing the view frames
    lda #<(wrch_handler)                ; Point WRCHV at wrch_handler, the game's font...
.set_wrchv_low
; Sprite base of each missile, to which its direction is added; also identifies the hero who fired it.
missile_sprite_base = set_wrchv_low+1
    sta wrchv                           ; ...into WRCHV's low byte...
    lda #>(wrch_handler)                ; ...and wrch_handler's high byte...
    sta wrchv + 1                       ; ...into WRCHV's: text now goes through it
; Take the level number from Coder, and start a new game on the first level, or go straight to the level on later ones, the heroes having carried over in &08C0-&0CFF.
    lda level_count_copy                ; levels_started, which Coder left in &8E...
    sta level_number                    ; ...is level_number, 1-25, for the checksum and Chalice
    lda victory_pitch                   ; Copy &8F, which Coder does not set...
.store_level_bcd
; INKEY key number of each hero's down key.
hero_key_down = store_level_bcd+2
    sta level_bcd                       ; ...into level_bcd, which nothing here reads
    lda levels_started                  ; First level of a game?
    cmp #1                              ; ...levels_started 1, the first level of a game?
    beq start_new_game                  ; Yes: reset the heroes and run the hero menu
    jmp level_loop                      ; No: the heroes carry over; straight to the level
.start_new_game
; INKEY key number of each hero's fire key.
hero_key_fire = start_new_game+1
    lda #0                              ; A = 0, for new_game_reset_heroes' first hero
    jmp new_game_reset_heroes           ; ...past the stores that zero the level counts
    equs "eon5"
    equb &0d, &18, &bd, &04, &0d, &69, &03  ; Not referenced
    equb &9d                            ; Not referenced
    equb &1d
    equb &1d                            ; Hero 1's health tens
    equb &1d                            ; Hero 2's health tens
    equb &1d, &d0                       ; Hero 3's health tens
    equs "''''"
    equb &18, &bd, &08, &0d, &6d, &40, &0d  ; Not referenced
    equb &18
    equb &0c                            ; Hero 0's view room, high byte
    equb &68                            ; Hero 1's view room, low byte
    equb &0c                            ; Hero 1's view room, high byte
    equb &28                            ; Hero 2's view room, low byte
    equb &0c                            ; Hero 2's view room, high byte
    equb &30                            ; Hero 3's view room, low byte
    equb &0c, &00, &00, &bd, &04, &0d, &85, &71
    equb &8a                            ; Hero 3's view room, high byte
    equb &10
    equs "DLHh"
    equb &00
    equs ",4<"
    equb &00, &0d, &d9                  ; Not referenced
    equb &00, &00, &00, &00
    equb &80, &40, &20, &10, &08, &04, &02, &01
    equb &b9, &30, &0d, &9d, &08, &0d, &4c, &d4
    equb &0e, &3c, &6a, &98, &e8, &e0, &04, &d0
    equb &0a, &a2, &00, &ad, &40, &0d, &49, &01
    equb &8d, &40, &0d, &8e, &ff, &0d, &68, &a8
    equb &68, &aa
    equs "h(`"
    equb &de, &dd, &df, &f0, &f2, &f1, &f3, &f8
    equb &fa, &f9, &fb, &f4, &f6, &f5, &f7, &fc  ; Not referenced
    equb &1e, &fd
    equb &00, &a9, &00, &8d, &9f, &16, &8d, &ff
    equb &16
.new_game_reset_heroes
    tax                                 ; Give each hero their starting attributes and score
.reset_each_hero
    jsr reset_hero                      ; Reset hero X: starting attributes, score 0000
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four done?
    bne reset_each_hero                 ; No: reset the next
    jsr hero_menu                       ; Then the players choose heroes and sound
; The level loop: Coder has already loaded this level, so set the monsters' strength and start it. The leftover code after the JMP, which would count the level and build a filename, is never run.
.level_loop
    lda levels_started                  ; Monster hit points = 6 + 2 x levels started...
    asl a                               ; ...2 x levels started...
    clc                                 ; ...ready to add...
    adc #6                              ; ...+ 6: 8 on level 1, 56 on level 25
    sta monster_start_hit_points        ; ...for every monster on this level
    jmp play_this_level                 ; Start the level Coder has loaded
    equb &ff, &16, &69, &01, &8d, &ff, &16, &d8
    equb &ad, &9f, &16, &c9, &09, &b0, &04, &a2
    equb &00, &f0, &02, &a2, &01, &ad, &ff, &16
    equb &29, &0f, &18, &69, '0', &9d, &d5, &16
    equb &e0, &00, &f0, &0d             ; Not referenced
.to_next_level
    jmp next_level_by_reset             ; A hero survived: reset the machine and run Coder
    equs "JJJJ"
    equb &18, &69, '0', &8d, &d5, &16, &a9, &0d
    equb &9d, &d6, &16                  ; Not referenced
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
    bne to_next_level                   ; Yes: on to the next level
; Every hero is dead: print the game-over message over the views, then wait for a key, or for the time limit, before starting again. The MOS goes on counting the vsync counter down at every vertical sync, so if it has passed 0 by the time the message is printed, the wait for it to reach 0 lasts until it comes round, up to 256 vsyncs (about 5 s), and only then are keys flushed and read.
    lda #&1c                            ; All dead: VDU 28,0,24,16,0, a window over the views...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
    lda #&18                            ; Bottom row 24
    jsr oswrch                          ; Send the bottom row
    lda #&10                            ; Right column 16, short of the status panel
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Send VDU 12: clear the window
    ldx #4                              ; Spaces over &0FF1-&0FF4, two of them the counters
    lda #&20 ; ' '                      ; ...the space to write
.restore_message_spaces
    sta panel_hero - 1,x                ; ...into each (&0FF1 held YOU ALL's full stop)
    dex                                 ; Next byte down
    bne restore_message_spaces          ; Until all four are spaces
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
    jmp restart_by_reset                ; ...then reset and reload the game with *DUNJUNZ
