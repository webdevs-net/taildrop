# Marks

`logo-taildrop.svg` is the mark; `logo-taildrop-ink.svg` is the monochrome twin used for the menu
bar, where macOS tints template images itself.

A 3×3 grid of flat-top hexagons — centres at 80/128/176, circumradius 16 — with four solid and five
at 30% opacity, and a droplet overlapping the lower right. The spacing comes from how a tailnet mark
reads at small sizes: nodes about a radius apart, so the grid stays a grid down to 16px.

Where the droplet would clip a hexagon, that hexagon is left out entirely rather than shaved into a
sliver, and the gap around the droplet is the same path stroked, so clear space stays even at any
size.

`logo-hex-pointy.svg` and its ink twin are the point-up alternative, kept for reference.
`logo-i-drop-corner.svg` is the earlier circular version.

Icons are generated from these by `make-icons.sh`, which renders every size and packs the `.icns`.

**Not affiliated with Tailscale.** The mark is an independent design and Tailscale is not involved
in this project.
