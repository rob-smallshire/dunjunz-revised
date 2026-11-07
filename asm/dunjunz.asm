; Dunjunz Revised: the game
;
; The top level of the game's source: it assembles GAME from the modules under asm/.
; See docs/memory.md for the memory map and how the game shares memory with the filing
; system. The description that follows is of the 1987 disc release this is derived from.
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

; ***************************************************************************************
; Memory regions
;
; The game in play: five regions outside the screen. The filing system's absolute
; workspace (STATIC_WORKSPACE) is the game's while it plays, claimed with service call &0A;
; page &0D (the filing system's NMI code) and &1700 up to PAGE (private workspace, PAGE at
; most &1C00) are never touched.
LOW_START = &0400                       ; Loader, scores; the per-level workspace at WORKSPACE
LOW_END = &0800
PAGE9_START = &0900                     ; Plotter, hero tables, the wall map (MOS buffers in BASIC)
PAGE9_END = &0d00
STATIC_WORKSPACE = &0f00                ; The filing system's absolute workspace, borrowed (not page &0E: the NFS keeps state there)
STATIC_WORKSPACE_PAGES = 8
WS_START = STATIC_WORKSPACE
WS_END = STATIC_WORKSPACE + STATIC_WORKSPACE_PAGES * 256
MID_START = &1c00                       ; Above the highest PAGE supported
MID_END = &3000
UP_START = &6e80                        ; Above the 25-row screen
UP_END = &8000

; GAME is loaded at MID_START and runs from startup, in screen memory. The parts of the
; game that run below MID_START are stored in screen memory, and startup copies them into
; place. While a level loads, with the display blanked, the game's contents of the
; absolute workspace are kept at STASH.
LOW_STORE = &3000
PAGE9_STORE = &3400
WS_STORE = &3800
STASH = &3000
STARTUP = &6980                         ; Rows 23-24, which the hero menu leaves alone
SETUP_ADDRESS = &5000                   ; Setup, loaded with each level, clear of STASH and LEVEL_FILE

INCLUDE "asm/defs/workspace.asm"
INCLUDE "asm/defs/level_file.asm"

; ***************************************************************************************
; &1C00-&2FFF: loaded in place
    org MID_START
.game_file_start
INCLUDE "asm/extra/exit.asm"
INCLUDE "asm/extra/doors_keys_sprites.asm"
INCLUDE "asm/core/frame.asm"
INCLUDE "asm/core/chalice.asm"
INCLUDE "asm/core/victory_check.asm"
INCLUDE "asm/core/last_skull.asm"
.mid_end
ASSERT mid_end <= MID_END

; ***************************************************************************************
; &0400-&07FF: stored at LOW_STORE
    org LOW_START
INCLUDE "asm/low/scores.asm"
INCLUDE "asm/core/loader.asm"
INCLUDE "asm/core/level_loop.asm"
.low_end
ASSERT low_end <= WORKSPACE
    copyblock LOW_START, low_end, LOW_STORE
    clear LOW_START, LOW_END

; ***************************************************************************************
; &0900-&0CFF: stored at PAGE9_STORE
    org PAGE9_START
INCLUDE "asm/core/plot.asm"
INCLUDE "asm/core/room_walls.asm"
.page9_end
ASSERT page9_end <= PAGE9_END
    copyblock PAGE9_START, page9_end, PAGE9_STORE
    clear PAGE9_START, PAGE9_END

; ***************************************************************************************
; &0E00-&16FF: stored at WS_STORE
    org WS_START
INCLUDE "asm/core/status_panel.asm"
INCLUDE "asm/core/font.asm"
INCLUDE "asm/core/level_start.asm"
INCLUDE "asm/core/sprites.asm"
INCLUDE "asm/core/game_over_text.asm"
.ws_end
ASSERT ws_end <= WS_END
    copyblock WS_START, ws_end, WS_STORE
    clear WS_START, WS_END
ASSERT WS_STORE + (WS_END - WS_START) <= STARTUP

; ***************************************************************************************
; Run once from screen memory: startup, game_entry and the hero menu
    org STARTUP
INCLUDE "asm/start/startup.asm"
INCLUDE "asm/start/game_entry.asm"
INCLUDE "asm/start/menu.asm"
.startup_end
ASSERT startup_end <= UP_START

; ***************************************************************************************
; Setup: its own file, loaded with each level and run in screen memory
    org SETUP_ADDRESS
.setup_start
INCLUDE "asm/setup/setup.asm"
.setup_end
ASSERT setup_end <= LEVEL_FILE
save "Setup", setup_start, setup_end, setup_level, SETUP_ADDRESS
    clear setup_start, setup_end

; ***************************************************************************************
; &6E80-&7FFF: loaded in place
    org UP_START
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
INCLUDE "asm/core/victory_sequence.asm"
.game_file_end
ASSERT game_file_end <= UP_END

; Layout constraints the code relies on
ASSERT LO(room_walls) = 0               ; test_wall, draw_room and update_game point at a room with >room_walls and the room's offset
ASSERT room_walls = &0c00               ; wrch_handler copies glyphs over character 128's definition through room_walls
ASSERT LO(object_free_map) = 0          ; test_object_free likewise

save "GAME", game_file_start, game_file_end, startup, MID_START
