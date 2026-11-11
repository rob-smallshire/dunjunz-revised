; ***************************************************************************************
; Read SPItFIRE's four sticks
;
; The driver when SPItFIRE answered: its switch bytes, ADVAL(12) for joysticks 1 and 2
; and ADVAL(28) for 3 and 4, low byte first, into stick_switch, then on to map_controls.
; SPItFIRE sets a direction's bit when the stick is more than a quarter of full scale
; from the centre, and fire in bit 0. Assembled at read_controls and stored with the hero
; menu, which copies it there.
.spitfire_driver
    lda #osbyte_read_adc_or_get_buffer_status  ; OSBYTE &80: ADVAL...
    ldx #adval_switch_bytes_1_2         ; ...12: joysticks 1 and 2
    jsr osbyte                          ; X = joystick 1's byte, Y = joystick 2's
    stx stick_switch                    ; Stick 0
    sty stick_switch + 1                ; Stick 1
    lda #osbyte_read_adc_or_get_buffer_status  ; ADVAL...
    ldx #adval_switch_bytes_3_4         ; ...28: joysticks 3 and 4
    jsr osbyte                          ; X = joystick 3's byte, Y = joystick 4's
    stx stick_switch + 2                ; Stick 2
    sty stick_switch + 3                ; Stick 3
    jmp map_controls                    ; Give each hero their stick's byte
