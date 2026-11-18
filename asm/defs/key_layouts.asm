; ***************************************************************************************
; The keyboard layouts
;
; Written by tools/dunjunz_revised/key_layouts.py, where the layouts are kept; do not edit.
; Each macro emits one table, where it is used.

; The fire key of set S (0-3) of the layout for N players (1-4), at 4 S + N - 1; 0 where
; the layout has no set S. The hero menu polls these (poll_key_sets).
MACRO KEY_LAYOUT_FIRE_KEYS
    equb inkey_key_l, inkey_key_t, inkey_key_down, inkey_key_tab  ; Set 1, in the layouts for 1-4 players
    equb 0, inkey_key_semicolon, inkey_key_space, inkey_key_down  ; Set 2, in the layouts for 1-4 players
    equb 0, 0, inkey_key_o, inkey_key_space  ; Set 3, in the layouts for 1-4 players
    equb 0, 0, 0, inkey_key_o  ; Set 4, in the layouts for 1-4 players
ENDMACRO

; Set S (0-3) of the layout for N players (1-4), at 6 (4 (N - 1) + S): the up, down,
; right, left and fire keys, in the order of the hero key tables (hero_key_up to
; hero_key_fire), then magic; 0s where the layout has no set S. Setup copies a hero's
; set into their slots (apply_key_sets).
KEY_SET_BYTES = 6
MACRO KEY_LAYOUT_SETS
    equb inkey_key_k, inkey_key_m, inkey_key_x, inkey_key_z, inkey_key_l, inkey_key_space  ; 1 player, set 1
    equb 0, 0, 0, 0, 0, 0  ; 1 player: no set 2
    equb 0, 0, 0, 0, 0, 0  ; 1 player: no set 3
    equb 0, 0, 0, 0, 0, 0  ; 1 player: no set 4
    equb inkey_key_r, inkey_key_d, inkey_key_s, inkey_key_a, inkey_key_t, inkey_key_c  ; 2 players, set 1
    equb inkey_key_k, inkey_key_m, inkey_key_n, inkey_key_b, inkey_key_semicolon, inkey_key_space  ; 2 players, set 2
    equb 0, 0, 0, 0, 0, 0  ; 2 players: no set 3
    equb 0, 0, 0, 0, 0, 0  ; 2 players: no set 4
    equb inkey_key_right, inkey_key_up, inkey_key_copy, inkey_key_delete, inkey_key_down, inkey_key_return  ; 3 players, set 1
    equb inkey_key_k, inkey_key_comma, inkey_key_slash, inkey_key_full_stop, inkey_key_space, inkey_key_l  ; 3 players, set 2
    equb inkey_key_g, inkey_key_b, inkey_key_i, inkey_key_u, inkey_key_o, inkey_key_j  ; 3 players, set 3
    equb 0, 0, 0, 0, 0, 0  ; 3 players: no set 4
    equb inkey_key_caps_lock, inkey_key_shift_lock, inkey_key_z, inkey_key_shift, inkey_key_tab, inkey_key_ctrl  ; 4 players, set 1
    equb inkey_key_right, inkey_key_up, inkey_key_copy, inkey_key_delete, inkey_key_down, inkey_key_return  ; 4 players, set 2
    equb inkey_key_k, inkey_key_comma, inkey_key_slash, inkey_key_full_stop, inkey_key_space, inkey_key_l  ; 4 players, set 3
    equb inkey_key_g, inkey_key_b, inkey_key_i, inkey_key_u, inkey_key_o, inkey_key_j  ; 4 players, set 4
ENDMACRO
