; ***************************************************************************************
; Find the joysticks and install their driver
;
; Called by hero_menu, once per game. Every hero starts on the keyboard (hero_stick
; no_stick), every stick unusable and its fire taken as held, so a stick joins only on a
; fresh press. map_controls is copied to the printer buffer. Then:
;
; - SPItFIRE is asked to identify itself, OSWORD &3F reason 0. If byte 0 comes back &53
;   with no status flags, reason 1 gives the number of joysticks, n, and reason 2 describes
;   each: a stick (kind 1) whose switch byte carries directions (capability bit 1) is
;   usable. The SPItFIRE driver is installed at read_controls and the menu's SPItFIRE line
;   says how many sticks are usable. SPItFIRE's guide
;   (~/Code/spitfire/docs/joystick-programming.md) says to detect it this way, never
;   through ADVAL.
; - If SPItFIRE answered with status flags set (no workspace, no hardware, joysticks off
;   or updates stopped), its joysticks cannot be read, and the joystick port's lines are
;   its SPI bus, so ADVAL means nothing: no stick is usable, read_controls is an RTS, and
;   the menu says SPItFIRE is not ready.
; - Without SPItFIRE, the analogue driver is installed and sticks 0 and 1 (joysticks 1
;   and 2) are usable. A port with nothing in it, or a machine without an ADC, never
;   presses fire, so its stick never joins. On a Master Compact (OSBYTE 0 gives 5) the
;   driver skips the axes, which MOS 5 makes up from the digital port, and reads that
;   port's directions and fire from ADVAL(0) alone.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.find_sticks
    ldx #max_sticks - 1                 ; Sticks and heroes 3 to 0
.reset_stick
    lda #no_stick                       ; Every hero on the keyboard
    sta hero_stick,x
    lda #0                              ; No stick usable yet
    sta stick_usable,x
    sta stick_switch,x                  ; Nothing read yet
    lda #switch_fire                    ; Fire taken as held, so joining needs a fresh press
    sta stick_fire_before,x
    dex                                 ; Next down
    bpl reset_stick                     ; Until 0 is done
    ldx #map_controls_end - map_controls - 1  ; Copy map_controls into the printer buffer
.copy_map_controls
    lda map_controls_image,x
    sta map_controls,x
    dex
    bpl copy_map_controls
    lda #0                              ; Reason 0: identify
    jsr call_spitfire                   ; Ask SPItFIRE
    lda spitfire_block                  ; Did it answer?
    cmp #spitfire_answered
    bne no_spitfire                     ; No: the analogue port
    lda spitfire_block + 5              ; Status flags: ready?
    beq spitfire_ready                  ; None: ready
    ldx #spitfire_not_ready_text - spitfire_texts  ; Not ready: say so...
    jsr show_spitfire_line
    lda #&60                            ; ...and no driver: read_controls is an RTS
    sta read_controls
    rts
.spitfire_ready
    lda #1                              ; Reason 1: the summary
    jsr call_spitfire
    ldx spitfire_block + 1              ; n, the joysticks: 1 to n
    lda #'0'                            ; Count the usable ones, as a digit
    sta spitfire_count_digit
    txa                                 ; None at all?
    beq install_spitfire_driver         ; Yes: none usable
.describe_stick
    stx spitfire_block + 1              ; Reason 2: describe joystick X
    lda #2
    jsr call_spitfire
    ldx spitfire_block + 1              ; Joystick X again
    lda spitfire_block + 3              ; Its kind...
    cmp #1                              ; ...a stick?
    bne next_described_stick            ; No: not for a player
    lda spitfire_block + 4              ; Its capabilities...
    and #2                              ; ...directions in its switch byte?
    beq next_described_stick            ; No: not usable
    lda #1                              ; Usable: stick X - 1
    sta stick_usable - 1,x
    inc spitfire_count_digit            ; One more
.next_described_stick
    dex                                 ; Next joystick down
    bne describe_stick                  ; Until joystick 1 is done
.install_spitfire_driver
    ldx #spitfire_sticks_text - spitfire_texts  ; "SPITFIRE STICKS: n"
    jsr show_spitfire_line
    ldx #spitfire_driver_end - spitfire_driver - 1  ; Copy the SPItFIRE driver...
.copy_spitfire_driver
    lda spitfire_driver_image,x         ; ...to read_controls
    sta read_controls,x
    dex
    bpl copy_spitfire_driver
    rts
.no_spitfire
    lda #1                              ; Joysticks 1 and 2 on the analogue port are usable
    sta stick_usable
    sta stick_usable + 1
    ldx #analogue_driver_end - analogue_driver - 1  ; Copy the analogue driver...
.copy_analogue_driver
    lda analogue_driver_image,x         ; ...to read_controls
    sta read_controls,x
    dex
    bpl copy_analogue_driver
    lda #osbyte_read_os_version         ; OSBYTE 0 with X = 1: which machine?
    ldx #1
    jsr osbyte                          ; X = 5 on a Master Compact
    cpx #os_version_master_compact      ; A Compact?
    bne analogue_driver_ready           ; No: the axes count
    lda #&4c                            ; Yes: JMP map_controls over analogue_axes...
    sta read_controls + ANALOGUE_AXES_OFFSET
    lda #<(map_controls)
    sta read_controls + ANALOGUE_AXES_OFFSET + 1
    lda #>(map_controls)
    sta read_controls + ANALOGUE_AXES_OFFSET + 2
.analogue_driver_ready
    rts
; ***************************************************************************************
; Ask SPItFIRE
;
; OSWORD &3F with reason code A, on spitfire_block. Without SPItFIRE nothing claims the
; call and the block comes back unchanged, so byte 0 is the reason code, not &53.
;
; On Entry:
;     A: the reason code
.call_spitfire
    sta spitfire_block                  ; The reason code in byte 0
    lda #osword_spitfire                ; OSWORD &3F...
    ldx #<(spitfire_block)              ; ...on spitfire_block
    ldy #>(spitfire_block)
    jmp osword                          ; Ask, and return
; ***************************************************************************************
; Write the menu's SPItFIRE line
;
; Copy the eighteen characters at spitfire_texts+X into menu_spitfire_line.
;
; On Entry:
;     X: offset of the text in spitfire_texts
.show_spitfire_line
    ldy #0                              ; Eighteen characters
.copy_spitfire_line
    lda spitfire_texts,x
    sta menu_spitfire_line,y
    inx
    iny
    cpy #18
    bne copy_spitfire_line
    rts
; ***************************************************************************************
; Leave the sticks ready for play
;
; Called as the menu ends. If no hero plays on a stick, read_controls becomes an RTS, so
; play reads no sticks. Either way every hero starts with no stick bits and no magic
; charge, whatever the menu's polling left.
.sticks_for_play
    ldx #max_sticks - 1                 ; Does any hero play on a stick?
.find_stick_in_play
    lda hero_stick,x
    bpl clear_controls                  ; Yes: keep the driver
    dex
    bpl find_stick_in_play
    lda #&60                            ; No: read_controls is just an RTS
    sta read_controls
.clear_controls
    lda #0                              ; Every hero: no stick bits, no charge
    ldx #max_sticks - 1
.clear_hero_controls
    sta control_bits,x
    sta magic_charge,x
    dex
    bpl clear_hero_controls
    rts
; The SPItFIRE line's texts, eighteen characters each.
.spitfire_texts
.spitfire_sticks_text
    equs "SPITFIRE STICKS: "
.spitfire_count_digit
    equs "0"                            ; The usable sticks, counted by find_sticks
.spitfire_not_ready_text
    equs "SPITFIRE NOT READY"
; Each stick's fire at the last poll (switch_fire, or 0), for poll_sticks.
.stick_fire_before
    skip max_sticks
; 1 for each stick a player can join with.
.stick_usable
    skip max_sticks
; OSWORD &3F's block.
.spitfire_block
    skip 16
