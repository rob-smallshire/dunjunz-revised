# Possible enhancements

Ideas for later, beyond the 1987 game's behaviour. None is planned yet;
each needs the owner's go-ahead. Decided work belongs in `plan.md`.

## Transparent sprites for the heroes

`plot_sprite` copies each byte to the screen, so a sprite's black pixels
hide whatever is under it: a hero standing on a trapdoor, key or object
covers the whole cell. Treating colour 0 as transparent needs no mask
tables, because a MODE 2 byte's two pixels are interleaved bits: the left
pixel is non-black if any bit of &AA is set, the right if any bit of &55
is set, so the mask is &AA, &55, both or neither, and the plot becomes
`screen = (screen AND NOT mask) OR byte`.

- Cost: a masked variant of the plot loop (about 30-40 bytes) and about
  20 cycles more per byte, so it should be used for the heroes (and perhaps
  missiles) only.
- Order: what shows through must be drawn first. Trapdoors already are
  (`draw_trapdoors` starts the frame); keys and objects are drawn after
  the heroes, and would have to move earlier.
- It changes the look of the game only where sprites overlap.

## A controls screen

The controls are in the README only. The Model B disc shows none; the
1987 Master disc's BASIC loader had a MODE 7 controls page. A help page
before the hero menu, or the key-redefinition phase planned for joysticks
(`plan.md`, milestone 6), could show them.
