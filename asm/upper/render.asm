; ***************************************************************************************
; Mark a creature's cells for drawing
;
; Mark the cell at cell_x, cell_y dirty, to be drawn afresh by render, and with it the
; next cell along when plot_offset_x or plot_offset_y places a sprite part way there,
; between cells: the cells a sprite plotted at that cell and offset covers. Play calls it
; where the 1987 release plotted a creature or rubbed one out. cell_x and cell_y are left
; as they were.
;
; On Entry:
;     CELL_X, CELL_Y: map cell
;     PLOT_OFFSET_X, PLOT_OFFSET_Y: the sprite's offsets (signed)
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
.mark_cells
    jsr mark_cell                       ; The cell itself
    lda plot_offset_x                   ; Part way across?
    beq mark_cells_down                 ; No: look down
    bmi mark_cell_left                  ; Leftwards: the cell to the left
    inc cell_x                          ; Rightwards: the cell to the right...
    jsr mark_cell                       ; ...marked...
    dec cell_x                          ; ...and back
    jmp mark_cells_down                 ; Then look down
.mark_cell_left
    dec cell_x                          ; The cell to the left...
    jsr mark_cell                       ; ...marked...
    inc cell_x                          ; ...and back
.mark_cells_down
    lda plot_offset_y                   ; Part way down?
    beq mark_cells_done                 ; No: done
    bmi mark_cell_above                 ; Upwards: the cell above
    inc cell_y                          ; Downwards: the cell below...
    jsr mark_cell                       ; ...marked...
    dec cell_y                          ; ...and back
    rts                                 ; Return
.mark_cell_above
    dec cell_y                          ; The cell above...
    jsr mark_cell                       ; ...marked...
    inc cell_y                          ; ...and back
.mark_cells_done
    rts                                 ; Return
; Find cell_x, cell_y's byte in dirty_cells: carry clear and its index in Y if a view
; shows the cell, the first in the order 3 to 0, whose marks stand for every view showing
; that room; carry set if none does. render_bit is set to the cell's bit. Preserves X.
.find_cell_byte
    jsr cell_room_and_bit               ; Its room, row and column bit
    ldy #6                              ; Views 3 to 0: view_room + 6, 4, 2, 0
.find_cell_view
    lda view_room,y                     ; This view's room...
    cmp render_room                     ; ...the cell's?
    beq found_cell_view                 ; Yes: this view's byte
    dey                                 ; No: the next view down...
    dey                                 ; ...two bytes on in view_room
    bpl find_cell_view                  ; Until view 0
    sec                                 ; None shows it
    rts                                 ; Return
.found_cell_view
    tya                                 ; Its eight bytes start at view x 8 = Y x 4...
    asl a                               ; ...
    asl a                               ; ...
    ora render_row                      ; ...plus the row
    tay                                 ; ...as the index
    clc                                 ; Found
    rts                                 ; Return
; Work out cell_x, cell_y's room offset (render_room), the cell's row in the room
; (render_row) and its column's bit (render_bit). Preserves X.
.cell_room_and_bit
    lda cell_y                          ; Room = (y AND &F8) x 4 + (x AND &F8)...
    and #&f8                            ; ...
    asl a                               ; ...
    asl a                               ; ...
    sta render_room                     ; ...(the two parts share no bits)...
    lda cell_x                          ; ...
    and #&f8                            ; ...
    ora render_room                     ; ...
    sta render_room                     ; ...as view_room holds it
    lda cell_y                          ; The row within the room...
    and #7                              ; ...
    sta render_row                      ; ...
    lda cell_x                          ; The column within the room...
    and #7                              ; ...
    tay                                 ; ...
    lda bit_masks,y                     ; ...as its bit, &80 for column 0
    sta render_bit                      ; ...
    rts                                 ; Return
; ***************************************************************************************
; Load a creature for drawing
;
; Set sprite_number, cell_x, cell_y, plot_offset_x and plot_offset_y for creature X,
; numbered in the order they are drawn, from back to front: 0-3 the heroes, as move_heroes
; last drew them (hero_drawn_*); 4-15 the missiles in flight, slots 0-11; 16-45 the
; monsters, 30 down to 1, as 1987 drew them, each with its facing sprite and walking frame,
; or its death sparkle. Carry set if creature X is not to be drawn: a hero not drawn this
; level or rubbed out, a free missile slot, a monster parked off the map or just killed.
;
; On Entry:
;     X: creature (0-45)
;
; On Exit:
;     C: clear to draw, set if nothing
;     X: preserved
;     Y: corrupted
.load_creature
    lda #0                              ; Square in its cell unless it is stepping
    sta plot_offset_x                   ; ...
    sta plot_offset_y                   ; ...
    cpx #4                              ; A hero?
    bcs load_missile                    ; No: a missile or a monster
    lda hero_drainer,x                  ; On an energy drainer?
    beq load_hero                       ; No: drawn
    lda render_frames                   ; Yes: every other frame (bit 0 of the count)...
    lsr a                               ; ...
    bcs load_nothing                    ; ...left out, so they flicker with it (a warning)
.load_hero
    lda hero_drawn_sprite,x             ; The sprite move_heroes drew, 0 if none...
    beq load_nothing                    ; ...none: nothing to draw
    sta sprite_number                   ; ...as the sprite
    lda hero_drawn_x,x                  ; Where it was drawn...
    sta cell_x                          ; ...
    lda hero_drawn_y,x                  ; ...
    sta cell_y                          ; ...
    lda hero_drawn_offset_x,x           ; ...and with what offsets
    sta plot_offset_x                   ; ...
    lda hero_drawn_offset_y,x           ; ...
    sta plot_offset_y                   ; ...
    clc                                 ; To be drawn
    rts                                 ; Return
.load_missile
    cpx #16                             ; A missile?
    bcs load_monster                    ; No: a monster
    txa                                 ; Its slot: creature - 4...
    sbc #3                              ; ...(carry clear: - 3 - 1)
    tay                                 ; ...in Y
    lda missile_direction,y             ; In flight (a direction, 1-4)?
    beq load_nothing                    ; No: a free slot
    clc                                 ; Its sprite: its weapon's base + direction
    adc missile_sprite_base,y           ; ...
    sta sprite_number                   ; ...
    lda missile_x,y                     ; Its cell...
    sta cell_x                          ; ...
    lda missile_y,y                     ; ...
    sta cell_y                          ; ...
    clc                                 ; To be drawn
    rts                                 ; Return
.load_monster
    stx render_creature                 ; Monster = 46 - creature: 30 for creature 16...
    lda #46                             ; ...
    sec                                 ; ...
    sbc render_creature                 ; ...
    tay                                 ; ...in Y
    lda monster_x,y                     ; Off the map (parked)?
    cmp #off_map                        ; ...
    beq load_nothing                    ; Yes: nothing to draw
    sta cell_x                          ; Its cell...
    lda monster_y,y                     ; ...
    sta cell_y                          ; ...
    lda monster_offset_x,y              ; ...and offsets
    sta plot_offset_x                   ; ...
    lda monster_offset_y,y              ; ...
    sta plot_offset_y                   ; ...
    lda monster_sprite,y                ; Its sprite: dying (the blank, &15, and up)?
    cmp #spr_blank                      ; ...
    beq load_nothing                    ; The blank: just killed, nothing to draw
    bcs load_monster_sprite             ; A sparkle: as it is
    adc monster_frame,y                 ; Alive: plus its walking frame (carry clear)
.load_monster_sprite
    sta sprite_number                   ; ...as the sprite
    clc                                 ; To be drawn
    rts                                 ; Return
.load_nothing
    sec                                 ; Nothing to draw
    rts                                 ; Return
; ***************************************************************************************
; Draw what has changed
;
; Called at the end of every frame of play, after every creature has moved. Play has
; marked the cells where anything changed (mark_cells, mark_cell). First any creature in
; a marked cell has all its cells marked, so nothing outside the marked cells is touched. Then each marked cell is drawn afresh, from the
; back: its floor solid (an object, a trapdoor, or the blank), then see-through a hero
; out of play there (sparkles or skull) and a key. Then every creature on a marked cell is
; drawn see-through over it, heroes, then missiles, then monsters, so that what lies
; under a creature shows round it and later ones are in front. A hero on an energy drainer
; is left out on every other frame (load_creature), so they flicker with it, a warning
; kept from the 1987 release; collect_objects marks their cell every frame they are on it.
; Last, the marks are cleared.
;
; A view that came on show (render_all) has all its cells marked first; the walls among
; them are left as the view drew them.
.render
    lda render_all                      ; A view newly on show?
    beq render_grow                     ; No: just what changed
    lda #&ff                            ; Yes: mark every cell of every view (the walls are
    ldx #31                             ; ...passed over below)
.mark_every_cell
    sta dirty_cells,x                   ; ...
    dex                                 ; ...
    bpl mark_every_cell                 ; ...
; Take in the whole of every creature whose cell is marked. A creature that has changed has
; marked all its cells already (one part way between cells always has: it moves every
; frame), so one that has not stands in one cell, and this marks the rest of nothing new.
.render_grow
    ldx #45                             ; Creatures 45 to 0
.render_grow_creature
    jsr load_creature                   ; Creature X: where?
    bcs render_grow_next                ; Nothing to draw: the next
    jsr cell_marked                     ; Its cell marked?
    beq render_grow_next                ; No: the next
    jsr mark_cells                      ; Yes: mark all of its cells
.render_grow_next
    dex                                 ; The next creature down
    bpl render_grow_creature            ; Until creature 0
; Draw the floor of every marked cell.
    ldx #6                              ; Views 3 to 0, by view_room offset
.render_each_view
    stx render_view                     ; This view...
    lda view_room,x                     ; ...its room
    sta render_room                     ; ...
.render_view_rows
    lda render_view                     ; The view's eight row bytes: view x 8 = offset x 4
    asl a                               ; ...
    asl a                               ; ...
    sta render_row                      ; ...the first row's byte
.render_each_row
    ldy render_row                      ; This row's bits...
    lda dirty_cells,y                   ; ...
    beq render_next_row                 ; None marked: the next row
    ldx #7                              ; Columns 7 to 0
.render_column
    lda bit_masks,x                     ; This column's bit...
    and dirty_cells,y                   ; ...marked?
    beq render_next_column              ; No: the next column
    txa                                 ; Yes: the cell's x: the room's column x 8 + column...
    sta cell_x                          ; ...
    lda render_room                     ; ...(the room offset's bits 3-4)...
    and #&18                            ; ...
    ora cell_x                          ; ...
    sta cell_x                          ; ...
    lda render_room                     ; ...and its y: the room's row x 8 (bits 5-7 / 4)...
    lsr a                               ; ...
    lsr a                               ; ...
    and #&38                            ; ...
    sta cell_y                          ; ...
    tya                                 ; ...+ the row within the room
    and #7                              ; ...
    ora cell_y                          ; ...
    sta cell_y                          ; ...
    txa                                 ; Keep the column...
    pha                                 ; ...
    jsr test_wall                       ; A wall (all marked when a view comes on show)?
    bne render_wall_cell                ; Yes: drawn with the view; leave it
    jsr draw_floor_cell                 ; No: draw the cell's floor
.render_wall_cell
    pla                                 ; Recover the column...
    tax                                 ; ...
    ldy render_row                      ; ...and the row's byte
.render_next_column
    dex                                 ; The next column
    bpl render_column                   ; Until column 0
.render_next_row
    inc render_row                      ; The next row...
    lda render_row                      ; ...still in this view's eight?
    and #7                              ; ...
    bne render_each_row                   ; Yes: draw it
.render_next_view
    ldx render_view                     ; The next view down
    dex                                 ; ...
    dex                                 ; ...
    bpl render_each_view                  ; Until view 0
; Draw every creature on a marked cell, back to front, see-through.
    ldx #0                              ; Creatures 0 to 45
.render_each_creature
    jsr load_creature                   ; Creature X: where?
    bcs render_next_creature            ; Nothing to draw
    jsr cell_marked                     ; Its cell marked (and so all of them)?
    beq render_next_creature            ; No: it is on show already, or not at all
    stx render_creature                 ; Keep the creature...
    lda #&80                            ; ...and draw it see-through
    sta plot_mode                       ; ...
    jsr plot_at_cell                    ; ...in every view showing it
    lda #0                              ; Solid again
    sta plot_mode                       ; ...
    ldx render_creature                 ; Recover the creature
.render_next_creature
    inx                                 ; The next creature
    cpx #46                             ; All 46 done?
    bne render_each_creature              ; No: the next
; Clear the marks, ready for the next frame.
    inc render_frames                   ; One more frame drawn
    lda #0                              ; Clear every mark...
    sta render_all                      ; ...and the call for everything
    ldx #31                             ; ...32 bytes
.clear_dirty_cells
    sta dirty_cells,x                   ; ...
    dex                                 ; ...
    bpl clear_dirty_cells               ; ...
    rts                                 ; Return with the screen up to date
; ***************************************************************************************
; The render pass's data
;
; dirty_cells: the marks, eight bytes for each view (view_room order), one for each row of
; its room, bit &80 for column 0. hero_drawn_*: each hero as move_heroes last drew them:
; sprite (0 for none), cell and offsets. hero_drainer: the energy drainer under each hero,
; its sprite, or 0. render_frames counts frames drawn; render_all is non-zero when a view
; has come on show.
.dirty_cells
    skip 32
.hero_drawn_sprite
    skip 4
.hero_drawn_x
    skip 4
.hero_drawn_y
    skip 4
.hero_drawn_offset_x
    skip 4
.hero_drawn_offset_y
    skip 4
.hero_drainer
    skip 4
.render_frames
    skip 1
; A monster as note_monster found it: sprite, cell x and y, offsets x and y.
.monster_before
    skip 5
.render_all
    skip 1
