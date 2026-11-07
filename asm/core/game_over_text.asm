; ***************************************************************************************
; Game-over message
;
; Eleven lines of seventeen characters, each ended by a carriage return, then a line feed
; and a last line ended by a zero byte. Two bytes of it (&0FF1, &0FF2) double as
; counters, and are overwritten with spaces before printing, so the full stop after "YOU
; ALL" never appears.
; The message printed when every hero has died, terminated by a zero byte.
.game_over_message
    equs "FAREWELL!", &0d
    equs "THE QUEST HAS", &0d
    equs "FAILED AND THE", &0d
    equs "GODS ARE IN NO", &0d
    equs "MOOD TO RESURRECT", &0d
; The "YOU ALL." line of game_over_message.
.game_over_you_all
    equs "YOU ALL.", &0d
    equs "NEW ADVENTURERS", &0d
    equs "MUST TAKE YOUR", &0d
    equs "PLACE,BEGINNING", &0d
    equs "BACK ON THE UPPER", &0d
    equs "MOST LEVEL.", &0d
    equb &0a                            ; Line feed: a blank line
    equs "FIND THE CHALICE!", &00
