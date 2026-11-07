    ALIGN &100                          ; Page-aligned: pointers into it are its high byte and an offset
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
; Health each hero loses when a monster touches it, 3-9 (lowered by a magic helmet). The status panel shows 10 minus this as the armour rating.
.hero_damage_taken
    equb &89, &9e, &87, &f3, &95, &9b, &92, &f7
    equb &90, &98, &8a, &8b, &85, &fd, &9a, &8a
    equb &ae, &a6, &a7, &ac, &aa, &ac, &a8, &a0
    equb &c9, &00, &00, &00, &00, &00, &00, &00
; OSWORD 7 (SOUND) parameter block for a monster hit, and (louder) touching an energy drainer.
.hit_sound
    equw &10, &01, 6, 6                 ; SOUND channel 0 (flush), envelope 1, pitch 6, duration 6
