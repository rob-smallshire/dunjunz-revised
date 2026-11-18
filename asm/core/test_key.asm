; ***************************************************************************************
; Test whether a hero's key, or their stick, is held
;
; Report whether a hero's key is held down at this moment, or the matching bit of their
; stick's switch byte is set. read_hero_keys calls it for each hero's direction and fire
; keys, from the hero_key tables, with the switch byte bit for the same action in Y, and
; check_magic with the magic key and switch_magic. A hero on a stick (hero_stick 0-3)
; plays on the stick alone: the keyboard is not read for them, so another player's set of
; keys, which may share keys with the hero's slots, cannot move them. A hero on a set of
; keys (hero_stick key_set_0 and up) has control_bits 0, so only the key counts.
;
; The key is scanned with OSBYTE &81 and a negative INKEY number (Y = &FF), which returns
; X = Y = &FF if it is held, and 0 if not. The 1987 release checked both; Y alone is
; enough. test_keyboard tests the key alone, for the pause key, which is no hero's.
;
; On Entry:
;     A: INKEY key number (negative, as a byte)
;     X: hero number (test_key only)
;     Y: the switch byte bit for the same action (test_key only)
;
; On Exit:
;     A: 0 if the key (or stick) is held, 1 if not
;     Z: set if held
;     X: preserved
;     Y: corrupted
.test_key
    pha                                 ; Keep the INKEY number
    tya                                 ; The action's bit...
    and control_bits,x                  ; ...in the hero's switch byte this frame?
    bne key_held_on_stick               ; Set: held on the stick
    pla                                 ; Not: the INKEY number back
    ldy hero_stick,x                    ; On a stick (0-3)?
    bpl key_not_held                    ; Yes: the keyboard does not count
.test_keyboard
    stx key_saved_x                     ; Keep the caller's X (the hero number)
    tax                                 ; The INKEY number in X, as OSBYTE &81 wants it
    lda #osbyte_inkey                   ; OSBYTE &81 with Y = &FF: scan the one key
    ldy #&ff                            ; Y = &FF: scan, do not wait
    jsr osbyte                          ; Y = &FF if the key is held, 0 if not
    ldx key_saved_x                     ; The caller's X again
    iny                                 ; Held: 0, Z set; up: 1, Z clear
    tya                                 ; A to match
    rts
.key_held_on_stick
    pla                                 ; Drop the INKEY number
    lda #0                              ; A = 0, Z set: held
    rts
.key_not_held
    lda #1                              ; A = 1, Z clear: not held
    rts
