; ***************************************************************************************
; The level file
;
; Each level file is loaded at LEVEL_FILE, in the screen's bottom rows, while the display
; is blanked, and unpack_level copies it into the game's tables. Its parts are labels in a
; block that emits no bytes.

LEVEL_FILE = &6b00

    org LEVEL_FILE
.level_file
.level_object_x
    skip 32
.level_object_y
    skip 32
.level_object_type
    skip 32
.level_door_x
    skip 21
.level_door_y
    skip 21
.level_door_sprite
    skip 22
.level_key_x
    skip 21
.level_key_y
    skip 27
.level_trapdoor_x
    skip 8
.level_trapdoor_y
    skip 8
.level_walls
    skip 208
.level_object_free_map
    skip 208
.level_wall_sprite
    skip 48
.level_file_end
ASSERT level_file_end - level_file = &2b0
    clear level_file, level_file_end    ; Only labels
