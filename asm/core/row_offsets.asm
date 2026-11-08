; ***************************************************************************************
; Screen row offsets
;
; Each character row's offset from the start of the screen, row x 640, as a high byte
; then a low byte, for rows 0-31. screen_address reads it; the 1987 release read the same
; table inside MOS 1.20 (at &C375), which no other MOS has.
.row_offsets
FOR row, 0, 31
    equb HI(row * 640), LO(row * 640)
NEXT
row_offsets_lo = row_offsets + 1
