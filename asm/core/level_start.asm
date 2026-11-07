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
    jsr load_level                      ; Load the level file, the display blanked meanwhile
    jsr setup_level                     ; Unpack it and reset the workspace and monsters (Setup)
; Show the play screen: clear the text area, display all 25 character rows, then draw the frames and the views.
    ldx #whole_screen_vdu - vdu_strings ; The whole screen as the text window, cleared
    jsr send_vdu                        ; ...for the play screen
    ldx #play_rows_vdu - vdu_strings    ; Show all 25 rows: 6845 register 6 = 25
    jsr send_vdu                        ; ...for the views and the panel
    lda #<(view_frame_plots)            ; (plot_x) points at the frames' PLOT commands...
    sta plot_x                          ; ...low byte in plot_x...
    lda #>(view_frame_plots)            ; ...and view_frame_plots' high byte...
    sta plot_y                          ; ...in plot_y, as draw_view_frames expects
    jsr draw_view_frames                ; Draw the four frames, then the room in each view
    rts                                 ; Return to the level loop to draw the panel and play
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
; Data of sprite &49: 4 bytes x 12 rows.
