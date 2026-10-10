import Loam.Tui.Layout
import Loam.Tui.Runtime
import Loam.Tui.Terminal

/-!
Read-only, manually useful TUI presentation-phase microbenchmark.

Run from repository root:

  lake build Loam.Tui.Terminal
  lake env lean --run bench/TuiWidgetLowering.lean

A synthetic nested, multi-span screen is used to mirror the repeated
Widget.lines -> per-glyph Span -> clip -> compile pattern in production
Home/Actual/Scheduled views. It is NOT a benchmark of actual household
views, actual input-to-frame latency, allocations, or a real terminal.

Numbers are exploratory, not CI pass/fail thresholds. Compare matched
machines and workloads before using them to justify a code change.
-/


open Loam.Tui.Kernel

set_option autoImplicit false

private def syntheticRow (index : Nat) (selected : Bool) : Widget :=
  let marker := if selected && index == 3 then ">" else " "
  .row
    [ span (" " ++ marker ++ " ") .selected
    , span (toString index ++ "  食費/食材  ") .normal
    , span ("数量: " ++ toString (index * 1357 + 100) ++ " jpy  ") .muted
    , span "sample-emoji 🐸  " .selected
    , span "café / テスト / very-long-description" .normal
    ]

/-- Nesting produces both single-row and multi-row physical widgets. -/
private def syntheticBody (bounds : Bounds) (selected : Bool) : Widget :=
  .column <| (List.range (bounds.height + 12)).map fun index =>
    if index % 5 == 0 then
      .column
        [ .row [span ("Group " ++ toString index ++ " / 予定と記帳") .muted]
        , syntheticRow index selected
        ]
    else
      syntheticRow index selected

private def footer : List Widget :=
  [ mutedLine " [j/k] move   [Enter] detail   [q] back"
  , mutedLine " Feedback: synthetic-only. Exact quantities remain unmodified."
  ]

/-- Match the per-codepoint Cell -> Span round trip in several production screens. -/
private def perGlyphRows (lines : List (List Cell)) : List Widget :=
  lines.map fun cells =>
    .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)

/-- Match the final clipping/reconstitution pattern, without changing policy. -/
private def clipAndRebuild (bounds : Bounds) (rows : List Widget) : Widget :=
  .column (rows.map fun row =>
    .row
      ((Loam.Tui.Layout.clipCells
        (Loam.Tui.Layout.contentWidth bounds) row.lines.flatten).map fun cell =>
          span (String.singleton cell.glyph) cell.style))

private def finalWidget (bounds : Bounds) (selected : Bool) : Widget :=
  let body := syntheticBody bounds selected
  let physical := perGlyphRows body.lines
  let fitted := Loam.Tui.Layout.fitWithFooter bounds physical footer
  clipAndRebuild bounds fitted

private def dirtyAnsiChars
    (bounds : Bounds)
    (old next : Loam.Tui.Runtime.CompiledWidget) : Nat :=
  (Loam.Tui.Runtime.dirtyRows bounds 0 old next).foldl
    (fun total row =>
      let content :=
        match next.rowAt 0 row.val with
        | none => ""
        | some cells =>
            Loam.Tui.Terminal.renderCellsAnsi <|
              Loam.Tui.Layout.clipCells
                (Loam.Tui.Layout.contentWidth bounds) cells.toList
      total +
        (Loam.Tui.Terminal.cursorTo row.val 0).length +
        content.length +
        "\x1b[0m\x1b[K".length)
    0

@[noinline] private def measureBodyBuild (bounds : Bounds) (selected : Bool) : Nat :=
  match syntheticBody bounds selected with
  | .column children => children.length
  | .row spans => spans.length

@[noinline] private def measureFlatten (body : Widget) : Nat :=
  body.lines.length

@[noinline] private def measureRebuild (lines : List (List Cell)) : Nat :=
  (perGlyphRows lines).length

@[noinline] private def measureFooterFit (bounds : Bounds) (rows : List Widget) : Nat :=
  (Loam.Tui.Layout.fitWithFooter bounds rows footer).length

@[noinline] private def measureClipRebuild (bounds : Bounds) (rows : List Widget) : Nat :=
  (clipAndRebuild bounds rows).lines.length

@[noinline] private def measureCompile (widget : Widget) : Nat :=
  (Loam.Tui.Runtime.compileWidget widget).lines.size

@[noinline] private def measureDirty
    (bounds : Bounds) (old next : Loam.Tui.Runtime.CompiledWidget) : Nat :=
  (Loam.Tui.Runtime.dirtyRows bounds 0 old next).length + 1

@[noinline] private def measureDirtyAnsi
    (bounds : Bounds) (old next : Loam.Tui.Runtime.CompiledWidget) : Nat :=
  dirtyAnsiChars bounds old next + 1

@[noinline] private def measureDirectAnsi (bounds : Bounds) (widget : Widget) : Nat :=
  (Loam.Tui.Terminal.directFrameAnsi bounds widget).length

@[noinline] private def measureFull (bounds : Bounds) (selected : Bool) : Nat :=
  (Loam.Tui.Runtime.compileWidget (finalWidget bounds selected)).lines.size

private def median (values : List Nat) : Nat :=
  if values.isEmpty then 0
  else
    let sorted := values.toArray.qsort (· < ·)
    sorted[sorted.size / 2]!

private def nsPerCall (rounds count : Nat) (action : Nat → Nat) : IO Nat := do
  let mut samples : List Nat := []
  for _ in List.range rounds do
    let t0 ← IO.monoNanosNow
    let mut checksum := 0
    for index in List.range count do
      checksum := checksum + action index
    let t1 ← IO.monoNanosNow
    if checksum == 0 then
      throw (IO.userError "microbenchmark produced an empty checksum")
    samples := ((t1 - t0) / count) :: samples
  pure (median samples)

private def profile (bounds : Bounds) : IO Unit := do
  let before := syntheticBody bounds false
  let after := syntheticBody bounds true
  let oldCells := before.lines
  let newCells := after.lines
  let rawRows := perGlyphRows newCells
  let fitted := Loam.Tui.Layout.fitWithFooter bounds rawRows footer
  let oldView := finalWidget bounds false
  let newView := finalWidget bounds true
  let oldFrame := Loam.Tui.Runtime.compileWidget oldView
  let newFrame := Loam.Tui.Runtime.compileWidget newView
  let changed := (Loam.Tui.Runtime.dirtyRows bounds 0 oldFrame newFrame).length

  if oldCells == newCells || changed == 0 then
    throw (IO.userError "synthetic selection failed to change a visible row")
  if newView.lines.length > bounds.height - 1 then
    throw (IO.userError "synthetic frame exceeded the reserved terminal row")
  let stages : List (String × (Nat → Nat)) :=
    [ ("widget-build", fun i => measureBodyBuild bounds (i % 2 == 0))
    , ("widget-lines", fun _ => measureFlatten after)
    , ("cell-to-glyph-span", fun _ => measureRebuild newCells)
    , ("footer-fit", fun _ => measureFooterFit bounds rawRows)
    , ("clip-rebuild", fun _ => measureClipRebuild bounds fitted)
    , ("compile", fun _ => measureCompile newView)
    , ("dirty-discovery", fun _ => measureDirty bounds oldFrame newFrame)
    , ("dirty-ansi", fun _ => measureDirtyAnsi bounds oldFrame newFrame)
    , ("direct-full-ansi", fun _ => measureDirectAnsi bounds newView)
    , ("full-lowering-compile", fun i => measureFull bounds (i % 2 == 0))
    ]

  IO.println s!"terminal={bounds.width}x{bounds.height} synthetic-source-rows={newCells.length} visible-rows={newView.lines.length} changed-rows={changed}"
  IO.println s!"  emitted-chars: dirty={dirtyAnsiChars bounds oldFrame newFrame} direct={Loam.Tui.Terminal.directFrameAnsi bounds newView |>.length}"
  IO.println "  phase\tmedian-ns-per-call"
  for (label, action) in stages do
    let ns ← nsPerCall 5 (if label == "direct-full-ansi" || label == "full-lowering-compile" then 50 else 200) action
    IO.println s!"  {label}\t{ns}"

/-- Synthetic only. Deliberately no call to dataDir, HouseholdImage, or publisher. -/
def main : IO Unit := do
  IO.println "TUI lowering phase profile (read-only, no CI timing threshold)"
  IO.println "Caution: synthetic construction; phase timings are independent and non-additive."
  for bounds in
      ([ { width := 48, height := 14 }
       , { width := 80, height := 24 }
       , { width := 160, height := 48 }
       ] : List Bounds) do
    profile bounds
