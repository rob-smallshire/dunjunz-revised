; ***************************************************************************************
; Is a hero on a trapdoor?
;
; Called by monster_reappears, so that a monster does not emerge from a trapdoor a hero
; stands on, and by draw_trapdoors, which leaves a trapdoor undrawn under a skull. Every
; hero counts, in play or out of it: a hero who dies on a trapdoor shuts it, as one
; standing on it does, until a Cross brings them back and they walk off. A hero who has
; gone down the exit is off the map, and one nobody plays is at x &1F, where no level has
; a trapdoor.
;
; On Entry:
;     Y: trapdoor, 0-7
;
; On Exit:
;     C: set if a hero is in the trapdoor's cell
;     A: corrupted
;     X: preserved
;     Y: the hero found if C is set; otherwise preserved
.hero_on_trapdoor
    txa                                 ; Keep the caller's X...
    pha                                 ; ...on the stack while X counts the heroes
    ldx #3                              ; Heroes 3 to 0...
.check_hero_on_trapdoor
    lda hero_x,x                        ; The hero's x...
    cmp trapdoor_x,y                    ; ...the trapdoor's?
    bne next_hero_on_trapdoor           ; No: not on it
    lda hero_y,x                        ; ...and the hero's y...
    cmp trapdoor_y,y                    ; ...the trapdoor's? Equal sets carry
    bne next_hero_on_trapdoor           ; No: not on it
    txa                                 ; Yes: the hero...
    tay                                 ; ...in Y for the caller
    bcs hero_on_trapdoor_done           ; Always: return with carry set
.next_hero_on_trapdoor
    dex                                 ; Next hero down
    bpl check_hero_on_trapdoor          ; More heroes: check the next
    clc                                 ; None on it: carry clear
.hero_on_trapdoor_done
    pla                                 ; The caller's X back...
    tax                                 ; ...preserving it (carry untouched)
    rts                                 ; Return, carry set if a hero is on the trapdoor
