; ***************************************************************************************
; Padding to the upper game
;
; Zeros in Dun1 from the end of Coder (&59B0) to the upper game at &6E80. In play this is
; screen memory. The level file is loaded into its last rows, at &6B00-&6DAF, so the
; labels for the level file's parts are defined here.
    skip 4432
.level_object_x                         ; &6B00
    skip 32
.level_object_y                         ; &6B20
    skip 32
.level_object_type                      ; &6B40
    skip 32
.level_door_x                           ; &6B60
    skip 21
.level_door_y                           ; &6B75
    skip 21
.level_door_sprite                      ; &6B8A
    skip 22
.level_key_x                            ; &6BA0
    skip 21
.level_key_y                            ; &6BB5
    skip 27
.level_trapdoor_x                       ; &6BD0
    skip 8
.level_trapdoor_y                       ; &6BD8
    skip 8
.level_walls                            ; &6BE0
    skip 208
.level_object_free_map                  ; &6CB0
    skip 208
.level_wall_sprite                      ; &6D80
    skip 256
; &6E80: the upper game follows
