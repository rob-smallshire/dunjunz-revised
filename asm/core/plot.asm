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
    equb &10, &10, &10, &10, &10, &10, &10  ; Not referenced
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
    equb &10                            ; Not referenced
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
; The level's wall map, from the level file: eight bytes per room, one per row of cells, one bit per cell (bit 7 at the left). Rooms are 8x8 cells and run four to a row of the map. The first eight bytes are also the MOS 1.20 definition of character 128, which the WRCHV handler overwrites with each glyph it prints; the level is unpacked only after the level number has been printed.
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
.hero_damage_taken
    equb &89, &9e, &87, &f3, &95, &9b, &92, &f7
    equb &90, &98, &8a, &8b, &85, &fd, &9a, &8a
    equb &ae, &a6, &a7, &ac, &aa, &ac, &a8, &a0
    equb &c9, &00, &00, &00, &00, &00, &00, &00
; OSWORD 7 (SOUND) parameter block for a monster hit, and (louder) touching an energy drainer.
.hit_sound
    equw &10, &01, 6, 6                 ; SOUND channel 0 (flush), envelope 1, pitch 6, duration 6
    equb &12, &00, &03, &00, &c8, &00, &0a, &00  ; Not referenced
    equb &a9
    equb &30
    equb &8d
    equb &bd
    equb &08, &a9
    equb &20
    equb &8d
    equb &be
    equb &08, &a9, &00, &8d, &bc, &08, &ea
    equb &4c, &10, &0d, &0d, &a2
    equb &80, &a0, &0d, &a9
    equb &00                            ; Not read: page &0D is refreshed from workspace_template
    equb &8d
    equb &84                            ; Hero 1's direction
    equb &0d                            ; Hero 2's direction
    equb &8d, &85                       ; Hero 3's direction
    equb &0d                            ; Not read: page &0D is refreshed from workspace_template
    equb &ad
    equb &12                            ; Hero 1's frame
    equb &02                            ; Hero 2's frame
    equb &8d, &2f                       ; Hero 3's frame
    equb &0d, &ad, &13, &02, &8d
    equb &30, &0d, &a9, &06, &20, &ee
    equb &ff
