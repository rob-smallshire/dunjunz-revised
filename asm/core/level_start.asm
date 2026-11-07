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
.next_level_by_reset
    lda #&4c ; 'L'                      ; Arm the BREAK intercept: a JMP opcode...
    sta os_break_intercept              ; ...into &0287, the intercept's first byte...
    lda #<(next_level_intercept)        ; ...JMP to next_level_intercept: low byte...
    sta os_break_intercept + 1          ; ...into &0288, the JMP's low byte
    lda #>(next_level_intercept)        ; ...then the routine's page...
    sta os_break_intercept + 2          ; ...into &0289: the intercept is armed
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
.reset_workspace
    ldx #0                              ; Copy workspace_template to page &0D
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
.draw_view_frames
    lda saved_wrchv                     ; Restore the MOS's own WRCHV for the PLOT commands...
    sta wrchv                           ; ...saved_wrchv's low byte into WRCHV...
    lda saved_wrchv + 1                 ; ...and its high byte...
    sta wrchv + 1                       ; ...so the PLOTs draw lines, not the game's font
    ldx #&14                            ; Twenty PLOT commands: five for each view's frame
.draw_view_frame
    lda #&19                            ; Start a PLOT command: VDU 25...
    jsr oswrch                          ; Send VDU 25: a PLOT command follows
    ldy #0                              ; ...then the five bytes of the command
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
.unpack_level
    ldx #max_object                     ; Objects 30 to 1: position and type
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
.unpack_keys
    lda level_key_x,x                   ; Key's x in the level file...
    sta key_x,x                         ; ...becomes its map x
    lda level_key_y,x                   ; The key's y in the file...
    sta key_y,x                         ; ...becomes its map y
    dex                                 ; Next key down
    bne unpack_keys                     ; Until key 1 is done
    ldx #0                              ; Trapdoors 0 to 7: where dead monsters come back
.unpack_trapdoors
    lda level_trapdoor_x,x              ; Trapdoor's x in the level file...
    sta trapdoor_x,x                    ; ...becomes its map x
    lda level_trapdoor_y,x              ; The trapdoor's y in the file...
    sta trapdoor_y,x                    ; ...becomes its map y
    inx                                 ; Next trapdoor up, 0 to 7
    cpx #8                              ; All eight done?
    bne unpack_trapdoors                ; No: copy the next
    ldx #0                              ; Wall map and object-free map, &C9 bytes each
.unpack_walls
    lda level_walls,x                   ; Byte of the level's wall map...
    sta room_walls,x                    ; ...into room_walls, which test_wall reads
    lda level_object_free_map,x         ; Byte of the level's object-free map...
    sta object_free_map,x               ; ...into object_free_map, which test_object_free reads
    inx                                 ; Next byte of both maps
    cpx #map_bytes                      ; Both maps copied?
    bne unpack_walls                    ; No: copy the next
    ldx #0                              ; The level's own wall block, &30 bytes
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
.reset_monsters
    ldx #max_monster                    ; Monsters 30 to 1...
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
.clear_text_area
    lda #&1c                            ; VDU 28: a text window over the whole screen...
    jsr oswrch                          ; Send VDU 28
    lda #0                              ; Left column 0
    jsr oswrch                          ; Send the left column
.set_text_window_bottom
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
.find_queue_end
    lda returning_hero_queue,x          ; Entry X of the queue
    bne next_queue_entry                ; In use: try the next
    lda #nobody_returns                 ; Empty: add a &64 marker there
    sta returning_hero_queue,x          ; ...in the first empty entry, behind those waiting
    rts                                 ; Return to hero_enters_exit
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
.level_bcd
    equb &01
; Data of sprite &49: 4 bytes x 12 rows.
