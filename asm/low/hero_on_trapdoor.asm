; ***************************************************************************************
; Is a hero standing on a trapdoor?
;
; Called by monster_reappears, so that a monster does not emerge from a trapdoor a hero in
; play stands on. Heroes out of play (dead, dying or gone, hero_direction 0) are not
; counted, so a skull does not shut a trapdoor for good.
;
; On Entry:
;     Y: trapdoor, 0-7
;
; On Exit:
;     C: set if a hero in play is in the trapdoor's cell
;     A: corrupted
;     X: preserved
;     Y: preserved
.hero_on_trapdoor
    txa                                 ; Keep the caller's X...
    pha                                 ; ...on the stack while X counts the heroes
    ldx #3                              ; Heroes 3 to 0...
.check_hero_on_trapdoor
    lda hero_direction,x                ; ...in play (a direction set)?
    beq next_hero_on_trapdoor           ; No: out of play, not counted
    lda hero_x,x                        ; The hero's x...
    cmp trapdoor_x,y                    ; ...the trapdoor's?
    bne next_hero_on_trapdoor           ; No: not on it
    lda hero_y,x                        ; ...and the hero's y...
    cmp trapdoor_y,y                    ; ...the trapdoor's? Equal sets carry
    beq hero_on_trapdoor_done           ; Yes: return with carry set
.next_hero_on_trapdoor
    dex                                 ; Next hero down
    bpl check_hero_on_trapdoor          ; More heroes: check the next
    clc                                 ; None on it: carry clear
.hero_on_trapdoor_done
    pla                                 ; The caller's X back...
    tax                                 ; ...preserving it (carry untouched)
    rts                                 ; Return, carry set if a hero is on the trapdoor
