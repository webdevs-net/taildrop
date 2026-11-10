#!/bin/bash
# Renders the app icon (.icns) and the menu bar template image from the SVG
# marks. Chrome is used as the renderer so there is no extra dependency.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$SRC/../app/Resources}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x "$CHROME" ]] || { echo "make-icons: Chrome not found, skipping" >&2; exit 0; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

# Render an SVG at one size on a transparent background. The mark is inset so
# it does not run to the very edge of the tile.
render() {
  local svg="$1" px="$2" dest="$3" pad="${4:-8}"
  cat > "$WORK/page.html" <<HTML
<!doctype html><meta charset=utf-8>
<style>
  html,body{margin:0;background:transparent}
  body{width:${px}px;height:${px}px;display:flex;align-items:center;justify-content:center}
  img{width:$((px - px * pad / 100 * 2))px;height:$((px - px * pad / 100 * 2))px}
</style>
<img src="file://$svg">
HTML
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --default-background-color=00000000 \
    --screenshot="$dest" --window-size="$px,$px" \
    "$WORK/page.html" >/dev/null 2>&1
}

# --- app icon -------------------------------------------------------------
ICONSET="$WORK/TailDrop.iconset"
mkdir -p "$ICONSET"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
            "512:512x512" "1024:512x512@2x"; do
  px="${spec%%:*}"; name="${spec##*:}"
  render "$SRC/logo-taildrop.svg" "$px" "$ICONSET/icon_$name.png"
done
iconutil -c icns "$ICONSET" -o "$OUT/TailDrop.icns"

# --- menu bar ------------------------------------------------------------
# Black, flat, transparent: macOS tints template images itself, so this one
# follows the menu bar through light and dark.
render "$SRC/logo-taildrop-ink.svg" 18 "$OUT/menubar.png" 0
render "$SRC/logo-taildrop-ink.svg" 36 "$OUT/menubar@2x.png" 0

echo "$OUT/TailDrop.icns"
