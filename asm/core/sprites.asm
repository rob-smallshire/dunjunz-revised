; ***************************************************************************************
; Sword sprites
;
; Sprites &49-&4C, the Fighter's missile flying up, right, down and left: 4 bytes by 12
; rows each.
.sprite_sword_up
    equb &00, &00, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &15, &00, &00
    equb &00, &03, &02, &00
    equb &00, &01, &00, &00
    equb &00, &01, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &4A: 4 bytes x 12 rows.
.sprite_sword_right
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &01, &00, &00
    equb &01, &03, &3f, &3f
    equb &00, &01, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &4B: 4 bytes x 12 rows.
.sprite_sword_down
    equb &00, &00, &00, &00
    equb &00, &00, &02, &00
    equb &00, &00, &02, &00
    equb &00, &01, &03, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &2a, &00
    equb &00, &00, &00, &00
; Data of sprite &4C: 4 bytes x 12 rows.
.sprite_sword_left
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &02, &00
    equb &3f, &3f, &03, &02
    equb &00, &00, &02, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; ***************************************************************************************
; Unused
;
; Leftover bytes, never read, including fragments of BASIC text ("?&A66=(rx%-lx%)",
; "sprite%?&A99=by%-ty%+1").
    equb &80, &00, &00, &32, &00        ; Not referenced
    equs "eco"
    equb &00, &8e, &0b, &94, &00, &00   ; Not referenced
    equs "?&A66=(rx%-lx%)"
    equb &81                            ; Not referenced
    equs "2+1:sprite%?&A99=by%-ty%+1"
    equb &0d, &03, &d4, &1d, &20, &d4, &31, &2c  ; Not referenced
; Data of sprite &69: 3 bytes x 12 rows.
; ***************************************************************************************
; Panel sprites: the shield and the small digits
;
; Sprite &69, the shield beside each hero's face in the status panel (3 bytes by 12
; rows), then sprites &6A-&72, the small digits 1-9 (1 byte by 5 rows), which show the
; armour rating on the shield and the missile damage.
.sprite_shield
    equb &3f, &3f, &3e
    equb &2a, &00, &14
    equb &2a, &00, &14
    equb &2a, &00, &14
    equb &2a, &00, &14
    equb &2a, &00, &14
    equb &2a, &00, &14
    equb &2a, &00, &14
    equb &15, &00, &28
    equb &15, &00, &28
    equb &00, &3e, &00
    equb &00, &3e, &00
; Data of sprite &6A: 1 bytes x 5 rows.
.sprite_small_digit_1
    equb &01
    equb &01
    equb &01
    equb &01
    equb &01
; Data of sprite &6B: 1 bytes x 5 rows.
.sprite_small_digit_2
    equb &03
    equb &01
    equb &03
    equb &02
    equb &03
; Data of sprite &6C: 1 bytes x 5 rows.
.sprite_small_digit_3
    equb &03
    equb &01
    equb &03
    equb &01
    equb &03
; Data of sprite &6D: 1 bytes x 5 rows.
.sprite_small_digit_4
    equb &02
    equb &02
    equb &03
    equb &03
    equb &01
; Data of sprite &6E: 1 bytes x 5 rows.
.sprite_small_digit_5
    equb &03
    equb &02
    equb &03
    equb &01
    equb &03
; Data of sprite &6F: 1 bytes x 5 rows.
.sprite_small_digit_6
    equb &02
    equb &02
    equb &03
    equb &03
    equb &03
; Data of sprite &70: 1 bytes x 5 rows.
.sprite_small_digit_7
    equb &03
    equb &01
    equb &01
    equb &01
    equb &01
; Data of sprite &71: 1 bytes x 5 rows.
.sprite_small_digit_8
    equb &03
    equb &03
    equb &03
    equb &03
    equb &03
; Data of sprite &72: 1 bytes x 5 rows.
.sprite_small_digit_9
    equb &03
    equb &03
    equb &03
    equb &01
    equb &01
    equb &0a, &00, &05, &00, &00, &00, &0a, &00
    equb &05, &00, &00, &00, &0a, &00, &05  ; Not referenced
; Data of sprite &74: 4 bytes x 3 rows.
; ***************************************************************************************
; Panel sprites: the missile and boots icons
;
; Sprite &74, the missile icon, one per missile a hero may have in flight (4 bytes by 3
; rows), and sprite &75, the boots icon shown while a hero wears the Boots of Speed (2
; bytes by 6 rows).
.sprite_missile_icon
    equb &00, &00, &01, &00
    equb &3f, &3f, &2b, &03
    equb &00, &00, &01, &00
; Data of sprite &75: 2 bytes x 6 rows.
.sprite_boots_icon
    equb &00, &05
    equb &00, &0a
    equb &05, &00
    equb &00, &0a
    equb &05, &00
    equb &0a, &00
; Data of sprite &76: 12 bytes x 8 rows.
; ***************************************************************************************
; The word LEVEL
;
; Sprite &76, the word LEVEL for the level-number display: 12 bytes by 8 rows.
.sprite_level_word
    equb &3c, &00, &14, &3c, &28, &28, &14, &14, &3c, &28, &3c, &00
    equb &3c, &00, &14, &00, &00, &28, &14, &14, &00, &00, &3c, &00
    equb &3c, &00, &14, &3c, &28, &3c, &3c, &14, &3c, &28, &3c, &00
    equb &3c, &3c, &14, &00, &00, &3c, &3c, &14, &00, &00, &3c, &3c
    equb &3c, &3c, &14, &3c, &28, &3c, &3c, &14, &3c, &28, &3c, &3c
    equb &3c, &3c, &14, &3c, &28, &14, &28, &14, &3c, &28, &3c, &3c
    equb &3c, &3c, &14, &3c, &28, &14, &28, &14, &3c, &28, &3c, &3c
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    equb &08, &00, &04, &00, &00, &00, &08, &04
    equb &00, &00, &08, &00, &0c, &0c, &04, &0c
    equb &08, &00, &08, &04, &0c, &08, &0c, &0c
    equb &1a, &35, &03, &8f, &7d, &9a, &82, &03
    equb &00, &00, &00, &6d, &19, &00, &00, &00  ; Not referenced
; OSWORD 8 (ENVELOPE) parameter block for casting magic.
.magic_envelope
    equb &03                            ; Envelope 3
    equb &01                            ; Step length 1 centisecond
    equb &0a, &0a, &ec                  ; Pitch change per step in sections 1-3: 10, 10, -20
    equb &03, &03, &03                  ; Steps in pitch sections 1-3: 3, 3, 3
    equb &80, &00, &00, &ff             ; Amplitude change per step in attack, decay, sustain, release: -128, 0, 0, -1
    equb &80, &80                       ; Target levels at the end of attack and decay: 128, 128
; OSWORD 7 (SOUND) parameter block for casting magic.
.magic_sound
    equw &12, &03, 0, 2                 ; SOUND channel 2 (flush), envelope 3, pitch 0, duration 2
; OSWORD 8 (ENVELOPE) parameter block for collecting treasure.
.treasure_envelope
    equb &03                            ; Envelope 3
    equb &02                            ; Step length 2 centiseconds
    equb &01, &01, &01                  ; Pitch change per step in sections 1-3: 1, 1, 1
    equb &01, &01, &01                  ; Steps in pitch sections 1-3: 1, 1, 1
    equb &80, &00, &00, &f8             ; Amplitude change per step in attack, decay, sustain, release: -128, 0, 0, -8
    equb &80, &80                       ; Target levels at the end of attack and decay: 128, 128
; OSWORD 7 (SOUND) parameter block for collecting treasure.
.treasure_sound
    equw &12, &03, 200, 5               ; SOUND channel 2 (flush), envelope 3, pitch 200, duration 5
; OSWORD 8 (ENVELOPE) parameter block for collecting an item.
.pickup_envelope
    equb &03                            ; Envelope 3
    equb &80                            ; Step length 0 centiseconds, no auto-repeat
    equb &00, &00, &00                  ; Pitch change per step in sections 1-3: 0, 0, 0
    equb &0a, &0a, &0a                  ; Steps in pitch sections 1-3: 10, 10, 10
    equb &0a, &00, &00, &fd             ; Amplitude change per step in attack, decay, sustain, release: 10, 0, 0, -3
    equb &80, &80                       ; Target levels at the end of attack and decay: 128, 128
; OSWORD 7 (SOUND) parameter block for collecting an item.
.pickup_sound
    equw &10, &03, 10, 5                ; SOUND channel 0 (flush), envelope 3, pitch 10, duration 5
; OSWORD 8 (ENVELOPE) parameter block for picking up a key.
.key_envelope
    equb &03                            ; Envelope 3
    equb &80                            ; Step length 0 centiseconds, no auto-repeat
    equb &00, &00, &00                  ; Pitch change per step in sections 1-3: 0, 0, 0
    equb &01, &1e, &1e                  ; Steps in pitch sections 1-3: 1, 30, 30
    equb &80, &00, &00, &fe             ; Amplitude change per step in attack, decay, sustain, release: -128, 0, 0, -2
    equb &80, &80                       ; Target levels at the end of attack and decay: 128, 128
; OSWORD 7 (SOUND) parameter block for picking up a key.
.key_sound
    equw &12, &03, 240, 1               ; SOUND channel 2 (flush), envelope 3, pitch 240, duration 1
; OSWORD 8 (ENVELOPE) parameter block for a hero going down the exit.
.exit_envelope
    equb &03                            ; Envelope 3
    equb &82                            ; Step length 2 centiseconds, no auto-repeat
    equb &ff, &ff, &fe                  ; Pitch change per step in sections 1-3: -1, -1, -2
    equb &01, &01, &80                  ; Steps in pitch sections 1-3: 1, 1, 128
    equb &80, &00, &00, &ff             ; Amplitude change per step in attack, decay, sustain, release: -128, 0, 0, -1
    equb &80, &80                       ; Target levels at the end of attack and decay: 128, 128
; OSWORD 7 (SOUND) parameter block for a hero going down the exit.
.exit_sound
    equw &12, &03, 250, 1               ; SOUND channel 2 (flush), envelope 3, pitch 250, duration 1
    equb &00, &00, &00, &00, &04        ; Not referenced
    equs "50:50:$"
    equb &0c, &0c, &08, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &0a, &00, &00, &00
    equb &00, &14, &34, &38, &03, &03   ; Not referenced
    equs "4<:%"
    equb &0f, &0f, &0f, &1e, &31, &38, &03  ; Not referenced
    equs "48<"
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &04        ; Not referenced
    equs "5?:"
    equb &18, &3f, &3a, &0c, &0c, &08, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &35, &00                       ; Not referenced
; Data of sprite &08: 4 bytes x 12 rows.
; ***************************************************************************************
; Hero and death sprites
;
; Sprite &08, the Ranger facing left (second frame), then sprites &64-&68, the skulls of
; a hero's death animation, the last of which is left where the hero fell; 4 bytes by 12
; rows each.
.sprite_ranger_left_1
    equb &00, &01, &03, &00
    equb &01, &0b, &08, &00
    equb &01, &0e, &0c, &00
    equb &03, &06, &3c, &00
    equb &02, &03, &25, &28
    equb &02, &05, &0f, &3c
    equb &02, &05, &0f, &3c
    equb &02, &00, &25, &29
    equb &00, &00, &3c, &09
    equb &00, &0a, &0c, &09
    equb &00, &0e, &0c, &00
    equb &00, &04, &00, &00
; Data of sprite &64: 4 bytes x 12 rows.
.sprite_skull_0
    equb &00, &00, &00, &00
    equb &00, &3f, &00, &00
    equb &00, &00, &00, &00
    equb &15, &15, &2a, &2a
    equb &2a, &3f, &3f, &15
    equb &2a, &3f, &3f, &15
    equb &2a, &35, &3a, &15
    equb &2a, &15, &2a, &15
    equb &2a, &00, &00, &2a
    equb &2a, &00, &3f, &2a
    equb &15, &00, &00, &2a
    equb &15, &00, &00, &00
; Data of sprite &65: 4 bytes x 12 rows.
.sprite_skull_1
    equb &15, &2a, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &15, &15, &2a, &2a
    equb &2a, &3f, &3f, &2a
    equb &2a, &35, &3a, &15
    equb &2a, &35, &3a, &15
    equb &2a, &3f, &3f, &15
    equb &00, &00, &00, &00
    equb &00, &00, &00, &2a
    equb &2a, &00, &00, &2a
    equb &15, &15, &2a, &2a
; Data of sprite &66: 4 bytes x 12 rows.
.sprite_skull_2
    equb &00, &00, &00, &00
    equb &00, &2a, &00, &00
    equb &15, &00, &00, &00
    equb &2a, &3f, &3f, &00
    equb &00, &35, &35, &00
    equb &15, &35, &35, &00
    equb &15, &3f, &3f, &00
    equb &15, &3a, &20, &15
    equb &15, &00, &00, &15
    equb &00, &2a, &00, &3f
    equb &2a, &15, &15, &15
    equb &15, &00, &2a, &00
; Data of sprite &67: 4 bytes x 12 rows.
.sprite_skull_3
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &15, &00, &00
    equb &00, &3f, &2a, &00
    equb &00, &35, &20, &00
    equb &15, &35, &20, &2a
    equb &3f, &3f, &3f, &00
    equb &15, &3a, &2a, &15
    equb &15, &00, &00, &2a
    equb &15, &2a, &15, &00
    equb &15, &3f, &2a, &00
    equb &2a, &15, &3f, &2a
; Data of sprite &68: 4 bytes x 12 rows.
.sprite_skull_4
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &15, &3f, &00
    equb &00, &10, &3a, &00
    equb &00, &10, &3a, &00
    equb &00, &15, &3f, &15
    equb &2a, &3f, &35, &2a
    equb &15, &2a, &2a, &00
    equb &00, &3f, &3f, &2a
    equb &3f, &15, &2a, &15
; Low bytes of the sprite data addresses, indexed by sprite number (120 entries).
; ***************************************************************************************
; Sprite tables
;
; Four tables of 120 entries, indexed by sprite number: data address low bytes, high
; bytes, widths in bytes and heights in rows.
.sprite_addr_lo
    equb <wall_sprite, <sprite_ranger_up_0, <sprite_ranger_up_1, <sprite_ranger_right_0
    equb <sprite_ranger_right_1, <sprite_ranger_down_0, <sprite_ranger_down_1, <sprite_ranger_left_0
    equb <sprite_ranger_left_1, <sprite_monster_up_0, <sprite_monster_up_1, <sprite_monster_right_0
    equb <sprite_monster_right_1, <sprite_monster_down_0, <sprite_monster_down_1, <sprite_monster_left_0
    equb <sprite_monster_left_1, <sprite_arrow_up, <sprite_arrow_right, <sprite_arrow_down
    equb <sprite_arrow_left, <sprite_blank, <sprite_sparkle_0, <sprite_sparkle_1
    equb <sprite_sparkle_2, <sprite_sparkle_3, <sprite_blank, <sprite_key
    equb <sprite_door_vertical, <sprite_door_horizontal, <sprite_digit_0, <sprite_digit_1
    equb <sprite_digit_2, <sprite_digit_3, <sprite_digit_4, <sprite_digit_5
    equb <sprite_digit_6, <sprite_digit_7, <sprite_digit_8, <sprite_digit_9
    equb <sprite_treasure, <sprite_food, <sprite_cross, <sprite_teleporter
    equb <sprite_trapdoor, <sprite_magic_user_up_0, <sprite_magic_user_up_1, <sprite_magic_user_right_0
    equb <sprite_magic_user_right_1, <sprite_magic_user_down_0, <sprite_magic_user_down_1, <sprite_magic_user_left_0
    equb <sprite_magic_user_left_1, <sprite_barbarian_up_0, <sprite_barbarian_up_1, <sprite_barbarian_right_0
    equb <sprite_barbarian_right_1, <sprite_barbarian_down_0, <sprite_barbarian_down_1, <sprite_barbarian_left_0
    equb <sprite_barbarian_left_1, <sprite_fighter_up_0, <sprite_fighter_up_1, <sprite_fighter_right_0
    equb <sprite_fighter_right_1, <sprite_fighter_down_0, <sprite_fighter_down_1, <sprite_fighter_left_0
    equb <sprite_fighter_left_1, <sprite_fireball_up, <sprite_fireball_right, <sprite_fireball_down
    equb <sprite_fireball_left, <sprite_sword_up, <sprite_sword_right, <sprite_sword_down
    equb <sprite_sword_left, <sprite_axe_up, <sprite_axe_right, <sprite_axe_down
    equb <sprite_axe_left, <sprite_exit, <sprite_key_icon, <sprite_drainer
    equb <sprite_drainer, <sprite_drainer, <sprite_drainer, <sprite_drainer
    equb <sprite_drainer, <sprite_drainer, <sprite_drainer, <sprite_drainer
    equb <sprite_drainer, <sprite_drainer, <sprite_drainer, <sprite_boots
    equb <sprite_helmet, <sprite_potion, <sprite_weapons, <sprite_magic_sword
    equb <sprite_skull_0, <sprite_skull_1, <sprite_skull_2, <sprite_skull_3
    equb <sprite_skull_4, <sprite_shield, <sprite_small_digit_1, <sprite_small_digit_2
    equb <sprite_small_digit_3, <sprite_small_digit_4, <sprite_small_digit_5, <sprite_small_digit_6
    equb <sprite_small_digit_7, <sprite_small_digit_8, <sprite_small_digit_9, <sprite_chalice
    equb <sprite_missile_icon, <sprite_boots_icon, <sprite_level_word, <sprite_blank
; High bytes of the sprite data addresses, indexed by sprite number.
.sprite_addr_hi
    equb >wall_sprite, >sprite_ranger_up_0, >sprite_ranger_up_1, >sprite_ranger_right_0
    equb >sprite_ranger_right_1, >sprite_ranger_down_0, >sprite_ranger_down_1, >sprite_ranger_left_0
    equb >sprite_ranger_left_1, >sprite_monster_up_0, >sprite_monster_up_1, >sprite_monster_right_0
    equb >sprite_monster_right_1, >sprite_monster_down_0, >sprite_monster_down_1, >sprite_monster_left_0
    equb >sprite_monster_left_1, >sprite_arrow_up, >sprite_arrow_right, >sprite_arrow_down
    equb >sprite_arrow_left, >sprite_blank, >sprite_sparkle_0, >sprite_sparkle_1
    equb >sprite_sparkle_2, >sprite_sparkle_3, >sprite_blank, >sprite_key
    equb >sprite_door_vertical, >sprite_door_horizontal, >sprite_digit_0, >sprite_digit_1
    equb >sprite_digit_2, >sprite_digit_3, >sprite_digit_4, >sprite_digit_5
    equb >sprite_digit_6, >sprite_digit_7, >sprite_digit_8, >sprite_digit_9
    equb >sprite_treasure, >sprite_food, >sprite_cross, >sprite_teleporter
    equb >sprite_trapdoor, >sprite_magic_user_up_0, >sprite_magic_user_up_1, >sprite_magic_user_right_0
    equb >sprite_magic_user_right_1, >sprite_magic_user_down_0, >sprite_magic_user_down_1, >sprite_magic_user_left_0
    equb >sprite_magic_user_left_1, >sprite_barbarian_up_0, >sprite_barbarian_up_1, >sprite_barbarian_right_0
    equb >sprite_barbarian_right_1, >sprite_barbarian_down_0, >sprite_barbarian_down_1, >sprite_barbarian_left_0
    equb >sprite_barbarian_left_1, >sprite_fighter_up_0, >sprite_fighter_up_1, >sprite_fighter_right_0
    equb >sprite_fighter_right_1, >sprite_fighter_down_0, >sprite_fighter_down_1, >sprite_fighter_left_0
    equb >sprite_fighter_left_1, >sprite_fireball_up, >sprite_fireball_right, >sprite_fireball_down
    equb >sprite_fireball_left, >sprite_sword_up, >sprite_sword_right, >sprite_sword_down
    equb >sprite_sword_left, >sprite_axe_up, >sprite_axe_right, >sprite_axe_down
    equb >sprite_axe_left, >sprite_exit, >sprite_key_icon, >sprite_drainer
    equb >sprite_drainer, >sprite_drainer, >sprite_drainer, >sprite_drainer
    equb >sprite_drainer, >sprite_drainer, >sprite_drainer, >sprite_drainer
    equb >sprite_drainer, >sprite_drainer, >sprite_drainer, >sprite_boots
    equb >sprite_helmet, >sprite_potion, >sprite_weapons, >sprite_magic_sword
    equb >sprite_skull_0, >sprite_skull_1, >sprite_skull_2, >sprite_skull_3
    equb >sprite_skull_4, >sprite_shield, >sprite_small_digit_1, >sprite_small_digit_2
    equb >sprite_small_digit_3, >sprite_small_digit_4, >sprite_small_digit_5, >sprite_small_digit_6
    equb >sprite_small_digit_7, >sprite_small_digit_8, >sprite_small_digit_9, >sprite_chalice
    equb >sprite_missile_icon, >sprite_boots_icon, >sprite_level_word, >sprite_blank
; Sprite widths in screen bytes, indexed by sprite number.
.sprite_widths
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &02, &04, &04, &04, &02, &02
    equb &02, &02, &02, &02, &02, &02, &02, &02
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &02, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &04, &04, &04, &04, &04, &04, &04
    equb &04, &03, &01, &01, &01, &01, &01, &01
    equb &01, &01, &01, &08, &04, &02, &0c, &02
; Sprite heights in pixel rows, indexed by sprite number.
.sprite_heights
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &03, &0c, &0c, &0c, &0a, &0a
    equb &0a, &0a, &0a, &0a, &0a, &0a, &0a, &0a
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &03, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &0c, &0c, &0c, &0c, &0c, &0c
    equb &0c, &0c, &05, &05, &05, &05, &05, &05
    equb &05, &05, &05, &18, &03, &06, &08, &06
