; ***************************************************************************************
; The joysticks' zero page
;
; Joysticks use the language's zero page, &00-&5F, which nothing uses while the game runs
; (it is *RUN, not a language, and the MOS and filing systems keep to &90 up). The hero
; menu sets it up once per game: it finds the joysticks, copies the driver for them to
; read_controls, and records which stick plays which hero. Like the workspace, this block
; only names the bytes; it emits none.
;
; Each frame update_game calls read_controls. The driver there reads every stick into
; stick_switch, in SPItFIRE's switch-byte layout, and goes on to map_controls, which gives
; each hero their stick's byte in control_bits, with bit 1 set once fire and a direction
; have been held together for magic_hold_frames. test_key reads control_bits. With no
; stick playing, read_controls is just an RTS and control_bits stays 0.

; Bits of a switch byte, as SPItFIRE's: fire, then the directions. Bit 1 is the game's own:
; the magic gesture, set by map_controls.
switch_fire                          = &01
switch_magic                         = &02
switch_left                          = &10
switch_down                          = &20
switch_up                            = &40
switch_right                         = &80
switch_directions                    = &f0

max_sticks                           = 4    ; SPItFIRE's joysticks 1-4, as sticks 0-3
no_stick                             = &ff  ; In hero_stick: the hero plays on the keyboard
magic_hold_frames                    = 8    ; Fire and a direction held this long cast magic (about half a second)
osbyte_read_os_version               = &00  ; OSBYTE 0, X = 1: the machine, in X
os_version_master_compact            = 5    ; ...5 for a Master Compact (MOS 5)
osword_spitfire                      = &3f  ; OSWORD &3F: SPItFIRE's descriptions of itself
spitfire_answered                    = &53  ; "S": byte 0 of the block when SPItFIRE answered
adval_switch_bytes_1_2               = 12   ; ADVAL(12): joysticks 1 and 2's switch bytes
adval_switch_bytes_3_4               = 28   ; ADVAL(28): joysticks 3 and 4's

ANALOGUE_AXES_OFFSET = 18               ; analogue_axes in the analogue driver, which find_sticks patches on a Compact
DRIVER_END = &60                        ; read_controls's driver ends below the tests' random number generator

    org &00
.hero_stick                             ; The stick (0-3) each hero plays with, or no_stick
    skip 4
.control_bits                           ; Each hero's switch byte this frame (0 on the keyboard), with switch_magic
    skip 4
.magic_charge                           ; Frames each hero has held fire and a direction together, up to magic_hold_frames
    skip 4
.stick_switch                           ; Each stick's switch byte this frame, as its driver read it
    skip 4
.key_saved_x                            ; test_key's X while OSBYTE runs
    skip 1
.axis_channel                           ; The analogue driver's ADC channel while OSBYTE runs
    skip 1
.read_controls                          ; The driver, copied here by the hero menu; an RTS when no stick plays
