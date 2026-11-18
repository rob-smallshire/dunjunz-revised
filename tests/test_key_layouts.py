"""The keyboard layouts (tools/dunjunz_revised/key_layouts.py): what they
hold, and that the keys of the set a player joins with reach their hero.

A layout's keys must all differ, none may be one the hero menu or play reads
for itself, and the layouts for one and two players must not let keys that
players hold together make a phantom of a key the game reads (see
docs/enhancements.md). The 4-player layout is the 1987 keys.
"""

from __future__ import annotations

import re
from itertools import product

import pytest

from dunjunz_revised.build import ASM_DIRPATH, REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, hero_keys, read_labels
from dunjunz_revised.disc_files import key_name
from dunjunz_revised.key_layouts import (
    ACTIONS,
    LAYOUTS,
    LAYOUTS_ASM_FILEPATH,
    MENU_KEYS,
    SLOT_ORDER,
    layouts_asm,
)
from dunjunz_revised.lockstep import RETURN, answer_title, hold_key, inkey_to_matrix
from dunjunz_revised.machines import MACHINES, launched
from dunjunz_revised.sixtyfive import GameImage

PLAY_KEYS = ("p", "escape")                 # pause, and ESCAPE held to end the game
INKEY = {name: int(value, 16) for name, value in
         re.findall(r"^inkey_key_(\w+)\s*=\s*&([0-9a-f]{2})", (ASM_DIRPATH / "defs" / "constants.asm").read_text(), re.M)}
DIRECTIONS = ("up", "down", "left", "right")


def matrix(key: str) -> tuple[int, int]:
    """A key's row and column in the keyboard matrix, from its INKEY number."""
    internal = INKEY[key] ^ 0xFF
    return internal >> 4, internal & 0x0F


def phantoms(held: set[str]) -> set[tuple[int, int]]:
    """The places in the matrix that read as held, besides the keys held, if
    the keyboard ghosts: the fourth corner of any rectangle of three."""
    places = {matrix(key) for key in held}
    return {(row_b, column_a)
            for row_a, column_a in places for row_b, column_b in places
            if row_a != row_b and column_a != column_b
            and (row_a, column_b) in places and (row_b, column_a) not in places}


def held_together(sets):
    """What players hold together in play: each a direction and fire; or one
    their magic key while the others move and fire."""
    for directions in product(*[[keys[d] for d in DIRECTIONS] for keys in sets]):
        yield set(directions) | {keys["fire"] for keys in sets}
    for caster, casting in enumerate(sets):
        others = [keys for index, keys in enumerate(sets) if index != caster]
        for directions in product(*[[keys[d] for d in DIRECTIONS] for keys in others]):
            yield set(directions) | {keys["fire"] for keys in others} | {casting["magic"]}


def test_the_generated_layouts_are_up_to_date():
    assert LAYOUTS_ASM_FILEPATH.read_text() == layouts_asm()


@pytest.mark.parametrize("players", sorted(LAYOUTS))
def test_a_layout_has_a_set_for_each_player_and_no_key_twice(players):
    sets = LAYOUTS[players]
    assert len(sets) == players
    keys = [keys[action] for keys in sets for action in ACTIONS]
    assert len(keys) == len(set(keys))
    assert all(key in INKEY for key in keys)


@pytest.mark.parametrize("players", sorted(LAYOUTS))
def test_no_set_fires_with_a_menu_key_or_uses_a_play_key(players):
    for keys in LAYOUTS[players]:
        assert keys["fire"] not in MENU_KEYS
        assert not set(keys.values()) & set(PLAY_KEYS)


@pytest.mark.parametrize("players", [1, 2])
def test_keys_held_together_make_no_phantom_of_a_game_key(players):
    sets = LAYOUTS[players]
    game_keys = {matrix(key) for keys in sets for key in keys.values()} | {matrix(key) for key in PLAY_KEYS}
    for held in held_together(sets):
        assert not phantoms(held) & game_keys, sorted(held)


def test_the_4_player_layout_is_the_1987_keys(disc_filepaths):
    """Each 1987 hero's keys, as the built game's template and hero_magic_key
    hold them, are the set of the same number in the 4-player layout."""
    for (hero, keys), layout_set in zip(hero_keys(REVISED_BUILD_DIRPATH), LAYOUTS[4]):
        assert keys == {action: key_name(layout_set[action]) for action in keys}, hero


def test_a_hero_on_a_stick_does_not_answer_the_keyboard(disc_filepaths):
    """test_key does not read the keyboard for a hero on a stick, so another
    player's keys cannot move them; it returns before calling the MOS."""
    image = GameImage.revised()
    image.poke(image.address("hero_stick"), bytes([0, 1, 2, 3]))
    image.poke(image.address("control_bits"), bytes(4))
    image.call("test_key", a=INKEY["k"], x=2, y=1)
    assert image.mpu.a == 1                             # not held
    image.poke(image.address("control_bits+2"), bytes([1]))
    image.call("test_key", a=INKEY["k"], x=2, y=1)
    assert image.mpu.a == 0                             # held, on the stick


@pytest.mark.parametrize("players, joins", [(1, [(0, 0)]), (2, [(0, 0), (1, 1)]), (2, [(1, 0), (0, 1)])])
def test_a_sets_keys_reach_the_hero_it_joins(disc_filepaths, players, joins):
    """Choose the number of keyboard players on the title, join heroes with
    sets' fire keys (each (set, hero): a set takes the first free hero), and
    the heroes play with their sets' keys."""
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    title_key = inkey_to_matrix({1: 0xCF, 2: 0xCE, 3: 0xEE, 4: 0xED}[players])
    with launched(MACHINES["dfs226"]) as bbc:
        bbc.boot_disc(REVISED_DISC_FILEPATH)
        bbc.run_for_emulated_seconds(8)
        answer_title(bbc, title_key)
        bbc.debugger.run_to(labels["menu_key_loop"], timeout=120)
        bbc.run_for_emulated_seconds(0.5)
        for set_index, _ in joins:
            fire = inkey_to_matrix(INKEY[LAYOUTS[players][set_index]["fire"]])
            bbc.keyboard.matrix_down(*fire)
            bbc.run_for_emulated_seconds(0.6)
            bbc.keyboard.matrix_up(*fire)
            bbc.run_for_emulated_seconds(0.4)
        hold_key(bbc, *RETURN, seconds=0.3)
        bbc.debugger.run_to(labels["update_game"], timeout=120)
        peek = bbc.memory.address.peek
        for set_index, hero in joins:
            keys = LAYOUTS[players][set_index]
            slots = [peek[labels[f"hero_key_{action}"] + hero] for action in SLOT_ORDER[:5]]
            assert slots == [INKEY[keys[action]] for action in SLOT_ORDER[:5]], (set_index, hero)
            if hero < 2:
                assert peek[labels["hero_magic_key"] + hero] == INKEY[keys["magic"]]
