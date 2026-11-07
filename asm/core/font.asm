; ***************************************************************************************
; Font: letters A-Z
;
; Eight bytes per letter, copied into the definition of character 128 by the WRCHV
; handler.
.font_letters
    equb %00111100                      ; 'A'
    equb %01000010
    equb %01000010
    equb %10001110
    equb %11110010
    equb %10000010
    equb %11000110
    equb %00000000
    equb %01111000                      ; 'B'
    equb %01000100
    equb %01000010
    equb %10111100
    equb %10000010
    equb %10000010
    equb %11111100
    equb %00000000
    equb %00111100                      ; 'C'
    equb %01000010
    equb %01000000
    equb %10000000
    equb %10000000
    equb %10000010
    equb %01111100
    equb %00000000
    equb %01111100                      ; 'D'
    equb %10000010
    equb %10000010
    equb %10000010
    equb %10000100
    equb %10000100
    equb %11111000
    equb %00000000
    equb %00001110                      ; 'E'
    equb %01110000
    equb %01000000
    equb %11001110
    equb %11110000
    equb %10000000
    equb %11111110
    equb %00000000
    equb %00011110                      ; 'F'
    equb %11100000
    equb %10000000
    equb %10001110
    equb %11110000
    equb %10000000
    equb %11000000
    equb %00000000
    equb %00111100                      ; 'G'
    equb %01000010
    equb %01000010
    equb %10000000
    equb %10011110
    equb %10000010
    equb %01111110
    equb %00000000
    equb %01100010                      ; 'H'
    equb %01000010
    equb %01000010
    equb %10011110
    equb %11100010
    equb %10000010
    equb %11000110
    equb %00000000
    equb %00011110                      ; 'I'
    equb %00001000
    equb %00001000
    equb %00010000
    equb %00010000
    equb %00010000
    equb %01111100
    equb %00000000
    equb %11111110                      ; 'J'
    equb %00000010
    equb %00000010
    equb %00000100
    equb %11000100
    equb %10000100
    equb %01111000
    equb %00000000
    equb %01000000                      ; 'K'
    equb %01001110
    equb %01110000
    equb %10001000
    equb %10001000
    equb %10000100
    equb %11000010
    equb %00000000
    equb %01100000                      ; 'L'
    equb %01000000
    equb %01000000
    equb %10000000
    equb %10000000
    equb %10000010
    equb %11111110
    equb %00000000
    equb %01000110                      ; 'M'
    equb %01101110
    equb %01101010
    equb %11011010
    equb %10010010
    equb %10000010
    equb %11000110
    equb %00000000
    equb %01100110                      ; 'N'
    equb %01010010
    equb %01010010
    equb %10001010
    equb %10001010
    equb %10001010
    equb %11000110
    equb %00000000
    equb %00111100                      ; 'O'
    equb %01000010
    equb %01000010
    equb %10000010
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %01111100                      ; 'P'
    equb %01000010
    equb %01000010
    equb %10111100
    equb %10000000
    equb %10000000
    equb %11000000
    equb %00000000
    equb %00111100                      ; 'Q'
    equb %01000010
    equb %01000010
    equb %10011010
    equb %10001010
    equb %10000110
    equb %01111110
    equb %00000000
    equb %01111100                      ; 'R'
    equb %01000010
    equb %01000010
    equb %10111100
    equb %10001000
    equb %10000100
    equb %11000010
    equb %00000000
    equb %00011110                      ; 'S'
    equb %00100010
    equb %01000000
    equb %00111100
    equb %00000010
    equb %10000010
    equb %11111100
    equb %00000000
    equb %11111110                      ; 'T'
    equb %10010010
    equb %00010000
    equb %00100000
    equb %00100000
    equb %00100000
    equb %01110000
    equb %00000000
    equb %01100110                      ; 'U'
    equb %01000010
    equb %01000010
    equb %10000010
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %11000110                      ; 'V'
    equb %01000010
    equb %01000010
    equb %10000010
    equb %10000100
    equb %01001000
    equb %00110000
    equb %00000000
    equb %01100110                      ; 'W'
    equb %01000010
    equb %01000010
    equb %10010010
    equb %10101010
    equb %01001010
    equb %01000100
    equb %00000000
    equb %01100110                      ; 'X'
    equb %00100010
    equb %00100100
    equb %00011000
    equb %00011000
    equb %00100100
    equb %11000110
    equb %00000000
    equb %10000110                      ; 'Y'
    equb %01000010
    equb %00110010
    equb %00001100
    equb %00001000
    equb %00010000
    equb %01110000
    equb %00000000
    equb %01111110                      ; 'Z'
    equb %00000010
    equb %00000100
    equb %00011000
    equb %00100000
    equb %01000010
    equb %11111110
    equb %00000000
; The game's font for the digits 0-9, in the same format as font_letters.
; ***************************************************************************************
; Font: digits 0-9
;
; Eight bytes per digit, copied into the definition of character 128 by the WRCHV
; handler.
.font_digits
    equb %00111100                      ; '0'
    equb %01000110
    equb %01001010
    equb %10010010
    equb %10100010
    equb %11000100
    equb %01111000
    equb %00000000
    equb %00001000                      ; '1'
    equb %00011000
    equb %00001000
    equb %00010000
    equb %00010000
    equb %00010000
    equb %00111100
    equb %00000000
    equb %00111100                      ; '2'
    equb %01000010
    equb %00000010
    equb %00001100
    equb %00110000
    equb %01000010
    equb %11111100
    equb %00000000
    equb %01111110                      ; '3'
    equb %00000010
    equb %00000100
    equb %00011000
    equb %00000110
    equb %10000010
    equb %01111100
    equb %00000000
    equb %00011000                      ; '4'
    equb %00101000
    equb %01001000
    equb %10010000
    equb %11111100
    equb %00010000
    equb %00111000
    equb %00000000
    equb %00011111                      ; '5'
    equb %00100000
    equb %00100000
    equb %00011000
    equb %00000100
    equb %10000010
    equb %01111100
    equb %00000000
    equb %00001110                      ; '6'
    equb %00010000
    equb %00100000
    equb %01111100
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %01111110                      ; '7'
    equb %00000010
    equb %00000010
    equb %00000100
    equb %00001000
    equb %00010000
    equb %01111000
    equb %00000000
    equb %00011100                      ; '8'
    equb %00100010
    equb %00100010
    equb %01111100
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %00111100                      ; '9'
    equb %01000010
    equb %01000010
    equb %00111110
    equb %00000010
    equb %00000100
    equb %00011000
    equb %00000000
