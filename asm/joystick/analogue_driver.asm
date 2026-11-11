; ***************************************************************************************
; Read two sticks on the analogue port
;
; The driver without SPItFIRE: build switch bytes, in SPItFIRE's layout, for joysticks 1
; and 2 into stick_switch, then go on to map_controls. ADVAL(0)'s low byte gives the fire
; buttons in bits 0 and 1; on a Master Compact it also gives the digital port's
; directions in bits 4-7, where a switch byte has them, so they are kept for joystick 1.
; Each axis, ADVAL(1)-(4), sets a direction when its high byte is &C0 or more, or below
; &40: more than a quarter of full scale from the centre, SPItFIRE's threshold. High is
; left on X and up on Y, the Acorn convention. Assembled at read_controls and stored with
; the hero menu, which copies it there.
;
; A Master Compact has no ADC: MOS 5 makes ADVAL(1)-(4) up from the digital port, and
; without a stick they read 0, which would be right and down. On a Compact find_sticks
; puts a JMP map_controls over analogue_axes, so only ADVAL(0) counts.
.analogue_driver
    lda #osbyte_read_adc_or_get_buffer_status  ; OSBYTE &80: ADVAL...
    ldx #0                              ; ...0: the fire buttons
    jsr osbyte                          ; X = buttons (and a Compact's directions)
    txa                                 ; Joystick 1: fire, bit 0...
    and #switch_fire OR switch_directions  ; ...and on a Compact the directions
    sta stick_switch                    ; Stick 0
    txa                                 ; Joystick 2: fire, bit 1...
    lsr a                               ; ...moved to bit 0
    and #switch_fire                    ; Only fire
    sta stick_switch + 1                ; Stick 1
.analogue_axes
    ldx #4                              ; Channels 4 down to 1
.read_axis
    stx axis_channel                    ; Kept across OSBYTE
    lda #osbyte_read_adc_or_get_buffer_status  ; ADVAL(X)...
    jsr osbyte                          ; ...Y = its high byte
    ldx axis_channel                    ; The channel again
    cpy #&c0                            ; Three quarters or more?
    bcs axis_high                       ; Yes: left or up
    cpy #&40                            ; A quarter or more?
    bcs next_axis                       ; Yes: near the centre, nothing
    lda axis_low_bits - 1,x             ; Below a quarter: right or down
    bne merge_axis                      ; Always: never 0
.axis_high
    lda axis_high_bits - 1,x            ; Left or up
.merge_axis
    ldy axis_stick - 1,x                ; The channel's stick...
    ora stick_switch,y                  ; ...gets the direction...
    sta stick_switch,y                  ; ...as well
.next_axis
    dex                                 ; Next channel down
    bne read_axis                       ; Until channel 1 is done
    jmp map_controls                    ; Give each hero their stick's byte
; By channel 1-4 (X and Y of joystick 1, then of joystick 2): the bit for a high reading...
.axis_high_bits
    equb switch_left, switch_up, switch_left, switch_up
; ...the bit for a low reading...
.axis_low_bits
    equb switch_right, switch_down, switch_right, switch_down
; ...and the stick.
.axis_stick
    equb 0, 0, 1, 1
