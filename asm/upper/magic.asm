; ***************************************************************************************
; Cast a hero's magic if their key is held
;
; Let the Ranger or the Magic-User cast magic, which kills every live monster in the room
; they are in. move_heroes jumps here (JMP, not JSR) for heroes 0 and 1 when they stand
; in a cell, before reading their other keys.
;
; hero_magic_delay is counted down first. It normally stands at 1, so the magic key
; (hero_magic_key) is scanned every frame; while it is not yet zero the RTS here returns
; from move_heroes itself, so neither this hero nor those after it move that frame.
; Without the key held, play goes on to read_hero_keys. With it held, the magic sound
; plays, the delay is set to 4 (three frozen frames follow) and the cost is taken one
; health point at a time: 6 for the Ranger, 3 for the Magic-User, which can kill the
; caster. Then every monster whose cell lies in the room the caster's view shows, and
; whose sprite is below the blank (alive), is given the blank sprite, the first frame of
; a death that update_monsters plays out, and the caster scores a point for each, through
; add_point, even if the cost has just killed them. Unlike a missile's kill, the magic
; does not reset the monster's hit points, so a monster wounded before comes back from
; its trapdoor still wounded. The caster does not move that frame: play goes on at
; draw_moved_hero, which draws them if still in play.
;
; On Entry:
;     X: hero number (0 or 1)
.check_magic
    dec hero_magic_delay,x              ; Count down this hero's magic key delay
    beq read_magic_key                  ; Zero: time to look at the magic key
    jmp read_hero_keys                  ; Not yet: on with the hero's other keys
.read_magic_key
    lda #1                              ; Delay 1: the key is read every frame from now on
    sta hero_magic_delay,x              ; ...so the next press is seen at once
    lda hero_magic_key,x                ; This hero's magic key, an INKEY number...
    jsr test_key                        ; ...scanned: Z set if held
    beq cast_magic                      ; Held: cast
    jmp read_hero_keys                  ; Not held: read the movement and fire keys
.cast_magic
; Cast the magic: play its sound, take the caster's health, then kill every live monster in the room the caster's view shows, a point each.
    txa                                 ; Held: cast. Keep the hero number...
    pha                                 ; ...on the stack: X carries the OSWORD blocks
    ldx #<(magic_envelope)              ; XY = magic_envelope, an OSWORD 8 block...
    ldy #>(magic_envelope)              ; ...and its page
    lda #osword_envelope                ; OSWORD 8: define the magic envelope
    jsr osword                          ; ENVELOPE command
    ldx #<(magic_sound)                 ; XY = magic_sound, an OSWORD 7 block...
    ldy #>(magic_sound)                 ; ...and its page
    lda #osword_sound                   ; OSWORD 7: make the magic sound
    jsr osword                          ; SOUND command
    pla                                 ; Recover the hero number...
    tax                                 ; ...the caster, in X again
; Hold off the key for three frames, then take the cost, 6 health for the Ranger and 3 for the Magic-User, a point at a time through lose_health_point. The caster may die of it; the spell still goes on.
    lda #4                              ; Ignore the key for the next three frames
    sta hero_magic_delay,x              ; ...so one press casts only once
    cpx #1                              ; Health cost: 3 for the Magic-User...
    beq magic_user_cost                 ; Magic-User (hero 1): the cheaper rate
    ldy #6                              ; ...6 for the Ranger
    jmp take_magic_cost                 ; Ranger: go and take 6 points
.magic_user_cost
    ldy #3                              ; Magic-User: 3 points
.take_magic_cost
    tya                                 ; Pay the cost one health point at a time
    pha                                 ; ...the points left on the stack
    jsr lose_health_point               ; One point off the caster, redrawn (it can kill them)
    pla                                 ; Recover the points left...
    tay                                 ; ...back in Y
    dey                                 ; One point fewer to take
    bne take_magic_cost                 ; Until the whole cost is paid
    lda #0                              ; No monsters killed yet:
    sta magic_kill_count                ; ...magic_kill_count counts this cast's kills
    txa                                 ; The caster's view_room index, 2 x hero...
    asl a                               ; ...x 2: view_room holds two bytes per hero
    sta sprite_number                   ; ...kept in sprite_number, free as scratch here
; Kill every live monster in the caster's room. A monster parked off the map (&FF) is in no room and survives. The kill only sets the first death frame; hit points are left as they are.
    ldx #max_monster                    ; For each monster, 30 to 1...
.check_magic_monster
    lda monster_x,x                     ; ...find its room from its cell: map x...
    sta cell_x                          ; ...as cell_x for test_wall...
    lda monster_y,x                     ; ...and map y...
    sta cell_y                          ; ...as cell_y; the wall bit is not wanted
    txa                                 ; Keep the monster number...
    pha                                 ; ...on the stack across test_wall
    jsr test_wall                       ; test_wall leaves the monster's room in map_ptr
    pla                                 ; Recover the monster number...
    tax                                 ; ...back in X
    ldy sprite_number                   ; Y = the caster's view_room index
    lda view_room,y                     ; The room the caster's view shows...
    cmp map_ptr                         ; ...is it the monster's room?
    bne next_monster_magic              ; Another room: the monster is spared
    lda monster_sprite,x                ; Alive? (dying ones are sprite &15 up)
    cmp #spr_blank                      ; Below the first death frame: alive
    bcs next_monster_magic              ; Already dying: not counted again
    lda #spr_blank                      ; Alive: the first death frame, &15...
    sta monster_sprite,x                ; ...and update_monsters plays out its death
    lda monster_start_hit_points        ; Its hit points back to the level's full strength...
    sta monster_hit_points,x            ; ...as a missile kill gives it, for when it returns
    inc magic_kill_count                ; ...a kill to score
.next_monster_magic
    dex                                 ; Next monster down
    bne check_magic_monster             ; Until monster 1 is done
; Score a point for each kill, to the caster, through add_point.
    lda sprite_number                   ; One point for each monster killed
    lsr a                               ; ...halve the view_room index back to the hero
    tax                                 ; ...X = the caster, who scores the points
    ldy magic_kill_count                ; ...Y = the monsters killed
.score_magic_kills
    cpy #0                              ; Any kills left to score?
    beq magic_cast                      ; None left: redraw the caster
    tya                                 ; Keep the kills left...
    pha                                 ; ...on the stack across add_point
    jsr add_point                       ; One point to the caster
    pla                                 ; Recover the kills left...
    tay                                 ; ...back in Y
    dey                                 ; One kill fewer to score
    jmp score_magic_kills               ; Score the next
.magic_cast
    jmp draw_moved_hero                 ; Cast: no move this frame; redraw the caster
; ***************************************************************************************
; Give a point to the hero who fired a missile
;
; Score one point for the hero whose missile is in slot X. move_missiles calls this when
; a missile kills a monster (through monster_killed) and when it wears down an energy
; drainer. The firer is told by the missile's sprite base, as in flip_firer_frame: arrows
; the Ranger, fireballs the Magic-User, axes the Barbarian, and anything else the
; Fighter. add_point adds the point and redraws the score, whether or not the firer is
; still in play.
;
; On Entry:
;     X: missile slot (0-11)
;
; On Exit:
;     A: corrupted
;     X: preserved
;     Y: corrupted
.credit_missile_owner
    ldy missile_sprite_base,x           ; Which hero fired it? Its sprite base says
    txa                                 ; Keep the missile slot...
    pha                                 ; ...on the stack: X becomes the hero
    tya                                 ; The sprite base, to compare
    cmp #spr_arrow_up - 1               ; ...the arrows' base, one below the up arrow?
    bne owner_fireball                  ; Not arrows: try fireballs
    ldx #0                              ; Arrows: the Ranger, hero 0
    jmp credit_owner                    ; Credit the Ranger
.owner_fireball
    cmp #spr_fireball_up - 1            ; ...the fireballs' base?
    bne owner_axe                       ; Not fireballs: try axes
    ldx #1                              ; Fireballs: the Magic-User, hero 1
    jmp credit_owner                    ; Credit the Magic-User
.owner_axe
    cmp #spr_axe_up - 1                 ; ...the axes' base?
    bne owner_sword                     ; Not axes: so it must be swords
    ldx #2                              ; Axes: the Barbarian, hero 2
    jmp credit_owner                    ; Credit the Barbarian
.owner_sword
    ldx #3                              ; Otherwise swords: the Fighter, hero 3
.credit_owner
    jsr add_point                       ; One point to the firer's score
    pla                                 ; Recover the missile slot...
    tax                                 ; ...in X again for move_missiles
    rts                                 ; Return with X = the missile slot again
