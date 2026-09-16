#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

foundation_files=(
  "Loam/Tui/Kernel.lean"
  "Loam/Tui/Layout.lean"
  "Loam/Tui/Runtime.lean"
  "Loam/Tui/Scroll.lean"
  "Loam/Tui/CyclicIndex.lean"
  "Loam/Tui/Terminal.lean"
)

for path in "${foundation_files[@]}"; do
  mkdir -p "$tmp/$(dirname "$path")"
  cp "$root/$path" "$tmp/$path"
done

cp "$root/lean-toolchain" "$tmp/lean-toolchain"
cp "$root/tests/tui_foundation_smoke.lean" "$tmp/FoundationSmoke.lean"

cat > "$tmp/lakefile.lean" <<'EOF'
import Lake
open Lake DSL

package tuiFoundation

lean_lib Loam
EOF

(
  cd "$tmp"
  lake build \
    Loam.Tui.Kernel \
    Loam.Tui.Layout \
    Loam.Tui.Runtime \
    Loam.Tui.Scroll \
    Loam.Tui.CyclicIndex \
    Loam.Tui.Terminal
  lake env lean --run FoundationSmoke.lean
)
