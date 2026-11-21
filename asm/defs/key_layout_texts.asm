; ***************************************************************************************
; The keyboard layouts, as the title shows them
;
; Written by tools/dunjunz_revised/key_layouts.py, where the layouts are kept; do not edit.
; For N players (1-4), key_layout_texts_lo and _hi + N - 1 point at the page of keys the
; title prints in MODE 7 (show_keys): teletext colour codes and text, lines ended by
; carriage returns (OSASCI starts each new line), the page by a zero.
.key_layout_texts_lo
    equb <key_layout_text_1, <key_layout_text_2, <key_layout_text_3, <key_layout_text_4
.key_layout_texts_hi
    equb >key_layout_text_1, >key_layout_text_2, >key_layout_text_3, >key_layout_text_4
.key_layout_text_1
    equb &83, "DUNJUNZ: ONE PLAYER AT THE KEYBOARD", &0d
    equb &0d
    equb &86, "KEY1", &82, "left", &87, "Z         ", &82, "right", &87, "X", &0d
    equb "     ", &82, "up", &87, "K           ", &82, "fire", &87, "L", &0d
    equb "     ", &82, "down", &87, "M         ", &82, "magic", &87, "SPACE", &0d
    equb &0d
    equb &87, "On the hero menu, press your fire key", &0d
    equb &87, "to join, and again for another hero.", &0d
    equb &87, "RETURN starts the game.", &0d
    equb &0d
    equb &83, "Press any key", &0d
    equb 0
.key_layout_text_2
    equb &83, "DUNJUNZ: TWO PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &86, "KEY1", &82, "left", &87, "A         ", &82, "right", &87, "S", &0d
    equb "     ", &82, "up", &87, "R           ", &82, "fire", &87, "T", &0d
    equb "     ", &82, "down", &87, "D         ", &82, "magic", &87, "C", &0d
    equb &0d
    equb &86, "KEY2", &82, "left", &87, "B         ", &82, "right", &87, "N", &0d
    equb "     ", &82, "up", &87, "K           ", &82, "fire", &87, ";", &0d
    equb "     ", &82, "down", &87, "M         ", &82, "magic", &87, "SPACE", &0d
    equb &0d
    equb &87, "On the hero menu, press your fire key", &0d
    equb &87, "to join, and again for another hero.", &0d
    equb &87, "RETURN starts the game.", &0d
    equb &0d
    equb &83, "Press any key", &0d
    equb 0
.key_layout_text_3
    equb &83, "DUNJUNZ: THREE PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &86, "KEY1", &82, "left", &87, "DELETE    ", &82, "right", &87, "COPY", &0d
    equb "     ", &82, "up", &87, "CURSOR RIGHT", &82, "fire", &87, "CURSOR DOWN", &0d
    equb "     ", &82, "down", &87, "CURSOR UP ", &82, "magic", &87, "RETURN", &0d
    equb &0d
    equb &86, "KEY2", &82, "left", &87, ".         ", &82, "right", &87, "/", &0d
    equb "     ", &82, "up", &87, "K           ", &82, "fire", &87, "SPACE", &0d
    equb "     ", &82, "down", &87, ",         ", &82, "magic", &87, "L", &0d
    equb &0d
    equb &86, "KEY3", &82, "left", &87, "U         ", &82, "right", &87, "I", &0d
    equb "     ", &82, "up", &87, "G           ", &82, "fire", &87, "O", &0d
    equb "     ", &82, "down", &87, "B         ", &82, "magic", &87, "J", &0d
    equb &0d
    equb &87, "On the hero menu, press your fire key", &0d
    equb &87, "to join, and again for another hero.", &0d
    equb &87, "RETURN starts the game.", &0d
    equb &0d
    equb &83, "Press any key", &0d
    equb 0
.key_layout_text_4
    equb &83, "DUNJUNZ: FOUR PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &86, "KEY1", &82, "left", &87, "SHIFT     ", &82, "right", &87, "Z", &0d
    equb "     ", &82, "up", &87, "CAPS LOCK   ", &82, "fire", &87, "TAB", &0d
    equb "     ", &82, "down", &87, "SHIFT LOCK", &82, "magic", &87, "CTRL", &0d
    equb &0d
    equb &86, "KEY2", &82, "left", &87, "DELETE    ", &82, "right", &87, "COPY", &0d
    equb "     ", &82, "up", &87, "CURSOR RIGHT", &82, "fire", &87, "CURSOR DOWN", &0d
    equb "     ", &82, "down", &87, "CURSOR UP ", &82, "magic", &87, "RETURN", &0d
    equb &0d
    equb &86, "KEY3", &82, "left", &87, ".         ", &82, "right", &87, "/", &0d
    equb "     ", &82, "up", &87, "K           ", &82, "fire", &87, "SPACE", &0d
    equb "     ", &82, "down", &87, ",         ", &82, "magic", &87, "L", &0d
    equb &0d
    equb &86, "KEY4", &82, "left", &87, "U         ", &82, "right", &87, "I", &0d
    equb "     ", &82, "up", &87, "G           ", &82, "fire", &87, "O", &0d
    equb "     ", &82, "down", &87, "B         ", &82, "magic", &87, "J", &0d
    equb &0d
    equb &87, "On the hero menu, press your fire key", &0d
    equb &87, "to join, and again for another hero.", &0d
    equb &87, "RETURN starts the game.", &0d
    equb &0d
    equb &83, "Press any key", &0d
    equb 0
