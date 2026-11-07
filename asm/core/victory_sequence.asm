; ***************************************************************************************
; Play the victory sequence
;
; Sparkles circle the Chalice to a rising, quickening bell tone, and the Chalice
; dissolves into black. Called by check_for_victory once a hero reaches the Chalice; play
; is frozen meanwhile, as nothing else runs.
;
; Each pass sounds the bell, draws the ring of sparkles round the Chalice
; (draw_victory_ring), and waits. The bell's pitch climbs by a step each pass and wraps
; past 255, and each time it wraps the step grows by 1, so the tone repeats as ever
; faster sweeps: about 256 x (1 + 1/2 + ... + 1/50), some 1,150 passes in all. The wait
; starts at &E6 units of about 1,280 cycles each and shortens by one a pass down to 1,
; reached on pass 229, near the end of the first sweep; from then on each pass also calls
; dissolve_chalice, which clears a random byte of the Chalice when its random value is
; below &C0. After the 50th wrap (erase_victory_ring), erase the ring, clear whatever is
; left of the Chalice's sprite, replot it black, and wait 255 vertical syncs, about five
; seconds. The Chalice's sprite data stays cleared, as the game starts afresh next.
;
; OSBYTEs &D4 and &D5 set (old AND Y) EOR X, and Y is never set for them: the bell's
; envelope byte takes Y left over from the frame, and the first pitch takes the Y that
; OSBYTE &D4 returns; later passes have Y = 0 from the wait loop, so the pitch is exactly
; victory_pitch.
;
; On Exit:
;     A: 0
;     X: corrupted
;     Y: corrupted
.victory_sequence
    lda #osbyte_bell_envelope           ; OSBYTE &D4: the bell's envelope byte...
    ldx #8                              ; ...EOR 8; Y, not set, is the AND mask
    jsr osbyte                          ; Set the bell's envelope for the victory tone  osbyte: bell envelope
; Set up the sequence: no pixel offsets, the first sparkle, pitch 0 rising by 1, a wait of &E6, 50 sweeps.
    lda #0                              ; Plot the ring and Chalice square on their cells:
    sta plot_offset_x                   ; ...no x offset...
    sta plot_offset_y                   ; ...and no y offset
    lda #spr_sparkle_0                  ; The ring starts with the first sparkle
    sta victory_sprite                  ; ...as the ring's sprite
    lda #0                              ; Tone starts at pitch 0...
    sta victory_pitch                   ; ...for the bell
    lda #&e6                            ; ...with the passes &E6 wait units apart...
    sta victory_delay                   ; ...the delay loop's outer count
    lda #&32 ; '2'                      ; ...for &32 (50) sweeps of the pitch...
    sta victory_steps_left              ; ...counted down as the pitch wraps
    lda #1                              ; ...rising by 1 a pass in the first sweep
    sta victory_pitch_step              ; ...the pitch's first step
; One pass of the sequence: raise the pitch, shorten the wait, sound the bell, draw the ring, dissolve a byte of the Chalice once at full speed, and wait.
.raise_victory_pitch
    clc                                 ; Pitch = (pitch + step) mod 256, C set on a wrap...
    lda victory_pitch                   ; ...the bell's current pitch...
    adc victory_pitch_step              ; ...plus this sweep's step...
    sta victory_pitch                   ; ...stored as the pitch for this pass
    bcc shorten_victory_delay           ; No wrap: the sweep goes on
    inc victory_pitch_step              ; Wrapped: the next sweep climbs one step faster...
    dec victory_steps_left              ; ...and one fewer sweep is left
    bne shorten_victory_delay           ; Sweeps left: go on
    jmp erase_victory_ring              ; 50 sweeps done: erase the ring and the Chalice
.shorten_victory_delay
    dec victory_delay                   ; Shorten the wait: the passes come faster...
    bne sound_victory_bell              ; Not yet zero: keep it
    lda #1                              ; ...but never below 1...
    sta victory_delay                   ; ...the full speed the rest of the sequence runs at
.sound_victory_bell
    ldx victory_pitch                   ; OSBYTE &D5: the bell's pitch...
    lda #osbyte_bell_frequency          ; ...set it from victory_pitch
    jsr osbyte                          ; Set it: the bell now sounds at that pitch  osbyte: bell frequency
    lda #7                              ; ...and sound the bell
    jsr oswrch                          ; Send BEL: the bell sounds at the new pitch
    jsr draw_victory_ring               ; Draw the ring, the sparkles one side further round
    lda victory_delay                   ; At full speed, dissolve the Chalice a byte at a time
    cmp #1                              ; Delay down to 1: the sequence is at full speed
    bne victory_delay_loop              ; Not yet: just wait
    jsr dissolve_chalice                ; Full speed: clear one more byte of the Chalice
.victory_delay_loop
    ldx victory_delay                   ; Wait victory_delay units before the next pass
.victory_delay_outer
    ldy #&ff                            ; Each unit is 255 inner loops, about 1,280 cycles
.victory_delay_inner
    dey                                 ; Count down the inner loop
    bne victory_delay_inner             ; Until it reaches zero
    dex                                 ; Count down the delay units
    bne victory_delay_outer             ; Until the delay is spent (Y = 0 for the next OSBYTE)
    jmp raise_victory_pitch             ; Next pass: raise the pitch again
; ***************************************************************************************
; Draw the ring of sprites round the Chalice
;
; Draw one frame of the sparkling ring. Called by victory_sequence once a pass, and once
; more with the blank sprite to erase the ring. Plot victory_sprite at the twelve cells
; round the Chalice's 2 x 2 block (x &19-&1C, y 3-6, all in the Chalice's room), from x
; &1C, y 3 leftwards along the top, down the left side, along the bottom and up the right
; side, three cells to a side, each corner starting a side. The sprite moves on to the
; next sparkle (next_victory_sprite) after each of the first three sides and is left at
; the fourth side's, so the next ring starts with it and the sparkles move one side round
; the ring each pass. With the blank sprite, it erases the ring.
;
; On Entry:
;     VICTORY_SPRITE: the sprite for the top side
;
; On Exit:
;     VICTORY_SPRITE: the sprite of the right side
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.draw_victory_ring
    lda #chalice_x + 2                  ; Start at x &1C, y 3: the ring runs round the Chalice's four cells
    sta ring_x                          ; ...as the ring's x...
    lda #chalice_y - 1                  ; ...one row above the Chalice...
    sta ring_y                          ; ...as the ring's y
    jsr plot_victory_sprite             ; Plot the top-right corner, first of the top side
    dec ring_x                          ; Left to x &1B, above the Chalice's right column
    jsr plot_victory_sprite             ; Plot the top side's second cell
    dec ring_x                          ; Left to x &1A, above its left column
    jsr plot_victory_sprite             ; Plot the last of the top side's three
    lda victory_sprite                  ; Keep the sprite...
    sta victory_sprite_copy             ; ...in victory_sprite_copy, which nothing reads
    jsr next_victory_sprite             ; ...and move to the next sparkle for the left side
    dec ring_x                          ; Left to x &19: the top-left corner
    jsr plot_victory_sprite             ; Plot it, first of the left side
    inc ring_y                          ; Down to y 4, beside the Chalice's top row
    jsr plot_victory_sprite             ; Plot the left side's second cell
    inc ring_y                          ; Down to y 5, beside its bottom row
    jsr plot_victory_sprite             ; Plot the left side's third cell
    jsr next_victory_sprite             ; Next sparkle for the bottom side
    inc ring_y                          ; Down to y 6: the bottom-left corner
    jsr plot_victory_sprite             ; Plot it, first of the bottom side
    inc ring_x                          ; Right to x &1A, below the Chalice's left column
    jsr plot_victory_sprite             ; Plot the bottom side's second cell
    inc ring_x                          ; Right to x &1B, below its right column
    jsr plot_victory_sprite             ; Plot the bottom side's third cell
    jsr next_victory_sprite             ; Next sparkle for the right side, kept for the next ring
    inc ring_x                          ; Right to x &1C: the bottom-right corner
    jsr plot_victory_sprite             ; Plot it, first of the right side
    dec ring_y                          ; Up to y 5, beside the Chalice's bottom row
    jsr plot_victory_sprite             ; Plot the right side's second cell
    dec ring_y                          ; Up to y 4, beside its top row
    jsr plot_victory_sprite             ; Plot the right side's third, closing the ring
    rts                                 ; Return, victory_sprite at the right side's sparkle
; ***************************************************************************************
; Plot a victory sprite at a cell
;
; Plot victory_sprite at the cell ring_x, ring_y in every view showing it, with the pixel
; offsets victory_sequence cleared. Called by draw_victory_ring for each of the ring's
; twelve cells; ring_x and ring_y are left as they were, for the next step.
;
; On Entry:
;     RING_X: cell x
;     RING_Y: cell y
;     VICTORY_SPRITE: the sprite
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.plot_victory_sprite
    lda ring_x                          ; Plot the victory sprite at the ring cell
    sta cell_x                          ; ...as the cell's x
    lda ring_y                          ; ...and its y...
    sta cell_y                          ; ...as the cell's y
    lda victory_sprite                  ; ...with the ring's current sprite...
    sta sprite_number                   ; ...as the sprite to plot
    jsr plot_at_cell                    ; ...in every view that shows the cell
    rts                                 ; Return to draw_victory_ring for the next cell
; ***************************************************************************************
; Choose the next victory sprite
;
; Step victory_sprite through the four sparkles, &16-&19, wrapping back to &16. Called by
; draw_victory_ring between the ring's sides, so each side shows a different sparkle. The
; blank sprite, &15, used to erase the ring, is left alone, so an erasing ring stays
; blank all the way round.
;
; On Entry:
;     VICTORY_SPRITE: the current sprite
;
; On Exit:
;     VICTORY_SPRITE: the next sparkle, &16-&19 in turn; &15 (erasing) is kept
;     A: victory_sprite
;     X: preserved
;     Y: preserved
.next_victory_sprite
    lda victory_sprite                  ; Erasing (sprite &15)? Keep it
    cmp #spr_blank                      ; ...the blank sprite?
    beq store_victory_sprite            ; Yes: keep erasing
    clc                                 ; Next sparkle, &16-&19 in turn
    adc #1                              ; ...the next sparkle sprite
    cmp #spr_sparkle_3 + 1              ; Past the last sparkle?
    bne store_victory_sprite            ; No: use it
    lda #spr_sparkle_0                  ; Yes: back to the first sparkle
.store_victory_sprite
    sta victory_sprite                  ; Make it the ring's sprite
    rts                                 ; Return with A = victory_sprite
; ***************************************************************************************
; Clear a random byte of the Chalice
;
; Eat one more hole in the Chalice. Called by victory_sequence on every pass once its
; wait is down to 1. Make a random number from the System VIA's timer 1 low byte mixed
; with two bytes of MOS workspace (&FC and &FA). If it is below &C0, the size of the
; Chalice's 8 x 24-byte sprite, zero that byte of sprite_chalice and replot the Chalice,
; so it dissolves into black a pixel pair at a time; otherwise do nothing this pass. A
; byte already clear may be chosen again, so some survive until erase_victory_ring clears
; the rest.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.dissolve_chalice
    lda system_via_t1c_l                ; Pick a byte of the Chalice: System VIA timer 1...
    eor os_irq_a                        ; ...mixed with the MOS's last interrupt A...
    eor os_zp_fa                        ; ...and more MOS workspace, for randomness
    cmp #&c0                            ; Within the Chalice's &C0 bytes?
    bcs dissolve_done                   ; No: nothing dissolves this pass
    tax                                 ; X = the chosen byte's offset in the sprite...
    lda #0                              ; ...cleared to zero, a black pair of pixels...
    sta sprite_chalice,x                ; ...in the Chalice's sprite data
    jsr plot_chalice                    ; ...and replot the Chalice with the hole in it
.dissolve_done
    rts                                 ; Return to victory_sequence's wait
; The 50th sweep is done: erase the ring, clear the rest of the Chalice, and hold the scene for 255 vsyncs.
.erase_victory_ring
    lda #spr_blank                      ; Erase the ring
    sta victory_sprite                  ; ...by making the blank the ring's sprite...
    jsr draw_victory_ring               ; ...and drawing the ring with it
    ldx #&c1                            ; Clear what is left of the Chalice...
    lda #0                              ; ...to zeros, black pixels
.clear_chalice_sprite
    sta sprite_chalice - 1,x            ; Clear a byte of the Chalice's sprite data
    dex                                 ; Next byte down
    bne clear_chalice_sprite            ; &C1 bytes: the &C0 and the unused byte after
    jsr plot_chalice                    ; ...and replot it, now black: the Chalice is gone
    lda #&ff                            ; Pause 255 vertical syncs (about five seconds)
    sta os_vsync_counter                ; ...which the MOS counts down at each vsync
.wait_vsync_chalice
    lda os_vsync_counter                ; Read the count
    bne wait_vsync_chalice              ; Until it reaches zero
    rts                                 ; Return to check_for_victory for the ending text
; ***************************************************************************************
; Plot the Chalice
;
; Plot sprite &73, the Chalice, at its top-left cell (x &1A, y 4) in every view showing
; it, as its sprite data now stands. Called by dissolve_chalice after each byte it
; clears, and at the end of victory_sequence to show it gone. The sprite is two cells
; wide and two high, so it covers the four cells check_for_victory tests. The pixel
; offsets are those victory_sequence cleared.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.plot_chalice
    lda #chalice_x                      ; The Chalice's top-left cell, x &1A, y 4...
    sta cell_x                          ; ...as the cell's x
    lda #chalice_y                      ; ...and y 4...
    sta cell_y                          ; ...as the cell's y
    lda #spr_chalice                    ; ...sprite &73, 2 x 2 cells...
    sta sprite_number                   ; ...as the sprite to plot...
    jsr plot_at_cell                    ; ...plotted in every view showing it
    rts                                 ; Return with the Chalice drawn as its data stands
