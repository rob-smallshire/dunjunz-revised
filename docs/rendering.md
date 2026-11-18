# Rendering

How the revision draws the play screen, and why. This replaces the 1987
scheme, in which each part of the game plotted as it went. Work in
progress: the steps at the end say how far it has got.

## What was wrong

In 1987, drawing is a side effect of play. The heroes, the doors, the keys,
the missiles and the monsters each rub themselves out and plot themselves
again as they are moved, in that order, and the objects and keys are
plotted again every frame. Every sprite is plotted solid: its black pixels
erase whatever was there. So a cell that two of them touch passes through
in-between pictures during a frame: the floor without the hero, the hero
without the key. Some of these were plotted only every other frame (a dead
hero's skull), so they flickered steadily. Others show only when the raster
happens to pass the cell between the two plots, so they flicker now and
then. Patching the order of the plots moved the flicker about, but could
not remove it (see the parked `see-through` branch).

Measured in beebium over 100 frames of scripted play with four heroes:

| | Frame (median cycles) | In `plot_sprite` | Calls a frame | Cycles a call |
|---|---|---|---|---|
| 1987 | 160,870 | 110,371 (69%) | 40 | 2,763 |
| Revised (2026.3) | 161,760 | 110,807 (69%) | 40 | 2,811 |

Over 300 frames the 1987 median is about 133,000 cycles. `play_level`
starts a frame every three vsyncs (120,000 cycles at 2 MHz), but most frames
take longer, so the game's speed is set by its work: busy rooms play slower.
More than two thirds of that work is `plot_sprite`, a general routine that
steps two 16-bit pointers for every byte.

## What it should be

1. **Play and drawing apart.** All of the game's logic runs as it does now,
   in the same order, with every plot taken out. No logic reads the screen
   (checked: only the plotter does), so play cannot change, and the state
   comparisons with 1987 stay exact.
2. **The picture follows from the state.** Each cell of each view shows its
   layers, back to front, each but the first see-through (its black shows
   what is under it):
   1. the floor: blank, a trapdoor or an object;
   2. a hero out of play: their sparkles or skull;
   3. the keys there (a stack of keys looks like one);
   4. the creatures over the cell: heroes in play (Ranger to Fighter), then
      missiles, then monsters, as 1987 plotted them;
   5. an energy drainer, drawn again over a hero standing on it, kept on
      purpose as a warning.

   Walls and doors are drawn with the view, as now.
3. **One render pass a frame, after play.** What each creature shows (its
   sprite, cell and offsets) is compared with what was drawn last frame, and
   the floor items with where they were. The cells under any change, old
   place and new, are marked dirty, and so are the cells of any creature
   that overlaps a dirty cell, until no more are added. Each dirty cell is
   then drawn, layer by layer, in every view that shows it. Cells that did
   not change are not touched. Each cell goes from its old picture to its
   new one in one go, so nothing can flicker. A frame's drawing then costs
   what changed, not what is on show.
4. **A steady frame rate.** With drawing cheaper, frames should fit in
   `play_level`'s three vsyncs, so the game runs at the 16.7 frames a second
   its code asks for, in busy rooms as in quiet ones. (1987 runs at about 15
   on average, slower when busy.)
5. **A faster plotter.** Most sprites are 4 bytes by 12 rows: a cell. A
   plotter for 4-byte-wide sprites can keep the sprite's place in the data
   in Y and the pixel row within the character row in X, and store each of
   the four columns with an `STA abs,X` whose address is set once per
   character row: about 60 cycles a row, against about 230 for
   `plot_sprite`. The see-through version leaves the screen's pixel where
   the sprite's is black. It is worked on in py65 (`tests/test_plot.py`,
   `tools/dunjunz_revised/sixtyfive.py`), against a model of the screen,
   where each try takes seconds, not minutes.

## Decisions

- 2026-11-18: play and rendering are to be separated, with a steady frame
  rate (the owner's decision, after the patches on `see-through`).
- 2026-11-18, after players' feedback on stardot: a dead hero's key stays
  in the skull's cell, as in 1987, drawn over the skull (layer 3 over
  layer 2), which needs this renderer.

## Steps

1. The py65 harness and a test of `plot_sprite` against the model. Done.
2. The fast plotter, solid, for 4-byte-wide sprites. Done: a 4 x 12
   sprite takes 1,040 cycles (py65), against about 2,800. Over 300 frames
   of scripted play (`uv run dr-frame-time`) the revised game's frames now
   take a median of 119,809 cycles, 90% within 120,145 and at most 215,996,
   against 1987's 132,788, 186,370 and 322,850: nearly every frame keeps the
   three-vsync pace. Play is unchanged.
3. The see-through version of the fast plotter, in py65 against the model.
4. The render pass. Each place in play that plots on the board (the heroes,
   missiles and monsters rubbed out and drawn, keys and objects taken or
   moved, doors opened, skulls changing) marks the cells concerned dirty
   instead: the cell, and the next one along while a creature is between
   cells, in each view showing it. After play, for each dirty cell, the
   floor (base, skull, key) is drawn; then every creature whose image
   touches a dirty cell is drawn see-through, heroes, missiles, monsters.
   First the dirty cells are grown to take in the whole of any such
   creature, so nothing outside them is touched. A room coming on show marks
   only the cells holding something: drawing the view blanks the rest.
5. The exit's animation and the Chalice, which draw on their own terms.
6. A dead hero's key left in the skull's cell.

## Where it stands (2026-11-18)

Steps 1-4 are done, on the `render` branch: play marks what changes, and
`render` (`asm/upper/render.asm`, with pieces in other regions for room:
`render_floor.asm`, `render_monsters.asm`, `render_marked.asm`,
`render_low.asm`) draws the marked cells after play. Changes found on the
way:

- A creature is marked only when it looks different: a hero by comparing
  with `hero_drawn_*` (`draw_hero`), a monster by noting it before its move
  and comparing after (`note_monster`, `mark_monster_if_changed`). Marking
  every creature every frame, as 1987 plotted them, would redraw a hero
  standing on a trapdoor every frame, floor then hero, and the raster would
  catch the floor alone: the flicker this is meant to end.
- A creature that has not changed stands in one cell (one part way between
  cells moves every frame), so growing the marks needs one pass over the
  creatures' own cells.
- Each cell is marked in the first view showing its room only (views 3 to
  0); `plot_at_cell` draws it in every view showing it.
- A view coming on show marks all its cells; the walls among them are left
  as the view drew them.
- An energy drainer keeps its warning: the hero on it is left out every
  other frame.
- The memory came from making the font, the WRCHV handler and the end of
  the game non-resident in play (see `docs/memory.md`), working out sprite
  sizes instead of two tables, and moving small modules between regions.

The comparisons with 1987 leave out cells where two things meet, now or in
the frame before (`crowded_cells`): those are drawn as one picture now.
Every cell holding one thing matches.

Frame times (`dr-frame-time`, 300 frames): median 119,996 cycles (the
three-vsync pace), 90% 161,304, max 407,090, against 1987's 132,788,
186,370 and 322,850. A room coming on show marks only its own cells
(`mark_room`); at a level's start, when every view has just been drawn, a
blank floor is not plotted again. The longest frames are room changes:
drawing the view, then the room's floor again with what is on it. Next:
skip the blank floor there too when no other view shows the room, and draw
a creature solid when nothing else is in its cells, to bring the busy
frames back to the pace; both need memory.
Then step 6, a dead hero's key in the skull's cell.
