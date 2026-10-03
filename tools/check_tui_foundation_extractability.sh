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
  "Loam/Tui/Chart.lean"
  "Loam/Tui/Terminal.lean"
  "Loam/Tui/terminal_native.c"
)

for path in "${foundation_files[@]}"; do
  mkdir -p "$tmp/$(dirname "$path")"
  cp "$root/$path" "$tmp/$path"
done

cp "$root/lean-toolchain" "$tmp/lean-toolchain"
cp "$root/tests/tui_foundation_smoke.lean" "$tmp/FoundationSmoke.lean"
cp "$root/Loam/Tests/TuiChart.lean" "$tmp/ChartSmoke.lean"

cat > "$tmp/lakefile.lean" <<'EOF'
import Lake
open Lake DSL

package tuiFoundation where
  moreLinkObjs := #[`@/terminalNative]

target terminalNative pkg : System.FilePath := do
  let src ← inputFile (pkg.dir / "Loam" / "Tui" / "terminal_native.c") true
  let lean ← getLeanInstall
  let obj ← buildO (pkg.buildDir / "native" / "terminal_native.o") src
    #["-I", lean.includeDir.toString] #["-O2", "-fPIC"]
  buildStaticLib (pkg.buildDir / "native" / nameToStaticLib "loam_terminal") #[obj]

lean_lib Loam

lean_exe foundationSmoke where
  root := `FoundationSmoke
EOF

(
  cd "$tmp"
  lake build \
    Loam.Tui.Kernel \
    Loam.Tui.Layout \
    Loam.Tui.Runtime \
    Loam.Tui.Scroll \
    Loam.Tui.CyclicIndex \
    Loam.Tui.Chart \
    Loam.Tui.Terminal foundationSmoke
  .lake/build/bin/foundationSmoke
  lake env lean --run ChartSmoke.lean
)
