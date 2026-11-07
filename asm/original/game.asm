; Dunjunz, official disc (Model B side): the game
;
; Annotated disassembly of the game file Dun1, which contains the level loader Coder.
;
; How Dun1 is laid out
;
; | In Dun1     | Runs at     | Contents                                                               |
; |-------------|-------------|------------------------------------------------------------------------|
; | &2000-&2FFF | in place    | The exit animation, drop_key, object_free_map, doors and keys, sprites |
; | &3000-&473F | &08C0-&1FFF | The game core, copied down by Coder                                    |
; | &5000-&51AF | in place    | coder_start (Coder), its commands and VDU tables                       |
; | &51B0-&55AF | &0400-&07FF | The keyboard-only image of page &04-&07                                |
; | &55B0-&59AF | &0400-&07FF | The same with joystick_bytev at &0780                                  |
; | &6E80-&7FFF | in place    | Heroes, missiles, objects, monsters, workspace_template, wrch_handler  |
;
; Coder is also a file of its own, Coder (&5000-&59AF), identical to those bytes of Dun1.
;
; Memory map in play
;
; | Range       | Contents                                                                                                                                                                                       |
; |-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
; | &0000-&03FF | Zero page, stack and MOS workspace; the game's zero page is &70-&8F; &0287 is the MOS BREAK intercept                                                                                          |
; | &0400-&07FF | One of the two images: score overflow, decrypt_level, the hero menu, remove_absent_heroes (and joystick_bytev)                                                                                 |
; | &08B0-&08BF | Page &08 state that survives the reset between levels: hero_score_ten_thousands, hero_absent, levels_started, level_digits                                                                     |
; | &08C0-&0CFF | plot_sprite, screen_address, per-hero tables and scores, room_walls at &0C00; copied only for the first level, so the heroes carry over                                                        |
; | &0D00-&1FFF | Page &0D's per-level workspace, game_entry, the level loop, the status panel, the victory sequence, start_level, check_level, the BREAK intercepts, the font, sprites, update_game, play_level |
; | &2000-&2FFF | The exit animation, doors and keys, sprites                                                                                                                                                    |
; | &3000-&6E7F | Screen (25 character rows in play); Dun1's stored copies lie here until the screen is cleared                                                                                                  |
; | &6B00-&6DAF | The level file, in the screen's bottom rows                                                                                                                                                    |
; | &6E80-&7FFF | Heroes, missiles, objects, monsters, workspace_template, wrch_handler                                                                                                                          |
;
; From power-on to play
;
; 1. Booted on a Model B, the other side's BOOT asks for the disc to be turned over and
;    runs *DUNJUNZ (its own listing). That sets page &08 (levels_started 0, level_digits
;    "0 ", every hero playing), shows the title screen, arms the BREAK intercept with a
;    JMP to &15B5 and runs *CODER with VDU output disabled.
; 2. coder_start (&5000) disables ESCAPE, cancels the BREAK intercept, counts the level
;    in levels_started and level_digits, and blanks the display. It *LOADs Dun1 (over
;    itself), then LEVELnn to &6B00, or for level 25 STONES, whose end is level 25. It
;    copies the keyboard image, or the joystick image if ADC channel 1 reads &80, to
;    &0400, and points BYTEV at joystick_bytev if a second read says so. It shows 23
;    rows, copies the game core (from &0D00 only, after the first level) and jumps to
;    game_entry at &0D31, leaving levels_started in level_count_copy (&8E).
; 3. game_entry sets the bell, saves WRCHV in saved_wrchv and points it at wrch_handler,
;    and sets level_number from &8E. On the first level it resets the heroes and runs
;    hero_menu; on later ones it goes straight to level_loop.
; 4. level_loop sets monster_start_hit_points from levels_started and calls start_level,
;    which runs steps 5 to 7.
; 5. clear_text_for_level clears rows 0-22 only, so the level file in rows 23-24
;    survives.
; 6. check_level decrypts the level and checks it against level_checksums (decrypt_level
;    resets the machine on a mismatch), then widens clear_text_area's window to all 25
;    rows.
; 7. unpack_level, reset_workspace and reset_monsters set up play; the screen is cleared
;    and set to 25 rows, and draw_view_frames draws the frames and the four views.
; 8. draw_status_panel and remove_absent_heroes finish the screen, and play_level runs
;    the level until no hero is left in play.
; 9. Every dead hero gets their starting attributes back. If any hero survived,
;    next_level_by_reset arms the BREAK intercept with a JMP to next_level_intercept and
;    resets the machine; on the intercept's second call, once the filing system is back,
;    it selects MODE 2 and runs *CODER again, which loads the next level (step 2). If all
;    four died, the game-over message is shown for up to 5.8 seconds or until a key, and
;    restart_by_reset resets the machine into restart_intercept, which runs *DUNJUNZ
;    (step 1). A hero reaching the Chalice on level 25 is caught by check_for_victory,
;    which plays victory_sequence, prints the ending message, waits for a key and resets
;    the machine through the RESET vector.

; Constants
spr_wall                             = &00  ; Sprite &00
spr_ranger_up_0                      = &01  ; Sprite &01
spr_monster_up_0                     = &09  ; Sprite &09
spr_monster_right_0                  = &0b  ; Sprite &0B
spr_monster_down_0                   = &0d  ; Sprite &0D
spr_monster_left_0                   = &0f  ; Sprite &0F
spr_arrow_up                         = &11  ; Sprite &11
spr_blank                            = &15  ; Sprite &15
spr_sparkle_0                        = &16  ; Sprite &16
spr_sparkle_3                        = &19  ; Sprite &19
spr_blank_key_icon                   = &1a  ; Sprite &1A
spr_key                              = &1b  ; Sprite &1B
spr_digit_0                          = &1e  ; Sprite &1E
spr_digit_3                          = &21  ; Sprite &21
spr_digit_9                          = &27  ; Sprite &27
spr_treasure                         = &28  ; Sprite &28
spr_food                             = &29  ; Sprite &29
spr_cross                            = &2a  ; Sprite &2A
spr_teleporter                       = &2b  ; Sprite &2B
spr_trapdoor                         = &2c  ; Sprite &2C
spr_magic_user_up_0                  = &2d  ; Sprite &2D
spr_barbarian_up_0                   = &35  ; Sprite &35
spr_fighter_up_0                     = &3d  ; Sprite &3D
spr_fireball_up                      = &45  ; Sprite &45
spr_sword_up                         = &49  ; Sprite &49
spr_axe_up                           = &4d  ; Sprite &4D
spr_exit                             = &51  ; Sprite &51
spr_key_icon                         = &52  ; Sprite &52
spr_drainer_0                        = &53  ; Sprite &53
spr_drainer_11                       = &5e  ; Sprite &5E
spr_boots                            = &5f  ; Sprite &5F
spr_helmet                           = &60  ; Sprite &60
spr_potion                           = &61  ; Sprite &61
spr_weapons                          = &62  ; Sprite &62
spr_shield                           = &69  ; Sprite &69
spr_small_digit_1                    = &6a  ; Sprite &6A
spr_small_digit_8                    = &71  ; Sprite &71
spr_small_digit_9                    = &72  ; Sprite &72
spr_chalice                          = &73  ; Sprite &73
spr_missile_icon                     = &74  ; Sprite &74
spr_boots_icon                       = &75  ; Sprite &75
spr_level_word                       = &76  ; Sprite &76
spr_blank_boots_icon                 = &77  ; Sprite &77
max_object                           = &1e  ; Objects are numbered 1 to 30
max_monster                          = &1e  ; Monsters are numbered 1 to 30
max_door                             = &14  ; Doors are numbered 1 to 20
max_key                              = &14  ; Keys are numbered 1 to 20; key n opens door n
screen_start                         = &3000  ; The start of screen memory, as the game programs the 6845
off_map                              = &ff  ; A map x or y that puts a door, key, object, monster or the exit off the map
nobody_returns                       = &64  ; A returning_hero_queue entry that brings nobody back
step_out_of_play                     = &63  ; hero_step of a hero out of play, never animated
view_right_column                    = &23  ; The screen byte column of the two right-hand views
view_bottom_row                      = &67  ; The pixel row of the two lower views
panel_left                           = &45  ; The status panel's leftmost screen byte column
level_file_end                       = &6db0  ; The end of the level file at &6B00
last_level                           = &19  ; The level with the Chalice
map_bytes                            = &c9  ; The length of the wall and object-free maps
chalice_x                            = &1a  ; Map x of the Chalice's left cells
chalice_y                            = &04  ; Map y of the Chalice's top cells
boot_osfile_block                    = &6b00  ; OSFILE control block built by boot_loader (in the level buffer)
coder_source                         = &70  ; Coder's copy source pointer (the game's plot_x, plot_y)
coder_dest                           = &72  ; Coder's copy destination pointer (the game's sprite_width, sprite_height)
core_offset                          = &80  ; Coder's offset into the game core, &0000 or &0440 (the game's ring_x, ring_y)
game_core_stored                     = &3000  ; Where Dun1 stores the game core, &08C0-&1FFF at run time
game_core_stored_end                 = &4740  ; The end of the stored game core
game_core_start                      = &08c0  ; Where the game core runs
keyboard_image_stored                = &51b0  ; Where Dun1 stores the keyboard-only &0400-&07FF image
joystick_image_stored                = &55b0  ; Where Dun1 stores the &0400-&07FF image with the joystick handler
low_image_start                      = &0400  ; Where either &0400-&07FF image runs
low_image_end                        = &0800  ; The end of the &0400-&07FF image
osbyte_bell_channel                  = &d3
osbyte_bell_envelope                 = &d4
osbyte_bell_frequency                = &d5
osbyte_bell_duration                 = &d6
osbyte_flush_buffer_class            = &0f
osbyte_inkey                         = &81
osword_envelope                      = &08
osword_sound                         = &07
osbyte_scan_keyboard_from_16         = &7a
osbyte_escape_break_effect           = &c8
osbyte_read_adc_or_get_buffer_status = &80
osbyte_kbd_status                    = &ca
osbyte_sound_suppression             = &d2
inkey_key_ctrl                       = &fe
inkey_key_return                     = &b6
inkey_key_caps_lock                  = &bf
inkey_key_right                      = &86
inkey_key_k                          = &b9
inkey_key_g                          = &ac
inkey_key_shift_lock                 = &af
inkey_key_up                         = &c6
inkey_key_comma                      = &99
inkey_key_b                          = &9b
inkey_key_z                          = &9e
inkey_key_copy                       = &96
inkey_key_slash                      = &97
inkey_key_i                          = &da
inkey_key_shift                      = &ff
inkey_key_delete                     = &a6
inkey_key_full_stop                  = &98
inkey_key_u                          = &ca
inkey_key_tab                        = &9f
inkey_key_down                       = &d6
inkey_key_space                      = &9d
inkey_key_o                          = &c9

; Memory locations
plot_x                   = &70  ; Sprite position: screen byte column, 0-79 (two MODE 2 pixels per byte). Also used as a scratch byte and pointer low byte by other routines.
; &70 referenced 57 times by &20c6, &30c4, &30d1, &36a8, &3b7c, &3c2c, &3c37, &3c3b, &44e6, &455c, &45b7, &51d2, &51e9, &51eb, &5202, &520a, &520c, &520e, &5215, &521b, &5357, &535b, &55d2, &55e9, &55eb, &5602, &560a, &560c, &560e, &5615, &561b, &5757, &575b, &726d, &7282, &72c6, &72db, &72eb, &72fb, &75b8, &75d9, &75e4, &75fb, &7823, &7846, &784a, &78a1, &78bb, &78d5, &78ef, &7f8f, &7f95, &7fc1, &7fcd, &7fe4, &7ff0, &7ffa
plot_y                   = &71  ; Sprite position: pixel row from the top of the screen. Also used as a pointer high byte by other routines.
; &71 referenced 32 times by &20c2, &30a7, &30bb, &36b7, &3b80, &44e2, &4558, &45b3, &51da, &5208, &5219, &5221, &55da, &5608, &5619, &5621, &7269, &72c2, &75b4, &75d5, &75ec, &7603, &7797, &77a9, &77bb, &77cd, &77ef, &77f3, &78a8, &78c2, &78dc, &78f6
sprite_width             = &72  ; Width of the sprite being plotted, in screen bytes.
; &72 referenced 10 times by &304f, &3067, &5204, &5211, &5213, &522a, &5604, &5611, &5613, &562a
sprite_height            = &73  ; Height of the sprite being plotted, in pixel rows.
; &73 referenced 2 times by &3054, &305b
screen_ptr               = &74  ; Screen address being written, low byte.
; &74 referenced 13 times by &305d, &306b, &306e, &3072, &3086, &308e, &3095, &3099, &30b9, &30bf, &30c1, &30d7, &30d9
screen_ptr_hi            = &75  ; Screen address being written, high byte.
; &75 referenced 9 times by &3061, &3076, &308c, &309b, &309f, &30b4, &30cd, &30cf, &30dd
row_start_ptr            = &76  ; Screen address of the first byte of the sprite row being plotted, low byte.
; &76 referenced 2 times by &305f, &3082
row_start_ptr_hi         = &77  ; Screen address of the first byte of the sprite row being plotted, high byte.
; &77 referenced 2 times by &3063, &3088
sprite_data_ptr          = &78  ; Address of the next sprite data byte to plot, low byte.
; &78 referenced 3 times by &3045, &3069, &3078
sprite_data_ptr_hi       = &79  ; Address of the next sprite data byte to plot, high byte.
; &79 referenced 2 times by &304a, &307c
sprite_number            = &7a  ; Sprite to plot: an index into the sprite tables at sprite_addr_lo, sprite_addr_hi, sprite_widths and sprite_heights.
; &7a referenced 46 times by &20ba, &3040, &36aa, &38e6, &393e, &446e, &44da, &450a, &4550, &4597, &45ab, &46a9, &46f5, &4711, &51ce, &51e3, &55ce, &55e3, &7077, &70a2, &70e9, &720f, &7242, &7272, &727e, &72cb, &72d7, &72e7, &72f7, &731c, &75c0, &75dd, &75f4, &7608, &760f, &7663, &767a, &7695, &76f5, &7813, &7836, &7840, &79cb, &79fb, &7b17, &7b50
map_ptr                  = &7b  ; Pointer into room_walls or object_free_map at a cell's room, low byte; set by test_wall and test_object_free.
; &7b referenced 21 times by &449b, &44a2, &44a4, &44c0, &44c5, &7046, &7542, &767f, &77a1, &77b3, &77c5, &77d7, &77e4, &790e, &7915, &7917, &792f, &794a, &7951, &7953, &796b
map_ptr_hi               = &7c  ; Pointer into a map, high byte.
; &7c referenced 4 times by &44a8, &77e0, &791b, &7957
plot_offset_x            = &7d  ; Horizontal offset added by plot_at_cell, in byte columns.
; &7d referenced 18 times by &3832, &4472, &4504, &459b, &46a3, &46e3, &4725, &7088, &70cc, &7307, &76ea, &7738, &780c, &787a, &79c5, &7a00, &7b1c, &7b55
plot_offset_y            = &7e  ; Vertical offset added by plot_at_cell, in pixel rows.
; &7e referenced 18 times by &3834, &4474, &4506, &459d, &46a5, &46e5, &472a, &708d, &70ce, &7309, &76ec, &773d, &780e, &788e, &79c7, &7a05, &7b21, &7b5a
ring_x                   = &80  ; Map x of the cell being drawn in the victory ring.
; &80 referenced 8 times by &388b, &3894, &3899, &38a6, &38bd, &38c2, &38ca, &38da
ring_y                   = &81  ; Map y of the cell being drawn in the victory ring.
; &81 referenced 7 times by &388f, &38ab, &38b0, &38b8, &38cf, &38d4, &38df
victory_sprite           = &82  ; Sprite drawn in the victory ring: a sparkle, &16-&19, or the blank, &15, to erase it.
; &82 referenced 6 times by &3838, &389e, &38e4, &38ec, &38fb, &3915
victory_delay            = &84  ; Wait between passes of the victory sequence, in units of 255 loops: &E6 at the start, one less each pass, down to 1.
; &84 referenced 5 times by &3840, &385c, &3862, &3873, &387c
victory_pitch_step       = &8d  ; Amount the victory tone's pitch rises each pass: 1 at the start, one more each time the pitch wraps past 255.
; &8d referenced 3 times by &3848, &384d, &3853
level_count_copy         = &8e  ; Copy of levels_started that coder_start leaves for game_entry, which makes it level_number. In play the game uses &8E for its own victory_steps_left.
; &8e referenced 2 times by &3844, &3855
victory_steps_left       = &8e  ; Copy of levels_started that coder_start leaves for game_entry, which makes it level_number. In play the game uses &8E for its own victory_steps_left.
; &8e referenced 2 times by &3844, &3855
victory_pitch            = &8f  ; Pitch of the bell in the victory sequence, set with OSBYTE &D5.
; &8f referenced 7 times by &34b0, &383c, &384b, &384f, &3864, &7934, &7970
os_zp_fa                 = &fa  ; MOS zero-page workspace, read by dissolve_chalice to vary its random choice.
; &fa referenced 1 time by &3903
os_irq_a                 = &fc  ; MOS 1.20: A at the last interrupt, read by dissolve_chalice to vary its random choice.
; &fc referenced 1 time by &3901
bytev                    = &020a
; &020a referenced 2 times by &50dd, &58f2
wrchv                    = &020e
; &020e referenced 4 times by &3495, &34a3, &3c1a, &3c47
filev                    = &0212
; &0212 referenced 2 times by &550e, &5918
os_vsync_counter         = &0240  ; MOS 1.20 counter decremented on every vertical sync interrupt. The game sets it and waits for it to run out to pace itself.
; &0240 referenced 7 times by &35a2, &35f9, &3929, &392c, &4630, &4640, &4647
os_break_intercept       = &0287  ; MOS BREAK intercept: if &0287 holds a JMP opcode the MOS jumps to &0287 twice during a reset, before and after the filing system is initialised (carry clear, then set).
; &0287 referenced 3 times by &3b9b, &3ba2, &5015
hero_score_ten_thousands = &08b0  ; Each hero's score ten-thousands digit as a small digit sprite (&69 for none, &6A-&72 for 1-9). reset_hero sets it to &69, and remove_absent_heroes redraws the digit from here under the score at each level.
; &08b0 used as index base 5 times by &3633, &5464, &546f, &5864, &586f
hero_absent              = &08b4  ; One flag per hero: 1 if switched off on the menu, 0 if playing. hero_menu toggles it with keys 1-4; remove_absent_heroes takes the absent heroes out of play at each level.
; &08b4 used as index base 8 times by &5360, &5365, &537b, &5479, &5760, &5765, &577b, &5879
levels_started           = &08bc  ; The level being played, 1-25, counted as levels started in this game. It lives in page &08, which survives the reset between levels: *DUNJUNZ sets it to 0 for a new game and coder_start adds one before loading each level. coder_start also reads it to choose Stones for level 25, to copy the whole game core only for level 1, and to pass it to game_entry in level_count_copy; game_entry and level_loop read it for the first-level test and the monsters' hit points.
; &08bc referenced 6 times by &34b5, &3554, &5018, &506f, &5074, &50fc
level_digits             = &08bd  ; The level number as ASCII digits for the level's filename: one digit and a space ("1 "-"9 "), or two digits ("10"-"25"). *DUNJUNZ sets "0 "; coder_start advances it before each level, in page &08 across the reset, and copies it into level_command_digits.
; &08bd referenced 5 times by &5031, &5036, &5039, &5042, &5063
mos_row_offsets          = &c375  ; MOS 1.20 table of screen row offsets for 640-byte rows (row x 640, high byte then low byte, one pair per character row). Read directly by screen_address; it is not part of any documented interface.
; &c375 used as index base 1 time by &30ae
mos_row_offsets_lo       = &c376  ; Low bytes of mos_row_offsets.
; &c376 used as index base 1 time by &30b6
mos_reset_entry          = &d9cd  ; MOS 1.20 reset entry, the target of the RESET vector. Called directly to reset the machine.
; &d9cd referenced 3 times by &3baf, &5231, &5631
mos_oswrch_default       = &e0a4  ; MOS 1.20 default OSWRCH routine, WRCHV's initial value. The WRCHV handler jumps here directly instead of through the saved vector.
; &e0a4 referenced 2 times by &7fd7, &7ffc
mos_osbyte_default       = &e772  ; MOS 1.20 default OSBYTE routine, BYTEV's initial value.
; &e772 referenced 2 times by &5948, &5999
system_via_t1c_l         = &fe44
; &fe44 referenced 3 times by &38fe, &7a6f, &7aac
osrdch                   = &ffe0
; &ffe0 referenced 3 times by &3817, &533f, &573f
osasci                   = &ffe3
; &ffe3 referenced 3 times by &35f1, &37fd, &380a
oswrch                   = &ffee
; &ffee referenced 63 times by &35c8, &35cd, &35d2, &35d7, &35dc, &35e1, &37dc, &37e1, &37e6, &37eb, &37f0, &37f5, &386d, &3b54, &3b59, &3b5e, &3b63, &3b68, &3b6b, &3b6e, &3b71, &3b74, &3b77, &3bb6, &3c27, &3c2e, &3cf9, &3cfe, &3d5c, &3d61, &3d66, &3d6b, &3d70, &3d75, &500b, &5010, &504f, &5059, &5094, &50e7, &50ec, &50f4, &52b2, &52b7, &52bc, &52c1, &52c6, &52cb, &52e0, &52e6, &52ed, &52f4, &56b2, &56b7, &56bc, &56c1, &56c6, &56cb, &56e0, &56e6, &56ed, &56f4, &6f47
osword                   = &fff1
; &fff1 referenced 15 times by &3de6, &3def, &4458, &45ed, &45f6, &736d, &7376, &73b9, &73e3, &748c, &74a9, &74b2, &7586, &7634, &763d
osbyte                   = &fff4
; &fff4 referenced 27 times by &3477, &3480, &3489, &3492, &3600, &3609, &3814, &382d, &3868, &4619, &4620, &4627, &5006, &50a7, &50d4, &5333, &533c, &539d, &5733, &573c, &579d, &594f, &595d, &596c, &597a, &5989, &7c9e
oscli                    = &fff7
; &fff7 referenced 7 times by &3bbd, &3bc4, &3d05, &3d0c, &5060, &5085, &508f
reset_vector             = &fffc  ; 6502 RESET vector, in the MOS ROM.
; &fffc referenced 1 time by &381a


    org &3000

; Move 1: &3000 to &08c0 for length 5952
    org &08c0
    equb &80, &05, &05, &05, &05, &05, &05, &80
    equb &00, &00, &f6, &80, &80, &00, &00, &00
    equb &01, &f6, &f6, &f6, &03, &03, &03, &64
    equb &fd, &00, &f9, &80, &14, &00, &00, &00
    equb &80, &00, &00, &00, &01, &1e, &1e, &80
    equb &00, &00, &fe, &80, &80, &00, &00, &00
    equb &01, &14, &0a, &05, &02, &02, &02, &01
    equb &00, &00, &ff, &80, &80, &00, &00, &00  ; Not referenced
; ***************************************************************************************
; Plot a sprite
;
; Copy sprite sprite_number to the screen with its top-left corner at byte column plot_x,
; pixel row plot_y.
;
; The four sprite tables, indexed by sprite number, give the address of its data and its
; size: sprite_width bytes across (two MODE 2 pixels to a byte) by sprite_height pixel
; rows. The data is stored row by row and is written over the screen contents without
; masking, so a sprite's black pixels erase what was there, and there is no clipping. The
; screen is laid out like MODE 2 with 640-byte character rows from &3000, so successive
; bytes of a sprite row are 8 bytes apart, and each pixel row starts one byte below the
; last, or 640-7 bytes on when it crosses into the next character row. screen_ptr walks
; across each row, row_start_ptr remembers where the row began, and sprite_data_ptr walks
; through the data; Y stays 0. sprite_width and sprite_height are left holding the
; sprite's size.
;
; On Entry:
;     PLOT_X: screen byte column (0-79)
;     PLOT_Y: pixel row
;     SPRITE_NUMBER: sprite to plot
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: 0
; &0900 referenced 22 times by &20ca, &36b9, &44ea, &4560, &45bd, &51de, &51ed, &55de, &55ed, &7276, &7286, &72cf, &72df, &72ef, &72ff, &7613, &7838, &7842, &78aa, &78c4, &78de, &78f8
.plot_sprite
    ldx sprite_number                   ; X = sprite number, indexing the four sprite tables
    lda sprite_addr_lo,x                ; Point sprite_data_ptr at the sprite's data...
    sta sprite_data_ptr                 ; ...its low byte from sprite_addr_lo
    lda sprite_addr_hi,x                ; ...high byte from its own table
    sta sprite_data_ptr_hi              ; ...so sprite_data_ptr walks through the data
    lda sprite_widths,x                 ; Bytes in each sprite row...
    sta sprite_width                    ; ...counted across each row
    lda sprite_heights,x                ; Pixel rows in the sprite...
    sta sprite_height                   ; ...counted down the sprite
    jsr screen_address                  ; screen_ptr = address of the top-left byte
    ldy #0                              ; Index stays 0: the pointers themselves advance
    ldx sprite_height                   ; X counts the pixel rows still to plot
; &091d referenced 1 time by &30a4
.plot_sprite_row
    lda screen_ptr                      ; Remember where this pixel row starts...
    sta row_start_ptr                   ; ...its low byte...
    lda screen_ptr_hi                   ; ...and its high byte...
    sta row_start_ptr_hi                ; ...in row_start_ptr, to step down from later
    txa                                 ; Save the row count
    pha                                 ; ...on the stack: X now counts bytes
    ldx sprite_width                    ; X counts the bytes across this row
; &0929 referenced 1 time by &307f
.plot_sprite_byte
    lda (sprite_data_ptr),y             ; Copy one sprite byte...
    sta (screen_ptr),y                  ; ...to the screen, over whatever was there
    clc                                 ; Step screen_ptr right one byte column: 8 bytes on
    lda screen_ptr                      ; ...the screen address's low byte...
    adc #8                              ; ...+ 8, the next byte column...
    sta screen_ptr                      ; ...as screen_ptr's new low byte
    bcc plot_sprite_next_data           ; No carry: the high byte stands
    inc screen_ptr_hi                   ; ...with carry into the high byte
; &0938 referenced 1 time by &3074
.plot_sprite_next_data
    inc sprite_data_ptr                 ; Next sprite data byte
    bne plot_sprite_count_byte          ; No carry: the high byte stands
    inc sprite_data_ptr_hi              ; ...with carry into the high byte
; &093e referenced 1 time by &307a
.plot_sprite_count_byte
    dex                                 ; One byte fewer left in this row
    bne plot_sprite_byte                ; More of the row: plot the next byte
    clc                                 ; screen_ptr = row start + 1: the next pixel row down
    lda row_start_ptr                   ; The row start's low byte...
    adc #1                              ; ...+ 1, one pixel row lower...
    sta screen_ptr                      ; ...is the new low byte
    lda row_start_ptr_hi                ; The row start's high byte...
    adc #0                              ; ...plus the carry...
    sta screen_ptr_hi                   ; ...is the new high byte
    lda screen_ptr                      ; Has it crossed into the next character row?
    and #7                              ; ...(pixel row within the character now 0)
    bne plot_sprite_next_row            ; No: still within the character row
    clc                                 ; Yes: add &278 more, to the top of the character...
    lda screen_ptr                      ; ...row below (row start + 1 + &278 = + 640 - 7)
    adc #&78 ; 'x'                      ; ...low byte + &78 (640 - 8 = &278)...
    sta screen_ptr                      ; ...as screen_ptr's low byte
    lda screen_ptr_hi                   ; ...then the high byte...
    adc #2                              ; ...+ 2 and the carry...
    sta screen_ptr_hi                   ; ...as screen_ptr's high byte: the row below
; &0961 referenced 1 time by &3092
.plot_sprite_next_row
    pla                                 ; Recover the row count
    tax                                 ; ...back into X
    dex                                 ; One pixel row fewer to plot
    bne plot_sprite_row                 ; More rows: plot the next
    rts                                 ; Return: the sprite is on the screen
; ***************************************************************************************
; Calculate a screen address
;
; Set screen_ptr to the screen address of byte column plot_x on pixel row plot_y: &3000 +
; 640 x (plot_y DIV 8) + (plot_y MOD 8) + 8 x plot_x. plot_sprite calls it once per
; sprite, for the top-left byte. The multiplication by 640 is done with a table inside
; MOS 1.20 (mos_row_offsets, two bytes per character row, high byte first), so this only
; works with that MOS. The high byte of 8 x plot_x is plot_x DIV 32, taken from plot_x's
; top three bits with four ROLs.
;
; On Entry:
;     PLOT_X: screen byte column (0-79)
;     PLOT_Y: pixel row
;
; On Exit:
;     SCREEN_PTR: screen address
;     A: corrupted
;     Y: corrupted
;     X: preserved
; &0967 referenced 1 time by &3056
.screen_address
    lda plot_y                          ; Table index = 2 x (plot_y DIV 8), the character row...
    lsr a                               ; ...plot_y DIV 2...
    lsr a                               ; ...plot_y DIV 4: 2 x the character row, + plot_y bit 2...
    and #&fe                            ; ...bit 0 cleared: the row's pair of table bytes
    tay                                 ; ...as the index into the row table
    lda mos_row_offsets,y               ; High byte of row x 640, from the MOS table...
    clc                                 ; ...(carry clear for the add)
    adc #>(screen_start)                ; ...plus &30: the screen starts at &3000
    sta screen_ptr_hi                   ; ...as the screen address high byte
    lda mos_row_offsets_lo,y            ; Low byte of row x 640
    sta screen_ptr                      ; ...as the low byte
    lda plot_y                          ; Add the pixel row within the character...
    and #7                              ; ...plot_y MOD 8...
    adc screen_ptr                      ; ...(carry clear: adding &30 to the high byte cannot carry)
    sta screen_ptr                      ; ...stored in the low byte
    clc                                 ; Add 8 x plot_x: its high byte is plot_x DIV 32...
    lda plot_x                          ; ...taking the byte column...
    and #&e0                            ; ...bits 7-5 kept...
    rol a                               ; ...four ROLs through the carry: bit 7 out...
    rol a                               ; ...bit 7 in at bit 0, bit 6 out
    rol a                               ; ...bits 7-6 at bits 1-0, bit 5 out
    rol a                               ; ...bits 7-5 now in bits 2-0
    clc                                 ; ...(carry clear for the add)
    adc screen_ptr_hi                   ; ...added to the high byte
    sta screen_ptr_hi                   ; ...as screen_ptr's high byte
    lda plot_x                          ; Low byte + (plot_x x 8) AND &FF: plot_x...
    asl a                               ; ...x 2...
    asl a                               ; ...x 4...
    asl a                               ; ...x 8, its top bits dropping out
    clc                                 ; ...(carry clear for the add)
    adc screen_ptr                      ; ...added to the low byte
    sta screen_ptr                      ; ...as screen_ptr's low byte
    bcc screen_address_done             ; No carry: done
    inc screen_ptr_hi                   ; ...with carry into the high byte
; &099f referenced 1 time by &30db
.screen_address_done
    rts                                 ; Return with screen_ptr set
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &ff, &ff, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Not referenced
; The exit's map x, kept while a hero goes down it.
; &09f0 referenced 4 times by &2026, &46ba, &46e7, &4713
.exit_saved_x
    equb &04
; The exit's map y, kept while a hero goes down it.
; &09f1 referenced 4 times by &202c, &46c0, &46ed, &4719
.exit_saved_y
    equb &2c
; Non-zero while a hero is going down the exit.
; &09f2 referenced 5 times by &2034, &2078, &3bed, &4650, &46d6
.exit_busy
    equb &00
; Direction (1, 3, 5, 7) of the hero spinning on the exit.
; &09f3 referenced 5 times by &2086, &46fe, &4703, &470e, &4734
.exit_spin
    equb &ff
; Spins left before the hero has gone (4 to 1).
; &09f4 referenced 3 times by &208b, &471f, &4737
.exit_shrinks_left
    equb &00
; The hero going down the exit.
; &09f5 referenced 3 times by &207e, &46de, &46fa
.exiting_hero
    equb &03
; &09f6 referenced 1 time by &2042; also used as index base 1 time by &4722
.exit_offsets_x
    equb &04
; exit_offsets_x entry 1.
; &09f7 referenced 1 time by &3bfe
.exit_offset_x_1
    equb &01
; exit_offsets_x entry 2.
; &09f8 referenced 1 time by &3c01
.exit_offset_x_2
    equb &01
; exit_offsets_x entry 3.
; &09f9 referenced 1 time by &3bf0
.exit_offset_x_3
    equb &00
; Vertical offset of the shrinking hero, in pixel rows, entries 1-4 by exit_shrinks_left (at exit_offsets_y+1 to +4). Also entry 4 of exit_offsets_x.
; &09fa referenced 1 time by &3bf3; also used as index base 1 time by &4727
.exit_offsets_y
    equb &00
; exit_offsets_y entry 1.
; &09fb referenced 1 time by &3c0e
.exit_offset_y_1
    equb &05
; exit_offsets_y entry 2.
; &09fc referenced 1 time by &3c13
.exit_offset_y_2
    equb &03
; exit_offsets_y entry 3.
; &09fd referenced 1 time by &3c04
.exit_offset_y_3
    equb &01
; exit_offsets_y entry 4.
; &09fe referenced 1 time by &3bf6
.exit_offset_y_4
    equb &00
; The hero whose sprites are shrunk, or &FF.
; &09ff referenced 4 times by &2045, &2081, &3c09, &466d
.shrunk_hero
    equb &ff
; Data of sprite &5F: 4 bytes x 12 rows.
.sprite_boots
    equb &00, &00, &00, &00
    equb &00, &00, &00, &15
    equb &00, &00, &00, &3f
    equb &00, &00, &00, &3f
    equb &00, &01, &13, &2a
    equb &00, &01, &13, &2a
    equb &00, &01, &13, &00
    equb &00, &03, &13, &00
    equb &03, &03, &33, &00
    equb &03, &03, &33, &00
    equb &03, &03, &33, &00
    equb &00, &00, &00, &00
; Data of sprite &60: 4 bytes x 12 rows.
.sprite_helmet
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &2a, &3c, &22, &2a
    equb &2a, &3c, &22, &2a
    equb &2a, &3c, &22, &2a
    equb &14, &14, &11, &00
    equb &14, &00, &11, &00
    equb &14, &28, &39, &00
    equb &14, &3c, &33, &00
    equb &14, &3c, &33, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
; Data of sprite &61: 4 bytes x 12 rows.
.sprite_potion
    equb &00, &00, &00, &00
    equb &00, &01, &02, &00
    equb &00, &15, &2a, &00
    equb &00, &05, &02, &00
    equb &00, &05, &02, &00
    equb &00, &05, &02, &00
    equb &00, &05, &02, &00
    equb &00, &0f, &03, &00
    equb &05, &0f, &0b, &02
    equb &05, &0f, &0b, &02
    equb &05, &0f, &03, &02
    equb &00, &0f, &03, &00
; Data of sprite &63: 4 bytes x 12 rows.
.sprite_magic_sword
    equb &00, &00, &00, &00
    equb &00, &54, &00, &54
    equb &00, &00, &00, &00
    equb &54, &00, &04, &00
    equb &00, &00, &04, &00
    equb &3f, &3f, &2e, &0c
    equb &15, &3f, &2e, &00
    equb &00, &00, &04, &54
    equb &a8, &00, &00, &00
    equb &00, &54, &00, &00
    equb &00, &00, &00, &a8
    equb &00, &00, &00, &00
; Data of sprite &62: 4 bytes x 12 rows.
.sprite_weapons
    equb &2a, &00, &00, &02
    equb &05, &00, &00, &02
    equb &00, &0a, &15, &01
    equb &00, &04, &1d, &01
    equb &01, &04, &15, &01
    equb &05, &00, &15, &01
    equb &05, &00, &15, &02
    equb &05, &00, &15, &02
    equb &00, &15, &15, &00
    equb &02, &2a, &33, &22
    equb &01, &00, &11, &00
    equb &02, &02, &11, &00
; Data of sprite &2A: 4 bytes x 12 rows.
.sprite_cross
    equb &00, &0f, &02, &00
    equb &00, &0f, &02, &00
    equb &00, &1f, &02, &00
    equb &3f, &1f, &0f, &02
    equb &0f, &1f, &0f, &02
    equb &0f, &1f, &0f, &02
    equb &00, &0f, &02, &00
    equb &00, &0f, &02, &00
    equb &00, &2f, &02, &00
    equb &00, &2f, &02, &00
    equb &00, &0f, &02, &00
    equb &00, &0f, &02, &00
; Number of missiles each hero may have in flight at once, 1-3 (raised by a pile of weapons).
; &0b20 used as index base 9 times by &3612, &366b, &3670, &6f22, &751a, &751d, &7526, &75c5, &75ca
.hero_max_missiles
    equb &03, &02, &01, &03
; INKEY key numbers of the magic keys of heroes 0 and 1, the only heroes with magic.
; &0b24 used as index base 1 time by &7624
.hero_magic_key
    equb inkey_key_ctrl, inkey_key_return
; Frames until heroes 0 and 1 next check their magic key.
; &0b26 used as index base 3 times by &7619, &7621, &7644
.hero_magic_delay
    equb &01, &01
; Monsters killed by the magic being cast, each worth a point.
; &0b28 referenced 3 times by &765e, &768f, &7699
.magic_kill_count
    equb &00, &10
; Queue of heroes waiting to come back: each entry is a hero number plus 1, or &64 for a slot that brings nobody back; 0 ends the queue. A Cross of Resurrection takes the first entry.
; &0b2a referenced 3 times by &7421, &742b, &7432; also used as index base 7 times by &3cdc, &3df4, &3dfb, &549c, &589c, &7256, &725f
.returning_hero_queue
    equb &03
; &0b2b referenced 2 times by &742f, &7438
    equb &02                            ; Queue entry 1
; &0b2c referenced 2 times by &7435, &743e
    equb &01                            ; Queue entry 2
; &0b2d referenced 2 times by &743b, &7441
    equb &04                            ; Queue entry 3
    equb &10                            ; Queue entry 4
; Index (0-7) of the trapdoor from which the next monster emerges.
; &0b2f referenced 5 times by &3bf9, &7cb3, &7cb6, &7cbf, &7cc2
.next_trapdoor
    equb &04
; Sprites of a hero dying, in order (sparkles &16-&19, then skulls &64-&68, ending as the skull left where the hero fell), or returning, in reverse.
; &0b30 used as index base 1 time by &76f2
.hero_appearance_sprites
    equb &16, &17, &18, &19
    equs "defgh"
    equb &10, &10, &10, &10, &10, &10, &10  ; Not referenced
; Hit points left for each monster (entries 1-30); a hit subtracts the missile's damage.
; &0b40 used as index base 4 times by &3cd2, &758d, &759e, &75a6
.monster_hit_points
    equb &10, &08, &08, &08, &08, &08, &08, &08
    equb &08, &08, &08, &08, &08, &08, &08, &05
    equb &08, &08, &08, &08, &08, &08, &08, &08
    equb &08, &08, &08, &08, &08, &08, &08, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
; Damage each hero's missiles do, 1-9 (raised by a magic sword).
; &0b70 used as index base 7 times by &3618, &3690, &6f4a, &756b, &756e, &7577, &75ee
.hero_missile_damage
    equb &02, &03, &09, &03, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
; Damage each missile in flight will do (12 slots, three per hero).
; &0b80 used as index base 3 times by &6f4d, &71f0, &7591
.missile_damage
    equb &02, &02, &02, &03, &03, &04, &09, &09
    equb &10, &03, &03, &03, &10, &10, &10
; &0b8f used as index base 1 time by &79cd
    equb &10                            ; Not referenced
; Map x of the level's eight trapdoors, from the level file.
; &0b90 used as index base 2 times by &3c94, &7cc5
.trapdoor_x
    equb &0b
    equb &15                            ; Trapdoor 2's x
    equb &17                            ; Trapdoor 3's x
    equb &10                            ; Trapdoor 4's x
    equb &03                            ; Trapdoor 5's x
    equb &17                            ; Trapdoor 6's x
    equb &0d                            ; Trapdoor 7's x
; &0b97 used as index base 1 time by &79d3
    equb &1a                            ; Trapdoor 8's x
; Map y of the level's eight trapdoors, from the level file.
; &0b98 used as index base 2 times by &3c9a, &7ccb
.trapdoor_y
    equb &04
    equb &0c                            ; Trapdoor 2's y
    equb &14                            ; Trapdoor 3's y
    equb &1d                            ; Trapdoor 4's y
    equb &25                            ; Trapdoor 5's y
    equb &20                            ; Trapdoor 6's y
    equb &28                            ; Trapdoor 7's y
    equb &2c                            ; Trapdoor 8's y
; Score hundreds digit, as a digit sprite (&1E-&27 for 0-9).
; &0ba0 used as index base 5 times by &3626, &72aa, &72ad, &72b6, &72d4
.hero_score_hundreds
    equb &1e, &1e, &1e, &1e
; Score tens digit, as a digit sprite.
; &0ba4 used as index base 5 times by &3629, &729b, &729e, &72a7, &72e4
.hero_score_tens
    equb &1e, &1e, &1e, &1e
; Score units digit, as a digit sprite.
; &0ba8 used as index base 8 times by &362e, &5492, &5892, &728c, &728f, &7298, &72f4, &74cf
.hero_score_units
    equb &1d, &1d, &1d, &1d
; Score thousands digit, as a digit sprite.
; &0bac used as index base 8 times by &3623, &51b0, &51b3, &51bc, &55b0, &55b3, &55bc, &72c8
.hero_score_thousands
    equb &1e, &1e, &1e, &1e, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10
; OSWORD 7 (SOUND) parameter block for teleporting.
.teleport_sound
    equw &13, &04, 100, 30              ; SOUND channel 3 (flush), envelope 4, pitch 100, duration 30
; OSWORD 7 (SOUND) parameter block for eating food, and (with its pitch changed) opening a door.
.food_sound
; &333c referenced 2 times by &444f, &445d
    equw &13, &02, 200, 2               ; SOUND channel 3 (flush), envelope 2, pitch 200, duration 2
; The level's wall map, from the level file: eight bytes per room, one per row of cells, one bit per cell (bit 7 at the left). Rooms are 8x8 cells and run four to a row of the map. The first eight bytes are also the MOS 1.20 definition of character 128, which the WRCHV handler overwrites with each glyph it prints; the level is unpacked only after the level number has been printed.
; &0c00 used as index base 3 times by &3ca7, &7fc8, &7feb
.room_walls
    equb &54, &49, &4b, &50, &24, &55, &54, &48, &4f, &5b, &4b, &46, &2c, &44, &5d, &2f  ; Not read: unpack_level copies each level's wall map here
    equb &44, &59, &57, &33, &43, &5a, &44, &5c, &38, &56, &5c, &3b, &56, &48, &52, &56  ; ...entries 16-31, not read
    equb &61, &6f, &02, &62, &72, &6c, &75, &07, &00, &6a, &03, &0b, &1d, &14, &16, &19  ; ...entries 32-47, not read
    equb &10, &70, &67, &74, &61, &66, &62, &19, &71, &19, &72, &7a, &6a, &78, &1e, &78  ; ...entries 48-63, not read
    equb &09, &17, &07, &0d, &64, &0b, &09, &05, &07, &0d, &13, &6b, &1c, &08, &1c, &02  ; ...entries 64-79, not read
    equb &19, &02, &01, &1a, &1b, &1b, &76, &03, &17, &79, &17, &1a, &0e, &16, &1b, &0b  ; ...entries 80-95, not read
    equb &40, &35, &2a, &2a, &37, &45, &21, &26, &25, &2c, &4a, &32, &29, &39, &4e, &2e  ; ...entries 96-111, not read
    equb &3e, &35, &52, &32, &3a, &2c, &56, &38, &36, &3c, &5a, &29, &39, &3c, &3a, &36  ; ...entries 112-127, not read
    equb &ce, &c6, &a2, &d7, &cc, &cc, &d5, &a7, &c1, &da, &aa, &ca, &ac, &cb, &a4, &a5  ; ...entries 128-143, not read
    equb &ba, &bb, &b8, &d4, &b4, &d7, &bc, &bd, &b2, &b3, &b0, &df, &bc, &d4, &d8, &bf  ; ...entries 144-159, not read
    equb &f4, &e9, &e7, &fa, &84, &e4, &f4, &e2, &88, &ea, &e5, &e5, &ff, &e4, &ea, &ea  ; ...entries 160-175, not read
    equb &e2, &f8, &fc, &f4, &94, &f0, &e4, &f6, &eb, &f0, &f4, &fc, &9c, &e9, &f6, &f6  ; ...entries 176-191, not read
    equb &93, &e1, &8f, &86, &97, &96, &87, &80, &8d  ; ...entries 192-200, not read
    equb &e7, &9e, &83, &8d, &83, &85, &90  ; Not referenced
; Health each hero loses when a monster touches it, 3-9 (lowered by a magic helmet). The status panel shows 10 minus this as the armour rating.
; &0cd0 used as index base 7 times by &361e, &365e, &74ef, &74f2, &74f9, &75bd, &79a7
.hero_damage_taken
    equb &89, &9e, &87, &f3, &95, &9b, &92, &f7
    equb &90, &98, &8a, &8b, &85, &fd, &9a, &8a
    equb &ae, &a6, &a7, &ac, &aa, &ac, &a8, &a0
    equb &c9, &00, &00, &00, &00, &00, &00, &00
; OSWORD 7 (SOUND) parameter block for a monster hit, and (louder) touching an energy drainer.
.hit_sound
; &3434 referenced 2 times by &7481, &7491
    equw &10, &01, 6, 6                 ; SOUND channel 0 (flush), envelope 1, pitch 6, duration 6
    equb &12, &00, &03, &00, &c8, &00, &0a, &00  ; Not referenced
; General-purpose scratch byte.
; &0d00 referenced 49 times by &2006, &200d, &201e, &205a, &2063, &2070, &4405, &4440, &448e, &4492, &4495, &4498, &44b7, &44c2, &6f19, &6f1e, &6f25, &6f71, &6fd7, &7002, &7007, &713c, &74b6, &74c3, &74d8, &77e6, &782c, &7857, &785b, &785e, &7861, &7886, &788b, &7901, &7905, &7908, &790b, &7926, &7931, &793d, &7941, &7944, &7947, &7962, &796d, &7976, &7990, &7a89, &7ce3; also used as index base 1 time by &3be5
.scratch
    equb &a9
; Second scratch byte.
; &0d01 referenced 8 times by &203a, &207b, &74d2, &7503, &7509, &750c, &7829, &782f
.scratch2
    equb &30
; Map x of the cell being drawn, tested or moved to. plot_at_cell replaces it with the pixel offset within the room.
; &0d02 referenced 59 times by &2094, &20a7, &20de, &20e9, &20fa, &38dc, &3934, &440b, &441b, &4466, &447c, &449d, &44ac, &4511, &4578, &4588, &4698, &46ea, &4716, &6fa7, &700f, &707c, &70aa, &70ee, &7120, &715b, &7176, &71e3, &7310, &732c, &733a, &73f0, &752f, &766a, &777d, &779b, &77ad, &77bf, &77d1, &7801, &7820, &7867, &7872, &787c, &789e, &78b8, &78d2, &78ec, &7910, &791d, &794c, &7959, &797b, &7997, &79d0, &79ea, &7a48, &7b07, &7b44
.cell_x
    equb &8d
; Map y of the cell being drawn, tested or moved to. plot_at_cell replaces it with the pixel offset within the room.
; &0d03 referenced 55 times by &209a, &20ad, &20d0, &20db, &20ec, &20f7, &38e1, &3939, &4411, &4426, &4460, &4482, &4489, &44ba, &4517, &457e, &4590, &469e, &46f0, &471c, &6fad, &7017, &7082, &70b0, &70f4, &7126, &7161, &717e, &71eb, &7316, &7332, &7345, &73fc, &7535, &7670, &7783, &7807, &7852, &787f, &7890, &78a5, &78bf, &78d9, &78f3, &78fc, &7929, &7938, &7965, &7983, &799f, &79d6, &79f3, &7a4e, &7b0d, &7b4a
.cell_y
    equb &bd
; Room of the cell being drawn, as an offset into room_walls.
; &0d04 referenced 7 times by &7864, &786c, &786f, &7896, &78b0, &78ca, &78e4
.cell_room
    equb &08, &a9
; Map x of the creature being moved, before the move.
; &0d06 referenced 11 times by &6e9a, &6f56, &6fbb, &6fe5, &7021, &7069, &7079, &79ed, &7a58, &7a95, &7af8
.previous_x
    equb &20
; Map y of the creature being moved, before the move.
; &0d07 referenced 11 times by &6ea0, &6f5c, &6fc1, &6feb, &7027, &706f, &707f, &79f6, &7a5e, &7a9b, &7afe
.previous_y
    equb &8d
; Pixel offset of the hero being moved, before the move.
; &0d08 referenced 2 times by &6ea6, &7085
.previous_offset_x
    equb &be
; Pixel offset of the hero being moved, before the move.
; &0d09 referenced 2 times by &6eac, &708a
.previous_offset_y
    equb &08, &a9, &00, &8d, &bc, &08, &ea
; Map x of each hero.
; &0d10 used as index base 30 times by &2091, &453d, &4575, &45c9, &4678, &4695, &46b4, &5497, &5897, &6e97, &6f39, &6f59, &6f87, &6f95, &6f98, &6fa4, &6fbe, &6fe8, &700c, &7024, &706c, &70a7, &71e0, &7329, &73ed, &752c, &777a, &799a, &7bbd, &7bcb
.hero_x
    equb &4c, &10, &0d, &0d, &a2
; Map y of each hero.
; &0d15 used as index base 27 times by &2097, &4543, &457b, &45cf, &4680, &469b, &6e9d, &6f3f, &6f5f, &6f80, &6f8e, &6f9e, &6faa, &6fc4, &6fee, &7014, &702a, &7072, &70ad, &71e8, &732f, &73f9, &7532, &7780, &79a2, &7bb6, &7bc4
.hero_y
    equb &80, &a0, &0d, &a9
; &0d19 used as index base 1 time by &4657
    equb &00                            ; Not read: page &0D is refreshed from workspace_template
; Direction each hero faces: 1 up, 3 right, 5 down, 7 left; 0 when the hero is not in play.
; &0d1a used as index base 19 times by &4526, &4692, &5480, &5880, &6e82, &6ecb, &6ede, &6ef1, &6f04, &6f2d, &6f79, &701c, &7097, &7221, &7249, &7452, &7711, &7b67, &7baf
.hero_direction
    equb &8d
    equb &84                            ; Hero 1's direction
    equb &0d                            ; Hero 2's direction
    equb &8d, &85                       ; Hero 3's direction
; &0d1f used as index base 1 time by &4663
    equb &0d                            ; Not read: page &0D is refreshed from workspace_template
; Animation frame of each hero (0 or 1), added to its sprite.
; &0d20 referenced 2 times by &774e, &7753; also used as index base 13 times by &4533, &548a, &588a, &6f62, &6f67, &709c, &7457, &76ee, &76ff, &771f, &772e, &7ba2, &7ba7
.hero_frame
    equb &ad
; &0d21 referenced 2 times by &775b, &7760
    equb &12                            ; Hero 1's frame
; &0d22 referenced 2 times by &7768, &776d
    equb &02                            ; Hero 2's frame
; &0d23 referenced 2 times by &7771, &7776
    equb &8d, &2f                       ; Hero 3's frame
; Frames left in each hero's step between cells.
; &0d25 used as index base 13 times by &468d, &5485, &5885, &6e87, &6eaf, &6fc9, &6ff3, &702f, &7063, &7401, &7716, &7b64, &7baa
.hero_step
    equb &0d, &ad, &13, &02, &8d
; Each hero's horizontal pixel offset while between cells.
; &0d2a used as index base 19 times by &6ea3, &6fcc, &6ff6, &7032, &705d, &724e, &7404, &745c, &7702, &7719, &7735, &7b70, &7b84, &7b8e, &7b9e, &7bd0, &7bd7, &7bda, &7bdd
.hero_offset_x
    equb &30, &0d, &a9, &06, &20, &ee
; Each hero's vertical pixel offset while between cells.
; &0d30 used as index base 20 times by &6ea9, &6fcf, &6ff9, &7035, &7060, &7251, &7407, &7461, &76da, &76e2, &771c, &773a, &7b75, &7b7f, &7b93, &7b99, &7bd3, &7be1, &7be4, &7be7
.hero_offset_y
    equb &ff
; ***************************************************************************************
; Start the game
;
; The game's entry point, where the release's loader jumps once the game is in memory. It
; prepares the two MOS services the game leans on:
;
; First the bell (the BEL character's channel, envelope, pitch and duration, through
; OSBYTEs &D3-&D6): the bell is what sounds when a hero fires, and the victory sequence
; raises its pitch.
;
; Then the text: save the MOS's WRCHV in saved_wrchv, for draw_view_frames to put back
; while it sends the view frames' PLOT commands, and point WRCHV at wrch_handler, so that
; all the game's text is printed in its own font.
;
; This code lives in the per-level workspace: from &0D40 its bytes are the missile tables
; and other workspace in page &0D, which reset_workspace overwrites from
; workspace_template at the start of every level, so it can run only before the first
; level after the game is loaded. It does not return; what follows &0D6A, starting the
; game, is the release's own.
; &0d31 referenced 1 time by &5149
.game_entry
    lda #osbyte_bell_channel            ; OSBYTE &D3: bell channel...
    ldx #&11                            ; ...&11: channel 1, with SOUND's flush bit set
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: the firing bell sounds on channel 1  osbyte: bell channel
    lda #osbyte_bell_envelope           ; OSBYTE &D4: bell envelope...
    ldx #0                              ; ...0, a fixed amplitude
    ldy #0                              ; Y = 0: replace the setting with X
; Map x of each missile (12 slots, three per hero).
; &0d40 used as index base 6 times by &6f3c, &70eb, &710c, &711a, &711d, &7158
.missile_x
    jsr osbyte                          ; Set it: BEL plays at a fixed amplitude  osbyte: bell envelope
    lda #osbyte_bell_frequency          ; OSBYTE &D5: bell pitch...
    ldx #&64 ; 'd'                      ; ...&64, SOUND pitch 100
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: BEL plays at pitch &64  osbyte: bell frequency
; Map y of each missile.
; &0d4c used as index base 6 times by &6f42, &70f1, &7105, &7113, &7123, &715e
.missile_y
    lda #osbyte_bell_duration           ; OSBYTE &D6: bell duration...
    ldx #1                              ; ...1, in twentieths of a second
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Set it: BEL lasts a twentieth of a second  osbyte: bell duration
    lda wrchv                           ; Save the MOS's WRCHV...
; Direction of each missile: 1 up, 2 right, 3 down, 4 left; bit 7 set for a missile just fired; 0 for an empty slot.
; &0d58 used as index base 12 times by &6f28, &6f36, &70d2, &70de, &70fe, &7134, &71a5, &71ae, &71ba, &71c6, &71ce, &720c
.missile_direction
    sta saved_wrchv                     ; ...its low byte into saved_wrchv...
    lda wrchv + 1                       ; ...and its high byte...
    sta saved_wrchv + 1                 ; ...in saved_wrchv, for drawing the view frames
    lda #<(wrch_handler)                ; Point WRCHV at wrch_handler, the game's font...
.set_wrchv_low
; &34a4 used as index base 4 times by &6f53, &7209, &76b1, &7747
; Sprite base of each missile, to which its direction is added; also identifies the hero who fired it.
missile_sprite_base = set_wrchv_low+1
    sta wrchv                           ; ...into WRCHV's low byte...
    lda #>(wrch_handler)                ; ...and wrch_handler's high byte...
    sta wrchv + 1                       ; ...into WRCHV's: text now goes through it
; Take the level number from Coder, and start a new game on the first level, or go straight to the level on later ones, the heroes having carried over in &08C0-&0CFF.
    lda level_count_copy                ; levels_started, which Coder left in &8E...
    sta level_number                    ; ...is level_number, 1-25, for the checksum and Chalice
; INKEY key number of each hero's up key.
; &0d70 used as index base 1 time by &6ec1
.hero_key_up
    lda victory_pitch                   ; Copy &8F, which Coder does not set...
.store_level_bcd
; &34b4 used as index base 1 time by &6ed4
; INKEY key number of each hero's down key.
hero_key_down = store_level_bcd+2
    sta level_bcd                       ; ...into level_bcd, which nothing here reads
    lda levels_started                  ; First level of a game?
; INKEY key number of each hero's right key.
; &0d78 used as index base 1 time by &6ee7
.hero_key_right
    cmp #1                              ; ...levels_started 1, the first level of a game?
    beq start_new_game                  ; Yes: reset the heroes and run the hero menu
; INKEY key number of each hero's left key.
; &0d7c used as index base 1 time by &6efa
.hero_key_left
    jmp level_loop                      ; No: the heroes carry over; straight to the level
; &0d7f referenced 1 time by &34ba
.start_new_game
; &34c0 used as index base 1 time by &6f0d
; INKEY key number of each hero's fire key.
hero_key_fire = start_new_game+1
    lda #0                              ; A = 0, for new_game_reset_heroes' first hero
    jmp new_game_reset_heroes           ; ...past the stores that zero the level counts
    equs "eon5"
    equb &0d, &18, &bd, &04, &0d, &69, &03  ; Not referenced
; &0d8f used as index base 1 time by &465c
    equb &9d                            ; Not referenced
; Health tens digit, as a digit sprite (&1E-&27); &1D when the hero is dead.
; &0d90 used as index base 11 times by &35ad, &548f, &588f, &7236, &7239, &726f, &738e, &7391, &739a, &7506, &7724
.hero_health_tens
    equb &1d
    equb &1d                            ; Hero 1's health tens
    equb &1d                            ; Hero 2's health tens
    equb &1d, &d0                       ; Hero 3's health tens
; Health units digit, as a digit sprite.
; &0d95 used as index base 7 times by &7227, &722a, &7233, &727b, &739d, &750f, &7727
.hero_health_units
    equs "''''"
    equb &18, &bd, &08, &0d, &6d, &40, &0d  ; Not referenced
; The room each hero's view shows: a pointer into room_walls, low byte then high byte, for each hero in turn (hero x at view_room + 2x).
; &0da0 referenced 2 times by &779e, &7893; also used as index base 3 times by &7043, &7544, &767c
.view_room
    equb &18
    equb &0c                            ; Hero 0's view room, high byte
; &0da2 referenced 2 times by &77b0, &78ad
    equb &68                            ; Hero 1's view room, low byte
    equb &0c                            ; Hero 1's view room, high byte
; &0da4 referenced 2 times by &77c2, &78c7
    equb &28                            ; Hero 2's view room, low byte
    equb &0c                            ; Hero 2's view room, high byte
; &0da6 referenced 2 times by &77d4, &78e1
    equb &30                            ; Hero 3's view room, low byte
    equb &0c, &00, &00, &bd, &04, &0d, &85, &71
    equb &8a                            ; Hero 3's view room, high byte
; Sprite base of each hero's missiles: arrows, fireballs, axes, swords.
; &0db0 used as index base 1 time by &6f50
.hero_missile_sprites
    equb &10
    equs "DLHh"
; Sprite base of each hero, to which direction and frame are added.
; &0db5 used as index base 4 times by &2051, &470b, &473d, &709f
.hero_sprites
    equb &00
    equs ",4<"
    equb &00, &0d, &d9                  ; Not referenced
; Non-zero while the hero wears Boots of Speed.
; &0dbc used as index base 3 times by &7056, &7351, &74e7
.hero_has_boots
    equb &00, &00, &00, &00
; Bit masks for the cells of a room row, left to right: &80, &40 ... &01.
; &0dc0 used as index base 3 times by &44b2, &7923, &795f
.bit_masks
    equb &80, &40, &20, &10, &08, &04, &02, &01
    equb &b9, &30, &0d, &9d, &08, &0d, &4c, &d4
; Pixel row of each hero's section of the status panel.
; &0dd0 used as index base 10 times by &20bc, &44dc, &4552, &45ad, &7266, &72bd, &75af, &75cf, &75e7, &75fe
.hero_panel_y
    equb &0e, &3c, &6a, &98, &e8, &e0, &04, &d0
    equb &0a, &a2, &00, &ad, &40, &0d, &49, &01
    equb &8d, &40, &0d, &8e, &ff, &0d, &68, &a8
    equb &68, &aa
    equs "h(`"
    equb &de, &dd, &df, &f0, &f2, &f1, &f3, &f8
    equb &fa, &f9, &fb, &f4, &f6, &f5, &f7, &fc  ; Not referenced
; Index of the last object to search when looking backwards for a teleporter (&1E, from workspace_template).
; &0dfd referenced 1 time by &73d3
.teleport_last
    equb &1e, &fd
; Written by draw_victory_ring; not read.
; &0dff referenced 1 time by &38a0
.victory_sprite_copy
    equb &00, &a9, &00, &8d, &9f, &16, &8d, &ff
    equb &16
; &0e08 referenced 1 time by &34c1
.new_game_reset_heroes
    tax                                 ; Give each hero their starting attributes and score
; &0e09 referenced 1 time by &354f
.reset_each_hero
    jsr reset_hero                      ; Reset hero X: starting attributes, score 0000
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four done?
    bne reset_each_hero                 ; No: reset the next
    jsr hero_menu                       ; Then the players choose heroes and sound
; The level loop: Coder has already loaded this level, so set the monsters' strength and start it. The leftover code after the JMP, which would count the level and build a filename, is never run.
; &0e14 referenced 1 time by &34bc
.level_loop
    lda levels_started                  ; Monster hit points = 6 + 2 x levels started...
    asl a                               ; ...2 x levels started...
    clc                                 ; ...ready to add...
    adc #6                              ; ...+ 6: 8 on level 1, 56 on level 25
    sta monster_start_hit_points        ; ...for every monster on this level
    jmp play_this_level                 ; Start the level Coder has loaded
    equb &ff, &16, &69, &01, &8d, &ff, &16, &d8
    equb &ad, &9f, &16, &c9, &09, &b0, &04, &a2
    equb &00, &f0, &02, &a2, &01, &ad, &ff, &16
    equb &29, &0f, &18, &69, '0', &9d, &d5, &16
    equb &e0, &00, &f0, &0d             ; Not referenced
; &0e45 referenced 1 time by &35c4
.to_next_level
    jmp next_level_by_reset             ; A hero survived: reset the machine and run Coder
    equs "JJJJ"
    equb &18, &69, '0', &8d, &d5, &16, &a9, &0d
    equb &9d, &d6, &16                  ; Not referenced
; Set the level up on the screen and play it: the level itself, the status panel, the absent heroes taken out, then play_level until no hero is left in play.
; &0e57 referenced 1 time by &355e
.play_this_level
    jsr start_level                     ; Load and draw the level
    jsr draw_status_panel               ; Draw every hero's panel section
    jsr remove_absent_heroes            ; Take out the heroes nobody plays
    lda #1                              ; Vsync count 1: play_level's first wait is two vsyncs
    sta os_vsync_counter                ; ...counted down at each vertical sync
    jsr play_level                      ; Play until no hero is left in play
; The level is over. Reset every hero who died, and end the game if all four did.
    ldx #0                              ; Count the dead, giving each their starting attributes
    stx count                           ; ...none dead so far
; &0e6d referenced 1 time by &35bd
.check_hero_dead
    lda hero_health_tens,x              ; Dead (heroes nobody plays count as dead)?
    cmp #spr_digit_0 - 1                ; ...health tens one below 0?
    bne next_hero_dead                  ; No: survived, so not reset
    jsr reset_hero                      ; Yes: start them afresh on the next level
    inc count                           ; ...and count them
; &0e7a referenced 1 time by &35b2
.next_hero_dead
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four checked?
    bne check_hero_dead                 ; No: next hero
    lda count                           ; Any hero survived?
    cmp #4                              ; ...fewer than four dead?
    bne to_next_level                   ; Yes: on to the next level
; Every hero is dead: print the game-over message over the views, then wait for a key, or for the time limit, before starting again. The MOS goes on counting the vsync counter down at every vertical sync, so if it has passed 0 by the time the message is printed, the wait for it to reach 0 lasts until it comes round, up to 256 vsyncs (about 5 s), and only then are keys flushed and read.
    lda #&1c                            ; All dead: VDU 28,0,24,16,0, a window over the views...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
    lda #&18                            ; Bottom row 24
    jsr oswrch                          ; Send the bottom row
    lda #&10                            ; Right column 16, short of the status panel
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Send VDU 12: clear the window
    ldx #4                              ; Spaces over &0FF1-&0FF4, two of them the counters
    lda #&20 ; ' '                      ; ...the space to write
; &0ea8 referenced 1 time by &35ec
.restore_message_spaces
    sta panel_hero - 1,x                ; ...into each (&0FF1 held YOU ALL's full stop)
    dex                                 ; Next byte down
    bne restore_message_spaces          ; Until all four are spaces
; &0eae referenced 1 time by &35f7
.print_game_over
    lda game_over_message,x             ; Print game_over_message from its start (X = 0)...
    jsr osasci                          ; ...through OSASCI, so each CR starts a new line
    inx                                 ; Step to the message's next character
    cmp #0                              ; ...up to its zero byte
    bne print_game_over                 ; Not the end: next
; &0eb9 referenced 1 time by &35fc
.wait_vsync_game_over
    lda os_vsync_counter                ; Wait for the vsync counter, still running, to reach 0
    bne wait_vsync_game_over            ; Not yet: keep waiting
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard keys pressed during play  Flush selected class of buffer
    ldx #&46 ; 'F'                      ; Game over: wait up to &246 cs (5.8 s) for a key...
    ldy #2                              ; ...Y = &02: the time limit's high byte
    lda #osbyte_inkey                   ; ...OSBYTE &81: INKEY with a time limit
    jsr osbyte                          ; Read a key, waiting up to 582 centiseconds
    jmp restart_by_reset                ; ...then reset and reload the game with *DUNJUNZ
; ***************************************************************************************
; Give a hero their starting attributes
;
; Undo everything hero X has gained: set their missile limit, missile damage and health
; lost per hit (hero_max_missiles, hero_missile_damage, hero_damage_taken) from the
; starting tables at &0F80, and their score to 0000 with no ten-thousands digit. It is
; called for every hero when a game starts, and by level_loop for each hero who died (or
; was not playing) when a level ends, so a dead hero comes back on the next level as new,
; while survivors keep their scores and the gains from objects. Health and position are
; not set here: reset_workspace restores those for every hero at each level. The units
; digit is set one below 0 because draw_status_panel draws the score by adding a point.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &0ecf referenced 2 times by &3549, &35b4
.reset_hero
    lda hero_start_max_missiles,x       ; Starting missile limit...
    sta hero_max_missiles,x             ; ...as hero X's missile limit
    lda hero_start_missile_damage,x     ; Starting missile damage...
    sta hero_missile_damage,x           ; ...as their missile damage
    lda hero_start_damage_taken,x       ; Starting health lost per hit (armour)...
    sta hero_damage_taken,x             ; ...as their health lost per hit
    lda #spr_digit_0                    ; Score 0000: digit sprite 0...
    sta hero_score_thousands,x          ; ...as the thousands digit...
    sta hero_score_hundreds,x           ; ...the hundreds digit...
    sta hero_score_tens,x               ; ...and the tens digit
    lda #spr_digit_0 - 1                ; ...units one below 0: draw_status_panel adds a point
    sta hero_score_units,x              ; ...as the units digit
    lda #spr_small_digit_1 - 1          ; No ten-thousands digit (&69, one below small 1)
    sta hero_score_ten_thousands,x      ; ...as the ten-thousands digit
    rts                                 ; Return, X still the hero
; ***************************************************************************************
; Draw the status panel
;
; Draw each hero's section of the status panel, the column to the right of the views,
; Ranger at the top to Fighter at the bottom. level_loop calls it once per level, after
; start_level has drawn the fresh screen and before remove_absent_heroes.
;
; The health and score are drawn by the routines play uses to change them:
; lose_health_point takes a point from the template's health of 99 + 1, so every hero
; starts every level on 99, and add_point adds one to the score, which a hero just reset
; has one below 0000. So a hero who survived the last level, and kept their score, gains
; a point here at every new level. Then, through plot_panel_sprite, which places each
; sprite relative to the hero's panel row (hero_panel_y): the face and the shield on the
; section's top row, with the armour rating (10 - health lost per hit) as a small digit
; on the shield; the missile damage as a small digit; and one missile icon per missile
; allowed in flight, three rows apart, beside the health. The keys, the boots icon and
; the ten-thousands digit are drawn elsewhere. panel_hero is the hero being drawn; count
; holds the icons' end row.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &0ef7 referenced 1 time by &359a
.draw_status_panel
    lda #0                              ; For each hero's section...
    sta panel_hero                      ; ...starting with the Ranger's, at the top
; Health and score first, drawn by the routines that change them in play.
; &0efc referenced 1 time by &36a5
.draw_panel_hero
    ldx panel_hero                      ; X = this hero
    jsr lose_health_point               ; Take a point from the template's 99 + 1: draws 99
    jsr add_point                       ; Add a point: draws the score (0000 if just reset)
; The section's top row: the hero's face and the shield, with the armour rating on the shield.
    lda hero_faces,x                    ; The hero's face (their facing-down sprite)...
    ldx #panel_left                     ; ...at column &45, the panel's left...
    ldy #0                              ; ...on the section's top row...
    jsr plot_panel_sprite               ; ...plotted at the section's top left
    ldx #panel_left + 8                 ; Shield at column &4D, the section's top right
    ldy #0                              ; ...on the top row...
    lda #spr_shield                     ; ...the shield sprite...
    jsr plot_panel_sprite               ; ...plotted, for the armour rating to go on
    ldx panel_hero                      ; Armour rating on the shield: 10 - health lost per hit
    sec                                 ; ...(no borrow into the subtract)
    lda #spr_small_digit_1 + 9          ; ...from &73, small digit 1 + 9...
    sbc hero_damage_taken,x             ; ...less the damage per hit
    ldx #panel_left + 9                 ; ...at column &4E...
    ldy #2                              ; ...2 rows down the section...
    jsr plot_panel_sprite               ; ...plotted on the shield
; One missile icon per missile the hero may have in flight, three rows apart from row &10.
    ldx panel_hero                      ; Icon rows run from &10 to &10 + 3 x missile limit...
    lda hero_max_missiles,x             ; ...the hero's missile limit, 1-3 at the start...
    asl a                               ; ...x 2...
    clc                                 ; ...(carry clear for the add)
    adc hero_max_missiles,x             ; ...+ limit: 3 rows per icon...
    adc #&10                            ; ...+ &10: the row after the last icon
    sta count                           ; ...(end row in count)
    ldy #&10                            ; ...first icon at row &10, beside the health
; &0f3a referenced 1 time by &368b
.draw_missile_icons
    tya                                 ; Keep the row...
    pha                                 ; ...on the stack
    ldx #panel_left + 6                 ; ...at column &4B
    lda #spr_missile_icon               ; ...the missile icon...
    jsr plot_panel_sprite               ; ...plotted at row Y
    pla                                 ; Recover the row...
    clc                                 ; ...(carry clear for the add)
    adc #3                              ; ...3 rows down...
    tay                                 ; ...for the next icon
    cpy count                           ; Past the last icon's row?
    bcc draw_missile_icons              ; No: plot another
; The damage the hero's missiles do, then on to the next hero's section.
    ldx panel_hero                      ; Missile damage as a small digit, above the icons
    lda hero_missile_damage,x           ; ...the hero's missile damage...
    clc                                 ; ...(carry clear for the add)
    adc #spr_small_digit_1 - 1          ; ...+ &69: small digit 1 for damage 1
    ldx #panel_left + 7                 ; ...at column &4C...
    ldy #&0a                            ; ...&0A rows down, four above the health...
    jsr plot_panel_sprite               ; ...plotted: the damage each missile does
    inc panel_hero                      ; Next hero's section
    lda panel_hero                      ; All four heroes drawn?
    cmp #4                              ; ...(four of them)
    bne draw_panel_hero                 ; No: the next hero
    rts                                 ; Return: all four sections drawn
; ***************************************************************************************
; Plot a sprite in a hero's panel section
;
; Plot sprite A at byte column X and pixel row Y + hero_panel_y - 14 for the hero
; panel_hero, the one draw_status_panel is drawing. Row 0 of a section is thus 14 rows
; above the health digits, which sit at the panel row itself. The panel row is read from
; workspace_template, whose copy in page &0D, made by reset_workspace, is hero_panel_y.
;
; On Entry:
;     A: sprite number
;     X: byte column
;     Y: row within the hero's panel section
;     PANEL_HERO: hero whose section it is (0-3)
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: 0
; &0f68 referenced 5 times by &364c, &3655, &3665, &3680, &369a
.plot_panel_sprite
    stx plot_x                          ; Byte column from X
    sta sprite_number                   ; Sprite from A
    tya                                 ; Row = Y + this hero's panel row - 14...
    ldx panel_hero                      ; ...for the hero being drawn...
    clc                                 ; ...(carry clear for the add)
    adc workspace_template + 208,x      ; ...(read from workspace_template, which page &0D copies)
    sec                                 ; ...(no borrow into the subtract)
    sbc #&0e                            ; ...less 14: row 0 is 14 above the health
    sta plot_y                          ; ...is the plot row
    jsr plot_sprite                     ; Plot the sprite in the hero's section
    rts                                 ; Return; plot_sprite leaves X and Y 0
    equb &00, &09, &60                  ; Not referenced
; Starting hero_max_missiles for each hero: 3, 2, 1, 2.
; ***************************************************************************************
; Heroes' starting attributes
;
; Four tables of one byte per hero (Ranger, Magic-User, Barbarian, Fighter): missiles in
; flight, missile damage, health lost per hit, and the face sprite for the panel.
; &0f80 used as index base 1 time by &360f
.hero_start_max_missiles
    equb &03, &02, &01, &02
; Starting hero_missile_damage for each hero: 2, 3, 9, 5.
; &0f84 used as index base 1 time by &3615
.hero_start_missile_damage
    equb &02, &03, &09, &05
; Starting hero_damage_taken for each hero: 7, 9, 6, 4 (armour ratings 3, 1, 4, 6).
; &0f88 used as index base 1 time by &361b
.hero_start_damage_taken
    equb &07, &09, &06, &04
; Sprite shown for each hero at the top left of their status panel section, plotted by draw_status_panel: &05, &31, &39, &41.
; &0f8c used as index base 1 time by &3645
.hero_faces
    equb &05, &31, &39, &41
; ***************************************************************************************
; Game-over message
;
; Eleven lines of seventeen characters, each ended by a carriage return, then a line feed
; and a last line ended by a zero byte. Two bytes of it (&0FF1, &0FF2) double as
; counters, and are overwritten with spaces before printing, so the full stop after "YOU
; ALL" never appears.
; The message printed when every hero has died, terminated by a zero byte.
; &0f90 used as index base 1 time by &35ee
.game_over_message
    equs "FAREWELL!        ", &0d
    equs "THE QUEST HAS    ", &0d
    equs "FAILED AND THE   ", &0d
    equs "GODS ARE IN NO   ", &0d
    equs "MOOD TO RESURRECT", &0d
; The "YOU ALL." line of game_over_message, whose bytes after the text double as panel_hero and count.
.game_over_you_all
; &3730 used as index base 1 time by &35e8
; &3731 referenced 8 times by &3639, &363c, &3658, &3668, &368d, &369d, &36a0, &36ad
; Hero counter for draw_status_panel. It is the full stop of game_over_message's "YOU ALL.", which is overwritten with a space before the message is printed.
panel_hero = game_over_you_all+7
; &3732 referenced 5 times by &35aa, &35b7, &35bf, &3675, &3688
; Counter, used for the dead heroes at the end of a level and the rows of missile icons. It is a byte of game_over_message.
count = game_over_you_all+8
    equs "YOU ALL.         ", &0d
    equs "NEW ADVENTURERS  ", &0d
    equs "MUST TAKE YOUR   ", &0d
    equs "PLACE,BEGINNING  ", &0d
    equs "BACK ON THE UPPER", &0d
    equs "MOST LEVEL.      ", &0d
    equb &0a                            ; Line feed: a blank line
    equs "FIND THE CHALICE!", &00
; ***************************************************************************************
; Unused
;
; Leftover bytes: "ND!" and a zero, the end of an earlier message, then "&C2".
    equb &4e, &44, &21, &00, &26, &43, &32  ; Not referenced
; ***************************************************************************************
; Check whether the Chalice has been found
;
; End the game in victory when a hero reaches the Chalice. Called by play_level first in
; every frame, before update_game. On levels other than 25 return at once. On level 25,
; test each hero's hero_door_x, hero_door_y, the cell move_heroes recorded as the one
; they last stepped or tried to step into (kept even when a wall stops them, so walking
; into the Chalice is enough). If it is one of the Chalice's four cells, x &1A-&1B and y
; 4-5, the game is won: play victory_sequence, set a text window over the views (columns
; 0-16, rows 0-24, leaving the status panel), clear it, print the ending text, flush the
; keyboard buffer, wait for a key and call the MOS's reset code through the RESET vector,
; so this never returns.
;
; The ending text is not part of the program: it is the 140 bytes at room_walls + &3A
; followed by the zero-terminated string at object_free_map + &3A, which on level 25 hold
; text instead of map data. Both lie clear of &0C00-&0C07, the definition of character
; 128 that wrch_handler rewrites for every letter or digit it prints. The Chalice's cells
; are fixed here, not read from the level's objects.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
; &1070 referenced 1 time by &464a
.check_for_victory
    lda level_number                    ; Which level is this?
    cmp #last_level                     ; The Chalice lies only on level 25
    bne no_victory                      ; Another level: no Chalice to find
    ldx #0                              ; Has a hero reached a Chalice cell, x &1A-&1B, y 4-5?
; &1079 referenced 1 time by &37c7
.check_door_x
    lda hero_door_x,x                   ; The cell hero X last stepped or bumped into...
    cmp #chalice_x                      ; ...in the Chalice's left column?
    beq check_door_y                    ; Yes: check the row
    cmp #chalice_x + 1                  ; ...or its right column?
    beq check_door_y                    ; Yes: check the row
; &1084 referenced 1 time by &37d5
.next_hero_victory
    inx                                 ; Not at the Chalice: on to the next hero
    cpx #4                              ; Past hero 3?
    bne check_door_x                    ; No: check the next hero
; &1089 referenced 1 time by &37b5
.no_victory
    rts                                 ; No hero at the Chalice: on with the frame
; &108a referenced 2 times by &37be, &37c2
.check_door_y
    lda hero_door_y,x                   ; ...and that cell's row...
    cmp #chalice_y                      ; ...in the Chalice's top row?
    beq start_victory                   ; Yes: the Chalice is found
    cmp #chalice_y + 1                  ; ...or its bottom row?
    beq start_victory                   ; Yes: the Chalice is found
    bne next_hero_victory               ; No: next hero
; &1097 referenced 2 times by &37cf, &37d3
.start_victory
    jsr victory_sequence                ; Sparkles, rising tone, the Chalice dissolves
; The game is won. Over the views, print the ending text that level 25's maps hold, wait for a key, and reset.
    lda #&1c                            ; VDU 28,0,24,16,0: a window over the four views...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
    lda #&18                            ; Bottom row 24, the last on show
    jsr oswrch                          ; Send the bottom row
    lda #&10                            ; Right column 16: the status panel stays
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Clear the views for the ending text
; Print the ending text: 140 bytes of level 25's wall map, then its object-free map up to a zero.
    ldx #0                              ; The ending text: 140 bytes from room_walls + &3A...
; &10ba referenced 1 time by &3803
.print_victory_text
    lda room_walls + 58,x               ; Next byte of level 25's wall map, which is text
    jsr osasci                          ; Print it in the game's font
    inx                                 ; On through the 140 bytes
    cpx #&8c                            ; All 140 printed?
    bne print_victory_text              ; No: print the next
    ldx #0                              ; ...then the ending message, at object_free_map + &3A
; &10c7 referenced 1 time by &3810
.print_ending_message
    lda object_free_map + 58,x          ; Next character of the ending message
    jsr osasci                          ; Print it, the zero included
    inx                                 ; On along the message (X stays non-zero)
    cmp #0                              ; The zero that ends the message?
    bne print_ending_message            ; No: print the next
; Wait for a fresh key press, then reset the machine through the RESET vector.
    lda #osbyte_flush_buffer_class      ; OSBYTE &0F, X non-zero: flush the input buffer...
    jsr osbyte                          ; ...so keys pressed in the sequence cannot skip the text  Flush selected class of buffer
    jsr osrdch                          ; Wait for a key once the ending text has been read
    lda reset_vector                    ; Aim the JSR below at the MOS's reset code...
    sta reset_call_address              ; ...the RESET vector's low byte as its operand's...
    lda reset_vector + 1                ; ...and the vector's high byte...
    sta reset_call_address + 1          ; ...as its high: no MOS address built in
.reset_call
; &3827 referenced 1 time by &381d
; Operand of the JSR at reset_call, set from the RESET vector.
reset_call_address = reset_call+1
; &3828 referenced 1 time by &3823
    jsr &00                             ; ...and call it: the game ends with a reset
; ***************************************************************************************
; Play the victory sequence
;
; Sparkles circle the Chalice to a rising, quickening bell tone, and the Chalice
; dissolves into black. Called by check_for_victory once a hero reaches the Chalice; play
; is frozen meanwhile, as nothing else runs.
;
; Each pass sounds the bell, draws the ring of sparkles round the Chalice
; (draw_victory_ring), and waits. The bell's pitch climbs by a step each pass and wraps
; past 255, and each time it wraps the step grows by 1, so the tone repeats as ever
; faster sweeps: about 256 x (1 + 1/2 + ... + 1/50), some 1,150 passes in all. The wait
; starts at &E6 units of about 1,280 cycles each and shortens by one a pass down to 1,
; reached on pass 229, near the end of the first sweep; from then on each pass also calls
; dissolve_chalice, which clears a random byte of the Chalice when its random value is
; below &C0. After the 50th wrap (erase_victory_ring), erase the ring, clear whatever is
; left of the Chalice's sprite, replot it black, and wait 255 vertical syncs, about five
; seconds. The Chalice's sprite data stays cleared, as the game resets next.
;
; OSBYTEs &D4 and &D5 set (old AND Y) EOR X, and Y is never set for them: the bell's
; envelope byte takes Y left over from the frame, and the first pitch takes the Y that
; OSBYTE &D4 returns; later passes have Y = 0 from the wait loop, so the pitch is exactly
; victory_pitch.
;
; On Exit:
;     A: 0
;     X: corrupted
;     Y: corrupted
; &10e9 referenced 1 time by &37d7
.victory_sequence
    lda #osbyte_bell_envelope           ; OSBYTE &D4: the bell's envelope byte...
    ldx #8                              ; ...EOR 8; Y, not set, is the AND mask
    jsr osbyte                          ; Set the bell's envelope for the victory tone  osbyte: bell envelope
; Set up the sequence: no pixel offsets, the first sparkle, pitch 0 rising by 1, a wait of &E6, 50 sweeps.
    lda #0                              ; Plot the ring and Chalice square on their cells:
    sta plot_offset_x                   ; ...no x offset...
    sta plot_offset_y                   ; ...and no y offset
    lda #spr_sparkle_0                  ; The ring starts with the first sparkle
    sta victory_sprite                  ; ...as the ring's sprite
    lda #0                              ; Tone starts at pitch 0...
    sta victory_pitch                   ; ...for the bell
    lda #&e6                            ; ...with the passes &E6 wait units apart...
    sta victory_delay                   ; ...the delay loop's outer count
    lda #&32 ; '2'                      ; ...for &32 (50) sweeps of the pitch...
    sta victory_steps_left              ; ...counted down as the pitch wraps
    lda #1                              ; ...rising by 1 a pass in the first sweep
    sta victory_pitch_step              ; ...the pitch's first step
; One pass of the sequence: raise the pitch, shorten the wait, sound the bell, draw the ring, dissolve a byte of the Chalice once at full speed, and wait.
; &110a referenced 1 time by &3886
.raise_victory_pitch
    clc                                 ; Pitch = (pitch + step) mod 256, C set on a wrap...
    lda victory_pitch                   ; ...the bell's current pitch...
    adc victory_pitch_step              ; ...plus this sweep's step...
    sta victory_pitch                   ; ...stored as the pitch for this pass
    bcc shorten_victory_delay           ; No wrap: the sweep goes on
    inc victory_pitch_step              ; Wrapped: the next sweep climbs one step faster...
    dec victory_steps_left              ; ...and one fewer sweep is left
    bne shorten_victory_delay           ; Sweeps left: go on
    jmp erase_victory_ring              ; 50 sweeps done: erase the ring and the Chalice
; &111c referenced 2 times by &3851, &3857
.shorten_victory_delay
    dec victory_delay                   ; Shorten the wait: the passes come faster...
    bne sound_victory_bell              ; Not yet zero: keep it
    lda #1                              ; ...but never below 1...
    sta victory_delay                   ; ...the full speed the rest of the sequence runs at
; &1124 referenced 1 time by &385e
.sound_victory_bell
    ldx victory_pitch                   ; OSBYTE &D5: the bell's pitch...
    lda #osbyte_bell_frequency          ; ...set it from victory_pitch
    jsr osbyte                          ; Set it: the bell now sounds at that pitch  osbyte: bell frequency
    lda #7                              ; ...and sound the bell
    jsr oswrch                          ; Send BEL: the bell sounds at the new pitch
    jsr draw_victory_ring               ; Draw the ring, the sparkles one side further round
    lda victory_delay                   ; At full speed, dissolve the Chalice a byte at a time
    cmp #1                              ; Delay down to 1: the sequence is at full speed
    bne victory_delay_loop              ; Not yet: just wait
    jsr dissolve_chalice                ; Full speed: clear one more byte of the Chalice
; &113c referenced 1 time by &3877
.victory_delay_loop
    ldx victory_delay                   ; Wait victory_delay units before the next pass
; &113e referenced 1 time by &3884
.victory_delay_outer
    ldy #&ff                            ; Each unit is 255 inner loops, about 1,280 cycles
; &1140 referenced 1 time by &3881
.victory_delay_inner
    dey                                 ; Count down the inner loop
    bne victory_delay_inner             ; Until it reaches zero
    dex                                 ; Count down the delay units
    bne victory_delay_outer             ; Until the delay is spent (Y = 0 for the next OSBYTE)
    jmp raise_victory_pitch             ; Next pass: raise the pitch again
; ***************************************************************************************
; Draw the ring of sprites round the Chalice
;
; Draw one frame of the sparkling ring. Called by victory_sequence once a pass, and once
; more with the blank sprite to erase the ring. Plot victory_sprite at the twelve cells
; round the Chalice's 2 x 2 block (x &19-&1C, y 3-6, all in the Chalice's room), from x
; &1C, y 3 leftwards along the top, down the left side, along the bottom and up the right
; side, three cells to a side, each corner starting a side. The sprite moves on to the
; next sparkle (next_victory_sprite) after each of the first three sides and is left at
; the fourth side's, so the next ring starts with it and the sparkles move one side round
; the ring each pass. With the blank sprite, it erases the ring.
;
; On Entry:
;     VICTORY_SPRITE: the sprite for the top side
;
; On Exit:
;     VICTORY_SPRITE: the sprite of the right side
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &1149 referenced 2 times by &3870, &3917
.draw_victory_ring
    lda #chalice_x + 2                  ; Start at x &1C, y 3: the ring runs round the Chalice's four cells
    sta ring_x                          ; ...as the ring's x...
    lda #chalice_y - 1                  ; ...one row above the Chalice...
    sta ring_y                          ; ...as the ring's y
    jsr plot_victory_sprite             ; Plot the top-right corner, first of the top side
    dec ring_x                          ; Left to x &1B, above the Chalice's right column
    jsr plot_victory_sprite             ; Plot the top side's second cell
    dec ring_x                          ; Left to x &1A, above its left column
    jsr plot_victory_sprite             ; Plot the last of the top side's three
    lda victory_sprite                  ; Keep the sprite...
    sta victory_sprite_copy             ; ...in victory_sprite_copy, which nothing reads
    jsr next_victory_sprite             ; ...and move to the next sparkle for the left side
    dec ring_x                          ; Left to x &19: the top-left corner
    jsr plot_victory_sprite             ; Plot it, first of the left side
    inc ring_y                          ; Down to y 4, beside the Chalice's top row
    jsr plot_victory_sprite             ; Plot the left side's second cell
    inc ring_y                          ; Down to y 5, beside its bottom row
    jsr plot_victory_sprite             ; Plot the left side's third cell
    jsr next_victory_sprite             ; Next sparkle for the bottom side
    inc ring_y                          ; Down to y 6: the bottom-left corner
    jsr plot_victory_sprite             ; Plot it, first of the bottom side
    inc ring_x                          ; Right to x &1A, below the Chalice's left column
    jsr plot_victory_sprite             ; Plot the bottom side's second cell
    inc ring_x                          ; Right to x &1B, below its right column
    jsr plot_victory_sprite             ; Plot the bottom side's third cell
    jsr next_victory_sprite             ; Next sparkle for the right side, kept for the next ring
    inc ring_x                          ; Right to x &1C: the bottom-right corner
    jsr plot_victory_sprite             ; Plot it, first of the right side
    dec ring_y                          ; Up to y 5, beside the Chalice's bottom row
    jsr plot_victory_sprite             ; Plot the right side's second cell
    dec ring_y                          ; Up to y 4, beside its top row
    jsr plot_victory_sprite             ; Plot the right side's third, closing the ring
    rts                                 ; Return, victory_sprite at the right side's sparkle
; ***************************************************************************************
; Plot a victory sprite at a cell
;
; Plot victory_sprite at the cell ring_x, ring_y in every view showing it, with the pixel
; offsets victory_sequence cleared. Called by draw_victory_ring for each of the ring's
; twelve cells; ring_x and ring_y are left as they were, for the next step.
;
; On Entry:
;     RING_X: cell x
;     RING_Y: cell y
;     VICTORY_SPRITE: the sprite
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &119a referenced 12 times by &3891, &3896, &389b, &38a8, &38ad, &38b2, &38ba, &38bf, &38c4, &38cc, &38d1, &38d6
.plot_victory_sprite
    lda ring_x                          ; Plot the victory sprite at the ring cell
    sta cell_x                          ; ...as the cell's x
    lda ring_y                          ; ...and its y...
    sta cell_y                          ; ...as the cell's y
    lda victory_sprite                  ; ...with the ring's current sprite...
    sta sprite_number                   ; ...as the sprite to plot
    jsr plot_at_cell                    ; ...in every view that shows the cell
    rts                                 ; Return to draw_victory_ring for the next cell
; ***************************************************************************************
; Choose the next victory sprite
;
; Step victory_sprite through the four sparkles, &16-&19, wrapping back to &16. Called by
; draw_victory_ring between the ring's sides, so each side shows a different sparkle. The
; blank sprite, &15, used to erase the ring, is left alone, so an erasing ring stays
; blank all the way round.
;
; On Entry:
;     VICTORY_SPRITE: the current sprite
;
; On Exit:
;     VICTORY_SPRITE: the next sparkle, &16-&19 in turn; &15 (erasing) is kept
;     A: victory_sprite
;     X: preserved
;     Y: preserved
; &11ac referenced 3 times by &38a3, &38b5, &38c7
.next_victory_sprite
    lda victory_sprite                  ; Erasing (sprite &15)? Keep it
    cmp #spr_blank                      ; ...the blank sprite?
    beq store_victory_sprite            ; Yes: keep erasing
    clc                                 ; Next sparkle, &16-&19 in turn
    adc #1                              ; ...the next sparkle sprite
    cmp #spr_sparkle_3 + 1              ; Past the last sparkle?
    bne store_victory_sprite            ; No: use it
    lda #spr_sparkle_0                  ; Yes: back to the first sparkle
; &11bb referenced 2 times by &38f0, &38f7
.store_victory_sprite
    sta victory_sprite                  ; Make it the ring's sprite
    rts                                 ; Return with A = victory_sprite
; ***************************************************************************************
; Clear a random byte of the Chalice
;
; Eat one more hole in the Chalice. Called by victory_sequence on every pass once its
; wait is down to 1. Make a random number from the System VIA's timer 1 low byte mixed
; with two bytes of MOS workspace (&FC and &FA). If it is below &C0, the size of the
; Chalice's 8 x 24-byte sprite, zero that byte of sprite_chalice and replot the Chalice,
; so it dissolves into black a pixel pair at a time; otherwise do nothing this pass. A
; byte already clear may be chosen again, so some survive until erase_victory_ring clears
; the rest.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &11be referenced 1 time by &3879
.dissolve_chalice
    lda system_via_t1c_l                ; Pick a byte of the Chalice: System VIA timer 1...
    eor os_irq_a                        ; ...mixed with the MOS's last interrupt A...
    eor os_zp_fa                        ; ...and more MOS workspace, for randomness
    cmp #&c0                            ; Within the Chalice's &C0 bytes?
    bcs dissolve_done                   ; No: nothing dissolves this pass
    tax                                 ; X = the chosen byte's offset in the sprite...
    lda #0                              ; ...cleared to zero, a black pair of pixels...
    sta sprite_chalice,x                ; ...in the Chalice's sprite data
    jsr plot_chalice                    ; ...and replot the Chalice with the hole in it
; &11d2 referenced 1 time by &3907
.dissolve_done
    rts                                 ; Return to victory_sequence's wait
; The 50th sweep is done: erase the ring, clear the rest of the Chalice, and hold the scene for 255 vsyncs.
; &11d3 referenced 1 time by &3859
.erase_victory_ring
    lda #spr_blank                      ; Erase the ring
    sta victory_sprite                  ; ...by making the blank the ring's sprite...
    jsr draw_victory_ring               ; ...and drawing the ring with it
    ldx #&c1                            ; Clear what is left of the Chalice...
    lda #0                              ; ...to zeros, black pixels
; &11de referenced 1 time by &3922
.clear_chalice_sprite
    sta sprite_chalice - 1,x            ; Clear a byte of the Chalice's sprite data
    dex                                 ; Next byte down
    bne clear_chalice_sprite            ; &C1 bytes: the &C0 and the unused byte after
    jsr plot_chalice                    ; ...and replot it, now black: the Chalice is gone
    lda #&ff                            ; Pause 255 vertical syncs (about five seconds)
    sta os_vsync_counter                ; ...which the MOS counts down at each vsync
; &11ec referenced 1 time by &392f
.wait_vsync_chalice
    lda os_vsync_counter                ; Read the count
    bne wait_vsync_chalice              ; Until it reaches zero
    rts                                 ; Return to check_for_victory for the ending text
; ***************************************************************************************
; Plot the Chalice
;
; Plot sprite &73, the Chalice, at its top-left cell (x &1A, y 4) in every view showing
; it, as its sprite data now stands. Called by dissolve_chalice after each byte it
; clears, and at the end of victory_sequence to show it gone. The sprite is two cells
; wide and two high, so it covers the four cells check_for_victory tests. The pixel
; offsets are those victory_sequence cleared.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &11f2 referenced 2 times by &390f, &3924
.plot_chalice
    lda #chalice_x                      ; The Chalice's top-left cell, x &1A, y 4...
    sta cell_x                          ; ...as the cell's x
    lda #chalice_y                      ; ...and y 4...
    sta cell_y                          ; ...as the cell's y
    lda #spr_chalice                    ; ...sprite &73, 2 x 2 cells...
    sta sprite_number                   ; ...as the sprite to plot...
    jsr plot_at_cell                    ; ...plotted in every view showing it
    rts                                 ; Return with the Chalice drawn as its data stands
; ***************************************************************************************
; Unused
;
; Leftover bytes, never read: &52 &78 &60 repeat the end of plot_chalice (JSR
; plot_at_cell's operand, then RTS), and the rest reads as a fragment of BASIC text,
; "(&1900+F".
    equs "Rx`(&1900+F"
; &120f used as index base 1 time by &391e
    equb &25                            ; Not referenced
; Data of sprite &73: 8 bytes x 24 rows.
; ***************************************************************************************
; The Chalice sprite
;
; Sprite &73: 8 bytes by 24 rows, two cells by two, plotted at x &1A, y 4 by
; plot_chalice. In the victory sequence dissolve_chalice zeros random bytes of it and
; erase_victory_ring zeros all of it (and the byte after); the game then ends in a reset.
; &1210 used as index base 1 time by &390c
.sprite_chalice
    equb &00, &00, &05, &0f, &0f, &0a, &00, &00
    equb &00, &00, &0f, &07, &0b, &0f, &00, &00
    equb &00, &05, &0b, &03, &03, &07, &0a, &00
    equb &00, &0f, &07, &5a, &a5, &0b, &0f, &00
    equb &00, &0f, &07, &0f, &0f, &0b, &0f, &00
    equb &05, &0b, &0f, &00, &00, &0f, &07, &0a
    equb &05, &0b, &0a, &00, &00, &05, &07, &0a
    equb &0f, &07, &0e, &00, &00, &0d, &0b, &0f
    equb &0f, &07, &04, &08, &04, &08, &0b, &0f
    equb &0b, &07, &45, &0c, &0c, &8a, &0b, &07
    equb &0f, &07, &00, &0c, &0c, &00, &0b, &0f
    equb &5a, &07, &0c, &4d, &8e, &0c, &0b, &a5
    equb &5a, &07, &0c, &4d, &8e, &0c, &0b, &a5
    equb &0f, &07, &00, &0c, &0c, &00, &0b, &0f
    equb &0b, &07, &45, &0c, &0c, &8a, &0b, &07
    equb &0f, &07, &04, &08, &04, &08, &0b, &0f
    equb &0f, &07, &0e, &00, &00, &0d, &0b, &0f
    equb &05, &0b, &0a, &00, &00, &05, &07, &0a
    equb &05, &0b, &0f, &00, &00, &0f, &07, &0a
    equb &00, &0f, &07, &0f, &0f, &0b, &0f, &00
    equb &00, &0f, &07, &5a, &a5, &0b, &0f, &00
    equb &00, &05, &0b, &03, &03, &07, &0a, &00
    equb &00, &00, &0f, &07, &0b, &0f, &00, &00
    equb &00, &00, &05, &0f, &0f, &0a, &00, &00
    equb &3d, &26, &00                  ; Not referenced
; The WRCHV contents found at start-up, restored while the game uses the MOS's own text output.
; &12d3 referenced 2 times by &3498, &3c17
.saved_wrchv
    equb &a4                            ; WRCHV as saved at start-up (&E0A4 as loaded)
; &12d4 referenced 2 times by &349e, &3c1d
    equb &e0, &00, &73                  ; Not referenced
; The game's font for the letters A-Z: eight bytes per letter, one per pixel row, in MOS character-definition format.
; ***************************************************************************************
; Font: letters A-Z
;
; Eight bytes per letter, copied into the definition of character 128 by the WRCHV
; handler.
; &12d7 used as index base 1 time by &7fc5
.font_letters
    equb %00111100                      ; 'A'
    equb %01000010
    equb %01000010
    equb %10001110
    equb %11110010
    equb %10000010
    equb %11000110
    equb %00000000
    equb %01111000                      ; 'B'
    equb %01000100
    equb %01000010
    equb %10111100
    equb %10000010
    equb %10000010
    equb %11111100
    equb %00000000
    equb %00111100                      ; 'C'
    equb %01000010
    equb %01000000
    equb %10000000
    equb %10000000
    equb %10000010
    equb %01111100
    equb %00000000
    equb %01111100                      ; 'D'
    equb %10000010
    equb %10000010
    equb %10000010
    equb %10000100
    equb %10000100
    equb %11111000
    equb %00000000
    equb %00001110                      ; 'E'
    equb %01110000
    equb %01000000
    equb %11001110
    equb %11110000
    equb %10000000
    equb %11111110
    equb %00000000
    equb %00011110                      ; 'F'
    equb %11100000
    equb %10000000
    equb %10001110
    equb %11110000
    equb %10000000
    equb %11000000
    equb %00000000
    equb %00111100                      ; 'G'
    equb %01000010
    equb %01000010
    equb %10000000
    equb %10011110
    equb %10000010
    equb %01111110
    equb %00000000
    equb %01100010                      ; 'H'
    equb %01000010
    equb %01000010
    equb %10011110
    equb %11100010
    equb %10000010
    equb %11000110
    equb %00000000
    equb %00011110                      ; 'I'
    equb %00001000
    equb %00001000
    equb %00010000
    equb %00010000
    equb %00010000
    equb %01111100
    equb %00000000
    equb %11111110                      ; 'J'
    equb %00000010
    equb %00000010
    equb %00000100
    equb %11000100
    equb %10000100
    equb %01111000
    equb %00000000
    equb %01000000                      ; 'K'
    equb %01001110
    equb %01110000
    equb %10001000
    equb %10001000
    equb %10000100
    equb %11000010
    equb %00000000
    equb %01100000                      ; 'L'
    equb %01000000
    equb %01000000
    equb %10000000
    equb %10000000
    equb %10000010
    equb %11111110
    equb %00000000
    equb %01000110                      ; 'M'
    equb %01101110
    equb %01101010
    equb %11011010
    equb %10010010
    equb %10000010
    equb %11000110
    equb %00000000
    equb %01100110                      ; 'N'
    equb %01010010
    equb %01010010
    equb %10001010
    equb %10001010
    equb %10001010
    equb %11000110
    equb %00000000
    equb %00111100                      ; 'O'
    equb %01000010
    equb %01000010
    equb %10000010
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %01111100                      ; 'P'
    equb %01000010
    equb %01000010
    equb %10111100
    equb %10000000
    equb %10000000
    equb %11000000
    equb %00000000
    equb %00111100                      ; 'Q'
    equb %01000010
    equb %01000010
    equb %10011010
    equb %10001010
    equb %10000110
    equb %01111110
    equb %00000000
    equb %01111100                      ; 'R'
    equb %01000010
    equb %01000010
    equb %10111100
    equb %10001000
    equb %10000100
    equb %11000010
    equb %00000000
    equb %00011110                      ; 'S'
    equb %00100010
    equb %01000000
    equb %00111100
    equb %00000010
    equb %10000010
    equb %11111100
    equb %00000000
    equb %11111110                      ; 'T'
    equb %10010010
    equb %00010000
    equb %00100000
    equb %00100000
    equb %00100000
    equb %01110000
    equb %00000000
    equb %01100110                      ; 'U'
    equb %01000010
    equb %01000010
    equb %10000010
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %11000110                      ; 'V'
    equb %01000010
    equb %01000010
    equb %10000010
    equb %10000100
    equb %01001000
    equb %00110000
    equb %00000000
    equb %01100110                      ; 'W'
    equb %01000010
    equb %01000010
    equb %10010010
    equb %10101010
    equb %01001010
    equb %01000100
    equb %00000000
    equb %01100110                      ; 'X'
    equb %00100010
    equb %00100100
    equb %00011000
    equb %00011000
    equb %00100100
    equb %11000110
    equb %00000000
    equb %10000110                      ; 'Y'
    equb %01000010
    equb %00110010
    equb %00001100
    equb %00001000
    equb %00010000
    equb %01110000
    equb %00000000
    equb %01111110                      ; 'Z'
    equb %00000010
    equb %00000100
    equb %00011000
    equb %00100000
    equb %01000010
    equb %11111110
    equb %00000000
; The game's font for the digits 0-9, in the same format as font_letters.
; ***************************************************************************************
; Font: digits 0-9
;
; Eight bytes per digit, copied into the definition of character 128 by the WRCHV
; handler.
; &13a7 used as index base 1 time by &7fe8
.font_digits
    equb %00111100                      ; '0'
    equb %01000110
    equb %01001010
    equb %10010010
    equb %10100010
    equb %11000100
    equb %01111000
    equb %00000000
    equb %00001000                      ; '1'
    equb %00011000
    equb %00001000
    equb %00010000
    equb %00010000
    equb %00010000
    equb %00111100
    equb %00000000
    equb %00111100                      ; '2'
    equb %01000010
    equb %00000010
    equb %00001100
    equb %00110000
    equb %01000010
    equb %11111100
    equb %00000000
    equb %01111110                      ; '3'
    equb %00000010
    equb %00000100
    equb %00011000
    equb %00000110
    equb %10000010
    equb %01111100
    equb %00000000
    equb %00011000                      ; '4'
    equb %00101000
    equb %01001000
    equb %10010000
    equb %11111100
    equb %00010000
    equb %00111000
    equb %00000000
    equb %00011111                      ; '5'
    equb %00100000
    equb %00100000
    equb %00011000
    equb %00000100
    equb %10000010
    equb %01111100
    equb %00000000
    equb %00001110                      ; '6'
    equb %00010000
    equb %00100000
    equb %01111100
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %01111110                      ; '7'
    equb %00000010
    equb %00000010
    equb %00000100
    equb %00001000
    equb %00010000
    equb %01111000
    equb %00000000
    equb %00011100                      ; '8'
    equb %00100010
    equb %00100010
    equb %01111100
    equb %10000010
    equb %10000010
    equb %01111100
    equb %00000000
    equb %00111100                      ; '9'
    equb %01000010
    equb %01000010
    equb %00111110
    equb %00000010
    equb %00000100
    equb %00011000
    equb %00000000
; ***************************************************************************************
; Unused
;
; Leftover bytes, never read: a second copy of the digit 9's eight glyph rows, then &74.
    equs "<BB>"
    equb &02, &04, &18, &00, &74        ; Not referenced
; ***************************************************************************************
; Set up and draw a new level
;
; Turn the next level's file into a fresh play screen. Called from the level loop (&0E57)
; at the start of every level; the loop then draws the status panel and plays the level.
;
; In order: prepare the text area (the first call, which differs between releases), get
; the level file at &6B00 decrypted and checked, unpack it into the game's tables
; (unpack_level), put the heroes, missiles and views back to the start (reset_workspace),
; start the monsters dead and the heroes without keys (reset_monsters), then clear the
; screen, set the 6845 to show all 25 character rows the play screen uses, and draw the
; view frames and the four views (draw_view_frames). The order matters: any text printed
; before loading rewrites character 128's definition at &0C00, the start of room_walls,
; so the level is unpacked after it; and the level file lies in screen rows 23-24, so the
; screen is cleared only once the file is unpacked.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &1400 referenced 1 time by &3597
.start_level
    jsr clear_text_for_level            ; Prepare the text area for the new level
    jsr check_level                     ; Get the level file at &6B00 decrypted and checked
    jsr unpack_level                    ; Copy its objects, doors, keys and maps into play
    jsr reset_workspace                 ; Put the heroes, missiles and views back to the start
    jsr reset_monsters                  ; Monsters to the trapdoors; heroes carry no keys
; Show the play screen: clear the text area, display all 25 character rows, then draw the frames and the views.
    jsr clear_text_area                 ; Clear the screen, LEVEL and all, for the play screen
    lda #&17                            ; VDU 23,0,6,25,0,0,0,0,0,0: set 6845 register 6...
    jsr oswrch                          ; Send VDU 23
    lda #0                              ; 0: a 6845 register setting follows
    jsr oswrch                          ; Send the 0
    lda #6                              ; Register 6: character rows displayed
    jsr oswrch                          ; Send the register number
    lda #&19                            ; ...to 25: the views and panel fill rows 0-24
    jsr oswrch                          ; Send it: show all 25 rows for play
    lda #0                              ; Six zero bytes complete the VDU 23
    jsr oswrch                          ; Send the first zero
    jsr oswrch                          ; Send the second zero
    jsr oswrch                          ; Send the third zero
    jsr oswrch                          ; Send the fourth zero
    jsr oswrch                          ; Send the fifth zero
    jsr oswrch                          ; Send the sixth zero
    lda #<(view_frame_plots)            ; (plot_x) points at the frames' PLOT commands...
    sta plot_x                          ; ...low byte in plot_x...
    lda #>(view_frame_plots)            ; ...and view_frame_plots' high byte...
    sta plot_y                          ; ...in plot_y, as draw_view_frames expects
    jsr draw_view_frames                ; Draw the four frames, then the room in each view
    rts                                 ; Return to the level loop to draw the panel and play
; ***************************************************************************************
; Check the level and set the text window
;
; Make the level Coder loaded ready for unpack_level. Called by start_level after
; clear_text_for_level: Coder has already put the file at &6B00-&6DAF. Decrypt it and
; check its checksum (decrypt_level resets the machine on a mismatch).
;
; Then set the bottom row of clear_text_area's text window from 22 to 24. Dun1 stores it
; as 22, so that clear_text_for_level's clear stops at row 22, above the level file in
; rows 23-24; from here on the whole screen is cleared. Coder reloads Dun1 for each
; level, so the window is 22 again at the next level's start.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &1446 referenced 1 time by &3b43
.check_level
    jsr decrypt_level                   ; Decrypt and check the level Coder loaded at &6B00
    lda #&18                            ; Bottom row 24 for clear_text_area's window...
    sta text_window_bottom              ; ...over the &16 in its VDU 28: the full 25 rows
    rts                                 ; Return to start_level: the level is ready to unpack
; ***************************************************************************************
; Restart the game by resetting the machine
;
; End the game after all four heroes have died. Reached from level_loop's end once the
; game-over message has been shown for up to 5.8 seconds. Arm the BREAK intercept with a
; JMP to restart_intercept and branch to reset_machine, so that the reset runs *DUNJUNZ,
; which resets page &08, shows the title screen and runs Coder for a new game. Never
; returns.
; &144f referenced 1 time by &360c
.restart_by_reset
    lda #<(restart_intercept)           ; Arm the BREAK intercept: JMP restart_intercept...
    sta os_break_intercept + 1          ; ...address low byte into &0288...
    lda #>(restart_intercept)           ; ...then the routine's page...
    sta os_break_intercept + 2          ; ...into &0289, the JMP's high byte
    lda #&4c ; 'L'                      ; ...then the JMP opcode...
    sta os_break_intercept              ; ...into &0287, which arms the intercept
    bne reset_machine                   ; ...and reset (always taken: A = &4C)
; ***************************************************************************************
; Move on to the next level by resetting the machine
;
; End a level that at least one hero survived, by having the machine reset itself into
; Coder. Reached through to_next_level, after level_loop's end has given the dead heroes
; their starting attributes back. Arm the MOS BREAK intercept (&0287-&0289) with a JMP to
; next_level_intercept and jump to the MOS 1.20 reset entry at &D9CD; the MOS calls the
; intercept during the reset, and its second call runs *CODER, which reloads the game and
; the next level. Page &08 (levels_started, level_digits and the menu's tables) and
; &08C0-&0CFF (the heroes' attributes and scores) survive the reset and Coder's copy.
; Never returns.
; &1460 referenced 1 time by &3585
.next_level_by_reset
    lda #&4c ; 'L'                      ; Arm the BREAK intercept: a JMP opcode...
    sta os_break_intercept              ; ...into &0287, the intercept's first byte...
    lda #<(next_level_intercept)        ; ...JMP to next_level_intercept: low byte...
    sta os_break_intercept + 1          ; ...into &0288, the JMP's low byte
    lda #>(next_level_intercept)        ; ...then the routine's page...
    sta os_break_intercept + 2          ; ...into &0289: the intercept is armed
; &146f referenced 1 time by &3b9e
.reset_machine
    jmp mos_reset_entry                 ; Reset: the MOS calls the intercept on the way
; ***************************************************************************************
; BREAK intercept: reload the game
;
; Called twice by the MOS during the reset that restart_by_reset makes. The first call
; (carry clear) comes before the filing system is initialised and does nothing. On the
; second, clear the screen of the game-over message, select the disc filing system and
; *DUNJUNZ, which takes over and never returns.
;
; On Entry:
;     C: set on the second call, after the filing system is initialised
.restart_intercept
    bcc restart_intercept_done          ; First call (before the filing system): nothing to do
    lda #&0c                            ; VDU 12: clear the screen...
    jsr oswrch                          ; ...of the game-over message
    ldx #&89                            ; *DISC: X, Y = &1489, the "DISC" after the C...
    ldy #&14                            ; ...high byte of the command
    jsr oscli                           ; ...so that *DUNJUNZ comes from the disc
    ldx #&8e                            ; *DUNJUNZ (at &148E): load the game afresh...
    ldy #&14                            ; ...high byte of the command
    jsr oscli                           ; ...which takes over and never returns
; &1487 referenced 1 time by &3bb2
.restart_intercept_done
    rts                                 ; Return to the MOS
; ***************************************************************************************
; restart_intercept's commands
;
; The *DISC and *DUNJUNZ command lines, read from &1489 and &148E (the C before DISC is
; not read). After them come stale bytes: STA &149C, LDA #&FF, JSR &3000, JMP &0450, the
; end of a level loader that calls FILEV's routine through a patched JSR.
    equs "CDISC"                        ; "C" (not read), then "DISC" from &1489: *DISC
    equb &0d                            ; ...the CR ending *DISC
    equs "DUNJUNZ"                      ; "DUNJUNZ": *DUNJUNZ, for restart_intercept
    equb &0d, &9c, &14, &a9, &ff, &20, &00  ; CR ending *DUNJUNZ; then stale STA &149C, LDA #&FF...
    equs "0LP"                          ; ...JSR &3000, JMP &0450: never run
    equb &04                            ; ...the JMP's high byte; not referenced
; ***************************************************************************************
; Reset the game workspace for a new level
;
; Put the heroes, missiles and views back where every level starts. Called by start_level
; once a level, after unpack_level and before reset_monsters. Copy the 256 bytes of
; workspace_template (&7D00) over page &0D, the per-level workspace, then reset the exit
; animation's state, which lives in page &09: no hero going down the exit (exit_busy 0)
; or left shrunk (shrunk_hero &FF), the shrinking hero's pixel offsets (x 1, 1, 0, 0 and
; y 5, 3, 1, 0 for exit_shrinks_left 1-4), and trapdoor 0 as the next one a monster comes
; out of (next_trapdoor). Nothing here touches the heroes' health or scores, which carry
; over from level to level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
; &14a0 referenced 1 time by &3b49
.reset_workspace
    ldx #0                              ; Copy workspace_template to page &0D
; &14a2 referenced 1 time by &3be9
.copy_workspace_template
    lda workspace_template,x            ; Byte of the starting values...
    sta scratch,x                       ; ...becomes page &0D's byte
    inx                                 ; Next of page &0D's 256 bytes
    bne copy_workspace_template         ; Until all 256 are copied: heroes back at the start
    lda #0                              ; Reset the exit animation and the trapdoor turn
    sta exit_busy                       ; No hero is going down the exit
    sta exit_offset_x_3                 ; Shrinking hero's x offset at shrink 3: 0...
    sta exit_offsets_y                  ; ...at shrink 4 (exit_offsets_y doubles as x 4)...
    sta exit_offset_y_4                 ; ...and the y offset at shrink 4
    sta next_trapdoor                   ; First monster emerges from trapdoor 0
    lda #1                              ; Offsets of 1 for the exit animation
    sta exit_offset_x_1                 ; ...x offset at shrink 1...
    sta exit_offset_x_2                 ; ...x offset at shrink 2...
    sta exit_offset_y_3                 ; ...and y offset at shrink 3
    lda #&ff                            ; &FF: no hero is shrunk
    sta shrunk_hero                     ; ...so no hero's sprites need restoring
    lda #5                              ; Shrinking hero's y offset at shrink 1: 5...
    sta exit_offset_y_1                 ; ...for y offset 1
    lda #3                              ; ...and at shrink 2: 3
    sta exit_offset_y_2                 ; ...for y offset 2
    rts                                 ; Return to start_level
; ***************************************************************************************
; Draw the frames round the four views
;
; Draw the play screen's four view frames and the room in each view. Called last by
; start_level, with (plot_x) at view_frame_plots. WRCHV is first pointed back at the
; MOS's own routine (saved_wrchv), because wrch_handler swaps the code of any letter or
; digit for character 128, which would corrupt any PLOT coordinate byte that happens to
; be one. Then send the twenty five-byte commands as VDU 25s, call draw_all_views to draw
; the room each hero's view shows, and point WRCHV at wrch_handler again, so text that
; follows is in the game's font.
;
; On Entry:
;     PLOT_X: address of view_frame_plots, low byte
;     PLOT_Y: address of view_frame_plots, high byte
;
; On Exit:
;     PLOT_X: advanced by 100
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &14d7 referenced 1 time by &3b82
.draw_view_frames
    lda saved_wrchv                     ; Restore the MOS's own WRCHV for the PLOT commands...
    sta wrchv                           ; ...saved_wrchv's low byte into WRCHV...
    lda saved_wrchv + 1                 ; ...and its high byte...
    sta wrchv + 1                       ; ...so the PLOTs draw lines, not the game's font
    ldx #&14                            ; Twenty PLOT commands: five for each view's frame
; &14e5 referenced 1 time by &3c40
.draw_view_frame
    lda #&19                            ; Start a PLOT command: VDU 25...
    jsr oswrch                          ; Send VDU 25: a PLOT command follows
    ldy #0                              ; ...then the five bytes of the command
; &14ec referenced 1 time by &3c34
.send_frame_vdu
    lda (plot_x),y                      ; Next byte of this PLOT: K, then X and Y
    jsr oswrch                          ; Send it to the VDU drivers
    iny                                 ; On to the command's next byte
    cpy #5                              ; All five sent?
    bne send_frame_vdu                  ; No: send the next
    clc                                 ; Step (plot_x) on to the next command...
    lda plot_x                          ; ...its low byte...
    adc #5                              ; ...plus five...
    sta plot_x                          ; ...to the next PLOT (the table is all in one page)
    ldy #0                              ; Start the next PLOT at its first byte
    dex                                 ; Count the PLOT done
    bne draw_view_frame                 ; Until all twenty are drawn
    jsr draw_all_views                  ; Draw each hero's room inside their frame
    lda #<(wrch_handler)                ; Point WRCHV back at wrch_handler...
    sta wrchv                           ; ...its low byte into WRCHV...
    lda #>(wrch_handler)                ; ...and its high byte...
    sta wrchv + 1                       ; ...so text is drawn in the game's font again
    rts                                 ; Return to start_level: frames and views drawn
; ***************************************************************************************
; Copy the loaded level into the game's tables
;
; Bring the level just loaded into play. Called by start_level once the level file at
; &6B00 has been decrypted and checked, before reset_workspace. Copy objects 1-30
; (position and type; the type is also the sprite), doors 1-20 (position and sprite),
; keys 1-20, trapdoors 0-7, &C9 bytes each of the wall map (into room_walls, read by
; test_wall) and object-free map (into object_free_map, read by test_object_free), and
; the level's 4 x 12 wall block into wall_sprite, sprite 0, the wall in every room. Entry
; 0 of the object, door and key tables is not touched. room_walls is also character 128's
; definition, which the game's text output overwrites, so this must follow the printing
; of the level number. The file itself lies in screen rows 23-24 and is wiped by
; start_level's clear_text_area once unpacked.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: preserved
; &1510 referenced 1 time by &3b46
.unpack_level
    ldx #max_object                     ; Objects 30 to 1: position and type
; &1512 referenced 1 time by &3c65
.unpack_objects
    lda level_object_x,x                ; Object's x in the level file...
    sta object_x,x                      ; ...becomes its map x
    lda level_object_y,x                ; The object's y in the file...
    sta object_y,x                      ; ...becomes its map y
    lda level_object_type,x             ; Its type, which is also its sprite...
    sta object_type,x                   ; ...becomes its object type
    dex                                 ; Next object down
    bne unpack_objects                  ; Until object 1 is done (entry 0 is unused)
    ldx #max_door                       ; Doors 20 to 1: position and sprite
; &1529 referenced 1 time by &3c7c
.unpack_doors
    lda level_door_x,x                  ; Door's x in the level file...
    sta door_x,x                        ; ...becomes its map x
    lda level_door_y,x                  ; The door's y in the file...
    sta door_y,x                        ; ...becomes its map y
    lda level_door_sprite,x             ; Its sprite, upright or across...
    sta door_sprite,x                   ; ...becomes its sprite
    dex                                 ; Next door down
    bne unpack_doors                    ; Until door 1 is done
    ldx #max_key                        ; Keys 20 to 1: position
; &1540 referenced 1 time by &3c8d
.unpack_keys
    lda level_key_x,x                   ; Key's x in the level file...
    sta key_x,x                         ; ...becomes its map x
    lda level_key_y,x                   ; The key's y in the file...
    sta key_y,x                         ; ...becomes its map y
    dex                                 ; Next key down
    bne unpack_keys                     ; Until key 1 is done
    ldx #0                              ; Trapdoors 0 to 7: where dead monsters come back
; &1551 referenced 1 time by &3ca0
.unpack_trapdoors
    lda level_trapdoor_x,x              ; Trapdoor's x in the level file...
    sta trapdoor_x,x                    ; ...becomes its map x
    lda level_trapdoor_y,x              ; The trapdoor's y in the file...
    sta trapdoor_y,x                    ; ...becomes its map y
    inx                                 ; Next trapdoor up, 0 to 7
    cpx #8                              ; All eight done?
    bne unpack_trapdoors                ; No: copy the next
    ldx #0                              ; Wall map and object-free map, &C9 bytes each
; &1564 referenced 1 time by &3cb3
.unpack_walls
    lda level_walls,x                   ; Byte of the level's wall map...
    sta room_walls,x                    ; ...into room_walls, which test_wall reads
    lda level_object_free_map,x         ; Byte of the level's object-free map...
    sta object_free_map,x               ; ...into object_free_map, which test_object_free reads
    inx                                 ; Next byte of both maps
    cpx #map_bytes                      ; Both maps copied?
    bne unpack_walls                    ; No: copy the next
    ldx #0                              ; The level's own wall block, &30 bytes
; &1577 referenced 1 time by &3cc0
.unpack_wall_sprite
    lda level_wall_sprite,x             ; Byte of the level's wall block...
    sta wall_sprite,x                   ; ...becomes sprite 0, the wall in every room
    inx                                 ; Next byte of the wall block
    cpx #&30 ; '0'                      ; All 4 x 12 bytes copied?
    bne unpack_wall_sprite              ; No: copy the next
    rts                                 ; Return to start_level with the level unpacked
; ***************************************************************************************
; Clear the monsters for a new level
;
; Start every monster dead and every hero empty-handed. Called by start_level after
; reset_workspace. Give monsters 1-30 the blank sprite (the first stage of dying) and an
; x off the map, so update_monsters brings each out of a trapdoor in turn, with
; monster_start_hit_points, the hit points level_loop set for this level. Then, for each
; of the four heroes, clear their returning_hero_queue entry, the key they carry
; (hero_key) and the swap flag (hero_key_dropped), and the cell kept for the door and
; Chalice checks (hero_door_x, hero_door_y), so nothing from the last level opens a door
; or wins the game. remove_absent_heroes refills the queue later for heroes nobody plays.
;
; On Exit:
;     A: 0
;     X: 4
;     Y: preserved
; &1583 referenced 1 time by &3b4c
.reset_monsters
    ldx #max_monster                    ; Monsters 30 to 1...
; &1585 referenced 1 time by &3cd6
.reset_each_monster
    lda #spr_blank                      ; ...dying, so that they emerge from the trapdoors...
    sta monster_sprite,x                ; ...as monster X's sprite...
    lda #off_map                        ; ...off the map...
    sta monster_x,x                     ; ...as monster X's x...
    lda monster_start_hit_points        ; ...with this level's hit points
    sta monster_hit_points,x            ; ...as monster X's hit points
    dex                                 ; Next monster down
    bne reset_each_monster              ; Until monster 1 is done
    ldx #0                              ; Each hero: clear queue place, key carried, door cell
    lda #0                              ; Zero for every entry cleared
; &159c referenced 1 time by &3cee
.clear_hero_carrying
    sta returning_hero_queue,x          ; Queue entry X empty: nobody waits to return
    sta hero_key,x                      ; Hero X carries no key
    sta hero_key_dropped,x              ; ...and has swapped none
    sta hero_door_x,x                   ; No door-check cell...
    sta hero_door_y,x                   ; ...in x or y
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four done?
    bne clear_hero_carrying             ; No: clear the next
    rts                                 ; Return to start_level, monsters and heroes reset
; ***************************************************************************************
; Clear the text area before a level
;
; start_level's first call. Only clears the screen: no level number is shown, and
; level_number is not counted here (game_entry sets it from levels_started). At this
; point clear_text_area's window still ends at row 22, as Dun1 stores it, so the level
; file Coder loaded into rows 23-24 is kept for check_level; Dun1's other stored bytes in
; rows 0-22 are wiped.
;
; On Exit:
;     A: corrupted
; &15b1 referenced 1 time by &3b40
.clear_text_for_level
    jsr clear_text_area                 ; Clear rows 0-22: the level file in rows 23-24 is kept
    rts                                 ; Return to start_level, which checks the level next
; ***************************************************************************************
; BREAK intercept: run Coder for the next level
;
; Called twice by the MOS during the reset that next_level_by_reset makes. The first call
; (carry clear) comes before the filing system is initialised and does nothing. On the
; second, select MODE 2, the disc filing system and *RUN CODER, which loads the next
; level and never returns. *DUNJUNZ also points the intercept at &15B5 while *CODER
; loads, so a BREAK then lands here too, but &15B5 holds this routine only if Coder has
; copied the game core there since power-on.
;
; On Entry:
;     C: set on the second call, after the filing system is initialised
.next_level_intercept
    bcc next_level_intercept_done       ; First call (before the filing system): nothing to do
    lda #&16                            ; MODE 2, the game's mode, for Coder...
    jsr oswrch                          ; ...send VDU 22, select a mode...
    lda #2                              ; ...then the mode number, 2...
    jsr oswrch                          ; ...sent: MODE 2 is selected
    ldx #&e0                            ; *DISC: X, Y = &15E0, "DISC"...
    ldy #&15                            ; ...high byte of the command
    jsr oscli                           ; ...so that Coder comes from the disc
    ldx #&e5                            ; *RUN CODER (at &15E5): the game and next level...
    ldy #&15                            ; ...high byte of the command
    jsr oscli                           ; ...which never returns
; &15cf referenced 1 time by &3cf5
.next_level_intercept_done
    rts                                 ; Return to the MOS
; ***************************************************************************************
; Unused, then next_level_intercept's commands
;
; Stale bytes, never run: &15D2-&15D8 repeat next_level_intercept's LDX #&E5, LDY #&15,
; JSR OSCLI, and an RTS and "ODER" follow. Then the *DISC and *RUN CODER command lines
; read from &15E0 and &15E5, and more unused bytes.
    equb &f7, &ff, &a2, &e5, &a0, &15, &20, &f7
    equb &ff                            ; Not referenced: stale code
    equs "`ODER"                        ; Not referenced: RTS, then "ODER"
    equb &0d, &ad                       ; Not referenced
    equs "DISC"                         ; "DISC": *DISC, for next_level_intercept
    equb &0d                            ; ...the CR ending *DISC
    equs "RUN CODER"                    ; "RUN CODER": *RUN CODER, for next_level_intercept
    equb &0d, &0f, &18                  ; CR ending *RUN CODER; then two bytes not referenced
    equs "i0 "                          ; Not referenced
    equb &ee, &ff, &a9, &1c, &20, &ee, &ff, &a9
    equb &01, &20, &ee, &ff, &a9, &16, &20, &ee
    equb &ff, &a9, &0e, &20, &ee, &ff, &a9, &11
    equb &20, &ee, &ff, &a9, &11, &20, &ee, &ff
    equb &a9, &02, &20, &ee, &ff, &60   ; Not referenced
; ***************************************************************************************
; Clear the screen
;
; Clear the screen above the game code. Called twice for each level: by the routine
; start_level calls first, before the level is loaded, and by start_level itself before
; the play screen is drawn. Set a text window the full 20 columns wide from row 0 to the
; bottom row (24 in play), and clear it with VDU 12. The window never reaches below row
; 24 because MODE 2's rows 25-31, &6E80-&7FFF, hold game code. The window is left set, so
; later text and clears stay inside it.
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: preserved
; &161a referenced 2 times by &3b4f, &3cf1
.clear_text_area
    lda #&1c                            ; VDU 28: a text window over the whole screen...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
.set_text_window_bottom
; &3d65 referenced 1 time by &3b8b
; The bottom row of clear_text_area's text window, an operand that check_level sets to &18.
text_window_bottom = set_text_window_bottom+1
    lda #&16                            ; Bottom row of the window (24 in play)
    jsr oswrch                          ; Send the bottom row
    lda #&13                            ; Right column 19: the full MODE 2 width
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Send it: the window clears to the background
    rts                                 ; Return with the window left set
    equb &60                            ; Not referenced
; Twenty VDU 25 (PLOT) commands, five bytes each (plot code, then x and y as 16-bit words), that draw the frames round the four views; read by draw_view_frames through (plot_x).
; ***************************************************************************************
; View frame PLOT commands
;
; Twenty five-byte VDU 25 commands (plot code, then x and y as 16-bit words) sent by
; draw_view_frames, five for each view's frame: PLOT 4 moves to the top-left corner,
; three PLOT 1s draw relative lines down 388, right 520 and up 388, and PLOT 5 draws back
; to the corner. The corners are (8,1022), (552,1022), (8,614) and (552,614); the second
; frame's first line is 389 long.
.view_frame_plots
    equb &04, &08, &00, &fe, &03
    equb &01, &00, &00, &7c, &fe
    equb &01, &08, &02, &00, &00
    equb &01, &00, &00, &84, &01
    equb &05, &08, &00, &fe, &03
    equb &04, &28, &02, &fe, &03
    equb &01, &00, &00, &7b, &fe
    equb &01, &08, &02, &00, &00
    equb &01, &00, &00, &84, &01
    equb &05, &28, &02, &fe, &03
    equb &04, &08, &00, &66, &02
    equb &01, &00, &00, &7c, &fe
    equb &01, &08, &02, &00, &00
    equb &01, &00, &00, &84, &01
    equb &05, &08, &00, &66, &02
    equb &04, &28, &02, &66, &02
    equb &01, &00, &00, &7c, &fe
    equb &01, &08, &02, &00, &00
    equb &01, &00, &00, &84, &01
    equb &05, &28, &02, &66, &02
    equb &08                            ; Not referenced
; The current level, 1-25, in binary. Set to 0 for a new game and counted up as each level starts. Read for the monsters' hit points (8 + 2 per level already played), for the level file's checksum entry (decrypt_level), and by check_for_victory, which looks for the Chalice only on level 25.
; &169f referenced 5 times by &34ad, &37b0, &507a, &5227, &5627
.level_number
    equb &01
; ***************************************************************************************
; Sound the exit and add a queue marker
;
; Play the exit's falling tone and queue a marker for the hero leaving. Called first by
; hero_enters_exit, when a hero steps onto the exit. Define envelope 3 from exit_envelope
; and play exit_sound with it (channel 2, pitch 250). Then put a &64 (nobody_returns)
; entry in the first empty (zero) entry of returning_hero_queue, behind any dead heroes
; waiting, as remove_absent_heroes does for each hero nobody plays. A Cross of
; Resurrection passes such markers to the back of the queue, so a hero who took the exit
; is never brought back by one. At most four of the queue's five entries are ever in use,
; so an empty one is always found; X is not bounded.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &16a0 referenced 1 time by &203d
.queue_exit_marker
    ldx #<(exit_envelope)               ; Envelope 3 for the exit: X = exit_envelope low...
    ldy #>(exit_envelope)               ; ...Y = its high byte...
    lda #osword_envelope                ; ...OSWORD 8: ENVELOPE...
    jsr osword                          ; Define envelope 3: a falling pitch  ENVELOPE command
    ldx #<(exit_sound)                  ; Play the exit sound: X = exit_sound low...
    ldy #>(exit_sound)                  ; ...Y = its high byte...
    lda #osword_sound                   ; ...OSWORD 7: SOUND...
    jsr osword                          ; Sound channel 2 with envelope 3  SOUND command
    ldx #0                              ; Append a marker to returning_hero_queue...
; &16b4 referenced 1 time by &3e00
.find_queue_end
    lda returning_hero_queue,x          ; Entry X of the queue
    bne next_queue_entry                ; In use: try the next
    lda #nobody_returns                 ; Empty: add a &64 marker there
    sta returning_hero_queue,x          ; ...in the first empty entry, behind those waiting
    rts                                 ; Return to hero_enters_exit
; &16bf referenced 1 time by &3df7
.next_queue_entry
    inx                                 ; Next entry along the queue
    bne find_queue_end                  ; Keep looking (at most four entries are in use)
    equb &02, &02, &00, &00, &83, &00, &00, &00
    equb &00, &00, &00, &31, &00, &8d   ; Not referenced
    equs "LEVEL"
.level_filename_digits
    equb &31
    equb &0d, &0d, &70, &00, &8d, &35, &f8, &00
    equb &00, &00, &00                  ; Not referenced
    equs "code"
    equb &00, &54, &12, &03, &17, &74, &00, &8c
    equb &50, &00, &00, &00, &fa, &16, &78, &00
    equb &8c, &50, &20, &00, &00, &02, &00, &79
    equb &00, &8c                       ; Not referenced
; The current level in binary-coded decimal (&01-&25), counted up with decimal arithmetic as each level starts, for printing the level number and for the digits of the level's filename.
; &16ff referenced 1 time by &34b2
.level_bcd
    equb &01
; Data of sprite &49: 4 bytes x 12 rows.
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
; &1ae0 used as index base 1 time by &3042
.sprite_addr_lo
    equb &00, &30, &60, &90, &c0, &f0, &20, &50
    equb &c0, &80, &b0, &e0, &10, &40, &70, &a0
    equb &d0, &00, &30, &60, &90, &cf, &00, &30
    equb &60, &90, &cf, &00, &c0, &c8, &00, &14
    equb &28, &3c, &50, &64, &78, &8c, &a0, &b4
    equb &30, &60, &f0, &c0, &c0, &00, &30, &60
    equb &90, &c0, &f0, &20, &50, &80, &b0, &e0
    equb &10, &40, &70, &a0, &d0, &00, &30, &60
    equb &90, &c0, &f0, &20, &50, &80, &b0, &e0
    equb &10, &00, &30, &60, &90, &40, &70, &a0
    equb &d0, &a0, &d0, &d0, &d0, &d0, &d0, &d0
    equb &d0, &d0, &d0, &d0, &d0, &d0, &d0, &00
    equb &30, &60, &c0, &90, &f0, &20, &50, &80
    equb &b0, &00, &24, &29, &2e, &33, &38, &3d
    equb &42, &47, &4c, &10, &60, &6c, &78, &cf
; High bytes of the sprite data addresses, indexed by sprite number.
; &1b58 used as index base 1 time by &3047
.sprite_addr_hi
    equb &2d, &2d, &2d, &2d, &2d, &2d, &2e, &2e
    equb &19, &2e, &2e, &2e, &2f, &2f, &2f, &2f
    equb &2f, &2c, &2c, &2c, &2c, &04, &2b, &2b
    equb &2b, &2b, &04, &29, &2c, &2a, &2a, &2a
    equb &2a, &2a, &2a, &2a, &2a, &2a, &2a, &2a
    equb &29, &29, &0a, &29, &2b, &23, &23, &23
    equb &23, &23, &23, &24, &24, &24, &24, &24
    equb &25, &25, &25, &25, &25, &26, &26, &26
    equb &26, &26, &26, &27, &27, &27, &27, &27
    equb &28, &17, &17, &17, &17, &28, &28, &28
    equb &28, &22, &22, &21, &21, &21, &21, &21
    equb &21, &21, &21, &21, &21, &21, &21, &0a
    equb &0a, &0a, &0a, &0a, &19, &1a, &1a, &1a
    equb &1a, &18, &18, &18, &18, &18, &18, &18
    equb &18, &18, &18, &12, &18, &18, &18, &04
; Sprite widths in screen bytes, indexed by sprite number.
; &1bd0 used as index base 3 times by &2009, &205f, &304c
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
; &1c48 used as index base 4 times by &2015, &201a, &206c, &3051
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
;    carried, if any, in its place; hero_key_dropped makes them skip the next frame, so
;    one who stays on the cell swaps back on the frame after.
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
; &1cc0 referenced 1 time by &464d
.update_game
    jsr move_heroes                     ; Move the heroes: steps, shots, magic, pick-ups
; Doors: for each hero, find a door at the cell they last stepped or tried to step into, and open it if they carry its key.
    ldx #0                              ; For each hero, 0-3...
; &1cc5 referenced 1 time by &44ff
.check_doors
    stx scratch                         ; ...hero number in scratch, for the door's points
    lda hero_door_x,x                   ; The cell hero X last stepped or bumped into...
    sta cell_x                          ; ...is the cell to test
    lda hero_door_y,x                   ; ...and its y...
    sta cell_y                          ; ...is the cell's y
    txa                                 ; Keep the hero's number...
    pha                                 ; ...on the stack for the key check
    ldx #max_door                       ; Doors 20 to 1: is one in that cell?
; &1cd8 referenced 1 time by &44f5
.check_door
    lda door_x,x                        ; This door's x (&FF once opened)...
    cmp cell_x                          ; ...the cell being tested?
    beq check_door_cell_y               ; Yes: check its y
    jmp next_door                       ; No: next door
; &1ce3 referenced 1 time by &441e
.check_door_cell_y
    lda door_y,x                        ; This door's y (&FF once opened)...
    cmp cell_y                          ; ...the cell being tested?
    beq check_door_key                  ; Yes: the hero has walked into this door
    jmp next_door                       ; No: next door
; &1cee referenced 1 time by &4429
.check_door_key
    pla                                 ; Does the hero carry this door's key?
    tay                                 ; Y = the hero's number...
    pha                                 ; ...kept on the stack
    txa                                 ; A = the door's number: key n opens door n
    cmp hero_key,y                      ; Is it the number of the key the hero carries?
    beq open_door                       ; Yes: open door
    jmp next_door                       ; No key, or the wrong one: the door stays shut
; The hero has the key: score 7, sound the door, erase it, clear its wall bit, and use up the key.
; &1cfa referenced 1 time by &4435
.open_door
    txa                                 ; Open the door: 7 points...
    pha                                 ; Keep the door's number...
    tya                                 ; ...and the hero's...
    pha                                 ; ...on the stack
    ldy #7                              ; Seven points, one per add_point call
    ldx scratch                         ; ...X = the hero who opened the door, for add_point
; &1d03 referenced 1 time by &444b
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
; &1db2 referenced 3 times by &4420, &442b, &4437
.next_door
    dex                                 ; Next door down, 20 to 1
    beq doors_done                      ; Doors all checked: this hero is done
    jmp check_door                      ; Otherwise check the next door
; &1db8 referenced 1 time by &44f3
.doors_done
    pla                                 ; Recover the hero number pushed at check_doors...
    tax                                 ; ...into X, to move on from this hero
; &1dba referenced 1 time by &44ef
.next_hero_doors
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four heroes done?
    beq draw_keys                       ; Yes: on to the keys
    jmp check_doors                     ; No: check this hero against the doors
; Keys. Redraw the keys on the floor, then for each hero: drop a dead hero's key where they fell, or pick up the key at the hero's cell, leaving any key carried in its place. The swap flag only skips the frame after a swap, so a hero who stays on the cell swaps back on the frame after that.
; &1dc2 referenced 1 time by &44fd
.draw_keys
    lda #0                              ; Redraw every key lying on the floor, 20 to 1
    sta plot_offset_x                   ; ...on their cells: no pixel offset...
    sta plot_offset_y                   ; ...across or down: keys sit squarely in cells
    lda #spr_key                        ; ...in the key sprite...
    sta sprite_number                   ; ...as the sprite to plot
    ldx #max_key                        ; ...counting keys down from 20; entry 0 is never drawn
; &1dce referenced 1 time by &4522
.draw_each_key
    lda key_x,x                         ; The key's x...
    sta cell_x                          ; ...is the column to plot at...
    lda key_y,x                         ; ...and y (off the map if it is carried)...
    sta cell_y                          ; ...the row: plot_at_cell needs both each time
    txa                                 ; Keep the key number...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Plot it in every view showing its cell
    pla                                 ; Recover the key number...
    tax                                 ; ...into X, counting down the keys
    dex                                 ; Next key down
    bne draw_each_key                   ; More keys: draw the next
    ldx #0                              ; For each hero, from hero 0...
; &1de6 referenced 1 time by &460b
.check_hero_keys
    lda hero_direction,x                ; Still in play (a direction set)?
    bne check_key_swap                  ; Yes: look for a key to pick up
    lda hero_key,x                      ; Out of play: dead, dying or gone. Holding a key?
    bne check_death_finished            ; Yes: see whether the death has played out
    jmp next_hero_keys                  ; No key: nothing to do for this hero
; &1df3 referenced 1 time by &452e
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
; &1e28 referenced 2 times by &4529, &4538
.check_key_swap
    lda hero_key_dropped,x              ; Swapped keys on the last frame?
    beq check_key_cell                  ; No: look for a key at the hero's cell
    lda #0                              ; Yes: skip this frame, clearing the flag
    sta hero_key_dropped,x              ; ...so next frame's check may swap again
    jmp next_hero_keys                  ; ...and move on to the next hero
; Look for a key at the hero's cell, keys 20 to 1; the first found is picked up.
; &1e35 referenced 1 time by &456b
.check_key_cell
    lda hero_x,x                        ; Is there a key at the hero's cell? Its x...
    sta cell_x                          ; ...in cell_x, for each key's x to match...
    lda hero_y,x                        ; ...and the hero's y...
    sta cell_y                          ; ...in cell_y, for each key's y
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack while X counts the keys
    ldx #max_key                        ; ...keys 20 to 1; entry 0 is never picked up
; &1e45 referenced 1 time by &4601
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
; The swap: the key carried (or unused entry 0) goes on the floor here, the new one is carried and taken off the map, and hero_key_dropped makes the next frame pass this hero by.
    txa                                 ; Drop the key carried (if any) in this cell...
    pha                                 ; ...keeping the new key's number on the stack...
    ldx hero_key,y                      ; ...the old key, or unseen entry 0 if none...
    lda hero_x,y                        ; ...goes to the hero's x...
    sta key_x,x                         ; ...as its x...
    lda hero_y,y                        ; ...and the hero's y...
    sta key_y,x                         ; ...as its y
    pla                                 ; Recover the new key's number...
    tax                                 ; ...into X, and in A to carry
    sta hero_key,y                      ; ...and carry the new one
    lda #1                              ; Mark the swap
    sta hero_key_dropped,y              ; ...so the dropped key is left alone next frame
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
; &1ebe referenced 2 times by &458b, &4593
.next_key
    dex                                 ; Next key down, 20 to 1
    beq keys_done                       ; Keys all checked: this hero is done
    jmp check_key                       ; Otherwise check the next key
; &1ec4 referenced 1 time by &45ff
.keys_done
    pla                                 ; Recover the hero number pushed at check_key_cell...
    tax                                 ; ...into X, to move on from this hero
; &1ec6 referenced 4 times by &4530, &4565, &4572, &45fb
.next_hero_keys
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four heroes done?
    beq update_rest                     ; Yes: on with the rest of the frame
    jmp check_hero_keys                 ; No: check this hero's keys
; The rest of the frame: objects, missiles, monsters, then the pause key.
; &1ece referenced 1 time by &4609
.update_rest
    jsr draw_objects                    ; Draw the objects over the floor
    jsr move_missiles                   ; Move the missiles a cell each
    jsr update_monsters                 ; Move the monsters
; The pause key, last in each frame's update. OSBYTE &7A reports a single key, so P is seen only when the scan finds it rather than another key held with it. Play resumes as soon as P is pressed again; if it is still held at the next frame's check, the game pauses again.
    lda #osbyte_scan_keyboard_from_16   ; OSBYTE &7A: which key is held, if any?
    jsr osbyte                          ; Scan keyboard from key 16
    cpx #&37 ; '7'                      ; P (internal key &37)?
    bne not_paused                      ; No: on with play
; &1ee0 referenced 1 time by &4625
.wait_pause_release
    jsr osbyte                          ; Paused: wait for P to be released...  Scan keyboard from key 16
    cpx #&37 ; '7'                      ; ...is P still the key held?
    beq wait_pause_release              ; Yes: keep waiting
; &1ee7 referenced 1 time by &462c
.wait_pause_press
    jsr osbyte                          ; ...then pressed again  Scan keyboard from key 16
    cpx #&37 ; '7'                      ; ...is P held again yet?
    bne wait_pause_press                ; No: stay paused
    lda #&10                            ; Next frame in 17 vsyncs, not the usual 3...
    sta os_vsync_counter                ; ...about a third of a second before play resumes
; &1ef3 referenced 1 time by &461e
.not_paused
    rts                                 ; Return to play_level: this frame's update is done
    equb &f9, &60                       ; Not referenced
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00   ; Zeros
; ***************************************************************************************
; Unused
;
; Four &3C bytes, "<<<<", which nothing reads.
    equs "<<<<"                         ; Not referenced
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
; &1f00 referenced 7 times by &2023, &2037, &208e, &35a5, &4643, &46db, &472f
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
; &1f17 referenced 1 time by &466b
.count_heroes_in_play
    lda hero_direction - 1,x            ; In play (a direction set)?
    bne check_exit                      ; Yes: the level goes on
    lda hero_health_tens - 1,x          ; Out of play: dead...
    cmp #spr_digit_0 - 1                ; ...(health tens digit below 0)...
    bne next_hero_in_play               ; No: alive but out of play; next hero
    lda hero_frame - 1,x                ; ...with the death animation unfinished?
    cmp #8                              ; ...frame 8 is the last of the death
    bcc check_exit                      ; Yes: the level goes on
; &1f2a referenced 1 time by &4661
.next_hero_in_play
    dex                                 ; Next hero down (X is the hero + 1)
    bne count_heroes_in_play            ; More heroes: check the next
    ldx shrunk_hero                     ; The level is over: restore the last exiting hero's sprites
    bmi play_level_done                 ; None (&FF): nothing to restore
    jsr restore_hero_sprites            ; Give them back their full-size sprites
; &1f35 referenced 1 time by &4670
.play_level_done
    rts                                 ; Return, perhaps into this loop at &1F8E
; Look for a hero on the exit. The first found leaves their key beside it, leaves play and the map, and starts down; the exit is hidden off the map until they have gone.
; &1f36 referenced 3 times by &4653, &465a, &4668
.check_exit
    ldx #0                              ; Is a hero on the exit? From hero 0
; &1f38 referenced 1 time by &46d4
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
; &1f91 referenced 2 times by &467e, &4686
.next_hero_exit
    inx                                 ; Next hero, 0 to 3
    cpx #4                              ; All four heroes checked?
    bne check_hero_on_exit              ; No: check the next
; The descent, one step a frame while exit_busy is set: redraw the exit, then the hero on it a quarter turn on, at the size and offsets for this turn.
; &1f96 referenced 1 time by &46ce
.check_exit_busy
    lda exit_busy                       ; A hero going down the exit?
    bne redraw_exit                     ; Yes: draw this frame of the descent
    jmp play_level                      ; No: next frame
; &1f9e referenced 1 time by &46d9
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
; &1ff2 referenced 1 time by &4708
.next_turn
    lda #&ff                            ; Start the next turn from facing up
    sta exit_spin                       ; ...-1, so the next frame's +2 gives 1
    dec exit_shrinks_left               ; Fourth turn done?
    beq restore_exit                    ; Yes: the hero has gone; bring the exit back
    clc                                 ; Shrink sprites base + 1 to + 7: a byte narrower...
    lda hero_sprites,x                  ; ...the hero's sprite base...


    ; Copy the newly assembled block of code back to it's proper place in the binary
    ; file.
    ; (Note the parameter order: 'copyblock <start>,<end>,<dest>')
    copyblock &08c0, *, &3000

    ; Clear the area of memory we just temporarily used to assemble the new block,
    ; allowing us to assemble there again if needed
    clear &08c0, &2000

    ; Set the program counter to the next position in the binary file.
    org &3000 + (* - &08c0)


    org &51b0

; Move 2: &51b0 to &0400 for length 1024
    org &0400
; ***************************************************************************************
; Add 1000 to a hero's score
;
; Carry a point into the thousands of hero X's score. add_ten_points calls it whenever
; the hundreds digit passes 9, and on return its draw_score redraws the four large digits
; (thousands to units) in the hero's panel section. The panel has room for only those
; four, so when the thousands digit passes 9 it goes back to 0 and the ten-thousands
; digit (hero_score_ten_thousands, a small digit sprite) goes up. That digit sticks at 9,
; so beyond 99,999 the large digits wrap while the small one stays at 9. Each change of
; the ten-thousands digit is drawn at draw_ten_thousands: the small digit &18 rows below
; the hero's panel row, under the score, followed by four of sprite &71. Sprite &71, the
; small 8, is a solid bar two pixels wide, the same shape a small 0 would have, so the
; line reads as a small N0000. remove_absent_heroes enters at draw_ten_thousands with the
; digit in A, to redraw the line on the fresh screen of each level. Uses plot_x, plot_y
; and sprite_number.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &0400 referenced 1 time by &72b9
.add_thousand_points
    inc hero_score_thousands,x          ; One more thousand: the hundreds digit carried
    lda hero_score_thousands,x          ; ...and check the new digit
    cmp #spr_digit_9 + 1                ; Past 9: another ten thousand?
    bne add_thousand_points_done        ; No: return; draw_score shows the new digit
    lda #spr_digit_0                    ; Yes: thousands 0...
    sta hero_score_thousands,x          ; ...stored for this hero
    inc page6_score_ten_thousands,x     ; ...and carry into the small ten-thousands digit
    lda page6_score_ten_thousands,x     ; ...and check the new digit
    cmp #spr_small_digit_9 + 1          ; Past small 9: a score of 100,000?
    bne draw_ten_thousands              ; No: draw it under the score
    lda #spr_small_digit_9              ; Yes: it sticks at 9
    sta page6_score_ten_thousands,x     ; ...stored for this hero
; &041e referenced 2 times by &51c7, &5472
.draw_ten_thousands
    sta sprite_number                   ; Plot the ten-thousands digit under the score...
    lda #panel_left                     ; ...at the panel's left column
    sta plot_x                          ; ...as the plot column
    lda workspace_template + 208,x      ; ...hero_panel_y, read from workspace_template
    clc                                 ; ...(carry clear for the add)
    adc #&18                            ; ...+ &18: below the score's rows, &0C-&15
    sta plot_y                          ; ...as the plot row
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack while plotting
    jsr plot_sprite                     ; Plot the ten-thousands digit
    lda #spr_small_digit_8              ; ...then four small 0s after it: sprite &71...
    sta sprite_number                   ; ...(small 8, a solid bar, the shape of a small 0)
    ldy #4                              ; ...four of them, for the 0000
; &0437 referenced 1 time by &51f3
.draw_ten_thousands_loop
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack while plotting
    inc plot_x                          ; Two byte columns right...
    inc plot_x                          ; ...a small digit's width on
    jsr plot_sprite                     ; Plot a 0 there
    pla                                 ; Recover the count...
    tay                                 ; ...of 0s still to plot, in Y
    dey                                 ; One fewer 0 to plot
    bne draw_ten_thousands_loop         ; More 0s: loop
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again, as on entry
; &0447 referenced 1 time by &51b8
.add_thousand_points_done
    rts                                 ; Return to draw_score (or remove_absent_heroes)
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
; ***************************************************************************************
; Decrypt and check the level just loaded
;
; Decrypt the level at &6B00-&6DAF in place, XORing each byte with the low byte of its
; own address, and sum the decrypted bytes. If the sum does not match the level's entry
; in level_checksums, call &D9CD, the reset entry of MOS 1.20, so a damaged or altered
; level file is never played. It runs once per level, as soon as the level file is in
; memory and before unpack_level copies it into the game's tables; it returns only if the
; level is intact, leaving it decrypted at &6B00. The pointer and the sum borrow the
; plotter's zero-page workspace (plot_x and plot_y, sprite_width), which nothing is using
; while a level loads.
;
; On Entry:
;     LEVEL_NUMBER: level loaded (1-25)
; &0450 referenced 1 time by &3b86
.decrypt_level
    ldy #0                              ; Point at &6B00, the start of the level...
    sty plot_x                          ; ...low byte 0, in plot_x (the pointer's low half)
    sty sprite_width                    ; Checksum 0, kept in sprite_width
    lda #>(level_object_x)              ; High byte &6B: the level buffer's page
    sta plot_y                          ; ...in plot_y (the pointer's high half)
; &045a referenced 2 times by &521f, &5225
.decrypt_level_loop
    lda (plot_x),y                      ; Fetch a level byte...
    eor plot_x                          ; ...XOR it with the low byte of its address...
    sta (plot_x),y                      ; ...and store it back decrypted
    clc                                 ; Add the decrypted byte to the checksum...
    adc sprite_width                    ; ...plus the sum so far
    sta sprite_width                    ; ...as the new sum, modulo 256
    inc plot_x                          ; Advance the pointer to the next level byte...
    bne decrypt_level_next              ; No carry: same page
    inc plot_y                          ; ...with carry into the high byte
; &046b referenced 1 time by &5217
.decrypt_level_next
    lda plot_x                          ; Stop at &6DB0, the end of the level...
    cmp #<(level_file_end)              ; ...low byte &B0?
    bne decrypt_level_loop              ; No: decrypt the next byte
    lda plot_y                          ; ...and high byte &6D?
    cmp #>(level_file_end)              ; ...(the end page)
    bne decrypt_level_loop              ; No: decrypt the next byte
    ldx level_number                    ; X = the level just loaded (1-25)
    lda sprite_width                    ; Compare the checksum...
    cmp level_checksums,x               ; ...with this level's entry in the table
    beq decrypt_level_done              ; Match: the level is intact; return
    jsr mos_reset_entry                 ; No match: reset the machine (a MOS 1.20 address)
; &0484 referenced 1 time by &522f
.decrypt_level_done
    rts                                 ; Return: the level at &6B00 is decrypted and intact
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
; &0490 used as index base 2 times by &522c, &562c
.level_checksums
    equb &00                            ; Entry 0: there is no level 0, so never read
; ***************************************************************************************
; Level checksums
;
; One byte per level, 1-25, indexed by level_number from level_checksums (whose entry 0
; is unused): the sum, modulo 256, of the level's &2B0 decrypted bytes, which
; decrypt_level checks before the level is played.
    equb &62, &cd, &0c, &44, &4d
    equb &22, &f6, &42, &21, &7d
    equb &5d, &d8, &a0, &f1, &0f
    equb &cc, &d3, &53, &3b, &83
    equb &71, &b2, &6f, &f3, &f1        ; Levels 1-25, five to a row
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
    equb &00, &00, &00, &00, &00        ; Zeros
; Data of sprite &15, &1A, &77: 4 bytes x 12 rows.
.sprite_blank
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00                            ; Not referenced
; ***************************************************************************************
; Choose the heroes and the sound
;
; The screen before each game where the players choose who plays. It is called once per
; game, when a new game starts, after reset_hero has given every hero their starting
; attributes and before the first level. Set a text window the full width of the screen
; (MODE 2's 20 columns) and clear it, print the menu (print_menu) and read keys until
; SPACE. Keys 1-4 toggle a hero between YES and NO by flipping their hero_absent flag and
; rewriting the menu entry; 5 and 6 switch the sound on and off with OSBYTE &D2. After
; each change the whole menu is reprinted. SPACE returns, so the game starts, only if at
; least one hero is playing. Before each key is read, the keyboard buffer is flushed and
; CAPS LOCK is forced on with SHIFT LOCK off.
;
; Neither hero_absent nor the menu text is set up here: the menu opens with whatever they
; held, which after a game over in the same load is the last game's choices. The ON/OFF
; entry shows only what was last chosen on the menu, not the sound suppression actually
; in force. hero_absent is read by remove_absent_heroes at each level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &0500 referenced 1 time by &3551
.hero_menu
    lda #&1c                            ; VDU 28: the menu's window, the screen's full width...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
    lda #&16                            ; Bottom row of the window
    jsr oswrch                          ; Send the bottom row
    lda #&13                            ; Right column 19, MODE 2's last
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Send VDU 12: clear the window
    jsr print_menu                      ; Print the menu
    jmp menu_key_loop                   ; Read keys until the players start the game
; ***************************************************************************************
; Print the menu text
;
; Print the sixteen positioned strings of menu_text, in their current state, through
; print_menu_string: fifteen in a loop and the sixteenth by falling into
; print_menu_string, whose return is this routine's. Called by hero_menu to show the menu
; and after every change.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &0524 referenced 3 times by &52ce, &5373, &53a0
.print_menu
    ldx #&0f                            ; Fifteen strings, then one more by falling through
    ldy #0                              ; Y walks through menu_text from its start
; &0528 referenced 1 time by &52dc
.print_menu_loop
    jsr print_menu_string               ; Print one menu string
    dex                                 ; One fewer to print
    bne print_menu_loop                 ; More to print: loop
; ***************************************************************************************
; Print one menu string
;
; Move the text cursor to the column and row in the two bytes at menu_text+Y, then print
; the following characters up to and including a carriage return.
;
; On Entry:
;     Y: offset of the string in menu_text
;
; On Exit:
;     Y: offset of the next string
; &052e referenced 1 time by &52d8
.print_menu_string
    lda #&1f                            ; VDU 31: move the text cursor...
    jsr oswrch                          ; Send VDU 31
    lda menu_text,y                     ; ...to the string's column...
    jsr oswrch                          ; Send the column
    iny                                 ; Step to the row byte
    lda menu_text,y                     ; ...and the string's row...
    jsr oswrch                          ; Send the row
; &0540 referenced 1 time by &52f9
.print_menu_string_loop
    iny                                 ; Print the characters...
    lda menu_text,y                     ; ...the next character...
    jsr oswrch                          ; ...sent to the screen...
    cmp #&0d                            ; ...up to and including the carriage return
    bne print_menu_string_loop          ; Not the CR yet: next character
    iny                                 ; Point at the next string
    rts                                 ; Return with Y at the next string's column byte
; ***************************************************************************************
; Change a menu entry to NO
;
; Write "NO " over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; off. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
; &054d referenced 1 time by &5370
.set_menu_no
    lda #'N'                            ; "NO ": N first...
    sta menu_text,y                     ; ...into the entry's first letter
    lda #'O'                            ; ...then O...
    sta menu_text + 1,y                 ; ...into the second letter
    lda #' '                            ; A space third, over YES's S...
    sta menu_text + 2,y                 ; ...into the third letter
    rts                                 ; Return: the entry reads NO
; ***************************************************************************************
; Change a menu entry to YES
;
; Write "YES" over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; on. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
; &055d referenced 1 time by &536a
.set_menu_yes
    lda #'Y'                            ; "YES": Y first...
    sta menu_text,y                     ; ...into the entry's first letter
    lda #'E'                            ; ...then E...
    sta menu_text + 1,y                 ; ...into the second letter
    lda #'S'                            ; ...then S...
    sta menu_text + 2,y                 ; ...into the third letter
    rts                                 ; Return: the entry reads YES
; ***************************************************************************************
; Change the sound entry to OFF
;
; Write "FF" at menu_text+Y, after the sound entry's "O", when key 6 turns the sound off.
;
; On Entry:
;     Y: offset of the entry's second character
; &056d referenced 1 time by &5394
.set_menu_off
    lda #'F'                            ; "FF" after the O
    sta menu_text,y                     ; ...over the N of ON...
    sta menu_text + 1,y                 ; ...and the space after it
    rts                                 ; Return: the entry reads OFF
; ***************************************************************************************
; Change the sound entry to ON
;
; Write "N " at menu_text+Y, after the sound entry's "O", when key 5 turns the sound on.
;
; On Entry:
;     Y: offset of the entry's second character
; &0576 referenced 1 time by &538d
.set_menu_on
    lda #'N'                            ; "N " after the O
    sta menu_text,y                     ; ...over OFF's first F
    lda #' '                            ; ...then a space...
    sta menu_text + 1,y                 ; ...over OFF's second F
    rts                                 ; Return: the entry reads ON
; Read one key and act on it, then come back for the next, until SPACE starts the game.
; &0581 referenced 6 times by &52d1, &5348, &534c, &5376, &5383, &53a3
.menu_key_loop
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard any keys already waiting  Flush selected class of buffer
    lda #osbyte_kbd_status              ; OSBYTE &CA: set the keyboard lock states...
    ldx #&20 ; ' '                      ; X = &20: CAPS LOCK on, SHIFT LOCK off
    ldy #0                              ; Y = 0: replace the status with X
    jsr osbyte                          ; Set it, whatever the Ranger's lock keys left  osbyte: kbd status
    jsr osrdch                          ; Wait for a key
    cmp #' '                            ; SPACE, to start the game?
    beq menu_space                      ; Yes: start, if anyone is playing
    cmp #'1'                            ; Ignore anything but 1-6
    bcc menu_key_loop                   ; Below '1': ignore it
    cmp #'7'                            ; ...or above '6' (at or past '7')?
    bcs menu_key_loop                   ; Yes: ignore it
    sec                                 ; Key number 0-5 = key - '1'...
    sbc #'1'                            ; ...so keys '1'-'6' become 0-5...
    tax                                 ; ...in X: a hero 0-3, or 4-5 for the sound
    cmp #4                              ; Key 5 or 6?
    bcs menu_sound_key                  ; Yes: the sound switch
; Keys 1-4: switch hero X between playing and absent, and show it as YES or NO.
    asl a                               ; 1-4: Y = offset of the hero's YES/NO, 6 x X + &51...
    sta plot_x                          ; Keep 2 x the hero number
    asl a                               ; 4 x the hero number...
    clc                                 ; ...(carry clear for the add)
    adc plot_x                          ; ...+ 2 x: 6 x the hero number
    adc #&51 ; 'Q'                      ; ...+ &51: this hero's YES/NO text
    tay                                 ; Y = its offset in menu_text
    lda hero_absent,x                   ; Toggle the hero between playing and absent...
    eor #1                              ; ...by flipping the absent flag
    sta hero_absent,x                   ; ...the hero's new absent flag
    bne menu_hero_off                   ; Now absent (flag 1)?
    jsr set_menu_yes                    ; No: playing, so the entry reads YES
    jmp menu_reprint                    ; ...and reprint the menu
; &05c0 referenced 1 time by &5368
.menu_hero_off
    jsr set_menu_no                     ; Absent: the entry reads NO
; &05c3 referenced 1 time by &536d
.menu_reprint
    jsr print_menu                      ; Reprint the menu with the change
    jmp menu_key_loop                   ; Wait for the next key
; SPACE: return, so the game starts, if at least one hero is playing; otherwise ignore it.
; &05c9 referenced 1 time by &5344
.menu_space
    ldx #3                              ; SPACE: is any hero playing?
; &05cb referenced 1 time by &5381
.menu_space_check_hero
    lda hero_absent,x                   ; Is this hero playing (absent flag 0)?
    beq menu_done                       ; Yes: return, and the game starts
    dex                                 ; Absent: try the previous hero
    bpl menu_space_check_hero           ; Heroes left to check: loop
    jmp menu_key_loop                   ; Nobody playing: ignore SPACE
; &05d6 referenced 1 time by &537e
.menu_done
    rts                                 ; Return: the game goes on to its first level
; Keys 5 and 6: sound on or off, through OSBYTE &D2, and the menu's entry to match.
; &05d7 referenced 1 time by &5354
.menu_sound_key
    ldy #&99                            ; Sound: Y = offset of the second letter of ON/OFF
    cmp #5                              ; Key 6 (A = key - "1")?
    beq menu_sound_off                  ; Yes: sound off
    jsr set_menu_on                     ; Key 5: ON...
    ldx #0                              ; ...with X = 0 to enable the sound
    beq menu_set_sound                  ; Always: set the sound
; &05e4 referenced 1 time by &538b
.menu_sound_off
    jsr set_menu_off                    ; Key 6: OFF...
    ldx #1                              ; ...with X = 1 to suppress it
; &05e9 referenced 1 time by &5392
.menu_set_sound
    lda #osbyte_sound_suppression       ; OSBYTE &D2: sound suppression
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Turn the sound on or off as chosen  osbyte: sound suppression
    jsr print_menu                      ; Reprint the menu with the change
    jmp menu_key_loop                   ; Wait for the next key
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &4f                       ; Not referenced
; The hero menu: sixteen strings, each a text column and row followed by the characters and a carriage return. The YES/NO and ON/OFF entries are rewritten as the players toggle them.
; ***************************************************************************************
; Hero menu text
;
; Sixteen entries of: column, row, text, carriage return; printed in order by print_menu,
; each at its own text position. The four heroes' YES/NO entries (text at menu_text + &51
; + 6 x hero) are rewritten by set_menu_yes and set_menu_no, and the sound entry's ON/OFF
; (second letter at menu_text + &99) by set_menu_on and set_menu_off, so the table holds
; the players' choices as well as showing them.
; &0600 used as index base 7 times by &52e3, &52ea, &52f1, &52ff, &530f, &531f, &5328
.menu_text
; &53b1 used as index base 8 times by &5304, &5314, &5322, &532d, &5704, &5714, &5722, &572d
    equb &06, &00                       ; Column 6, row 0
; &0602 used as index base 4 times by &5309, &5319, &5709, &5719
    equs "DUNJUNZ", &0d
    equb &00, &02                       ; Column 0, row 2
    equs "HERO", &0d
    equb &0c, &02                       ; Column 12, row 2
    equs "PLAYING", &0d
    equb &00, &04                       ; Column 0, row 4
    equs "1 RANGER", &0d
    equb &00, &05                       ; Column 0, row 5
    equs "2 MAGIC-USER", &0d
    equb &00, &06                       ; Column 0, row 6
    equs "3 BARBARIAN", &0d
    equb &00, &07                       ; Column 0, row 7
    equs "4 FIGHTER", &0d
    equb &0e, &04                       ; Column 14, row 4
    equs "YES", &0d
    equb &0e, &05                       ; Column 14, row 5
    equs "YES", &0d
    equb &0e, &06                       ; Column 14, row 6
    equs "YES", &0d
    equb &0e, &07                       ; Column 14, row 7
    equs "YES", &0d
    equb &00, &09                       ; Column 0, row 9
    equs "TYPE NUMBER", &0d
    equb &00, &0a                       ; Column 0, row 10
    equs "TO TOGGLE", &0d
    equb &00, &0d                       ; Column 0, row 13
    equs "SOUND ON(5) OFF(6)", &0d
    equb &07, &0f                       ; Column 7, row 15
    equs "ON ", &0d
    equb &03, &14                       ; Column 3, row 20
    equs "SPACE TO PLAY", &0d
    equb &00, &0d, &a9, &63             ; Not referenced
; ***************************************************************************************
; Take the heroes nobody plays out of the level
;
; The last step of setting up each level, called by level_loop after draw_status_panel
; and just before play_level. For each hero in turn:
;
; First redraw the small ten-thousands line under the score, if it has one (through
; draw_ten_thousands), since start_level cleared the screen and draw_status_panel draws
; only the four large digits.
;
; Then, if the hero was switched off on the menu (hero_absent), take them out of play,
; since reset_workspace has just given every hero their starting state: direction 0;
; step_out_of_play, so move_heroes passes over them; frame 8 and dead health, so that
; play_level treats them as dead with their death animation over, and level_loop counts
; them among the dead (and resets them) when the level ends; map x &1F; and a
; nobody_returns entry in returning_hero_queue, which reset_monsters has just emptied.
; The absent heroes' entries go at the front of the queue, in hero order; a Cross of
; Resurrection sends such an entry to the back and takes the next. Their panel section
; keeps the health and score just drawn.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &06b0 referenced 1 time by &359d
.remove_absent_heroes
    ldx #0                              ; Hero 0 first...
    ldy #0                              ; ...Y = the queue entry for the next absent hero
; &06b4 referenced 1 time by &54a3
.remove_absent_heroes_loop
    lda hero_score_ten_thousands,x      ; Score of 10000 or more?
    cmp #spr_small_digit_1              ; ...ten-thousands sprite small 1 or above?
    bcc remove_absent_heroes_check      ; No: nothing under the score; check absence
    txa                                 ; Yes: redraw it, lost when the screen was cleared
    pha                                 ; Keep the hero number...
    tya                                 ; ...and the queue entry...
    pha                                 ; ...on the stack
    lda hero_score_ten_thousands,x      ; The digit's sprite...
    jsr draw_ten_thousands              ; ...drawn under the score with its 0000
    pla                                 ; Recover the queue entry...
    tay                                 ; ...for the next absent hero, in Y
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again
; Take the hero out of play if nobody is playing them, so that they count as dead, and a Cross of Resurrection passes over their queue entry.
; &06c9 referenced 1 time by &5469
.remove_absent_heroes_check
    lda hero_absent,x                   ; Switched off on the menu?
    beq remove_absent_heroes_next       ; No: playing; next hero
    lda #0                              ; Yes: take them out of play...
    sta hero_direction,x                ; ...direction 0: not in play
    lda #step_out_of_play               ; ...step &63, so move_heroes passes them over...
    sta hero_step,x                     ; ...as the hero's step count
    lda #8                              ; ...frame 8: their death animation is over...
    sta hero_frame,x                    ; ...as the hero's frame
    lda #spr_digit_0 - 1                ; ...health tens below 0: dead...
    sta hero_health_tens,x              ; ...as the health tens digit
    dec hero_score_units,x              ; ...units back below 0, undoing the panel's point
    lda #&1f                            ; ...map x &1F, the dungeon's last column...
    sta hero_x,x                        ; ...as the hero's map x
    lda #nobody_returns                 ; ...and a nobody_returns entry in the queue...
    sta returning_hero_queue,y          ; ...which a Cross of Resurrection skips
    iny                                 ; The next absent hero takes the next entry
; &06f0 referenced 1 time by &547c
.remove_absent_heroes_next
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four heroes done?
    bne remove_absent_heroes_loop       ; No: next hero
    rts                                 ; Return to level_loop: the level is ready to play
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00                       ; Zeros
; Each hero's score ten-thousands digit where add_thousand_points still keeps it, at its cassette address. Every other routine uses hero_score_ten_thousands at &08B0, and Coder reloads this page for every level, so the digit is lost between levels.
; &06f8 used as index base 3 times by &51bf, &51c2, &51cb
.page6_score_ten_thousands
    equs "iiii"
    equb &00, &00, &00, &00             ; Not referenced
; Leftover contents of the MOS 1.20 line-input buffer (&0700) from the machine the image was saved on.
; ***************************************************************************************
; Leftovers in the line-input buffer
;
; Not used by the game. &0700 is the MOS 1.20 line-input buffer, and these bytes are what
; it held when this image was saved: the command *SA. DANK 400+3FF 740, then a fragment
; of BBC BASIC assembler (label+2:LDA#255:.label JSR&30).
.line_buffer_leftovers
    equs "*SA. DANK 400+3FF 740"
    equb &0d, &0d                       ; Not referenced
    equs "740"
    equb &0d                            ; Not referenced
    equb &0d, &54, &50, &0d, &0d, &50, &0d  ; Not referenced
    equs "Alabel+2:LDA#255:.label JSR&30"
; ***************************************************************************************
; Load the game file and run it (not used)
;
; Build an OSFILE control block at &6B00 naming boot_filename with load address &2000,
; call the filing system's FILEV handler to load the file, and jump to &2000. &0740 is
; the execution address in the *SAVE command left at &0700, so this is the image's own
; entry point when it is *RUN, but nothing in this release reaches it.
.boot_loader
    ldx #<(boot_osfile_block)           ; X/Y = &6B00, the control block...
    ldy #>(boot_osfile_block)           ; ...Y = &6B, its page
    lda #<(boot_filename)               ; Filename address: boot_filename...
    sta boot_osfile_block               ; ...into the block's filename pointer, low byte
    lda #>(boot_filename)               ; ...boot_filename's high byte
    sta boot_osfile_block + 1           ; ...into the filename pointer's high byte
    lda #0                              ; Load address &00002000...
    sta boot_osfile_block + 2           ; ...load address byte 0 = 0
    sta boot_osfile_block + 4           ; ...byte 2 = 0
    sta boot_osfile_block + 5           ; ...byte 3 = 0
    lda #&20 ; ' '                      ; ...byte 1 = &20
    sta boot_osfile_block + 3           ; ...so the file loads at &00002000
    lda filev                           ; Copy FILEV into the JSR below...
    sta boot_load_call + 1              ; ...FILEV low byte into the JSR's operand
    lda filev + 1                       ; ...FILEV high byte
    sta boot_load_call + 2              ; ...so the JSR calls the filing system directly
    lda #&ff                            ; OSFILE &FF: load the file at the block's address
.boot_load_call
; &551d referenced 1 time by &5511
; &551e referenced 1 time by &5517
    jsr &3000                           ; Call FILEV (operand patched above)
    jmp &2000                           ; Enter the loaded game at &2000
    equb &00, &00, &00, &00             ; Not referenced
    equb &00                            ; Not referenced
; &0777 referenced 1 time by &591b
    equb &00                            ; Not referenced
; &0778 referenced 1 time by &5921
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00                  ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00   ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00   ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00  ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00                            ; Not referenced
    equb &00, &00, &00                  ; Not referenced
    equb &00, &00, &00, &00, &00, &00, &00  ; Not referenced
; Name of the file boot_loader loads, CR-terminated.
; ***************************************************************************************
; Name of the file boot_loader loads
.boot_filename
    equs "Dun1"
    equb &0d, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00             ; Not referenced


    ; Copy the newly assembled block of code back to it's proper place in the binary
    ; file.
    ; (Note the parameter order: 'copyblock <start>,<end>,<dest>')
    copyblock add_thousand_points, *, &51b0

    ; Clear the area of memory we just temporarily used to assemble the new block,
    ; allowing us to assemble there again if needed
    clear add_thousand_points, &0800

    ; Set the program counter to the next position in the binary file.
    org &51b0 + (* - add_thousand_points)


    org &55b0

; Move 3: &55b0 to &0400 for length 1024
    org &0400
; ***************************************************************************************
; Add 1000 to a hero's score
;
; Carry a point into the thousands of hero X's score. add_ten_points calls it whenever
; the hundreds digit passes 9, and on return its draw_score redraws the four large digits
; (thousands to units) in the hero's panel section. The panel has room for only those
; four, so when the thousands digit passes 9 it goes back to 0 and the ten-thousands
; digit (hero_score_ten_thousands, a small digit sprite) goes up. That digit sticks at 9,
; so beyond 99,999 the large digits wrap while the small one stays at 9. Each change of
; the ten-thousands digit is drawn at draw_ten_thousands: the small digit &18 rows below
; the hero's panel row, under the score, followed by four of sprite &71. Sprite &71, the
; small 8, is a solid bar two pixels wide, the same shape a small 0 would have, so the
; line reads as a small N0000. remove_absent_heroes enters at draw_ten_thousands with the
; digit in A, to redraw the line on the fresh screen of each level. Uses plot_x, plot_y
; and sprite_number.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &0400 referenced 1 time by &72b9
.add_thousand_points_joystick
    inc hero_score_thousands,x          ; One more thousand: the hundreds digit carried
    lda hero_score_thousands,x          ; ...and check the new digit
    cmp #spr_digit_9 + 1                ; Past 9: another ten thousand?
    bne add_thousand_points_done_joystick  ; No: return; draw_score shows the new digit
    lda #spr_digit_0                    ; Yes: thousands 0...
    sta hero_score_thousands,x          ; ...stored for this hero
    inc page6_score_ten_thousands_joystick,x  ; ...and carry into the small ten-thousands digit
    lda page6_score_ten_thousands_joystick,x  ; ...and check the new digit
    cmp #spr_small_digit_9 + 1          ; Past small 9: a score of 100,000?
    bne draw_ten_thousands_joystick     ; No: draw it under the score
    lda #spr_small_digit_9              ; Yes: it sticks at 9
    sta page6_score_ten_thousands_joystick,x  ; ...stored for this hero
; &041e referenced 2 times by &55c7, &5872
.draw_ten_thousands_joystick
    sta sprite_number                   ; Plot the ten-thousands digit under the score...
    lda #panel_left                     ; ...at the panel's left column
    sta plot_x                          ; ...as the plot column
    lda workspace_template + 208,x      ; ...hero_panel_y, read from workspace_template
    clc                                 ; ...(carry clear for the add)
    adc #&18                            ; ...+ &18: below the score's rows, &0C-&15
    sta plot_y                          ; ...as the plot row
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack while plotting
    jsr plot_sprite                     ; Plot the ten-thousands digit
    lda #spr_small_digit_8              ; ...then four small 0s after it: sprite &71...
    sta sprite_number                   ; ...(small 8, a solid bar, the shape of a small 0)
    ldy #4                              ; ...four of them, for the 0000
; &0437 referenced 1 time by &55f3
.draw_ten_thousands_loop_joystick
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack while plotting
    inc plot_x                          ; Two byte columns right...
    inc plot_x                          ; ...a small digit's width on
    jsr plot_sprite                     ; Plot a 0 there
    pla                                 ; Recover the count...
    tay                                 ; ...of 0s still to plot, in Y
    dey                                 ; One fewer 0 to plot
    bne draw_ten_thousands_loop_joystick  ; More 0s: loop
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again, as on entry
; &0447 referenced 1 time by &55b8
.add_thousand_points_done_joystick
    rts                                 ; Return to draw_score (or remove_absent_heroes)
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
; ***************************************************************************************
; Decrypt and check the level just loaded
;
; Decrypt the level at &6B00-&6DAF in place, XORing each byte with the low byte of its
; own address, and sum the decrypted bytes. If the sum does not match the level's entry
; in level_checksums, call &D9CD, the reset entry of MOS 1.20, so a damaged or altered
; level file is never played. It runs once per level, as soon as the level file is in
; memory and before unpack_level copies it into the game's tables; it returns only if the
; level is intact, leaving it decrypted at &6B00. The pointer and the sum borrow the
; plotter's zero-page workspace (plot_x and plot_y, sprite_width), which nothing is using
; while a level loads.
;
; On Entry:
;     LEVEL_NUMBER: level loaded (1-25)
; &0450 referenced 1 time by &3b86
.decrypt_level_joystick
    ldy #0                              ; Point at &6B00, the start of the level...
    sty plot_x                          ; ...low byte 0, in plot_x (the pointer's low half)
    sty sprite_width                    ; Checksum 0, kept in sprite_width
    lda #>(level_object_x)              ; High byte &6B: the level buffer's page
    sta plot_y                          ; ...in plot_y (the pointer's high half)
; &045a referenced 2 times by &561f, &5625
.decrypt_level_loop_joystick
    lda (plot_x),y                      ; Fetch a level byte...
    eor plot_x                          ; ...XOR it with the low byte of its address...
    sta (plot_x),y                      ; ...and store it back decrypted
    clc                                 ; Add the decrypted byte to the checksum...
    adc sprite_width                    ; ...plus the sum so far
    sta sprite_width                    ; ...as the new sum, modulo 256
    inc plot_x                          ; Advance the pointer to the next level byte...
    bne decrypt_level_next_joystick     ; No carry: same page
    inc plot_y                          ; ...with carry into the high byte
; &046b referenced 1 time by &5617
.decrypt_level_next_joystick
    lda plot_x                          ; Stop at &6DB0, the end of the level...
    cmp #<(level_file_end)              ; ...low byte &B0?
    bne decrypt_level_loop_joystick     ; No: decrypt the next byte
    lda plot_y                          ; ...and high byte &6D?
    cmp #>(level_file_end)              ; ...(the end page)
    bne decrypt_level_loop_joystick     ; No: decrypt the next byte
    ldx level_number                    ; X = the level just loaded (1-25)
    lda sprite_width                    ; Compare the checksum...
    cmp level_checksums,x               ; ...with this level's entry in the table
    beq decrypt_level_done_joystick     ; Match: the level is intact; return
    jsr mos_reset_entry                 ; No match: reset the machine (a MOS 1.20 address)
; &0484 referenced 1 time by &562f
.decrypt_level_done_joystick
    rts                                 ; Return: the level at &6B00 is decrypted and intact
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
    equb &00                            ; Entry 0: there is no level 0, so never read
; ***************************************************************************************
; Level checksums
;
; One byte per level, 1-25, indexed by level_number from level_checksums (whose entry 0
; is unused): the sum, modulo 256, of the level's &2B0 decrypted bytes, which
; decrypt_level checks before the level is played.
    equb &62, &cd, &0c, &44, &4d
    equb &22, &f6, &42, &21, &7d
    equb &5d, &d8, &a0, &f1, &0f
    equb &cc, &d3, &53, &3b, &83
    equb &71, &b2, &6f, &f3, &f1        ; Levels 1-25, five to a row
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
    equb &00, &00, &00, &00, &00        ; Zeros
; Data of sprite &15, &1A, &77: 4 bytes x 12 rows.
.sprite_blank_joystick
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00, &00, &00, &00
    equb &00                            ; Not referenced
; ***************************************************************************************
; Choose the heroes and the sound
;
; The screen before each game where the players choose who plays. It is called once per
; game, when a new game starts, after reset_hero has given every hero their starting
; attributes and before the first level. Set a text window the full width of the screen
; (MODE 2's 20 columns) and clear it, print the menu (print_menu) and read keys until
; SPACE. Keys 1-4 toggle a hero between YES and NO by flipping their hero_absent flag and
; rewriting the menu entry; 5 and 6 switch the sound on and off with OSBYTE &D2. After
; each change the whole menu is reprinted. SPACE returns, so the game starts, only if at
; least one hero is playing. Before each key is read, the keyboard buffer is flushed and
; CAPS LOCK is forced on with SHIFT LOCK off.
;
; Neither hero_absent nor the menu text is set up here: the menu opens with whatever they
; held, which after a game over in the same load is the last game's choices. The ON/OFF
; entry shows only what was last chosen on the menu, not the sound suppression actually
; in force. hero_absent is read by remove_absent_heroes at each level.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &0500 referenced 1 time by &3551
.hero_menu_joystick
    lda #&1c                            ; VDU 28: the menu's window, the screen's full width...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
    lda #&16                            ; Bottom row of the window
    jsr oswrch                          ; Send the bottom row
    lda #&13                            ; Right column 19, MODE 2's last
    jsr oswrch                          ; Send the right column
    lda #0                              ; Top row 0
    jsr oswrch                          ; Send the top row
    lda #&0c                            ; ...VDU 12 to clear it
    jsr oswrch                          ; Send VDU 12: clear the window
    jsr print_menu_joystick             ; Print the menu
    jmp menu_key_loop_joystick          ; Read keys until the players start the game
; ***************************************************************************************
; Print the menu text
;
; Print the sixteen positioned strings of menu_text, in their current state, through
; print_menu_string: fifteen in a loop and the sixteenth by falling into
; print_menu_string, whose return is this routine's. Called by hero_menu to show the menu
; and after every change.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &0524 referenced 3 times by &56ce, &5773, &57a0
.print_menu_joystick
    ldx #&0f                            ; Fifteen strings, then one more by falling through
    ldy #0                              ; Y walks through menu_text from its start
; &0528 referenced 1 time by &56dc
.print_menu_loop_joystick
    jsr print_menu_string_joystick      ; Print one menu string
    dex                                 ; One fewer to print
    bne print_menu_loop_joystick        ; More to print: loop
; ***************************************************************************************
; Print one menu string
;
; Move the text cursor to the column and row in the two bytes at menu_text+Y, then print
; the following characters up to and including a carriage return.
;
; On Entry:
;     Y: offset of the string in menu_text
;
; On Exit:
;     Y: offset of the next string
; &052e referenced 1 time by &56d8
.print_menu_string_joystick
    lda #&1f                            ; VDU 31: move the text cursor...
    jsr oswrch                          ; Send VDU 31
    lda menu_text_joystick,y            ; ...to the string's column...
    jsr oswrch                          ; Send the column
    iny                                 ; Step to the row byte
    lda menu_text_joystick,y            ; ...and the string's row...
    jsr oswrch                          ; Send the row
; &0540 referenced 1 time by &56f9
.print_menu_string_loop_joystick
    iny                                 ; Print the characters...
    lda menu_text_joystick,y            ; ...the next character...
    jsr oswrch                          ; ...sent to the screen...
    cmp #&0d                            ; ...up to and including the carriage return
    bne print_menu_string_loop_joystick ; Not the CR yet: next character
    iny                                 ; Point at the next string
    rts                                 ; Return with Y at the next string's column byte
; ***************************************************************************************
; Change a menu entry to NO
;
; Write "NO " over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; off. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
; &054d referenced 1 time by &5770
.set_menu_no_joystick
    lda #'N'                            ; "NO ": N first...
    sta menu_text_joystick,y            ; ...into the entry's first letter
    lda #'O'                            ; ...then O...
    sta menu_text_joystick + 1,y        ; ...into the second letter
    lda #' '                            ; A space third, over YES's S...
    sta menu_text_joystick + 2,y        ; ...into the third letter
    rts                                 ; Return: the entry reads NO
; ***************************************************************************************
; Change a menu entry to YES
;
; Write "YES" over a hero's YES/NO entry at menu_text+Y, when hero_menu switches the hero
; on. print_menu then shows it.
;
; On Entry:
;     Y: offset of the entry
; &055d referenced 1 time by &576a
.set_menu_yes_joystick
    lda #'Y'                            ; "YES": Y first...
    sta menu_text_joystick,y            ; ...into the entry's first letter
    lda #'E'                            ; ...then E...
    sta menu_text_joystick + 1,y        ; ...into the second letter
    lda #'S'                            ; ...then S...
    sta menu_text_joystick + 2,y        ; ...into the third letter
    rts                                 ; Return: the entry reads YES
; ***************************************************************************************
; Change the sound entry to OFF
;
; Write "FF" at menu_text+Y, after the sound entry's "O", when key 6 turns the sound off.
;
; On Entry:
;     Y: offset of the entry's second character
; &056d referenced 1 time by &5794
.set_menu_off_joystick
    lda #'F'                            ; "FF" after the O
    sta menu_text_joystick,y            ; ...over the N of ON...
    sta menu_text_joystick + 1,y        ; ...and the space after it
    rts                                 ; Return: the entry reads OFF
; ***************************************************************************************
; Change the sound entry to ON
;
; Write "N " at menu_text+Y, after the sound entry's "O", when key 5 turns the sound on.
;
; On Entry:
;     Y: offset of the entry's second character
; &0576 referenced 1 time by &578d
.set_menu_on_joystick
    lda #'N'                            ; "N " after the O
    sta menu_text_joystick,y            ; ...over OFF's first F
    lda #' '                            ; ...then a space...
    sta menu_text_joystick + 1,y        ; ...over OFF's second F
    rts                                 ; Return: the entry reads ON
; Read one key and act on it, then come back for the next, until SPACE starts the game.
; &0581 referenced 6 times by &56d1, &5748, &574c, &5776, &5783, &57a3
.menu_key_loop_joystick
    lda #osbyte_flush_buffer_class      ; Flush the input buffers
    jsr osbyte                          ; Discard any keys already waiting  Flush selected class of buffer
    lda #osbyte_kbd_status              ; OSBYTE &CA: set the keyboard lock states...
    ldx #&20 ; ' '                      ; X = &20: CAPS LOCK on, SHIFT LOCK off
    ldy #0                              ; Y = 0: replace the status with X
    jsr osbyte                          ; Set it, whatever the Ranger's lock keys left  osbyte: kbd status
    jsr osrdch                          ; Wait for a key
    cmp #' '                            ; SPACE, to start the game?
    beq menu_space_joystick             ; Yes: start, if anyone is playing
    cmp #'1'                            ; Ignore anything but 1-6
    bcc menu_key_loop_joystick          ; Below '1': ignore it
    cmp #'7'                            ; ...or above '6' (at or past '7')?
    bcs menu_key_loop_joystick          ; Yes: ignore it
    sec                                 ; Key number 0-5 = key - '1'...
    sbc #'1'                            ; ...so keys '1'-'6' become 0-5...
    tax                                 ; ...in X: a hero 0-3, or 4-5 for the sound
    cmp #4                              ; Key 5 or 6?
    bcs menu_sound_key_joystick         ; Yes: the sound switch
; Keys 1-4: switch hero X between playing and absent, and show it as YES or NO.
    asl a                               ; 1-4: Y = offset of the hero's YES/NO, 6 x X + &51...
    sta plot_x                          ; Keep 2 x the hero number
    asl a                               ; 4 x the hero number...
    clc                                 ; ...(carry clear for the add)
    adc plot_x                          ; ...+ 2 x: 6 x the hero number
    adc #&51 ; 'Q'                      ; ...+ &51: this hero's YES/NO text
    tay                                 ; Y = its offset in menu_text
    lda hero_absent,x                   ; Toggle the hero between playing and absent...
    eor #1                              ; ...by flipping the absent flag
    sta hero_absent,x                   ; ...the hero's new absent flag
    bne menu_hero_off_joystick          ; Now absent (flag 1)?
    jsr set_menu_yes_joystick           ; No: playing, so the entry reads YES
    jmp menu_reprint_joystick           ; ...and reprint the menu
; &05c0 referenced 1 time by &5768
.menu_hero_off_joystick
    jsr set_menu_no_joystick            ; Absent: the entry reads NO
; &05c3 referenced 1 time by &576d
.menu_reprint_joystick
    jsr print_menu_joystick             ; Reprint the menu with the change
    jmp menu_key_loop_joystick          ; Wait for the next key
; SPACE: return, so the game starts, if at least one hero is playing; otherwise ignore it.
; &05c9 referenced 1 time by &5744
.menu_space_joystick
    ldx #3                              ; SPACE: is any hero playing?
; &05cb referenced 1 time by &5781
.menu_space_check_hero_joystick
    lda hero_absent,x                   ; Is this hero playing (absent flag 0)?
    beq menu_done_joystick              ; Yes: return, and the game starts
    dex                                 ; Absent: try the previous hero
    bpl menu_space_check_hero_joystick  ; Heroes left to check: loop
    jmp menu_key_loop_joystick          ; Nobody playing: ignore SPACE
; &05d6 referenced 1 time by &577e
.menu_done_joystick
    rts                                 ; Return: the game goes on to its first level
; Keys 5 and 6: sound on or off, through OSBYTE &D2, and the menu's entry to match.
; &05d7 referenced 1 time by &5754
.menu_sound_key_joystick
    ldy #&99                            ; Sound: Y = offset of the second letter of ON/OFF
    cmp #5                              ; Key 6 (A = key - "1")?
    beq menu_sound_off_joystick         ; Yes: sound off
    jsr set_menu_on_joystick            ; Key 5: ON...
    ldx #0                              ; ...with X = 0 to enable the sound
    beq menu_set_sound_joystick         ; Always: set the sound
; &05e4 referenced 1 time by &578b
.menu_sound_off_joystick
    jsr set_menu_off_joystick           ; Key 6: OFF...
    ldx #1                              ; ...with X = 1 to suppress it
; &05e9 referenced 1 time by &5792
.menu_set_sound_joystick
    lda #osbyte_sound_suppression       ; OSBYTE &D2: sound suppression
    ldy #0                              ; Y = 0: replace the setting with X
    jsr osbyte                          ; Turn the sound on or off as chosen  osbyte: sound suppression
    jsr print_menu_joystick             ; Reprint the menu with the change
    jmp menu_key_loop_joystick          ; Wait for the next key
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &4f                       ; Not referenced
; The hero menu: sixteen strings, each a text column and row followed by the characters and a carriage return. The YES/NO and ON/OFF entries are rewritten as the players toggle them.
; ***************************************************************************************
; Hero menu text
;
; Sixteen entries of: column, row, text, carriage return; printed in order by print_menu,
; each at its own text position. The four heroes' YES/NO entries (text at menu_text + &51
; + 6 x hero) are rewritten by set_menu_yes and set_menu_no, and the sound entry's ON/OFF
; (second letter at menu_text + &99) by set_menu_on and set_menu_off, so the table holds
; the players' choices as well as showing them.
; &0600 used as index base 7 times by &56e3, &56ea, &56f1, &56ff, &570f, &571f, &5728
.menu_text_joystick
    equb &06, &00                       ; Column 6, row 0
; &0602 used as index base 4 times by &5309, &5319, &5709, &5719
    equs "DUNJUNZ", &0d
    equb &00, &02                       ; Column 0, row 2
    equs "HERO", &0d
    equb &0c, &02                       ; Column 12, row 2
    equs "PLAYING", &0d
    equb &00, &04                       ; Column 0, row 4
    equs "1 RANGER", &0d
    equb &00, &05                       ; Column 0, row 5
    equs "2 MAGIC-USER", &0d
    equb &00, &06                       ; Column 0, row 6
    equs "3 BARBARIAN", &0d
    equb &00, &07                       ; Column 0, row 7
    equs "4 FIGHTER", &0d
    equb &0e, &04                       ; Column 14, row 4
    equs "YES", &0d
    equb &0e, &05                       ; Column 14, row 5
    equs "YES", &0d
    equb &0e, &06                       ; Column 14, row 6
    equs "YES", &0d
    equb &0e, &07                       ; Column 14, row 7
    equs "YES", &0d
    equb &00, &09                       ; Column 0, row 9
    equs "TYPE NUMBER", &0d
    equb &00, &0a                       ; Column 0, row 10
    equs "TO TOGGLE", &0d
    equb &00, &0d                       ; Column 0, row 13
    equs "SOUND ON(5) OFF(6)", &0d
    equb &07, &0f                       ; Column 7, row 15
    equs "ON ", &0d
    equb &03, &14                       ; Column 3, row 20
    equs "SPACE TO PLAY", &0d
    equb &00, &0d, &a9, &63             ; Not referenced
; ***************************************************************************************
; Take the heroes nobody plays out of the level
;
; The last step of setting up each level, called by level_loop after draw_status_panel
; and just before play_level. For each hero in turn:
;
; First redraw the small ten-thousands line under the score, if it has one (through
; draw_ten_thousands), since start_level cleared the screen and draw_status_panel draws
; only the four large digits.
;
; Then, if the hero was switched off on the menu (hero_absent), take them out of play,
; since reset_workspace has just given every hero their starting state: direction 0;
; step_out_of_play, so move_heroes passes over them; frame 8 and dead health, so that
; play_level treats them as dead with their death animation over, and level_loop counts
; them among the dead (and resets them) when the level ends; map x &1F; and a
; nobody_returns entry in returning_hero_queue, which reset_monsters has just emptied.
; The absent heroes' entries go at the front of the queue, in hero order; a Cross of
; Resurrection sends such an entry to the back and takes the next. Their panel section
; keeps the health and score just drawn.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &06b0 referenced 1 time by &359d
.remove_absent_heroes_joystick
    ldx #0                              ; Hero 0 first...
    ldy #0                              ; ...Y = the queue entry for the next absent hero
; &06b4 referenced 1 time by &58a3
.remove_absent_heroes_loop_joystick
    lda hero_score_ten_thousands,x      ; Score of 10000 or more?
    cmp #spr_small_digit_1              ; ...ten-thousands sprite small 1 or above?
    bcc remove_absent_heroes_check_joystick  ; No: nothing under the score; check absence
    txa                                 ; Yes: redraw it, lost when the screen was cleared
    pha                                 ; Keep the hero number...
    tya                                 ; ...and the queue entry...
    pha                                 ; ...on the stack
    lda hero_score_ten_thousands,x      ; The digit's sprite...
    jsr draw_ten_thousands_joystick     ; ...drawn under the score with its 0000
    pla                                 ; Recover the queue entry...
    tay                                 ; ...for the next absent hero, in Y
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again
; Take the hero out of play if nobody is playing them, so that they count as dead, and a Cross of Resurrection passes over their queue entry.
; &06c9 referenced 1 time by &5869
.remove_absent_heroes_check_joystick
    lda hero_absent,x                   ; Switched off on the menu?
    beq remove_absent_heroes_next_joystick  ; No: playing; next hero
    lda #0                              ; Yes: take them out of play...
    sta hero_direction,x                ; ...direction 0: not in play
    lda #step_out_of_play               ; ...step &63, so move_heroes passes them over...
    sta hero_step,x                     ; ...as the hero's step count
    lda #8                              ; ...frame 8: their death animation is over...
    sta hero_frame,x                    ; ...as the hero's frame
    lda #spr_digit_0 - 1                ; ...health tens below 0: dead...
    sta hero_health_tens,x              ; ...as the health tens digit
    dec hero_score_units,x              ; ...units back below 0, undoing the panel's point
    lda #&1f                            ; ...map x &1F, the dungeon's last column...
    sta hero_x,x                        ; ...as the hero's map x
    lda #nobody_returns                 ; ...and a nobody_returns entry in the queue...
    sta returning_hero_queue,y          ; ...which a Cross of Resurrection skips
    iny                                 ; The next absent hero takes the next entry
; &06f0 referenced 1 time by &587c
.remove_absent_heroes_next_joystick
    inx                                 ; Next hero, 0-3
    cpx #4                              ; All four heroes done?
    bne remove_absent_heroes_loop_joystick  ; No: next hero
    rts                                 ; Return to level_loop: the level is ready to play
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00                       ; Zeros
; Each hero's score ten-thousands digit where add_thousand_points still keeps it, at its cassette address. Every other routine uses hero_score_ten_thousands at &08B0, and Coder reloads this page for every level, so the digit is lost between levels.
; &06f8 used as index base 3 times by &55bf, &55c2, &55cb
.page6_score_ten_thousands_joystick
    equs "iiii"
    equb &00, &00, &00, &00             ; Not referenced
; Leftover contents of the MOS 1.20 line-input buffer (&0700) from the machine the image was saved on.
; ***************************************************************************************
; Leftovers in the line-input buffer
;
; Not used by the game. &0700 is the MOS 1.20 line-input buffer, and these bytes are what
; it held when this image was saved: the command *SA. Control 400+3FF, then a fragment of
; BBC BASIC assembler (label+2:LDA#255:.label JSR&30).
.line_buffer_leftovers_joystick
    equs "*SA. Control 400+3FF"
    equb &0d, &0d, &0d                  ; Not referenced
    equs "740"
    equb &0d                            ; Not referenced
    equb &0d, &54, &50, &0d, &0d, &50, &0d  ; Not referenced
    equs "Alabel+2:LDA#255:.label JSR&30"
; ***************************************************************************************
; Load the game file and run it (not used)
;
; Point BYTEV at joystick_bytev (&0780), then build an OSFILE control block at &6B00
; naming boot_filename with load address &2000, call the filing system's FILEV handler to
; load the file, and jump to &2000. &0740 is the execution address in the *SAVE command
; left at &0700, so this is the image's own entry point when it is *RUN, but nothing in
; this release reaches it.
.boot_loader_joystick
    lda #<(joystick_bytev)              ; BYTEV = &0780, joystick_bytev...
    sta bytev                           ; ...joystick_bytev's low byte into BYTEV
    lda #>(joystick_bytev)              ; ...its high byte
    sta bytev + 1                       ; ...so INKEY scans reach the joystick handler
    ldx #<(boot_osfile_block)           ; X/Y = &6B00, the control block...
    ldy #>(boot_osfile_block)           ; ...Y = &6B, its page
    lda #<(boot_filename_joystick)      ; Filename address: boot_filename...
    sta boot_osfile_block               ; ...into the block's filename pointer, low byte
    lda #>(boot_filename_joystick)      ; ...boot_filename's high byte
    sta boot_osfile_block + 1           ; ...into the filename pointer's high byte
    lda #0                              ; Load address &00002000...
    sta boot_osfile_block + 2           ; ...load address byte 0 = 0
    sta boot_osfile_block + 4           ; ...byte 2 = 0
    sta boot_osfile_block + 5           ; ...byte 3 = 0
    lda #&20 ; ' '                      ; ...byte 1 = &20
    sta boot_osfile_block + 3           ; ...so the file loads at &00002000
    lda filev                           ; Copy FILEV into the JSR below...
    sta boot_load_call_joystick + 1     ; ...FILEV low byte into the JSR's operand
    lda filev + 1                       ; ...FILEV high byte
    sta boot_load_call_joystick + 2     ; ...so the JSR calls the filing system directly
    lda #&ff                            ; OSFILE &FF: load the file at the block's address
.boot_load_call_joystick
; &5927 referenced 1 time by &591b
; &5928 referenced 1 time by &5921
    jsr &3000                           ; Call FILEV (operand patched above)
    jmp &2000                           ; Enter the loaded game at &2000
    equb &00, &00, &00, &00             ; Not referenced
; ***************************************************************************************
; BYTEV handler: read a joystick for the Barbarian's keys
;
; Installed on BYTEV by Coder, in the joystick image of &0400-&07FF only. Answers
; test_key's OSBYTE &81 scans of the Barbarian's (hero 2's) keys from the analogue port,
; so that a joystick plays the Barbarian: left (. &98) and right (/ &97) from channel 1,
; up (K &B9) and down (, &99) from channel 2, and fire (SPACE &9D) from either fire
; button. A direction counts only at the stick's extreme, when the channel's high byte is
; &FF or 0, so the stick works as a switch. Every other call goes to the MOS 1.20 OSBYTE
; routine at &E772 directly, skipping any other BYTEV claimant. The handler's own OSBYTE
; &80 reads come back through BYTEV into it and are passed on the same way. The
; Barbarian's five keys are never scanned while it is installed, so that hero can be
; played only with the joystick. test_key counts a key as held only when X and Y both
; come back &FF, so a not-pressed answer needs only X = 0.
;
; On Entry:
;     A: OSBYTE number
;     X: OSBYTE X
;
; On Exit:
;     X: &FF if the key is pressed, 0 if not
;     Y: &FF if the key is pressed
.joystick_bytev
    cmp #&81                            ; OSBYTE &81 (INKEY)?
    bne joystick_pass_on                ; No: let the MOS handle it
    cpx #inkey_key_full_stop            ; The Barbarian's left key (.)?
    beq joystick_left                   ; Yes: read the stick for left
    cpx #inkey_key_comma                ; The Barbarian's down key (,)?
    beq joystick_down                   ; Yes: read the stick for down
    cpx #inkey_key_k                    ; The Barbarian's up key (K)?
    beq joystick_up                     ; Yes: read the stick for up
    cpx #inkey_key_slash                ; The Barbarian's right key (/)?
    beq joystick_right                  ; Yes: read the stick for right
    cpx #inkey_key_space                ; The Barbarian's fire key (SPACE)?
    beq joystick_fire                   ; Yes: read the fire buttons
    jmp mos_osbyte_default              ; Any other key: scan the keyboard as usual
; &079b referenced 1 time by &5936
.joystick_left
    ldx #1                              ; Left: channel 1 high byte &FF?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #&ff                            ; ...high byte &FF: pushed fully left?
    bne joystick_not_pressed            ; No: not pressed
    ldx #&ff                            ; Yes: pressed (Y is already &FF)
    rts                                 ; Return X = Y = &FF: left is pressed
; &07a9 referenced 1 time by &5942
.joystick_right
    ldx #1                              ; Right: channel 1 high byte 0?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #0                              ; ...high byte 0: pushed fully right?
    bne joystick_not_pressed            ; No: not pressed
    dey                                 ; Yes: pressed (Y = &FF)
    ldx #&ff                            ; ...X = Y = &FF, as INKEY reports a key held
    rts                                 ; Return X = Y = &FF: right is pressed
; &07b8 referenced 1 time by &593e
.joystick_up
    ldx #2                              ; Up: channel 2 high byte &FF?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #&ff                            ; ...high byte &FF: pushed fully up?
    bne joystick_not_pressed            ; No: not pressed
    ldx #&ff                            ; Yes: pressed (Y is already &FF)
    rts                                 ; Return X = Y = &FF: up is pressed
; &07c6 referenced 1 time by &593a
.joystick_down
    ldx #2                              ; Down: channel 2 high byte 0?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...with OSBYTE &80, reading the ADC
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #0                              ; ...high byte 0: pushed fully down?
    bne joystick_not_pressed            ; No: not pressed
    dey                                 ; Yes: pressed (Y = &FF)
    ldx #&ff                            ; ...X = Y = &FF, as INKEY reports a key held
    rts                                 ; Return X = Y = &FF: down is pressed
; &07d5 referenced 1 time by &5946
.joystick_fire
    ldx #0                              ; Fire: either fire button?
    lda #osbyte_read_adc_or_get_buffer_status  ; ...OSBYTE &80, X = 0: the fire buttons in X
    jsr osbyte                          ; Read ADC channel X or buffer status
    txa                                 ; ...the button bits...
    and #3                              ; ...bits 0-1: either button held?
    beq joystick_not_pressed            ; No: not pressed
    ldx #&ff                            ; Yes: X = &FF, fire pressed...
    ldy #&ff                            ; ...X = Y = &FF, as INKEY reports a key held
    rts                                 ; Return X = Y = &FF: fire is pressed
; &07e6 referenced 5 times by &5954, &5962, &5971, &597f, &598f
.joystick_not_pressed
    ldx #0                              ; Not pressed: X = 0, which test_key reads as not held
    rts                                 ; Return X = 0: the key is not pressed
; &07e9 referenced 1 time by &5932
.joystick_pass_on
    jmp mos_osbyte_default              ; Not INKEY: on to the MOS 1.20 OSBYTE routine
    equb &00, &00, &00, &00             ; Not referenced
; Name of the file boot_loader loads, CR-terminated.
; ***************************************************************************************
; Name of the file boot_loader loads
.boot_filename_joystick
    equs "Dun1"
    equb &0d, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00             ; Not referenced


    ; Copy the newly assembled block of code back to it's proper place in the binary
    ; file.
    ; (Note the parameter order: 'copyblock <start>,<end>,<dest>')
    copyblock add_thousand_points_joystick, *, &55b0

    ; Clear the area of memory we just temporarily used to assemble the new block,
    ; allowing us to assemble there again if needed
    clear add_thousand_points_joystick, &0800

    ; Set the program counter to the next position in the binary file.
    org &55b0 + (* - add_thousand_points_joystick)


    org &2000

.dasmos_start
    adc #1                              ; ...+1: their first sprite...
    tay                                 ; ...in Y, for the height loop...
    tax                                 ; ...and in X, for the width loop
    adc #7                              ; ...+7: stop before base + 8, left frame 1
    sta scratch                         ; ...kept as the end
; &2009 referenced 1 time by &2010
.shrink_hero_width
    dec sprite_widths,x                 ; One byte (two pixels) narrower
    inx                                 ; Next of the hero's seven sprites
    cpx scratch                         ; Reached the end?
    bne shrink_hero_width               ; No: narrow the next
    tya                                 ; Three rows shorter...
    tax                                 ; ...from the first sprite again
; &2014 referenced 1 time by &2021
.shrink_hero_height
    sec                                 ; ...set carry to subtract
    lda sprite_heights,x                ; This sprite's height...
    sbc #3                              ; ...less three rows...
    sta sprite_heights,x                ; ...stored back in sprite_heights
    inx                                 ; Next of the hero's seven sprites
    cpx scratch                         ; Reached the end?
    bne shrink_hero_height              ; No: shorten the next
    jmp play_level                      ; ...three rows shorter. Next frame
; The hero has gone: put the exit back.
; &2026 referenced 1 time by &473a
.restore_exit
    lda exit_saved_x                    ; Put the exit back where it was...
    sta exit_x                          ; ...exit_saved_x back as its x...
    lda exit_saved_y                    ; ...and its saved y...
    sta exit_y                          ; ...as its y, so the next hero can use it
    lda #0                              ; ...and end the animation
    sta exit_busy                       ; ...exit no longer busy
    jmp play_level                      ; Next frame: the descent is over
; ***************************************************************************************
; Start a hero going down the exit
;
; Start hero X's descent: the hero spins on the exit for four turns, shrinking after each
; of the first three. Called by play_level's check_exit for a hero who has just stepped
; onto the exit, after drop_key, and after the hero has been taken out of play and the
; exit hidden off the map.
;
; queue_exit_marker plays the exit sound and puts a nobody_returns marker in
; returning_hero_queue, as remove_absent_heroes does for a hero nobody plays. Any hero
; shrunk on an earlier descent (shrunk_hero) gets their full-size sprites back, as the
; sprites are shared with no copy. Then exit_busy is set, exiting_hero and shrunk_hero
; become X, exit_spin starts at -1 (the first frame's +2 gives the up-facing sprite) and
; exit_shrinks_left at 4; play_level's redraw_exit runs the spin from the next frame.
;
; It ends by jumping to play_level rather than returning, so its return address (into
; check_exit at &1F8E) stays on the stack until the level ends; see play_level.
;
; On Entry:
;     X: hero number (0-3)
; &203a referenced 1 time by &46cb
.hero_enters_exit
    stx scratch2                        ; Keep the hero number
    jsr queue_exit_marker               ; Sound the exit; mark the hero queue
    lda #4                              ; exit_offsets_x entry 0 = 4...
    sta exit_offsets_x                  ; ...never read: shrinks run from 4 down to 1
    ldx shrunk_hero                     ; Restore the sprites of any hero shrunk before
    bmi start_hero_animation            ; None (&FF): go straight on
    jsr restore_hero_sprites            ; Give that hero back their full-size sprites
    jmp start_hero_animation            ; ...then start this hero's spin
; ***************************************************************************************
; Restore a hero's sprite sizes
;
; Give hero X back their full-size sprites after the exit animation has shrunk them. The
; descent narrows sprites base + 1 to base + 7 (base from hero_sprites) by a byte and
; shortens them by three rows after each of three turns, in sprite_widths and
; sprite_heights themselves. This sets the seven back to a whole cell, 4 bytes wide and
; 12 rows high, which is what every hero's walking sprites measure. Called by
; hero_enters_exit, before the next hero's descent shrinks their own sprites, and by
; play_level when the level ends, each time for shrunk_hero.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: 12
;     X: base + 1
;     Y: base + 8
; &2050 referenced 2 times by &204a, &4672
.restore_hero_sprites
    clc                                 ; The hero's sprites base + 1 to base + 7
    lda hero_sprites,x                  ; ...the hero's sprite base...
    adc #1                              ; ...+1: their first sprite...
    tax                                 ; ...in X, kept to restart Y for the heights...
    tay                                 ; ...and in Y, to walk the widths
    adc #7                              ; ...+7: stop before base + 8, left frame 1
    sta scratch                         ; ...kept as the end
    lda #4                              ; Widths back to 4 bytes, a whole cell...
; &205f referenced 1 time by &2066
.restore_sprite_widths
    sta sprite_widths,y                 ; Sprite Y back to 4 bytes wide
    iny                                 ; Next of the seven, base + 1 to base + 7
    cpy scratch                         ; Reached the end?
    bne restore_sprite_widths           ; No: widen the next
    txa                                 ; ...from the first sprite again...
    tay                                 ; ...in Y, to walk the heights
    lda #&0c                            ; ...heights back to 12 rows, a whole cell
; &206c referenced 1 time by &2073
.restore_sprite_heights
    sta sprite_heights,y                ; Sprite Y back to 12 rows high
    iny                                 ; Next of the seven
    cpy scratch                         ; Reached the end?
    bne restore_sprite_heights          ; No: restore the next
    rts                                 ; Return with the hero's sprites full size again
; Set up the descent for the hero kept in scratch2.
; &2076 referenced 2 times by &2048, &204d
.start_hero_animation
    lda #1                              ; Start the animation for this hero...
    sta exit_busy                       ; ...the exit is busy...
    lda scratch2                        ; ...the hero kept by hero_enters_exit...
    sta exiting_hero                    ; ...is the one going down...
    sta shrunk_hero                     ; ...and the one whose sprites will shrink
    lda #&ff                            ; ...turning from the start...
    sta exit_spin                       ; ...-1, so the first frame's +2 gives 1
    lda #4                              ; ...for four turns, shrinking after the first three
    sta exit_shrinks_left               ; ...in exit_shrinks_left, counting turns 4 to 1
    jmp play_level                      ; Back to play_level, leaving the JSR's return address
; ***************************************************************************************
; Drop the key a hero carries
;
; Leave hero X's key behind beside the exit, so the heroes still playing can use it.
; Called by play_level's check_exit as the hero steps onto the exit, before they are
; taken out of play.
;
; find_open_neighbour picks the first wall-free cell of those above, right of and below
; the hero, or else the cell to the left whatever it holds; another key or an object may
; already lie there. The key's key_x/key_y are set to that cell, so update_game's
; draw_keys shows it from the next frame; hero_key is cleared and the key icon erased
; from the hero's panel section. A hero with no key moves key entry 0, which is never
; drawn or picked up.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &2091 referenced 1 time by &4688
.drop_key
    lda hero_x,x                        ; From the hero's cell (the exit)...
    sta cell_x                          ; ...is where the search starts: x...
    lda hero_y,x                        ; ...and the hero's y...
    sta cell_y                          ; ...and y
    txa                                 ; ...find a wall-free cell next to it
    pha                                 ; Keep the hero number...
    jsr find_open_neighbour             ; ...on the stack across the search
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, to find the key they carry
    ldy hero_key,x                      ; Put the hero's key there (entry 0 if none)
    lda cell_x                          ; ...the free cell's x...
    sta key_x,y                         ; ...as the key's x...
    lda cell_y                          ; ...and its y...
    sta key_y,y                         ; ...as the key's y
    lda #0                              ; The hero carries no key
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
    tax                                 ; ...into X, preserved for check_exit
    rts                                 ; Return with the key on the floor beside the exit
; ***************************************************************************************
; Find a free cell next to a cell
;
; Find where drop_key, its only caller, can put down a key next to the exit. Starting
; from cell_x, cell_y, try the cells above, to the right and below, in that order,
; through test_wall, and leave cell_x, cell_y on the first without a wall; failing all
; three, leave them on the cell to the left without testing it, so a key can land in a
; wall there. Only walls are tested, not keys, objects or creatures. map_ptr is left
; pointing at the room of the last cell tested.
;
; On Entry:
;     CELL_X: cell x
;     CELL_Y: cell y
;
; On Exit:
;     CELL_X: x of the first free neighbour, trying above, right and below; otherwise the cell to the left, unchecked
;     CELL_Y: its y
;     Y: 0 if a free neighbour was found
;     A: corrupted
;     X: corrupted
; &20d0 referenced 1 time by &209f
.find_open_neighbour
    dec cell_y                          ; Try the cell above first
    jsr test_wall                       ; ...is there a wall in it?
    cpy #0                              ; Y = 0 if no wall there
    bne try_cell_right                  ; Wall: try the cell to the right
    rts                                 ; No wall: leave cell_x, cell_y on it
; &20db referenced 1 time by &20d8
.try_cell_right
    inc cell_y                          ; Then the cell to the right
    inc cell_x                          ; ...x + 1 (y back to the starting row)
    jsr test_wall                       ; ...is there a wall in it?
    cpy #0                              ; Y = 0 if no wall there
    bne try_cell_below                  ; Wall: try the cell below
    rts                                 ; No wall: leave cell_x, cell_y on it
; &20e9 referenced 1 time by &20e6
.try_cell_below
    dec cell_x                          ; Then the cell below
    inc cell_y                          ; ...y + 1 (x back to the starting column)
    jsr test_wall                       ; ...is there a wall in it?
    cpy #0                              ; Y = 0 if no wall there
    bne try_cell_left                   ; Wall: fall back on the cell to the left
    rts                                 ; No wall: leave cell_x, cell_y on it
; &20f7 referenced 1 time by &20f4
.try_cell_left
    dec cell_y                          ; Otherwise the cell to the left
    dec cell_x                          ; ...x - 1: unchecked, the last resort
    rts                                 ; Return, Y non-zero
    equb &01, &3f                       ; Not referenced
; Map of the cells that cannot hold an object, in the same layout as room_walls, from the level file: a bit is clear where an object lies (and on a few other cells), so the object list need only be searched when a hero steps onto a clear bit.
; &2100 used as index base 1 time by &3cad
.object_free_map
    equb &00, &02, &07, &07, &1f, &3f, &7d, &7f, &00, &30, &78, &fd, &7f, &ff, &80, &00  ; Not read: unpack_level copies each level's object-free map here
    equb &00, &60, &e0, &c0, &df, &c0, &1f, &0f, &00, &58, &58, &58, &d8, &18, &f8, &80  ; ...entries 16-31, not read
    equb &76, &3e, &5f, &6e, &7e, &00, &7f, &7f, &00, &66, &66, &7e, &7e, &66, &66, &00  ; ...entries 32-47, not read
    equb &1f, &1f, &03, &03, &ff, &03, &03, &03, &80, &80, &80, &80, &80, &f6, &fe, &f6  ; ...entries 48-63, not read
    equb &7f, &00, &3f, &2f, &37, &37, &2f, &37, &c0, &03, &c4, &86, &40, &00, &80, &c1  ; ...entries 64-79, not read
    equb &03, &e3, &e0, &e1, &41, &41, &00, &ff, &fe, &fe, &00, &00, &00, &00, &00, &8a  ; ...entries 80-95, not read
    equb &00, &00, &00, &00, &7e, &7f, &7e, &00, &01, &01, &01, &3f, &3f, &bf, &3f, &3f  ; ...entries 96-111, not read
    equb &f7, &ff, &c1, &f7, &c1, &ff, &f7, &bf, &8e, &9e, &de, &9c, &9e, &8e, &8e, &80  ; ...entries 112-127, not read
    equb &7e, &3e, &7e, &00, &7c, &7a, &7e, &00, &2f, &1f, &00, &00, &00, &ce, &ae, &5e  ; ...entries 128-143, not read
    equb &1f, &1f, &1f, &1b, &17, &1f, &00, &01, &80, &80, &80, &80, &80, &80, &02, &02  ; ...entries 144-159, not read
    equb &7e, &7a, &7e, &00, &7e, &3e, &7f, &00, &be, &0e, &0e, &0f, &0e, &0e, &be, &00  ; ...entries 160-175, not read
    equb &01, &01, &0f, &df, &07, &03, &01, &00, &08, &08, &5a, &fe, &fe, &fc, &b8, &00  ; ...entries 176-191, not read
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00  ; ...entries 192-200, not read
    equb &08, &2a, &00, &00, &00, &00, &00  ; Not referenced
; Data of sprite &53, &54, &55, &56, &57, &58, &59, &5A, &5B, &5C, &5D, &5E: 4 bytes x 12 rows.
.sprite_drainer
    equb &11, &33, &33, &22
    equb &33, &33, &33, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &ff, &c0, &33
    equb &33, &33, &33, &33
    equb &11, &33, &33, &22
; Map x of each door (entries 1-20).
; &2200 used as index base 4 times by &3c6c, &4418, &44cb, &77fe
.door_x
    equb &ff, &ff, &ff, &04, &ff, &ff, &06, &ff, &11, &ff, &ff, &ff, &1a, &03, &03, &0b  ; Not read: unpack_level copies each level's doors here
    equb &ff, &03, &09, &12, &ff        ; ...entries 16-20, not read
    equb &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff
    equb &ff, &ff, &ff                  ; Not referenced
; Map y of each door.
; &2220 used as index base 4 times by &3c72, &4423, &44ce, &7804
.door_y
    equb &ff, &ff, &ff, &0d, &ff, &ff, &11, &ff, &16, &ff, &ff, &ff, &1a, &23, &27, &25  ; Not read: unpack_level copies each level's doors here
    equb &ff, &2b, &2e, &2b, &ff        ; ...entries 16-20, not read
    equb &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff
    equb &ff, &ff, &ff                  ; Not referenced
; Sprite of each door.
; &2240 used as index base 2 times by &3c78, &7810
.door_sprite
    equb &ff, &1c, &1c, &1d, &1c, &1c, &1d, &1d, &1d, &1d, &1d, &1c, &1c, &1d, &1d, &1c  ; Not read: unpack_level copies each level's door sprites here
    equb &1d, &1d, &1c, &1c, &ff        ; ...entries 16-20, not read
    equb &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff
    equb &ff, &ff, &ff                  ; Not referenced
; Map x of each key lying on the floor (entries 1-20); key n opens door n.
; &2260 used as index base 7 times by &20aa, &3c83, &450e, &4540, &4585, &45cc, &45e1
.key_x
    equb &13, &ff, &ff, &1b, &ff, &ff, &17, &ff, &1c, &ff, &ff, &ff, &02, &15, &04, &09  ; Not read: unpack_level copies each level's keys here
    equb &ff, &04, &19, &17, &ff        ; ...entries 16-20, not read
    equb &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff
    equb &ff, &ff, &ff                  ; Not referenced
; Map y of each key on the floor.
; &2280 used as index base 7 times by &20b0, &3c89, &4514, &4546, &458d, &45d2, &45e4
.key_y
    equb &25, &ff, &ff, &06, &ff, &ff, &09, &ff, &18, &ff, &ff, &ff, &29, &04, &0c, &14  ; Not read: unpack_level copies each level's keys here
    equb &ff, &0f, &03, &04, &ff        ; ...entries 16-20, not read
    equb &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff
    equb &ff, &ff, &ff                  ; Not referenced
; Data of sprite &51: 4 bytes x 12 rows.
.sprite_exit
    equb &03, &03, &03, &03
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &02, &00, &00, &01
    equb &03, &03, &03, &03
; Data of sprite &52: 2 bytes x 3 rows.
.sprite_key_icon
    equb &00, &05
    equb &0f, &0f
    equb &0f, &05
; ***************************************************************************************
; Unused
;
; Zero bytes, which nothing reads.
    equb &00, &00, &00, &00, &00, &00, &00, &00, &00, &00  ; Zeros
; Number of the key each hero carries, or 0.
; &22e0 used as index base 10 times by &20a4, &20b5, &3cdf, &4432, &44d5, &452b, &453a, &454b, &45c6, &45d7
.hero_key
    equb &00, &00, &00, &00, &00
; Set when the hero has just swapped keys, so the key dropped is not picked straight back up.
; &22e5 used as index base 4 times by &3ce2, &4568, &456f, &45dc
.hero_key_dropped
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00
; Hero map x, kept for the door and key checks.
; &22f0 used as index base 4 times by &37b9, &3ce5, &4408, &6f9b
.hero_door_x
    equb &1a, &09, &00, &16, &00
; Hero map y, kept for the door and key checks.
; &22f5 used as index base 4 times by &37ca, &3ce8, &440e, &6fa1
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
; &2d00 used as index base 1 time by &3cba
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

    org &4740
; ***************************************************************************************
; Unused
;
; Zeros between the stored game core (&3000-&473F) and Coder (&5000).
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Not referenced
; ***************************************************************************************
; Coder: load the game and the next level
;
; Build the game afresh from disc for the next level and start it. Run once per level as
; *CODER: for the first level by *DUNJUNZ, and for each later one by next_level_intercept
; during the reset that ends the level before. It never returns.
;
; Count the level: levels_started and level_digits, the filename's number ("1 " to "25"),
; live in page &08, which the reset leaves alone and *DUNJUNZ resets for a new game.
; Blank the display (6845 register 1 = 0) and silence the VDU, then *LOAD DUN1, which
; holds this code, so the bytes being run are rewritten with identical ones; the reload
; also restores level_command, so the digits go into it only afterwards. Load the level
; file to &6B00, which is screen memory: LEVELnn, or for level 25 STONES at &6680, whose
; last &2B0 bytes are level 25.
;
; Copy one of the two &0400-&07FF images into place: the one with joystick_bytev only if
; ADC channel 1 reads with a high byte of exactly &80. The channel is read again to
; decide whether to point BYTEV at &0780, so if the two reads disagree the image and the
; vector do not match: the joystick image with the MOS's BYTEV, or BYTEV at the keyboard
; image's &0780, which holds zeros (BRK). Show 80 columns and 23 rows again (the level
; file's rows 23-24 stay hidden), then copy the game core: all of &3000-&473F to
; &08C0-&1FFF for the first level, but only from &3440, to &0D00-&1FFF, for later ones,
; so that the heroes' scores and attributes in &08C0-&0CFF carry over. Leave
; levels_started in &8E for game_entry, and jump to it.
;
; Coder uses the game's zero page &70-&73 and &80-&81 for its pointers; nothing there is
; needed until game_entry.
; Set up the machine: ESCAPE off, VDU output on to the screen only, and the BREAK intercept cancelled.
.coder_start
    lda #osbyte_escape_break_effect     ; Disable ESCAPE for the whole game...
    ldx #1                              ; ...X = 1: ESCAPE disabled, BREAK as normal
    ldy #0                              ; ...Y = 0: X replaces the old setting
    jsr osbyte                          ; osbyte: escape break effect
    lda #6                              ; VDU 6, 3: text to the screen, none to a printer
    jsr oswrch                          ; ...VDU 6 undoes the VDU 21 *DUNJUNZ sends...
    lda #3                              ; ...then 3 (VDU 3: printer off)...
    jsr oswrch                          ; ...keeps output off any printer
    lda #0                              ; Cancel the BREAK intercept *DUNJUNZ armed...
    sta os_break_intercept              ; ...so a BREAK now resets plainly until a level ends
; Count the level and advance its filename digits in page &08: "0 " to "9 " step by the single digit, then "10" on in two.
    inc levels_started                  ; One more level started (1 for the first)
    lda level_digits + 1                ; Advance level_digits, the filename's level number...
    cmp #&20 ; ' '                      ; Second digit a space (levels 1-9)?
    beq advance_single_digit            ; Yes: advance the single digit
    clc                                 ; No: advance the units digit...
    adc #1                              ; ...+1, the next units digit
    sta level_digits + 1                ; ...back into level_digits
    cmp #&3a ; ':'                      ; ...past '9': does it carry?
    bcc set_up_6845_for_loading         ; No: the number is ready
    lda #&30 ; '0'                      ; Yes: units '0' and carry into the tens
    sta level_digits + 1                ; ...units digit back to '0'...
    inc level_digits                    ; ...and one more tens
    bne set_up_6845_for_loading         ; Always taken: the number is ready
; &5036 referenced 1 time by &5020
.advance_single_digit
    inc level_digits                    ; Advance the single digit ('0 ' becomes '1 ')...
    lda level_digits                    ; ...to check it
    cmp #&3a ; ':'                      ; ...past '9': level 10, two digits now?
    bcc set_up_6845_for_loading         ; No: levels 1-9 are ready
    lda #&31 ; '1'                      ; Yes: level 10, "10"
    sta level_digits                    ; ...'1' as the tens digit...
    lda #&30 ; '0'                      ; ...and '0' as the units digit...
    sta level_digits + 1                ; ...in place of the space
; Blank the display and silence the VDU, then reload Dun1 and the level file.
; &504a referenced 3 times by &502a, &5034, &503e
.set_up_6845_for_loading
    ldx #0                              ; Blank the display while the files load
; &504c referenced 1 time by &5055
.send_loading_vdu
    lda loading_vdu,x                   ; ...the next byte of loading_vdu...
    jsr oswrch                          ; ...to the VDU
    inx                                 ; ...on to the next
    cpx #play_vdu - loading_vdu         ; ...until all 21 are sent
    bne send_loading_vdu                ; More to send
    lda #&15                            ; VDU 21: stop all VDU output...
    jsr oswrch                          ; ...so the *LOADs print nothing
    ldx #<(dun1_command)                ; Reload Dun1: a fresh game, and this code over itself
    ldy #>(dun1_command)                ; ...high byte of the command
    jsr oscli                           ; ...*LOAD DUN1 to &2000-&7FFF
    lda level_digits                    ; Copy the level's digits into level_command
    sta level_command_digits            ; ...the tens digit, or the only one...
    lda level_digits + 1                ; ...second digit, or a space...
    sta level_command_digits + 1        ; ...at level_command+10
    lda levels_started                  ; Hand levels_started to game_entry in &8E...
    sta level_count_copy                ; ...which game_entry makes level_number
    lda levels_started                  ; A = levels started - 1, to pick the level's file
    sec                                 ; ...minus 1 (carry set for the subtract)...
    sbc #1                              ; ...24 for level 25
    sta level_number                    ; ...in level_number (the core copy overwrites it)
    cmp #&18                            ; Levels started 25: the last level?
    bne load_level_file                 ; Not level 25: load its LEVELnn file
    ldx #<(stones_command)              ; Yes: *LOAD STONES 6680, whose end is level 25...
    ldy #>(stones_command)              ; ...high byte of the command
    jsr oscli                           ; ...putting level 25 at &6B00
    jmp level_loaded                    ; ...and skip the LEVELnn load
; &508b referenced 1 time by &507f
.load_level_file
    ldx #<(level_command)               ; No: *LOAD LEVELnn 6B00
    ldy #>(level_command)               ; ...high byte of the command
    jsr oscli                           ; ...to &6B00, where check_level decrypts it
; Turn the VDU back on and copy the keyboard or joystick image of &0400-&07FF into place.
; &5092 referenced 1 time by &5088
.level_loaded
    lda #6                              ; VDU 6: VDU output on again
    jsr oswrch                          ; ...so the game's text can appear
    lda #<(low_image_start)             ; Copy one &0400-&07FF image into place...
    sta coder_dest                      ; ...destination pointer in coder_dest...
    lda #>(low_image_start)             ; ...high byte &04, the image's first page...
    sta coder_dest + 1                  ; ...destination &0400 complete
    lda #<(keyboard_image_stored)       ; ...source low byte &B0, for &51B0 or &55B0
    sta coder_source                    ; ...source pointer in coder_source
    lda #osbyte_read_adc_or_get_buffer_status  ; Is a joystick there? Read ADC channel 1...
    ldx #1                              ; ...channel 1: the joystick's left-right axis
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #&80                            ; ...high byte exactly &80?
    bne use_keyboard_image              ; Not &80: use the keyboard-only image
    lda #>(joystick_image_stored)       ; Yes: the image with the joystick handler, &55B0
    sta coder_source + 1                ; ...source page &55: copy from &55B0
    bne copy_low_image                  ; Always taken: copy it
; &50b4 referenced 1 time by &50ac
.use_keyboard_image
    lda #>(keyboard_image_stored)       ; No: the keyboard-only image, &51B0
    sta coder_source + 1                ; ...source page &51: copy from &51B0
; &50b8 referenced 1 time by &50b2
.copy_low_image
    ldy #0                              ; Copy a kilobyte, up to &0800...
; &50ba referenced 1 time by &50ce
.copy_low_byte
    lda (coder_source),y                ; ...take the next byte...
    sta (coder_dest),y                  ; ...into the game's &0400-&07FF
    inc coder_dest                      ; Step the destination...
    bne copy_low_next_source            ; ...within the page
    inc coder_dest + 1                  ; ...or on to the next page
; &50c4 referenced 1 time by &50c0
.copy_low_next_source
    inc coder_source                    ; Step the source...
    bne copy_low_check_end              ; ...within the page
    inc coder_source + 1                ; ...or on to the next page
; &50ca referenced 1 time by &50c6
.copy_low_check_end
    lda coder_dest + 1                  ; Stop when the destination reaches &0800...
    cmp #>(low_image_end)               ; ...page &08: past the image's end?
    bne copy_low_byte                   ; No: copy more
; Point BYTEV at the joystick handler if channel 1 still reads &80.
    lda #osbyte_read_adc_or_get_buffer_status  ; Read channel 1 again: install the handler?
    ldx #1                              ; ...channel 1 again
    jsr osbyte                          ; Read ADC channel X or buffer status
    cpy #&80                            ; ...high byte exactly &80?
    bne set_up_screen_for_play          ; No: keep the MOS's BYTEV
    lda #<(joystick_bytev)              ; Yes: point BYTEV at joystick_bytev (&0780)
    sta bytev                           ; ...the handler's low byte into BYTEV...
    lda #>(joystick_bytev)              ; ...and its page, &07...
    sta bytev + 1                       ; ...so the Barbarian's key scans read the joystick
; Set the text colour and show the display, 23 rows.
; &50e5 referenced 1 time by &50d9
.set_up_screen_for_play
    lda #&11                            ; COLOUR 2: VDU 17, then the colour...
    jsr oswrch                          ; ...send VDU 17, set the text colour...
    lda #2                              ; ...text colour 2...
    jsr oswrch                          ; ...for the game's messages
    ldx #0                              ; Show the display again, 23 rows, for play
; &50f1 referenced 1 time by &50fa
.send_play_vdu
    lda play_vdu,x                      ; ...the next byte of play_vdu...
    jsr oswrch                          ; ...to the VDU
    inx                                 ; ...on to the next
    cpx #coder_leftovers - play_vdu     ; ...until all 20 are sent
    bne send_play_vdu                   ; More to send
; Copy the game core down, keeping &08C0-&0CFF after the first level, and start the game.
    lda levels_started                  ; First level of a game?
    cmp #2                              ; ...fewer than 2 levels started?
    bcs keep_heroes                     ; No: keep the heroes
    lda #0                              ; Yes: copy all of &3000-&473F to &08C0-&1FFF
    sta core_offset                     ; ...offset &0000: low byte...
    sta core_offset + 1                 ; ...and high byte: no offset
    beq copy_game_core                  ; Always taken: copy from the start
; &510b referenced 1 time by &5101
.keep_heroes
    lda #&40 ; '@'                      ; No: copy &3440-&473F to &0D00, keeping the heroes' state
    sta core_offset                     ; ...offset &0440: low byte...
    lda #4                              ; ...high byte &04...
    sta core_offset + 1                 ; ...so &08C0-&0CFF is left as it is
; &5113 referenced 1 time by &5109
.copy_game_core
    lda core_offset                     ; Source = &3000 + offset...
    sta coder_source                    ; ...source low byte
    lda #>(game_core_stored)            ; ...page &30, where Dun1 stores the core...
    clc                                 ; ...(carry clear for the add)...
    adc core_offset + 1                 ; ...plus the offset's high byte...
    sta coder_source + 1                ; ...source high byte
    lda #<(game_core_start)             ; ...destination = &08C0 + offset
    clc                                 ; ...(carry clear for the add)...
    adc core_offset                     ; ...the offset's low byte...
    sta coder_dest                      ; ...destination low byte
    lda #>(game_core_start)             ; ...page &08, where the core runs...
    adc core_offset + 1                 ; ...plus the offset's high byte and carry...
    sta coder_dest + 1                  ; ...destination high byte
    ldy #0                              ; Copy bytes up to &4740
; &512d referenced 2 times by &5141, &5147
.copy_core_byte
    lda (coder_source),y                ; ...take the next byte...
    sta (coder_dest),y                  ; ...into the running game
    inc coder_source                    ; Step the source...
    bne copy_core_next_dest             ; ...within the page
    inc coder_source + 1                ; ...or on to the next page
; &5137 referenced 1 time by &5133
.copy_core_next_dest
    inc coder_dest                      ; Step the destination...
    bne copy_core_check_end             ; ...within the page
    inc coder_dest + 1                  ; ...or on to the next page
; &513d referenced 1 time by &5139
.copy_core_check_end
    lda coder_source                    ; Stop at the core's end, &4740: source low byte...
    cmp #<(game_core_stored_end)        ; ...&40, the end's low byte?
    bne copy_core_byte                  ; No: copy more
    lda coder_source + 1                ; ...then the source's page...
    cmp #>(game_core_stored_end)        ; ...&47: the source at &4740, the core's end?
    bne copy_core_byte                  ; No: copy more
    jmp game_entry                      ; Enter the game at game_entry
; ***************************************************************************************
; Coder's commands
;
; Three OSCLI command lines, each ended by a CR.
.stones_command
    equs "LOAD STONES 6680", &0d        ; *LOAD STONES 6680, for level 25
.dun1_command
    equs "LOAD DUN1", &0d               ; *LOAD DUN1
.level_command
; &5171 referenced 1 time by &5066
level_command_digits = level_command+10
; &5172 referenced 1 time by &506c
    equs "LOAD LEVEL   6B00", &0d       ; *LOAD LEVELnn 6B00, the digits at +10
; ***************************************************************************************
; Coder's VDU tables
;
; 6845 set-ups sent with VDU 23,0: one while loading, one for play.
.loading_vdu
    equb &17, &00, &01, &00, &00, &00, &00, &00, &00, &00  ; VDU 23,0,1,0: 6845 register 1 = 0, no characters displayed
    equb &17, &00, &0a, &20, &00, &00, &00, &00, &00, &00  ; VDU 23,0,10,&20: 6845 register 10 = &20, no cursor
    equb &00                            ; A further 0, sent too (21 bytes are sent)
.play_vdu
    equb &17, &00, &01, &50, &00, &00, &00, &00, &00, &00  ; VDU 23,0,1,80: 6845 register 1 = 80 characters displayed
    equb &17, &00, &06, &17, &00, &00, &00, &00, &00, &00  ; VDU 23,0,6,23: 6845 register 6 = 23 character rows displayed
; ***************************************************************************************
; Unused
;
; Leftover bytes: stale code from an earlier assembly.
.coder_leftovers
    equb &85, &70, &bd, &d0, &7d, &18, &69, &18, &85, &71, &8a, &48, &20, &00

    org &59b0
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00  ; Not referenced
; &6b00 used as index base 1 time by &3c52
.level_object_x
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6b20 used as index base 1 time by &3c58
.level_object_y
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6b40 used as index base 1 time by &3c5e
.level_object_type
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6b60 used as index base 1 time by &3c69
.level_door_x
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00
; &6b75 used as index base 1 time by &3c6f
.level_door_y
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00
; &6b8a used as index base 1 time by &3c75
.level_door_sprite
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00
; &6ba0 used as index base 1 time by &3c80
.level_key_x
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00
; &6bb5 used as index base 1 time by &3c86
.level_key_y
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00
; &6bd0 used as index base 1 time by &3c91
.level_trapdoor_x
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6bd8 used as index base 1 time by &3c97
.level_trapdoor_y
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6be0 used as index base 1 time by &3ca4
.level_walls
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6cb0 used as index base 1 time by &3caa
.level_object_free_map
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
; &6d80 used as index base 1 time by &3cb7
.level_wall_sprite
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
; ***************************************************************************************
; Move the heroes
;
; Let each of the four heroes, in turn from the Ranger, walk, fire or cast magic for this
; frame, redraw them, and let them pick up what lies in their cell. update_game calls
; this first in every frame, before the door and key tests (which use the cells it
; records in hero_door_x/y), draw_objects, move_missiles and update_monsters.
;
; A hero out of play is passed over if nobody plays them (step &63), or handed to
; animate_absent_hero if dying or returning through a Cross. A hero half way through a
; step (step 1) finishes it through continue_hero_step and reads no keys. Otherwise
; heroes 0 and 1 first go through check_magic, which comes back to read_hero_keys, or
; after a cast to draw_moved_hero with no move; then the first held of up, down, right,
; left and fire decides. A direction turns the hero that way (directions 1, 3, 5, 7) and
; tries the next cell, which is recorded in hero_door_x/y whatever is there, so a hero
; pushing on a door opens it. A wall or closed door, a monster (alive or dying, found by
; find_creature) or another hero in play refuses the move; walking into a monster also
; costs one health point, whatever the hero's armour. A move into another room is made at
; once and switches the hero's view (show_hero_room); within a room the Boots of Speed
; make it at once too, and without them the hero stays in the old cell, drawn half a cell
; along, and arrives on the next frame. Fire puts a missile in the first of the hero's
; free slots (3 x hero up to hero_max_missiles of them), in the hero's own cell, with bit
; 7 of its direction set so move_missiles does not erase it off the hero; the bell (VDU
; 7) sounds and the hero's frame flips. With no slot free, or no key held, the hero
; stands still.
;
; A hero who moved or was refused is erased from where they were drawn, using
; previous_x/y and previous_offset_x/y; every hero still in play is then drawn, and
; collect_objects runs whenever object_free_map lets their cell hold an object, every
; frame they are there and not only on arrival. check_magic's delay returns from
; move_heroes itself, so after a cast the later heroes are not moved for three frames.
; The bytes at &6F6D are never executed.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &6e80 referenced 1 time by &4400
.move_heroes
    ldx #0                              ; Hero 0, the Ranger, first
; For hero X: one out of play is not moved or drawn here, only animated if dying or returning.
; &6e82 referenced 1 time by &70c6
.move_hero
    lda hero_direction,x                ; A direction (1, 3, 5, 7) means the hero is in play
    bne remember_hero_position          ; In play: remember where they are, then move them
    lda hero_step,x                     ; Out of play: why? The step says
    cmp #step_out_of_play               ; Step &63 marks a hero nobody plays
    bne animate_absent                  ; Not &63: the hero is dying or returning
    jmp next_hero                       ; Nobody plays them: nothing to move or draw
; &6e91 referenced 1 time by &6e8c
.animate_absent
    jsr animate_absent_hero             ; Step the skull or resurrection animation
    jmp next_hero                       ; Then on to the next hero
; In play: keep the cell and offsets now drawn, to erase the hero there and to put them back if blocked.
; &6e97 referenced 1 time by &6e85
.remember_hero_position
    lda hero_x,x                        ; Remember the hero's cell and offsets before moving
    sta previous_x                      ; previous_x: where to put the hero back if blocked
    lda hero_y,x                        ; The cell's y...
    sta previous_y                      ; ...in previous_y, for the same
    lda hero_offset_x,x                 ; The horizontal pixel offset now drawn...
    sta previous_offset_x               ; ...so erase_hero blanks the image where it is
    lda hero_offset_y,x                 ; And the vertical pixel offset...
    sta previous_offset_y               ; ...for the same erase
; A hero half way through a step arrives this frame and reads no keys; only a standing hero acts.
    lda hero_step,x                     ; Half way between cells (step 1)?
    beq check_magic_key                 ; No: standing in a cell, so read the keys
    jsr continue_hero_step              ; Yes: arrive in the next cell; no keys this frame
    jmp erase_hero                      ; Erase the half-way image, draw the arrival
; &6eba referenced 1 time by &6eb2
.check_magic_key
    cpx #2                              ; Hero 0 or 1 (the two with magic)?
    bcs read_hero_keys                  ; Barbarian or Fighter: no magic, straight to the keys
    jmp check_magic                     ; Ranger or Magic-User: magic key, then back
; Standing in a cell: the first held key of up, down, right, left and fire decides what the hero does.
; &6ec1 referenced 2 times by &6ebc, &76ab
.read_hero_keys
    lda hero_key_up,x                   ; Up key held? (directions beat fire, up first)
    jsr test_key                        ; Z set if held
    bne check_key_down                  ; Not held: try down
    lda #1                              ; Held: face up...
    sta hero_direction,x                ; ...direction 1: drawn as sprite base + 1 or + 2
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell above
; &6ed4 referenced 1 time by &6ec7
.check_key_down
    lda hero_key_down,x                 ; Down key held?
    jsr test_key                        ; Z set if held
    bne check_key_right                 ; Not held: try right
    lda #5                              ; Held: face down...
    sta hero_direction,x                ; ...direction 5: drawn as sprite base + 5 or + 6
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell below
; &6ee7 referenced 1 time by &6eda
.check_key_right
    lda hero_key_right,x                ; Right key held?
    jsr test_key                        ; Z set if held
    bne check_key_left                  ; Not held: try left
    lda #3                              ; Held: face right...
    sta hero_direction,x                ; ...direction 3: drawn as sprite base + 3 or + 4
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell to the right
; &6efa referenced 1 time by &6eed
.check_key_left
    lda hero_key_left,x                 ; Left key held?
    jsr test_key                        ; Z set if held
    bne check_key_fire                  ; Not held: try fire
    lda #7                              ; Held: face left...
    sta hero_direction,x                ; ...direction 7: drawn as sprite base + 7 or + 8
    jsr start_hero_step                 ; ...set the half-cell offsets for the step...
    jmp step_hero                       ; ...and try the cell to the left
; &6f0d referenced 1 time by &6f00
.check_key_fire
    lda hero_key_fire,x                 ; Fire key held? (only when no direction is)
    jsr test_key                        ; Z set if held
    beq fire_missile                    ; Held: launch a missile the way the hero faces
    jmp draw_moved_hero                 ; No key: the hero stands still, drawn in place
; Fire: put a missile in the hero's first free slot, in the hero's cell, flying the way the hero faces.
; &6f18 referenced 1 time by &6f13
.fire_missile
    txa                                 ; Slots 3 x hero to 3 x hero + hero_max_missiles - 1
    sta scratch                         ; Hero number kept to add...
    asl a                               ; ...doubled: 2 x hero...
    clc                                 ; ...(no carry in)...
    adc scratch                         ; ...+ hero: 3 x hero, the hero's first slot
    tay                                 ; Y walks the hero's slots
    adc hero_max_missiles,x             ; - how many missiles the hero may have in flight...
    sta scratch                         ; ...the first slot past the hero's own
; &6f28 referenced 1 time by &6f74
.find_missile_slot
    lda missile_direction,y             ; This slot's missile still flying?
    bne next_missile_slot               ; Yes: look at the hero's next slot
    lda hero_direction,x                ; Free: missile direction = (hero direction + 1) / 2
    clc                                 ; Hero direction 1, 3, 5 or 7...
    adc #1                              ; ...+ 1: 2, 4, 6 or 8...
    lsr a                               ; ...halved: 1-4, up, right, down, left
    ora #&80                            ; Bit 7: just fired, so not erased off the hero
    sta missile_direction,y             ; The slot is now in flight
    lda hero_x,x                        ; It starts in the hero's cell; move_missiles moves it on
    sta missile_x,y                     ; ...missile x = hero x...
    lda hero_y,x                        ; ...and the hero's y...
    sta missile_y,y                     ; ...as missile y
    lda #7                              ; The firing sound: VDU 7, the bell...
    jsr oswrch                          ; ...through OSWRCH, the same for every hero
    lda hero_missile_damage,x           ; The hero's current missile damage...
    sta missile_damage,y                ; ...goes with this missile, for whatever it hits
    lda hero_missile_sprites,x          ; The hero's weapon sprites (arrow, fireball, axe, sword)...
    sta missile_sprite_base,y           ; ...so it is drawn, and its owner known, by these
    lda previous_x                      ; Put back the cell remembered at the start...
    sta hero_x,x                        ; ...the same cell: nothing has moved the hero here
    lda previous_y                      ; And the y...
    sta hero_y,x                        ; ...is put back the same way
    lda hero_frame,x                    ; Next animation frame...
    eor #1                              ; ...0 and 1 alternate...
    sta hero_frame,x                    ; ...so the hero is seen to throw
    jmp draw_moved_hero                 ; Draw the hero where they stand; no erase needed
; Unreachable after the JMP: DEY and BNE find_missile_slot.
    equb &88, &d0, &b8                  ; Not referenced
; Slot taken: try the hero's next one, up to the limit worked out above.
; &6f70 referenced 1 time by &6f2b
.next_missile_slot
    iny                                 ; The hero's next slot
    cpy scratch                         ; Past the hero's last slot?
    bne find_missile_slot               ; No: is that one free?
    jmp draw_moved_hero                 ; All the hero's missiles in flight: no shot
; Move: try the next cell the way the hero faces. A wall or closed door, a monster, or another hero in play refuses it. The hero has already turned, so a refused move still changes the way they face.
; &6f79 referenced 4 times by &6ed1, &6ee4, &6ef7, &6f0a
.step_hero
    lda hero_direction,x                ; Move the hero's cell in the direction faced: up...
    cmp #1                              ; Direction 1, facing up?
    bne step_right                      ; No: try right
    dec hero_y,x                        ; Up: one row up the map
; &6f83 referenced 1 time by &6f7e
.step_right
    cmp #3                              ; Direction 3, facing right? (A still holds it)
    bne step_down                       ; No: try down
    inc hero_x,x                        ; Right: one column along
; &6f8a referenced 1 time by &6f85
.step_down
    cmp #5                              ; Direction 5, facing down?
    bne step_left                       ; No: try left
    inc hero_y,x                        ; Down: one row down the map
; &6f91 referenced 1 time by &6f8c
.step_left
    cmp #7                              ; Direction 7, facing left?
    bne note_new_cell                   ; No: the cell is moved
    dec hero_x,x                        ; Left: one column back
; &6f98 referenced 1 time by &6f93
.note_new_cell
    lda hero_x,x                        ; Record the cell tried, wall or not...
    sta hero_door_x,x                   ; ...so update_game finds a door the hero walks into
    lda hero_y,x                        ; And the y tried...
    sta hero_door_y,x                   ; ...in hero_door_y, for the same door test
    lda hero_x,x                        ; Is the cell tried a wall (or a closed door)?
    sta cell_x                          ; cell_x: the cell for test_wall
    lda hero_y,x                        ; And the y tried...
    sta cell_y                          ; ...in cell_y, also used by the hero test
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across test_wall
    jsr test_wall                       ; Y = the cell's wall bit; map_ptr = its room
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, which test_wall used for the bit
    cpy #0                              ; Wall bit clear?
    beq check_monster_in_cell           ; Clear: is a monster in the way?
; Refused by a wall or closed door: back to the old cell, standing whole. The door test in update_game may still open it.
    lda previous_x                      ; A wall: the hero stays in the old cell...
    sta hero_x,x                        ; ...hero_x put back from previous_x...
    lda previous_y                      ; ...and y back...
    sta hero_y,x                        ; ...so the hero does not enter the wall
; &6fc7 referenced 1 time by &7050
.cancel_hero_step
    lda #0                              ; The move is over: the hero stands in a whole cell
    sta hero_step,x                     ; No step under way...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...and no vertical offset
    jmp erase_hero                      ; Erase the old image, draw the hero in their cell
; No wall. A monster in the cell, alive or dying, refuses the move and costs the hero one health point.
; &6fd5 referenced 1 time by &6fb9
.check_monster_in_cell
    lda #0                              ; Is a monster in the cell tried?
    sta scratch                         ; scratch 0: look for monsters only, not heroes
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across find_creature
    jsr find_creature                   ; Y non-zero if a monster is in the cell
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, which find_creature used for monsters
    cpy #0                              ; A monster there?
    beq check_hero_in_cell              ; No: is another hero in the way?
    lda previous_x                      ; Yes: the hero stays in the old cell...
    sta hero_x,x                        ; ...hero_x put back from previous_x...
    lda previous_y                      ; ...and y back...
    sta hero_y,x                        ; ...so the hero stays out of the monster's cell
    lda #0                              ; The move is over: the hero stands in a whole cell...
    sta hero_step,x                     ; ...no step under way...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...and no vertical offset
    jsr lose_health_point               ; ...and pays a health point for walking into it
    jmp erase_hero                      ; Erase the old image, draw the hero in their cell
; Nor a monster. Another hero in play there refuses the move at no cost; a hero out of play (a skull) does not.
; &7002 referenced 1 time by &6fe3
.check_hero_in_cell
    stx scratch                         ; Is another hero in play in the cell tried?
    ldy #0                              ; From hero 0
; &7007 referenced 1 time by &703e
.check_other_hero
    cpy scratch                         ; The moving hero itself?
    beq next_other_hero                 ; Yes: skip it
    lda hero_x,y                        ; Other hero's x...
    cmp cell_x                          ; ...the cell tried's x?
    bne next_other_hero                 ; No: not in the way
    lda hero_y,y                        ; Other hero's y...
    cmp cell_y                          ; ...the cell tried's y?
    bne next_other_hero                 ; No: not in the way
    lda hero_direction,y                ; There, but in play?
    beq next_other_hero                 ; No (a skull, say): not in the way
    lda previous_x                      ; In play there: the hero stays in the old cell...
    sta hero_x,x                        ; ...hero_x put back from previous_x...
    lda previous_y                      ; ...and y back...
    sta hero_y,x                        ; ...so heroes in play never share a cell
    lda #0                              ; The move is over: the hero stands in a whole cell...
    sta hero_step,x                     ; ...no step under way...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...and no vertical offset
    jmp erase_hero                      ; Erase the old image, draw the hero in their cell
; &703b referenced 4 times by &700a, &7012, &701a, &701f
.next_other_hero
    iny                                 ; Next hero to compare with the cell tried
    cpy #4                              ; Checked all four?
    bne check_other_hero                ; No: check that one
; The cell is free. A move into another room is made at once, as is one with the Boots of Speed; otherwise the hero is drawn half way and arrives on the next frame.
    txa                                 ; The way is clear. Is the cell tried in another room?
    asl a                               ; Two bytes per view_room entry...
    tax                                 ; ...so X = 2 x hero indexes the hero's view
    lda view_room,x                     ; The low byte of the room the hero's view shows...
    cmp map_ptr                         ; ...against the cell's room, left by test_wall
    beq check_boots                     ; Same room: the boots decide the pace
    txa                                 ; New room: the hero arrives at once...
    lsr a                               ; Halve the index...
    tax                                 ; ...back to the hero number
    jsr show_hero_room                  ; Switch the hero's view to the new room and draw it
    jmp cancel_hero_step                ; ...and the move ends in the new cell, no half step
; &7053 referenced 1 time by &7048
.check_boots
    txa                                 ; Wearing the Boots of Speed?
    lsr a                               ; Halve the view index...
    tax                                 ; ...back to the hero number
    lda hero_has_boots,x                ; Non-zero while the hero wears the boots
    beq stay_in_old_cell                ; No: a half step this frame
    lda #0                              ; Yes: arrive in the cell at once, with no step
    sta hero_offset_x,x                 ; No horizontal offset...
    sta hero_offset_y,x                 ; ...no vertical offset...
    sta hero_step,x                     ; ...and no step: one cell a frame, twice the pace
    jmp erase_hero                      ; Erase the old position and draw the new
; &7069 referenced 1 time by &7059
.stay_in_old_cell
    lda previous_x                      ; No boots: hero stays in the old cell, drawn half way
    sta hero_x,x                        ; ...by start_hero_step's offsets; next frame it arrives
    lda previous_y                      ; And the old y...
    sta hero_y,x                        ; ...so others still meet the hero in the old cell
; Erase the hero's image from where it was drawn last.
; &7075 referenced 5 times by &6eb7, &6fd2, &6fff, &7038, &7066
.erase_hero
    lda #spr_blank                      ; Erase the hero's image as it was before this frame
    sta sprite_number                   ; The blank sprite...
    lda previous_x                      ; ...at the hero's old cell...
    sta cell_x                          ; ...as the cell to plot at
    lda previous_y                      ; And the old y...
    sta cell_y                          ; ...in cell_y: where the hero was last drawn
    lda previous_offset_x               ; With the old pixel offsets too...
    sta plot_offset_x                   ; ...the old horizontal offset...
    lda previous_offset_y               ; ...and the old vertical offset...
    sta plot_offset_y                   ; ...so a half-way image is blanked where it was
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Blank the hero in every view showing that cell
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, to draw the same hero
; Draw the hero, then pick up any object in their cell. A hero comes here on every frame they are moved, standing still or not, so a hero standing on an energy drainer loses 10 health a frame.
; &7096 referenced 4 times by &6f15, &6f6a, &6f76, &76ae
.draw_moved_hero
    clc                                 ; Clear carry for the sprite sum
    lda hero_direction,x                ; Still in play? A bump or magic's cost may have killed
    beq next_hero                       ; Direction 0: out of play, not drawn
    adc hero_frame,x                    ; Sprite = direction + frame (0 or 1)...
    adc hero_sprites,x                  ; ...+ the hero's base: Ranger, Magic-User, and so on
    sta sprite_number                   ; The sprite to draw
    jsr draw_hero                       ; Draw them in every view showing their cell
    lda hero_x,x                        ; Can the hero's cell hold an object?
    sta cell_x                          ; The hero's cell, to test for an object...
    lda hero_y,x                        ; And the hero's y...
    sta cell_y                          ; ...in cell_y, where they now stand
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack across test_object_free
    jsr test_object_free                ; Y zero if an object may lie in the cell
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for collect_objects
    cpy #0                              ; Can an object lie there?
    bne next_hero                       ; No: nothing to pick up; next hero
    jsr collect_objects                 ; Yes: pick up whatever is there
; On to the next hero, until all four have had their turn.
; &70c1 referenced 4 times by &6e8e, &6e94, &709a, &70bc
.next_hero
    inx                                 ; Next hero, in the order Ranger to Fighter
    cpx #4                              ; All four heroes moved?
    beq move_heroes_done                ; Yes: every hero has had this frame's turn
    jmp move_hero                       ; No: move the next hero
; &70c9 referenced 1 time by &70c4
.move_heroes_done
    rts                                 ; Return to update_game, all four heroes moved and drawn
; ***************************************************************************************
; Move the missiles
;
; Fly every missile in flight one cell and settle what it hits. update_game calls this
; each frame, after move_heroes (which fires them) and draw_objects, and before
; update_monsters, which plays out the deaths it causes.
;
; Each of the twelve slots (three per hero, from 3 x hero) with a non-zero
; missile_direction is in flight. It is erased from its cell, unless fired this frame
; (bit 7 set) and so still on its hero, whose frame flip_firer_frame then flips back. It
; moves one cell in its direction (1-4: up, right, down, left), a cell a frame with no
; pixel offset, and the new cell is tried in turn, with the slot kept on the stack
; throughout. A wall spends the missile. A live monster takes its damage through
; monster_hit, which spends the missile and, for a kill, gives the firer a point; a
; monster already sparkling lets it through. The test for live is a sprite below the
; first sparkle, so a monster killed earlier in the frame (sprite blank until
; update_monsters runs) can be hit again. An energy drainer is worn down a stage, and
; removed after its last; the firer scores a point and the missile is turned round in the
; drainer's cell, so it can fly back into its firer. Any hero in the cell, the firer
; included and whether in play or not (a skull stops it), spends the missile, and
; lose_health_point takes missile_damage points, one at a time, from a hero in play.
; Otherwise the missile is drawn in its new cell as missile_sprite_base + direction, the
; weapon pointing the way it flies. A spent missile is not drawn, and its direction 0
; frees the slot for its hero's next shot. Missiles pass through one another and through
; objects other than drainers.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &70ca referenced 1 time by &4611
.move_missiles
    lda #0                              ; Missiles move a whole cell a frame...
    sta plot_offset_x                   ; ...so they are plotted with no horizontal offset...
    sta plot_offset_y                   ; ...and no vertical offset
    ldx #0                              ; Slot 0 first: the Ranger's first missile
; For missile slot X: an empty slot (direction 0) is passed over. One fired this frame shares its hero's cell and is moved without being erased.
; &70d2 referenced 1 time by &721d
.move_missile
    lda missile_direction,x             ; A direction means this slot's missile is flying
    bne check_just_fired                ; Flying: erase and move it
    jmp next_missile                    ; Empty slot: nothing to move
; &70da referenced 1 time by &70d5
.check_just_fired
    bpl erase_missile                   ; Bit 7 clear: flying since an earlier frame
    and #&7f                            ; Fired this frame: drop the just-fired bit...
    sta missile_direction,x             ; ...leaving direction 1-4
    jsr flip_firer_frame                ; ...flip the firer's animation frame again...
    jmp step_missile                    ; ...and move it unerased: its cell is the hero's
; Erase the missile and move it one cell.
; &70e7 referenced 1 time by &70da
.erase_missile
    lda #spr_blank                      ; Erase the missile from the cell it flew to last frame
    sta sprite_number                   ; The blank sprite
    lda missile_x,x                     ; The missile's x...
    sta cell_x                          ; ...as the cell to plot at
    lda missile_y,x                     ; And its y...
    sta cell_y                          ; ...in cell_y: where it was drawn last frame
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack across plot_at_cell
    jsr plot_at_cell                    ; Blank it in every view showing that cell
    pla                                 ; Recover the missile slot...
    tax                                 ; ...into X, to move the same missile
; &70fe referenced 1 time by &70e4
.step_missile
    lda missile_direction,x             ; Move it one cell the way it flies: up...
    cmp #1                              ; Direction 1: up
    bne missile_right                   ; No: try right
    dec missile_y,x                     ; Up: one row up the map
; &7108 referenced 1 time by &7103
.missile_right
    cmp #2                              ; Direction 2: right? (A still holds it)
    bne missile_down                    ; No: try down
    inc missile_x,x                     ; Right: one column along
; &710f referenced 1 time by &710a
.missile_down
    cmp #3                              ; Direction 3: down?
    bne missile_left                    ; No: try left
    inc missile_y,x                     ; Down: one row down the map
; &7116 referenced 1 time by &7111
.missile_left
    cmp #4                              ; Direction 4: left?
    bne check_missile_wall              ; No: the cell is moved
    dec missile_x,x                     ; Left: one column back
; Try the new cell: wall, monster, energy drainer, then hero. The slot stays on the stack through the tests.
; &711d referenced 1 time by &7118
.check_missile_wall
    lda missile_x,x                     ; Does the missile's new cell hold a wall or door?
    sta cell_x                          ; ...as the cell to test
    lda missile_y,x                     ; And its y...
    sta cell_y                          ; ...in cell_y, kept for every test below
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack across the tests
    jsr test_wall                       ; Z set if the cell is clear of walls
    beq check_missile_monster           ; Clear: is a monster there?
; Spent: the missile stops where it is, undrawn, and its slot is free for its hero's next shot.
; &7130 referenced 2 times by &71fe, &75ab
.missile_spent_pop
    pla                                 ; A wall: the missile stops, never drawn there
    tax                                 ; Recover the missile slot
; &7132 referenced 1 time by &7153
.missile_spent
    lda #0                              ; The missile is spent: free its slot...
    sta missile_direction,x             ; ...direction 0, so the hero may fire again
    jmp next_missile                    ; On to the next slot
; No wall. A live monster takes the hit; a sparkling (dying) one lets the missile through.
; &713a referenced 1 time by &712e
.check_missile_monster
    lda #0                              ; Is a monster in the new cell?
    sta scratch                         ; scratch 0: look for monsters only, not heroes
    jsr find_creature                   ; Z clear, X = the monster, if one is in the cell
    beq check_missile_object            ; None: an object or a hero?
    lda monster_sprite,x                ; One there: is it still alive?
    cmp #spr_sparkle_0                  ; Sparkles on: dying; the blank (just killed) is live
    bcs check_missile_object            ; Dying: the missile flies through it
    pla                                 ; Alive: hit it, with the slot off the stack...
    tay                                 ; ...in Y, for monster_hit
    jmp monster_hit                     ; Hit sound, damage; it spends the missile
; monster_hit jumps back here, slot in X, when its hit kills the monster.
; &7150 referenced 1 time by &75a3
.monster_killed
    jsr credit_missile_owner            ; monster_hit's kill: a point to the firer...
    jmp missile_spent                   ; ...and the missile is spent
; No live monster there. If the cell can hold an object, look for an energy drainer there.
; &7156 referenced 2 times by &7142, &7149
.check_missile_object
    pla                                 ; Could the new cell hold an object (a drainer)?
    tax                                 ; Recover the missile slot
    lda missile_x,x                     ; The missile's x...
    sta cell_x                          ; ...as the cell to test
    lda missile_y,x                     ; And its y...
    sta cell_y                          ; ...in cell_y (find_creature left it intact)
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack across test_object_free
    jsr test_object_free                ; Y zero if an object may lie in the cell
    pla                                 ; Recover the missile slot...
    tax                                 ; ...into X, which test_object_free used for the bit
    cpy #0                              ; Can an object lie there?
    bne check_missile_hero              ; No: no drainer; is a hero there?
; A missile hitting an energy drainer wears it down, scores for the firer and turns round in its cell.
    txa                                 ; Look for an energy drainer at the cell...
    pha                                 ; Keep the missile slot while X runs over objects
    ldx #max_object                     ; ...objects 30 to 1
; &7173 referenced 1 time by &71d5
.check_object_drainer
    lda object_x,x                      ; This object's x...
    cmp cell_x                          ; ...the missile's cell?
    bne next_object_drainer             ; No: the next object
    lda object_y,x                      ; This object's y...
    cmp cell_y                          ; ...the missile's cell too?
    bne next_object_drainer             ; No: the next object
    lda object_type,x                   ; The object in the cell: a drainer (&53-&5E)?
    cmp #spr_drainer_0                  ; Below the drainer sprites?
    bcc no_drainer                      ; Yes: some other object; stop looking
    cmp #spr_drainer_11 + 1             ; Past the last drainer stage?
    bcs no_drainer                      ; Yes: some other object; stop looking
    inc object_type,x                   ; A drainer: the hit wears it down a stage
    lda object_type,x                   ; Its new stage...
    cmp #spr_drainer_11 + 1             ; Past the last (12 hits from the first stage)?
    bne credit_drainer_hit              ; No: it survives; score and bounce
    lda #off_map                        ; Worn away: take it out of the level
    sta object_x,x                      ; Off the map in x...
    sta object_y,x                      ; ...and y, so it is never drawn or met again
; &71a0 referenced 1 time by &7196
.credit_drainer_hit
    pla                                 ; A point to the hero who fired, for every hit
    tax                                 ; Recover the missile slot
    jsr credit_missile_owner            ; The missile's sprites say whose it is
    lda missile_direction,x             ; Turn the missile round, still in the drainer's cell
    cmp #1                              ; Direction 1, flying up?
    bne reverse_right                   ; No: try right
    lda #3                              ; Up turns to down...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
; &71b4 referenced 1 time by &71aa
.reverse_right
    cmp #2                              ; Direction 2, flying right?
    bne reverse_down                    ; No: try down
    lda #4                              ; Right turns to left...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
; &71c0 referenced 1 time by &71b6
.reverse_down
    cmp #3                              ; Direction 3, flying down?
    bne reverse_left                    ; No: it was flying left
    lda #1                              ; Down turns to up...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
; &71cc referenced 1 time by &71c2
.reverse_left
    lda #2                              ; Left turns to right...
    sta missile_direction,x             ; ...back the way it came
    jmp check_missile_hero              ; Is a hero in the drainer's cell?
; &71d4 referenced 2 times by &7179, &7181
.next_object_drainer
    dex                                 ; Next object down, looking for one in the cell
    bne check_object_drainer            ; Until all 30 are checked
; &71d7 referenced 2 times by &7188, &718c
.no_drainer
    pla                                 ; No drainer in the cell: drop the saved slot...
    tax                                 ; ...back into X
; The first hero in the cell, in play or not, stops the missile.
; &71d9 referenced 5 times by &716d, &71b1, &71bd, &71c9, &71d1
.check_missile_hero
    txa                                 ; Is a hero in the new cell? Any hero, even the firer
    pha                                 ; Keep the missile slot while X runs over heroes
    ldx #0                              ; From hero 0
; &71dd referenced 1 time by &7204
.check_hero_hit
    pla                                 ; Fetch the missile slot...
    tay                                 ; ...into Y, to read its damage if this hero is hit...
    pha                                 ; ...leaving it on the stack
    lda hero_x,x                        ; This hero's x...
    cmp cell_x                          ; ...the missile's cell?
    bne next_hero_hit                   ; No: the next hero
    lda hero_y,x                        ; This hero's y...
    cmp cell_y                          ; ...the missile's cell too?
    bne next_hero_hit                   ; No: the next hero
    lda missile_damage,y                ; Hit: the hero loses the missile's damage...
    tay                                 ; ...Y health points, one at a time
; &71f4 referenced 1 time by &71fc
.take_missile_damage
    tya                                 ; Keep the count...
    pha                                 ; ...on the stack across the call
    jsr lose_health_point               ; One point (none if out of play, as a skull)
    pla                                 ; Recover the count...
    tay                                 ; ...of damage points still to take, into Y
    dey                                 ; One fewer to take
    bne take_missile_damage             ; More to take: take the next
    jmp missile_spent_pop               ; The missile is spent, slot still on the stack
; &7201 referenced 2 times by &71e6, &71ee
.next_hero_hit
    inx                                 ; Next hero to test against the missile's cell
    cpx #4                              ; All four heroes checked?
    bne check_hero_hit                  ; No: check the next hero against the missile's cell
; No wall, live monster or hero in the new cell: draw the missile there, pointing the way it flies (a drainer will have turned it round), then go on to the next slot.
    pla                                 ; Nothing hit: the missile flies on, drawn in its new cell
    tax                                 ; Missile slot back in X
    clc                                 ; Sprite = the missile's base...
    lda missile_sprite_base,x           ; ...(its hero's weapon, the sprite before its up sprite)...
    adc missile_direction,x             ; ...plus its direction, 1-4: the weapon pointing that way
    sta sprite_number                   ; ...is the sprite to plot
    txa                                 ; Keep the missile slot...
    pha                                 ; ...across the plot
    jsr plot_at_cell                    ; Plot the missile in every view showing its cell
    pla                                 ; Recover the missile slot...
    tax                                 ; ...into X, for the slot loop
; &7218 referenced 2 times by &70d7, &7137
.next_missile
    inx                                 ; Next missile slot
    cpx #&0c                            ; Past the twelfth slot (three per hero)?
    beq move_missiles_done              ; Yes: every missile moved this frame
    jmp move_missile                    ; No: move this slot's missile
; &7220 referenced 1 time by &721b
.move_missiles_done
    rts                                 ; Return to update_game: all twelve slots done
; ***************************************************************************************
; Take one health point from a hero
;
; If hero X is in play, take one point from their health and redraw it in the status
; panel; if that point was their last, kill them.
;
; Every kind of harm is paid through here, one call per point: a hero walking into a
; monster (move_heroes, 1 point), a monster stepping onto a hero (hero_damage_taken
; points), a missile (its damage), an energy drainer (10, from collect_objects) and the
; cost of magic (6 for the Ranger, 3 for the Magic-User). Three callers use it only to
; draw a health they have set one point high: draw_status_panel (99 + 1 at each level),
; the potion, and a returning hero (33, drawn as 32).
;
; Health is two digit sprites, hero_health_tens and hero_health_units (&1E-&27 for 0-9),
; so the units digit wraps from 0 to 9 with a borrow from the tens. Health 00 is still
; alive; the hero dies when a point is taken from 00, which leaves the tens at &1D, one
; below the 0 sprite: the play loop tests that to count the dead. On death the hero's
; sprite is erased from every view, they leave play (direction 0), the death animation is
; started (frame step +1, counter 1, run by move_heroes) and their number + 1 is put in
; the first free entry of returning_hero_queue, for a Cross of Resurrection to bring
; back. The health is not redrawn on death. A hero out of play (dying, returning, or not
; playing) loses nothing, so a skull is safe to touch.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &7221 referenced 8 times by &363f, &6ffc, &71f6, &749a, &7512, &7654, &772a, &79ac
.lose_health_point
    lda hero_direction,x                ; Direction 0: out of play, dying or returning
    bne take_health_unit                ; In play: they can be hurt
    rts                                 ; Out of play: nothing to lose
; &7227 referenced 1 time by &7224
.take_health_unit
    dec hero_health_units,x             ; Health down one: the units digit sprite
    lda hero_health_units,x             ; ...and look at the new units digit
    cmp #spr_digit_0 - 1                ; Gone below the 0 sprite?
    bne draw_health                     ; No: the tens are untouched, redraw the health
    lda #spr_digit_9                    ; Yes: units back to 9...
    sta hero_health_units,x             ; ...so 30 becomes 29
    dec hero_health_tens,x              ; ...and borrow from the tens
    lda hero_health_tens,x              ; ...and look at the new tens digit
    cmp #spr_digit_0 - 1                ; Below 0? The point was taken from 00
    bne draw_health                     ; No: still alive, redraw the health
; The point was taken from health 00: the hero dies. The tens digit is left at &1D, below the 0 sprite, which marks the hero as dead to the play loop.
    lda #spr_blank                      ; The hero has died: erase them...
    sta sprite_number                   ; ...with the blank sprite...
    jsr draw_hero                       ; ...at their cell in every view showing it
    lda #0                              ; ...take them out of play...
    sta hero_direction,x                ; ...so they neither move nor take more harm
    lda #1                              ; ...and start the death animation:
    sta hero_offset_x,x                 ; ...frame step +1: forwards to the skull...
    sta hero_offset_y,x                 ; ...frame counter 1: the first step comes next frame
; Put the hero in the first free (zero) entry of returning_hero_queue, as hero + 1, to wait for a Cross. The search has no limit; a free entry is always there, as the queue holds at most one entry per hero.
    ldy #0                              ; Queue them for a Cross: from the queue's front...
; &7256 referenced 1 time by &7264
.find_queue_slot
    lda returning_hero_queue,y          ; ...look at this queue entry
    bne next_queue_slot                 ; Taken: try the next entry
    txa                                 ; Free: entry = hero number + 1...
    clc                                 ; ...(carry clear for the add)...
    adc #1                              ; ...(entries are hero + 1, so 0 can mean free)...
    sta returning_hero_queue,y          ; ...queued behind those already waiting
    rts                                 ; Return, health not redrawn
; &7263 referenced 1 time by &7259
.next_queue_slot
    iny                                 ; Next queue entry
    bne find_queue_slot                 ; Keep looking (an empty entry is always found)
; Draw hero X's health, two digit sprites on the top row of their panel section, tens at panel_left and units three byte columns right. lose_health_point falls through to here and food calls it; plot_sprite corrupts X, so the hero is kept on the stack.
; &7266 referenced 3 times by &722f, &723e, &73a2
.draw_health
    lda hero_panel_y,x                  ; Health on the top row of the hero's panel section...
    sta plot_y                          ; ...as the plotting row
    lda #panel_left                     ; Tens in the panel's left column...
    sta plot_x                          ; ...as the plotting column
    lda hero_health_tens,x              ; The tens digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the health's tens digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the units digit
    lda hero_health_units,x             ; The units digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 3                 ; ...three byte columns right of the tens...
    sta plot_x                          ; ...on the same row
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the health's units digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the health drawn and X the hero
; ***************************************************************************************
; Add one point to a hero's score
;
; Add one to hero X's score and redraw it in the status panel. Points come one at a time
; from here: a monster killed by a missile or by magic, a hit on an energy drainer, food
; (five calls) and a door opened (seven); draw_status_panel calls it at each level just
; to draw the score, which adds a point. Bigger rewards go through add_ten_points.
;
; The score is kept as digit sprites, one table per digit (hero_score_thousands,
; _hundreds, _tens, _units; &1E-&27 for 0-9), so it can be plotted as it stands. A units
; digit past 9 is set back to 0 and the carry made by falling into add_ten_points, which
; goes on into the hundreds and, through add_thousand_points, the thousands and the small
; ten-thousands digit. draw_score then plots all four main digits.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &728c referenced 5 times by &3642, &4445, &73a9, &76a2, &76d4
.add_point
    inc hero_score_units,x              ; Score up one: the units digit sprite
    lda hero_score_units,x              ; ...and look at the new units digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne draw_score                      ; No: nothing to carry, redraw the score
    lda #spr_digit_0                    ; Yes: units back to 0...
    sta hero_score_units,x              ; ...and carry by falling into add_ten_points
; ***************************************************************************************
; Add ten points to a hero's score
;
; Add ten to hero X's score, carrying into the hundreds and through add_thousand_points,
; and redraw the score. collect_objects calls it for treasure (twice: 20 points), the
; Cross of Resurrection and every magic item; add_point falls into it to carry from the
; units. The units digit is not touched, which the potion relies on: it reads the units
; digit before calling this.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &729b referenced 4 times by &737f, &7382, &7419, &74d5
.add_ten_points
    inc hero_score_tens,x               ; Score up ten: the tens digit sprite
    lda hero_score_tens,x               ; ...and look at the new tens digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne draw_score                      ; No: nothing to carry, redraw the score
    lda #spr_digit_0                    ; Yes: tens back to 0...
    sta hero_score_tens,x               ; ...stored for this hero
    inc hero_score_hundreds,x           ; ...and carry into the hundreds
    lda hero_score_hundreds,x           ; ...and look at the new hundreds digit
    cmp #spr_digit_9 + 1                ; Past the 9 sprite?
    bne draw_score                      ; No: redraw the score
    lda #spr_digit_0                    ; Yes: hundreds back to 0...
    sta hero_score_hundreds,x           ; ...stored for this hero
    jsr add_thousand_points             ; ...and carry into the thousands and beyond
; Draw hero X's score, four digit sprites (thousands, hundreds, tens, units, three byte columns apart from panel_left) twelve rows below the health. The ten-thousands digit is drawn by add_thousand_points when it changes.
; &72bc referenced 3 times by &7294, &72a3, &72b2
.draw_score
    clc                                 ; Score: all four digits, twelve rows below the health
    lda hero_panel_y,x                  ; Row: the hero's panel section...
    adc #&0c                            ; ...twelve rows down, below the health
    sta plot_y                          ; ...as the plotting row
    lda #panel_left                     ; Thousands digit in the panel's left column
    sta plot_x                          ; ...as the plotting column
    lda hero_score_thousands,x          ; The thousands digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the thousands digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the hundreds digit
    lda hero_score_hundreds,x           ; The hundreds digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 3                 ; ...three byte columns right (&48)...
    sta plot_x                          ; ...as the plotting column
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the hundreds digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the tens digit
    lda hero_score_tens,x               ; The tens digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 6                 ; ...six byte columns right (&4B)...
    sta plot_x                          ; ...as the plotting column
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the tens digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, for the units digit
    lda hero_score_units,x              ; The units digit sprite...
    sta sprite_number                   ; ...as the sprite to plot
    lda #panel_left + 9                 ; ...nine byte columns right (&4E)...
    sta plot_x                          ; ...as the plotting column
    txa                                 ; Keep the hero number...
    pha                                 ; ...across the plot
    jsr plot_sprite                     ; Plot the units digit
    pla                                 ; Recover the hero number...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the score drawn and X the hero
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
; &7305 referenced 1 time by &460e
.draw_objects
    lda #0                              ; No pixel offsets
    sta plot_offset_x                   ; ...across the cell horizontally...
    sta plot_offset_y                   ; ...and vertically: objects sit squarely in their cells
    ldx #max_object                     ; Objects 30 to 1: plot each at its cell
; &730d referenced 1 time by &7326
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
; &2A Cross of Resurrection: 10 points and the pickup sound; removed, and the first hero
; in returning_hero_queue starts to materialise where they fell. With nobody waiting it
; is wasted.
;
; &51 the exit: passed over (update_game's check_hero_on_exit deals with it) and the
; search goes on.
;
; &5F and up, magic items: removed, the pickup sound and 10 points, then &5F Boots of
; Speed (bolt icon, a whole cell per step), &60 helmet (one less health lost per monster
; blow, to at least 3, and the armour rating redrawn), &61 potion (health set to the
; score's units digit twice over, e.g. 77), &62 pile of weapons (one more missile in
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
; &7329 referenced 1 time by &70be
.collect_objects
    lda hero_x,x                        ; The hero's cell: map x...
    sta cell_x                          ; ...as the cell to search
    lda hero_y,x                        ; ...and map y...
    sta cell_y                          ; ...as cell_y, for the comparisons
    ldy #max_object                     ; Search from object 30, the exit, down to 1
; &7337 referenced 1 time by &7473
.check_object
    lda object_x,y                      ; Object Y's map x...
    cmp cell_x                          ; ...the hero's column?
    beq check_object_y                  ; Yes: compare the row
    jmp next_object                     ; No: try the next object
; &7342 referenced 1 time by &733d
.check_object_y
    lda object_y,y                      ; Object Y's map y...
    cmp cell_y                          ; ...the hero's row?
    beq object_found                    ; Yes: the hero is on object Y
    jmp next_object                     ; No: try the next object
; Object Y is in the hero's cell. Whatever it is, the hero loses the Boots of Speed and their bolt icon first.
; &734d referenced 1 time by &7348
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
; &738a referenced 1 time by &7361
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
; &73a0 referenced 1 time by &7396
.redraw_health
    tya                                 ; Show the new health and score 5 points:
    pha                                 ; Keep the object number
    jsr draw_health                     ; Redraw the health in the panel
    ldy #5                              ; Food is worth 5 points
; &73a7 referenced 1 time by &73af
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
; &73c3 referenced 1 time by &738c
.check_teleporter
    cmp #spr_teleporter                 ; Teleporter (moves the hero)?
    bne check_cross                     ; No: try the Cross
; Teleporter: find its partner, the nearest teleporter before it in the object list, wrapping round to 29 after object 0 (whose type, never set by unpack_level, is 0 and never matches). A lone teleporter finds itself.
; &73c7 referenced 2 times by &73d1, &73d6
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
; &73d9 referenced 1 time by &73cd
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
; &740d referenced 1 time by &73c5
.check_cross
    cmp #spr_cross                      ; Cross of Resurrection?
    bne check_magic_item                ; No: try the exit, drainers and magic items
; Cross of Resurrection: remove it and score 10 whether or not anyone is waiting to return, play the pickup sound, then look at the front of returning_hero_queue.
    lda #off_map                        ; Cross: take it off the level...
    sta object_x,y                      ; ...off the map in x...
    sta object_y,y                      ; ...and y, even if nobody comes back
    jsr add_ten_points                  ; The Cross is worth 10 points
    txa                                 ; Keep the hero...
    pha                                 ; ...across the sound and the queue
    jsr play_pickup_sound               ; Play the pickup sound
    lda returning_hero_queue            ; First queue entry used (a hero or a &64 marker)?
    bne take_returning_hero             ; Yes: bring back the first hero waiting
    pla                                 ; No: wasted. Recover the hero...
    tax                                 ; ...into X...
    rts                                 ; ...and return, the Cross spent on nobody
; Bring back the first hero waiting in returning_hero_queue. Each pass takes the front entry and shifts the four entries up one; &64 markers, which stand for heroes left out on the menu, are put back at the end and the next entry taken. A hero found is started materialising (the death animation run backwards, by animate_absent_hero) in the cell where they fell.
; &7429 referenced 1 time by &7424
.take_returning_hero
    ldy #0                              ; Take the first entry off the queue, appending 0...
; &742b referenced 1 time by &744a
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
; &744c referenced 1 time by &7446
.check_queue_empty
    cpx #&ff                            ; &FF: the front entry was 0, nobody left waiting?
    beq cross_done                      ; Yes: nobody returns
    lda #0                              ; Start hero X materialising: out of play...
    sta hero_direction,x                ; ...direction 0: not in play while the sprites run
    lda #8                              ; ...from the skull back...
    sta hero_frame,x                    ; ...frame 8, the last of hero_appearance_sprites
    lda #&ff                            ; ...stepping backwards through the sprites...
    sta hero_offset_x,x                 ; ...frame step -1
    lda #1                              ; ...the first step next frame
    sta hero_offset_y,x                 ; ...the frame counter
; &7464 referenced 1 time by &744e
.cross_done
    pla                                 ; Recover the hero who picked up the Cross...
    tax                                 ; ...into X, for move_heroes
    rts                                 ; Return to move_heroes
; Shared tail for treasure and food: take object Y off the map.
; &7467 referenced 2 times by &7387, &73c0
.remove_object
    lda #off_map                        ; Take object Y off the level:
    sta object_x,y                      ; ...off the map in x...
    sta object_y,y                      ; ...and y, so it is neither drawn nor found again
    rts                                 ; Return to move_heroes: the object is gone
; The object is not in the hero's cell, or is the exit: try the next one down.
; &7470 referenced 3 times by &733f, &734a, &747d
.next_object
    dey                                 ; Next object down
    beq collect_objects_done            ; Past object 1: nothing in the cell
    jmp check_object                    ; Check this object
; &7476 referenced 1 time by &7471
.collect_objects_done
    rts                                 ; Return: nothing to act on in the hero's cell
; Not treasure, food, a teleporter or the Cross: the exit, an energy drainer or a magic item, told apart by type ranges alone.
; &7477 referenced 1 time by &740f
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
; &7498 referenced 1 time by &74a0
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
; &74a3 referenced 2 times by &741e, &74ca
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
; &74b6 referenced 1 time by &7479
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
; &74eb referenced 1 time by &74dd
.check_helmet
    cmp #spr_helmet                     ; Magic helmet (better armour)?
    bne check_potion                    ; No: try the potion
; Magic helmet: lower hero_damage_taken, the health a monster's blow takes, by one to at least 3, and redraw the armour rating (10 - hero_damage_taken, so at most 7).
    dec hero_damage_taken,x             ; Helmet: one less health lost per hit...
    lda hero_damage_taken,x             ; ...and look at it
    cmp #3                              ; ...below 3 (armour 7, the best)?
    bcs redraw_armour                   ; No: keep it
    inc hero_damage_taken,x             ; Yes: back to 3
; &74fc referenced 1 time by &74f7
.redraw_armour
    jmp draw_armour_rating              ; Redraw the armour rating on the shield
; &74ff referenced 1 time by &74ed
.check_potion
    cmp #spr_potion                     ; Potion of healing?
    bne check_weapons                   ; No: try the weapons
; Potion of healing: health is set from the score's units digit d, read before the 10 points were added, as tens d and units d + 1, then lose_health_point takes a point and draws it: health dd, from 00 to 99.
    lda scratch2                        ; Potion: health = the score's last digit twice...
    sta hero_health_tens,x              ; ...as the tens (so a score ending in 0 gives 00)
    inc scratch2                        ; ...and the units one higher...
    lda scratch2                        ; ...the sprite after it...
    sta hero_health_units,x             ; ...as the health's units
    jsr lose_health_point               ; ...less a point, which also draws the health
    rts                                 ; Return to move_heroes with the new health drawn
; &7516 referenced 1 time by &7501
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
; &7529 referenced 1 time by &7522
.draw_missile_icon
    jmp draw_new_missile_icon           ; Draw the newest missile icon
; ***************************************************************************************
; Show the room a hero has moved into
;
; Make hero X's view show the room they are now in, and redraw that view's walls and
; doors. move_heroes calls this when a hero steps into another room, and a teleporter
; jumps here after moving the hero.
;
; Each hero has a fixed view (0 top left to 3 bottom right). test_wall is called on the
; hero's cell only for the room offset it leaves in map_ptr; that becomes the low byte of
; the view's view_room entry (view_room + 2 x hero), the pointer into room_walls that
; draw_view_0 to draw_view_3 and plot_at_cell read; the high byte never changes. The
; matching draw_view_n then draws the room's walls and doors. Creatures and objects
; appear in the new view as they are next plotted.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
; &752c referenced 2 times by &704d, &740a
.show_hero_room
    lda hero_x,x                        ; The hero's cell, for test_wall to find its room
    sta cell_x                          ; ...as cell_x for test_wall...
    lda hero_y,x                        ; ...and its map y...
    sta cell_y                          ; ...as cell_y for test_wall
    txa                                 ; Keep the hero...
    pha                                 ; ...on the stack: test_wall corrupts X
    jsr test_wall                       ; Only for map_ptr: the offset of the cell's room
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, to pick their view
    pha                                 ; Keep the hero number across the view draw
    asl a                               ; Hero x 2: their view's entry in view_room...
    tay                                 ; ...two bytes, a pointer into room_walls
    lda map_ptr                         ; The room's offset that test_wall left...
    sta view_room,y                     ; ...becomes the view's room
; Redraw the hero's own view, which is fixed by hero number.
    cpx #0                              ; Redraw this hero's own view: hero 0's?
    bne check_view_1                    ; No: try hero 1
    jsr draw_view_0                     ; Hero 0: redraw the top-left view
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Ranger's view redrawn
; &7551 referenced 1 time by &7549
.check_view_1
    cpx #1                              ; Hero 1, the top-right view?
    bne check_view_2                    ; No: try hero 2
    jsr draw_view_1                     ; Yes: redraw it
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Magic-User's view redrawn
; &755b referenced 1 time by &7553
.check_view_2
    cpx #2                              ; Hero 2, the bottom-left view?
    bne show_view_3                     ; No: hero 3
    jsr draw_view_2                     ; Yes: redraw it
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Barbarian's view redrawn
; &7565 referenced 1 time by &755d
.show_view_3
    jsr draw_view_3                     ; Hero 3: redraw the bottom-right view
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Fighter's view redrawn
; Magic sword: one more damage for each missile the hero fires from now on, to at most 9, and the panel's damage digit redrawn. Missiles already in flight keep their damage.
; &756b referenced 1 time by &7518
.magic_sword
    inc hero_missile_damage,x           ; Magic sword: one more damage per missile...
    lda hero_missile_damage,x           ; ...and look at it
    cmp #&0a                            ; ...past 9, the most?
    bne draw_missile_damage             ; No: draw the new damage in the panel
    lda #9                              ; Yes: back to 9...
    sta hero_missile_damage,x           ; ...as the missile damage
    bne draw_missile_damage             ; ...and draw it (always taken)
; A missile has hit a live monster: X is the monster, Y the missile slot. Reached by JMP from move_missiles, and leaves by jumping back into it. Every hit makes the hit sound. The missile's damage is taken from the monster's hit points; below 0 kills it (0 survives), and the kill is scored by monster_killed. Either way the missile is spent.
; &757c referenced 1 time by &714d
.monster_hit
    txa                                 ; Hit: sound the blow
    pha                                 ; Keep the monster...
    tya                                 ; ...and the missile slot...
    pha                                 ; ...across the OSWORD call
    ldx #<(hit_sound)                   ; XY = hit_sound, at pitch 6...
    ldy #>(hit_sound)                   ; ...the block in page &0C...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; Sound the blow:  SOUND command
    pla                                 ; Recover the missile slot...
    tay                                 ; ...into Y, for its damage...
    pla                                 ; ...and the monster...
    tax                                 ; ...into X, for its hit points
    lda monster_hit_points,x            ; The monster's hit points...
    sec                                 ; ...set the carry for the subtraction...
    sbc missile_damage,y                ; ...less this missile's damage
    bpl store_monster_health            ; 0 or more: alive (0 hit points survives a hit)
; Killed: the monster's sprite becomes the blank, from which update_monsters runs the sparkles, and its slot is given this level's starting hit points for when it comes back at a trapdoor.
    lda #spr_blank                      ; Below 0: killed. Start it dying...
    sta monster_sprite,x                ; ...from the blank sprite through the sparkles
    lda monster_start_hit_points        ; ...and give the slot this level's hit points...
    sta monster_hit_points,x            ; ...ready for when it comes back at a trapdoor
    tya                                 ; Missile slot back in X...
    tax                                 ; ...as monster_killed expects
    jmp monster_killed                  ; ...a point to its hero, and the missile is spent
; &75a6 referenced 1 time by &7594
.store_monster_health
    sta monster_hit_points,x            ; Alive: store the hit points left
    tya                                 ; Push the missile slot, as missile_spent_pop...
    pha                                 ; ...expects to find it on the stack
    jmp missile_spent_pop               ; The missile is spent: one hit per missile
; Redraw hero X's armour rating after a magic helmet: the small digit 10 - hero_damage_taken (at most 7) on the shield in their panel section, twelve rows above the health. Jumped to from collect_objects; returns to its caller with X kept.
; &75ae referenced 1 time by &74fc
.draw_armour_rating
    sec                                 ; Armour rating = 10 - health lost per hit, drawn...
    lda hero_panel_y,x                  ; ...on the shield: the hero's panel row...
    sbc #&0c                            ; ...less twelve pixel rows...
    sta plot_y                          ; ...as the plotting row
    lda #panel_left + 9                 ; ...byte column &4E, nine right of the panel's left...
    sta plot_x                          ; ...as the plotting column
    lda #spr_small_digit_1 + 9          ; Small digit 10...
    sec                                 ; ...set the carry for the subtraction...
    sbc hero_damage_taken,x             ; ...less the health lost per hit: 1 to 7
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; Plot it, keeping X, and return
; Add the icon for hero X's newest missile after a pile of weapons, at the row draw_status_panel would give it (icon n at its row &0D + 3n, which plot_panel_sprite offsets by the panel row - &0E). Icons are only added: with 3 already allowed the third is drawn again. Jumped to from collect_objects; returns with X kept.
; &75c5 referenced 1 time by &7529
.draw_new_missile_icon
    lda hero_max_missiles,x             ; Icon for the newest missile allowed: missiles x 2...
    asl a                               ; ...(x 2)...
    clc                                 ; ...clear the carry for the addition...
    adc hero_max_missiles,x             ; ...+ missiles again: 3 rows per icon...
    adc #&0d                            ; ...+ &0D, as in draw_status_panel's icon rows...
    adc hero_panel_y,x                  ; ...+ the hero's panel row...
    sec                                 ; ...set the carry for the subtraction...
    sbc #&0e                            ; ...- &0E, plot_panel_sprite's bias: the same row
    sta plot_y                          ; ...as the plotting row
    lda #panel_left + 6                 ; ...byte column &4B, the icons' column...
    sta plot_x                          ; ...as the plotting column
    lda #spr_missile_icon               ; The missile icon...
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; Plot it, keeping X, and return
; Redraw hero X's missile damage after a magic sword, as a small digit (1-9) four rows above their panel row. Jumped to from collect_objects; returns with X kept.
; &75e2 referenced 2 times by &7573, &757a
.draw_missile_damage
    lda #panel_left + 7                 ; Missile damage: byte column &4C...
    sta plot_x                          ; ...as the plotting column
    sec                                 ; ...set the carry for the subtraction...
    lda hero_panel_y,x                  ; ...the hero's panel row...
    sbc #4                              ; ...less four pixel rows...
    sta plot_y                          ; ...as the plotting row
    lda hero_missile_damage,x           ; The damage, 1-9...
    clc                                 ; ...clear the carry for the addition...
    adc #spr_small_digit_1 - 1          ; ...+ one before small digit 1: its small digit
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; Plot it, keeping X, and return
; ***************************************************************************************
; Set the position of a hero's boots icon
;
; Set plot_x to the panel's column &4A and plot_y to eight pixel rows above hero X's
; panel row (hero_panel_y), where the lightning bolt shows that the hero wears Boots of
; Speed. collect_objects calls it before plot_boots_icon, when boots are picked up, and
; before erase_boots_icon, when any object is found under the hero.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     PLOT_X: &4A
;     PLOT_Y: hero_panel_y - 8
;     X: preserved
; &75f9 referenced 2 times by &7354, &74df
.point_at_boots_icon
    lda #panel_left + 5                 ; The bolt's byte column, &4A...
    sta plot_x                          ; ...as the plotting column
    sec                                 ; ...set the carry for the subtraction...
    lda hero_panel_y,x                  ; ...the hero's panel row...
    sbc #8                              ; ...8 rows above the hero's panel section
    sta plot_y                          ; ...as the icon's pixel row
    rts                                 ; Return with plot_x, plot_y at the hero's boots icon
; ***************************************************************************************
; Show a hero's boots icon
;
; Plot the lightning bolt at plot_x, plot_y, where point_at_boots_icon has just pointed,
; to show that hero X now wears Boots of Speed. Called when the boots are picked up. The
; plot goes through plot_keeping_x, which keeps the hero number across plot_sprite (which
; leaves X = 0).
;
; On Entry:
;     X: hero number (0-3)
;     PLOT_X: the icon's byte column
;     PLOT_Y: the icon's pixel row
;
; On Exit:
;     X: preserved
; &7606 referenced 1 time by &74e2
.plot_boots_icon
    lda #spr_boots_icon                 ; The lightning bolt: the hero has Boots of Speed...
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; ...plotted where point_at_boots_icon pointed
; ***************************************************************************************
; Remove a hero's boots icon
;
; Plot the blank boots sprite over the lightning bolt at plot_x, plot_y, where
; point_at_boots_icon has just pointed. collect_objects calls this whenever a hero finds
; any object, since every find takes the boots off. Falls into plot_keeping_x.
;
; On Entry:
;     X: hero number (0-3)
;     PLOT_X: the icon's byte column
;     PLOT_Y: the icon's pixel row
;
; On Exit:
;     X: preserved
; &760d referenced 1 time by &7357
.erase_boots_icon
    lda #spr_blank_boots_icon           ; The blank: the boots are lost...
    sta sprite_number                   ; ...as the sprite to plot
; &7611 referenced 4 times by &75c2, &75df, &75f6, &760a
.plot_keeping_x
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack: plot_sprite leaves X = 0
    jsr plot_sprite                     ; Plot the icon in the hero's panel section
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again for the caller
    rts                                 ; Return with X = the hero again
; ***************************************************************************************
; Cast a hero's magic if their key is held
;
; Let the Ranger or the Magic-User cast magic, which kills every live monster in the room
; they are in. move_heroes jumps here (JMP, not JSR) for heroes 0 and 1 when they stand
; in a cell, before reading their other keys.
;
; hero_magic_delay is counted down first. It normally stands at 1, so the magic key
; (hero_magic_key) is scanned every frame; while it is not yet zero the RTS here returns
; from move_heroes itself, so neither this hero nor those after it move that frame.
; Without the key held, play goes on to read_hero_keys. With it held, the magic sound
; plays, the delay is set to 4 (three frozen frames follow) and the cost is taken one
; health point at a time: 6 for the Ranger, 3 for the Magic-User, which can kill the
; caster. Then every monster whose cell lies in the room the caster's view shows, and
; whose sprite is below the blank (alive), is given the blank sprite, the first frame of
; a death that update_monsters plays out, and the caster scores a point for each, through
; add_point, even if the cost has just killed them. Unlike a missile's kill, the magic
; does not reset the monster's hit points, so a monster wounded before comes back from
; its trapdoor still wounded. The caster does not move that frame: play goes on at
; draw_moved_hero, which draws them if still in play.
;
; On Entry:
;     X: hero number (0 or 1)
; &7619 referenced 1 time by &6ebe
.check_magic
    dec hero_magic_delay,x              ; Count down this hero's magic key delay
    beq read_magic_key                  ; Zero: time to look at the magic key
    rts                                 ; Not yet: RTS ends move_heroes; later heroes wait too
; &761f referenced 1 time by &761c
.read_magic_key
    lda #1                              ; Delay 1: the key is read every frame from now on
    sta hero_magic_delay,x              ; ...so the next press is seen at once
    lda hero_magic_key,x                ; This hero's magic key, an INKEY number...
    jsr test_key                        ; ...scanned: Z set if held
    bne no_magic                        ; Not held: read the movement and fire keys
; Cast the magic: play its sound, take the caster's health, then kill every live monster in the room the caster's view shows, a point each.
    txa                                 ; Held: cast. Keep the hero number...
    pha                                 ; ...on the stack: X carries the OSWORD blocks
    ldx #<(magic_envelope)              ; XY = magic_envelope, an OSWORD 8 block...
    ldy #>(magic_envelope)              ; ...and its page
    lda #osword_envelope                ; OSWORD 8: define the magic envelope
    jsr osword                          ; ENVELOPE command
    ldx #<(magic_sound)                 ; XY = magic_sound, an OSWORD 7 block...
    ldy #>(magic_sound)                 ; ...and its page
    lda #osword_sound                   ; OSWORD 7: make the magic sound
    jsr osword                          ; SOUND command
    pla                                 ; Recover the hero number...
    tax                                 ; ...the caster, in X again
; Hold off the key for three frames, then take the cost, 6 health for the Ranger and 3 for the Magic-User, a point at a time through lose_health_point. The caster may die of it; the spell still goes on.
    lda #4                              ; Ignore the key for the next three frames
    sta hero_magic_delay,x              ; ...so one press casts only once
    cpx #1                              ; Health cost: 3 for the Magic-User...
    beq magic_user_cost                 ; Magic-User (hero 1): the cheaper rate
    ldy #6                              ; ...6 for the Ranger
    jmp take_magic_cost                 ; Ranger: go and take 6 points
; &7650 referenced 1 time by &7649
.magic_user_cost
    ldy #3                              ; Magic-User: 3 points
; &7652 referenced 2 times by &764d, &765a
.take_magic_cost
    tya                                 ; Pay the cost one health point at a time
    pha                                 ; ...the points left on the stack
    jsr lose_health_point               ; One point off the caster, redrawn (it can kill them)
    pla                                 ; Recover the points left...
    tay                                 ; ...back in Y
    dey                                 ; One point fewer to take
    bne take_magic_cost                 ; Until the whole cost is paid
    lda #0                              ; No monsters killed yet:
    sta magic_kill_count                ; ...magic_kill_count counts this cast's kills
    txa                                 ; The caster's view_room index, 2 x hero...
    asl a                               ; ...x 2: view_room holds two bytes per hero
    sta sprite_number                   ; ...kept in sprite_number, free as scratch here
; Kill every live monster in the caster's room. A monster parked off the map (&FF) is in no room and survives. The kill only sets the first death frame; hit points are left as they are.
    ldx #max_monster                    ; For each monster, 30 to 1...
; &7667 referenced 1 time by &7693
.check_magic_monster
    lda monster_x,x                     ; ...find its room from its cell: map x...
    sta cell_x                          ; ...as cell_x for test_wall...
    lda monster_y,x                     ; ...and map y...
    sta cell_y                          ; ...as cell_y; the wall bit is not wanted
    txa                                 ; Keep the monster number...
    pha                                 ; ...on the stack across test_wall
    jsr test_wall                       ; test_wall leaves the monster's room in map_ptr
    pla                                 ; Recover the monster number...
    tax                                 ; ...back in X
    ldy sprite_number                   ; Y = the caster's view_room index
    lda view_room,y                     ; The room the caster's view shows...
    cmp map_ptr                         ; ...is it the monster's room?
    bne next_monster_magic              ; Another room: the monster is spared
    lda monster_sprite,x                ; Alive? (dying ones are sprite &15 up)
    cmp #spr_blank                      ; Below the first death frame: alive
    bcs next_monster_magic              ; Already dying: not counted again
    lda #spr_blank                      ; Alive: the first death frame, &15...
    sta monster_sprite,x                ; ...and update_monsters plays out its death
    inc magic_kill_count                ; ...a kill to score
; &7692 referenced 2 times by &7681, &7688
.next_monster_magic
    dex                                 ; Next monster down
    bne check_magic_monster             ; Until monster 1 is done
; Score a point for each kill, to the caster, through add_point.
    lda sprite_number                   ; One point for each monster killed
    lsr a                               ; ...halve the view_room index back to the hero
    tax                                 ; ...X = the caster, who scores the points
    ldy magic_kill_count                ; ...Y = the monsters killed
; &769c referenced 1 time by &76a8
.score_magic_kills
    cpy #0                              ; Any kills left to score?
    beq magic_cast                      ; None left: redraw the caster
    tya                                 ; Keep the kills left...
    pha                                 ; ...on the stack across add_point
    jsr add_point                       ; One point to the caster
    pla                                 ; Recover the kills left...
    tay                                 ; ...back in Y
    dey                                 ; One kill fewer to score
    jmp score_magic_kills               ; Score the next
; &76ab referenced 1 time by &762a
.no_magic
    jmp read_hero_keys                  ; No cast: read the movement and fire keys
; &76ae referenced 1 time by &769e
.magic_cast
    jmp draw_moved_hero                 ; Cast: no move this frame; redraw the caster
; ***************************************************************************************
; Give a point to the hero who fired a missile
;
; Score one point for the hero whose missile is in slot X. move_missiles calls this when
; a missile kills a monster (through monster_killed) and when it wears down an energy
; drainer. The firer is told by the missile's sprite base, as in flip_firer_frame: arrows
; the Ranger, fireballs the Magic-User, axes the Barbarian, and anything else the
; Fighter. add_point adds the point and redraws the score, whether or not the firer is
; still in play.
;
; On Entry:
;     X: missile slot (0-11)
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
; &76b1 referenced 2 times by &7150, &71a2
.credit_missile_owner
    ldy missile_sprite_base,x           ; Which hero fired it? Its sprite base says
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack: X becomes the hero
    tya                                 ; The sprite base, to compare
    cmp #spr_arrow_up - 1               ; ...the arrows' base, one below the up arrow?
    bne owner_fireball                  ; Not arrows: try fireballs
    ldx #0                              ; Arrows: the Ranger, hero 0
    jmp credit_owner                    ; Credit the Ranger
; &76c0 referenced 1 time by &76b9
.owner_fireball
    cmp #spr_fireball_up - 1            ; ...the fireballs' base?
    bne owner_axe                       ; Not fireballs: try axes
    ldx #1                              ; Fireballs: the Magic-User, hero 1
    jmp credit_owner                    ; Credit the Magic-User
; &76c9 referenced 1 time by &76c2
.owner_axe
    cmp #spr_axe_up - 1                 ; ...the axes' base?
    bne owner_sword                     ; Not axes: so it must be swords
    ldx #2                              ; Axes: the Barbarian, hero 2
    jmp credit_owner                    ; Credit the Barbarian
; &76d2 referenced 1 time by &76cb
.owner_sword
    ldx #3                              ; Otherwise swords: the Fighter, hero 3
; &76d4 referenced 3 times by &76bd, &76c6, &76cf
.credit_owner
    jsr add_point                       ; One point to the firer's score
    pla                                 ; Recover the missile slot...
    tax                                 ; ...in X again for move_missiles
    rts                                 ; Return with X = the missile slot again
; ***************************************************************************************
; Animate a hero who is out of play
;
; Play a dying hero's sparkles and skull, or a returning hero's skull and sparkles in
; reverse, at the cell where they fell. move_heroes calls this each frame, in the hero's
; turn, for a hero out of play (direction 0) unless nobody plays them (step &63). While
; out of play the hero's offset bytes are reused: hero_offset_y is a two-frame timer and
; hero_offset_x the step through the sequence (+1 or -1), both set by lose_health_point
; for a death and by collect_objects for a Cross of Resurrection.
;
; Every other frame, plot hero_appearance_sprites entry hero_frame at the hero's cell,
; with no pixel offset, then step hero_frame by hero_offset_x: forwards (+1) for a hero
; dying, stopping at the skull (entry 8), which is then redrawn every other frame until a
; Cross brings the hero back; backwards (-1) for a hero returning through a Cross of
; Resurrection, from entry 8. A dying hero starts from their walking frame (0 or 1),
; which lose_health_point does not reset, so the first sparkle may be skipped. A
; returning hero is put back in play as hero_frame reaches 0, so entry 0 is never shown
; on the way back: they come back in the cell where they fell, facing down, standing
; squarely in it, with health 32 (set to 33 and drawn by taking a point). move_heroes
; draws them on their next turn.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
; &76da referenced 1 time by &6e91
.animate_absent_hero
    dec hero_offset_y,x                 ; Every other frame: count down the timer...
    beq absent_frame_due                ; Timer run out: show the next sprite
    rts                                 ; Not yet: nothing to draw this frame
; Due: plot the sprite for the hero's place in the sequence at their cell.
; &76e0 referenced 1 time by &76dd
.absent_frame_due
    lda #2                              ; Restart the two-frame timer...
    sta hero_offset_y,x                 ; ...which an absent hero keeps in hero_offset_y
    jsr get_hero_cell                   ; Plot the current appearance sprite at the hero's cell
    lda #0                              ; No pixel offsets (those bytes hold timer and step)...
    sta plot_offset_x                   ; ...none across...
    sta plot_offset_y                   ; ...and none down
    lda hero_frame,x                    ; The hero's place in the appearance sequence...
    tay                                 ; ...as an index...
    lda hero_appearance_sprites,y       ; ...picks the sparkle or skull to show
    sta sprite_number                   ; ...as the sprite to plot
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack: plot_at_cell changes X
    jsr plot_at_cell                    ; Plot it in every view that shows the hero
    pla                                 ; Recover the hero number...
    tax                                 ; ...back in X
; Step to the next place, holding a dying hero at the skull (place 8).
    clc                                 ; Step to the next (+1 dying, -1 returning), stopping at 8
    lda hero_frame,x                    ; Current place in the sequence...
    adc hero_offset_x,x                 ; ...plus the step kept in hero_offset_x
    cmp #9                              ; Past the skull (place 8)?
    bcc check_hero_returned             ; No: keep the new place
    lda #8                              ; Yes: a dead hero stays on the skull
; &770b referenced 1 time by &7707
.check_hero_returned
    cmp #0                              ; Place 0? Only a returning hero gets there
    bne store_hero_frame                ; No: store the new place for the next plot
; A returning hero has reached place 0: put them back in play, facing down, squarely in their cell, with 32 health.
    lda #5                              ; Yes: back in play before place 0 is shown...
    sta hero_direction,x                ; ...facing down (direction 5)
    lda #0                              ; ...with no step or offsets...
    sta hero_step,x                     ; ...not mid-step...
    sta hero_offset_x,x                 ; ...no horizontal offset...
    sta hero_offset_y,x                 ; ...no vertical offset...
    sta hero_frame,x                    ; ...and animation frame 0
    lda #spr_digit_3                    ; ...and health 33, drawn by taking a point
    sta hero_health_tens,x              ; ...tens digit 3...
    sta hero_health_units,x             ; ...units digit 3...
    jsr lose_health_point               ; ...less a point, which also draws it: 32
    rts                                 ; Return with the hero back in play
; &772e referenced 1 time by &770d
.store_hero_frame
    sta hero_frame,x                    ; Store the new place, to show in two frames
    rts                                 ; Return; the hero stays out of play
; ***************************************************************************************
; Draw a hero
;
; Plot sprite_number at hero X's cell, shifted by their pixel offsets (half a cell along
; while a step is under way), in every view that shows it. move_heroes calls it each
; frame for every hero in play, at draw_moved_hero, with the hero's sprite for their
; direction and frame; lose_health_point calls it with the blank to erase a hero who has
; just died. cell_x and cell_y are left as plot_at_cell leaves them, as positions within
; the view, so callers needing the map cell load it again.
;
; On Entry:
;     X: hero number (0-3)
;     SPRITE_NUMBER: sprite to plot
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
; &7732 referenced 2 times by &70a4, &7244
.draw_hero
    jsr get_hero_cell                   ; The hero's map cell...
    lda hero_offset_x,x                 ; ...and the pixel offsets of a step in progress
    sta plot_offset_x                   ; ...the column offset (0 or +-2) as plot_offset_x...
    lda hero_offset_y,x                 ; ...and the row offset (0 or +-6)...
    sta plot_offset_y                   ; ...as plot_offset_y
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack: each plot leaves X = 0
    jsr plot_at_cell                    ; Plot the hero in every view showing it
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again for the caller
    rts                                 ; Return with X = the hero again
; ***************************************************************************************
; Animate the hero who fired a missile
;
; Toggle the animation frame (0 or 1) of the hero whose missile is in slot X, so the
; hero's sprite changes as they throw. move_missiles calls this on a missile's first
; move, while bit 7 of its direction still marks it as just fired; move_heroes flipped
; the frame when it fired, so this flips it back, and the throw shows for one frame. The
; firer is told by the missile's sprite base (one less than its up sprite): arrows the
; Ranger, fireballs the Magic-User, axes the Barbarian, and anything else the Fighter.
; The hero is not redrawn here; the new frame shows when move_heroes next draws them.
;
; On Entry:
;     X: missile slot (0-11)
;
; On Exit:
;     A: corrupted
;     X: preserved
; &7747 referenced 1 time by &70e1
.flip_firer_frame
    lda missile_sprite_base,x           ; Which hero fired it? Its sprite base says
    cmp #spr_arrow_up - 1               ; ...the arrows' base, one below the up arrow?
    bne firer_fireball                  ; Not arrows: try fireballs
    lda hero_frame                      ; The Ranger's animation frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame                      ; ...so the Ranger's sprite changes as they fire
    rts                                 ; Return; X is still the missile slot
; &7757 referenced 1 time by &774c
.firer_fireball
    cmp #spr_fireball_up - 1            ; ...the fireballs' base?
    bne firer_axe                       ; Not fireballs: try axes
    lda hero_frame + 1                  ; The Magic-User's animation frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame + 1                  ; ...so the Magic-User's sprite changes as they cast
    rts                                 ; Return; X is still the missile slot
; &7764 referenced 1 time by &7759
.firer_axe
    cmp #spr_axe_up - 1                 ; ...the axes' base?
    bne firer_sword                     ; Not axes: so it must be swords
    lda hero_frame + 2                  ; The Barbarian's animation frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame + 2                  ; ...so the Barbarian's sprite changes as they throw
    rts                                 ; Return; X is still the missile slot
; &7771 referenced 1 time by &7766
.firer_sword
    lda hero_frame + 3                  ; Otherwise swords: the Fighter's frame...
    eor #1                              ; ...flipped between 0 and 1...
    sta hero_frame + 3                  ; ...so the Fighter's sprite changes as they throw
    rts                                 ; Return; X is still the missile slot
; ***************************************************************************************
; Copy a hero's position to cell_x, cell_y
;
; Load hero X's map cell into cell_x and cell_y, ready for plot_at_cell. Used by
; draw_hero and animate_absent_hero.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     CELL_X: hero_x
;     CELL_Y: hero_y
;     A: hero_y
;     X: preserved
; &777a referenced 2 times by &76e5, &7732
.get_hero_cell
    lda hero_x,x                        ; The hero's map x...
    sta cell_x                          ; ...as cell_x, for plot_at_cell
    lda hero_y,x                        ; ...and map y...
    sta cell_y                          ; ...as cell_y
    rts                                 ; Return with the hero's cell in cell_x, cell_y
    equb &73                            ; Not referenced
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
; &7788 referenced 1 time by &3c42
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
; &7795 referenced 2 times by &754b, &7788
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
; &77a7 referenced 2 times by &7555, &778b
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
; &77b9 referenced 2 times by &755f, &778e
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
; &77cb referenced 2 times by &7565, &7791
.draw_view_3
    lda #view_bottom_row                ; Bottom-right view: pixel row &67...
    sta plot_y                          ; ...as the view's top pixel row
    lda #view_right_column              ; ...byte column &23...
    sta cell_x                          ; ...as the view's left screen column
    lda view_room + 6                   ; ...the room the Fighter's view shows
    sta map_ptr                         ; ...whose walls draw_room reads
    jsr draw_room                       ; Draw its walls and doors
    rts                                 ; Return with the bottom-right view redrawn
    equb &60                            ; Not referenced
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
; &77de referenced 4 times by &77a3, &77b5, &77c7, &77d9
.draw_room
    lda #>(room_walls)                  ; The room's walls are in page &0C
    sta map_ptr_hi                      ; ...so map_ptr points at the room's wall bytes
; Walls: paint each of the room's eight rows of cells, wall or blank, from its wall byte, twelve pixel rows apart.
    ldy #0                              ; For each of the room's eight rows of cells...
; &77e4 referenced 1 time by &77fa
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
; &77fe referenced 1 time by &781d
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
; &7820 referenced 1 time by &77eb
.draw_room_row
    lda cell_x                          ; Start at the view's left edge
    sta plot_x                          ; ...as the first cell's screen column
    ldx #&80                            ; Bit mask, starting with the leftmost cell
; &7827 referenced 1 time by &784f
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
; &783e referenced 1 time by &7832
.plot_blank
    lda #spr_blank                      ; Plot the blank (sprite &15)
    sta sprite_number                   ; ...as the sprite to plot
    jsr plot_sprite                     ; Clear whatever the view showed there
; &7845 referenced 1 time by &783b
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
; &7852 referenced 19 times by &38e8, &3940, &4476, &451c, &45a1, &46ad, &46f7, &472c, &7091, &70f9, &7213, &7320, &76f9, &7741, &7817, &79db, &7a07, &7b25, &7b5c
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
; &78ad referenced 1 time by &7899
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
; &78c7 referenced 1 time by &78b3
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
; &78e1 referenced 1 time by &78cd
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
; &78fb referenced 1 time by &78e7
.plot_at_cell_done
    rts                                 ; Return; cell_x, cell_y now hold the view position
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
; &78fc referenced 8 times by &20d3, &20e1, &20ef, &6fb2, &712b, &753a, &7675, &7a51
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
; &7938 referenced 2 times by &70b5, &7166
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
; &7974 referenced 4 times by &6fdc, &713f, &7a8c, &7ce6
.find_creature
    ldx #max_monster                    ; Monsters 30 to 1, alive or dying...
; &7976 referenced 1 time by &798e
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
; &798d referenced 3 times by &7979, &7981, &7989
.next_monster_find
    dex                                 ; Next monster down
    bne check_monster                   ; Until monster 1 is done
; Then, only for a monster asking, heroes: the first in the cell, in play or not, is hurt and blocks the move.
    lda scratch                         ; No monster there. Is a monster asking (scratch > 0)?
    beq nothing_found                   ; No (a hero or missile): heroes are not looked for
    ldx #0                              ; Yes: a hero blocks it too. Heroes 0 to 3...
; &7997 referenced 1 time by &79ba
.check_hero
    lda cell_x                          ; ...is this hero in the cell? cell_x...
    cmp hero_x,x                        ; ...against the hero's x
    bne next_hero_find                  ; Another column: not this hero
    lda cell_y                          ; ...and cell_y...
    cmp hero_y,x                        ; ...against the hero's y
    bne next_hero_find                  ; Another row: not this hero
    ldy hero_damage_taken,x             ; Found, in play or not: health a blow costs them
; &79aa referenced 1 time by &79b2
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
; &79b7 referenced 2 times by &799d, &79a5
.next_hero_find
    inx                                 ; Next hero up
    cpx #4                              ; All four heroes checked?
    bne check_hero                      ; No: check the next
; &79bc referenced 1 time by &7993
.nothing_found
    lda #0                              ; Nothing there: return A = Y = 0...
    ldy #0                              ; ...the cell is free of creatures
    rts                                 ; Return with Z set: nothing in the cell
; ***************************************************************************************
; Draw the trapdoors and move the monsters
;
; Move every monster on by one frame of its life, and redraw the trapdoors they come out
; of. update_game calls it once a frame, after draw_objects and move_missiles, so a
; monster killed by a missile or magic this frame starts its death here.
;
; The eight trapdoors are drawn first, because erasing a creature or missile that crossed
; one has blanked its cell. Then each monster, 30 down to 1, is erased where it was drawn
; last frame and moved on according to its state.
;
; Moving: a monster mid-step slides a quarter cell further (continue_monster_step). One
; that is not stepping tries the next cell the way it faces. If that cell is open and
; holds no creature, it starts a step: monster_x and monster_y keep the old cell while
; the offsets carry the sprite across, so an interior cell takes four frames (a quarter,
; a half, three quarters, then square in the new cell). A cell in a room's edge row or
; column, in the direction of travel, is entered at once, so no sprite is drawn between
; two rooms and a monster crosses from one room into the next in two frames.
;
; Blocked: a wall, a closed door or a creature in the cell keeps the monster where it is.
; It turns a random way, each of the four equally likely, from the System VIA's timer 1,
; and tries that way next frame. A monster does not chase anyone: it walks straight on
; until blocked. find_creature takes hero_damage_taken points from a hero it finds in the
; cell, so a monster hurts a hero each time it tries to step into them.
;
; Dying: a monster killed by a missile or by magic is given sprite &15 (the blank) there.
; Each frame here advances it through the sparkles &16-&19, drawn where it died.
;
; Reappearing: after the last sparkle monster_reappears puts it on the next trapdoor in
; turn, facing up, to be drawn next frame.
;
; reset_monsters starts every monster at the blank with x &FF, so at the start of a level
; all 30 sparkle off the map together and emerge on the same frame, shared out round the
; eight trapdoors in turn. Only the target cell is ever tested for a creature: during a
; slide the monster is still recorded in the cell it is leaving, and the arrival is not
; checked again, so two monsters, or a monster and a hero, can end a step in the same
; cell. The creature test made as a monster reappears looks at the wrong cell (see
; monster_reappears).
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
; &79c1 referenced 1 time by &4614
.update_monsters
    ldx #8                              ; Redraw trapdoors 8 to 1 (sprite &2C)...
    lda #0                              ; Trapdoors sit squarely in their cells:
    sta plot_offset_x                   ; ...no horizontal offset...
    sta plot_offset_y                   ; ...and no vertical offset
    lda #spr_trapdoor                   ; The trapdoor sprite...
    sta sprite_number                   ; ...the same for all eight
; &79cd referenced 1 time by &79e1
.draw_trapdoor
    lda trapdoor_x - 1,x                ; This trapdoor's map x...
    sta cell_x                          ; ...as the cell to plot
    lda trapdoor_y - 1,x                ; ...and its map y
    sta cell_y                          ; ...as cell_y
    txa                                 ; Keep the trapdoor number...
    pha                                 ; ...on the stack: plot_at_cell changes X
    jsr plot_at_cell                    ; Draw it in every view showing its cell
    pla                                 ; Recover the trapdoor number...
    tax                                 ; ...back in X
    dex                                 ; Next trapdoor down
    bne draw_trapdoor                   ; Until trapdoor 1 is drawn
    ldx #max_monster                    ; Then each monster, 30 to 1...
; Each monster in turn, 30 down to 1. It is first rubbed out where it was drawn last frame, its cell and offsets plotted with the blank sprite, and its cell is kept in previous_x and previous_y. Then its state decides what happens: a dying monster (sprite &15 and up) shows its next sparkle, one part way through a step slides on, and any other tries a new step. The monster number stays on the stack until monster_done.
; &79e5 referenced 1 time by &7b2d
.next_monster_update
    txa                                 ; Keep the monster number...
    pha                                 ; ...on the stack while it moves
    lda monster_x,x                     ; Erase it at its cell and offsets, remembering the cell
    sta cell_x                          ; ...as the cell to erase...
    sta previous_x                      ; ...and as where it came from
    lda monster_y,x                     ; ...and its map y...
    sta cell_y                          ; ...as the cell to erase...
    sta previous_y                      ; ...and as where it came from
    lda #spr_blank                      ; The blank sprite...
    sta sprite_number                   ; ...to rub it out
    lda monster_offset_x,x              ; Its horizontal offset...
    sta plot_offset_x                   ; ...for the erase
    lda monster_offset_y,x              ; ...and its vertical offset...
    sta plot_offset_y                   ; ...so the blank covers it where it was drawn
    jsr plot_at_cell                    ; Rub the monster out in every view showing it
    pla                                 ; The monster number back from the stack...
    pha                                 ; ...left there for monster_done
    tax                                 ; ...in X again
    lda monster_sprite,x                ; Is the monster dying?
    cmp #spr_blank                      ; Sprite &15 (the blank) and up: killed
    bcc check_monster_step              ; Below &15: alive, so it moves
    jmp advance_dying_monster           ; Killed: show its next sparkle
; &7a17 referenced 1 time by &7a12
.check_monster_step
    lda monster_step,x                  ; Part way through a step?
    beq start_monster_move              ; No: try a step to the next cell
    jsr continue_monster_step           ; Yes: slide it a quarter cell further
    pla                                 ; Drop the stacked number (X still has it)...
    jmp draw_monster                    ; ...as draw_monster pushes it again
; A monster that is not stepping tries the next cell the way it faces. Its cell is moved there provisionally and the step's first offsets are set, then the cell is tested: first for a wall or closed door, then for a creature.
; &7a23 referenced 1 time by &7a1a
.start_monster_move
    lda monster_sprite,x                ; Step into the next cell in the way it faces: up...
    cmp #spr_monster_up_0               ; Sprite 9, facing up?
    bne monster_right                   ; No: try right
    dec monster_y,x                     ; Yes: one row up
; &7a2d referenced 1 time by &7a28
.monster_right
    cmp #spr_monster_right_0            ; Sprite &0B, facing right?
    bne monster_down                    ; No: try down
    inc monster_x,x                     ; Yes: one column right
; &7a34 referenced 1 time by &7a2f
.monster_down
    cmp #spr_monster_down_0             ; Sprite &0D, facing down?
    bne monster_left                    ; No: try left
    inc monster_y,x                     ; Yes: one row down
; &7a3b referenced 1 time by &7a36
.monster_left
    cmp #spr_monster_left_0             ; Sprite &0F, facing left?
    bne set_monster_step                ; No: it does not move
    dec monster_x,x                     ; Yes: one column left
; &7a42 referenced 1 time by &7a3d
.set_monster_step
    jsr start_monster_step              ; First quarter-cell offsets of the step
    lda monster_x,x                     ; Is the new cell a wall (or a closed door)?
    sta cell_x                          ; ...the new x as cell_x
    lda monster_y,x                     ; The new y...
    sta cell_y                          ; ...as cell_y: the cell to test
    jsr test_wall                       ; Z set if the cell is open
    beq check_monster_blocked           ; Open: is a creature in the way?
; Blocked by a wall: the monster goes back to the cell it was in, with no step under way, and faces a random way. A random 0-7 + 8 gives a sprite &08-&0F; an even one is rounded up to the facing above it, so up, right, down and left are each chosen 2 times in 8. It tries that way on the next frame.
    pla                                 ; Wall: the monster stays where it is...
    tax                                 ; ...its number back in X, which test_wall changed
    lda previous_x                      ; The cell it was in...
    sta monster_x,x                     ; ...back in monster_x
    lda previous_y                      ; ...and its row...
    sta monster_y,x                     ; ...back in monster_y
    lda #0                              ; No step under way:
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    lda system_via_t1c_l                ; Turn a random way, from the System VIA's timer
    and #7                              ; A random 0-7...
    clc                                 ; ...+ 8, the first monster sprite...
    adc #8                              ; ...a sprite &08-&0F
    sta monster_sprite,x                ; Face the monster that way
    and #1                              ; Odd sprites (9, &0B, &0D, &0F) are the facings
    beq turn_monster                    ; Even: round it up to the next facing
    jmp draw_monster                    ; Odd: draw it; it tries the new way next frame
; &7a81 referenced 1 time by &7a7c
.turn_monster
    inc monster_sprite,x                ; Round up: each way is equally likely, 2 in 8
    jmp draw_monster                    ; Draw it; it tries the new way next frame
; The cell is open: is a monster or hero standing in it? find_creature skips this monster and, because scratch is non-zero, takes hero_damage_taken points from a hero it finds there. A monster mid-slide is still recorded in the cell it is leaving, so it does not block the cell it is entering.
; &7a87 referenced 1 time by &7a54
.check_monster_blocked
    pla                                 ; Monster or hero in the new cell? (a hero there is hurt)
    pha                                 ; ...left stacked for later
    sta scratch                         ; Non-zero scratch: skip this monster, check heroes
    jsr find_creature                   ; A = 0 if no creature is at cell_x, cell_y
    cmp #0                              ; Non-zero: a monster or hero is in the cell
    beq monster_vertical                ; No: the cell is free, so the step goes ahead
; Blocked by a creature: as for a wall, the monster stays where it was, with no step, and turns a random way.
    pla                                 ; Yes: stay put, with no step, and turn a random way
    tax                                 ; ...its number back in X, which find_creature changed
    lda previous_x                      ; The cell it was in...
    sta monster_x,x                     ; ...back in monster_x
    lda previous_y                      ; ...and its row...
    sta monster_y,x                     ; ...back in monster_y
    lda #0                              ; No step under way:
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    lda system_via_t1c_l                ; Turn a random way, from the System VIA's timer
    and #7                              ; A random 0-7...
    clc                                 ; ...+ 8, the first monster sprite...
    adc #8                              ; ...a sprite &08-&0F
    sta monster_sprite,x                ; Face the monster that way
    and #1                              ; Odd sprites (9, &0B, &0D, &0F) are the facings
    bne draw_monster                    ; Odd: draw it; it tries the new way next frame
    inc monster_sprite,x                ; Even: round it up to the next facing
    jmp draw_monster                    ; Draw it; it tries the new way next frame
; The step goes ahead. A step into a cell on a room's edge row (moving up or down) or edge column (moving across) is made at once, with no slide, so the sprite is never drawn part way between two rooms. Any other step keeps the old cell in monster_x and monster_y and lets the offsets carry the sprite across over four frames.
; &7ac1 referenced 1 time by &7a91
.monster_vertical
    pla                                 ; The step goes ahead...
    tax                                 ; ...its number back in X, which find_creature changed
    lda monster_sprite,x                ; Which way is it going?
    cmp #spr_monster_up_0               ; Moving up, so the new row decides?
    beq check_room_edge                 ; Yes: check the new row
    cmp #spr_monster_down_0             ; Moving down, likewise?
    beq check_room_edge                 ; Yes: check the new row
    lda monster_x,x                     ; Across: is the new cell in a room's edge column?
    and #7                              ; Column within its eight-cell room
    beq monster_at_edge                 ; Column 0: the left edge
    cmp #7                              ; Column 7, the right edge?
    beq monster_at_edge                 ; Yes: an edge
    jmp monster_move_on                 ; No: slide there over the coming frames
; &7adc referenced 2 times by &7ac8, &7acc
.check_room_edge
    lda monster_y,x                     ; Up or down: is the new cell in a room's edge row?
    and #7                              ; Row within its eight-cell room
    beq monster_at_edge                 ; Row 0: the top edge
    cmp #7                              ; Row 7, the bottom edge?
    beq monster_at_edge                 ; Yes: an edge
    jmp monster_move_on                 ; No: slide there over the coming frames
; &7aea referenced 4 times by &7ad3, &7ad7, &7ae1, &7ae5
.monster_at_edge
    lda #0                              ; Edge: jump straight in, so no slide crosses rooms
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    jmp draw_monster                    ; Draw it squarely in the new cell
; &7af8 referenced 2 times by &7ad9, &7ae7
.monster_move_on
    lda previous_x                      ; Slide: keep the old cell until the step ends...
    sta monster_x,x                     ; ...back in monster_x
    lda previous_y                      ; ...and its row...
    sta monster_y,x                     ; ...back in monster_y: drawn offset from there
; Draw the monster at its recorded cell, displaced by its offsets, as its facing sprite plus its walking frame, in every view that shows the room. The dying and reappearing paths join at monster_done, which pulls the monster number and moves on to the next.
; &7b04 referenced 6 times by &7a20, &7a7e, &7a84, &7ab9, &7abe, &7af5
.draw_monster
    lda monster_x,x                     ; Draw it: its cell, facing + frame, offsets
    sta cell_x                          ; ...as cell_x for plot_at_cell
    lda monster_y,x                     ; Its map y...
    sta cell_y                          ; ...as cell_y for plot_at_cell
    clc                                 ; Ready to add the frame
    lda monster_sprite,x                ; Its facing sprite...
    adc monster_frame,x                 ; ...plus walking frame 0 or 1...
    sta sprite_number                   ; ...is the sprite to plot
    lda monster_offset_x,x              ; How far it has slid across...
    sta plot_offset_x                   ; ...as the horizontal offset
    lda monster_offset_y,x              ; How far it has slid down...
    sta plot_offset_y                   ; ...as the vertical offset
    txa                                 ; Keep the monster number...
    pha                                 ; ...across the plot, which changes X
    jsr plot_at_cell                    ; Draw it in every view whose room shows it
; &7b28 referenced 3 times by &7b5f, &7cf8, &7cfb
.monster_done
    pla                                 ; The monster number back from the stack...
    tax                                 ; ...in X, to count on down
    dex                                 ; Next monster down
    beq update_monsters_done            ; Past monster 1: all 30 updated
    jmp next_monster_update             ; Otherwise update the next one
; &7b30 referenced 1 time by &7b2b
.update_monsters_done
    rts                                 ; Return: every monster moved and drawn
; A killed monster is set to sprite &15 (the blank). Each frame the sprite advances, showing the sparkles &16-&19 at the cell and offsets it died at; after the last the monster reappears. Its step counter is left as it was, since a dying monster is dispatched before the step is looked at.
; &7b31 referenced 1 time by &7a14
.advance_dying_monster
    pla                                 ; Drop the stacked number (X still has it)
    inc monster_sprite,x                ; Next death frame: &16-&19 are the sparkles
    lda monster_sprite,x                ; Which frame now?
    cmp #spr_sparkle_3 + 1              ; Past the last sparkle (&19)?
    bne draw_monster_death              ; No: draw this sparkle
    jmp monster_reappears               ; Yes: bring it back at a trapdoor
; &7b3f referenced 1 time by &7b3a
.draw_monster_death
    txa                                 ; Draw the sparkle where the monster died...
    pha                                 ; ...keeping the monster number across the plot
    lda monster_x,x                     ; Its map x, where it died...
    sta cell_x                          ; ...as cell_x for plot_at_cell
    lda monster_y,x                     ; ...and its map y...
    sta cell_y                          ; ...as cell_y for plot_at_cell
    lda monster_sprite,x                ; The sparkle sprite, with no walking frame...
    sta sprite_number                   ; ...is the sprite to plot
    lda monster_offset_x,x              ; Offsets frozen at the moment it died...
    sta plot_offset_x                   ; ...across, as plot_offset_x
    lda monster_offset_y,x              ; ...and how far down it had slid...
    sta plot_offset_y                   ; ...so it sparkles exactly where it died
    jsr plot_at_cell                    ; Draw the sparkle in every view showing it
    jmp monster_done                    ; Pull the monster number and on to the next
; ***************************************************************************************
; Start a hero's step between cells
;
; Called by move_heroes when a direction key starts a move within a room and the hero has
; no Boots of Speed. Set hero X's step counter to 1 and their pixel offsets to half a
; cell in the direction they face (hero_direction 1, 3, 5 or 7: up, right, down, left): 6
; rows up or down, or 2 byte columns left or right. move_heroes then draws the hero
; there, half way to the next cell, for one frame, still recorded in the old cell;
; continue_hero_step completes the move on the next frame.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: corrupted
;     X: preserved
; &7b62 referenced 4 times by &6ece, &6ee1, &6ef4, &6f07
.start_hero_step
    lda #1                              ; One frame to go before the hero is in the new cell
    sta hero_step,x                     ; ...as hero_step: continue_hero_step ends it
    lda hero_direction,x                ; Draw the hero half a cell along the way they face
    cmp #1                              ; Direction 1, facing up?
    bne hero_step_right                 ; No: try right
    lda #0                              ; Up: not across...
    sta hero_offset_x,x                 ; ...no horizontal offset
    lda #&fa                            ; -6: half a 12-row cell up...
    sta hero_offset_y,x                 ; ...as the vertical offset
    rts                                 ; Return: drawn half a cell up
; &7b79 referenced 1 time by &7b6c
.hero_step_right
    cmp #3                              ; Direction 3, facing right?
    bne hero_step_down                  ; No: try down
    lda #0                              ; Right: not up or down...
    sta hero_offset_y,x                 ; ...no vertical offset
    lda #2                              ; +2: half a 4-byte cell right...
    sta hero_offset_x,x                 ; ...as the horizontal offset
    rts                                 ; Return: drawn half a cell right
; &7b88 referenced 1 time by &7b7b
.hero_step_down
    cmp #5                              ; Direction 5, facing down?
    bne hero_step_left                  ; No: they face left
    lda #0                              ; Down: not across...
    sta hero_offset_x,x                 ; ...no horizontal offset
    lda #6                              ; +6: half a cell down...
    sta hero_offset_y,x                 ; ...as the vertical offset
    rts                                 ; Return: drawn half a cell down
; &7b97 referenced 1 time by &7b8a
.hero_step_left
    lda #0                              ; Left: not up or down...
    sta hero_offset_y,x                 ; ...no vertical offset
    lda #&fe                            ; -2: half a cell left...
    sta hero_offset_x,x                 ; ...as the horizontal offset
    rts                                 ; Return: drawn half a cell left
; ***************************************************************************************
; Continue a hero's step between cells
;
; Called by move_heroes, in place of reading the hero's keys, on the frame after a step
; starts. Toggle hero X's walking frame and count down their step. When it ends, move the
; hero one cell in the direction they face and clear the pixel offsets, so a step takes
; two frames. The offsets are then doubled. Since start_hero_step sets the counter to 1
; and nothing else gives an in-play hero a non-zero step, the step always ends here, so
; the doubling only ever doubles zero offsets.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     A: corrupted
;     X: preserved
; &7ba2 referenced 1 time by &6eb4
.continue_hero_step
    lda hero_frame,x                    ; Swap the hero's walking frame...
    eor #1                              ; ...0 to 1 or 1 to 0...
    sta hero_frame,x                    ; ...so their legs move
    dec hero_step,x                     ; One frame fewer to the new cell
    bne double_offsets                  ; Not there yet (never taken: the step is 1)
    lda hero_direction,x                ; Arrived: move their cell on the way they face: up...
    cmp #1                              ; Direction 1, facing up?
    bne continue_right                  ; No: try right
    dec hero_y,x                        ; Yes: one row up
; &7bb9 referenced 1 time by &7bb4
.continue_right
    cmp #3                              ; Direction 3, facing right?
    bne continue_down                   ; No: try down
    inc hero_x,x                        ; Yes: one column right
; &7bc0 referenced 1 time by &7bbb
.continue_down
    cmp #5                              ; Direction 5, facing down?
    bne continue_left                   ; No: try left
    inc hero_y,x                        ; Yes: one row down
; &7bc7 referenced 1 time by &7bc2
.continue_left
    cmp #7                              ; Direction 7, facing left?
    bne hero_no_offsets                 ; No: no move
    dec hero_x,x                        ; Yes: one column left
; &7bce referenced 1 time by &7bc9
.hero_no_offsets
    lda #0                              ; Drawn squarely in the new cell:
    sta hero_offset_x,x                 ; ...no horizontal offset
    sta hero_offset_y,x                 ; ...no vertical offset
; &7bd6 referenced 1 time by &7bad
.double_offsets
    clc                                 ; Double the offsets, which are always zero by now
    lda hero_offset_x,x                 ; Horizontal offset x 2: the offset...
    adc hero_offset_x,x                 ; ...added to itself...
    sta hero_offset_x,x                 ; ...stored back, still 0
    clc                                 ; Ready for the vertical offset
    lda hero_offset_y,x                 ; Vertical offset x 2: the offset...
    adc hero_offset_y,x                 ; ...added to itself...
    sta hero_offset_y,x                 ; ...stored back, still 0
    rts                                 ; Return: the hero is squarely in the new cell
; ***************************************************************************************
; Start a monster's step between cells
;
; Called by update_monsters when a monster that is not stepping tries the next cell,
; before that cell is tested. Set monster X's step counter to 3 and its offsets to the
; first quarter of a cell in the direction it faces: 3 rows up or down, or one byte
; column left or right. If the cell turns out to be blocked, or on a room's edge,
; update_monsters clears all three again; otherwise the monster is drawn this frame a
; quarter of the way there, and continue_monster_step takes over on the next.
;
; On Entry:
;     X: monster number (1-30)
;
; On Exit:
;     A: corrupted
;     X: preserved
; &7beb referenced 1 time by &7a42
.start_monster_step
    lda #3                              ; Three more frames to reach the new cell...
    sta monster_step,x                  ; ...as the step count
    lda monster_sprite,x                ; Draw it a quarter cell along the way it faces: up...
    cmp #spr_monster_up_0               ; Sprite 9, facing up?
    bne monster_step_right              ; No: try right
    lda #0                              ; Up: not across...
    sta monster_offset_x,x              ; ...no horizontal offset
    lda #&fd                            ; -3: a quarter of a 12-row cell up...
    sta monster_offset_y,x              ; ...as the vertical offset
    rts                                 ; Return: drawn a quarter cell up
; &7c02 referenced 1 time by &7bf5
.monster_step_right
    cmp #spr_monster_right_0            ; Sprite &0B, facing right?
    bne monster_step_down               ; No: try down
    lda #0                              ; Right: not up or down...
    sta monster_offset_y,x              ; ...no vertical offset
    lda #1                              ; +1: a quarter of a 4-byte cell right...
    sta monster_offset_x,x              ; ...as the horizontal offset
    rts                                 ; Return: drawn a quarter cell right
; &7c11 referenced 1 time by &7c04
.monster_step_down
    cmp #spr_monster_down_0             ; Sprite &0D, facing down?
    bne monster_step_left               ; No: it faces left
    lda #0                              ; Down: not across...
    sta monster_offset_x,x              ; ...no horizontal offset
    lda #3                              ; +3: a quarter of a cell down...
    sta monster_offset_y,x              ; ...as the vertical offset
    rts                                 ; Return: drawn a quarter cell down
; &7c20 referenced 1 time by &7c13
.monster_step_left
    lda #0                              ; Left: not up or down...
    sta monster_offset_y,x              ; ...no vertical offset
    lda #&ff                            ; -1: a quarter of a cell left...
    sta monster_offset_x,x              ; ...as the horizontal offset
    rts                                 ; Return: drawn a quarter cell left
; ***************************************************************************************
; Continue a monster's step between cells
;
; Called by update_monsters each frame while monster X's step is under way (monster_step
; non-zero). Toggle its walking frame, so its legs move, and count down its step. On the
; first two calls the offsets grow by another quarter of a cell (a byte column or three
; rows), to a half and then three quarters. On the third the step ends: monster_x or
; monster_y moves one cell on the way it faces and the offsets are cleared, so it is
; drawn squarely in the new cell. With the frame start_monster_step began, a monster
; crosses an interior cell in four frames. Nothing tests the new cell again on arrival.
;
; On Entry:
;     X: monster number (1-30)
;
; On Exit:
;     A: corrupted
;     X: preserved
; &7c2b referenced 1 time by &7a1c
.continue_monster_step
    lda monster_frame,x                 ; Swap the monster's walking frame...
    eor #1                              ; ...0 to 1 or 1 to 0...
    sta monster_frame,x                 ; ...so its legs move as it slides
    dec monster_step,x                  ; One frame fewer to the new cell
    bne grow_offset_x                   ; Not there yet: slide a quarter cell further
    lda monster_sprite,x                ; Arrived: move its cell on the way it faces: up...
    cmp #spr_monster_up_0               ; Sprite 9, facing up?
    bne monster_continue_right          ; No: try right
    dec monster_y,x                     ; Yes: one row up
; &7c42 referenced 1 time by &7c3d
.monster_continue_right
    cmp #spr_monster_right_0            ; Sprite &0B, facing right?
    bne monster_continue_down           ; No: try down
    inc monster_x,x                     ; Yes: one column right
; &7c49 referenced 1 time by &7c44
.monster_continue_down
    cmp #spr_monster_down_0             ; Sprite &0D, facing down?
    bne monster_continue_left           ; No: try left
    inc monster_y,x                     ; Yes: one row down
; &7c50 referenced 1 time by &7c4b
.monster_continue_left
    cmp #spr_monster_left_0             ; Sprite &0F, facing left?
    bne monster_no_offsets              ; No: no move
    dec monster_x,x                     ; Yes: one column left
; &7c57 referenced 1 time by &7c52
.monster_no_offsets
    lda #0                              ; Drawn squarely in the new cell:
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset (zeros don't grow)
; &7c5f referenced 1 time by &7c36
.grow_offset_x
    lda monster_offset_x,x              ; Slide across a further quarter cell (a byte column)
    beq grow_offset_y                   ; Zero: moving up or down, or arrived
    bpl grow_offset_x_right             ; Positive: moving right
    dec monster_offset_x,x              ; Negative: one more column left
    jmp grow_offset_y                   ; Now the vertical offset
; &7c6c referenced 1 time by &7c64
.grow_offset_x_right
    inc monster_offset_x,x              ; One more column right
; &7c6f referenced 2 times by &7c62, &7c69
.grow_offset_y
    lda monster_offset_y,x              ; Slide down or up a further quarter cell (3 rows)
    beq monster_step_done               ; Zero: moving across, or arrived
    bpl grow_offset_y_down              ; Positive: moving down
    sec                                 ; Moving up: three more rows up...
    lda monster_offset_y,x              ; ...from the vertical offset...
    sbc #3                              ; ...three rows further up...
    sta monster_offset_y,x              ; ...to -6 or -9
    jmp monster_step_done               ; Offsets grown: return
; &7c82 referenced 1 time by &7c74
.grow_offset_y_down
    clc                                 ; Moving down: three more rows down...
    lda monster_offset_y,x              ; ...from the vertical offset...
    adc #3                              ; ...three rows further down...
    sta monster_offset_y,x              ; ...to 6 or 9
; &7c8b referenced 2 times by &7c72, &7c7f
.monster_step_done
    rts                                 ; Return: offsets grown, or the step ended
    equb &de, &35, &0d, &bd, &35, &0d, &d0, &00
    equb &60                            ; Not referenced
; ***************************************************************************************
; Test whether a key is pressed
;
; Report whether one key is held down at this moment. read_hero_keys calls it for each
; hero's direction and fire keys, from the hero_key tables, and check_magic for the
; Ranger's and Magic-User's magic keys. The key is scanned with OSBYTE &81 and a negative
; INKEY number (Y = &FF), which returns X = Y = &FF if it is held; the caller's X, the
; hero number, is kept on the stack across the call.
;
; On Entry:
;     A: INKEY key number (negative, as a byte)
;
; On Exit:
;     A: 0 if the key is pressed, 1 if not
;     Z: set if the key is pressed
;     X: preserved
;     Y: corrupted
; &7c95 referenced 6 times by &6ec4, &6ed7, &6eea, &6efd, &6f10, &7627
.test_key
    tay                                 ; Park the INKEY number in Y for a moment
    txa                                 ; Keep the caller's X (the hero number)...
    pha                                 ; ...on the stack, as OSBYTE returns in X
    tya                                 ; The INKEY number...
    tax                                 ; ...in X, as OSBYTE &81 wants it
    lda #osbyte_inkey                   ; OSBYTE &81 with Y = &FF: scan the key
    ldy #&ff                            ; Y = &FF: scan the one key, not wait
    jsr osbyte                          ; Scan it: X = Y = &FF if the key is held.  Test whether the key with negative INKEY number X is pressed
    cpy #&ff                            ; Held only if both Y and X come back &FF
    bne key_not_pressed                 ; Y not &FF: the key is up
    cpx #&ff                            ; X = &FF too?
    bne key_not_pressed                 ; No: the key is up
    pla                                 ; Held: the caller's X back from the stack...
    tax                                 ; ...the hero number again
    lda #0                              ; A = 0, Z set: the key is held
    rts                                 ; Return with Z set: the key is held
; &7cae referenced 2 times by &7ca3, &7ca7
.key_not_pressed
    pla                                 ; Up: the caller's X back from the stack...
    tax                                 ; ...the hero number again
    lda #1                              ; A = 1, Z clear: the key is up
    rts                                 ; Return with Z clear: the key is up
; The monster comes back facing up on the next trapdoor in turn, with the hit points the kill gave it back. It is not drawn until next frame. The creature test that follows reads cell_x and cell_y, which still hold the dying monster's position within its view, as the erase's plot_at_cell left them, not the trapdoor's cell. So a creature already on the trapdoor does not stop the monster emerging; one that happens to stand at the unrelated cell the leftovers name parks the monster at &FF,&FF, still alive, where nothing returns it to a trapdoor (and a hero there is hurt).
; &7cb3 referenced 1 time by &7b3c
.monster_reappears
    inc next_trapdoor                   ; Each reappearance uses the next trapdoor in turn
    lda next_trapdoor                   ; Which trapdoor now?
    cmp #8                              ; Past the eighth (7)?
    bne emerge_at_trapdoor              ; No: emerge there
    lda #0                              ; Yes: wrap round to trapdoor 0...
    sta next_trapdoor                   ; ...for this monster and the next
; &7cc2 referenced 1 time by &7cbb
.emerge_at_trapdoor
    ldy next_trapdoor                   ; Y = the trapdoor to emerge from
    lda trapdoor_x,y                    ; Put the monster on it, facing up, with no step
    sta monster_x,x                     ; ...the trapdoor's x as the monster's
    lda trapdoor_y,y                    ; The trapdoor's y...
    sta monster_y,x                     ; ...as the monster's
    lda #spr_monster_up_0               ; Facing up (sprite 9)...
    sta monster_sprite,x                ; ...ends the death: alive again, drawn next frame
    lda #0                              ; No step under way:
    sta monster_step,x                  ; ...step count 0
    sta monster_offset_x,x              ; ...no horizontal offset
    sta monster_offset_y,x              ; ...no vertical offset
    txa                                 ; Test for a creature at cell_x, cell_y...
    pha                                 ; ...stacking the number for monster_done
    stx scratch                         ; Non-zero scratch: skip this monster, check heroes
    jsr find_creature                   ; cell_x/y: plot_at_cell's leftovers, not the trapdoor
    cmp #0                              ; A = 0 if nothing is at that cell
    beq emerge_done                     ; Nothing there: the monster stays on the trapdoor
    pla                                 ; Something there: park it off the map, still alive
    pha                                 ; ...keeping it stacked for monster_done
    tax                                 ; ...its number in X, which find_creature changed
    lda #off_map                        ; Off the map...
    sta monster_x,x                     ; ...as its x
    sta monster_y,x                     ; ...and its y: no trapdoor will take it back
    jmp monster_done                    ; Pull the monster number and on to the next
; &7cfb referenced 1 time by &7ceb
.emerge_done
    jmp monster_done                    ; Pull the monster number and on to the next
    equb &00                            ; Not referenced
; Hit points a monster starts with on this level: 6 + 2 x the level number (8 on level 1).
; &7cff referenced 3 times by &355b, &3ccf, &759b
.monster_start_hit_points
    equb &08
; Initial contents of page &0D, copied there at the start of every level.
; ***************************************************************************************
; Workspace template
;
; The starting contents of page &0D, the heroes' and missiles' workspace, which
; reset_workspace copies there whole at the start of every level. Byte +n becomes &0D00 +
; n. It sets the heroes in the four cells of the start, facing four ways and not
; stepping; every missile slot empty; each hero's direction and fire keys (hero_key_up
; etc. at +&70, as negative INKEY numbers for test_key); health digits 9 and 9 + 1 (+&90,
; +&95), which read 99 once draw_status_panel has taken a point; every view on the start
; room (+&A0); the heroes' and missiles' sprite bases (+&B0, +&B5); the bit masks
; test_wall and test_object_free use (+&C0); and the panel rows (+&D0). The bytes between
; variables are copied with the rest.
; &7d00 used as index base 1 time by &3be2
.workspace_template
    equb &00                            ; scratch: working byte
    equb &00                            ; scratch2: working byte
    equb &1f                            ; cell_x: set before use
    equb &1f                            ; cell_y: set before use
    equb &d2                            ; cell_room: set before use
    equb &d2                            ; Copied to &0D05: no variable starts here
    equb &cc                            ; previous_x: set before use
    equb &b1                            ; previous_y: set before use
    equb &07                            ; previous_offset_x: set before use
    equb &07                            ; previous_offset_y: set before use
    equb &01, &01, &00, &2c, &34, &3c   ; Copied to &0D0A: no variable starts here
    equb &0b, &0b, &0c, &0c             ; hero_x: the heroes start at x 11, 11, 12, 12...
    equb &2f                            ; Copied to &0D14: no variable starts here
    equb &0b, &0c, &0b, &0c             ; hero_y: ...and y 11, 12, 11, 12, the four cells of the start
    equb &26                            ; Copied to &0D19: no variable starts here
    equb &01, &03, &05, &07             ; hero_direction: facing up, right, down and left
    equb &2d, &2f                       ; Copied to &0D1E: no variable starts here
    equb &01, &01, &01, &01             ; hero_frame: walking frame 1 for every hero
    equb &5d                            ; Copied to &0D24: no variable starts here
    equb &00, &00, &00, &00             ; hero_step: not stepping
    equb &16                            ; Copied to &0D29: no variable starts here
    equb &00, &00, &00, &00             ; hero_offset_x: no offset
    equb &1d, &1f                       ; Copied to &0D2E: no variable starts here
    equb &00, &00, &00, &00             ; hero_offset_y: no offset
    equb &03, &05, &07, &05, &07, &36, &35, &37
    equb &3c, &3e, &3d, &3f             ; Copied to &0D34: no variable starts here
    equb &01, &82, &81, &83, &88, &8a, &89, &8b
    equb &84, &86, &85, &87             ; missile_x: unused while the slots are empty
    equb &8c, &8e, &8d, &8f, &08, &48, &8a, &48
    equb &98, &48, &ae, &ff             ; missile_y: unused while the slots are empty
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00             ; missile_direction: every slot empty
    equb &15, &85, &7a, &8a, &48, &20, &00, &09
    equb &68, &aa, &bd, &08             ; missile_sprite_base: set when a missile is fired
    equb inkey_key_caps_lock, inkey_key_right, inkey_key_k, inkey_key_g  ; hero_key_up: heroes 0-3, read through test_key
    equb inkey_key_shift_lock, inkey_key_up, inkey_key_comma, inkey_key_b  ; hero_key_down: likewise, one per hero
    equb inkey_key_z, inkey_key_copy, inkey_key_slash, inkey_key_i  ; hero_key_right: likewise
    equb inkey_key_shift, inkey_key_delete, inkey_key_full_stop, inkey_key_u  ; hero_key_left: likewise
    equb inkey_key_tab, inkey_key_down, inkey_key_space, inkey_key_o  ; hero_key_fire: likewise
    equb &0d, &c9, &05, &d0, &09, &18, &bd, &04
    equb &0d, &69, &03, &9d             ; Copied to &0D84: no variable starts here
    equb spr_digit_9, spr_digit_9, spr_digit_9, spr_digit_9  ; hero_health_tens: the 9 digit sprite...
    equb &d0                            ; Copied to &0D94: no variable starts here
    equb spr_digit_9 + 1, spr_digit_9 + 1, spr_digit_9 + 1, spr_digit_9 + 1  ; hero_health_units: ...9 + 1: health 99 once a point is taken
    equb &18, &bd, &08, &0d, &6d, &40, &0d  ; Copied to &0D99: no variable starts here
    equb <(room_walls + &28), >(room_walls + &28), <(room_walls + &28), >(room_walls + &28), <(room_walls + &28), >(room_walls + &28), <(room_walls + &28), >(room_walls + &28)  ; view_room: every view starts on the heroes' room, &0C28
    equb &00, &00, &bd, &04, &0d, &85, &71, &8a  ; Copied to &0DA8: no variable starts here
    equb spr_arrow_up - 1, spr_fireball_up - 1, spr_axe_up - 1, spr_sword_up - 1  ; hero_missile_sprites: arrows, fireballs, axes, swords
    equb &68                            ; Copied to &0DB4: no variable starts here
    equb spr_ranger_up_0 - 1, spr_magic_user_up_0 - 1, spr_barbarian_up_0 - 1, spr_fighter_up_0 - 1  ; hero_sprites: Ranger, Magic-User, Barbarian, Fighter
    equb &00, &0d, &d9                  ; Copied to &0DB9: no variable starts here
    equb &00, &00, &00, &00             ; hero_has_boots: none
    equb &80, &40, &20, &10, &08, &04, &02, &01  ; bit_masks: &80 down to &01
    equb &b9, &30, &0d, &9d, &08, &0d, &4c, &d4  ; Copied to &0DC8: no variable starts here
; &7dd0 used as index base 3 times by &36b1, &51d4, &55d4
    equb &18, &46, &74, &a2             ; hero_panel_y: the four sections of the status panel
    equb &e8, &e0, &04, &d0, &0a, &a2, &00, &ad
    equb &40, &0d, &49, &01, &8d, &40, &0d, &8e
    equb &ff, &0d, &68, &a8, &68, &aa, &68, &28
    equb &60, &de, &dd, &df, &f0, &f2, &f1, &f3
    equb &f8, &fa, &f9, &fb, &f4, &f6, &f5, &f7
    equb &fc                            ; Copied to &0DD4: no variable starts here
    equb &1e                            ; teleport_last: object &1E, the last
    equb &fd                            ; Copied to &0DFE: no variable starts here
    equb &00                            ; victory_sprite_copy: set before use
; Map x of each monster (entries 1-30; entry 0 unused). During a step it stays the cell the monster is leaving until the step ends, so find_creature, the missiles and the magic all meet the monster there. &FF (off_map) after reset_monsters, and for a monster monster_reappears has parked. Written by update_monsters, continue_monster_step and monster_reappears.
; &7e00 used as index base 17 times by &3ccc, &7667, &797e, &79e7, &7a31, &7a3f, &7a45, &7a5b, &7a98, &7ace, &7afb, &7b04, &7b41, &7c46, &7c54, &7cc8, &7cf2
.monster_x
    equb &00, &04, &0b, &09, &1d, &08, &01, &06, &07, &0a, &01, &0b, &1a, &06, &0b, &16  ; Not read: reset_monsters and the trapdoors set the monsters
    equb &15, &0d, &1b, &14, &1a, &09, &1c, &0f, &1e, &02, &1a, &0b, &1c, &0e, &16, &00  ; ...entries 16-31, not read
    equb &00, &00, &00, &1a, &00, &00, &00, &00, &00  ; ...entries 32-40, not read
; Map y of each monster, kept like monster_x.
; &7e29 used as index base 16 times by &766d, &7986, &79f0, &7a2a, &7a38, &7a4b, &7a61, &7a9e, &7adc, &7b01, &7b0a, &7b47, &7c3f, &7c4d, &7cce, &7cf5
.monster_y
    equb &00, &24, &17, &25, &20, &24, &22, &14, &27, &0d, &20, &01, &26, &0a, &01, &12  ; Not read: reset_monsters and the trapdoors set the monsters
    equb &05, &20, &29, &0d, &26, &27, &08, &06, &1a, &14, &03, &1d, &07, &0d, &17, &00  ; ...entries 16-31, not read
    equb &00, &00, &00, &1b, &00, &00, &00, &00, &00  ; ...entries 32-40, not read
; Each monster's state as a sprite number: 9, &0B, &0D or &0F facing up, right, down or left; &15 (the blank) when just killed, then &16-&19, the sparkles of its death, one a frame. It reaches &1A only for the moment before monster_reappears resets it to 9.
; &7e52 used as index base 19 times by &3cc7, &7144, &7598, &7683, &768c, &7a0d, &7a23, &7a77, &7a81, &7ab4, &7abb, &7ac3, &7b11, &7b32, &7b35, &7b4d, &7bf0, &7c38, &7cd3
.monster_sprite
    equb &00, &09, &0d, &0b, &0b, &0b, &09, &0f
    equb &0f, &0b, &0d, &0b, &0b, &0f, &0d, &0d
    equb &09, &0f, &0b, &0f, &0b, &0b, &0f, &09
    equb &0d, &0f, &0b, &09, &0d, &0b, &09, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; Each monster's animation frame (0 or 1), added to its facing sprite; toggled on each frame of a step.
; &7e7b used as index base 3 times by &7b14, &7c2b, &7c30
.monster_frame
    equb &00, &00, &01, &00, &00, &01, &01, &00
    equb &01, &01, &00, &01, &01, &01, &00, &01
    equb &00, &01, &00, &01, &01, &00, &00, &01
    equb &01, &00, &00, &00, &01, &01, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; How far each monster is drawn across from its cell during a step, in byte columns: 0, or +/-1 to 3.
; &7ea4 used as index base 15 times by &79fd, &7a69, &7aa6, &7aef, &7b19, &7b52, &7bf9, &7c0d, &7c17, &7c27, &7c59, &7c5f, &7c66, &7c6c, &7cdb
.monster_offset_x
    equb &00, &00, &00, &02, &02, &02, &00, &fd
    equb &fe, &01, &00, &02, &03, &00, &00, &00
    equb &00, &fe, &00, &00, &01, &00, &00, &00
    equb &00, &00, &03, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; How far each monster is drawn down from its cell during a step, in pixel rows: 0, or +/-3, 6 or 9.
; &7ecd used as index base 17 times by &7a02, &7a6c, &7aa9, &7af2, &7b1e, &7b57, &7bfe, &7c08, &7c1c, &7c22, &7c5c, &7c6f, &7c77, &7c7c, &7c83, &7c88, &7cde
.monster_offset_y
    equb &00, &fd, &00, &00, &00, &00, &fa, &00
    equb &00, &00, &03, &00, &00, &00, &06, &03
    equb &fd, &00, &00, &00, &00, &00, &00, &00
    equb &06, &00, &00, &f7, &00, &00, &f7, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00
; Frames left in each monster's step between cells: 3 when the step starts, counted down by continue_monster_step, 0 when the monster is not stepping. Not looked at while a monster is dying; monster_reappears clears it.
; &7ef6 used as index base 7 times by &7a17, &7a66, &7aa3, &7aec, &7bed, &7c33, &7cd8
.monster_step
    equb &00, &03, &00, &02, &02, &02, &02, &01
    equb &02, &03, &03, &02, &01, &00, &02, &03
    equb &03, &02, &00, &00, &03, &00, &00, &00
    equb &02, &00, &01, &01, &00, &00, &01, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00
; Map x of each object on the level (entries 1-30), from the level file; &FF once collected. Entry 30 is the exit.
; &7f20 used as index base 9 times by &3c55, &7173, &719a, &730d, &7337, &73ea, &7413, &7469, &74bb
.object_x
    equb &00, &ff, &ff, &ff, &ff, &ff, &18, &04, &04, &05, &ff, &ff, &ff, &ff, &ff, &ff  ; Not read: unpack_level copies each level's objects here
    equb &ff, &ff, &ff, &ff, &ff, &01, &07, &04, &04, &ff, &ff, &ff, &ff, &ff  ; ...entries 16-29, not read
; Map x of the exit (object 30).
; &7f3e referenced 4 times by &2029, &467b, &46b7, &46c5
.exit_x
    equb &04                            ; ...the exit's entry
; Map y of each object.
; &7f3f used as index base 9 times by &3c5b, &717b, &719d, &7313, &7342, &73f3, &7416, &746c, &74be
.object_y
    equb &00, &ff, &ff, &ff, &ff, &ff, &15, &18, &19, &19, &ff, &ff, &ff, &ff, &ff, &ff  ; Not read: unpack_level copies each level's objects here
    equb &ff, &ff, &ff, &ff, &ff, &2a, &2a, &2b, &2e, &ff, &ff, &ff, &ff, &ff  ; ...entries 16-29, not read
; Map y of the exit (object 30).
; &7f5d referenced 4 times by &202f, &4683, &46bd, &46c8
.exit_y
    equb &2c                            ; ...the exit's entry
; Each object's type, which is also its sprite: &28 treasure, &29 food, &2A Cross of Resurrection, &2B teleporter, &51 exit, &53-&5E energy drainer (advancing with each hit), &5F Boots of Speed, &60 magic helmet, &61 potion of healing, &62 pile of weapons, &63 magic sword.
; &7f5e used as index base 7 times by &3c61, &7183, &718e, &7191, &7319, &735c, &73c8
.object_type
    equb &00, &5f, &5f, &5f, &29, &63, &5f, &53, &2b, &53, &28, &28, &60, &60, &28, &2a  ; Not read: unpack_level copies each level's objects here
    equb &62, &28, &28, &29, &28, &2b, &2b, &2b, &2b, &29, &28, &28, &29, &28  ; ...entries 16-29, not read
    equb &51                            ; ...the exit's entry
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00, &00, &00, &00, &00, &00, &00
    equb &00, &00                       ; Not referenced
; ***************************************************************************************
; WRCHV handler: print letters and digits in the game font
;
; Installed on WRCHV while the game runs. A letter (either case) or a digit is printed in
; the game's own font: its eight-byte glyph is copied over the definition of character
; 128 (user_char_128) and character 128 is printed instead. Every other character is
; printed unchanged. Both paths finish in the MOS 1.20 OSWRCH routine at
; mos_oswrch_default, jumped to directly rather than through the WRCHV value saved at
; start-up. Lower-case letters share the capitals' glyphs. The handler keeps the
; character in plot_x, the sprite plotter's zero-page column, and it looks at every byte
; alone, with no notion of a VDU sequence: a VDU parameter byte that falls in '0'-'9',
; 'A'-'Z' or 'a'-'z' is sent as &80 too.
;
; On Entry:
;     A: character to print
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: preserved
;     PLOT_X: corrupted
.wrch_handler
    sta plot_x                          ; Keep the character in plot_x, borrowed as scratch
    txa                                 ; Save the caller's X...
    pha                                 ; ...on the stack
    tya                                 ; ...and the caller's Y
    pha                                 ; ...on the stack: OSWRCH must preserve both
    lda plot_x                          ; Classify the character by range
    cmp #'0'                            ; Below '0': a control code, space or punctuation?
    bcc pass_character                  ; Controls, space, punctuation: the MOS font
    cmp #':'                            ; Below ':', so a digit '0'-'9'?
    bcc digit_glyph                     ; A digit: use the game's digit glyph
    cmp #'A'                            ; Below 'A', so ':' to '@'?
    bcc pass_character                  ; Punctuation: the MOS font
    cmp #'['                            ; Below '[', so a capital 'A'-'Z'?
    bcc capital_letter                  ; A capital: use the game's letter glyph
    cmp #'a'                            ; Below 'a', so '[' to '`'?
    bcc pass_character                  ; Punctuation: the MOS font
    cmp #'{'                            ; '{' or above, past the lower-case letters?
    bcs pass_character                  ; '{' and above: the MOS font
    sec                                 ; Lower case: letter number 0-25...
    sbc #'a'                            ; ...so it is drawn with the capital's glyph
    jmp glyph_offset                    ; Join the capitals' path
; &7fb5 referenced 1 time by &7fa5
.capital_letter
    sec                                 ; Capital: letter number 0-25...
    sbc #'A'                            ; ...0 for 'A'
; &7fb8 referenced 1 time by &7fb2
.glyph_offset
    asl a                               ; Glyph offset = letter x 8 in font_letters: x 2...
    asl a                               ; ...x 4 (8 bytes a glyph)...
    asl a                               ; ...x 8: the glyph's offset (at most 200)
    bne copy_glyph                      ; Branch to the next instruction either way
; &7fbd referenced 1 time by &7fbb
.copy_glyph
    tax                                 ; X indexes the glyph in font_letters
    clc                                 ; End offset = start + 8...
    adc #8                              ; ...one glyph's eight rows...
    sta plot_x                          ; ...in plot_x, the character no longer needed
    ldy #0                              ; Y indexes character 128's definition at &0C00
; &7fc5 referenced 1 time by &7fcf
.copy_letter_glyph
    lda font_letters,x                  ; Copy a row of the letter's glyph...
    sta room_walls,y                    ; ...over character 128's definition
    iny                                 ; Next row of character 128
    inx                                 ; Next row of the glyph
    cpx plot_x                          ; All eight rows copied?
    bne copy_letter_glyph               ; No: copy the next row
; &7fd1 referenced 1 time by &7ff4
.restore_registers
    pla                                 ; Restore the caller's Y...
    tay                                 ; ...from the stack
    pla                                 ; ...and the caller's X
    tax                                 ; ...from the stack
    lda #&80                            ; Character 128, which now looks like the glyph...
    jmp mos_oswrch_default              ; ...printed by the MOS 1.20 OSWRCH routine itself
; &7fda referenced 1 time by &7f9d
.digit_glyph
    sec                                 ; Digit: digit number 0-9...
    sbc #'0'                            ; ...0 for '0'
    asl a                               ; Glyph offset = digit x 8 in font_digits: x 2...
    asl a                               ; ...x 4 (8 bytes a glyph)...
    asl a                               ; ...x 8: the glyph's offset
    tax                                 ; X indexes the glyph in font_digits
    clc                                 ; End offset = start + 8...
    adc #8                              ; ...one glyph's eight rows...
    sta plot_x                          ; ...in plot_x, the character no longer needed
    ldy #0                              ; Y indexes character 128's definition at &0C00
; &7fe8 referenced 1 time by &7ff2
.copy_digit_glyph
    lda font_digits,x                   ; Copy a row of the digit's glyph...
    sta room_walls,y                    ; ...over character 128's definition
    iny                                 ; Next row of character 128
    inx                                 ; Next row of the glyph
    cpx plot_x                          ; All eight rows copied?
    bne copy_digit_glyph                ; No: copy the next row
    beq restore_registers               ; Done (always taken): print character 128
; &7ff6 referenced 4 times by &7f99, &7fa1, &7fa9, &7fad
.pass_character
    pla                                 ; Not a letter or digit: restore the caller's Y...
    tay                                 ; ...from the stack
    pla                                 ; ...and the caller's X
    tax                                 ; ...from the stack
    lda plot_x                          ; The character, unchanged, from plot_x...
    jmp mos_oswrch_default              ; ...printed by the MOS 1.20 OSWRCH routine itself
    equb &00                            ; Not referenced
.dasmos_end

save "Dun1", dasmos_start, dasmos_end, &2000, &2000
save "Coder", &5000, &59b0, &5000, &5000

; Label references by decreasing frequency:
;     oswrch:                               63
;     cell_x:                               59
;     plot_x:                               57
;     cell_y:                               55
;     scratch:                              50
;     sprite_number:                        46
;     plot_y:                               32
;     hero_x:                               30
;     hero_y:                               27
;     osbyte:                               27
;     plot_sprite:                          22
;     map_ptr:                              21
;     hero_offset_y:                        20
;     hero_direction:                       19
;     hero_offset_x:                        19
;     monster_sprite:                       19
;     plot_at_cell:                         19
;     plot_offset_x:                        18
;     plot_offset_y:                        18
;     monster_offset_y:                     17
;     monster_x:                            17
;     monster_y:                            16
;     hero_frame:                           15
;     monster_offset_x:                     15
;     osword:                               15
;     menu_text:                            14
;     menu_text_joystick:                   14
;     hero_step:                            13
;     screen_ptr:                           13
;     menu_key_loop:                        12
;     menu_key_loop_joystick:               12
;     missile_direction:                    12
;     plot_victory_sprite:                  12
;     hero_health_tens:                     11
;     previous_x:                           11
;     previous_y:                           11
;     hero_key:                             10
;     hero_panel_y:                         10
;     returning_hero_queue:                 10
;     sprite_width:                         10
;     hero_max_missiles:                     9
;     object_x:                              9
;     object_y:                              9
;     screen_ptr_hi:                         9
;     hero_absent:                           8
;     hero_score_thousands:                  8
;     hero_score_units:                      8
;     lose_health_point:                     8
;     menu_text + 1:                         8
;     menu_text_joystick + 1:                8
;     panel_hero:                            8
;     ring_x:                                8
;     scratch2:                              8
;     test_wall:                             8
;     cell_room:                             7
;     hero_damage_taken:                     7
;     hero_health_units:                     7
;     hero_missile_damage:                   7
;     key_x:                                 7
;     key_y:                                 7
;     monster_step:                          7
;     object_type:                           7
;     os_vsync_counter:                      7
;     oscli:                                 7
;     play_level:                            7
;     ring_y:                                7
;     victory_pitch:                         7
;     draw_monster:                          6
;     levels_started:                        6
;     missile_x:                             6
;     missile_y:                             6
;     page6_score_ten_thousands:             6
;     page6_score_ten_thousands_joystick:    6
;     print_menu:                            6
;     print_menu_joystick:                   6
;     test_key:                              6
;     victory_sprite:                        6
;     add_point:                             5
;     check_missile_hero:                    5
;     count:                                 5
;     erase_hero:                            5
;     exit_busy:                             5
;     exit_spin:                             5
;     hero_score_hundreds:                   5
;     hero_score_ten_thousands:              5
;     hero_score_tens:                       5
;     joystick_not_pressed:                  5
;     level_digits:                          5
;     level_digits + 1:                      5
;     level_number:                          5
;     next_trapdoor:                         5
;     plot_panel_sprite:                     5
;     victory_delay:                         5
;     view_room:                             5
;     add_ten_points:                        4
;     decrypt_level_loop:                    4
;     decrypt_level_loop_joystick:           4
;     door_x:                                4
;     door_y:                                4
;     draw_moved_hero:                       4
;     draw_room:                             4
;     draw_ten_thousands:                    4
;     draw_ten_thousands_joystick:           4
;     exit_saved_x:                          4
;     exit_saved_y:                          4
;     exit_x:                                4
;     exit_y:                                4
;     find_creature:                         4
;     hero_door_x:                           4
;     hero_door_y:                           4
;     hero_key_dropped:                      4
;     hero_sprites:                          4
;     map_ptr_hi:                            4
;     menu_text + 2:                         4
;     menu_text_joystick + 2:                4
;     missile_sprite_base:                   4
;     monster_at_edge:                       4
;     monster_hit_points:                    4
;     next_hero:                             4
;     next_hero_keys:                        4
;     next_other_hero:                       4
;     pass_character:                        4
;     plot_keeping_x:                        4
;     shrunk_hero:                           4
;     sprite_heights:                        4
;     start_hero_step:                       4
;     step_hero:                             4
;     wrchv:                                 4
;     wrchv + 1:                             4
;     bit_masks:                             3
;     check_exit:                            3
;     credit_owner:                          3
;     draw_health:                           3
;     draw_score:                            3
;     exit_shrinks_left:                     3
;     exiting_hero:                          3
;     hero_has_boots:                        3
;     hero_magic_delay:                      3
;     magic_kill_count:                      3
;     missile_damage:                        3
;     monster_done:                          3
;     monster_frame:                         3
;     monster_start_hit_points:              3
;     mos_reset_entry:                       3
;     next_door:                             3
;     next_monster_find:                     3
;     next_object:                           3
;     next_victory_sprite:                   3
;     os_break_intercept:                    3
;     osasci:                                3
;     osrdch:                                3
;     room_walls:                            3
;     set_up_6845_for_loading:               3
;     sprite_data_ptr:                       3
;     sprite_widths:                         3
;     system_via_t1c_l:                      3
;     victory_pitch_step:                    3
;     workspace_template + 208:              3
;     add_thousand_points_done:              2
;     add_thousand_points_done_joystick:     2
;     bytev:                                 2
;     bytev + 1:                             2
;     check_door_y:                          2
;     check_key_swap:                        2
;     check_missile_object:                  2
;     check_room_edge:                       2
;     clear_text_area:                       2
;     copy_core_byte:                        2
;     credit_missile_owner:                  2
;     decrypt_level_done:                    2
;     decrypt_level_done_joystick:           2
;     decrypt_level_next:                    2
;     decrypt_level_next_joystick:           2
;     door_sprite:                           2
;     draw_hero:                             2
;     draw_missile_damage:                   2
;     draw_ten_thousands_loop:               2
;     draw_ten_thousands_loop_joystick:      2
;     draw_victory_ring:                     2
;     draw_view_0:                           2
;     draw_view_1:                           2
;     draw_view_2:                           2
;     draw_view_3:                           2
;     exit_offsets_x:                        2
;     exit_offsets_y:                        2
;     filev:                                 2
;     filev + 1:                             2
;     find_previous_teleporter:              2
;     food_sound + 4:                        2
;     get_hero_cell:                         2
;     grow_offset_y:                         2
;     hero_frame + 1:                        2
;     hero_frame + 2:                        2
;     hero_frame + 3:                        2
;     hit_sound + 4:                         2
;     key_not_pressed:                       2
;     level_checksums:                       2
;     level_count_copy:                      2
;     menu_done:                             2
;     menu_done_joystick:                    2
;     menu_hero_off:                         2
;     menu_hero_off_joystick:                2
;     menu_reprint:                          2
;     menu_reprint_joystick:                 2
;     menu_set_sound:                        2
;     menu_set_sound_joystick:               2
;     menu_sound_key:                        2
;     menu_sound_key_joystick:               2
;     menu_sound_off:                        2
;     menu_sound_off_joystick:               2
;     menu_space:                            2
;     menu_space_check_hero:                 2
;     menu_space_check_hero_joystick:        2
;     menu_space_joystick:                   2
;     missile_spent_pop:                     2
;     monster_move_on:                       2
;     monster_step_done:                     2
;     monster_x + 35:                        2
;     monster_y + 35:                        2
;     mos_osbyte_default:                    2
;     mos_oswrch_default:                    2
;     next_hero_exit:                        2
;     next_hero_find:                        2
;     next_hero_hit:                         2
;     next_key:                              2
;     next_missile:                          2
;     next_monster_magic:                    2
;     next_object_drainer:                   2
;     no_drainer:                            2
;     os_break_intercept + 1:                2
;     os_break_intercept + 2:                2
;     play_pickup_sound:                     2
;     plot_chalice:                          2
;     point_at_boots_icon:                   2
;     previous_offset_x:                     2
;     previous_offset_y:                     2
;     print_menu_loop:                       2
;     print_menu_loop_joystick:              2
;     print_menu_string:                     2
;     print_menu_string_joystick:            2
;     print_menu_string_loop:                2
;     print_menu_string_loop_joystick:       2
;     read_hero_keys:                        2
;     remove_absent_heroes_check:            2
;     remove_absent_heroes_check_joystick:   2
;     remove_absent_heroes_loop:             2
;     remove_absent_heroes_loop_joystick:    2
;     remove_absent_heroes_next:             2
;     remove_absent_heroes_next_joystick:    2
;     remove_object:                         2
;     reset_hero:                            2
;     restore_hero_sprites:                  2
;     returning_hero_queue + 1:              2
;     returning_hero_queue + 2:              2
;     returning_hero_queue + 3:              2
;     row_start_ptr:                         2
;     row_start_ptr_hi:                      2
;     saved_wrchv:                           2
;     saved_wrchv + 1:                       2
;     set_menu_no:                           2
;     set_menu_no_joystick:                  2
;     set_menu_off:                          2
;     set_menu_off_joystick:                 2
;     set_menu_on:                           2
;     set_menu_on_joystick:                  2
;     set_menu_yes:                          2
;     set_menu_yes_joystick:                 2
;     shorten_victory_delay:                 2
;     show_hero_room:                        2
;     sprite_data_ptr_hi:                    2
;     sprite_height:                         2
;     start_hero_animation:                  2
;     start_victory:                         2
;     store_victory_sprite:                  2
;     take_magic_cost:                       2
;     test_object_free:                      2
;     trapdoor_x:                            2
;     trapdoor_y:                            2
;     victory_steps_left:                    2
;     view_room + 2:                         2
;     view_room + 4:                         2
;     view_room + 6:                         2
;     absent_frame_due:                      1
;     add_food_points:                       1
;     add_thousand_points:                   1
;     add_thousand_points_joystick:          1
;     advance_dying_monster:                 1
;     advance_single_digit:                  1
;     animate_absent:                        1
;     animate_absent_hero:                   1
;     boot_load_call + 1:                    1
;     boot_load_call + 2:                    1
;     boot_load_call_joystick + 1:           1
;     boot_load_call_joystick + 2:           1
;     cancel_hero_step:                      1
;     capital_letter:                        1
;     check_boots:                           1
;     check_cross:                           1
;     check_death_finished:                  1
;     check_door:                            1
;     check_door_cell_y:                     1
;     check_door_key:                        1
;     check_door_x:                          1
;     check_doors:                           1
;     check_exit_busy:                       1
;     check_food:                            1
;     check_for_victory:                     1
;     check_helmet:                          1
;     check_hero:                            1
;     check_hero_dead:                       1
;     check_hero_hit:                        1
;     check_hero_in_cell:                    1
;     check_hero_keys:                       1
;     check_hero_on_exit:                    1
;     check_hero_returned:                   1
;     check_just_fired:                      1
;     check_key:                             1
;     check_key_cell:                        1
;     check_key_down:                        1
;     check_key_fire:                        1
;     check_key_left:                        1
;     check_key_right:                       1
;     check_level:                           1
;     check_magic:                           1
;     check_magic_item:                      1
;     check_magic_key:                       1
;     check_magic_monster:                   1
;     check_missile_monster:                 1
;     check_missile_wall:                    1
;     check_monster:                         1
;     check_monster_blocked:                 1
;     check_monster_in_cell:                 1
;     check_monster_step:                    1
;     check_object:                          1
;     check_object_drainer:                  1
;     check_object_y:                        1
;     check_other_hero:                      1
;     check_potion:                          1
;     check_queue_empty:                     1
;     check_teleporter:                      1
;     check_view_1:                          1
;     check_view_1_room:                     1
;     check_view_2:                          1
;     check_view_2_room:                     1
;     check_view_3_room:                     1
;     check_weapons:                         1
;     clear_chalice_sprite:                  1
;     clear_hero_carrying:                   1
;     clear_text_for_level:                  1
;     collect_objects:                       1
;     collect_objects_done:                  1
;     continue_down:                         1
;     continue_hero_step:                    1
;     continue_left:                         1
;     continue_monster_step:                 1
;     continue_right:                        1
;     copy_core_check_end:                   1
;     copy_core_next_dest:                   1
;     copy_digit_glyph:                      1
;     copy_game_core:                        1
;     copy_glyph:                            1
;     copy_letter_glyph:                     1
;     copy_low_byte:                         1
;     copy_low_check_end:                    1
;     copy_low_image:                        1
;     copy_low_next_source:                  1
;     copy_workspace_template:               1
;     count_heroes_in_play:                  1
;     credit_drainer_hit:                    1
;     cross_done:                            1
;     decrypt_level:                         1
;     decrypt_level_joystick:                1
;     digit_glyph:                           1
;     dissolve_chalice:                      1
;     dissolve_done:                         1
;     door_points_loop:                      1
;     doors_done:                            1
;     double_offsets:                        1
;     draw_all_views:                        1
;     draw_armour_rating:                    1
;     draw_each_key:                         1
;     draw_each_object:                      1
;     draw_keys:                             1
;     draw_missile_icon:                     1
;     draw_missile_icons:                    1
;     draw_monster_death:                    1
;     draw_new_missile_icon:                 1
;     draw_objects:                          1
;     draw_panel_hero:                       1
;     draw_room_cell:                        1
;     draw_room_doors:                       1
;     draw_room_row:                         1
;     draw_room_walls:                       1
;     draw_status_panel:                     1
;     draw_trapdoor:                         1
;     draw_view_frame:                       1
;     draw_view_frames:                      1
;     drop_key:                              1
;     emerge_at_trapdoor:                    1
;     emerge_done:                           1
;     erase_boots_icon:                      1
;     erase_missile:                         1
;     erase_victory_ring:                    1
;     exit_offset_x_1:                       1
;     exit_offset_x_2:                       1
;     exit_offset_x_3:                       1
;     exit_offset_y_1:                       1
;     exit_offset_y_2:                       1
;     exit_offset_y_3:                       1
;     exit_offset_y_4:                       1
;     find_missile_slot:                     1
;     find_open_neighbour:                   1
;     find_queue_end:                        1
;     find_queue_slot:                       1
;     fire_missile:                          1
;     firer_axe:                             1
;     firer_fireball:                        1
;     firer_sword:                           1
;     flip_firer_frame:                      1
;     font_digits:                           1
;     font_letters:                          1
;     game_entry:                            1
;     game_over_message:                     1
;     glyph_offset:                          1
;     grow_offset_x:                         1
;     grow_offset_x_right:                   1
;     grow_offset_y_down:                    1
;     hero_appearance_sprites:               1
;     hero_direction - 1:                    1
;     hero_enters_exit:                      1
;     hero_faces:                            1
;     hero_frame - 1:                        1
;     hero_health_tens - 1:                  1
;     hero_key_down:                         1
;     hero_key_fire:                         1
;     hero_key_left:                         1
;     hero_key_right:                        1
;     hero_key_up:                           1
;     hero_magic_key:                        1
;     hero_menu:                             1
;     hero_menu_joystick:                    1
;     hero_missile_sprites:                  1
;     hero_no_offsets:                       1
;     hero_start_damage_taken:               1
;     hero_start_max_missiles:               1
;     hero_start_missile_damage:             1
;     hero_step_down:                        1
;     hero_step_left:                        1
;     hero_step_right:                       1
;     joystick_down:                         1
;     joystick_fire:                         1
;     joystick_left:                         1
;     joystick_pass_on:                      1
;     joystick_right:                        1
;     joystick_up:                           1
;     keep_heroes:                           1
;     keys_done:                             1
;     level_bcd:                             1
;     level_command_digits:                  1
;     level_command_digits + 1:              1
;     level_door_sprite:                     1
;     level_door_x:                          1
;     level_door_y:                          1
;     level_key_x:                           1
;     level_key_y:                           1
;     level_loaded:                          1
;     level_loop:                            1
;     level_object_free_map:                 1
;     level_object_type:                     1
;     level_object_x:                        1
;     level_object_y:                        1
;     level_trapdoor_x:                      1
;     level_trapdoor_y:                      1
;     level_wall_sprite:                     1
;     level_walls:                           1
;     load_level_file:                       1
;     magic_cast:                            1
;     magic_item:                            1
;     magic_sword:                           1
;     magic_user_cost:                       1
;     missile_down:                          1
;     missile_left:                          1
;     missile_right:                         1
;     missile_spent:                         1
;     monster_continue_down:                 1
;     monster_continue_left:                 1
;     monster_continue_right:                1
;     monster_down:                          1
;     monster_hit:                           1
;     monster_killed:                        1
;     monster_left:                          1
;     monster_no_offsets:                    1
;     monster_reappears:                     1
;     monster_right:                         1
;     monster_step_down:                     1
;     monster_step_left:                     1
;     monster_step_right:                    1
;     monster_vertical:                      1
;     mos_row_offsets:                       1
;     mos_row_offsets_lo:                    1
;     move_hero:                             1
;     move_heroes:                           1
;     move_heroes_done:                      1
;     move_missile:                          1
;     move_missiles:                         1
;     move_missiles_done:                    1
;     new_game_reset_heroes:                 1
;     next_hero_dead:                        1
;     next_hero_doors:                       1
;     next_hero_in_play:                     1
;     next_hero_victory:                     1
;     next_level_by_reset:                   1
;     next_level_intercept_done:             1
;     next_missile_slot:                     1
;     next_monster_update:                   1
;     next_queue_entry:                      1
;     next_queue_slot:                       1
;     next_room_cell:                        1
;     next_turn:                             1
;     no_magic:                              1
;     no_victory:                            1
;     not_paused:                            1
;     note_new_cell:                         1
;     nothing_found:                         1
;     object_found:                          1
;     object_free_map:                       1
;     object_free_map + 58:                  1
;     open_door:                             1
;     os_irq_a:                              1
;     os_zp_fa:                              1
;     owner_axe:                             1
;     owner_fireball:                        1
;     owner_sword:                           1
;     panel_hero - 1:                        1
;     play_level_done:                       1
;     play_this_level:                       1
;     plot_at_cell_done:                     1
;     plot_blank:                            1
;     plot_boots_icon:                       1
;     plot_sprite_byte:                      1
;     plot_sprite_count_byte:                1
;     plot_sprite_next_data:                 1
;     plot_sprite_next_row:                  1
;     plot_sprite_row:                       1
;     print_ending_message:                  1
;     print_game_over:                       1
;     print_victory_text:                    1
;     queue_exit_marker:                     1
;     raise_victory_pitch:                   1
;     read_magic_key:                        1
;     redraw_armour:                         1
;     redraw_exit:                           1
;     redraw_health:                         1
;     remember_hero_position:                1
;     remove_absent_heroes:                  1
;     remove_absent_heroes_joystick:         1
;     reset_call_address:                    1
;     reset_call_address + 1:                1
;     reset_each_hero:                       1
;     reset_each_monster:                    1
;     reset_machine:                         1
;     reset_monsters:                        1
;     reset_vector:                          1
;     reset_vector + 1:                      1
;     reset_workspace:                       1
;     restart_by_reset:                      1
;     restart_intercept_done:                1
;     restore_exit:                          1
;     restore_message_spaces:                1
;     restore_registers:                     1
;     restore_sprite_heights:                1
;     restore_sprite_widths:                 1
;     reverse_down:                          1
;     reverse_left:                          1
;     reverse_right:                         1
;     room_walls + 58:                       1
;     score_magic_kills:                     1
;     screen_address:                        1
;     screen_address_done:                   1
;     send_frame_vdu:                        1
;     send_loading_vdu:                      1
;     send_play_vdu:                         1
;     set_monster_step:                      1
;     set_up_screen_for_play:                1
;     shift_returning_queue:                 1
;     show_view_3:                           1
;     shrink_hero_height:                    1
;     shrink_hero_width:                     1
;     sound_victory_bell:                    1
;     sprite_addr_hi:                        1
;     sprite_addr_lo:                        1
;     sprite_chalice:                        1
;     sprite_chalice - 1:                    1
;     start_level:                           1
;     start_monster_move:                    1
;     start_monster_step:                    1
;     start_new_game:                        1
;     stay_in_old_cell:                      1
;     step_down:                             1
;     step_left:                             1
;     step_missile:                          1
;     step_right:                            1
;     store_hero_frame:                      1
;     store_monster_health:                  1
;     take_health_unit:                      1
;     take_hero_damage:                      1
;     take_missile_damage:                   1
;     take_returning_hero:                   1
;     take_ten_health:                       1
;     teleport:                              1
;     teleport_last:                         1
;     text_window_bottom:                    1
;     to_next_level:                         1
;     trapdoor_x - 1:                        1
;     trapdoor_y - 1:                        1
;     try_cell_below:                        1
;     try_cell_left:                         1
;     try_cell_right:                        1
;     turn_monster:                          1
;     unpack_doors:                          1
;     unpack_keys:                           1
;     unpack_level:                          1
;     unpack_objects:                        1
;     unpack_trapdoors:                      1
;     unpack_wall_sprite:                    1
;     unpack_walls:                          1
;     update_game:                           1
;     update_monsters:                       1
;     update_monsters_done:                  1
;     update_rest:                           1
;     use_keyboard_image:                    1
;     victory_delay_inner:                   1
;     victory_delay_loop:                    1
;     victory_delay_outer:                   1
;     victory_sequence:                      1
;     victory_sprite_copy:                   1
;     wait_pause_press:                      1
;     wait_pause_release:                    1
;     wait_vsync_chalice:                    1
;     wait_vsync_game_over:                  1
;     wall_sprite:                           1
;     workspace_template:                    1

; Stats:
;     Total size (Code + Data) = 24576 bytes
;     Code                     = 7788 bytes (32%)
;     Data                     = 16788 bytes (68%)
;
;     Number of instructions   = 3574
;     Number of data bytes     = 15908 bytes
;     Number of data words     = 64 bytes
;     Number of string bytes   = 816 bytes
;     Number of strings        = 83
