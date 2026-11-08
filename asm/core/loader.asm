; ***************************************************************************************
; Load the level
;
; Load Setup, the level set-up code, at SETUP_ADDRESS and the file LevelN, N from
; level_digits, into the level file buffer at LEVEL_FILE, both in screen memory, with the
; display blanked, then show the play screen's 23 rows again. Called by start_level at the start of every level.
;
; The game owns the filing system's absolute workspace (STATIC_WORKSPACE) while it plays:
; startup claimed it with service call &0A, which makes the filing system save what it
; needs into its private workspace. load_file hands it back for each load.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.load_level
    ldx #blank_display_vdu - vdu_strings ; Blank the display while the files load...
    jsr send_vdu                        ; ...6845 register 1 = 0, no characters shown
    lda level_digits                    ; The level number's first digit...
    sta level_name_digits               ; ...after "Level"
    lda level_digits + 1                ; Its second digit, or a space for levels 1-9...
    cmp #' '                            ; ...a space?
    bne store_second_digit              ; No: two digits
    lda #&0d                            ; Yes: end the name after one digit
.store_second_digit
    sta level_name_digits + 1           ; The second digit, or the name's CR
    ldx #<(setup_osfile_block)          ; Load Setup, the level set-up code...
    ldy #>(setup_osfile_block)          ; ...with setup_osfile_block
    jsr load_file                       ; ...through the filing system
    ldx #<(level_osfile_block)          ; Load the level file...
    ldy #>(level_osfile_block)          ; ...with level_osfile_block
    jsr load_file                       ; ...through the filing system
    ldx #play_display_vdu - vdu_strings ; Show the play screen's 23 rows again
                                        ; ...and return: fall into send_vdu
; ***************************************************************************************
; Send a VDU string
;
; Send the string at vdu_strings + X, a count and then that many bytes, through mos_wrch,
; so that saved_wrchv must be set.
;
; On Entry:
;     X: offset of the string's count in vdu_strings
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: 0
.send_vdu
    ldy vdu_strings,x                   ; The number of bytes
.send_vdu_byte
    inx                                 ; The next byte...
    lda vdu_strings,x                   ; ...of the string
    jsr mos_wrch                        ; Send it, past wrch_handler
    dey                                 ; One fewer to send
    bne send_vdu_byte                   ; Until all are sent
    rts                                 ; Return
; Print A through the MOS's own WRCHV, as saved in saved_wrchv, not through wrch_handler,
; which would print a letter or digit among the parameters of a VDU 23 (80 is "P") as
; character 128.
.mos_wrch
    jmp (saved_wrchv)                   ; The MOS's WRCH routine returns to the caller
; ***************************************************************************************
; Load a file while the game owns the filing system's workspace
;
; Copy the game's contents of STATIC_WORKSPACE to STASH, in screen memory, which must not
; be on show; reselect the filing system, which rebuilds its workspace from its private
; workspace; load the file with OSFILE &FF; claim the workspace again with service call
; &0A; and copy the game's contents back. VDU output is disabled meanwhile, so nothing the
; filing system prints reaches the screen (wrch_handler would print it with a font that is
; not there).
;
; On Entry:
;     X, Y: address of an OSFILE control block whose load address is used
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.load_file
    stx load_file_block                 ; Keep the control block's address...
    sty load_file_block + 1             ; ...for the OSFILE call
    lda #&15                            ; VDU 21: disable VDU output
    jsr oswrch                          ; ...during the load
    lda #>(STATIC_WORKSPACE)            ; Copy the game's workspace pages...
    ldy #>(STASH)                       ; ...to the stash
    jsr copy_static_workspace           ; ...out of the filing system's way
    jsr reselect_filing_system          ; The filing system takes its workspace back
    lda #osfile_load                    ; OSFILE &FF: load the file...
    ldx load_file_block                 ; ...with the caller's control block
    ldy load_file_block + 1             ; ...(X, Y)
    jsr osfile                          ; Load it
    jsr claim_static_workspace          ; Take the workspace for the game again
    lda #>(STASH)                       ; Copy the game's pages back...
    ldy #>(STATIC_WORKSPACE)            ; ...from the stash to the workspace
    jsr copy_static_workspace           ; ...the game is whole again
    lda #6                              ; VDU 6: enable VDU output
    jmp oswrch                          ; ...and return
; ***************************************************************************************
; Claim the filing system's absolute workspace
;
; Issue service call &0A through OSBYTE &8F: the filing system that owns the absolute
; workspace saves what it needs into its private workspace and gives the space up.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.claim_static_workspace
    lda #osbyte_issue_service           ; OSBYTE &8F: issue a paged ROM service call...
    ldx #service_claim_static_workspace ; ...&0A: claim the static workspace
    ldy #&ff                            ; ...Y not used by the call
    jmp osbyte                          ; Claim it, and return
; ***************************************************************************************
; Copy the game's workspace pages
;
; Copy STATIC_WORKSPACE_PAGES pages from page A to page Y, through pointers in the
; plotter's zero page (plot_x, sprite_width), which nothing else uses meanwhile.
;
; On Entry:
;     A: source page
;     Y: destination page
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: 0
.copy_static_workspace
    ldx #STATIC_WORKSPACE_PAGES         ; The number of pages to copy
; Copy X pages from page A to page Y; startup uses this entry too.
.copy_pages
    sta plot_y                          ; Source pointer's high byte...
    sty sprite_height                   ; ...and the destination's
    ldy #0                              ; Both pointers start at the start of a page
    sty plot_x                          ; ...source low byte 0
    sty sprite_width                    ; ...destination low byte 0
.copy_page_byte
    lda (plot_x),y                      ; Copy a byte...
    sta (sprite_width),y                ; ...to the destination
    iny                                 ; Next byte of the page
    bne copy_page_byte                  ; Until the page is done
    inc plot_y                          ; Next source page
    inc sprite_height                   ; Next destination page
    dex                                 ; One page fewer to copy
    bne copy_page_byte                  ; Until all are copied
    rts                                 ; Return
; ***************************************************************************************
; Reselect the filing system
;
; Select the filing system the game was started from again, so that it rebuilds its
; absolute workspace from its private workspace. The disc and network filing systems are
; selected with *DISC and *NET, which every version handles; any other with service call
; &12, which DFS 0.90 does not survive.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.reselect_filing_system
    lda filing_system_number            ; The filing system's number, from OSARGS 0,0
    ldx #<(disc_command)                ; 4, a disc filing system: *DISC
    ldy #>(disc_command)                ; ...(X, Y) = the command
    cmp #filing_system_disc             ; A disc filing system?
    beq reselect_by_command             ; Yes: *DISC
    ldx #<(net_command)                 ; 5, the network filing system: *NET
    ldy #>(net_command)                 ; ...(X, Y) = the command
    cmp #filing_system_net              ; The network filing system?
    beq reselect_by_command             ; Yes: *NET
    tay                                 ; Otherwise service call &12 with Y = its number...
    lda #osbyte_issue_service           ; ...through OSBYTE &8F
    ldx #service_select_filing_system   ; ...&12: initialise filing system Y
    jmp osbyte                          ; Select it, and return
.reselect_by_command
    jmp oscli                           ; Select it by its command, and return
; ***************************************************************************************
; Load the title and the game afresh
;
; End the game, after game over or victory: give WRCHV back to the MOS, hand the
; workspace back to the filing system, and *RUN DUNJUNZ, which loads over the game and
; never returns.
.restart_game
    lda saved_wrchv                     ; Put the MOS's WRCHV back...
    sta wrchv                           ; ...low byte...
    lda saved_wrchv + 1                 ; ...and high byte
    sta wrchv + 1                       ; ...so the title prints in the MOS's font
    jsr reselect_filing_system          ; The filing system takes its workspace back
    ldx #<(run_title_command)           ; *RUN DUNJUNZ...
    ldy #>(run_title_command)           ; ...(X, Y) = the command
    jmp oscli                           ; ...which does not return
; ***************************************************************************************
; The loader's data
;
; The filing system's number, set by startup from OSARGS 0,0.
.filing_system_number
    equb 0
; The address of load_file's OSFILE control block.
.load_file_block
    equw 0
.disc_command
    equs "DISC", &0d                    ; Selects a disc filing system again
.net_command
    equs "NET", &0d                     ; Selects the network filing system again
.run_title_command
    equs "RUN DUNJUNZ", &0d             ; The title, which loads the game again
; The OSFILE control block for a level: its name, and the load address, in the I/O
; processor's memory (&FFFF in the top half) even when a second processor is present.
.level_osfile_block
    equw level_name                     ; The filename
    equd &ffff0000 + LEVEL_FILE         ; Load address: the level file buffer
    equd 0                              ; Exec address byte 0 = 0: load at the address above
    equd 0                              ; Not used for a load
    equd 0                              ; Not used for a load
; The OSFILE control block for Setup, likewise.
.setup_osfile_block
    equw setup_name                     ; The filename
    equd &ffff0000 + SETUP_ADDRESS      ; Load address: where start_level runs it
    equd 0                              ; Exec address byte 0 = 0: load at the address above
    equd 0                              ; Not used for a load
    equd 0                              ; Not used for a load
.setup_name
    equs "Setup", &0d
.level_name
    equs "Level"                        ; "LevelN" or "LevelNN", CR-terminated
.level_name_digits
    equs "1", &0d, &0d                  ; The digits, set by load_level
; Strings for send_vdu: each a count, then the bytes.
.vdu_strings
.blank_display_vdu
    equb 20
    equb &17, &00, &01, &00, &00, &00, &00, &00, &00, &00  ; 6845 register 1 = 0: no characters shown
    equb &17, &00, &0a, &20, &00, &00, &00, &00, &00, &00  ; Register 10 = &20: no cursor
.play_display_vdu
    equb 22
    equb &11, &02                       ; VDU 17,2: text colour 2, for the menu and the messages
    equb &17, &00, &01, &50, &00, &00, &00, &00, &00, &00  ; Register 1 = 80 characters shown
    equb &17, &00, &06, &17, &00, &00, &00, &00, &00, &00  ; Register 6 = 23 character rows shown
.play_rows_vdu
    equb 10
    equb &17, &00, &06, &19, &00, &00, &00, &00, &00, &00  ; Register 6 = 25: the views and panel fill rows 0-24
.whole_screen_vdu
    equb 6
    equb &1c, &00, &18, &13, &00, &0c   ; VDU 28,0,24,19,0: the whole screen as the text window; VDU 12 clears it
.views_window_vdu
    equb 6
    equb &1c, &00, &18, &10, &00, &0c   ; VDU 28,0,24,16,0: the views, short of the panel; VDU 12 clears them
