; ***************************************************************************************
; Start the game
;
; The GAME file's entry point, run once where the file stores it, in screen memory. The
; title has blanked the display and disabled VDU output before *RUN GAME.
;
; Close any *EXEC file (the !BOOT file may still be open, with its buffer in the filing
; system's workspace), disable ESCAPE, note which filing system is selected, and claim
; its absolute workspace with service call &0A. Then copy the parts of the game stored in
; screen memory to where they run, and enter the game with VDU output on and the play
; screen's 23 rows shown. Coder did most of this in the 1987 release, for every level.
.startup
    lda #osbyte_close_spool_exec        ; OSBYTE &77: close any *SPOOL and *EXEC files
    jsr osbyte                          ; ...so no open file depends on the workspace
    lda #osbyte_escape_break_effect     ; Disable ESCAPE for the whole game...
    ldx #1                              ; ...X = 1: ESCAPE disabled, BREAK as normal
    ldy #0                              ; ...Y = 0: X replaces the old setting
    jsr osbyte                          ; Set it
    lda #0                              ; OSARGS 0,0: which filing system is selected?
    tay                                 ; ...Y = 0, A = 0
    jsr osargs                          ; ...its number in A
    pha                                 ; Keep it until the loader is in place
    jsr claim_static_workspace_stored   ; The game takes the filing system's workspace
    lda #>(LOW_STORE)                   ; Copy the stored &0400-&07FF...
    ldy #>(LOW_START)                   ; ...into place
    ldx #(LOW_END - LOW_START) DIV 256  ; ...its pages
    jsr copy_pages_stored               ; Copy them
    lda #>(PAGE9_STORE)                 ; Copy the stored &0900-&0CFF...
    ldy #>(PAGE9_START)                 ; ...into place
    ldx #(PAGE9_END - PAGE9_START) DIV 256  ; ...its pages
    jsr copy_pages                      ; Copy them, now with the loader's copy in place
    lda #>(WS_STORE)                    ; Copy the stored &0E00-&16FF...
    ldy #>(STATIC_WORKSPACE)            ; ...into the workspace just claimed
    jsr copy_static_workspace           ; Copy them
    lda wrchv                           ; Save the MOS's WRCHV in saved_wrchv now...
    sta saved_wrchv                     ; ...low byte...
    lda wrchv + 1                       ; ...and high byte
    sta saved_wrchv + 1                 ; ...for send_vdu, below
    pla                                 ; The filing system's number...
    sta filing_system_number            ; ...for reselect_filing_system
    lda #6                              ; VDU 6: enable VDU output again
    jsr oswrch                          ; Send it
    lda #3                              ; VDU 3: no printer
    jsr oswrch                          ; Send it
    ldx #play_display_vdu - vdu_strings ; Show the play screen's 23 rows
    jsr send_vdu                        ; ...for the hero menu
    jmp game_entry                      ; Enter the game
; Before the loader is copied into place, startup reaches its routines in their stored
; copy in screen memory.
claim_static_workspace_stored = claim_static_workspace - LOW_START + LOW_STORE
copy_pages_stored = copy_pages - LOW_START + LOW_STORE
