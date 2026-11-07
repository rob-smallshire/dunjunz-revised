; Dunjunz Revised: the game
;
; The top level of the game's source. It assembles Dun1, which contains the level loader
; Coder, from the modules under asm/. The layout below is still the 1987 disc release's,
; and the build checks that the output is identical to it; the description that follows
; is of that release.
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

INCLUDE "asm/defs/constants.asm"
INCLUDE "asm/defs/addresses.asm"

    org &3000

; Stored at &3000 in the file, assembled to run at &08c0 (5952 bytes)
    org &08c0
INCLUDE "asm/core/plot.asm"
INCLUDE "asm/core/game_start.asm"
INCLUDE "asm/core/status_panel.asm"
INCLUDE "asm/core/victory.asm"
INCLUDE "asm/core/font.asm"
INCLUDE "asm/core/level_start.asm"
INCLUDE "asm/core/sprites.asm"
INCLUDE "asm/core/frame.asm"
    copyblock &08c0, *, &3000           ; Store what was assembled at its run address in the file at &3000
    clear &08c0, &2000                  ; Free the run addresses for the next block assembled there
    org &3000 + (* - &08c0)             ; Carry on in the file after the stored copy

    org &51b0

; Stored at &51b0 in the file, assembled to run at &0400 (1024 bytes)
    org &0400
INCLUDE "asm/low/keyboard.asm"
    copyblock add_thousand_points, *, &51b0; Store what was assembled at its run address in the file at &51b0
    clear add_thousand_points, &0800    ; Free the run addresses for the next block assembled there
    org &51b0 + (* - add_thousand_points); Carry on in the file after the stored copy

    org &55b0

; Stored at &55b0 in the file, assembled to run at &0400 (1024 bytes)
    org &0400
INCLUDE "asm/low/joystick.asm"
    copyblock add_thousand_points_joystick, *, &55b0; Store what was assembled at its run address in the file at &55b0
    clear add_thousand_points_joystick, &0800; Free the run addresses for the next block assembled there
    org &55b0 + (* - add_thousand_points_joystick); Carry on in the file after the stored copy

    org &2000

.dasmos_start
INCLUDE "asm/extra/exit.asm"
INCLUDE "asm/extra/doors_keys_sprites.asm"
    org &4740
INCLUDE "asm/coder/coder.asm"
    org &59b0
INCLUDE "asm/coder/padding.asm"
INCLUDE "asm/upper/move_heroes.asm"
INCLUDE "asm/upper/scoring.asm"
INCLUDE "asm/upper/objects.asm"
INCLUDE "asm/upper/hero_room.asm"
INCLUDE "asm/upper/magic.asm"
INCLUDE "asm/upper/hero_animation.asm"
INCLUDE "asm/upper/views.asm"
INCLUDE "asm/upper/map_tests.asm"
INCLUDE "asm/upper/monsters.asm"
INCLUDE "asm/upper/steps.asm"
INCLUDE "asm/upper/keys.asm"
INCLUDE "asm/upper/workspace.asm"
INCLUDE "asm/upper/wrch.asm"
.dasmos_end

; Layout constraints the code relies on
ASSERT LO(room_walls) = 0               ; test_wall, draw_room and update_game point at a room with >room_walls and the room's offset
ASSERT LO(object_free_map) = 0          ; test_object_free likewise
ASSERT exit_shrink_continues = &2000    ; the exit animation runs on from the end of the game core into extra/exit.asm

save "Dun1", dasmos_start, dasmos_end, &2000, &2000
save "Coder", &5000, &59b0, &5000, &5000
