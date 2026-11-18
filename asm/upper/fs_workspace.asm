; ***************************************************************************************
; Clear the filing system's absolute workspace
;
; Fill STATIC_WORKSPACE, the filing system's absolute workspace that the game borrows,
; with zeros, before the workspace is handed back for a load. The game's contents have
; been stashed (load_file), or are no longer needed (load_ending). A filing system that
; saves what it needs when the workspace is claimed (service &0A) and rebuilds it when
; selected again does not care. ANFS 4.18 does neither: it ignores service &0A and, being
; still selected, *NET leaves its workspace as it is, so it would read the game's bytes
; as its channel tables (&0FC8, &1000). Zeros are a table with nothing open. It lies with
; the code the end of the game keeps, as load_ending calls it.
;
; On Exit:
;     A: 0
;     X: 0
.clear_fs_workspace
    lda #0                              ; Zero...
    tax                                 ; ...from the start of each page
.clear_fs_workspace_byte
FOR page, 0, STATIC_WORKSPACE_PAGES - 1
    sta STATIC_WORKSPACE + page * &100,x ; ...byte X of each of the eight pages
NEXT
    inx                                 ; The next byte
    bne clear_fs_workspace_byte         ; Until all 256 of each page are done
    rts                                 ; Return with the workspace clear
