; ***************************************************************************************
; The per-level workspace
;
; 256 bytes refreshed from workspace_template at the start of every level by
; reset_workspace: the heroes' places and steps, missiles, keys, health, views and
; scratch bytes. The workspace moves by changing WORKSPACE alone. Its fields are labels in a block
; that emits no bytes (only skips), so they appear in the build's symbols. Fields of four
; or five entries are indexed by hero number.

WORKSPACE = &0700

    org WORKSPACE
.workspace
; General-purpose scratch byte.
.scratch
    skip 1
; Second scratch byte.
.scratch2
    skip 1
; Map x of the cell being drawn, tested or moved to. plot_at_cell replaces it with the pixel offset within the room.
.cell_x
    skip 1
; Map y of the cell being drawn, tested or moved to. plot_at_cell replaces it with the pixel offset within the room.
.cell_y
    skip 1
; Room of the cell being drawn, as an offset into room_walls.
.cell_room
    skip 2
; Map x of the creature being moved, before the move.
.previous_x
    skip 1
; Map y of the creature being moved, before the move.
.previous_y
    skip 1
; Pixel offset of the hero being moved, before the move.
.previous_offset_x
    skip 1
; Pixel offset of the hero being moved, before the move.
.previous_offset_y
    skip 7
; Map x of each hero.
.hero_x
    skip 5
; Map y of each hero.
.hero_y
    skip 5
; Direction each hero faces: 1 up, 3 right, 5 down, 7 left; 0 when the hero is not in play.
.hero_direction
    skip 6
; Animation frame of each hero (0 or 1), added to its sprite.
.hero_frame
    skip 5
; Frames left in each hero's step between cells.
.hero_step
    skip 5
; Each hero's horizontal pixel offset while between cells.
.hero_offset_x
    skip 6
; Each hero's vertical pixel offset while between cells.
.hero_offset_y
    skip 16
; Map x of each missile (12 slots, three per hero).
.missile_x
    skip 12
; Map y of each missile.
.missile_y
    skip 12
; Direction of each missile: 1 up, 2 right, 3 down, 4 left; bit 7 set for a missile just fired; 0 for an empty slot.
.missile_direction
    skip 12
; Sprite base of each missile, to which its direction is added; also identifies the hero who fired it.
.missile_sprite_base
    skip 12
; INKEY key number of each hero's up key.
.hero_key_up
    skip 4
; INKEY key number of each hero's down key.
.hero_key_down
    skip 4
; INKEY key number of each hero's right key.
.hero_key_right
    skip 4
; INKEY key number of each hero's left key.
.hero_key_left
    skip 4
; INKEY key number of each hero's fire key.
.hero_key_fire
    skip 16
; Health tens digit, as a digit sprite (&1E-&27); &1D when the hero is dead.
.hero_health_tens
    skip 5
; Health units digit, as a digit sprite.
.hero_health_units
    skip 11
; The room each hero's view shows: a pointer into room_walls, low byte then high byte, for each hero in turn (hero x at view_room + 2x).
.view_room
    skip 16
; Sprite base of each hero's missiles: arrows, fireballs, axes, swords.
.hero_missile_sprites
    skip 5
; Sprite base of each hero, to which direction and frame are added.
.hero_sprites
    skip 7
; Non-zero while the hero wears Boots of Speed.
.hero_has_boots
    skip 4
; Bit masks for the cells of a room row, left to right: &80, &40 ... &01.
.bit_masks
    skip 16
; Pixel row of each hero's section of the status panel.
.hero_panel_y
    skip 45
; Index of the last object to search when looking backwards for a teleporter (&1E, from workspace_template).
.teleport_last
    skip 2
; Written by draw_victory_ring; not read.
.victory_sprite_copy
    skip 1
.workspace_end
ASSERT workspace_end - workspace = &100
    clear workspace, workspace_end      ; Only labels: leave the memory free for whatever the file holds there
