; ***************************************************************************************
; The keyboard layouts, as the title shows them
;
; Written by tools/dunjunz_revised/key_layouts.py, where the layouts are kept; do not edit.
; For N players (1-4), key_layout_texts_lo and _hi + N - 1 point at the page of keys the
; title prints in MODE 7 under the banner (show_keys), for print_text (runs of spaces
; as their lengths): teletext colour codes and text,
; lines ended by carriage returns (OSASCI starts each new line), except a full row and
; the last, which fills the screen's last row; the page ended by a zero.
.key_layout_texts_lo
    equb <key_layout_text_1, <key_layout_text_2, <key_layout_text_3, <key_layout_text_4
.key_layout_texts_hi
    equb >key_layout_text_1, >key_layout_text_2, >key_layout_text_3, >key_layout_text_4
.key_layout_text_1
    equb &08, &83, "ONE PLAYER AT THE KEYBOARD", &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb "KEY1", &82, "left", &87, "Z", &0b, &82, "right", &87, "X", &0d
    equb &04, &82, "up", &02, &87, "K", &0b, &82, "fire ", &87, "L", &0d
    equb &04, &82, "down", &87, "M", &0b, &82, "magic", &87, "SPACE", &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0c, &01, &83, "Press any key"
    equb 0
.key_layout_text_2
    equb &08, &83, "TWO PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &0d
    equb &0d
    equb "KEY1", &82, "left", &87, "A", &0b, &82, "right", &87, "S", &0d
    equb &04, &82, "up", &02, &87, "R", &0b, &82, "fire ", &87, "T", &0d
    equb &04, &82, "down", &87, "D", &0b, &82, "magic", &87, "C", &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0d
    equb "KEY2", &82, "left", &87, "B", &0b, &82, "right", &87, "N", &0d
    equb &04, &82, "up", &02, &87, "K", &0b, &82, "fire ", &87, ";", &0d
    equb &04, &82, "down", &87, "M", &0b, &82, "magic", &87, "SPACE", &0d
    equb &0d
    equb &0d
    equb &0d
    equb &0c, &01, &83, "Press any key"
    equb 0
.key_layout_text_3
    equb &08, &83, "THREE PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb "KEY1", &82, "left", &87, "DELETE", &06, &82, "right", &87, "COPY", &0d
    equb &04, &82, "up", &02, &87, "CURSOR RIGHT", &82, "fire ", &87, "CURSOR DOWN"
    equb &04, &82, "down", &87, "CURSOR UP", &03, &82, "magic", &87, "RETURN", &0d
    equb &0d
    equb &0d
    equb "KEY2", &82, "left", &87, ".", &0b, &82, "right", &87, "/", &0d
    equb &04, &82, "up", &02, &87, "K", &0b, &82, "fire ", &87, "SPACE", &0d
    equb &04, &82, "down", &87, ",", &0b, &82, "magic", &87, "L", &0d
    equb &0d
    equb &0d
    equb "KEY3", &82, "left", &87, "U", &0b, &82, "right", &87, "I", &0d
    equb &04, &82, "up", &02, &87, "G", &0b, &82, "fire ", &87, "O", &0d
    equb &04, &82, "down", &87, "B", &0b, &82, "magic", &87, "J", &0d
    equb &0d
    equb &0d
    equb &0c, &01, &83, "Press any key"
    equb 0
.key_layout_text_4
    equb &08, &83, "FOUR PLAYERS AT THE KEYBOARD", &0d
    equb "KEY1", &82, "left", &87, "SHIFT", &07, &82, "right", &87, "Z", &0d
    equb &04, &82, "up", &02, &87, "CAPS LOCK", &03, &82, "fire ", &87, "TAB", &0d
    equb &04, &82, "down", &87, "SHIFT LOCK", &02, &82, "magic", &87, "CTRL", &0d
    equb &0d
    equb "KEY2", &82, "left", &87, "DELETE", &06, &82, "right", &87, "COPY", &0d
    equb &04, &82, "up", &02, &87, "CURSOR RIGHT", &82, "fire ", &87, "CURSOR DOWN"
    equb &04, &82, "down", &87, "CURSOR UP", &03, &82, "magic", &87, "RETURN", &0d
    equb &0d
    equb "KEY3", &82, "left", &87, ".", &0b, &82, "right", &87, "/", &0d
    equb &04, &82, "up", &02, &87, "K", &0b, &82, "fire ", &87, "SPACE", &0d
    equb &04, &82, "down", &87, ",", &0b, &82, "magic", &87, "L", &0d
    equb &0d
    equb "KEY4", &82, "left", &87, "U", &0b, &82, "right", &87, "I", &0d
    equb &04, &82, "up", &02, &87, "G", &0b, &82, "fire ", &87, "O", &0d
    equb &04, &82, "down", &87, "B", &0b, &82, "magic", &87, "J", &0d
    equb &0d
    equb &0c, &01, &83, "Press any key"
    equb 0
