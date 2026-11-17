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
    lda sprite_width                    ; Four bytes wide, as most sprites are?
    cmp #4                              ; ...
    beq plot_four_wide                  ; Yes: the faster loop
    ldy #0                              ; Index stays 0: the pointers themselves advance
    ldx sprite_height                   ; X counts the pixel rows still to plot
.plot_sprite_row
    lda screen_ptr                      ; Remember where this pixel row starts...
    sta row_start_ptr                   ; ...its low byte...
    lda screen_ptr_hi                   ; ...and its high byte...
    sta row_start_ptr_hi                ; ...in row_start_ptr, to step down from later
    txa                                 ; Save the row count
    pha                                 ; ...on the stack: X now counts bytes
    ldx sprite_width                    ; X counts the bytes across this row
.plot_sprite_byte
    lda (sprite_data_ptr),y             ; Copy one sprite byte...
    sta (screen_ptr),y                  ; ...to the screen, over whatever was there
    clc                                 ; Step screen_ptr right one byte column: 8 bytes on
    lda screen_ptr                      ; ...the screen address's low byte...
    adc #8                              ; ...+ 8, the next byte column...
    sta screen_ptr                      ; ...as screen_ptr's new low byte
    bcc plot_sprite_next_data           ; No carry: the high byte stands
    inc screen_ptr_hi                   ; ...with carry into the high byte
.plot_sprite_next_data
    inc sprite_data_ptr                 ; Next sprite data byte
    bne plot_sprite_count_byte          ; No carry: the high byte stands
    inc sprite_data_ptr_hi              ; ...with carry into the high byte
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
.plot_sprite_next_row
    pla                                 ; Recover the row count
    tax                                 ; ...back into X
    dex                                 ; One pixel row fewer to plot
    bne plot_sprite_row                 ; More rows: plot the next
    rts                                 ; Return: the sprite is on the screen
; ***************************************************************************************
; Plot a sprite four bytes wide
;
; plot_sprite's loop for a sprite four bytes wide, which most are (a cell is four bytes by
; twelve rows), with sprite_data_ptr, sprite_height and screen_ptr set. Y steps through
; the sprite's data and X through the pixel rows of a character row, and the four
; columns, eight bytes apart on the screen, are stored by four STA abs,X whose addresses
; are set at each character row (set_four_wide_columns): about 60 cycles a row, where the
; general loop takes about 230. The data is read with (sprite_data_ptr),Y, so a sprite may
; have at most 63 rows.
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: 0
.plot_four_wide
    lda sprite_height                   ; The data's length: rows x 4...
    asl a                               ; ...x 2...
    asl a                               ; ...x 4...
    sta four_wide_end + 1               ; ...where the row loop stops
    lda screen_ptr                      ; The pixel row within the character row...
    and #7                              ; ...(the address's low three bits)...
    tax                                 ; ...in X
    eor screen_ptr                      ; The character row's top at this column...
    ldy screen_ptr_hi                   ; ...(low byte with those bits cleared, and high)...
    jsr set_four_wide_columns           ; ...and the three columns after it, into the stores
    ldy #0                              ; From the sprite's first byte
.four_wide_row
    lda (sprite_data_ptr),y             ; First column...
.four_wide_store_0
    sta &ffff,x                         ; ...stored at the row in this character row
    iny                                 ; Next byte
    lda (sprite_data_ptr),y             ; Second column...
.four_wide_store_1
    sta &ffff,x                         ; ...eight bytes on
    iny                                 ; Next byte
    lda (sprite_data_ptr),y             ; Third column...
.four_wide_store_2
    sta &ffff,x                         ; ...sixteen bytes on
    iny                                 ; Next byte
    lda (sprite_data_ptr),y             ; Fourth column...
.four_wide_store_3
    sta &ffff,x                         ; ...twenty-four bytes on
    iny                                 ; Next byte
.four_wide_end
    cpy #&ff                            ; All the rows plotted? (rows x 4, set above)
    beq four_wide_done                  ; Yes: done
    inx                                 ; Next pixel row...
    cpx #8                              ; ...still in this character row?
    bne four_wide_row                   ; Yes: plot it
    tya                                 ; No: keep the data index...
    pha                                 ; ...on the stack
    clc                                 ; The character row below, 640 bytes on...
    lda four_wide_store_0 + 1           ; ...from the first column's top: low byte...
    adc #&80                            ; ...+ &80...
    pha                                 ; ...kept...
    lda four_wide_store_0 + 2           ; ...and the high byte...
    adc #2                              ; ...+ 2 and the carry (640 = &280)...
    tay                                 ; ...in Y
    pla                                 ; The low byte in A
    ldx #0                              ; From the character row's top row
    jsr set_four_wide_columns           ; Set the four stores there
    pla                                 ; Recover the data index...
    tay                                 ; ...into Y (never 0 here)
    bne four_wide_row                   ; ...and plot on (always taken)
.four_wide_done
    ldx #0                              ; Leave X and Y 0, as plot_sprite does
    ldy #0                              ; ...
    rts                                 ; Return: the sprite is on the screen
; Set the four stores of plot_four_wide to the character row whose first column's top is
; at A (low) and Y (high), and the next three columns, 8, 16 and 24 bytes on.
.set_four_wide_columns
    sta four_wide_store_0 + 1           ; First column: low byte...
    sty four_wide_store_0 + 2           ; ...and high byte
    clc                                 ; Second column: 8 bytes on...
    adc #8                              ; ...
    bcc set_four_wide_column_1          ; No carry: the same page
    iny                                 ; Carry: the next page
.set_four_wide_column_1
    sta four_wide_store_1 + 1           ; ...low byte...
    sty four_wide_store_1 + 2           ; ...and high byte
    clc                                 ; Third column: 8 bytes on again...
    adc #8                              ; ...
    bcc set_four_wide_column_2          ; No carry: the same page
    iny                                 ; Carry: the next page
.set_four_wide_column_2
    sta four_wide_store_2 + 1           ; ...low byte...
    sty four_wide_store_2 + 2           ; ...and high byte
    clc                                 ; Fourth column: 8 bytes on again...
    adc #8                              ; ...
    bcc set_four_wide_column_3          ; No carry: the same page
    iny                                 ; Carry: the next page
.set_four_wide_column_3
    sta four_wide_store_3 + 1           ; ...low byte...
    sty four_wide_store_3 + 2           ; ...and high byte
    rts                                 ; Return with the stores set
; ***************************************************************************************
; Calculate a screen address
;
; Set screen_ptr to the screen address of byte column plot_x on pixel row plot_y: &3000 +
; 640 x (plot_y DIV 8) + (plot_y MOD 8) + 8 x plot_x. plot_sprite calls it once per
; sprite, for the top-left byte. The multiplication by 640 is done with row_offsets, two
; bytes per character row, high byte first. The high byte of 8 x plot_x is plot_x DIV 32, taken from plot_x's
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
.screen_address
    lda plot_y                          ; Table index = 2 x (plot_y DIV 8), the character row...
    lsr a                               ; ...plot_y DIV 2...
    lsr a                               ; ...plot_y DIV 4: 2 x the character row, + plot_y bit 2...
    and #&fe                            ; ...bit 0 cleared: the row's pair of table bytes
    tay                                 ; ...as the index into the row table
    lda row_offsets,y                   ; High byte of row x 640, from row_offsets...
    clc                                 ; ...(carry clear for the add)
    adc #>(screen_start)                ; ...plus &30: the screen starts at &3000
    sta screen_ptr_hi                   ; ...as the screen address high byte
    lda row_offsets_lo,y                ; Low byte of row x 640
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
.screen_address_done
    rts                                 ; Return with screen_ptr set
; The exit's map x, kept while a hero goes down it.
.exit_saved_x
    equb &04
; The exit's map y, kept while a hero goes down it.
.exit_saved_y
    equb &2c
; Non-zero while a hero is going down the exit.
.exit_busy
    equb &00
; Direction (1, 3, 5, 7) of the hero spinning on the exit.
.exit_spin
    equb &ff
; Spins left before the hero has gone (4 to 1).
.exit_shrinks_left
    equb &00
; The hero going down the exit.
.exiting_hero
    equb &03
.exit_offsets_x
    equb &04
; exit_offsets_x entry 1.
.exit_offset_x_1
    equb &01
; exit_offsets_x entry 2.
.exit_offset_x_2
    equb &01
; exit_offsets_x entry 3.
.exit_offset_x_3
    equb &00
; Vertical offset of the shrinking hero, in pixel rows, entries 1-4 by exit_shrinks_left (at exit_offsets_y+1 to +4). Also entry 4 of exit_offsets_x.
.exit_offsets_y
    equb &00
; exit_offsets_y entry 1.
.exit_offset_y_1
    equb &05
; exit_offsets_y entry 2.
.exit_offset_y_2
    equb &03
; exit_offsets_y entry 3.
.exit_offset_y_3
    equb &01
; exit_offsets_y entry 4.
.exit_offset_y_4
    equb &00
; The hero whose sprites are shrunk, or &FF.
.shrunk_hero
    equb &ff
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
.hero_max_missiles
    equb &03, &02, &01, &03
; INKEY key numbers of the magic keys of heroes 0 and 1, the only heroes with magic.
.hero_magic_key
    equb inkey_key_ctrl, inkey_key_return
; Frames until heroes 0 and 1 next check their magic key.
.hero_magic_delay
    equb &01, &01
; Monsters killed by the magic being cast, each worth a point.
.magic_kill_count
    equb &00, &10
; Queue of heroes waiting to come back: each entry is a hero number plus 1, or &64 for a slot that brings nobody back; 0 ends the queue. A Cross of Resurrection takes the first entry.
.returning_hero_queue
    equb &03
    equb &02                            ; Queue entry 1
    equb &01                            ; Queue entry 2
    equb &04                            ; Queue entry 3
    equb &10                            ; Queue entry 4
; Index (0-7) of the trapdoor from which the next monster emerges.
.next_trapdoor
    equb &04
; Sprites of a hero dying, in order (sparkles &16-&19, then skulls &64-&68, ending as the skull left where the hero fell), or returning, in reverse.
.hero_appearance_sprites
    equb &16, &17, &18, &19
    equs "defgh"
; Hit points left for each monster (entries 1-30); a hit subtracts the missile's damage.
.monster_hit_points
    equb &10, &08, &08, &08, &08, &08, &08, &08
    equb &08, &08, &08, &08, &08, &08, &08, &05
    equb &08, &08, &08, &08, &08, &08, &08, &08
    equb &08, &08, &08, &08, &08, &08, &08, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
; Damage each hero's missiles do, 1-9 (raised by a magic sword).
.hero_missile_damage
    equb &02, &03, &09, &03, &10, &10, &10, &10
    equb &10, &10, &10, &10, &10, &10, &10, &10
; Damage each missile in flight will do (12 slots, three per hero).
.missile_damage
    equb &02, &02, &02, &03, &03, &04, &09, &09
    equb &10, &03, &03, &03, &10, &10, &10
; Map x of the level's eight trapdoors, from the level file.
.trapdoor_x
    equb &0b
    equb &15                            ; Trapdoor 2's x
    equb &17                            ; Trapdoor 3's x
    equb &10                            ; Trapdoor 4's x
    equb &03                            ; Trapdoor 5's x
    equb &17                            ; Trapdoor 6's x
    equb &0d                            ; Trapdoor 7's x
    equb &1a                            ; Trapdoor 8's x
; Map y of the level's eight trapdoors, from the level file.
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
.hero_score_hundreds
    equb &1e, &1e, &1e, &1e
; Score tens digit, as a digit sprite.
.hero_score_tens
    equb &1e, &1e, &1e, &1e
; Score units digit, as a digit sprite.
.hero_score_units
    equb &1d, &1d, &1d, &1d
; Score thousands digit, as a digit sprite.
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
    equw &13, &02, 200, 2               ; SOUND channel 3 (flush), envelope 2, pitch 200, duration 2
