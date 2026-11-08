; ***************************************************************************************
; Draw the level's objects
;
; Draw every object still on the level (treasure, food, teleporters, drainers, magic
; items, the exit) in whichever views show it. update_game calls this every frame, after
; move_heroes and the door and key checks and before move_missiles and update_monsters,
; so an object that a hero has just walked off or a monster has crossed is put back
; before the next sprites are drawn over it.
;
; Objects 30 (the exit) down to 1 are plotted with plot_at_cell, their type being their
; sprite, squarely in their cells (no pixel offset). Object 0 is not drawn. A collected
; or worn-away object has map x and y &FF (off_map), which plot_at_cell works out to a
; room offset (&DB) that no view shows, so it is not drawn.
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: corrupted
.draw_objects
    lda #0                              ; No pixel offsets
    sta plot_offset_x                   ; ...across the cell horizontally...
    sta plot_offset_y                   ; ...and vertically: objects sit squarely in their cells
    ldx #max_object                     ; Objects 30 to 1: plot each at its cell
.draw_each_object
    lda object_x,x                      ; This object's map x...
    sta cell_x                          ; ...is the cell to plot at...
    lda object_y,x                      ; ...and its map y...
    sta cell_y                          ; ...the cell's row
    lda object_type,x                   ; Its type, which is also its sprite...
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the object number...
    pha                                 ; ...across the plot
    jsr plot_at_cell                    ; Plot it in every view showing its cell
    pla                                 ; Recover the object number...
    tax                                 ; ...into X, to count down
    dex                                 ; Next object down
    bne draw_each_object                ; Until object 1 is drawn (object 0 is not drawn)
    rts                                 ; Return to update_game, X = 0
; ***************************************************************************************
; Pick up the object in a hero's cell
;
; Give hero X whatever lies in the cell they have just stepped into: pick up treasure,
; food, the Cross or a magic item, ride a teleporter, or suffer an energy drainer.
; move_heroes calls this every frame for each hero in play, after drawing them
; (draw_moved_hero), whether they moved, stood still or fired, and only when
; object_free_map says the hero's cell can hold an object. A pickup is removed at once,
; so it acts once; a drainer stays and acts on every frame the hero's cell is its cell:
; the frame of arrival, each frame standing on it, and the half-step frame of leaving it
; (the hero's cell changes only on arrival), so walking across one within a room costs at
; least 20 health.
;
; Objects 30 down to 1 are compared with the hero's cell and the first match is acted on.
; Finding any object at all takes off the hero's Boots of Speed and erases the bolt from
; the panel, before the type is looked at, so the boots are lost to a teleporter, a
; drainer or the exit as well as to a pickup. Then, by type (object_type, which is also
; the sprite):
;
; &28 treasure: 20 points and the treasure sound; removed.
;
; &29 food: 10 health (to at most 99), 5 points and the food sound; removed.
;
; &2B teleporter: the hero is moved to the cell above the previous teleporter in the
; object list, searching back and wrapping from object 0 to 29, so each leads to the one
; before it and the first to the last; the cell is not tested for walls or creatures, and
; a lone teleporter leads to itself. The teleport sound plays and show_hero_room redraws
; the view. The teleporter stays.
;
; &2A Cross of Resurrection: the first hero in returning_hero_queue starts to materialise
; where they fell, and the Cross scores 10 points, plays the pickup sound and is removed.
; With nobody waiting it stays where it is (the 1987 code took it anyway, wasted).
;
; &51 the exit: passed over (update_game's check_hero_on_exit deals with it) and the
; search goes on.
;
; &5F and up, magic items: removed, the pickup sound and 10 points, then &5F Boots of
; Speed (bolt icon, a whole cell per step), &60 helmet (one less health lost per monster
; blow, to at least 3, and the armour rating redrawn), &61 potion (health set to the
; score's units digit twice over, e.g. 77, and 11 for a 0, where the 1987 code gave 00), &62 pile of weapons (one more missile in
; flight, to at most 3, and its icon) and anything else, &63, the magic sword (one more
; missile damage, to at most 9, redrawn).
;
; Anything else (&53-&5E, an energy drainer at one of its stages): hit_sound at pitch &32
; and 10 health lost, one point at a time, which can kill. The drainer stays.
;
; Treasure, food, the Cross and magic items are removed by setting their map x and y to
; &FF (off_map), so they are neither drawn nor found again.
;
; On Entry:
;     X: hero number (0-3)
.collect_objects
    lda hero_x,x                        ; The hero's cell: map x...
    sta cell_x                          ; ...as the cell to search
    lda hero_y,x                        ; ...and map y...
    sta cell_y                          ; ...as cell_y, for the comparisons
    ldy #max_object                     ; Search from object 30, the exit, down to 1
.check_object
    lda object_x,y                      ; Object Y's map x...
    cmp cell_x                          ; ...the hero's column?
    beq check_object_y                  ; Yes: compare the row
    jmp next_object                     ; No: try the next object
.check_object_y
    lda object_y,y                      ; Object Y's map y...
    cmp cell_y                          ; ...the hero's row?
    beq object_found                    ; Yes: the hero is on object Y
    jmp next_object                     ; No: try the next object
; Object Y is in the hero's cell. Whatever it is, the hero loses the Boots of Speed and their bolt icon first.
.object_found
    tya                                 ; Found: any object at all costs the Boots of Speed
    pha                                 ; Keep the object number...
    lda #0                              ; ...take the boots off...
    sta hero_has_boots,x                ; ...this hero: back to normal speed
    jsr point_at_boots_icon             ; Point at the hero's bolt in the panel...
    jsr erase_boots_icon                ; ...and erase it
    pla                                 ; Recover the object number...
    tay                                 ; ...into Y, to read its type
    lda object_type,y                   ; The object's type, which is its sprite
    cmp #spr_treasure                   ; Treasure (20 points)?
    bne check_food                      ; No: try food
; Treasure: define envelope 3 and play the treasure sound with it, score 20 and remove it.
    txa                                 ; Treasure: its sound, keeping hero and object
    pha                                 ; Keep the hero...
    tya                                 ; ...and the object...
    pha                                 ; ...across the OSWORD calls
    ldx #<(treasure_envelope)           ; XY = treasure_envelope, defining envelope 3...
    ldy #>(treasure_envelope)           ; ...the block in page &19...
    lda #osword_envelope                ; ...OSWORD 8, ENVELOPE
    jsr osword                          ; Define the treasure envelope:  ENVELOPE command
    ldx #<(treasure_sound)              ; ...then XY = treasure_sound, with envelope 3...
    ldy #>(treasure_sound)              ; ...the next block in page &19...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; Play the treasure sound:  SOUND command
    pla                                 ; Recover the object...
    tay                                 ; ...into Y, to be removed...
    pla                                 ; ...and the hero...
    tax                                 ; ...into X, to be scored
    tya                                 ; Treasure is worth 20 points:
    pha                                 ; ...keeping the object number
    jsr add_ten_points                  ; Ten points, the score redrawn...
    jsr add_ten_points                  ; ...and ten more
    pla                                 ; Recover the object number...
    tay                                 ; ...into Y, for remove_object
    jmp remove_object                   ; Take the treasure off the level
.check_food
    cmp #spr_food                       ; Food (10 health, 5 points)?
    bne check_teleporter                ; No: try a teleporter
; Food: add 10 health (to at most 99), redraw it, score 5, play the food sound and remove it.
    inc hero_health_tens,x              ; Food: +10 health, one on the tens digit...
    lda hero_health_tens,x              ; ...and look at the new tens digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne redraw_health                   ; No: health is up by 10
    lda #spr_digit_9                    ; Yes: health is capped at 99...
    sta hero_health_tens,x              ; ...tens digit 9...
    sta hero_health_units,x             ; ...units digit 9, whatever it was
.redraw_health
    tya                                 ; Show the new health and score 5 points:
    pha                                 ; Keep the object number
    jsr draw_health                     ; Redraw the health in the panel
    ldy #5                              ; Food is worth 5 points
.add_food_points
    tya                                 ; Keep the count of points to add...
    pha                                 ; ...on the stack across add_point and its plots
    jsr add_point                       ; One point, the score redrawn
    pla                                 ; Recover the count...
    tay                                 ; ...into Y, to count down
    dey                                 ; One fewer to add
    bne add_food_points                 ; Until all five are added
    txa                                 ; The food sound, keeping the hero
    pha                                 ; Keep the hero across the OSWORD call
    ldx #<(food_sound)                  ; XY = food_sound...
    ldy #>(food_sound)                  ; ...the block in page &0B...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; Play the food sound:  SOUND command
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as move_heroes had it
    pla                                 ; Recover the object number...
    tay                                 ; ...into Y, for remove_object
    jmp remove_object                   ; Take the food off the level
.check_teleporter
    cmp #spr_teleporter                 ; Teleporter (moves the hero)?
    bne check_cross                     ; No: try the Cross
; Teleporter: find its partner, the nearest teleporter before it in the object list, wrapping round to 29 after object 0 (whose type, never set by unpack_level, is 0 and never matches). A lone teleporter finds itself.
.find_previous_teleporter
    dey                                 ; Teleporter: search back from it for the previous...
    lda object_type,y                   ; ...object's type...
    cmp #spr_teleporter                 ; ...a teleporter too?
    beq teleport                        ; Yes: it is the destination
    cpy #0                              ; Searched down to object 0?
    bne find_previous_teleporter        ; No: keep looking backwards
    ldy teleport_last                   ; Yes: wrap round to 30, so the search goes on at 29
    jmp find_previous_teleporter        ; ...(the one found may be this teleporter itself)
; Y is the destination teleporter. The hero arrives standing on the cell above it, whatever is there, and their view is moved to that cell's room.
.teleport
    txa                                 ; The teleport sound, keeping hero and destination
    pha                                 ; Keep the hero...
    tya                                 ; ...and the destination teleporter...
    pha                                 ; ...across the OSWORD call
    ldx #<(teleport_sound)              ; XY = teleport_sound...
    ldy #>(teleport_sound)              ; ...the block in page &0B...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; Play the teleport sound:  SOUND command
    pla                                 ; Recover the destination...
    tay                                 ; ...into Y, to read its cell...
    pla                                 ; ...and the hero...
    tax                                 ; ...into X, the hero to move
    lda object_x,y                      ; Move the hero to the cell above the destination...
    sta hero_x,x                        ; ...the destination's column...
    sta cell_x                          ; ...and cell_x (show_hero_room sets it again)
    lda object_y,y                      ; ...and its row...
    sec                                 ; ...less one: the row above it...
    sbc #1                              ; ...so the hero does not stand on it and teleport back
    sta hero_y,x                        ; ...as the hero's row (wall or not: it is not tested)
    sta cell_y                          ; ...and cell_y, likewise
    lda #0                              ; Arrive standing still:
    sta hero_step,x                     ; ...not part way through a step
    sta hero_offset_x,x                 ; ...and no pixel offsets...
    sta hero_offset_y,x                 ; ...in either direction
    jmp show_hero_room                  ; Point the hero's view at the room arrived in
.check_cross
    cmp #spr_cross                      ; Cross of Resurrection?
    bne check_magic_item                ; No: try the exit, drainers and magic items
; Cross of Resurrection: look in returning_hero_queue for a hero waiting to return. With nobody waiting the Cross stays where it is, for later; the 1987 code took it and scored 10 even then, so it was wasted. With a hero waiting, they start to come back, and the Cross is removed, scores 10 and plays the pickup sound.
    txa                                 ; Cross: keep the hero...
    pha                                 ; ...on the stack...
    tya                                 ; ...and the object...
    pha                                 ; ...across the queue
; Bring back the first hero waiting in returning_hero_queue. Each pass takes the front entry and shifts the four entries up one; &64 markers, which stand for heroes left out on the menu, are put back at the end and the next entry taken. A hero found is started materialising (the death animation run backwards, by animate_absent_hero) in the cell where they fell.
.take_returning_hero
    ldy #0                              ; Take the first entry off the queue, appending 0...
.shift_returning_queue
    ldx returning_hero_queue            ; First entry: a hero number + 1, the &64 marker or 0...
    dex                                 ; ...minus 1: the hero, &63 for the marker, &FF for none
    lda returning_hero_queue + 1        ; Shift the queue up one: the second entry...
    sta returning_hero_queue            ; ...becomes the first...
    lda returning_hero_queue + 2        ; ...the third entry...
    sta returning_hero_queue + 1        ; ...becomes the second...
    lda returning_hero_queue + 3        ; ...the fourth entry...
    sta returning_hero_queue + 2        ; ...becomes the third...
    sty returning_hero_queue + 3        ; ...and Y fills the last (0, or the marker sent back)
    cpx #nobody_returns - 1             ; A &64 marker (a hero absent from the menu)?
    bne check_queue_empty               ; No: a hero, or nobody
    ldy #nobody_returns                 ; Yes: send it to the back and take the next entry
    bne shift_returning_queue           ; ...(always taken: Y is &64)
.check_queue_empty
    cpx #&ff                            ; &FF: the front entry was 0, nobody left waiting?
    beq cross_unused                    ; Yes: nobody returns, and the Cross stays
    lda #0                              ; Start hero X materialising: out of play...
    sta hero_direction,x                ; ...direction 0: not in play while the sprites run
    lda #8                              ; ...from the skull back...
    sta hero_frame,x                    ; ...frame 8, the last of hero_appearance_sprites
    lda #&ff                            ; ...stepping backwards through the sprites...
    sta hero_offset_x,x                 ; ...frame step -1
    lda #1                              ; ...the first step next frame
    sta hero_offset_y,x                 ; ...the frame counter
; A hero is coming back: the Cross is used up.
    pla                                 ; Recover the Cross's object number...
    tay                                 ; ...into Y
    lda #off_map                        ; Take the Cross off the level...
    sta object_x,y                      ; ...off the map in x...
    sta object_y,y                      ; ...and y, so it is neither drawn nor found again
    pla                                 ; Recover the hero who picked it up...
    tax                                 ; ...into X
    jsr add_ten_points                  ; The Cross is worth 10 points
    txa                                 ; Keep the hero...
    pha                                 ; ...across the sound
    jsr play_pickup_sound               ; Play the pickup sound
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, for move_heroes
    rts                                 ; Return to move_heroes
; Nobody to bring back: the Cross stays where it lies.
.cross_unused
    pla                                 ; Drop the object number...
    pla                                 ; ...and recover the hero who found the Cross...
    tax                                 ; ...into X, for move_heroes
    rts                                 ; Return to move_heroes
; Shared tail for treasure and food: take object Y off the map.
.remove_object
    lda #off_map                        ; Take object Y off the level:
    sta object_x,y                      ; ...off the map in x...
    sta object_y,y                      ; ...and y, so it is neither drawn nor found again
    rts                                 ; Return to move_heroes: the object is gone
; The object is not in the hero's cell, or is the exit: try the next one down.
.next_object
    dey                                 ; Next object down
    beq collect_objects_done            ; Past object 1: nothing in the cell
    jmp check_object                    ; Check this object
.collect_objects_done
    rts                                 ; Return: nothing to act on in the hero's cell
; Not treasure, food, a teleporter or the Cross: the exit, an energy drainer or a magic item, told apart by type ranges alone.
.check_magic_item
    cmp #spr_boots                      ; Type &5F or above: a magic item?
    bcs magic_item                      ; Yes: collect the magic item
    cmp #spr_exit                       ; The exit? The main loop deals with it...
    beq next_object                     ; ...so search on for another object in the cell
; An energy drainer (&53-&5E): sound it by playing hit_sound with its pitch changed to &32 for the call, then take 10 health one point at a time. The drainer stays, and acts again on every frame the hero's cell is its cell.
    lda #&32 ; '2'                      ; Any other type is an energy drainer: pitch &32...
    sta hit_sound + 4                   ; ...instead of 6 in hit_sound, the drainer's noise
    txa                                 ; Keep the hero...
    pha                                 ; ...across the OSWORD call
    ldx #<(hit_sound)                   ; XY = hit_sound, now at the drainer's pitch...
    ldy #>(hit_sound)                   ; ...the block in page &0C...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; The drainer's noise:  SOUND command
    lda #6                              ; ...then pitch 6 again...
    sta hit_sound + 4                   ; ...for monster_hit's blow
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, for lose_health_point
    ldy #&0a                            ; The drainer takes 10 health and stays
.take_ten_health
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack: lose_health_point corrupts Y
    jsr lose_health_point               ; One point of the hero's health
    pla                                 ; Recover the count...
    tay                                 ; ...into Y, to count down
    dey                                 ; One fewer to take
    bne take_ten_health                 ; Until all ten are taken
    rts                                 ; Return: the drainer stays, to act again next frame
; ***************************************************************************************
; Play the pickup sound
;
; Play the sound of a Cross or magic item being picked up. collect_objects calls it for
; both. Envelope 3 is defined as the pickup envelope and the pickup sound played with it
; on the noise channel, from the OSWORD parameter blocks pickup_envelope and
; pickup_sound. Envelope 3 is shared with the treasure, key and exit sounds, which define
; their own, so it is defined again each time.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.play_pickup_sound
    ldx #<(pickup_envelope)             ; XY = pickup_envelope, defining envelope 3...
    ldy #>(pickup_envelope)             ; ...the block in page &19...
    lda #osword_envelope                ; ...OSWORD 8, ENVELOPE
    jsr osword                          ; Define it:  ENVELOPE command
    ldx #<(pickup_sound)                ; ...then XY = pickup_sound, with envelope 3...
    ldy #>(pickup_sound)                ; ...the next block in page &19...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; Play it:  SOUND command
    rts                                 ; Return, A, X and Y corrupted by the OSWORDs
; A magic item, type &5F or above: removed, the pickup sound, and 10 points for every kind. The type then picks boots, helmet, potion or weapons, and any other type counts as a magic sword.
.magic_item
    sta scratch                         ; A magic item: keep its type for the tests below
    lda #off_map                        ; Take it off the level...
    sta object_x,y                      ; ...off the map in x...
    sta object_y,y                      ; ...and y, so it is neither drawn nor found again
    txa                                 ; The pickup sound, keeping the hero
    pha                                 ; Keep the hero across the sound
    lda scratch                         ; A = (type AND 7) x 4: unused, as play_pickup_sound...
    and #7                              ; ...sets its own registers...
    asl a                               ; ...x 2...
    asl a                               ; ...x 4, then lost to the OSWORD calls
    jsr play_pickup_sound               ; Play the pickup sound
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, to be scored
    lda hero_score_units,x              ; The score's units digit sprite...
    sta scratch2                        ; ...kept for a potion (add_ten_points leaves it)
    jsr add_ten_points                  ; Every magic item is worth 10 points
    lda scratch                         ; The item's type...
    cmp #spr_boots                      ; ...Boots of Speed?
    bne check_helmet                    ; No: try the helmet
; Boots of Speed: show the bolt and let the hero step a whole cell a frame, until they next find an object.
    jsr point_at_boots_icon             ; Boots: point at the hero's bolt in the panel...
    jsr plot_boots_icon                 ; ...and show it
    lda #1                              ; ...and wear them...
    sta hero_has_boots,x                ; ...so the hero moves a whole cell per step
    rts                                 ; Return to move_heroes, the boots on
.check_helmet
    cmp #spr_helmet                     ; Magic helmet (better armour)?
    bne check_potion                    ; No: try the potion
; Magic helmet: lower hero_damage_taken, the health a monster's blow takes, by one to at least 3, and redraw the armour rating (10 - hero_damage_taken, so at most 7).
    dec hero_damage_taken,x             ; Helmet: one less health lost per hit...
    lda hero_damage_taken,x             ; ...and look at it
    cmp #3                              ; ...below 3 (armour 7, the best)?
    bcs redraw_armour                   ; No: keep it
    inc hero_damage_taken,x             ; Yes: back to 3
.redraw_armour
    jmp draw_armour_rating              ; Redraw the armour rating on the shield
.check_potion
    cmp #spr_potion                     ; Potion of healing?
    bne check_weapons                   ; No: try the weapons
; Potion of healing: health is set from the score's units digit d, read before the 10 points were added, as dd, from 11 to 99. A 0 counts as 1: the 1987 code gave health 00, a point from death.
    ldy scratch2                        ; Potion: the score's last digit, as a sprite...
    cpy #spr_digit_0                    ; ...a 0?
    bne potion_health                   ; No: health is that digit twice
    iny                                 ; Yes: a 1 instead, so health 11, not 00
.potion_health
    tya                                 ; The digit...
    sta hero_health_tens,x              ; ...as the health's tens...
    sta hero_health_units,x             ; ...and its units
    jmp draw_health                     ; Draw the new health; back to move_heroes
.check_weapons
    cmp #spr_weapons                    ; Pile of weapons?
    bne magic_sword                     ; No: anything else is taken as a magic sword
; Pile of weapons: one more missile allowed in flight, to at most 3 (the hero's three missile slots), and its icon added.
    inc hero_max_missiles,x             ; Weapons: one more missile in flight at once...
    lda hero_max_missiles,x             ; ...and look at it
    cmp #4                              ; ...past 3, the hero's missile slots?
    bne draw_missile_icon               ; No: add its icon to the panel
    lda #3                              ; Yes: back to 3...
    sta hero_max_missiles,x             ; ...as the missiles allowed
.draw_missile_icon
    jmp draw_new_missile_icon           ; Draw the newest missile icon
