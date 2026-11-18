<!-- Generated from README.md.j2 by dr-build: edit that, not this. -->
# Dunjunz Revised

![The Dunjunz Revised title screen](docs/title-screen.gif)

**Dunjunz Revised**: a revised version of *Dunjunz*, the
four-player dungeon game by Julian Avis, published by Bug-Byte for the BBC
Micro in 1986 (cassette) and 1987 (disc).

The game is unchanged in spirit. The revision fixes bugs, keeps the game
resident instead of resetting the machine between levels, and loads
through whatever filing system is in use (DFS 0.90 to 2.2x, NFS and ANFS
over Econet), from a single disc. See [docs/plan.md](docs/plan.md).

## Provenance

The starting point is the Model B side of the official 1987 flippy disc,
as reassembled and annotated in the
[acornaeology Dunjunz disassembly](https://github.com/acornaeology/dunjunz).
`asm/original/` holds that reassembly, taken at acornaeology/dunjunz
commit `fd674e9`. The build checks it byte-for-byte against the original
files in `reference/disc/`. Every change from the original game is in this
repository's history.

This is not an official release, and it is not one of the earlier
unofficial versions (Ole's crack of the cassette, or the sideways RAM
hack). Every disc and title screen it builds says "Dunjunz Revised" and
its version.

## Credits and copyright

*Dunjunz* was written by Julian Avis and is copyright © Bug-Byte 1986.

The annotations and the revisions are copyright © Robert Smallshire.

This repository has no licence, deliberately. The revised game is
intertwined with the original program, which is copyright, so the default
copyright law applies to the whole repository. If the copyright holders
object to it being available, it will be taken down.

## Building

Requires [uv](https://docs.astral.sh/uv/) and
[beebasm](https://github.com/stardot/beebasm) 1.10 or later on the PATH.

```sh
uv sync
uv run dr-build        # build/dunjunz-revised-v<version>.ssd and .adl, and build/dunjunz-original.ssd (the 1987 baseline)
uv run pytest          # tests, in the beebium emulator
```

## Running it

Boot `dunjunz-revised-v<version>.ssd` (DFS, any BBC Micro) or
`dunjunz-revised-v<version>.adl` (ADFS, a Master or a Master Compact) with
SHIFT-BREAK, or copy the files to any filing system (a network file server
included) and `*RUN DUNJUNZ`. The game needs PAGE at &1C00 or below.
`*TYPE README` on either disc shows its version, how to play, and the
copyright notice; the disc titles carry the version too.

## Playing it

Up to four players share the keyboard, or play with joysticks: up to four
through SPItFIRE on a Master Compact, otherwise two on the analogue port
(or a Compact's own joystick port).

On the title, press 1-4 for the number of players sharing the keyboard, or
fire on a joystick if everyone plays with a stick. Any other key gives four
keyboard players, with the 1987 keys. Each player at the keyboard has a set
of keys, KEY1 to KEY4, from the layout for that many players, shown before
the game loads.

On the hero menu, every player joins by pressing fire, on their joystick or
their set of keys. A press takes the first free hero, and each further press
moves on to the next, past the Fighter to nobody, so any set of keys can
play any hero. The menu shows KEY1-KEY4 or JOY1-JOY4 against each hero who
plays. 5 and 6 turn the sound on and off, and RETURN starts the game.

### One player at the keyboard

| Keys | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| KEY1 | K | M | Z | X | L | SPACE |

### Two players at the keyboard

| Keys | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| KEY1 | R | D | A | S | T | C |
| KEY2 | K | M | B | N | ; | SPACE |

### Three players at the keyboard

| Keys | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| KEY1 | → | ↑ | DELETE | COPY | ↓ | RETURN |
| KEY2 | K | , | . | / | SPACE | L |
| KEY3 | G | B | U | I | O | J |

### Four players at the keyboard

| Keys | Up | Down | Left | Right | Fire | Magic |
|---|---|---|---|---|---|---|
| KEY1 | CAPS LOCK | SHIFT LOCK | SHIFT | Z | TAB | CTRL |
| KEY2 | → | ↑ | DELETE | COPY | ↓ | RETURN |
| KEY3 | K | , | . | / | SPACE | L |
| KEY4 | G | B | U | I | O | J |

The layout for four players is the 1987 keys, each set one 1987 hero's:
KEY1 the Ranger's, KEY2 the Magic-User's, KEY3 the Barbarian's and KEY4 the
Fighter's, with magic keys added for the last two, as any set can now play
the heroes with magic. The Magic-User's arrow keys don't move the way they
are labelled: → moves up and ↑ moves down, as in 1987. The layout for three
players is the same without the Ranger's set.

Only the Ranger and the Magic-User can cast magic. P pauses and resumes the
game; holding ESCAPE for half a second ends it. On a joystick, fire and a
direction held together for half a second cast magic.

When the game ends, R plays again at once with the same heroes, keys and
joysticks, skipping the title and the hero menu: within ten seconds of game
over, or as the key after the victory's ending. Any other key, or none,
goes back to the title.
