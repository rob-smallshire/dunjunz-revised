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
    equb &83 : equs "DUNJUNZ: ONE PLAYER AT THE KEYBOARD", &0d
    equb &0d
    equb &86 : equs "KEY1  up K             down M", &0d
    equb &87 : equs "      left Z           right X", &0d
    equb &87 : equs "      fire L           magic SPACE", &0d
    equb &0d
    equb &87 : equs "On the hero menu, press your fire key", &0d
    equb &87 : equs "to join, and again for another hero.", &0d
    equb &87 : equs "RETURN starts the game.", &0d
    equb &0d
    equb &83 : equs "Press any key", &0d
    equb 0
.key_layout_text_2
    equb &83 : equs "DUNJUNZ: TWO PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &86 : equs "KEY1  up R             down D", &0d
    equb &87 : equs "      left A           right S", &0d
    equb &87 : equs "      fire T           magic C", &0d
    equb &0d
    equb &86 : equs "KEY2  up K             down M", &0d
    equb &87 : equs "      left B           right N", &0d
    equb &87 : equs "      fire ;           magic SPACE", &0d
    equb &0d
    equb &87 : equs "On the hero menu, press your fire key", &0d
    equb &87 : equs "to join, and again for another hero.", &0d
    equb &87 : equs "RETURN starts the game.", &0d
    equb &0d
    equb &83 : equs "Press any key", &0d
    equb 0
.key_layout_text_3
    equb &83 : equs "DUNJUNZ: THREE PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &86 : equs "KEY1  up CURSOR RIGHT  down CURSOR UP", &0d
    equb &87 : equs "      left DELETE      right COPY", &0d
    equb &87 : equs "      fire CURSOR DOWN magic RETURN", &0d
    equb &0d
    equb &86 : equs "KEY2  up K             down ,", &0d
    equb &87 : equs "      left .           right /", &0d
    equb &87 : equs "      fire SPACE       magic L", &0d
    equb &0d
    equb &86 : equs "KEY3  up G             down B", &0d
    equb &87 : equs "      left U           right I", &0d
    equb &87 : equs "      fire O           magic J", &0d
    equb &0d
    equb &87 : equs "On the hero menu, press your fire key", &0d
    equb &87 : equs "to join, and again for another hero.", &0d
    equb &87 : equs "RETURN starts the game.", &0d
    equb &0d
    equb &83 : equs "Press any key", &0d
    equb 0
.key_layout_text_4
    equb &83 : equs "DUNJUNZ: FOUR PLAYERS AT THE KEYBOARD", &0d
    equb &0d
    equb &86 : equs "KEY1  up CAPS LOCK     down SHIFT LOCK", &0d
    equb &87 : equs "      left SHIFT       right Z", &0d
    equb &87 : equs "      fire TAB         magic CTRL", &0d
    equb &0d
    equb &86 : equs "KEY2  up CURSOR RIGHT  down CURSOR UP", &0d
    equb &87 : equs "      left DELETE      right COPY", &0d
    equb &87 : equs "      fire CURSOR DOWN magic RETURN", &0d
    equb &0d
    equb &86 : equs "KEY3  up K             down ,", &0d
    equb &87 : equs "      left .           right /", &0d
    equb &87 : equs "      fire SPACE       magic L", &0d
    equb &0d
    equb &86 : equs "KEY4  up G             down B", &0d
    equb &87 : equs "      left U           right I", &0d
    equb &87 : equs "      fire O           magic J", &0d
    equb &0d
    equb &87 : equs "On the hero menu, press your fire key", &0d
    equb &87 : equs "to join, and again for another hero.", &0d
    equb &87 : equs "RETURN starts the game.", &0d
    equb &0d
    equb &83 : equs "Press any key", &0d
    equb 0
