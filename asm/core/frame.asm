; ***************************************************************************************
; Run one frame of play
;
; Do all of a frame's play apart from the exit. Called by play_level once a frame, after
; check_for_victory; play_level deals with the exit when this returns. The work, in
; order:
;
; 1. move_heroes: each hero in play walks, fires or casts magic, is redrawn, and picks up
;    any object in their cell. It records in hero_door_x/y the cell each hero stepped or
;    tried to step into.
; 2. Doors (check_doors): for each hero in turn, doors 20 to 1 are compared with that
;    cell. If one is there and the hero carries its key (key n opens door n; hero_key 0
;    means none, and there is no door 0), the door opens: the hero scores 7 points, the
;    door sound plays (food_sound at a lower pitch), the door is erased from every view,
;    its wall bit in room_walls is cleared, its entry in door_x/door_y is moved off the
;    map, and the key is used up and its panel icon erased. At most one door opens per
;    hero per frame. Every hero is tested, in play or not.
; 3. Keys (draw_keys): every key on the floor is redrawn, then each hero is checked. A
;    dead hero whose death animation has finished drops their key where they fell. A hero
;    in play, or still dying, who stands on a key picks it up and leaves the key they
;    carried, if any, in its place. hero_key_dropped remembers the key left there, and
;    the hero picks up no key until they are off it, so a swap happens once, on arrival.
;    draw_keys leaves that key undrawn meanwhile, or it would be drawn over the hero on
;    every frame. A hero out of play with no key forgets it.
;    In the 1987 release it was a flag that held off only the next frame, so a hero who
;    stayed on the cell swapped back and forth every other frame.
; 4. draw_objects: the objects are replotted, repairing any cell a moving sprite has
;    crossed.
; 5. move_missiles: each missile in flight moves one cell and hits what it meets.
; 6. update_monsters: the trapdoors are redrawn and the monsters move.
; 7. The pause key: if it is held, the game freezes here until it is pressed again.
;    OSBYTE &7A reports only the lowest-numbered key held, so a held movement key can
;    hide it.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.update_game
    jsr move_heroes                     ; Move the heroes: steps, shots, magic, pick-ups
; Doors: for each hero, find a door at the cell they last stepped or tried to step into, and open it if they carry its key.
    ldx #0                              ; For each hero, 0-3...
.check_doors
    stx scratch                         ; ...hero number in scratch, for the door's points
    lda hero_door_x,x                   ; The cell hero X last stepped or bumped into...
    sta cell_x                          ; ...is the cell to test
    lda hero_door_y,x                   ; ...and its y...
    sta cell_y                          ; ...is the cell's y
    txa                                 ; Keep the hero's number...
    pha                                 ; ...on the stack for the key check
    ldx #max_door                       ; Doors 20 to 1: is one in that cell?
.check_door
    lda door_x,x                        ; This door's x (&FF once opened)...
    cmp cell_x                          ; ...the cell being tested?
    beq check_door_cell_y               ; Yes: check its y
    jmp next_door                       ; No: next door
.check_door_cell_y
    lda door_y,x                        ; This door's y (&FF once opened)...
    cmp cell_y                          ; ...the cell being tested?
    beq check_door_key                  ; Yes: the hero has walked into this door
    jmp next_door                       ; No: next door
.check_door_key
    pla                                 ; Does the hero carry this door's key?
    tay                                 ; Y = the hero's number...
    pha                                 ; ...kept on the stack
    txa                                 ; A = the door's number: key n opens door n
    cmp hero_key,y                      ; Is it the number of the key the hero carries?
    beq open_door                       ; Yes: open door
    jmp next_door                       ; No key, or the wrong one: the door stays shut
; The hero has the key: score 7, sound the door, erase it, clear its wall bit, and use up the key.
.open_door
    txa                                 ; Open the door: 7 points...
    pha                                 ; Keep the door's number...
    tya                                 ; ...and the hero's...
    pha                                 ; ...on the stack
    ldy #7                              ; Seven points, one per add_point call
    ldx scratch                         ; ...X = the hero who opened the door, for add_point
.door_points_loop
    tya                                 ; Keep the count of points still to give
    pha                                 ; ...on the stack, as add_point uses Y
    jsr add_point                       ; One point to the hero's score, redrawn
    pla                                 ; Recover the count of points to give
    tay                                 ; ...back into Y
    dey                                 ; One fewer to give
    bne door_points_loop                ; More to give: add the next point
; The door sound: food_sound played at a lower pitch.
    lda #&96                            ; The door sound is the food sound, lower...
    sta food_sound + 4                  ; ...pitch 150 instead of food's 200
    ldx #<(food_sound)                  ; SOUND food_sound: block address low...
    ldy #>(food_sound)                  ; ...and high: the door sound's block
    lda #osword_sound                   ; OSWORD 7: SOUND
    jsr osword                          ; Sound the door opening  SOUND command
    lda #&c8                            ; ...then put food's pitch back...
    sta food_sound + 4                  ; ...to 200, for the next food eaten
; Erase the door from every view showing it, keeping its cell in monster_x + 35 and monster_y + 35 across plot_at_cell, which overwrites cell_x and cell_y.
    lda cell_y                          ; Save the door's cell; plot_at_cell changes cell_x/y...
    sta monster_y + 35                  ; ...y into the spare byte at monster_y + 35...
    lda cell_x                          ; ...then the door's x...
    sta monster_x + 35                  ; ...into the spare byte at monster_x + 35
    lda #spr_blank                      ; Erase the door from the screen...
    sta sprite_number                   ; ...the blank as the sprite to plot
    lda #0                              ; ...squarely on the door's cell...
    sta plot_offset_x                   ; ...no shift across (plot_offset_x 0)...
    sta plot_offset_y                   ; ...or down (plot_offset_y 0)
    jsr plot_at_cell                    ; Blank the door in every view showing its room
    lda monster_x + 35                  ; ...and recover its cell
    sta cell_x                          ; ...back into cell_x...
    lda monster_y + 35                  ; ...then the door's y...
    sta cell_y                          ; ...back into cell_y
    pla                                 ; Recover the hero number pushed at open_door...
    tay                                 ; ...into Y, unused: Y is the wall row index below
    pla                                 ; Recover the door number...
    tax                                 ; ...into X, to remove its entry once the wall is gone
; Clear the door's bit in room_walls, so test_wall no longer stops heroes, monsters or missiles there.
    lda cell_y                          ; Door's room: (y AND &F8) x 4 + (x AND &F8)...
    and #&f8                            ; ...y AND &F8: the room's top row, 8 rows a room...
    sta scratch                         ; ...kept in scratch to add three more times
    clc                                 ; ...clear carry for the adds
    adc scratch                         ; ...x 2...
    adc scratch                         ; ...x 3...
    adc scratch                         ; ...x 4: 32 bytes per row of four rooms
    sta map_ptr                         ; ...kept in map_ptr
    lda cell_x                          ; ...plus the room column...
    and #&f8                            ; ...x AND &F8: 8 bytes per room...
    adc map_ptr                         ; ...added to the row of rooms' offset...
    sta map_ptr                         ; ...giving the room's offset in room_walls
    lda #>(room_walls)                  ; ...plus room_walls' page...
    sta map_ptr_hi                      ; ...in map_ptr_hi: map_ptr points at the room
    txa                                 ; Keep the door number...
    pha                                 ; ...on the stack while X is used for the bit
    lda cell_x                          ; ...mask for the column...
    and #7                              ; ...x AND 7, the cell's column in the room...
    tax                                 ; ...as the index into bit_masks...
    lda bit_masks,x                     ; ...for the cell's bit in its row byte...
    eor #&ff                            ; ...inverted, to keep every other wall...
    sta scratch                         ; ...as the mask to clear it with
    lda cell_y                          ; ...byte for the row...
    and #7                              ; ...y AND 7, the cell's row in the room...
    tay                                 ; ...indexes the room's eight row bytes
    lda (map_ptr),y                     ; ...the row of walls holding the door...
    and scratch                         ; ...knock out the door's bit...
    sta (map_ptr),y                     ; ...so the doorway no longer blocks anyone
    pla                                 ; Recover the door number...
    tax                                 ; ...into X, to index door_x and door_y
; Remove the door from door_x/door_y and use up the key, erasing its icon from the hero's panel.
    lda #off_map                        ; Take the door out of the level...
    sta door_x,x                        ; ...x off the map: no hero matches it again...
    sta door_y,x                        ; ...and y off the map
    pla                                 ; Recover the hero number pushed at check_doors...
    tax                                 ; ...into X, for their key slot and panel
    lda #0                              ; The key is used up: the hero carries none
    sta hero_key,x                      ; ...in the hero's key slot
    lda #spr_blank_key_icon             ; Erase the key icon from the hero's panel
    sta sprite_number                   ; ...as the sprite to plot
    lda hero_panel_y,x                  ; ...from the hero's panel row...
    sec                                 ; ...set carry to subtract
    sbc #&0d                            ; ...less 13: the key icon's row...
    sta plot_y                          ; ...as plot_y, the icon's screen row
    lda #panel_left + 5                 ; ...in panel column panel_left + 5...
    sta plot_x                          ; ...as plot_x, the icon's column
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across plot_sprite
    jsr plot_sprite                     ; Plot the blank icon over the key icon
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for next_hero_doors
    jmp next_hero_doors                 ; One door a frame per hero: on to the next hero
.next_door
    dex                                 ; Next door down, 20 to 1
    beq doors_done                      ; Doors all checked: this hero is done
    jmp check_door                      ; Otherwise check the next door
.doors_done
    pla                                 ; Recover the hero number pushed at check_doors...
    tax                                 ; ...into X, to move on from this hero
.next_hero_doors
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four heroes done?
    beq draw_keys                       ; Yes: on to the keys
    jmp check_doors                     ; No: check this hero against the doors
; Keys. Redraw the keys on the floor, then for each hero: drop a dead hero's key where they fell, or pick up the key at the hero's cell, leaving any key carried in its place. The swap flag only skips the frame after a swap, so a hero who stays on the cell swaps back on the frame after that.
.draw_keys
    lda #0                              ; Redraw every key lying on the floor, 20 to 1
    sta plot_offset_x                   ; ...on their cells: no pixel offset...
    sta plot_offset_y                   ; ...across or down: keys sit squarely in cells
    lda #spr_key                        ; ...in the key sprite...
    sta sprite_number                   ; ...as the sprite to plot
    ldx #max_key                        ; ...counting keys down from 20; entry 0 is never drawn
.draw_each_key
    txa                                 ; Is this key under the hero who dropped it?
    ldy #3                              ; ...each hero, 3 to 0...
.check_key_under_hero
    cmp hero_key_dropped,y              ; ...dropped this key and is still on it?
    beq draw_next_key                   ; Yes: leave it undrawn, so the hero shows
    dey                                 ; Next hero down
    bpl check_key_under_hero            ; More heroes: check the next
    lda key_x,x                         ; The key's x...
    sta cell_x                          ; ...is the column to plot at...
    lda key_y,x                         ; ...and y (off the map if it is carried)...
    sta cell_y                          ; ...the row: plot_at_cell needs both each time
    txa                                 ; Keep the key number...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Plot it in every view showing its cell
    pla                                 ; Recover the key number...
    tax                                 ; ...into X, counting down the keys
.draw_next_key
    dex                                 ; Next key down
    bne draw_each_key                   ; More keys: draw the next
    ldx #0                              ; For each hero, from hero 0...
.check_hero_keys
    lda hero_direction,x                ; Still in play (a direction set)?
    bne check_key_swap                  ; Yes: look for a key to pick up
    lda hero_key,x                      ; Out of play: dead, dying or gone. Holding a key?
    bne check_death_finished            ; Yes: see whether the death has played out
    lda #0                              ; No key: forget any key dropped in a swap...
    sta hero_key_dropped,x              ; ...so draw_keys shows it again
    jmp next_hero_keys                  ; Nothing more to do for this hero
.check_death_finished
    lda hero_frame,x                    ; Has the death animation reached its end?
    cmp #8                              ; ...frame 8 is the last of the death
    bne check_key_swap                  ; Still dying: key checks go on as if in play
; A dead hero's death animation has ended: leave their key on the cell where they fell and erase its icon.
    ldy hero_key,x                      ; Yes: drop the key where the hero fell
    lda hero_x,x                        ; ...at the hero's x...
    sta key_x,y                         ; ...as the key's x...
    lda hero_y,x                        ; ...and the hero's y...
    sta key_y,y                         ; ...as the key's y
    lda #0                              ; The dead hero carries no key now...
    sta hero_key,x                      ; ...so this is done only once
    lda #spr_blank_key_icon             ; Erase the key icon from the hero's panel
    sta sprite_number                   ; ...as the sprite to plot
    lda hero_panel_y,x                  ; ...using the hero's panel row...
    sec                                 ; ...set carry to subtract
    sbc #&0d                            ; ...less 13: the key icon's row...
    sta plot_y                          ; ...as plot_y, the icon's screen row
    lda #panel_left + 5                 ; ...in panel column panel_left + 5...
    sta plot_x                          ; ...as plot_x, the icon's column
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across plot_sprite
    jsr plot_sprite                     ; Plot the blank icon over the key icon
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for next_hero_keys
    jmp next_hero_keys                  ; Key dropped: on to the next hero
.check_key_swap
    ldy hero_key_dropped,x              ; The key this hero dropped in a swap, if any
    beq check_key_cell                  ; None: look for a key at the hero's cell
    lda key_x,y                         ; Is the hero still on it? Its x...
    cmp hero_x,x                        ; ...at the hero's x?
    bne left_dropped_key                ; No: the hero has left it
    lda key_y,y                         ; ...and its y...
    cmp hero_y,x                        ; ...at the hero's y?
    bne left_dropped_key                ; No: the hero has left it
    jmp next_hero_keys                  ; Still on it: no swap back; on to the next hero
.left_dropped_key
    lda #0                              ; Off the dropped key (or it was taken): forget it
    sta hero_key_dropped,x              ; ...and look for a key here as usual
; Look for a key at the hero's cell, keys 20 to 1; the first found is picked up.
.check_key_cell
    lda hero_x,x                        ; Is there a key at the hero's cell? Its x...
    sta cell_x                          ; ...in cell_x, for each key's x to match...
    lda hero_y,x                        ; ...and the hero's y...
    sta cell_y                          ; ...in cell_y, for each key's y
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack while X counts the keys
    ldx #max_key                        ; ...keys 20 to 1; entry 0 is never picked up
.check_key
    lda key_x,x                         ; This key's x...
    cmp cell_x                          ; ...at the hero's x?
    bne next_key                        ; No: try the next key
    lda key_y,x                         ; ...and its y...
    cmp cell_y                          ; ...at the hero's y?
    bne next_key                        ; No: try the next key
    lda #spr_blank                      ; Yes: pick it up, erasing it from the floor
    sta sprite_number                   ; ...as the sprite to plot...
    lda #0                              ; ...squarely on the key's cell...
    sta plot_offset_x                   ; ...no shift across (plot_offset_x 0)...
    sta plot_offset_y                   ; ...or down (plot_offset_y 0)
    txa                                 ; Keep the key number...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Blank the key in every view showing it
    pla                                 ; Recover the key number...
    tax                                 ; ...into X: the key being picked up
    pla                                 ; Show the key icon in the hero's panel: hero...
    tay                                 ; ...into Y, to index hero_panel_y...
    pha                                 ; ...and back on the stack for later
    lda #spr_key_icon                   ; ...in the key icon sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda hero_panel_y,y                  ; ...from the hero's panel row...
    sec                                 ; ...set carry to subtract
    sbc #&0d                            ; ...less 13: the key icon's row...
    sta plot_y                          ; ...as plot_y, the icon's screen row
    lda #panel_left + 5                 ; ...in panel column panel_left + 5...
    sta plot_x                          ; ...as plot_x, the icon's column
    tya                                 ; Keep the hero number...
    pha                                 ; ...on the stack...
    txa                                 ; ...and the key number...
    pha                                 ; ...both kept across plot_sprite
    jsr plot_sprite                     ; Plot the key icon
    pla                                 ; Recover the key number...
    tax                                 ; ...into X: the key to carry...
    pla                                 ; ...and the hero number...
    tay                                 ; ...into Y: the hero picking it up
; The swap: the key carried (or unused entry 0) goes on the floor here, the new one is carried and taken off the map, and hero_key_dropped keeps the old one's number, so it is left alone until the hero is off it.
    txa                                 ; Drop the key carried (if any) in this cell...
    pha                                 ; ...keeping the new key's number on the stack...
    ldx hero_key,y                      ; ...the old key, or unseen entry 0 if none...
    lda hero_x,y                        ; ...goes to the hero's x...
    sta key_x,x                         ; ...as its x...
    lda hero_y,y                        ; ...and the hero's y...
    sta key_y,x                         ; ...as its y
    txa                                 ; Remember the key dropped (0 if none)...
    sta hero_key_dropped,y              ; ...so it is not picked straight back up
    pla                                 ; Recover the new key's number...
    tax                                 ; ...into X, and in A to carry
    sta hero_key,y                      ; ...and carry the new one
    lda #off_map                        ; Take the new key off the floor
    sta key_x,x                         ; ...x off the map, so draw_keys skips it...
    sta key_y,x                         ; ...and y off the map
    ldx #<(key_envelope)                ; Sound the pickup: ENVELOPE key_envelope low...
    ldy #>(key_envelope)                ; ...and high: the pickup's envelope block
    lda #osword_envelope                ; OSWORD 8: ENVELOPE
    jsr osword                          ; Define the key pickup envelope  ENVELOPE command
    ldx #<(key_sound)                   ; SOUND key_sound: block address low...
    ldy #>(key_sound)                   ; ...and high: the pickup's sound block
    lda #osword_sound                   ; OSWORD 7: SOUND
    jsr osword                          ; Play the key pickup sound  SOUND command
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for next_hero_keys
    jmp next_hero_keys                  ; One key a frame per hero: next hero
.next_key
    dex                                 ; Next key down, 20 to 1
    beq keys_done                       ; Keys all checked: this hero is done
    jmp check_key                       ; Otherwise check the next key
.keys_done
    pla                                 ; Recover the hero number pushed at check_key_cell...
    tax                                 ; ...into X, to move on from this hero
.next_hero_keys
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four heroes done?
    beq update_rest                     ; Yes: on with the rest of the frame
    jmp check_hero_keys                 ; No: check this hero's keys
; The rest of the frame: objects, missiles, monsters, then the pause key.
.update_rest
    jsr draw_objects                    ; Draw the objects over the floor
    jsr move_missiles                   ; Move the missiles a cell each
    jsr update_monsters                 ; Move the monsters
; The pause key, last in each frame's update: P, read with test_key, which sees it
; whatever other keys are held (OSBYTE &7A, which the 1987 release used, reports only the
; lowest-numbered key held, so a movement key could hide P). Pause until P is pressed
; again, then wait for it to be released, so that a P still held does not pause again.
    lda #inkey_key_p                    ; P held?
    jsr test_key                        ; ...Z set if so
    bne not_paused                      ; No: on with play
.wait_pause_release
    lda #inkey_key_p                    ; Paused: wait for P to be released...
    jsr test_key                        ; ...is it still held?
    beq wait_pause_release              ; Yes: keep waiting
.wait_pause_press
    lda #inkey_key_p                    ; ...then pressed again
    jsr test_key                        ; ...is it held yet?
    bne wait_pause_press                ; No: stay paused
.wait_resume_release
    lda #inkey_key_p                    ; ...and released
    jsr test_key                        ; ...is it still held?
    beq wait_resume_release             ; Yes: keep waiting
    lda #&10                            ; Next frame in 17 vsyncs, not the usual 3...
    sta os_vsync_counter                ; ...about a third of a second before play resumes
.not_paused
    rts                                 ; Return to play_level: this frame's update is done
; ***************************************************************************************
; Play a level until it ends
;
; The game's frame loop: play the current level until it is over. Called once per level
; by new_game's level loop, after the level is drawn, the status panel set up and absent
; heroes removed; when it returns, new_game gives each dead hero their starting
; attributes back, ending the game if all four died.
;
; A frame, in order:
;
; 1. Wait for os_vsync_counter, which the MOS counts down at every vertical sync, to go
;    negative, then set it to 2. Frames start three vsyncs apart (about 17 a second), or
;    at once if a frame's work took longer.
; 2. check_for_victory: on level 25, a hero at the Chalice wins the game, and it never
;    returns.
; 3. update_game: heroes, doors, keys, objects, missiles, monsters and the pause key, in
;    that order (see its banner).
; 4. The level-end test, skipped while a hero is going down the exit (exit_busy). The
;    level is over when every hero is out of play (direction 0) and no dead hero's death
;    animation is still short of frame 8; heroes who went down the exit, or whom nobody
;    plays, count as out of play. shrunk_hero's sprites are then restored and the loop
;    returns.
; 5. check_exit: the first hero found standing on the exit drops their key beside it
;    (drop_key), is taken out of play, erased and moved off the map (hero_x &FF), and the
;    exit itself is moved off the map, its cell kept in exit_saved_x/y, so no other hero
;    can enter it meanwhile. hero_enters_exit then starts the descent and jumps back to
;    the top of the loop.
; 6. While exit_busy is set, redraw_exit draws one step of the descent: the exit sprite
;    on its cell, then the hero on it turned a quarter, through up, right, down and left.
;    On the fifth frame of each turn only the exit is drawn and the hero's sprites shrink
;    by a byte and three rows (shrink_hero_width/height), drawn from then on with
;    exit_offsets_x/y to keep them near the cell's centre. After four turns, 20 frames in
;    all, restore_exit puts the exit back and clears exit_busy, so another hero can use
;    it.
;
; How the level ends: hero_enters_exit is entered with JSR but leaves with a JMP to
; play_level, so each descent leaves a return address (into check_exit at &1F8E) on the
; stack. The RTS at the level's end therefore returns into check_exit once for each hero
; who left by the exit; each such return runs one more full frame before the next RTS,
; and only the last returns to new_game.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; Pace the game: start a frame every three vsyncs.
.play_level
    lda os_vsync_counter                ; Wait for the vertical sync counter to pass zero...
    bpl play_level                      ; Not yet negative: keep waiting
    lda #2                              ; ...and set it for three syncs from now
    sta os_vsync_counter                ; ...in the MOS's vertical sync counter
; This frame's play: the Chalice on level 25, then all but the exit (update_game).
    jsr check_for_victory               ; On level 25: has a hero reached the Chalice?
    jsr update_game                     ; Run a frame: heroes, keys, objects, monsters
; Is the level over? Never while a hero is going down the exit; otherwise when every hero is out of play and no death animation is still running.
    lda exit_busy                       ; A hero going down the exit?
    bne check_exit                      ; Yes: the level goes on
    ldx #4                              ; Is any hero in play, or still dying? Heroes 3 to 0
.count_heroes_in_play
    lda hero_direction - 1,x            ; In play (a direction set)?
    bne check_exit                      ; Yes: the level goes on
    lda hero_health_tens - 1,x          ; Out of play: dead...
    cmp #spr_digit_0 - 1                ; ...(health tens digit below 0)...
    bne next_hero_in_play               ; No: alive but out of play; next hero
    lda hero_frame - 1,x                ; ...with the death animation unfinished?
    cmp #8                              ; ...frame 8 is the last of the death
    bcc check_exit                      ; Yes: the level goes on
.next_hero_in_play
    dex                                 ; Next hero down (X is the hero + 1)
    bne count_heroes_in_play            ; More heroes: check the next
    ldx shrunk_hero                     ; The level is over: restore the last exiting hero's sprites
    bmi play_level_done                 ; None (&FF): nothing to restore
    jsr restore_hero_sprites            ; Give them back their full-size sprites
.play_level_done
    rts                                 ; Return, perhaps into this loop at &1F8E
; Look for a hero on the exit. The first found leaves their key beside it, leaves play and the map, and starts down; the exit is hidden off the map until they have gone.
.check_exit
    ldx #0                              ; Is a hero on the exit? From hero 0
.check_hero_on_exit
    lda hero_x,x                        ; The hero's x...
    cmp exit_x                          ; ...at the exit's x?
    bne next_hero_exit                  ; No: next hero
    lda hero_y,x                        ; ...and the hero's y...
    cmp exit_y                          ; ...at the exit's y?
    bne next_hero_exit                  ; No: next hero
    jsr drop_key                        ; Yes: drop their key beside it
    lda #step_out_of_play               ; Take them out of play for the rest of the level
    sta hero_step,x                     ; ...so they are never animated...
    lda #0                              ; ...and no direction...
    sta hero_direction,x                ; ...so move_heroes skips them
    lda hero_x,x                        ; Erase them from the exit's cell
    sta cell_x                          ; ...is the cell to blank: x...
    lda hero_y,x                        ; ...and the hero's y...
    sta cell_y                          ; ...and y...
    lda #0                              ; ...squarely on the cell...
    sta plot_offset_x                   ; ...no shift across (plot_offset_x 0)...
    sta plot_offset_y                   ; ...or down (plot_offset_y 0)...
    lda #spr_blank                      ; ...with the blank sprite
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Plot the blank in every view showing them
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, to move them off the map
    lda #off_map                        ; Move them off the map
    sta hero_x,x                        ; ...x off the map, so nothing meets them
    lda exit_x                          ; Hide the exit while they go down it, keeping its position
    sta exit_saved_x                    ; ...x in exit_saved_x, for redraw_exit...
    lda exit_y                          ; ...and its y...
    sta exit_saved_y                    ; ...in exit_saved_y, for restore_exit too
    lda #off_map                        ; ...then put the exit off the map...
    sta exit_x                          ; ...x &FF...
    sta exit_y                          ; ...and y &FF, so no other hero can enter it
    jsr hero_enters_exit                ; Start the exit animation (which jumps back to play_level)
    jmp check_exit_busy                 ; Reached by the RTS at the end of the level: one more frame
.next_hero_exit
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four heroes checked?
    bne check_hero_on_exit              ; No: check the next
; The descent, one step a frame while exit_busy is set: redraw the exit, then the hero on it a quarter turn on, at the size and offsets for this turn.
.check_exit_busy
    lda exit_busy                       ; A hero going down the exit?
    bne redraw_exit                     ; Yes: draw this frame of the descent
    jmp play_level                      ; No: next frame
.redraw_exit
    ldx exiting_hero                    ; Redraw the exit under the spinning hero
    lda #0                              ; ...squarely on its cell...
    sta plot_offset_x                   ; ...no shift across (plot_offset_x 0)...
    sta plot_offset_y                   ; ...or down (plot_offset_y 0)...
    lda exit_saved_x                    ; ...at exit_saved_x...
    sta cell_x                          ; ...(exit_x itself is off the map)...
    lda exit_saved_y                    ; ...and exit_saved_y...
    sta cell_y                          ; ...as the cell to plot...
    lda #spr_exit                       ; ...with the exit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    jsr plot_at_cell                    ; Plot it in every view showing it
    ldx exiting_hero                    ; Turn the hero a quarter: up, right, down, left
    clc                                 ; ...clear carry for the add
    lda exit_spin                       ; ...from the current direction...
    adc #2                              ; ...two sprites on: the next direction...
    sta exit_spin                       ; ...kept for the next frame
    cmp #9                              ; Past left (9): a full turn?
    beq next_turn                       ; Yes: shrink the hero, showing just the exit
    clc                                 ; Plot the hero on the exit, centred for its current size
    lda hero_sprites,x                  ; ...the hero's sprite base...
    adc exit_spin                       ; ...plus the direction's frame...
    sta sprite_number                   ; ...as the sprite to plot
    lda exit_saved_x                    ; ...on the exit's cell: its x...
    sta cell_x                          ; ...set again, as plot_at_cell changed cell_x...
    lda exit_saved_y                    ; ...and its y...
    sta cell_y                          ; ...and cell_y
    ldx exit_shrinks_left               ; ...with offsets for its size, by turns left...
    lda exit_offsets_x,x                ; ...byte columns right, from exit_offsets_x...
    sta plot_offset_x                   ; ...as plot_offset_x, centring the narrower sprite...
    lda exit_offsets_y,x                ; ...pixel rows down, from exit_offsets_y...
    sta plot_offset_y                   ; ...as plot_offset_y, centring the shorter one
    jsr plot_at_cell                    ; Plot the hero in every view showing the exit
    jmp play_level                      ; Next frame: the next quarter turn
; A full turn is done. After the fourth the hero has gone; after each of the first three, sprites base + 1 to base + 7 shrink by a byte and three rows.
.next_turn
    lda #&ff                            ; Start the next turn from facing up
    sta exit_spin                       ; ...-1, so the next frame's +2 gives 1
    dec exit_shrinks_left               ; Fourth turn done?
    bne shrink_hero_sprites             ; No: shrink the hero's sprites
    jmp restore_exit                    ; Yes: the hero has gone; bring the exit back
.shrink_hero_sprites
    clc                                 ; Shrink sprites base + 1 to + 7: a byte narrower...
    lda hero_sprites,x                  ; ...the hero's sprite base...
