; ***************************************************************************************
; Draw all four views
;
; Draw the walls and doors of the room in each hero's view: the Ranger's top left, the
; Magic-User's top right, the Barbarian's bottom left and the Fighter's bottom right.
; draw_view_frames calls it once as each level starts, after drawing the frames round the
; views, when every view_room entry holds the heroes' starting room. A view is drawn even
; for a hero nobody plays. Since each draw_room plots every door in every view showing
; its room, the doors of a room shared by several views are drawn several times over.
; Heroes, monsters and objects appear as the first frame of play plots them.
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: corrupted
.draw_all_views
    jsr draw_view_0                     ; The Ranger's view, top left
    jsr draw_view_1                     ; The Magic-User's view, top right
    jsr draw_view_2                     ; The Barbarian's view, bottom left
    jsr draw_view_3                     ; The Fighter's view, bottom right
    rts                                 ; Return with all four rooms drawn
; ***************************************************************************************
; Draw the top-left view
;
; Draw the walls and doors of the room in hero 0's view, the Ranger's, whose top-left
; cell starts at byte column 1, pixel row 1 (see plot_at_cell for the view coordinates).
; draw_all_views calls this as a level starts, and show_hero_room when hero 0 enters
; another room. The view's corner is passed to draw_room in plot_y and, for want of a
; spare variable, in cell_x; only the low byte of view_room is passed, in map_ptr, as
; draw_room supplies page &0C.
;
; On Entry:
;     VIEW_ROOM: the room hero 0 is in
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.draw_view_0
    lda #1                              ; Top-left view: pixel row 1...
    sta plot_y                          ; ...as the view's top pixel row
    lda #1                              ; ...byte column 1...
    sta cell_x                          ; ...in cell_x, as draw_room expects
    lda view_room                       ; ...the room the Ranger's view shows
    sta map_ptr                         ; ...whose walls draw_room reads
    jsr draw_room                       ; Draw its walls and doors
    rts                                 ; Return with the top-left view redrawn
; ***************************************************************************************
; Draw the top-right view
;
; Draw the room in hero 1's view, the Magic-User's, whose top-left is byte column &23,
; pixel row 1. Called as draw_view_0 is.
;
; On Entry:
;     VIEW_ROOM + 2: the room hero 1 is in
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.draw_view_1
    lda #1                              ; Top-right view: pixel row 1...
    sta plot_y                          ; ...as the view's top pixel row
    lda #view_right_column              ; ...byte column &23...
    sta cell_x                          ; ...as the view's left screen column
    lda view_room + 2                   ; ...the room the Magic-User's view shows
    sta map_ptr                         ; ...whose walls draw_room reads
    jsr draw_room                       ; Draw its walls and doors
    rts                                 ; Return with the top-right view redrawn
; ***************************************************************************************
; Draw the bottom-left view
;
; Draw the room in hero 2's view, the Barbarian's, whose top-left is byte column 1, pixel
; row &67. Called as draw_view_0 is.
;
; On Entry:
;     VIEW_ROOM + 4: the room hero 2 is in
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.draw_view_2
    lda #view_bottom_row                ; Bottom-left view: pixel row &67...
    sta plot_y                          ; ...as the view's top pixel row
    lda #1                              ; ...byte column 1...
    sta cell_x                          ; ...as the view's left screen column
    lda view_room + 4                   ; ...the room the Barbarian's view shows
    sta map_ptr                         ; ...whose walls draw_room reads
    jsr draw_room                       ; Draw its walls and doors
    rts                                 ; Return with the bottom-left view redrawn
; ***************************************************************************************
; Draw the bottom-right view
;
; Draw the room in hero 3's view, the Fighter's, whose top-left is byte column &23, pixel
; row &67. Called as draw_view_0 is.
;
; On Entry:
;     VIEW_ROOM + 6: the room hero 3 is in
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.draw_view_3
    lda #view_bottom_row                ; Bottom-right view: pixel row &67...
    sta plot_y                          ; ...as the view's top pixel row
    lda #view_right_column              ; ...byte column &23...
    sta cell_x                          ; ...as the view's left screen column
    lda view_room + 6                   ; ...the room the Fighter's view shows
    sta map_ptr                         ; ...whose walls draw_room reads
    jsr draw_room                       ; Draw its walls and doors
    rts                                 ; Return with the bottom-right view redrawn
; ***************************************************************************************
; Draw a room
;
; Repaint one view with the walls of its room and the level's doors, wiping whatever the
; view showed before. Called by draw_view_0 to draw_view_3, so as a level starts and
; whenever a hero changes room.
;
; The room's eight wall bytes (see test_wall for the map layout) are read through
; map_ptr, whose high byte is set here to page &0C (room_walls). Each byte is one row of
; cells: draw_room_row plots a wall block or a blank in each of its eight cells, and
; plot_y moves down twelve pixel rows for the next. Every cell is painted, so this also
; wipes the previous room's creatures and objects; they reappear as they are next
; plotted. Then each of doors 20 to 1 is plotted at its map cell through plot_at_cell,
; which draws it only in views whose room holds it, and in every such view, not just this
; one. A closed door's cell is also a wall in room_walls, so it is first drawn as a wall
; block and then covered by the door; an opened door has its wall bit cleared and its
; position set to off_map, so it is drawn nowhere.
;
; On Entry:
;     MAP_PTR: the room's offset in room_walls (the low byte)
;     CELL_X: the view's left byte column
;     PLOT_Y: the view's top pixel row
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: corrupted
;     CELL_X: corrupted
;     CELL_Y: corrupted
.draw_room
    lda #>(room_walls)                  ; The room's walls are in page &0C
    sta map_ptr_hi                      ; ...so map_ptr points at the room's wall bytes
; Walls: paint each of the room's eight rows of cells, wall or blank, from its wall byte, twelve pixel rows apart.
    ldy #0                              ; For each of the room's eight rows of cells...
.draw_room_walls
    lda (map_ptr),y                     ; ...take its eight wall bits...
    sta scratch                         ; ...in scratch for draw_room_row
    tya                                 ; Keep the row number...
    pha                                 ; ...on the stack across the row
    jsr draw_room_row                   ; ...and draw the row's walls and blanks
    clc                                 ; Twelve pixel rows down
    lda plot_y                          ; Down to the next row of cells...
    adc #&0c                            ; ...each 12 pixel rows tall
    sta plot_y                          ; ...ready for the next row
    pla                                 ; Recover the row number...
    tay                                 ; ...back in Y
    iny                                 ; Next row of the room down
    cpy #8                              ; All eight rows done?
    bne draw_room_walls                 ; No: draw the next row
; Doors: plot every door on the level through plot_at_cell, which shows only those in rooms on view, in every such view.
    ldx #max_door                       ; Then doors 20 to 1, wherever they are on the map
.draw_room_doors
    lda door_x,x                        ; This door's map x...
    sta cell_x                          ; ...as the cell to plot
    lda door_y,x                        ; ...and its map y (off_map once opened)...
    sta cell_y                          ; ...as cell_y
    lda #0                              ; Doors sit squarely in their cells:
    sta plot_offset_x                   ; ...no horizontal offset...
    sta plot_offset_y                   ; ...and no vertical offset
    lda door_sprite,x                   ; Its sprite, vertical or horizontal...
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the door number...
    pha                                 ; ...on the stack: plot_at_cell changes X
    jsr plot_at_cell                    ; Plot it in every view showing its cell
    pla                                 ; Recover the door number...
    tax                                 ; ...in X for the count
    dex                                 ; Next door down
    bne draw_room_doors                 ; Until door 1 is drawn
    rts                                 ; Return with the room and its doors drawn
; ***************************************************************************************
; Draw one row of a room
;
; Plot a wall block or a blank in each of the eight cells of one row of a view, from bit
; 7 of scratch (the leftmost cell) to bit 0, four byte columns apart, starting at byte
; column cell_x. Called by draw_room for each row. The cells are plotted with plot_sprite
; directly, in this view only.
;
; On Entry:
;     SCRATCH: the row's eight wall bits, the leftmost cell in bit 7
;     CELL_X: the view's left byte column
;     PLOT_Y: the row's top pixel row
;
; On Exit:
;     A: 0
;     X: 0
;     Y: corrupted
;     PLOT_X: cell_x + 32, just right of the view
.draw_room_row
    lda cell_x                          ; Start at the view's left edge
    sta plot_x                          ; ...as the first cell's screen column
    ldx #&80                            ; Bit mask, starting with the leftmost cell
.draw_room_cell
    txa                                 ; Keep this cell's bit mask...
    pha                                 ; ...on the stack: plot_sprite leaves X = 0...
    sta scratch2                        ; ...and in scratch2 for the test
    lda scratch                         ; Wall in this cell?
    and scratch2                        ; ...against the row's wall bits
    beq plot_blank                      ; No: an open cell, blanked
    lda #spr_wall                       ; Yes: plot the wall block (sprite 0)
    sta sprite_number                   ; ...as the sprite to plot
    jsr plot_sprite                     ; Draw the wall block in this cell
    jmp next_room_cell                  ; On to the next cell
.plot_blank
    lda #spr_blank                      ; Plot the blank (sprite &15)
    sta sprite_number                   ; ...as the sprite to plot
    jsr plot_sprite                     ; Clear whatever the view showed there
.next_room_cell
    clc                                 ; Four byte columns right
    lda plot_x                          ; Next cell's screen column...
    adc #4                              ; ...four bytes, one cell's width, along
    sta plot_x                          ; ...stored for the next plot
    pla                                 ; This cell's mask back from the stack...
    lsr a                               ; ...shifted to the next cell right
    tax                                 ; ...into X; zero once the eighth cell is done
    bne draw_room_cell                  ; ...until all eight are done
    rts                                 ; Return with the row drawn, X = 0
; ***************************************************************************************
; Plot a sprite at a map cell in every view
;
; Draw (or, with the blank sprite, erase) sprite_number at a map cell, in every view that
; is showing the cell's room. Heroes, skulls, monsters, sparkles, missiles, objects,
; keys, doors, trapdoors and the Chalice are all drawn and erased through here; only the
; walls (draw_room_row) and the status panel are plotted directly. So a cell in a room
; that two heroes share is drawn in both views, and one in a room that no view shows is
; not drawn at all.
;
; Map coordinates. The dungeon is a grid of cells, x across from 0 at the left, y down
; from 0 at the top, divided into rooms of 8x8 cells, four rooms across (x 0-31) and six
; down (y 0-47). A room is named by its offset in room_walls, 32 x its row of rooms + 8 x
; its column of rooms, which is (y AND &F8) x 4 + (x AND &F8): always a multiple of 8,
; from 0 to &B8 (test_wall describes the map's bytes). The cell's place within its room
; is x AND 7, y AND 7.
;
; View coordinates. plot_sprite takes a byte column (plot_x, 0-79 across the screen, two
; MODE 2 pixels each) and a pixel row (plot_y, from 0 at the top). Each view shows one
; room, 8 cells of 4 byte columns by 8 cells of 12 pixel rows (32 x 96), with its
; top-left at column 1 or view_right_column (&23) and row 1 or view_bottom_row (&67):
; hero 0's view top left, 1 top right, 2 bottom left, 3 bottom right. view_room + 2 x
; hero holds the offset of the room each view shows. A cell's sprite goes at the view's
; corner + ((x AND 7) x 4 + plot_offset_x, (y AND 7) x 12 + plot_offset_y). The offsets
; are signed (&FA is 6 rows up) and place a sprite part way between cells while it steps.
;
; The room offset is worked out once and compared with the low byte of each view_room
; entry, views 0 to 3 in turn. A cell at off_map (&FF, &FF), where collected objects,
; opened doors and parked monsters are put, comes out as &DB, through the carries of the
; sum: not a multiple of 8, so no view shows it and it is never drawn. There is no
; clipping, but no hero's or monster's step crosses a room edge, so a stepping sprite
; stays inside its view.
;
; cell_x and cell_y are overwritten with the position within the room, so a caller that
; needs the map cell again sets them again; code that reads them afterwards without doing
; so sees these view positions.
;
; On Entry:
;     CELL_X: map x
;     CELL_Y: map y
;     SPRITE_NUMBER: sprite to plot
;     PLOT_OFFSET_X: byte columns to shift right
;     PLOT_OFFSET_Y: pixel rows to shift down
;
; On Exit:
;     CELL_X: byte column within the room
;     CELL_Y: pixel row within the room
;     CELL_ROOM: the cell's room, as an offset into room_walls
; Which room is the cell in? Its offset in room_walls, the same number view_room holds for each view.
.plot_at_cell
    lda cell_y                          ; Room = (cell_y AND &F8) x 4 + (cell_x AND &F8)...
    and #&f8                            ; ...y AND &F8 = 8 x the cell's row of rooms...
    sta scratch                         ; ...kept in scratch, to add up four times...
    clc                                 ; ...(y < 64 on the map: no carry, so clear it once)
    adc scratch                         ; ...doubled: 16 bytes per row of rooms so far...
    adc scratch                         ; ...tripled: 24...
    adc scratch                         ; ...x 4: 32 bytes, four rooms, per row of rooms
    sta cell_room                       ; ...the offset of the cell's row of rooms
    lda cell_x                          ; Add the room's column in that row...
    and #&f8                            ; ...x AND &F8 = 8 x the column: 8 bytes per room
    adc cell_room                       ; ...giving the room's offset in room_walls (0-&B8)
    sta cell_room                       ; ...in cell_room, to compare with each view_room
; Where in a view does the cell go? Its column and row within the room, scaled to bytes and pixel rows, plus the sprite's offsets.
    lda cell_x                          ; Byte column in a view = (x AND 7) x 4 + offset_x
    and #7                              ; ...the cell's column within its room, 0-7...
    asl a                               ; ...x 2...
    asl a                               ; ...x 4: each cell is 4 byte columns wide
    clc                                 ; ...clear the carry for the offset
    adc plot_offset_x                   ; ...plus the sprite's signed offset in byte columns
    sta cell_x                          ; ...cell_x is now the column within the view
    lda cell_y                          ; Pixel row in a view = (y AND 7) x 12 + offset_y
    and #7                              ; ...the cell's row within its room, 0-7...
    asl a                               ; ...x 2...
    asl a                               ; ...x 4...
    sta scratch                         ; ...row x 4 kept in scratch, for the sum...
    asl a                               ; ...x 8...
    clc                                 ; ...clear the carry (at most 56 + 28)
    adc scratch                         ; ...x 8 + x 4 = x 12: each cell is 12 rows tall
    adc plot_offset_y                   ; ...plus the sprite's signed offset in pixel rows
    sta cell_y                          ; ...cell_y is now the row within the view
; Plot it in each view showing that room, at the view's top-left corner plus the position within the room.
    lda view_room                       ; The Ranger's view (top left): this room?
    cmp cell_room                       ; ...the room the cell is in?
    bne check_view_1_room               ; Not shown there: try the top-right view
    clc                                 ; Shown: screen position = view corner (1, 1) + cell's
    lda #1                              ; ...the view's left byte column, 1...
    adc cell_x                          ; ...plus the column within the view
    sta plot_x                          ; ...as plot_x
    lda #1                              ; ...the view's top pixel row, 1...
    adc cell_y                          ; ...plus the row within the view
    sta plot_y                          ; ...as plot_y
    jsr plot_sprite                     ; Draw it in the top-left view
.check_view_1_room
    lda view_room + 2                   ; The Magic-User's view (top right): this room?
    cmp cell_room                       ; ...the room the cell is in?
    bne check_view_2_room               ; Not shown there: try the bottom-left view
    clc                                 ; Shown: view corner (&23, 1) + cell's position
    lda #view_right_column              ; ...the view's left byte column...
    adc cell_x                          ; ...plus the column within the view
    sta plot_x                          ; ...as plot_x
    lda #1                              ; ...the view's top pixel row, 1...
    adc cell_y                          ; ...plus the row within the view
    sta plot_y                          ; ...as plot_y
    jsr plot_sprite                     ; Draw it in the top-right view
.check_view_2_room
    lda view_room + 4                   ; The Barbarian's view (bottom left): this room?
    cmp cell_room                       ; ...the room the cell is in?
    bne check_view_3_room               ; Not shown there: try the bottom-right view
    clc                                 ; Shown: view corner (1, &67) + cell's position
    lda #1                              ; ...the view's left byte column, 1...
    adc cell_x                          ; ...plus the column within the view
    sta plot_x                          ; ...as plot_x
    lda #view_bottom_row                ; ...the view's top pixel row...
    adc cell_y                          ; ...plus the row within the view
    sta plot_y                          ; ...as plot_y
    jsr plot_sprite                     ; Draw it in the bottom-left view
.check_view_3_room
    lda view_room + 6                   ; The Fighter's view (bottom right): this room?
    cmp cell_room                       ; ...the room the cell is in?
    bne plot_at_cell_done               ; Not shown there: done
    clc                                 ; Shown: view corner (&23, &67) + cell's position
    lda #view_right_column              ; ...the view's left byte column...
    adc cell_x                          ; ...plus the column within the view
    sta plot_x                          ; ...as plot_x
    lda #view_bottom_row                ; ...the view's top pixel row...
    adc cell_y                          ; ...plus the row within the view
    sta plot_y                          ; ...as plot_y
    jsr plot_sprite                     ; Draw it in the bottom-right view
.plot_at_cell_done
    rts                                 ; Return; cell_x, cell_y now hold the view position
