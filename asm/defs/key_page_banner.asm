; ***************************************************************************************
; The banner across the top of the title's page of keys
;
; Written by tools/dunjunz_revised/key_page_banner.py (uv run dr-banner); do not edit.
; The DUNJUNZ logo from the 1987 title picture in teletext mosaic graphics: seven full
; rows of 40 cells, so the cursor moves from each to the next by itself, each row's
; graphics colour code first, then a zero. Every byte has bit 7
; set, so the MOS puts it on the screen as it is.
.key_page_banner
    equb &93, &a0, &a0, &a0, &f8, &9d, &a0, &9e, &fc, &9c, &fc, &f0, &a0, &a0, &a0, &a0, &a0, &a0, &a2, &ab, &9d, &a0, &a0, &a0, &af, &9c, &a1, &a2, &ab, &9d, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a1, &9c, &a0
    equb &93, &a0, &a0, &a0, &ff, &af, &a3, &ff, &b7, &a3, &eb, &ff, &e0, &f4, &a0, &e0, &f4, &f8, &b0, &a0, &f0, &a2, &ff, &f5, &a0, &f4, &a0, &a0, &f8, &f0, &b0, &a0, &f0, &a0, &a0, &ea, &ff, &a5, &a0, &a0
    equb &93, &a0, &a0, &a0, &a5, &a0, &a0, &ff, &b5, &a0, &ea, &ff, &aa, &ff, &f4, &fa, &bf, &ff, &9e, &fc, &ff, &a0, &ef, &ff, &a0, &ff, &f5, &f8, &ff, &ef, &ff, &fc, &ff, &a0, &e8, &ff, &b7, &a0, &a0, &a0
    equb &91, &a0, &a0, &a0, &a0, &a0, &a0, &ff, &b5, &e0, &fe, &bf, &a0, &ab, &af, &9e, &a1, &af, &a5, &a3, &af, &a0, &ea, &ff, &b5, &aa, &af, &af, &a7, &aa, &a7, &a3, &af, &e0, &ff, &bf, &a0, &a0, &a0, &a0
    equb &91, &a0, &a0, &a0, &a0, &a0, &a0, &9d, &9e, &a7, &9c, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &ec, &f0, &f0, &a0, &f8, &ff, &b5, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &fe, &ff, &f1, &a0, &e0, &f8, &a0
    equb &91, &a0, &a0, &a0, &a0, &a0, &e0, &ff, &bf, &a1, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &ab, &af, &ef, &bf, &af, &a1, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a3, &af, &9d, &a0, &a0, &a0, &a0
    equb &95, &a2, &ab, &af, &ff, &fd, &ff, &a7, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a0, &a3, &af, &9d, &a0
    equb 0
