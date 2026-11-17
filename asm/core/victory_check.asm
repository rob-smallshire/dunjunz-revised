; ***************************************************************************************
; Check whether the Chalice has been found
;
; End the game in victory when a hero reaches the Chalice. Called by play_level first in
; every frame, before update_game. On levels other than 25 return at once. On level 25,
; test each hero's hero_door_x, hero_door_y, the cell move_heroes recorded as the one
; they last stepped or tried to step into (kept even when a wall stops them, so walking
; into the Chalice is enough). If it is one of the Chalice's four cells, x &1A-&1B and y
; 4-5, the game is won: load the end of the game (load_ending) and jump to ending_victory,
; which plays the victory sequence, prints the ending text and starts afresh, so this
; never returns. The Chalice's cells are fixed here, not read from the level's objects.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
.check_for_victory
    lda level_number                    ; Which level is this?
    cmp #last_level                     ; The Chalice lies only on level 25
    bne no_victory                      ; Another level: no Chalice to find
    ldx #0                              ; Has a hero reached a Chalice cell, x &1A-&1B, y 4-5?
.check_door_x
    lda hero_door_x,x                   ; The cell hero X last stepped or bumped into...
    cmp #chalice_x                      ; ...in the Chalice's left column?
    beq check_door_y                    ; Yes: check the row
    cmp #chalice_x + 1                  ; ...or its right column?
    beq check_door_y                    ; Yes: check the row
.next_hero_victory
    inx                                 ; Not at the Chalice: on to the next hero
    cpx #4                              ; Past hero 3?
    bne check_door_x                    ; No: check the next hero
.no_victory
    rts                                 ; No hero at the Chalice: on with the frame
.check_door_y
    lda hero_door_y,x                   ; ...and that cell's row...
    cmp #chalice_y                      ; ...in the Chalice's top row?
    beq start_victory                   ; Yes: the Chalice is found
    cmp #chalice_y + 1                  ; ...or its bottom row?
    beq start_victory                   ; Yes: the Chalice is found
    bne next_hero_victory               ; No: next hero
.start_victory
    jsr load_ending                     ; Load the end of the game over the code for play
    jmp ending_victory                  ; ...and play the victory sequence and the ending
