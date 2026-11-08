; ***************************************************************************************
; Draw the trapdoors
;
; Redraw the eight trapdoors, because erasing a creature or missile that crossed one has
; blanked its cell. update_game calls it first in each frame, so every hero, missile and
; monster is drawn over them. The 1987 release drew them at the start of update_monsters,
; after the heroes and missiles, so a hero or missile on a trapdoor flickered with it.
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: corrupted
.draw_trapdoors
    ldx #8                              ; Redraw trapdoors 8 to 1 (sprite &2C)...
    lda #0                              ; Trapdoors sit squarely in their cells:
    sta plot_offset_x                   ; ...no horizontal offset...
    sta plot_offset_y                   ; ...and no vertical offset
    lda #spr_trapdoor                   ; The trapdoor sprite...
    sta sprite_number                   ; ...the same for all eight
.draw_trapdoor
    lda trapdoor_x - 1,x                ; This trapdoor's map x...
    sta cell_x                          ; ...as the cell to plot
    lda trapdoor_y - 1,x                ; ...and its map y
    sta cell_y                          ; ...as cell_y
    txa                                 ; Keep the trapdoor number...
    pha                                 ; ...on the stack: plot_at_cell changes X
    jsr plot_at_cell                    ; Draw it in every view showing its cell
    pla                                 ; Recover the trapdoor number...
    tax                                 ; ...back in X
    dex                                 ; Next trapdoor down
    bne draw_trapdoor                   ; Until trapdoor 1 is drawn
    rts                                 ; Return with every trapdoor drawn
; ***************************************************************************************
; Move the monsters
;
; Move every monster on by one frame of its life. update_game calls it once a frame,
; after draw_objects and move_missiles, so a monster killed by a missile or magic this
; frame starts its death here. Each monster, 30 down to 1, is erased where it was drawn
; last frame and moved on according to its state.
;
; Moving: a monster mid-step slides a quarter cell further (continue_monster_step). One
; that is not stepping tries the next cell the way it faces. If that cell is open and
; holds no creature, it starts a step: monster_x and monster_y keep the old cell while
; the offsets carry the sprite across, so an interior cell takes four frames (a quarter,
; a half, three quarters, then square in the new cell). A cell in a room's edge row or
; column, in the direction of travel, is entered at once, so no sprite is drawn between
; two rooms and a monster crosses from one room into the next in two frames.
;
; Blocked: a wall, a closed door or a creature in the cell keeps the monster where it is.
; It turns a random way, each of the four equally likely, from the System VIA's timer 1,
; and tries that way next frame. A monster does not chase anyone: it walks straight on
; until blocked. find_creature takes hero_damage_taken points from a hero it finds in the
; cell, so a monster hurts a hero each time it tries to step into them.
;
; Dying: a monster killed by a missile or by magic is given sprite &15 (the blank) there.
; Each frame here advances it through the sparkles &16-&19, drawn where it died.
;
; Reappearing: after the last sparkle monster_reappears puts it on the next trapdoor in
; turn, facing up, to be drawn next frame. A trapdoor a hero in play stands on stays
; shut: the monster tries the next trapdoor on the next frame.
;
; reset_monsters starts every monster at the blank with x &FF, so at the start of a level
; all 30 sparkle off the map together and emerge on the same frame, shared out round the
; eight trapdoors in turn. Only the target cell is ever tested for a creature: during a
; slide the monster is still recorded in the cell it is leaving, and the arrival is not
; checked again, so two monsters, or a monster and a hero, can end a step in the same
; cell. Monsters may emerge onto each other, as all 30 do at the start of a level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.update_monsters
    ldx #max_monster                    ; Each monster, 30 to 1...
; Each monster in turn, 30 down to 1. It is first rubbed out where it was drawn last frame, its cell and offsets plotted with the blank sprite, and its cell is kept in previous_x and previous_y. Then its state decides what happens: a dying monster (sprite &15 and up) shows its next sparkle, one part way through a step slides on, and any other tries a new step. The monster number stays on the stack until monster_done.
.next_monster_update
    txa                                 ; Keep the monster number...
    pha                                 ; ...on the stack while it moves
    lda monster_x,x                     ; Erase it at its cell and offsets, remembering the cell
    sta cell_x                          ; ...as the cell to erase...
    sta previous_x                      ; ...and as where it came from
    lda monster_y,x                     ; ...and its map y...
    sta cell_y                          ; ...as the cell to erase...
    sta previous_y                      ; ...and as where it came from
    lda #spr_blank                      ; The blank sprite...
    sta sprite_number                   ; ...to rub it out
    lda monster_offset_x,x              ; Its horizontal offset...
    sta plot_offset_x                   ; ...for the erase
    lda monster_offset_y,x              ; ...and its vertical offset...
    sta plot_offset_y                   ; ...so the blank covers it where it was drawn
    jsr plot_at_cell                    ; Rub the monster out in every view showing it
    pla                                 ; The monster number back from the stack...
    pha                                 ; ...left there for monster_done
    tax                                 ; ...in X again
    lda monster_sprite,x                ; Is the monster dying?
    cmp #spr_blank                      ; Sprite &15 (the blank) and up: killed
    bcc check_monster_step              ; Below &15: alive, so it moves
    jmp advance_dying_monster           ; Killed: show its next sparkle
.check_monster_step
    lda monster_step,x                  ; Part way through a step?
    beq start_monster_move              ; No: try a step to the next cell
    jsr continue_monster_step           ; Yes: slide it a quarter cell further
    pla                                 ; Drop the stacked number (X still has it)...
    jmp draw_monster                    ; ...as draw_monster pushes it again
; A monster that is not stepping tries the next cell the way it faces. Its cell is moved there provisionally and the step's first offsets are set, then the cell is tested: first for a wall or closed door, then for a creature.
.start_monster_move
    lda monster_sprite,x                ; Step into the next cell in the way it faces: up...
    cmp #spr_monster_up_0               ; Sprite 9, facing up?
    bne monster_right                   ; No: try right
    dec monster_y,x                     ; Yes: one row up
.monster_right
    cmp #spr_monster_right_0            ; Sprite &0B, facing right?
    bne monster_down                    ; No: try down
    inc monster_x,x                     ; Yes: one column right
.monster_down
    cmp #spr_monster_down_0             ; Sprite &0D, facing down?
    bne monster_left                    ; No: try left
    inc monster_y,x                     ; Yes: one row down
.monster_left
    cmp #spr_monster_left_0             ; Sprite &0F, facing left?
    bne set_monster_step                ; No: it does not move
    dec monster_x,x                     ; Yes: one column left
.set_monster_step
    jsr start_monster_step              ; First quarter-cell offsets of the step
    lda monster_x,x                     ; Is the new cell a wall (or a closed door)?
    sta cell_x                          ; ...the new x as cell_x
    lda monster_y,x                     ; The new y...
    sta cell_y                          ; ...as cell_y: the cell to test
    jsr test_wall                       ; Z set if the cell is open
    beq check_monster_blocked           ; Open: is a creature in the way?
; Blocked by a wall: the monster goes back to the cell it was in, with no step under way, and faces a random way. A random 0-7 + 8 gives a sprite &08-&0F; an even one is rounded up to the facing above it, so up, right, down and left are each chosen 2 times in 8. It tries that way on the next frame.
    pla                                 ; Wall: the monster stays where it is...
    tax                                 ; ...its number back in X, which test_wall changed
    lda previous_x                      ; The cell it was in...
    sta monster_x,x                     ; ...back in monster_x
    lda previous_y                      ; ...and its row...
    sta monster_y,x                     ; ...back in monster_y
    lda #0                              ; No step under way:
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    lda system_via_t1c_l                ; Turn a random way, from the System VIA's timer
    and #7                              ; A random 0-7...
    clc                                 ; ...+ 8, the first monster sprite...
    adc #8                              ; ...a sprite &08-&0F
    sta monster_sprite,x                ; Face the monster that way
    and #1                              ; Odd sprites (9, &0B, &0D, &0F) are the facings
    beq turn_monster                    ; Even: round it up to the next facing
    jmp draw_monster                    ; Odd: draw it; it tries the new way next frame
.turn_monster
    inc monster_sprite,x                ; Round up: each way is equally likely, 2 in 8
    jmp draw_monster                    ; Draw it; it tries the new way next frame
; The cell is open: is a monster or hero standing in it? find_creature skips this monster and, because scratch is non-zero, takes hero_damage_taken points from a hero it finds there. A monster mid-slide is still recorded in the cell it is leaving, so it does not block the cell it is entering.
.check_monster_blocked
    pla                                 ; Monster or hero in the new cell? (a hero there is hurt)
    pha                                 ; ...left stacked for later
    sta scratch                         ; Non-zero scratch: skip this monster, check heroes
    jsr find_creature                   ; A = 0 if no creature is at cell_x, cell_y
    cmp #0                              ; Non-zero: a monster or hero is in the cell
    beq monster_vertical                ; No: the cell is free, so the step goes ahead
; Blocked by a creature: as for a wall, the monster stays where it was, with no step, and turns a random way.
    pla                                 ; Yes: stay put, with no step, and turn a random way
    tax                                 ; ...its number back in X, which find_creature changed
    lda previous_x                      ; The cell it was in...
    sta monster_x,x                     ; ...back in monster_x
    lda previous_y                      ; ...and its row...
    sta monster_y,x                     ; ...back in monster_y
    lda #0                              ; No step under way:
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    lda system_via_t1c_l                ; Turn a random way, from the System VIA's timer
    and #7                              ; A random 0-7...
    clc                                 ; ...+ 8, the first monster sprite...
    adc #8                              ; ...a sprite &08-&0F
    sta monster_sprite,x                ; Face the monster that way
    and #1                              ; Odd sprites (9, &0B, &0D, &0F) are the facings
    bne draw_monster                    ; Odd: draw it; it tries the new way next frame
    inc monster_sprite,x                ; Even: round it up to the next facing
    jmp draw_monster                    ; Draw it; it tries the new way next frame
; The step goes ahead. A step into a cell on a room's edge row (moving up or down) or edge column (moving across) is made at once, with no slide, so the sprite is never drawn part way between two rooms. Any other step keeps the old cell in monster_x and monster_y and lets the offsets carry the sprite across over four frames.
.monster_vertical
    pla                                 ; The step goes ahead...
    tax                                 ; ...its number back in X, which find_creature changed
    lda monster_sprite,x                ; Which way is it going?
    cmp #spr_monster_up_0               ; Moving up, so the new row decides?
    beq check_room_edge                 ; Yes: check the new row
    cmp #spr_monster_down_0             ; Moving down, likewise?
    beq check_room_edge                 ; Yes: check the new row
    lda monster_x,x                     ; Across: is the new cell in a room's edge column?
    and #7                              ; Column within its eight-cell room
    beq monster_at_edge                 ; Column 0: the left edge
    cmp #7                              ; Column 7, the right edge?
    beq monster_at_edge                 ; Yes: an edge
    jmp monster_move_on                 ; No: slide there over the coming frames
.check_room_edge
    lda monster_y,x                     ; Up or down: is the new cell in a room's edge row?
    and #7                              ; Row within its eight-cell room
    beq monster_at_edge                 ; Row 0: the top edge
    cmp #7                              ; Row 7, the bottom edge?
    beq monster_at_edge                 ; Yes: an edge
    jmp monster_move_on                 ; No: slide there over the coming frames
.monster_at_edge
    lda #0                              ; Edge: jump straight in, so no slide crosses rooms
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    jmp draw_monster                    ; Draw it squarely in the new cell
.monster_move_on
    lda previous_x                      ; Slide: keep the old cell until the step ends...
    sta monster_x,x                     ; ...back in monster_x
    lda previous_y                      ; ...and its row...
    sta monster_y,x                     ; ...back in monster_y: drawn offset from there
; Draw the monster at its recorded cell, displaced by its offsets, as its facing sprite plus its walking frame, in every view that shows the room. The dying and reappearing paths join at monster_done, which pulls the monster number and moves on to the next.
.draw_monster
    lda monster_x,x                     ; Draw it: its cell, facing + frame, offsets
    sta cell_x                          ; ...as cell_x for plot_at_cell
    lda monster_y,x                     ; Its map y...
    sta cell_y                          ; ...as cell_y for plot_at_cell
    clc                                 ; Ready to add the frame
    lda monster_sprite,x                ; Its facing sprite...
    adc monster_frame,x                 ; ...plus walking frame 0 or 1...
    sta sprite_number                   ; ...is the sprite to plot
    lda monster_offset_x,x              ; How far it has slid across...
    sta plot_offset_x                   ; ...as the horizontal offset
    lda monster_offset_y,x              ; How far it has slid down...
    sta plot_offset_y                   ; ...as the vertical offset
    txa                                 ; Keep the monster number...
    pha                                 ; ...across the plot, which changes X
    jsr plot_at_cell                    ; Draw it in every view whose room shows it
.monster_done
    pla                                 ; The monster number back from the stack...
    tax                                 ; ...in X, to count on down
    dex                                 ; Next monster down
    beq update_monsters_done            ; Past monster 1: all 30 updated
    jmp next_monster_update             ; Otherwise update the next one
.update_monsters_done
    rts                                 ; Return: every monster moved and drawn
; A killed monster is set to sprite &15 (the blank). Each frame the sprite advances, showing the sparkles &16-&19 at the cell and offsets it died at; after the last the monster reappears. Its step counter is left as it was, since a dying monster is dispatched before the step is looked at.
.advance_dying_monster
    pla                                 ; Drop the stacked number (X still has it)
    inc monster_sprite,x                ; Next death frame: &16-&19 are the sparkles
    lda monster_sprite,x                ; Which frame now?
    cmp #spr_sparkle_3 + 1              ; Past the last sparkle (&19)?
    bne draw_monster_death              ; No: draw this sparkle
    jmp monster_reappears               ; Yes: bring it back at a trapdoor
.draw_monster_death
    txa                                 ; Draw the sparkle where the monster died...
    pha                                 ; ...keeping the monster number across the plot
    lda monster_x,x                     ; Its map x, where it died...
    sta cell_x                          ; ...as cell_x for plot_at_cell
    lda monster_y,x                     ; ...and its map y...
    sta cell_y                          ; ...as cell_y for plot_at_cell
    lda monster_sprite,x                ; The sparkle sprite, with no walking frame...
    sta sprite_number                   ; ...is the sprite to plot
    lda monster_offset_x,x              ; Offsets frozen at the moment it died...
    sta plot_offset_x                   ; ...across, as plot_offset_x
    lda monster_offset_y,x              ; ...and how far down it had slid...
    sta plot_offset_y                   ; ...so it sparkles exactly where it died
    jsr plot_at_cell                    ; Draw the sparkle in every view showing it
    jmp monster_done                    ; Pull the monster number and on to the next
