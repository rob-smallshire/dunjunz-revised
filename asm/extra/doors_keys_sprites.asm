; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
; Number of the key each hero carries, or 0.
.hero_key
    equb &00, &00, &00, &00, &00
; Set when the hero has just swapped keys, so the key dropped is not picked straight back up.
.hero_key_dropped
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00
; Hero map x, kept for the door and key checks.
.hero_door_x
    equb &1a, &09, &00, &16, &00
; Hero map y, kept for the door and key checks.
.hero_door_y
    equb &06, &1d, &00, &09, &00, &00, &00, &00
    equb &00, &00, &00
; Data of sprite &2D: 4 bytes x 12 rows.
.sprite_magic_user_up_0
    equb &01, &0a, &00, &00
    equb &03, &0a, &0b, &00
    equb &03, &00, &0b, &02
    equb &03, &00, &00, &03
    equb &03, &00, &0a, &03
    equb &03, &10, &1a, &01
    equb &01, &27, &0f, &23
    equb &01, &33, &33, &23
    equb &01, &13, &33, &00
    equb &03, &13, &33, &00
    equb &03, &03, &22, &00
    equb &03, &03, &00, &00
; Data of sprite &2E: 4 bytes x 12 rows.
.sprite_magic_user_up_1
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &0f, &00, &00, &0f
    equb &03, &00, &0a, &03
    equb &03, &10, &1a, &01
    equb &01, &27, &0f, &23
    equb &01, &33, &33, &23
    equb &01, &13, &33, &03
    equb &00, &13, &33, &03
    equb &00, &03, &23, &03
    equb &00, &01, &01, &03
; Data of sprite &2F: 4 bytes x 12 rows.
.sprite_magic_user_right_0
    equb &03, &00, &03, &00
    equb &03, &03, &03, &02
    equb &03, &13, &00, &0f
    equb &03, &27, &00, &00
    equb &13, &32, &00, &00
    equb &13, &27, &0a, &00
    equb &13, &27, &0a, &00
    equb &13, &32, &00, &00
    equb &01, &27, &00, &0a
    equb &00, &13, &01, &0a
    equb &00, &03, &03, &0a
    equb &00, &01, &03, &00
; Data of sprite &30: 4 bytes x 12 rows.
.sprite_magic_user_right_1
    equb &00, &00, &00, &00
    equb &00, &01, &03, &0a
    equb &00, &13, &07, &00
    equb &01, &27, &00, &00
    equb &11, &32, &00, &00
    equb &11, &27, &0a, &00
    equb &13, &27, &0a, &00
    equb &13, &32, &00, &00
    equb &03, &27, &05, &00
    equb &03, &13, &07, &00
    equb &03, &03, &07, &00
    equb &03, &01, &02, &00
; Data of sprite &31: 4 bytes x 12 rows.
.sprite_magic_user_down_0
    equb &00, &00, &03, &03
    equb &00, &11, &03, &03
    equb &00, &33, &23, &03
    equb &00, &33, &23, &02
    equb &13, &33, &33, &02
    equb &13, &0f, &1b, &02
    equb &02, &25, &20, &03
    equb &03, &05, &00, &03
    equb &03, &00, &00, &03
    equb &01, &07, &00, &03
    equb &00, &07, &05, &03
    equb &00, &00, &05, &02
; Data of sprite &32: 4 bytes x 12 rows.
.sprite_magic_user_down_1
    equb &03, &02, &02, &00
    equb &03, &13, &03, &00
    equb &03, &33, &23, &00
    equb &03, &33, &23, &02
    equb &13, &33, &33, &02
    equb &13, &0f, &1b, &02
    equb &02, &25, &20, &03
    equb &03, &05, &00, &03
    equb &0f, &00, &00, &0f
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &33: 4 bytes x 12 rows.
.sprite_magic_user_left_0
    equb &00, &03, &02, &00
    equb &05, &03, &03, &00
    equb &05, &02, &23, &00
    equb &05, &00, &1b, &02
    equb &00, &00, &31, &23
    equb &00, &05, &1b, &23
    equb &00, &05, &1b, &23
    equb &00, &00, &31, &23
    equb &00, &00, &1b, &03
    equb &0f, &00, &23, &03
    equb &01, &03, &03, &03
    equb &00, &03, &00, &03
; Data of sprite &34: 4 bytes x 12 rows.
.sprite_magic_user_left_1
    equb &00, &01, &02, &03
    equb &00, &0b, &03, &03
    equb &00, &0b, &23, &03
    equb &00, &0a, &1b, &03
    equb &00, &00, &31, &23
    equb &00, &05, &1b, &23
    equb &00, &05, &1b, &22
    equb &00, &00, &31, &22
    equb &00, &00, &1b, &02
    equb &00, &0b, &23, &00
    equb &05, &03, &02, &00
    equb &00, &00, &00, &00
; Data of sprite &35: 4 bytes x 12 rows.
.sprite_barbarian_up_0
    equb &00, &00, &3f, &3f
    equb &00, &0f, &05, &0a
    equb &01, &0f, &2d, &1e
    equb &01, &0f, &05, &0a
    equb &0b, &02, &00, &03
    equb &0f, &1a, &20, &0f
    equb &0f, &34, &38, &0f
    equb &0f, &30, &30, &0f
    equb &0f, &34, &38, &0f
    equb &0b, &1a, &25, &07
    equb &05, &03, &0b, &0a
    equb &00, &0b, &07, &00
; Data of sprite &36: 4 bytes x 12 rows.
.sprite_barbarian_up_1
    equb &00, &15, &3f, &2a
    equb &05, &0a, &0f, &00
    equb &07, &1e, &0f, &28
    equb &07, &0a, &0f, &00
    equb &03, &02, &01, &02
    equb &0f, &10, &25, &0a
    equb &0f, &34, &38, &0f
    equb &0f, &30, &30, &0f
    equb &0f, &34, &38, &0f
    equb &0f, &12, &21, &0f
    equb &01, &0b, &07, &02
    equb &00, &07, &03, &00
; Data of sprite &37: 4 bytes x 12 rows.
.sprite_barbarian_right_0
    equb &00, &0f, &02, &00
    equb &05, &0b, &0f, &0a
    equb &05, &0b, &0f, &0a
    equb &0b, &1a, &05, &0a
    equb &07, &34, &20, &28
    equb &0b, &34, &20, &28
    equb &03, &34, &20, &28
    equb &07, &34, &20, &3d
    equb &0b, &12, &05, &1f
    equb &01, &0f, &07, &1f
    equb &05, &0f, &07, &1f
    equb &00, &0f, &03, &3d
; Data of sprite &38: 4 bytes x 12 rows.
.sprite_barbarian_right_1
    equb &00, &0f, &02, &28
    equb &05, &0b, &0f, &0a
    equb &05, &0b, &0f, &0a
    equb &03, &1a, &05, &0a
    equb &0b, &34, &20, &28
    equb &03, &34, &20, &3d
    equb &0b, &34, &25, &1f
    equb &07, &34, &25, &1f
    equb &0b, &1a, &07, &1f
    equb &05, &0f, &07, &15
    equb &05, &0f, &03, &00
    equb &00, &0f, &00, &00
; Data of sprite &39: 4 bytes x 12 rows.
.sprite_barbarian_down_0
    equb &00, &0b, &07, &00
    equb &05, &07, &03, &0a
    equb &0b, &1a, &25, &07
    equb &0f, &34, &38, &0f
    equb &0f, &30, &30, &0f
    equb &0f, &34, &38, &0f
    equb &0f, &10, &25, &0f
    equb &03, &00, &01, &07
    equb &05, &0a, &0f, &02
    equb &2d, &1e, &0f, &02
    equb &05, &0a, &0f, &00
    equb &3f, &3f, &00, &00
; Data of sprite &3A: 4 bytes x 12 rows.
.sprite_barbarian_down_1
    equb &00, &03, &0b, &00
    equb &01, &0b, &07, &02
    equb &0f, &12, &21, &0f
    equb &0f, &34, &38, &0f
    equb &0f, &30, &30, &0f
    equb &0f, &34, &38, &0f
    equb &05, &1a, &20, &0f
    equb &01, &02, &01, &03
    equb &00, &0f, &05, &0b
    equb &14, &0f, &2d, &0b
    equb &00, &0f, &05, &0a
    equb &15, &3f, &2a, &00
; Data of sprite &3B: 4 bytes x 12 rows.
.sprite_barbarian_left_0
    equb &3e, &03, &0f, &00
    equb &2f, &0b, &0f, &0a
    equb &2f, &0b, &0f, &02
    equb &2f, &0a, &21, &07
    equb &3e, &10, &38, &0b
    equb &14, &10, &38, &03
    equb &14, &10, &38, &07
    equb &14, &10, &38, &0b
    equb &05, &0a, &25, &07
    equb &05, &0f, &07, &0a
    equb &05, &0f, &07, &0a
    equb &00, &01, &0f, &00
; Data of sprite &3C: 4 bytes x 12 rows.
.sprite_barbarian_left_1
    equb &00, &00, &0f, &00
    equb &00, &03, &0f, &0a
    equb &2a, &0b, &0f, &0a
    equb &2f, &0b, &25, &07
    equb &2f, &1a, &38, &0b
    equb &2f, &1a, &38, &07
    equb &3e, &10, &38, &03
    equb &14, &10, &38, &07
    equb &05, &0a, &25, &03
    equb &05, &0f, &07, &0a
    equb &05, &0f, &07, &0a
    equb &14, &01, &0f, &00
; Data of sprite &3D: 4 bytes x 12 rows.
.sprite_fighter_up_0
    equb &00, &15, &00, &00
    equb &00, &00, &2a, &00
    equb &28, &0a, &15, &00
    equb &2d, &0e, &00, &2b
    equb &39, &0e, &00, &03
    equb &39, &26, &0a, &33
    equb &39, &23, &0b, &33
    equb &39, &27, &0f, &33
    equb &00, &36, &3c, &22
    equb &00, &3e, &3c, &2a
    equb &15, &00, &0c, &15
    equb &00, &00, &0c, &00
; Data of sprite &3E: 4 bytes x 12 rows.
.sprite_fighter_up_1
    equb &00, &28, &00, &15
    equb &00, &28, &00, &15
    equb &14, &00, &00, &15
    equb &14, &27, &04, &1d
    equb &39, &27, &04, &1d
    equb &39, &22, &0e, &1d
    equb &11, &32, &1a, &03
    equb &00, &27, &0f, &33
    equb &00, &36, &3c, &33
    equb &00, &3e, &3c, &2a
    equb &15, &04, &08, &15
    equb &00, &04, &08, &00
; Data of sprite &3F: 4 bytes x 12 rows.
.sprite_fighter_right_0
    equb &00, &3c, &3c, &28
    equb &00, &11, &22, &00
    equb &2a, &33, &27, &0a
    equb &15, &39, &05, &00
    equb &14, &06, &08, &00
    equb &14, &0f, &08, &00
    equb &14, &0f, &00, &00
    equb &1c, &02, &00, &15
    equb &1d, &28, &00, &2a
    equb &3b, &33, &17, &00
    equb &00, &33, &0a, &00
    equb &00, &01, &0a, &00
; Data of sprite &40: 4 bytes x 12 rows.
.sprite_fighter_right_1
    equb &00, &00, &28, &00
    equb &2a, &33, &36, &00
    equb &15, &39, &33, &28
    equb &1c, &02, &11, &1e
    equb &1c, &0f, &00, &0a
    equb &14, &0f, &00, &00
    equb &14, &02, &00, &00
    equb &15, &2c, &08, &00
    equb &3b, &26, &08, &00
    equb &11, &23, &00, &00
    equb &11, &23, &3f, &3f
    equb &00, &00, &00, &00
; Data of sprite &41: 4 bytes x 12 rows.
.sprite_fighter_down_0
    equb &00, &0c, &00, &00
    equb &2a, &0c, &00, &2a
    equb &15, &3c, &3d, &00
    equb &11, &3c, &39, &00
    equb &33, &0f, &1b, &36
    equb &33, &07, &13, &36
    equb &33, &05, &19, &36
    equb &03, &00, &0d, &36
    equb &17, &00, &0d, &1e
    equb &00, &2a, &05, &14
    equb &00, &15, &00, &00
    equb &00, &00, &2a, &00
; Data of sprite &42: 4 bytes x 12 rows.
.sprite_fighter_down_1
    equb &00, &04, &08, &00
    equb &2a, &04, &08, &2a
    equb &15, &3c, &3d, &00
    equb &33, &3c, &39, &00
    equb &33, &0f, &1b, &00
    equb &03, &25, &31, &22
    equb &2e, &0d, &11, &36
    equb &2e, &08, &1b, &36
    equb &2e, &08, &1b, &28
    equb &2a, &00, &00, &28
    equb &2a, &00, &14, &00
    equb &2a, &00, &14, &00
; Data of sprite &43: 4 bytes x 12 rows.
.sprite_fighter_left_0
    equb &00, &05, &02, &00
    equb &00, &05, &33, &00
    equb &00, &2b, &33, &37
    equb &15, &00, &14, &2e
    equb &2a, &00, &01, &2c
    equb &00, &00, &0f, &28
    equb &00, &04, &0f, &28
    equb &00, &04, &09, &28
    equb &00, &0a, &36, &2a
    equb &05, &1b, &33, &15
    equb &00, &11, &22, &00
    equb &14, &3c, &3c, &00
; Data of sprite &44: 4 bytes x 12 rows.
.sprite_fighter_left_1
    equb &3f, &3f, &13, &22
    equb &00, &00, &13, &22
    equb &00, &04, &19, &37
    equb &00, &04, &1c, &2a
    equb &00, &00, &01, &28
    equb &00, &00, &0f, &28
    equb &05, &00, &0f, &2c
    equb &2d, &22, &01, &2c
    equb &14, &33, &36, &2a
    equb &00, &39, &33, &15
    equb &00, &14, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &45: 4 bytes x 12 rows.
.sprite_fireball_up
    equb &00, &00, &0a, &00
    equb &00, &01, &03, &00
    equb &00, &05, &07, &00
    equb &00, &01, &0b, &00
    equb &00, &05, &07, &00
    equb &00, &05, &07, &00
    equb &00, &05, &0f, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
; Data of sprite &46: 4 bytes x 12 rows.
.sprite_fireball_right
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &05, &0a
    equb &00, &0f, &0b, &07
    equb &0f, &0b, &07, &07
    equb &00, &0f, &0b, &07
    equb &00, &00, &05, &0a
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &47: 4 bytes x 12 rows.
.sprite_fireball_down
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &05, &0f, &00
    equb &00, &05, &07, &00
    equb &00, &05, &07, &00
    equb &00, &01, &0b, &00
    equb &00, &05, &07, &00
    equb &00, &01, &03, &00
    equb &00, &00, &0a, &00
; Data of sprite &48: 4 bytes x 12 rows.
.sprite_fireball_left
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &05, &0a, &00, &00
    equb &0b, &07, &0f, &00
    equb &0b, &0b, &07, &0f
    equb &0b, &07, &0f, &00
    equb &05, &0a, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &4D: 4 bytes x 12 rows.
.sprite_axe_up
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &15, &2a
    equb &00, &00, &3f, &3f
    equb &00, &00, &15, &2a
    equb &14, &3c, &3c, &3c
    equb &00, &00, &15, &2a
    equb &00, &00, &3f, &3f
    equb &00, &00, &15, &2a
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &4E: 4 bytes x 12 rows.
.sprite_axe_right
    equb &00, &00, &00, &00
    equb &00, &14, &00, &00
    equb &00, &14, &00, &00
    equb &00, &14, &00, &00
    equb &00, &14, &00, &00
    equb &15, &14, &15, &00
    equb &15, &3e, &3f, &00
    equb &15, &3e, &3f, &00
    equb &15, &3e, &3f, &00
    equb &15, &14, &15, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &4F: 4 bytes x 12 rows.
.sprite_axe_down
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &15, &2a, &00, &00
    equb &3f, &3f, &00, &00
    equb &15, &2a, &00, &00
    equb &3c, &3c, &3c, &28
    equb &15, &2a, &00, &00
    equb &3f, &3f, &00, &00
    equb &15, &2a, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &50: 4 bytes x 12 rows.
.sprite_axe_left
    equb &00, &00, &00, &00
    equb &00, &2a, &28, &2a
    equb &00, &3f, &3d, &2a
    equb &00, &3f, &3d, &2a
    equb &00, &3f, &3d, &2a
    equb &00, &2a, &28, &2a
    equb &00, &00, &28, &00
    equb &00, &00, &28, &00
    equb &00, &00, &28, &00
    equb &00, &00, &28, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &1B: 4 bytes x 12 rows.
.sprite_key
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &0a
    equb &00, &00, &05, &05
    equb &00, &00, &05, &05
    equb &0f, &0f, &0f, &05
    equb &0a, &0a, &05, &05
    equb &0a, &0a, &05, &05
    equb &0a, &0a, &00, &0a
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &28: 4 bytes x 12 rows.
.sprite_treasure
    equb &03, &03, &02, &02
    equb &13, &50, &02, &02
    equb &02, &24, &17, &03
    equb &47, &00, &02, &03
    equb &12, &0d, &02, &03
    equb &02, &4f, &02, &03
    equb &06, &32, &02, &03
    equb &47, &02, &02, &03
    equb &12, &a5, &02, &03
    equb &07, &08, &17, &03
    equb &06, &b0, &02, &02
    equb &03, &03, &02, &02
; Data of sprite &29: 4 bytes x 12 rows.
.sprite_food
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &2a, &00, &00, &00
    equb &2a, &00, &00, &00
    equb &15, &00, &00, &00
    equb &2f, &2a, &0f, &00
    equb &2f, &0f, &0f, &0a
    equb &00, &0f, &03, &0b
    equb &00, &05, &0f, &03
    equb &00, &05, &07, &02
    equb &00, &00, &03, &02
    equb &00, &00, &03, &00
    equb &05, &0f, &0f, &00, &0a, &0f, &0f, &0a
    equb &0a, &00, &05, &00, &05, &30, &20, &0a
    equb &05, &00, &00, &0a, &00, &1a, &30, &05
    equb &00, &0a, &00, &05, &0f, &1a, &30, &25
    equb &0f, &00, &00, &0a, &0a, &30, &30, &0a
    equb &05, &00, &00, &0a, &00, &0f, &0f, &00  ; Not referenced
; Data of sprite &2B: 4 bytes x 12 rows.
.sprite_teleporter
    equb &3f, &3f, &3f, &3f
    equb &3e, &3c, &3c, &38
    equb &3e, &3c, &3c, &38
    equb &3e, &3f, &3f, &38
    equb &3e, &3e, &38, &38
    equb &3e, &3e, &38, &38
    equb &3e, &3e, &38, &38
    equb &3e, &3e, &38, &38
    equb &3e, &30, &30, &38
    equb &3e, &3c, &3c, &38
    equb &3e, &3c, &3c, &38
    equb &30, &30, &30, &30
    equb &00, &2c, &00, &00, &00, &2c, &08, &00
    equb &00, &0c, &08, &00, &04, &0f, &0e, &00  ; Not referenced
; Data of sprite &1E: 2 bytes x 10 rows.
.sprite_digit_0
    equb &04, &08
    equb &08, &0c
    equb &08, &0c
    equb &08, &0c
    equb &08, &0c
    equb &0c, &04
    equb &0c, &04
    equb &0c, &04
    equb &0c, &04
    equb &04, &08
; Data of sprite &1F: 2 bytes x 10 rows.
.sprite_digit_1
    equb &04, &00
    equb &0c, &00
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &0c, &00
; Data of sprite &20: 2 bytes x 10 rows.
.sprite_digit_2
    equb &04, &08
    equb &08, &04
    equb &08, &04
    equb &00, &04
    equb &00, &08
    equb &04, &00
    equb &08, &00
    equb &08, &04
    equb &08, &08
    equb &0c, &0c
; Data of sprite &21: 2 bytes x 10 rows.
.sprite_digit_3
    equb &04, &08
    equb &08, &04
    equb &00, &04
    equb &00, &04
    equb &04, &08
    equb &04, &08
    equb &00, &04
    equb &00, &04
    equb &0c, &04
    equb &04, &08
; Data of sprite &22: 2 bytes x 10 rows.
.sprite_digit_4
    equb &00, &08
    equb &04, &08
    equb &04, &08
    equb &08, &08
    equb &08, &0c
    equb &0c, &08
    equb &00, &0c
    equb &00, &08
    equb &00, &08
    equb &04, &08
; Data of sprite &23: 2 bytes x 10 rows.
.sprite_digit_5
    equb &0c, &0c
    equb &08, &04
    equb &08, &00
    equb &08, &00
    equb &04, &00
    equb &00, &08
    equb &00, &04
    equb &04, &04
    equb &08, &04
    equb &04, &08
; Data of sprite &24: 2 bytes x 10 rows.
.sprite_digit_6
    equb &00, &04
    equb &00, &08
    equb &04, &00
    equb &04, &00
    equb &04, &08
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &04, &08
; Data of sprite &25: 2 bytes x 10 rows.
.sprite_digit_7
    equb &0c, &0c
    equb &00, &04
    equb &00, &08
    equb &00, &08
    equb &00, &08
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &04, &00
    equb &0c, &08
; Data of sprite &26: 2 bytes x 10 rows.
.sprite_digit_8
    equb &04, &08
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &04, &08
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &04, &08
; Data of sprite &27: 2 bytes x 10 rows.
.sprite_digit_9
    equb &04, &08
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &08, &04
    equb &04, &08
    equb &00, &08
    equb &00, &08
    equb &04, &00
    equb &08, &00
; Data of sprite &1D: 4 bytes x 12 rows.
.sprite_door_horizontal
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &3f, &3f, &3f, &3f
    equb &3e, &3c, &3c, &38
    equb &3e, &3c, &3c, &38
    equb &3e, &3c, &3c, &38
    equb &3e, &3c, &3c, &38
    equb &30, &30, &30, &30
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &0f, &1a, &30, &20, &00, &00, &00, &25  ; Not referenced
; Data of sprite &16: 4 bytes x 12 rows.
.sprite_sparkle_0
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &15, &2a, &00
    equb &00, &3f, &3f, &00
    equb &00, &3f, &3f, &00
    equb &00, &15, &2a, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &17: 4 bytes x 12 rows.
.sprite_sparkle_1
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &3f, &3f, &00
    equb &00, &00, &00, &00
    equb &15, &15, &2a, &2a
    equb &15, &00, &00, &2a
    equb &15, &00, &00, &2a
    equb &15, &15, &2a, &2a
    equb &00, &00, &00, &00
    equb &00, &3f, &3f, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &18: 4 bytes x 12 rows.
.sprite_sparkle_2
    equb &00, &00, &00, &00
    equb &15, &3f, &3f, &2a
    equb &00, &3f, &3f, &00
    equb &2a, &00, &00, &15
    equb &3f, &00, &00, &3f
    equb &3f, &15, &2a, &3f
    equb &3f, &15, &2a, &3f
    equb &3f, &00, &00, &3f
    equb &2a, &00, &00, &15
    equb &00, &3f, &3f, &00
    equb &15, &3f, &3f, &2a
    equb &00, &00, &00, &00
; Data of sprite &19: 4 bytes x 12 rows.
.sprite_sparkle_3
    equb &3f, &00, &00, &3f
    equb &3f, &2a, &15, &3f
    equb &2a, &2a, &15, &15
    equb &2a, &00, &00, &15
    equb &3f, &15, &2a, &3f
    equb &15, &2a, &15, &2a
    equb &15, &2a, &15, &2a
    equb &3f, &15, &2a, &3f
    equb &2a, &00, &00, &15
    equb &2a, &2a, &15, &15
    equb &3f, &2a, &15, &3f
    equb &3f, &00, &00, &3f
; Data of sprite &2C: 4 bytes x 12 rows.
.sprite_trapdoor
    equb &3c, &3c, &3c, &3c
    equb &29, &03, &03, &16
    equb &3f, &12, &03, &16
    equb &3f, &03, &03, &34
    equb &29, &03, &21, &16
    equb &29, &03, &03, &16
    equb &29, &21, &21, &16
    equb &29, &03, &03, &34
    equb &3f, &03, &21, &16
    equb &3f, &03, &03, &16
    equb &29, &21, &12, &16
    equb &3c, &3c, &3c, &3c
    equb &00, &00, &00, &00, &04, &00, &00, &00
    equb &20, &00, &00, &00, &fd, &14, &93, &00  ; Not referenced
; Data of sprite &11: 4 bytes x 12 rows.
.sprite_arrow_up
    equb &00, &00, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &05, &00, &00
    equb &00, &05, &00, &00
    equb &00, &05, &00, &00
    equb &00, &05, &00, &00
    equb &00, &05, &00, &00
    equb &00, &05, &00, &00
    equb &00, &0c, &08, &00
    equb &00, &08, &08, &00
    equb &00, &00, &00, &00
; Data of sprite &12: 4 bytes x 12 rows.
.sprite_arrow_right
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &0c, &00, &00, &00
    equb &04, &0f, &0f, &2a
    equb &0c, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &13: 4 bytes x 12 rows.
.sprite_arrow_down
    equb &00, &00, &00, &00
    equb &00, &04, &04, &00
    equb &00, &04, &0c, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &0a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &00, &00
; Data of sprite &14: 4 bytes x 12 rows.
.sprite_arrow_left
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &0c
    equb &15, &0f, &0f, &08
    equb &00, &00, &00, &0c
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &1C: 4 bytes x 12 rows.
.sprite_door_vertical
    equb &00, &3f, &3a, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &3e, &38, &00
    equb &00, &30, &30, &00
    equb &01, &00, &00, &00, &17, &00, &00, &90
    equb &17, &00, &00, &00, &00, &00, &00, &00  ; Not referenced
; Data of sprite 0, the wall block (4 bytes x 12 rows), replaced by each level's own from the level file.
.wall_sprite
    equb &0f, &0b, &0f, &07
    equb &03, &0f, &0f, &0f
    equb &0f, &1f, &2f, &0b
    equb &0f, &2f, &0b, &0f
    equb &1f, &0f, &0f, &07
    equb &1f, &1f, &0f, &07
    equb &17, &0f, &07, &07
    equb &1f, &0f, &0f, &07
    equb &0f, &2f, &0b, &0f
    equb &07, &0b, &07, &0f
    equb &0f, &0f, &0f, &03
    equb &0b, &0f, &0f, &0f
; Data of sprite &01: 4 bytes x 12 rows.
.sprite_ranger_up_0
    equb &00, &03, &0b, &00
    equb &01, &00, &0a, &02
    equb &02, &00, &04, &01
    equb &01, &02, &04, &00
    equb &0b, &02, &00, &08
    equb &0b, &07, &00, &08
    equb &1c, &25, &34, &08
    equb &1c, &0f, &1e, &08
    equb &04, &3c, &29, &08
    equb &04, &3c, &0c, &00
    equb &00, &0c, &09, &00
    equb &00, &00, &03, &00
; Data of sprite &02: 4 bytes x 12 rows.
.sprite_ranger_up_1
    equb &00, &03, &02, &00
    equb &00, &00, &01, &00
    equb &00, &00, &00, &0a
    equb &05, &00, &03, &0a
    equb &05, &00, &03, &09
    equb &04, &05, &03, &09
    equb &0c, &25, &34, &09
    equb &1c, &0f, &1e, &09
    equb &04, &3c, &28, &08
    equb &04, &3c, &0c, &00
    equb &01, &0c, &08, &00
    equb &01, &02, &00, &00
; Data of sprite &03: 4 bytes x 12 rows.
.sprite_ranger_right_0
    equb &00, &04, &0b, &00
    equb &00, &0c, &0b, &00
    equb &04, &09, &02, &02
    equb &04, &3c, &02, &03
    equb &14, &1a, &02, &01
    equb &3c, &0f, &0a, &01
    equb &3c, &0f, &0a, &0d
    equb &16, &1a, &04, &0d
    equb &03, &3c, &0c, &03
    equb &03, &06, &08, &02
    equb &00, &00, &01, &00
    equb &00, &00, &01, &00
; Data of sprite &04: 4 bytes x 12 rows.
.sprite_ranger_right_1
    equb &00, &00, &08, &00
    equb &00, &0c, &0d, &00
    equb &06, &0c, &05, &00
    equb &06, &3c, &00, &00
    equb &16, &1a, &00, &01
    equb &3c, &0f, &0a, &01
    equb &3c, &0f, &0a, &01
    equb &14, &1a, &03, &01
    equb &00, &3c, &09, &03
    equb &00, &0c, &0d, &02
    equb &00, &04, &07, &02
    equb &00, &03, &02, &00
; Data of sprite &05: 4 bytes x 12 rows.
.sprite_ranger_down_0
    equb &00, &03, &00, &00
    equb &00, &06, &0c, &00
    equb &00, &0c, &3c, &08
    equb &04, &16, &3c, &08
    equb &04, &2d, &0f, &2c
    equb &04, &38, &1a, &2c
    equb &04, &00, &0b, &07
    equb &04, &00, &01, &07
    equb &00, &08, &01, &02
    equb &02, &08, &00, &01
    equb &01, &05, &00, &02
    equb &00, &07, &03, &00
; Data of sprite &06: 4 bytes x 12 rows.
.sprite_ranger_down_1
    equb &00, &00, &01, &02
    equb &00, &04, &0c, &02
    equb &00, &0c, &3c, &08
    equb &04, &14, &3c, &08
    equb &06, &2d, &0f, &2c
    equb &06, &38, &1a, &0c
    equb &06, &03, &0a, &08
    equb &06, &03, &00, &0a
    equb &05, &03, &00, &0a
    equb &05, &00, &00, &00
    equb &00, &02, &00, &00
    equb &00, &01, &03, &00
; Data of sprite &07: 4 bytes x 12 rows.
.sprite_ranger_left_0
    equb &00, &02, &00, &00
    equb &00, &02, &00, &00
    equb &01, &04, &09, &03
    equb &03, &0c, &3c, &03
    equb &0e, &08, &25, &29
    equb &0e, &05, &0f, &3c
    equb &02, &05, &0f, &3c
    equb &02, &01, &25, &28
    equb &03, &01, &3c, &08
    equb &01, &01, &06, &08
    equb &00, &07, &0c, &00
    equb &00, &07, &08, &00
; Data of sprite &09: 4 bytes x 12 rows.
.sprite_monster_up_0
    equb &00, &00, &00, &02
    equb &00, &00, &01, &13
    equb &04, &08, &01, &13
    equb &45, &30, &8b, &13
    equb &10, &30, &20, &02
    equb &1a, &30, &20, &02
    equb &1a, &30, &25, &07
    equb &1e, &30, &2d, &0f
    equb &3c, &3c, &2d, &0a
    equb &14, &3c, &2c, &00
    equb &00, &00, &0c, &00
    equb &00, &00, &0c, &00
; Data of sprite &0A: 4 bytes x 12 rows.
.sprite_monster_up_1
    equb &00, &04, &08, &00
    equb &00, &04, &08, &02
    equb &45, &30, &8b, &13
    equb &10, &30, &21, &13
    equb &10, &30, &21, &13
    equb &1a, &30, &20, &02
    equb &0f, &30, &00, &02
    equb &1e, &3c, &2d, &07
    equb &1e, &3c, &2d, &0f
    equb &14, &3c, &2d, &0a
    equb &04, &08, &00, &00
    equb &04, &08, &00, &00
; Data of sprite &0B: 4 bytes x 12 rows.
.sprite_monster_right_0
    equb &00, &2d, &0a, &00
    equb &14, &2d, &00, &00
    equb &14, &38, &8e, &08
    equb &14, &30, &24, &08
    equb &14, &30, &24, &08
    equb &14, &30, &20, &00
    equb &1c, &30, &20, &00
    equb &1c, &38, &8a, &00
    equb &0c, &28, &00, &00
    equb &00, &3c, &01, &02
    equb &00, &0f, &03, &03
    equb &00, &0f, &11, &22
; Data of sprite &0C: 4 bytes x 12 rows.
.sprite_monster_right_1
    equb &00, &2d, &0a, &00
    equb &14, &2d, &00, &00
    equb &1c, &38, &8a, &00
    equb &1c, &30, &20, &00
    equb &1c, &30, &20, &00
    equb &14, &30, &24, &08
    equb &3c, &30, &24, &08
    equb &3c, &10, &8e, &08
    equb &0f, &00, &00, &00
    equb &0f, &01, &02, &00
    equb &0b, &03, &03, &00
    equb &00, &11, &22, &00
; Data of sprite &0D: 4 bytes x 12 rows.
.sprite_monster_down_0
    equb &00, &0c, &00, &00
    equb &00, &0c, &00, &00
    equb &00, &1c, &3c, &28
    equb &05, &1e, &3c, &3c
    equb &0f, &1e, &30, &2d
    equb &0b, &1a, &30, &25
    equb &01, &10, &30, &25
    equb &01, &10, &30, &20
    equb &23, &47, &30, &8a
    equb &23, &02, &04, &08
    equb &23, &02, &00, &00
    equb &01, &00, &00, &00
; Data of sprite &0E: 4 bytes x 12 rows.
.sprite_monster_down_1
    equb &00, &00, &04, &08
    equb &00, &00, &04, &08
    equb &05, &1e, &3c, &28
    equb &0f, &1e, &3c, &2d
    equb &0b, &1e, &3c, &2d
    equb &01, &00, &30, &0f
    equb &01, &10, &30, &25
    equb &23, &12, &30, &20
    equb &23, &12, &30, &20
    equb &23, &47, &30, &8a
    equb &01, &04, &08, &00
    equb &00, &04, &08, &00
; Data of sprite &0F: 4 bytes x 12 rows.
.sprite_monster_left_0
    equb &11, &22, &0f, &00
    equb &03, &03, &0f, &00
    equb &01, &02, &3c, &00
    equb &00, &00, &14, &0c
    equb &00, &45, &34, &2c
    equb &00, &10, &30, &2c
    equb &00, &10, &30, &28
    equb &04, &18, &30, &28
    equb &04, &18, &30, &28
    equb &04, &4d, &34, &28
    equb &00, &00, &1e, &28
    equb &00, &05, &1e, &00
; Data of sprite &10: 4 bytes x 12 rows.
.sprite_monster_left_1
    equb &00, &11, &22, &00
    equb &00, &03, &03, &07
    equb &00, &01, &02, &0f
    equb &00, &00, &00, &0f
    equb &04, &4d, &20, &3c
    equb &04, &18, &30, &3c
    equb &04, &18, &30, &28
    equb &00, &10, &30, &2c
    equb &00, &10, &30, &2c
    equb &00, &45, &34, &2c
    equb &00, &00, &1e, &28
    equb &00, &05, &1e, &00
