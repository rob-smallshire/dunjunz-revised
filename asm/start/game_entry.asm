; ***************************************************************************************
; Enter the game
;
; Run once, from screen memory, by startup. Set the bell, which sounds when a hero fires:
; channel 1, a fixed amplitude, pitch 100, a twentieth of a second (OSBYTEs &D3-&D6). Save
; the MOS's WRCHV in saved_wrchv and point WRCHV at wrch_handler, the game's font. Then
; give every hero their starting attributes, let the players choose the heroes and the
; sound, and start the first level.
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
    sta wrchv                           ; ...into WRCHV's low byte...
    lda #>(wrch_handler)                ; ...and wrch_handler's high byte...
    sta wrchv + 1                       ; ...into WRCHV's: text now goes through it
    ldx #0                              ; Give each hero their starting attributes and score
.reset_each_hero
    jsr reset_hero                      ; Reset hero X: starting attributes, score 0000
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four done?
    bne reset_each_hero                 ; No: reset the next
    jsr hero_menu                       ; Then the players choose heroes and sound
    jmp next_level                      ; Start the first level
