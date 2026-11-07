; ***************************************************************************************
; Test for a wall at a map cell
;
; Say whether a map cell is solid: a wall, or a door not yet opened. Heroes
; (move_heroes), missiles (move_missiles) and monsters (update_monsters) test here the
; cell they are about to enter, and find_open_neighbour the cells next to the exit where
; drop_key can put a key down. check_magic and show_hero_room call it only for the room
; pointer it leaves in map_ptr.
;
; The wall map. room_walls (&0C00) holds eight bytes per room, one per row of cells from
; the top, and one bit per cell, bit 7 for the leftmost (x AND 7 = 0) to bit 0 for the
; rightmost; a set bit is solid. Rooms are stored in rows of four, left to right, so a
; room's eight bytes start at (y AND &F8) x 4 + (x AND &F8) (see plot_at_cell for the
; coordinates), and the cell is bit bit_masks[x AND 7] of byte y AND 7 there.
; object_free_map at &2100 has the same layout (test_object_free). The level file
; supplies both; opening a door clears its bit.
;
; The bit is returned in A and Y, with Z set for an open cell; callers that have pulled X
; from the stack test Y. map_ptr is left pointing at the room's bytes, its low byte being
; the room offset that view_room uses. Coordinates off the map are not checked: off_map
; (&FF, &FF) reads a byte beyond the wall map. The bit is also stored in &8F
; (victory_pitch), which the victory sequence sets before it reads it, so the copy is
; never used.
;
; On Entry:
;     CELL_X: map x
;     CELL_Y: map y
;
; On Exit:
;     A: wall bit
;     Y: wall bit
;     Z: set if no wall
;     X: corrupted (the column within the room)
;     MAP_PTR: the cell's room in room_walls
; Point map_ptr at the cell's room in room_walls.
.test_wall
    lda cell_y                          ; Room offset = (cell_y AND &F8) x 4 + (cell_x AND &F8)...
    and #&f8                            ; ...y AND &F8 = 8 x the cell's row of rooms...
    sta scratch                         ; ...kept in scratch, to add up four times...
    clc                                 ; ...(y < 64 on the map: no carry, so clear it once)
    adc scratch                         ; ...doubled: 16 bytes per row of rooms so far...
    adc scratch                         ; ...tripled: 24...
    adc scratch                         ; ...x 4: 32 bytes, four rooms, per row of rooms
    sta map_ptr                         ; ...the start of its row of rooms, in map_ptr
    lda cell_x                          ; Add the room's column in that row...
    and #&f8                            ; ...x AND &F8 = 8 x the column: 8 bytes per room
    adc map_ptr                         ; ...to the row's offset...
    sta map_ptr                         ; ...map_ptr low = the room's offset (0-&B8)...
    lda #>(room_walls)                  ; ...in page &0C, room_walls...
    sta map_ptr_hi                      ; ...as map_ptr's high byte: map_ptr = the room's bytes
; Pick out the cell's bit: bit_masks for the column, the room's byte for the row.
    lda cell_x                          ; Mask for the cell's column within the room...
    and #7                              ; ...x AND 7, 0 at the left...
    tax                                 ; ...in X, to look up its bit...
    lda bit_masks,x                     ; ...&80 for column 0 down to &01 for column 7
    sta scratch                         ; ...kept in scratch to test the row byte with
    lda cell_y                          ; The row byte: y AND 7...
    and #7                              ; ...the cell's row within the room, 0-7...
    tay                                 ; ...in Y, indexing the room's eight bytes
    lda (map_ptr),y                     ; The row's walls, one bit per cell...
    and scratch                         ; ...masked to this cell: non-zero if solid
    sta victory_pitch                   ; ...copied to &8F, which is never read for it...
    tay                                 ; ...and to Y: callers pull X, then test Y
    rts                                 ; Return with Z set if the cell is open
; ***************************************************************************************
; Test whether a map cell can hold an object
;
; Say whether an object might lie in a map cell, so that the object list need be searched
; only there. move_heroes calls it for a hero who has moved, before collect_objects, and
; move_missiles for a missile's new cell, before looking for an energy drainer.
;
; The same calculation as test_wall, on object_free_map at &2100 instead of room_walls:
; eight bytes per room, a bit per cell, bit 7 at the left. A clear bit means an object
; may lie there; the map comes from the level file and is not changed when an object is
; collected, so a cleared cell goes on costing a search that finds nothing. The bit is
; returned in A and Y, with Z set if an object may lie there, and also stored in &8F
; (victory_pitch), where nothing reads it. map_ptr is left pointing into object_free_map.
;
; On Entry:
;     CELL_X: map x
;     CELL_Y: map y
;
; On Exit:
;     A: map bit
;     Y: map bit
;     Z: set if an object may lie there
;     X: corrupted (the column within the room)
; Point map_ptr at the cell's room in object_free_map.
.test_object_free
    lda cell_y                          ; Room offset = (cell_y AND &F8) x 4 + (cell_x AND &F8)...
    and #&f8                            ; ...y AND &F8 = 8 x the cell's row of rooms...
    sta scratch                         ; ...kept in scratch, to add up four times...
    clc                                 ; ...(y < 64 on the map: no carry, so clear it once)
    adc scratch                         ; ...doubled: 16 bytes per row of rooms so far...
    adc scratch                         ; ...tripled: 24...
    adc scratch                         ; ...x 4: 32 bytes, laid out as room_walls
    sta map_ptr                         ; ...the start of its row of rooms, in map_ptr
    lda cell_x                          ; Add the room's column in that row...
    and #&f8                            ; ...x AND &F8 = 8 x the column: 8 bytes per room
    adc map_ptr                         ; ...to the row's offset...
    sta map_ptr                         ; ...map_ptr low = the room's offset (0-&B8)...
    lda #>(object_free_map)             ; ...in page &21, object_free_map...
    sta map_ptr_hi                      ; ...as map_ptr's high byte: map_ptr = the room's bytes
; Pick out the cell's bit, as test_wall does.
    lda cell_x                          ; Mask for the cell's column within the room...
    and #7                              ; ...x AND 7, 0 at the left...
    tax                                 ; ...in X, to look up its bit...
    lda bit_masks,x                     ; ...&80 for column 0 down to &01 for column 7
    sta scratch                         ; ...kept in scratch to test the row byte with
    lda cell_y                          ; The row byte: y AND 7...
    and #7                              ; ...the cell's row within the room, 0-7...
    tay                                 ; ...in Y, indexing the room's eight bytes
    lda (map_ptr),y                     ; The row's bits, one per cell...
    and scratch                         ; ...masked to this cell: zero if an object may lie
    sta victory_pitch                   ; ...copied to &8F, which is never read for it...
    tay                                 ; ...and to Y: callers pull X, then test Y
    rts                                 ; Return with Z set if an object may lie here
; ***************************************************************************************
; Look for a monster or hero at a cell
;
; Say whether a creature stands in a map cell, and if a monster has walked into a hero,
; hurt the hero. Called by move_heroes and move_missiles for the cell a hero or missile
; is entering, and by update_monsters for the cell a monster steps into and for the
; trapdoor a dead monster comes back at (monster_reappears).
;
; Monsters 30 to 1 are compared first, skipping monster number scratch; the first whose
; cell matches is returned. If none matches and scratch is non-zero (a monster is
; asking), heroes 0 to 3 are compared too, and the first one found loses
; hero_damage_taken points of health, one at a time through lose_health_point. A hero or
; missile passes scratch = 0, so only monsters are looked for (they test heroes their own
; way); a monster passes its own number, so it skips itself and is blocked by, and hurts,
; a hero in its way, every frame it tries.
;
; Neither search looks at state: a dying monster still fills its cell, and a hero out of
; play (a skull) blocks a monster too, though lose_health_point takes nothing from them.
; A found monster is reported with A = Y = cell_y, so one in map row 0 would read as
; nothing found. monster_reappears calls this without loading the trapdoor's cell, so it
; tests the view position plot_at_cell left in cell_x, cell_y; a hero who happens to
; stand at that cell is hurt.
;
; On Entry:
;     SCRATCH: the monster moving (1-30), or 0
;     CELL_X: map x
;     CELL_Y: map y
;
; On Exit:
;     A: cell_y if a monster was found, 1 if a hero, else 0
;     Y: cell_y if a monster was found, else 0
;     Z: clear if a creature was found (cell_y non-zero)
;     X: the monster or hero found; else 0, or 4 after the hero search
; Monsters first: any but the asker, alive or dying, in the cell?
.find_creature
    ldx #max_monster                    ; Monsters 30 to 1, alive or dying...
.check_monster
    cpx scratch                         ; ...except monster number scratch, the one asking
    beq next_monster_find               ; The asker itself: skip it
    lda cell_x                          ; Is this monster in the cell? cell_x...
    cmp monster_x,x                     ; ...against the monster's x
    bne next_monster_find               ; Another column: not this monster
    lda cell_y                          ; ...and cell_y...
    cmp monster_y,x                     ; ...against the monster's y
    bne next_monster_find               ; Another row: not this monster
    tay                                 ; Found: A = Y = cell_y, X = the monster
    rts                                 ; Return, Z clear unless the cell is in row 0
.next_monster_find
    dex                                 ; Next monster down
    bne check_monster                   ; Until monster 1 is done
; Then, only for a monster asking, heroes: the first in the cell, in play or not, is hurt and blocks the move.
    lda scratch                         ; No monster there. Is a monster asking (scratch > 0)?
    beq nothing_found                   ; No (a hero or missile): heroes are not looked for
    ldx #0                              ; Yes: a hero blocks it too. Heroes 0 to 3...
.check_hero
    lda cell_x                          ; ...is this hero in the cell? cell_x...
    cmp hero_x,x                        ; ...against the hero's x
    bne next_hero_find                  ; Another column: not this hero
    lda cell_y                          ; ...and cell_y...
    cmp hero_y,x                        ; ...against the hero's y
    bne next_hero_find                  ; Another row: not this hero
    ldy hero_damage_taken,x             ; Found, in play or not: health a blow costs them
.take_hero_damage
    tya                                 ; Take it a point at a time: keep the points left...
    pha                                 ; ...on the stack across lose_health_point
    jsr lose_health_point               ; One point off the hero (none if out of play)
    pla                                 ; Recover the points still to take...
    tay                                 ; ...back in Y
    dey                                 ; One point fewer to take
    bne take_hero_damage                ; Until the hero has taken them all
    lda #1                              ; Return A = 1, Z clear (Y = 0): a hero was there
    rts                                 ; ...so the monster is blocked (or parked)
.next_hero_find
    inx                                 ; Next hero up
    cpx #4                              ; All four heroes checked?
    bne check_hero                      ; No: check the next
.nothing_found
    lda #0                              ; Nothing there: return A = Y = 0...
    ldy #0                              ; ...the cell is free of creatures
    rts                                 ; Return with Z set: nothing in the cell
