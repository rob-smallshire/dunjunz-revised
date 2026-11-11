; ***************************************************************************************
; Give each hero their stick's switch byte
;
; The end of every driver: after the driver has read the sticks into stick_switch, hand
; each hero the byte of the stick that plays them, in control_bits, or 0 for a hero on
; the keyboard. While a stick holds fire and a direction together its hero's magic_charge
; counts the frames, and from the magic_hold_frames-th on (about half a second) the hero's
; byte also has switch_magic set, which check_magic casts on. On the keyboard a held
; direction beats fire, so the combination had no other meaning. Letting either go starts
; the count again.
;
; Copied by the hero menu to the MOS's printer buffer (&0880), which the game never prints
; to, alongside the page &08 state at &08B0.
;
; On Exit:
;     A: corrupted
;     X: &FF
;     Y: corrupted
.map_controls
    ldx #3                              ; Heroes 3 to 0
.map_hero
    lda #0                              ; On the keyboard: no stick bits
    ldy hero_stick,x                    ; The hero's stick...
    bmi store_controls                  ; ...none: 0
    lda stick_switch,y                  ; The stick's switch byte this frame
    tay                                 ; Kept in Y
    and #switch_directions              ; A direction held?
    beq no_charge                       ; No: no magic
    tya                                 ; And fire, bit 0...
    lsr a                               ; ...into carry
    bcc no_charge                       ; No fire: no magic
    inc magic_charge,x                  ; Both: one more frame
    lda magic_charge,x                  ; Held long enough?
    cmp #magic_hold_frames
    bcc keep_controls                   ; Not yet: just the stick's byte
    dec magic_charge,x                  ; Yes: back one, so the count reaches it again next frame...
    iny                                 ; ...and set switch_magic (bit 1, always clear in a switch byte)
    iny
    bne keep_controls                   ; Always: Y is not zero
.no_charge
    lda #0                              ; Let go: count again from 0
    sta magic_charge,x
.keep_controls
    tya                                 ; The hero's byte
.store_controls
    sta control_bits,x                  ; For test_key
    dex                                 ; Next hero down
    bpl map_hero                        ; Until hero 0 is done
    rts
