; ***************************************************************************************
; The banner across the top of the title's page of keys, and its twinkling stars
;
; Written by tools/dunjunz_revised/key_page_banner.py (uv run dr-banner); do not edit.
; The DUNJUNZ logo from the 1987 title picture in teletext mosaic graphics: seven full
; rows of 40 cells, so the cursor moves from each to the next by itself, each row's
; graphics colour code first, with the codes of the stars' sites; text for print_text
; (runs of spaces as their lengths), mosaic characters with bit 7 set, so that the MOS
; puts them on the screen as they are; then a zero.
.key_page_banner
    equb &93, &03, &f8, &ff, &ff, &ff, &ff, &fc, &fc, &f0, &97, &9a, &02, &99, &93, &a2, &ab, &ff, &ff, &ff, &ff, &ff, &af, &a1, &a2, &ab, &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff, &a1, " "
    equb &93, &03, &ff, &af, &a3, &ff, &b7, &a3, &eb, &ff, &e0, &f4, " ", &e0, &f4, &f8, &b0, " ", &f0, &a2, &ff, &f5, " ", &f4, &02, &f8, &f0, &b0, " ", &f0, &02, &ea, &ff, &a5, &02
    equb &93, &03, &a5, &02, &ff, &b5, " ", &ea, &ff, &aa, &ff, &f4, &fa, &bf, &ff, &ff, &fc, &ff, " ", &ef, &ff, " ", &ff, &f5, &f8, &ff, &ef, &ff, &fc, &ff, " ", &e8, &ff, &b7, &97, &02
    equb &97, &9a, &03, &99, &91, &ff, &b5, &e0, &fe, &bf, " ", &ab, &af, &af, &a1, &af, &a5, &a3, &af, " ", &ea, &ff, &b5, &aa, &af, &af, &a7, &aa, &a7, &a3, &af, &e0, &ff, &bf, " ", &97, &02
    equb &97, &9a, &03, &99, &91, &ff, &ff, &ff, &a7, &97, &9a, &03, &99, &91, &ec, &f0, &f0, " ", &f8, &ff, &b5, &97, &9a, &03, &99, &91, " ", &fe, &ff, &f1, " ", &e0, &f8, " "
    equb &91, &05, &e0, &ff, &bf, &a1, " ", &97, &9a, &03, &99, &91, " ", &ab, &af, &ef, &bf, &af, &a1, &97, &9a, &03, &99, &91, " ", &a3, &af, &ff, &ff, &ff, &ff, " "
    equb &95, &a2, &ab, &af, &ff, &fd, &ff, &a7, &0c, &0c, &04, &a3, &af, &ff, " "
    equb 0

STAR_SITES = 5
STAR_TICK_CENTISECONDS = 3
STAR_WINDOW_WIDTH = 3
STAR_WINDOW_BYTES = 6
TWINKLE_FRAMES = 7
; Where each site's window is on the screen.
.star_screen_lo
    equb LO(mode_7_screen + 122), LO(mode_7_screen + 173), LO(mode_7_screen + 187), LO(mode_7_screen + 14), LO(mode_7_screen + 117)
.star_screen_hi
    equb HI(mode_7_screen + 122), HI(mode_7_screen + 173), HI(mode_7_screen + 187), HI(mode_7_screen + 14), HI(mode_7_screen + 117)
; The ticks between each site's twinkles; and each site's count of ticks, which
; show_keys moves on each tick, back to 0 at the period: it twinkles from 0 to
; TWINKLE_FRAMES - 1.
.star_periods
    equb 41, 53, 47, 59, 67
.star_counts
    equb 35, 24, 32, 17, 12
; Where each site's frames start in star_frames.
.star_site_frames
    equb 0, 30, 60, 90, 120
; The frames of a twinkle, as offsets in a site's frames.
.twinkle_frames
    equb 6, 12, 18, 24, 18, 12, 6
; Each site's window, frame by frame: blank, a dot, two crosses, and the largest with
; its angles, each held at the site's largest; the cells by rows, as on the screen.
.star_frames
    equb &20, &20, &20, &20, &20, &20  ; Row 3, column 2: size 0
    equb &20, &b0, &20, &20, &20, &20  ; Row 3, column 2: size 1
    equb &e0, &f4, &20, &20, &a1, &20  ; Row 3, column 2: size 2
    equb &f0, &f5, &b0, &20, &a5, &20  ; Row 3, column 2: size 3
    equb &f8, &fd, &b0, &a2, &a7, &20  ; Row 3, column 2: size 4
    equb &20, &20, &20, &20, &20, &20  ; Row 4, column 13: size 0
    equb &20, &e0, &20, &20, &20, &20  ; Row 4, column 13: size 1
    equb &20, &f8, &b0, &20, &a2, &20  ; Row 4, column 13: size 2
    equb &e0, &fa, &f0, &20, &aa, &20  ; Row 4, column 13: size 3
    equb &e0, &fe, &f4, &20, &ab, &a1  ; Row 4, column 13: size 4
    equb &20, &20, &20, &20, &20, &20  ; Row 4, column 27: size 0
    equb &20, &20, &20, &20, &a1, &20  ; Row 4, column 27: size 1
    equb &20, &b0, &20, &a2, &a7, &20  ; Row 4, column 27: size 2
    equb &20, &b4, &20, &a3, &b7, &a1  ; Row 4, column 27: size 3
    equb &20, &b4, &20, &a3, &b7, &a1  ; Row 4, column 27: size 4
    equb &20, &20, &99, &20, &e0, &f4  ; Row 0, column 14: size 0
    equb &a8, &20, &99, &20, &e0, &f4  ; Row 0, column 14: size 1
    equb &ee, &a4, &99, &20, &e0, &f4  ; Row 0, column 14: size 2
    equb &ee, &a4, &99, &20, &e0, &f4  ; Row 0, column 14: size 3
    equb &ee, &a4, &99, &20, &e0, &f4  ; Row 0, column 14: size 4
    equb &97, &20, &20, &97, &20, &20  ; Row 2, column 37: size 0
    equb &97, &20, &20, &97, &a2, &20  ; Row 2, column 37: size 1
    equb &97, &e0, &20, &97, &ab, &a1  ; Row 2, column 37: size 2
    equb &97, &e0, &20, &97, &ab, &a1  ; Row 2, column 37: size 3
    equb &97, &e0, &20, &97, &ab, &a1  ; Row 2, column 37: size 4
