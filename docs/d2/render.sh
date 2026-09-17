#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
INPUT="$ROOT/docs/d2/current_actual_target_comparison.d2"
OUT_DIR="$ROOT/scratch/d2"
SVG="$OUT_DIR/current_actual_target_comparison.svg"
ASCII="$OUT_DIR/current_actual_target_comparison.txt"

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

d2 --layout=elk "$INPUT" "$SVG"
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
