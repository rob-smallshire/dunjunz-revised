; ***************************************************************************************
; Game-over message
;
; Twelve lines, printed through OSASCI in a window seventeen characters wide. In the 1987
; release each line was padded to seventeen characters, so that the cursor wrapped and the
; carriage return left a blank line; here the shorter lines end with a carriage return
; and a line feed instead, which looks the same. The full stop after "YOU ALL" appears,
; as its bytes no longer double as counters (see level_loop.asm).
; The message printed when every hero has died, terminated by a zero byte.
.game_over_message
    equs "FAREWELL!", &0d, &0a
    equs "THE QUEST HAS", &0d, &0a
    equs "FAILED AND THE", &0d, &0a
    equs "GODS ARE IN NO", &0d, &0a
    equs "MOOD TO RESURRECT", &0d
; The "YOU ALL." line of game_over_message.
.game_over_you_all
    equs "YOU ALL.", &0d, &0a
    equs "NEW ADVENTURERS", &0d, &0a
    equs "MUST TAKE YOUR", &0d, &0a
    equs "PLACE,BEGINNING", &0d, &0a
    equs "BACK ON THE UPPER", &0d
    equs "MOST LEVEL.", &0d, &0a
    equb &0a                            ; Line feed: a blank line
    equs "FIND THE CHALICE!", &00
