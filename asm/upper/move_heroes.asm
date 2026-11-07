; ***************************************************************************************
; Move the heroes
;
; Let each of the four heroes, in turn from the Ranger, walk, fire or cast magic for this
; frame, redraw them, and let them pick up what lies in their cell. update_game calls
; this first in every frame, before the door and key tests (which use the cells it
; records in hero_door_x/y), draw_objects, move_missiles and update_monsters.
;
; A hero out of play is passed over if nobody plays them (step &63), or handed to
; animate_absent_hero if dying or returning through a Cross. A hero half way through a
; step (step 1) finishes it through continue_hero_step and reads no keys. Otherwise
; heroes 0 and 1 first go through check_magic, which comes back to read_hero_keys, or
; after a cast to draw_moved_hero with no move; then the first held of up, down, right,
; left and fire decides. A direction turns the hero that way (directions 1, 3, 5, 7) and
; tries the next cell, which is recorded in hero_door_x/y whatever is there, so a hero
; pushing on a door opens it. A wall or closed door, a monster (alive or dying, found by
; find_creature) or another hero in play refuses the move; walking into a monster also
; costs one health point, whatever the hero's armour. A move into another room is made at
; once and switches the hero's view (show_hero_room); within a room the Boots of Speed
; make it at once too, and without them the hero stays in the old cell, drawn half a cell
; along, and arrives on the next frame. Fire puts a missile in the first of the hero's
; free slots (3 x hero up to hero_max_missiles of them), in the hero's own cell, with bit
; 7 of its direction set so move_missiles does not erase it off the hero; the bell (VDU
; 7) sounds and the hero's frame flips. With no slot free, or no key held, the hero
; stands still.
;
; A hero who moved or was refused is erased from where they were drawn, using
; previous_x/y and previous_offset_x/y; every hero still in play is then drawn, and
; collect_objects runs whenever object_free_map lets their cell hold an object, every
; frame they are there and not only on arrival. check_magic's delay returns from
; move_heroes itself, so after a cast the later heroes are not moved for three frames.
; The bytes at &6F6D are never executed.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.move_heroes
    ldx #0                              ; Hero 0, the Ranger, first
; For hero X: one out of play is not moved or drawn here, only animated if dying or returning.
.move_hero
    lda hero_direction,x                ; A direction (1, 3, 5, 7) means the hero is in play
    bne remember_hero_position          ; In play: remember where they are, then move them
    lda hero_step,x                     ; Out of play: why? The step says
    cmp #step_out_of_play               ; Step &63 marks a hero nobody plays
    bne animate_absent                  ; Not &63: the hero is dying or returning
    jmp next_hero                       ; Nobody plays them: nothing to move or draw
.animate_absent
    jsr animate_absent_hero             ; Step the skull or resurrection animation
    jmp next_hero                       ; Then on to the next hero
; In play: keep the cell and offsets now drawn, to erase the hero there and to put them back if blocked.
.remember_hero_position
    lda hero_x,x                        ; Remember the hero's cell and offsets before moving
    sta previous_x                      ; previous_x: where to put the hero back if blocked
    lda hero_y,x                        ; The cell's y...
    sta previous_y                      ; ...in previous_y, for the same
    lda hero_offset_x,x                 ; The horizontal pixel offset now drawn...
    sta previous_offset_x               ; ...so erase_hero blanks the image where it is
    lda hero_offset_y,x                 ; And the vertical pixel offset...
    sta previous_offset_y               ; ...for the same erase
; A hero half way through a step arrives this frame and reads no keys; only a standing hero acts.
    lda hero_step,x                     ; Half way between cells (step 1)?
    beq check_magic_key                 ; No: standing in a cell, so read the keys
    jsr continue_hero_step              ; Yes: arrive in the next cell; no keys this frame
    jmp erase_hero                      ; Erase the half-way image, draw the arrival
.check_magic_key
    cpx #2                              ; Hero 0 or 1 (the two with magic)?
    bcs read_hero_keys                  ; Barbarian or Fighter: no magic, straight to the keys
    jmp check_magic                     ; Ranger or Magic-User: magic key, then back
; Standing in a cell: the first held key of up, down, right, left and fire decides what the hero does.
.read_hero_keys
    lda hero_key_up,x                   ; Up key held? (directions beat fire, up first)
    jsr test_key                        ; Z set if held
    bne check_key_down                  ; Not held: try down
    lda #1                              ; Held: face up...
    sta hero_direction,x                ; ...direction 1: drawn as sprite base + 1 or + 2
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell above
.check_key_down
    lda hero_key_down,x                 ; Down key held?
    jsr test_key                        ; Z set if held
    bne check_key_right                 ; Not held: try right
    lda #5                              ; Held: face down...
    sta hero_direction,x                ; ...direction 5: drawn as sprite base + 5 or + 6
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell below
.check_key_right
    lda hero_key_right,x                ; Right key held?
    jsr test_key                        ; Z set if held
    bne check_key_left                  ; Not held: try left
    lda #3                              ; Held: face right...
    sta hero_direction,x                ; ...direction 3: drawn as sprite base + 3 or + 4
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell to the right
.check_key_left
    lda hero_key_left,x                 ; Left key held?
    jsr test_key                        ; Z set if held
    bne check_key_fire                  ; Not held: try fire
    lda #7                              ; Held: face left...
    sta hero_direction,x                ; ...direction 7: drawn as sprite base + 7 or + 8
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell to the left
.check_key_fire
    lda hero_key_fire,x                 ; Fire key held? (only when no direction is)
    jsr test_key                        ; Z set if held
    beq fire_missile                    ; Held: launch a missile the way the hero faces
    jmp draw_moved_hero                 ; No key: the hero stands still, drawn in place
; Fire: put a missile in the hero's first free slot, in the hero's cell, flying the way the hero faces.
.fire_missile
    txa                                 ; Slots 3 x hero to 3 x hero + hero_max_missiles - 1
    sta scratch                         ; Hero number kept to add...
    asl a                               ; ...doubled: 2 x hero...
    clc                                 ; ...(no carry in)...
    adc scratch                         ; ...+ hero: 3 x hero, the hero's first slot
    tay                                 ; Y walks the hero's slots
    adc hero_max_missiles,x             ; - how many missiles the hero may have in flight...
    sta scratch                         ; ...the first slot past the hero's own
.find_missile_slot
    lda missile_direction,y             ; This slot's missile still flying?
    bne next_missile_slot               ; Yes: look at the hero's next slot
    lda hero_direction,x                ; Free: missile direction = (hero direction + 1) / 2
    clc                                 ; Hero direction 1, 3, 5 or 7...
    adc #1                              ; ...+ 1: 2, 4, 6 or 8...
    lsr a                               ; ...halved: 1-4, up, right, down, left
    ora #&80                            ; Bit 7: just fired, so not erased off the hero
    sta missile_direction,y             ; The slot is now in flight
    lda hero_x,x                        ; It starts in the hero's cell; move_missiles moves it on
    sta missile_x,y                     ; ...missile x = hero x...
    lda hero_y,x                        ; ...and the hero's y...
    sta missile_y,y                     ; ...as missile y
    lda #7                              ; The firing sound: VDU 7, the bell...
    jsr oswrch                          ; ...through OSWRCH, the same for every hero
    lda hero_missile_damage,x           ; The hero's current missile damage...
    sta missile_damage,y                ; ...goes with this missile, for whatever it hits
    lda hero_missile_sprites,x          ; The hero's weapon sprites (arrow, fireball, axe, sword)...
    sta missile_sprite_base,y           ; ...so it is drawn, and its owner known, by these
    lda previous_x                      ; Put back the cell remembered at the start...
    sta hero_x,x                        ; ...the same cell: nothing has moved the hero here
    lda previous_y                      ; And the y...
    sta hero_y,x                        ; ...is put back the same way
    lda hero_frame,x                    ; Next animation frame...
    eor #1                              ; ...0 and 1 alternate...
    sta hero_frame,x                    ; ...so the hero is seen to throw
    jmp draw_moved_hero                 ; Draw the hero where they stand; no erase needed
; Unreachable after the JMP: DEY and BNE find_missile_slot.
; Slot taken: try the hero's next one, up to the limit worked out above.
.next_missile_slot
    iny                                 ; The hero's next slot
    cpy scratch                         ; Past the hero's last slot?
    bne find_missile_slot               ; No: is that one free?
    jmp draw_moved_hero                 ; All the hero's missiles in flight: no shot
; Move: try the next cell the way the hero faces. A wall or closed door, a monster, or another hero in play refuses it. The hero has already turned, so a refused move still changes the way they face.
.step_hero
    lda hero_direction,x                ; Move the hero's cell in the direction faced: up...
    cmp #1                              ; Direction 1, facing up?
    bne step_right                      ; No: try right
    dec hero_y,x                        ; Up: one row up the map
.step_right
    cmp #3                              ; Direction 3, facing right? (A still holds it)
    bne step_down                       ; No: try down
    inc hero_x,x                        ; Right: one column along
.step_down
    cmp #5                              ; Direction 5, facing down?
    bne step_left                       ; No: try left
    inc hero_y,x                        ; Down: one row down the map
.step_left
    cmp #7                              ; Direction 7, facing left?
    bne note_new_cell                   ; No: the cell is moved
    dec hero_x,x                        ; Left: one column back
.note_new_cell
    lda hero_x,x                        ; Record the cell tried, wall or not...
    sta hero_door_x,x                   ; ...so update_game finds a door the hero walks into
    lda hero_y,x                        ; And the y tried...
    sta hero_door_y,x                   ; ...in hero_door_y, for the same door test
    lda hero_x,x                        ; Is the cell tried a wall (or a closed door)?
    sta cell_x                          ; cell_x: the cell for test_wall
    lda hero_y,x                        ; And the y tried...
    sta cell_y                          ; ...in cell_y, also used by the hero test
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across test_wall
    jsr test_wall                       ; Y = the cell's wall bit; map_ptr = its room
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, which test_wall used for the bit
    cpy #0                              ; Wall bit clear?
    beq check_monster_in_cell           ; Clear: is a monster in the way?
; Refused by a wall or closed door: back to the old cell, standing whole. The door test in update_game may still open it.
    lda previous_x                      ; A wall: the hero stays in the old cell...
    sta hero_x,x                        ; ...hero_x put back from previous_x...
    lda previous_y                      ; ...and y back...
    sta hero_y,x                        ; ...so the hero does not enter the wall
.cancel_hero_step
    lda #0                              ; The move is over: the hero stands in a whole cell
    sta hero_step,x                     ; No step under way...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...and no vertical offset
    jmp erase_hero                      ; Erase the old image, draw the hero in their cell
; No wall. A monster in the cell, alive or dying, refuses the move and costs the hero one health point.
.check_monster_in_cell
    lda #0                              ; Is a monster in the cell tried?
    sta scratch                         ; scratch 0: look for monsters only, not heroes
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across find_creature
    jsr find_creature                   ; Y non-zero if a monster is in the cell
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, which find_creature used for monsters
    cpy #0                              ; A monster there?
    beq check_hero_in_cell              ; No: is another hero in the way?
    lda previous_x                      ; Yes: the hero stays in the old cell...
    sta hero_x,x                        ; ...hero_x put back from previous_x...
    lda previous_y                      ; ...and y back...
    sta hero_y,x                        ; ...so the hero stays out of the monster's cell
    lda #0                              ; The move is over: the hero stands in a whole cell...
    sta hero_step,x                     ; ...no step under way...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...and no vertical offset
    jsr lose_health_point               ; ...and pays a health point for walking into it
    jmp erase_hero                      ; Erase the old image, draw the hero in their cell
; Nor a monster. Another hero in play there refuses the move at no cost; a hero out of play (a skull) does not.
.check_hero_in_cell
    stx scratch                         ; Is another hero in play in the cell tried?
    ldy #0                              ; From hero 0
.check_other_hero
    cpy scratch                         ; The moving hero itself?
    beq next_other_hero                 ; Yes: skip it
    lda hero_x,y                        ; Other hero's x...
    cmp cell_x                          ; ...the cell tried's x?
    bne next_other_hero                 ; No: not in the way
    lda hero_y,y                        ; Other hero's y...
    cmp cell_y                          ; ...the cell tried's y?
    bne next_other_hero                 ; No: not in the way
    lda hero_direction,y                ; There, but in play?
    beq next_other_hero                 ; No (a skull, say): not in the way
    lda previous_x                      ; In play there: the hero stays in the old cell...
    sta hero_x,x                        ; ...hero_x put back from previous_x...
    lda previous_y                      ; ...and y back...
    sta hero_y,x                        ; ...so heroes in play never share a cell
    lda #0                              ; The move is over: the hero stands in a whole cell...
    sta hero_step,x                     ; ...no step under way...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...and no vertical offset
    jmp erase_hero                      ; Erase the old image, draw the hero in their cell
.next_other_hero
    iny                                 ; Next hero to compare with the cell tried
    cpy #4                              ; Checked all four?
    bne check_other_hero                ; No: check that one
; The cell is free. A move into another room is made at once, as is one with the Boots of Speed; otherwise the hero is drawn half way and arrives on the next frame.
    txa                                 ; The way is clear. Is the cell tried in another room?
    asl a                               ; Two bytes per view_room entry...
    tax                                 ; ...so X = 2 x hero indexes the hero's view
    lda view_room,x                     ; The low byte of the room the hero's view shows...
    cmp map_ptr                         ; ...against the cell's room, left by test_wall
    beq check_boots                     ; Same room: the boots decide the pace
    txa                                 ; New room: the hero arrives at once...
    lsr a                               ; Halve the index...
    tax                                 ; ...back to the hero number
    jsr show_hero_room                  ; Switch the hero's view to the new room and draw it
    jmp cancel_hero_step                ; ...and the move ends in the new cell, no half step
.check_boots
    txa                                 ; Wearing the Boots of Speed?
    lsr a                               ; Halve the view index...
    tax                                 ; ...back to the hero number
    lda hero_has_boots,x                ; Non-zero while the hero wears the boots
    beq stay_in_old_cell                ; No: a half step this frame
    lda #0                              ; Yes: arrive in the cell at once, with no step
    sta hero_offset_x,x                 ; No horizontal offset...
    sta hero_offset_y,x                 ; ...no vertical offset...
    sta hero_step,x                     ; ...and no step: one cell a frame, twice the pace
    jmp erase_hero                      ; Erase the old position and draw the new
.stay_in_old_cell
    lda previous_x                      ; No boots: hero stays in the old cell, drawn half way
    sta hero_x,x                        ; ...by start_hero_step's offsets; next frame it arrives
    lda previous_y                      ; And the old y...
    sta hero_y,x                        ; ...so others still meet the hero in the old cell
; Erase the hero's image from where it was drawn last.
.erase_hero
    lda #spr_blank                      ; Erase the hero's image as it was before this frame
    sta sprite_number                   ; The blank sprite...
    lda previous_x                      ; ...at the hero's old cell...
    sta cell_x                          ; ...as the cell to plot at
    lda previous_y                      ; And the old y...
    sta cell_y                          ; ...in cell_y: where the hero was last drawn
    lda previous_offset_x               ; With the old pixel offsets too...
    sta plot_offset_x                   ; ...the old horizontal offset...
    lda previous_offset_y               ; ...and the old vertical offset...
    sta plot_offset_y                   ; ...so a half-way image is blanked where it was
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Blank the hero in every view showing that cell
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, to draw the same hero
; Draw the hero, then pick up any object in their cell. A hero comes here on every frame they are moved, standing still or not, so a hero standing on an energy drainer loses 10 health a frame.
.draw_moved_hero
    clc                                 ; Clear carry for the sprite sum
    lda hero_direction,x                ; Still in play? A bump or magic's cost may have killed
    beq next_hero                       ; Direction 0: out of play, not drawn
    adc hero_frame,x                    ; Sprite = direction + frame (0 or 1)...
    adc hero_sprites,x                  ; ...+ the hero's base: Ranger, Magic-User, and so on
    sta sprite_number                   ; The sprite to draw
    jsr draw_hero                       ; Draw them in every view showing their cell
    lda hero_x,x                        ; Can the hero's cell hold an object?
    sta cell_x                          ; The hero's cell, to test for an object...
    lda hero_y,x                        ; And the hero's y...
    sta cell_y                          ; ...in cell_y, where they now stand
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across test_object_free
    jsr test_object_free                ; Y zero if an object may lie in the cell
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for collect_objects
    cpy #0                              ; Can an object lie there?
    bne next_hero                       ; No: nothing to pick up; next hero
    jsr collect_objects                 ; Yes: pick up whatever is there
; On to the next hero, until all four have had their turn.
.next_hero
    inx                                 ; Next hero, in the order Ranger to Fighter
    cpx #4                              ; All four heroes moved?
    beq move_heroes_done                ; Yes: every hero has had this frame's turn
    jmp move_hero                       ; No: move the next hero
.move_heroes_done
    rts                                 ; Return to update_game, all four heroes moved and drawn
; ***************************************************************************************
; Move the missiles
;
; Fly every missile in flight one cell and settle what it hits. update_game calls this
; each frame, after move_heroes (which fires them) and draw_objects, and before
; update_monsters, which plays out the deaths it causes.
;
; Each of the twelve slots (three per hero, from 3 x hero) with a non-zero
; missile_direction is in flight. It is erased from its cell, unless fired this frame
; (bit 7 set) and so still on its hero, whose frame flip_firer_frame then flips back. It
; moves one cell in its direction (1-4: up, right, down, left), a cell a frame with no
; pixel offset, and the new cell is tried in turn, with the slot kept on the stack
; throughout. A wall spends the missile. A live monster takes its damage through
; monster_hit, which spends the missile and, for a kill, gives the firer a point; a
; monster already sparkling lets it through. The test for live is a sprite below the
; first sparkle, so a monster killed earlier in the frame (sprite blank until
; update_monsters runs) can be hit again. An energy drainer is worn down a stage, and
; removed after its last; the firer scores a point and the missile is turned round in the
; drainer's cell, so it can fly back into its firer. Any hero in the cell, the firer
; included and whether in play or not (a skull stops it), spends the missile, and
; lose_health_point takes missile_damage points, one at a time, from a hero in play.
; Otherwise the missile is drawn in its new cell as missile_sprite_base + direction, the
; weapon pointing the way it flies. A spent missile is not drawn, and its direction 0
; frees the slot for its hero's next shot. Missiles pass through one another and through
; objects other than drainers.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.move_missiles
    lda #0                              ; Missiles move a whole cell a frame...
    sta plot_offset_x                   ; ...so they are plotted with no horizontal offset...
    sta plot_offset_y                   ; ...and no vertical offset
    ldx #0                              ; Slot 0 first: the Ranger's first missile
; For missile slot X: an empty slot (direction 0) is passed over. One fired this frame shares its hero's cell and is moved without being erased.
.move_missile
    lda missile_direction,x             ; A direction means this slot's missile is flying
    bne check_just_fired                ; Flying: erase and move it
    jmp next_missile                    ; Empty slot: nothing to move
.check_just_fired
    bpl erase_missile                   ; Bit 7 clear: flying since an earlier frame
    and #&7f                            ; Fired this frame: drop the just-fired bit...
    sta missile_direction,x             ; ...leaving direction 1-4
    jsr flip_firer_frame                ; ...flip the firer's animation frame again...
    jmp step_missile                    ; ...and move it unerased: its cell is the hero's
; Erase the missile and move it one cell.
.erase_missile
    lda #spr_blank                      ; Erase the missile from the cell it flew to last frame
    sta sprite_number                   ; The blank sprite
    lda missile_x,x                     ; The missile's x...
    sta cell_x                          ; ...as the cell to plot at
    lda missile_y,x                     ; And its y...
    sta cell_y                          ; ...in cell_y: where it was drawn last frame
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Blank it in every view showing that cell
    pla                                 ; Recover the missile slot...
    tax                                 ; ...into X, to move the same missile
.step_missile
    lda missile_direction,x             ; Move it one cell the way it flies: up...
    cmp #1                              ; Direction 1: up
    bne missile_right                   ; No: try right
    dec missile_y,x                     ; Up: one row up the map
.missile_right
    cmp #2                              ; Direction 2: right? (A still holds it)
    bne missile_down                    ; No: try down
    inc missile_x,x                     ; Right: one column along
.missile_down
    cmp #3                              ; Direction 3: down?
    bne missile_left                    ; No: try left
    inc missile_y,x                     ; Down: one row down the map
.missile_left
    cmp #4                              ; Direction 4: left?
    bne check_missile_wall              ; No: the cell is moved
    dec missile_x,x                     ; Left: one column back
; Try the new cell: wall, monster, energy drainer, then hero. The slot stays on the stack through the tests.
.check_missile_wall
    lda missile_x,x                     ; Does the missile's new cell hold a wall or door?
    sta cell_x                          ; ...as the cell to test
    lda missile_y,x                     ; And its y...
    sta cell_y                          ; ...in cell_y, kept for every test below
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack across the tests
    jsr test_wall                       ; Z set if the cell is clear of walls
    beq check_missile_monster           ; Clear: is a monster there?
; Spent: the missile stops where it is, undrawn, and its slot is free for its hero's next shot.
.missile_spent_pop
    pla                                 ; A wall: the missile stops, never drawn there
    tax                                 ; Recover the missile slot
.missile_spent
    lda #0                              ; The missile is spent: free its slot...
    sta missile_direction,x             ; ...direction 0, so the hero may fire again
    jmp next_missile                    ; On to the next slot
; No wall. A live monster takes the hit; a sparkling (dying) one lets the missile through.
.check_missile_monster
    lda #0                              ; Is a monster in the new cell?
    sta scratch                         ; scratch 0: look for monsters only, not heroes
    jsr find_creature                   ; Z clear, X = the monster, if one is in the cell
    beq check_missile_object            ; None: an object or a hero?
    lda monster_sprite,x                ; One there: is it still alive?
    cmp #spr_sparkle_0                  ; Sparkles on: dying; the blank (just killed) is live
    bcs check_missile_object            ; Dying: the missile flies through it
    pla                                 ; Alive: hit it, with the slot off the stack...
    tay                                 ; ...in Y, for monster_hit
    jmp monster_hit                     ; Hit sound, damage; it spends the missile
; monster_hit jumps back here, slot in X, when its hit kills the monster.
.monster_killed
    jsr credit_missile_owner            ; monster_hit's kill: a point to the firer...
    jmp missile_spent                   ; ...and the missile is spent
; No live monster there. If the cell can hold an object, look for an energy drainer there.
.check_missile_object
    pla                                 ; Could the new cell hold an object (a drainer)?
    tax                                 ; Recover the missile slot
    lda missile_x,x                     ; The missile's x...
    sta cell_x                          ; ...as the cell to test
    lda missile_y,x                     ; And its y...
    sta cell_y                          ; ...in cell_y (find_creature left it intact)
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack across test_object_free
    jsr test_object_free                ; Y zero if an object may lie in the cell
    pla                                 ; Recover the missile slot...
    tax                                 ; ...into X, which test_object_free used for the bit
    cpy #0                              ; Can an object lie there?
    bne check_missile_hero              ; No: no drainer; is a hero there?
; A missile hitting an energy drainer wears it down, scores for the firer and turns round in its cell.
    txa                                 ; Look for an energy drainer at the cell...
    pha                                 ; Keep the missile slot while X runs over objects
    ldx #max_object                     ; ...objects 30 to 1
.check_object_drainer
    lda object_x,x                      ; This object's x...
    cmp cell_x                          ; ...the missile's cell?
    bne next_object_drainer             ; No: the next object
    lda object_y,x                      ; This object's y...
    cmp cell_y                          ; ...the missile's cell too?
    bne next_object_drainer             ; No: the next object
    lda object_type,x                   ; The object in the cell: a drainer (&53-&5E)?
    cmp #spr_drainer_0                  ; Below the drainer sprites?
    bcc no_drainer                      ; Yes: some other object; stop looking
    cmp #spr_drainer_11 + 1             ; Past the last drainer stage?
    bcs no_drainer                      ; Yes: some other object; stop looking
    inc object_type,x                   ; A drainer: the hit wears it down a stage
    lda object_type,x                   ; Its new stage...
    cmp #spr_drainer_11 + 1             ; Past the last (12 hits from the first stage)?
    bne credit_drainer_hit              ; No: it survives; score and bounce
    lda #off_map                        ; Worn away: take it out of the level
    sta object_x,x                      ; Off the map in x...
    sta object_y,x                      ; ...and y, so it is never drawn or met again
.credit_drainer_hit
    pla                                 ; A point to the hero who fired, for every hit
    tax                                 ; Recover the missile slot
    jsr credit_missile_owner            ; The missile's sprites say whose it is
    lda missile_direction,x             ; Turn the missile round, still in the drainer's cell
    cmp #1                              ; Direction 1, flying up?
    bne reverse_right                   ; No: try right
    lda #3                              ; Up turns to down...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
.reverse_right
    cmp #2                              ; Direction 2, flying right?
    bne reverse_down                    ; No: try down
    lda #4                              ; Right turns to left...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
.reverse_down
    cmp #3                              ; Direction 3, flying down?
    bne reverse_left                    ; No: it was flying left
    lda #1                              ; Down turns to up...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
.reverse_left
    lda #2                              ; Left turns to right...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
.next_object_drainer
    dex                                 ; Next object down, looking for one in the cell
    bne check_object_drainer            ; Until all 30 are checked
.no_drainer
    pla                                 ; No drainer in the cell: drop the saved slot...
    tax                                 ; ...back into X
; The first hero in the cell, in play or not, stops the missile.
.check_missile_hero
    txa                                 ; Is a hero in the new cell? Any hero, even the firer
    pha                                 ; Keep the missile slot while X runs over heroes
    ldx #0                              ; From hero 0
.check_hero_hit
    pla                                 ; Fetch the missile slot...
    tay                                 ; ...into Y, to read its damage if this hero is hit...
    pha                                 ; ...leaving it on the stack
    lda hero_x,x                        ; This hero's x...
    cmp cell_x                          ; ...the missile's cell?
    bne next_hero_hit                   ; No: the next hero
    lda hero_y,x                        ; This hero's y...
    cmp cell_y                          ; ...the missile's cell too?
    bne next_hero_hit                   ; No: the next hero
    lda missile_damage,y                ; Hit: the hero loses the missile's damage...
    tay                                 ; ...Y health points, one at a time
.take_missile_damage
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack across the call
    jsr lose_health_point               ; One point (none if out of play, as a skull)
    pla                                 ; Recover the count...
    tay                                 ; ...of damage points still to take, into Y
    dey                                 ; One fewer to take
    bne take_missile_damage             ; More to take: take the next
    jmp missile_spent_pop               ; The missile is spent, slot still on the stack
.next_hero_hit
    inx                                 ; Next hero to test against the missile's cell
    cpx #4                              ; All four heroes checked?
    bne check_hero_hit                  ; No: check the next hero against the missile's cell
; No wall, live monster or hero in the new cell: draw the missile there, pointing the way it flies (a drainer will have turned it round), then go on to the next slot.
    pla                                 ; Nothing hit: the missile flies on, drawn in its new cell
    tax                                 ; Missile slot back in X
    clc                                 ; Sprite = the missile's base...
    lda missile_sprite_base,x           ; ...(its hero's weapon, the sprite before its up sprite)...
    adc missile_direction,x             ; ...plus its direction, 1-4: the weapon pointing that way
    sta sprite_number                   ; ...is the sprite to plot
    txa                                 ; Keep the missile slot...
    pha                                 ; ...across the plot
    jsr plot_at_cell                    ; Plot the missile in every view showing its cell
    pla                                 ; Recover the missile slot...
    tax                                 ; ...into X, for the slot loop
.next_missile
    inx                                 ; Next missile slot
    cpx #&0c                            ; Past the twelfth slot (three per hero)?
    beq move_missiles_done              ; Yes: every missile moved this frame
    jmp move_missile                    ; No: move this slot's missile
.move_missiles_done
    rts                                 ; Return to update_game: all twelve slots done
