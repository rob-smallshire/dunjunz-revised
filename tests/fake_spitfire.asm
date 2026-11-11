; ***************************************************************************************
; A fake SPItFIRE, for the joystick tests
;
; Beebium emulates neither SPItFIRE nor the BBC's analogue-to-digital converter, so the
; joystick tests run the game on a Model B with this sideways ROM in a RAM slot. It
; answers what the game uses of SPItFIRE's interface
; (~/Code/spitfire/docs/joystick-programming.md), and stands in for an analogue port:
;
;   OSWORD &3F  reasons 0-2 (identify, summary, describe joystick j), from fake_identify,
;               fake_summary and fake_describe, when fake_mode is 1. Otherwise, and for
;               other reasons, the call is not claimed and the block comes back unchanged,
;               as on a machine without SPItFIRE.
;   OSBYTE &80  fake_mode 1 (SPItFIRE): channels 12 and 28 give the switch bytes in
;               fake_switches, joysticks 1 and 2 or 3 and 4, in X and Y.
;               fake_mode 2 (an analogue port): channel 0 gives fake_fire in X, and
;               channels 1-4 give fake_axes (low byte, high byte) in X and Y.
;               Anything else goes on to fake_old_bytev.
;
; The configuration lives in the ROM's own bank, at &BF00, which the tests write through
; beebium while the bank is not paged in. OSWORD &3F is claimed through service call 8
; (unrecognised OSWORD: A, X and Y of the call in &EF, &F0 and &F1). The OSBYTE hook is
; reached through the MOS's extended vector for BYTEV, which the tests set up: BYTEV =
; &FF0F, and &0DAE-&0DB0 = byte_hook and this ROM's number, with the old BYTEV in
; fake_old_bytev. The pointer at &A8-&A9 (the MOS's transient workspace, as the real ROM
; uses &A8-&AF) addresses the block.
;
; Assembled by tests/fake_spitfire.py.
; ***************************************************************************************

block_ptr = &a8

    org &8000
.rom_start
    equb 0, 0, 0                        ; No language entry
    jmp service                         ; Service entry
    equb &82                            ; ROM type: service entry, 6502 code
    equb copyright - rom_start          ; Offset of the zero byte before the copyright string
    equb 0                              ; Version
    equs "Fake SPItFIRE"                ; Title
.copyright
    equs 0, "(C)", 0                    ; Copyright, as the MOS requires

; Service calls: claim OSWORD &3F (call 8) when configured as SPItFIRE; pass all else on.
.service
    cmp #8                              ; Unrecognised OSWORD?
    bne service_pass                    ; No: not ours
    pha                                 ; Keep A, X and Y in case the call is not ours
    txa
    pha
    tya
    pha
    lda &ef                             ; The OSWORD number...
    cmp #&3f                            ; ...&3F, SPItFIRE's?
    bne osword_pass                     ; No: pass it on
    lda fake_mode                       ; Configured as SPItFIRE?
    cmp #1
    bne osword_pass                     ; No: pass it on, as without SPItFIRE
    lda &f0                             ; Point at the caller's block
    sta block_ptr
    lda &f1
    sta block_ptr + 1
    ldy #0
    lda (block_ptr),y                   ; The reason code
    beq reason_identify                 ; 0: identify
    cmp #1
    beq reason_summary                  ; 1: summary
    cmp #2
    beq reason_describe                 ; 2: describe joystick j
.osword_pass
    pla                                 ; Not ours: restore A, X and Y...
    tay
    pla
    tax
    pla
.service_pass
    rts                                 ; ...and pass the call on

; Reason 0: bytes 1-5 from fake_identify.
.reason_identify
    ldx #0
.copy_identify
    lda fake_identify,x
    iny
    sta (block_ptr),y
    inx
    cpx #5
    bne copy_identify
    beq claim                           ; Always

; Reason 1: bytes 1-8 from fake_summary.
.reason_summary
    ldx #0
.copy_summary
    lda fake_summary,x
    iny
    sta (block_ptr),y
    inx
    cpx #8
    bne copy_summary
    beq claim                           ; Always

; Reason 2: bytes 2-5 from fake_describe, four bytes per joystick j (1-4) in byte 1.
.reason_describe
    iny                                 ; Byte 1: j
    lda (block_ptr),y
    sec
    sbc #1                              ; j - 1...
    asl a
    asl a                               ; ...x 4: this joystick's entry
    tax
.copy_describe
    lda fake_describe,x
    iny
    sta (block_ptr),y
    inx
    cpy #5
    bne copy_describe

; Claim the call: byte 0 = &53, A = 0.
.claim
    lda #&53                            ; "S": SPItFIRE answered
    ldy #0
    sta (block_ptr),y
    pla                                 ; Drop the saved A, X and Y, restoring X and Y
    tay
    pla
    tax
    pla
    lda #0                              ; Claimed
    rts

; OSBYTE &80 on the configured channels; anything else goes on to the old BYTEV.
.byte_hook
    cmp #&80                            ; ADVAL?
    bne byte_pass                       ; No
    pha
    lda fake_mode
    cmp #1
    beq byte_spitfire
    cmp #2
    beq byte_analogue
.byte_pass_pull
    pla
.byte_pass
    jmp (fake_old_bytev)

.byte_spitfire
    cpx #12                             ; Joysticks 1 and 2's switch bytes?
    bne spitfire_28
    ldx fake_switches
    ldy fake_switches + 1
    pla
    rts
.spitfire_28
    cpx #28                             ; Joysticks 3 and 4's?
    bne byte_pass_pull
    ldx fake_switches + 2
    ldy fake_switches + 3
    pla
    rts

.byte_analogue
    cpx #5                              ; Channels 0-4 only
    bcs byte_pass_pull
    cpx #0
    bne analogue_axis
    ldx fake_fire                       ; Channel 0: the fire buttons
    ldy #0
    pla
    rts
.analogue_axis
    txa                                 ; Channel 1-4: its two bytes...
    asl a
    tax
    ldy fake_axes - 1,x                 ; ...high...
    lda fake_axes - 2,x                 ; ...and low
    tax
    pla
    rts

; The configuration, written by the tests.
    org &bf00
.fake_mode       skip 1                 ; 0 off, 1 SPItFIRE, 2 an analogue port
.fake_identify   skip 5                 ; Reason 0's bytes 1-5
.fake_summary    skip 8                 ; Reason 1's bytes 1-8
.fake_describe   skip 16                ; Reason 2's bytes 2-5 for joysticks 1-4
.fake_switches   skip 4                 ; Joysticks 1-4's switch bytes
.fake_fire       skip 1                 ; ADVAL(0)'s low byte
.fake_axes       skip 8                 ; ADVAL(1)-(4), low byte first
.fake_old_bytev  skip 2                 ; BYTEV before the hook
.rom_end

    save "fake_spitfire.rom", rom_start, &c000
