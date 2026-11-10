# Marks

Proportions are taken from Tailscale's own mark (their favicon): a 3×3 grid at 15/24/33 with r=3 on
a 48 canvas — dots a radius apart, not the looser grid they're often drawn as. Four dots form the
"t" (middle row plus one below centre) and the other five sit at 30% opacity behind. Scaled ×16/3
here, so centres land on 80/128/176 with r=16.

| File | Idea |
|---|---|
| `logo-g-drop-stem.svg` | The droplet *is* the stem of the "t" — the mark reads as itself and as a drop |
| `logo-h-drop-in-front.svg` | Droplet floating in front of the whole mark, knocked out with an even gap |
| `logo-i-drop-corner.svg` | Droplet over the lower-right, mark left almost intact |
| `*-ink.svg` | Same shapes in ink rather than blue, for menu bars and monochrome use |
| `reference-tailscale-proportions.svg` | The measured grid alone, for checking proportions |

Where a droplet would clip a dot, that dot is left out entirely rather than shaved into a sliver.
The gap around each droplet is the same path stroked, so clear space stays even at any size.

**Trademark:** these deliberately echo Tailscale's mark. Fine for an internal tool; if TailDrop ever
ships publicly, the grid should be redrawn far enough away that nobody mistakes it for a Tailscale
product, or permission sought.
