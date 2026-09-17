#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
OUT_DIR="$ROOT/scratch/d2"

if ! command -v d2 >/dev/null 2>&1; then
  cat >&2 <<'EOF'
D2 CLI was not found.
Install D2, verify it with `d2 version`, then rerun:
  sh docs/d2/render.sh
Official install guide: https://d2lang.com/tour/install/
EOF
  exit 127
fi

mkdir -p "$OUT_DIR"

for INPUT in "$ROOT"/docs/d2/*.d2; do
  NAME=$(basename "$INPUT" .d2)
  SVG="$OUT_DIR/$NAME.svg"
  ASCII="$OUT_DIR/$NAME.txt"

  # D2's default SVG is fit-to-screen. That is convenient for embedding, but a
  # local browser can then behave like the whole diagram is one fitted canvas.
  # An explicit scale keeps intrinsic SVG dimensions so normal browser zoom and
  # scrolling remain useful during audit inspection.
  d2 --layout=elk --scale=1 "$INPUT" "$SVG"
  d2 --layout=elk "$INPUT" "$ASCII"

  printf 'D2 projection rendered:\n  SVG:   %s\n  ASCII: %s\n' "$SVG" "$ASCII"

  if [ "${1:-}" = "--open" ]; then
    if [ "$(uname -s)" = "Darwin" ] && command -v open >/dev/null 2>&1; then
      # Use Safari explicitly so the experiment does not depend on the user's
      # system-wide SVG file association (which may point at an editor).
      open -a Safari "$SVG"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$SVG" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
      open "$SVG"
    else
      printf 'No desktop opener found; open the SVG path above manually.\n' >&2
    fi
  fi
done
