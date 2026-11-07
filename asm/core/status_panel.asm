; ***************************************************************************************
; Give a hero their starting attributes
;
; Undo everything hero X has gained: set their missile limit, missile damage and health
; lost per hit (hero_max_missiles, hero_missile_damage, hero_damage_taken) from the
; starting tables at &0F80, and their score to 0000 with no ten-thousands digit. It is
; called for every hero when a game starts, and by level_loop for each hero who died (or
; was not playing) when a level ends, so a dead hero comes back on the next level as new,
; while survivors keep their scores and the gains from objects. Health and position are
; not set here: reset_workspace restores those for every hero at each level. The units
; digit is set one below 0 because draw_status_panel draws the score by adding a point.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.reset_hero
    lda hero_start_max_missiles,x       ; Starting missile limit...
    sta hero_max_missiles,x             ; ...as hero X's missile limit
    lda hero_start_missile_damage,x     ; Starting missile damage...
    sta hero_missile_damage,x           ; ...as their missile damage
    lda hero_start_damage_taken,x       ; Starting health lost per hit (armour)...
    sta hero_damage_taken,x             ; ...as their health lost per hit
    lda #spr_digit_0                    ; Score 0000: digit sprite 0...
    sta hero_score_thousands,x          ; ...as the thousands digit...
    sta hero_score_hundreds,x           ; ...the hundreds digit...
    sta hero_score_tens,x               ; ...and the tens digit
    lda #spr_digit_0 - 1                ; ...units one below 0: draw_status_panel adds a point
    sta hero_score_units,x              ; ...as the units digit
    lda #spr_small_digit_1 - 1          ; No ten-thousands digit (&69, one below small 1)
    sta hero_score_ten_thousands,x      ; ...as the ten-thousands digit
    rts                                 ; Return, X still the hero
; ***************************************************************************************
; Draw the status panel
;
; Draw each hero's section of the status panel, the column to the right of the views,
; Ranger at the top to Fighter at the bottom. level_loop calls it once per level, after
; start_level has drawn the fresh screen and before remove_absent_heroes.
;
; The health and score are drawn by the routines play uses to change them:
; lose_health_point takes a point from the template's health of 99 + 1, so every hero
; starts every level on 99, and add_point adds one to the score, which a hero just reset
; has one below 0000. So a hero who survived the last level, and kept their score, gains
; a point here at every new level. Then, through plot_panel_sprite, which places each
; sprite relative to the hero's panel row (hero_panel_y): the face and the shield on the
; section's top row, with the armour rating (10 - health lost per hit) as a small digit
; on the shield; the missile damage as a small digit; and one missile icon per missile
; allowed in flight, three rows apart, beside the health. The keys, the boots icon and
; the ten-thousands digit are drawn elsewhere. panel_hero is the hero being drawn; count
; holds the icons' end row.
;
; On Exit:
;     A: corrupted
;     X: corrupted
;     Y: corrupted
.draw_status_panel
    lda #0                              ; For each hero's section...
    sta panel_hero                      ; ...starting with the Ranger's, at the top
; Health and score first, drawn by the routines that change them in play.
.draw_panel_hero
    ldx panel_hero                      ; X = this hero
    jsr lose_health_point               ; Take a point from the template's 99 + 1: draws 99
    jsr add_point                       ; Add a point: draws the score (0000 if just reset)
; The section's top row: the hero's face and the shield, with the armour rating on the shield.
    lda hero_faces,x                    ; The hero's face (their facing-down sprite)...
    ldx #panel_left                     ; ...at column &45, the panel's left...
    ldy #0                              ; ...on the section's top row...
    jsr plot_panel_sprite               ; ...plotted at the section's top left
    ldx #panel_left + 8                 ; Shield at column &4D, the section's top right
    ldy #0                              ; ...on the top row...
    lda #spr_shield                     ; ...the shield sprite...
    jsr plot_panel_sprite               ; ...plotted, for the armour rating to go on
    ldx panel_hero                      ; Armour rating on the shield: 10 - health lost per hit
    sec                                 ; ...(no borrow into the subtract)
    lda #spr_small_digit_1 + 9          ; ...from &73, small digit 1 + 9...
    sbc hero_damage_taken,x             ; ...less the damage per hit
    ldx #panel_left + 9                 ; ...at column &4E...
    ldy #2                              ; ...2 rows down the section...
    jsr plot_panel_sprite               ; ...plotted on the shield
; One missile icon per missile the hero may have in flight, three rows apart from row &10.
    ldx panel_hero                      ; Icon rows run from &10 to &10 + 3 x missile limit...
    lda hero_max_missiles,x             ; ...the hero's missile limit, 1-3 at the start...
    asl a                               ; ...x 2...
    clc                                 ; ...(carry clear for the add)
    adc hero_max_missiles,x             ; ...+ limit: 3 rows per icon...
    adc #&10                            ; ...+ &10: the row after the last icon
    sta count                           ; ...(end row in count)
    ldy #&10                            ; ...first icon at row &10, beside the health
.draw_missile_icons
    tya                                 ; Keep the row...
    pha                                 ; ...on the stack
    ldx #panel_left + 6                 ; ...at column &4B
    lda #spr_missile_icon               ; ...the missile icon...
    jsr plot_panel_sprite               ; ...plotted at row Y
    pla                                 ; Recover the row...
    clc                                 ; ...(carry clear for the add)
    adc #3                              ; ...3 rows down...
    tay                                 ; ...for the next icon
    cpy count                           ; Past the last icon's row?
    bcc draw_missile_icons              ; No: plot another
; The damage the hero's missiles do, then on to the next hero's section.
    ldx panel_hero                      ; Missile damage as a small digit, above the icons
    lda hero_missile_damage,x           ; ...the hero's missile damage...
    clc                                 ; ...(carry clear for the add)
    adc #spr_small_digit_1 - 1          ; ...+ &69: small digit 1 for damage 1
    ldx #panel_left + 7                 ; ...at column &4C...
    ldy #&0a                            ; ...&0A rows down, four above the health...
    jsr plot_panel_sprite               ; ...plotted: the damage each missile does
    inc panel_hero                      ; Next hero's section
    lda panel_hero                      ; All four heroes drawn?
    cmp #4                              ; ...(four of them)
    bne draw_panel_hero                 ; No: the next hero
    rts                                 ; Return: all four sections drawn
; ***************************************************************************************
; Plot a sprite in a hero's panel section
;
; Plot sprite A at byte column X and pixel row Y + hero_panel_y - 14 for the hero
; panel_hero, the one draw_status_panel is drawing. Row 0 of a section is thus 14 rows
; above the health digits, which sit at the panel row itself. The panel row is read from
; workspace_template, whose copy in page &0D, made by reset_workspace, is hero_panel_y.
;
; On Entry:
;     A: sprite number
;     X: byte column
;     Y: row within the hero's panel section
;     PANEL_HERO: hero whose section it is (0-3)
;
; On Exit:
;     A: corrupted
;     X: 0
;     Y: 0
.plot_panel_sprite
    stx plot_x                          ; Byte column from X
    sta sprite_number                   ; Sprite from A
    tya                                 ; Row = Y + this hero's panel row - 14...
    ldx panel_hero                      ; ...for the hero being drawn...
    clc                                 ; ...(carry clear for the add)
    adc workspace_template + 208,x      ; ...(read from workspace_template, which page &0D copies)
    sec                                 ; ...(no borrow into the subtract)
    sbc #&0e                            ; ...less 14: row 0 is 14 above the health
    sta plot_y                          ; ...is the plot row
    jsr plot_sprite                     ; Plot the sprite in the hero's section
    rts                                 ; Return; plot_sprite leaves X and Y 0
    equb &00, &09, &60                  ; Not referenced
; Starting hero_max_missiles for each hero: 3, 2, 1, 2.
; ***************************************************************************************
; Heroes' starting attributes
;
; Four tables of one byte per hero (Ranger, Magic-User, Barbarian, Fighter): missiles in
; flight, missile damage, health lost per hit, and the face sprite for the panel.
.hero_start_max_missiles
    equb &03, &02, &01, &02
; Starting hero_missile_damage for each hero: 2, 3, 9, 5.
.hero_start_missile_damage
    equb &02, &03, &09, &05
; Starting hero_damage_taken for each hero: 7, 9, 6, 4 (armour ratings 3, 1, 4, 6).
.hero_start_damage_taken
    equb &07, &09, &06, &04
; Sprite shown for each hero at the top left of their status panel section, plotted by draw_status_panel: &05, &31, &39, &41.
.hero_faces
    equb &05, &31, &39, &41
; ***************************************************************************************
; Game-over message
;
; Eleven lines of seventeen characters, each ended by a carriage return, then a line feed
; and a last line ended by a zero byte. Two bytes of it (&0FF1, &0FF2) double as
; counters, and are overwritten with spaces before printing, so the full stop after "YOU
; ALL" never appears.
; The message printed when every hero has died, terminated by a zero byte.
.game_over_message
    equs "FAREWELL!        ", &0d
    equs "THE QUEST HAS    ", &0d
    equs "FAILED AND THE   ", &0d
    equs "GODS ARE IN NO   ", &0d
    equs "MOOD TO RESURRECT", &0d
; The "YOU ALL." line of game_over_message, whose bytes after the text double as panel_hero and count.
.game_over_you_all
; Hero counter for draw_status_panel. It is the full stop of game_over_message's "YOU ALL.", which is overwritten with a space before the message is printed.
panel_hero = game_over_you_all+7
; Counter, used for the dead heroes at the end of a level and the rows of missile icons. It is a byte of game_over_message.
count = game_over_you_all+8
    equs "YOU ALL.         ", &0d
    equs "NEW ADVENTURERS  ", &0d
    equs "MUST TAKE YOUR   ", &0d
    equs "PLACE,BEGINNING  ", &0d
    equs "BACK ON THE UPPER", &0d
    equs "MOST LEVEL.      ", &0d
    equb &0a                            ; Line feed: a blank line
    equs "FIND THE CHALICE!", &00
; ***************************************************************************************
; Unused
;
; Leftover bytes: "ND!" and a zero, the end of an earlier message, then "&C2".
    equb &4e, &44, &21, &00, &26, &43, &32  ; Not referenced
