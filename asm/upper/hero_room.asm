; ***************************************************************************************
; Show the room a hero has moved into
;
; Make hero X's view show the room they are now in, and redraw that view's walls and
; doors. move_heroes calls this when a hero steps into another room, and a teleporter
; jumps here after moving the hero.
;
; Each hero has a fixed view (0 top left to 3 bottom right). test_wall is called on the
; hero's cell only for the room offset it leaves in map_ptr; that becomes the low byte of
; the view's view_room entry (view_room + 2 x hero), the pointer into room_walls that
; draw_view_0 to draw_view_3 and plot_at_cell read; the high byte never changes. The
; matching draw_view_n then draws the room's walls and doors. Creatures and objects
; appear in the new view as they are next plotted.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     X: preserved
.show_hero_room
    lda hero_x,x                        ; The hero's cell, for test_wall to find its room
    sta cell_x                          ; ...as cell_x for test_wall...
    lda hero_y,x                        ; ...and its map y...
    sta cell_y                          ; ...as cell_y for test_wall
    txa                                 ; Keep the hero...
    pha                                 ; ...on the stack: test_wall corrupts X
    jsr test_wall                       ; Only for map_ptr: the offset of the cell's room
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, to pick their view
    pha                                 ; Keep the hero number across the view draw
    asl a                               ; Hero x 2: their view's entry in view_room...
    tay                                 ; ...two bytes, a pointer into room_walls
    lda map_ptr                         ; The room's offset that test_wall left...
    sta view_room,y                     ; ...becomes the view's room
; Redraw the hero's own view, which is fixed by hero number.
    cpx #0                              ; Redraw this hero's own view: hero 0's?
    bne check_view_1                    ; No: try hero 1
    jsr draw_view_0                     ; Hero 0: redraw the top-left view
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Ranger's view redrawn
.check_view_1
    cpx #1                              ; Hero 1, the top-right view?
    bne check_view_2                    ; No: try hero 2
    jsr draw_view_1                     ; Yes: redraw it
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Magic-User's view redrawn
.check_view_2
    cpx #2                              ; Hero 2, the bottom-left view?
    bne show_view_3                     ; No: hero 3
    jsr draw_view_2                     ; Yes: redraw it
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Barbarian's view redrawn
.show_view_3
    jsr draw_view_3                     ; Hero 3: redraw the bottom-right view
    pla                                 ; Recover the hero...
    tax                                 ; ...into X, as the caller had it
    rts                                 ; Return with the Fighter's view redrawn
; Magic sword: one more damage for each missile the hero fires from now on, to at most 9, and the panel's damage digit redrawn. Missiles already in flight keep their damage.
.magic_sword
    inc hero_missile_damage,x           ; Magic sword: one more damage per missile...
    lda hero_missile_damage,x           ; ...and look at it
    cmp #&0a                            ; ...past 9, the most?
    bne draw_missile_damage             ; No: draw the new damage in the panel
    lda #9                              ; Yes: back to 9...
    sta hero_missile_damage,x           ; ...as the missile damage
    bne draw_missile_damage             ; ...and draw it (always taken)
; A missile has hit a live monster: X is the monster, Y the missile slot. Reached by JMP from move_missiles, and leaves by jumping back into it. Every hit makes the hit sound. The missile's damage is taken from the monster's hit points; below 0 kills it (0 survives), and the kill is scored by monster_killed. Either way the missile is spent.
.monster_hit
    txa                                 ; Hit: sound the blow
    pha                                 ; Keep the monster...
    tya                                 ; ...and the missile slot...
    pha                                 ; ...across the OSWORD call
    ldx #<(hit_sound)                   ; XY = hit_sound, at pitch 6...
    ldy #>(hit_sound)                   ; ...the block in page &0C...
    lda #osword_sound                   ; ...OSWORD 7, SOUND
    jsr osword                          ; Sound the blow:  SOUND command
    pla                                 ; Recover the missile slot...
    tay                                 ; ...into Y, for its damage...
    pla                                 ; ...and the monster...
    tax                                 ; ...into X, for its hit points
    lda monster_hit_points,x            ; The monster's hit points...
    sec                                 ; ...set the carry for the subtraction...
    sbc missile_damage,y                ; ...less this missile's damage
    bpl store_monster_health            ; 0 or more: alive (0 hit points survives a hit)
; Killed: the monster's sprite becomes the blank, from which update_monsters runs the sparkles, and its slot is given this level's starting hit points for when it comes back at a trapdoor.
    lda #spr_blank                      ; Below 0: killed. Start it dying...
    sta monster_sprite,x                ; ...from the blank sprite through the sparkles
    lda monster_start_hit_points        ; ...and give the slot this level's hit points...
    sta monster_hit_points,x            ; ...ready for when it comes back at a trapdoor
    tya                                 ; Missile slot back in X...
    tax                                 ; ...as monster_killed expects
    jmp monster_killed                  ; ...a point to its hero, and the missile is spent
.store_monster_health
    sta monster_hit_points,x            ; Alive: store the hit points left
    tya                                 ; Push the missile slot, as missile_spent_pop...
    pha                                 ; ...expects to find it on the stack
    jmp missile_spent_pop               ; The missile is spent: one hit per missile
; Redraw hero X's armour rating after a magic helmet: the small digit 10 - hero_damage_taken (at most 7) on the shield in their panel section, twelve rows above the health. Jumped to from collect_objects; returns to its caller with X kept.
.draw_armour_rating
    sec                                 ; Armour rating = 10 - health lost per hit, drawn...
    lda hero_panel_y,x                  ; ...on the shield: the hero's panel row...
    sbc #&0c                            ; ...less twelve pixel rows...
    sta plot_y                          ; ...as the plotting row
    lda #panel_left + 9                 ; ...byte column &4E, nine right of the panel's left...
    sta plot_x                          ; ...as the plotting column
    lda #spr_small_digit_1 + 9          ; Small digit 10...
    sec                                 ; ...set the carry for the subtraction...
    sbc hero_damage_taken,x             ; ...less the health lost per hit: 1 to 7
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; Plot it, keeping X, and return
; Add the icon for hero X's newest missile after a pile of weapons, at the row draw_status_panel would give it (icon n at its row &0D + 3n, which plot_panel_sprite offsets by the panel row - &0E). Icons are only added: with 3 already allowed the third is drawn again. Jumped to from collect_objects; returns with X kept.
.draw_new_missile_icon
    lda hero_max_missiles,x             ; Icon for the newest missile allowed: missiles x 2...
    asl a                               ; ...(x 2)...
    clc                                 ; ...clear the carry for the addition...
    adc hero_max_missiles,x             ; ...+ missiles again: 3 rows per icon...
    adc #&0d                            ; ...+ &0D, as in draw_status_panel's icon rows...
    adc hero_panel_y,x                  ; ...+ the hero's panel row...
    sec                                 ; ...set the carry for the subtraction...
    sbc #&0e                            ; ...- &0E, plot_panel_sprite's bias: the same row
    sta plot_y                          ; ...as the plotting row
    lda #panel_left + 6                 ; ...byte column &4B, the icons' column...
    sta plot_x                          ; ...as the plotting column
    lda #spr_missile_icon               ; The missile icon...
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; Plot it, keeping X, and return
; Redraw hero X's missile damage after a magic sword, as a small digit (1-9) four rows above their panel row. Jumped to from collect_objects; returns with X kept.
.draw_missile_damage
    lda #panel_left + 7                 ; Missile damage: byte column &4C...
    sta plot_x                          ; ...as the plotting column
    sec                                 ; ...set the carry for the subtraction...
    lda hero_panel_y,x                  ; ...the hero's panel row...
    sbc #4                              ; ...less four pixel rows...
    sta plot_y                          ; ...as the plotting row
    lda hero_missile_damage,x           ; The damage, 1-9...
    clc                                 ; ...clear the carry for the addition...
    adc #spr_small_digit_1 - 1          ; ...+ one before small digit 1: its small digit
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; Plot it, keeping X, and return
; ***************************************************************************************
; Set the position of a hero's boots icon
;
; Set plot_x to the panel's column &4A and plot_y to eight pixel rows above hero X's
; panel row (hero_panel_y), where the lightning bolt shows that the hero wears Boots of
; Speed. collect_objects calls it before plot_boots_icon, when boots are picked up, and
; before erase_boots_icon, when any object is found under the hero.
;
; On Entry:
;     X: hero number (0-3)
;
; On Exit:
;     PLOT_X: &4A
;     PLOT_Y: hero_panel_y - 8
;     X: preserved
.point_at_boots_icon
    lda #panel_left + 5                 ; The bolt's byte column, &4A...
    sta plot_x                          ; ...as the plotting column
    sec                                 ; ...set the carry for the subtraction...
    lda hero_panel_y,x                  ; ...the hero's panel row...
    sbc #8                              ; ...8 rows above the hero's panel section
    sta plot_y                          ; ...as the icon's pixel row
    rts                                 ; Return with plot_x, plot_y at the hero's boots icon
; ***************************************************************************************
; Show a hero's boots icon
;
; Plot the lightning bolt at plot_x, plot_y, where point_at_boots_icon has just pointed,
; to show that hero X now wears Boots of Speed. Called when the boots are picked up. The
; plot goes through plot_keeping_x, which keeps the hero number across plot_sprite (which
; leaves X = 0).
;
; On Entry:
;     X: hero number (0-3)
;     PLOT_X: the icon's byte column
;     PLOT_Y: the icon's pixel row
;
; On Exit:
;     X: preserved
.plot_boots_icon
    lda #spr_boots_icon                 ; The lightning bolt: the hero has Boots of Speed...
    sta sprite_number                   ; ...as the sprite to plot
    jmp plot_keeping_x                  ; ...plotted where point_at_boots_icon pointed
; ***************************************************************************************
; Remove a hero's boots icon
;
; Plot the blank boots sprite over the lightning bolt at plot_x, plot_y, where
; point_at_boots_icon has just pointed. collect_objects calls this whenever a hero finds
; any object, since every find takes the boots off. Falls into plot_keeping_x.
;
; On Entry:
;     X: hero number (0-3)
;     PLOT_X: the icon's byte column
;     PLOT_Y: the icon's pixel row
;
; On Exit:
;     X: preserved
.erase_boots_icon
    lda #spr_blank_boots_icon           ; The blank: the boots are lost...
    sta sprite_number                   ; ...as the sprite to plot
.plot_keeping_x
    txa                                 ; Keep the hero number...
    pha                                 ; ...on the stack: plot_sprite leaves X = 0
    jsr plot_sprite                     ; Plot the icon in the hero's panel section
    pla                                 ; Recover the hero number...
    tax                                 ; ...in X again for the caller
    rts                                 ; Return with X = the hero again
