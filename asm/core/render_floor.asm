; ***************************************************************************************
; Draw a cell's floor
;
; Draw map cell cell_x, cell_y afresh, from the back: the object there, or else a
; trapdoor, or else the blank, solid; then, see-through, a hero out of play there (their
; sparkles or skull, hero_appearance_sprites) and a key (one, though keys may be
; stacked). The heroes nobody plays lie off the views (x &1F) and are never drawn.
;
; On Entry:
;     CELL_X, CELL_Y: map cell
;
; On Exit:
;     A, X, Y: corrupted
.draw_floor_cell
    ldy #max_object                     ; Objects 30 to 1: one in the cell?
.floor_object
    lda object_x,y                      ; This object's x...
    cmp cell_x                          ; ...the cell's?
    bne next_floor_object               ; No: the next
    lda object_y,y                      ; ...and y?
    cmp cell_y                          ; ...
    bne next_floor_object               ; No: the next
    lda object_type,y                   ; Yes: its sprite
    bne floor_base                      ; (always taken: no object type is 0)
.next_floor_object
    dey                                 ; The next object down
    bne floor_object                    ; Until object 1
    ldy #7                              ; Trapdoors 7 to 0: one in the cell?
.floor_trapdoor
    lda trapdoor_x,y                    ; This trapdoor's x...
    cmp cell_x                          ; ...the cell's?
    bne next_floor_trapdoor             ; No: the next
    lda trapdoor_y,y                    ; ...and y?
    cmp cell_y                          ; ...
    bne next_floor_trapdoor             ; No: the next
    lda #spr_trapdoor                   ; Yes: the trapdoor
    bne floor_base                      ; (always taken)
.next_floor_trapdoor
    dey                                 ; The next trapdoor down
    bpl floor_trapdoor                  ; Until trapdoor 0
    lda #spr_blank                      ; Neither: the blank
.floor_base
    sta sprite_number                   ; The base, solid
    lda #0                              ; ...
    jsr plot_floor                      ; ...
    ldx #3                              ; Heroes 3 to 0: one out of play here?
.floor_absent_hero
    lda hero_direction,x                ; Out of play (direction 0)?
    bne next_floor_absent_hero          ; No: drawn as a creature
    lda hero_x,x                        ; In this cell?
    cmp cell_x                          ; ...
    bne next_floor_absent_hero          ; No: the next
    lda hero_y,x                        ; ...
    cmp cell_y                          ; ...
    bne next_floor_absent_hero          ; No: the next
    ldy hero_frame,x                    ; Yes: their place in the sequence...
    lda hero_appearance_sprites,y       ; ...its sprite (sparkles to skull)...
    sta sprite_number                   ; ...
    txa                                 ; Keep the hero...
    pha                                 ; ...
    lda #&80                            ; ...see-through
    jsr plot_floor                      ; ...
    pla                                 ; Recover the hero
    tax                                 ; ...
.next_floor_absent_hero
    dex                                 ; The next hero down
    bpl floor_absent_hero               ; Until hero 0
    ldy #max_key                        ; Keys 20 to 1: one in the cell?
.floor_key
    lda key_x,y                         ; This key's x...
    cmp cell_x                          ; ...the cell's?
    bne next_floor_key                  ; No: the next
    lda key_y,y                         ; ...and y?
    cmp cell_y                          ; ...
    bne next_floor_key                  ; No: the next
    lda #spr_key                        ; Yes: a key, see-through
    sta sprite_number                   ; ...
    lda #&80                            ; ...
    jmp plot_floor                      ; ...and return (one is enough)
.next_floor_key
    dey                                 ; The next key down
    bne floor_key                       ; Until key 1
    rts                                 ; Return with the cell drawn
