import Loam.Tui.Layout
import Loam.Tui.Reports
import Loam.Tui.Runtime
import Loam.Tui.Terminal

open Loam.Tui.Kernel

set_option autoImplicit false

private def median (values : List Nat) : Nat :=
  if values.isEmpty then
    0
  else
    let sorted := values.toArray.qsort (· < ·)
    sorted[sorted.size / 2]!

private def repeated (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def syntheticRow (index : Nat) : Widget :=
  .row
    [ span ("row-" ++ toString index ++ " ")
    , span (repeated 72 (if index % 2 = 0 then 'x' else 'y')) .muted
    ]

private def preparedView (rowCount page : Nat) : Loam.Tui.Reports.PreparedScrollView :=
  {
    body := (List.range rowCount).map syntheticRow
    footer :=
      [ .row [span "footer-1" .muted]
      , .row [span "footer-2" .muted]
      , .row [span "footer-3" .muted]
      , .row [span "notice" .normal]
      ]
    page
    extent := rowCount
  }

@[noinline] private def forceViewportShape
    (bounds : Bounds)
    (state : Loam.Tui.Reports.State)
    (prepared : Loam.Tui.Reports.PreparedScrollView)
    (offset : Nat) : Nat :=
  let view :=
    Loam.Tui.Reports.viewPreparedScroll bounds { state with scroll := offset } prepared
  match view with
  | .row spans => spans.length
  | .column children => children.length

@[noinline] private def forceDirectAnsi
    (bounds : Bounds)
    (state : Loam.Tui.Reports.State)
    (prepared : Loam.Tui.Reports.PreparedScrollView)
    (offset : Nat) : Nat :=
  let view :=
    Loam.Tui.Reports.viewPreparedScroll bounds { state with scroll := offset } prepared
  (Loam.Tui.Terminal.directFrameAnsi bounds view).length

private def dirtyAnsiLength
    (bounds : Bounds)
    (old new : Loam.Tui.Runtime.CompiledWidget) : Nat :=
  (Loam.Tui.Runtime.dirtyRows bounds 0 old new).foldl
    (fun total row =>
      let content :=
        match new.rowAt 0 row.val with
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

@[noinline] private def forceCompiledDirty
    (bounds : Bounds)
    (state : Loam.Tui.Reports.State)
    (prepared : Loam.Tui.Reports.PreparedScrollView)
    (old : Loam.Tui.Runtime.CompiledWidget)
    (offset : Nat) : Nat :=
  let view :=
    Loam.Tui.Reports.viewPreparedScroll bounds { state with scroll := offset } prepared
  let next := Loam.Tui.Runtime.compileWidget view
  dirtyAnsiLength bounds old next

private def medianNsPerCall
    (repetitions iterations : Nat)
    (action : Nat → Nat) : IO Nat := do
  let mut samples : List Nat := []
  for _ in List.range repetitions do
    let t0 ← IO.monoNanosNow
    let mut checksum := 0
    for i in List.range iterations do
      checksum := checksum + action i
    let t1 ← IO.monoNanosNow
    if checksum == 0 then
      IO.println "unreachable"
    samples := ((t1 - t0) / iterations) :: samples
  pure (median samples)

def main : IO Unit := do
  let bounds : Bounds := { width := 100, height := 30 }
  let page := 25
  let rowCount := 10000
  let prepared := preparedView rowCount page
  let state := Loam.Tui.Reports.initialForDate "2026-10-02"

  IO.println "TUI scroll render measurement"
  IO.println s!"rows={rowCount} page={page} terminal={bounds.width}x{bounds.height}"
  IO.println "offset\tviewport-ns\tdirect-ansi-ns\tdirect-chars"

  for offset in [0, 100, 1000, 5000, 9000] do
    let viewportNs ← medianNsPerCall 7 4000 fun i =>
      forceViewportShape bounds state prepared (offset + (i % 8))
    let directNs ← medianNsPerCall 7 300 fun i =>
      forceDirectAnsi bounds state prepared (offset + (i % 8))
    let directChars := forceDirectAnsi bounds state prepared offset
    IO.println s!"{offset}\t{viewportNs}\t{directNs}\t{directChars}"

  let oldView := Loam.Tui.Reports.viewPreparedScroll bounds { state with scroll := 5000 } prepared
  let oldFrame := Loam.Tui.Runtime.compileWidget oldView
  let nextView := Loam.Tui.Reports.viewPreparedScroll bounds { state with scroll := 5001 } prepared
  let nextFrame := Loam.Tui.Runtime.compileWidget nextView
  let dirtyCount := (Loam.Tui.Runtime.dirtyRows bounds 0 oldFrame nextFrame).length
  let dirtyChars := dirtyAnsiLength bounds oldFrame nextFrame
  let directChars := forceDirectAnsi bounds state prepared 5001
  let dirtyNs ← medianNsPerCall 7 300 fun i =>
    forceCompiledDirty bounds state prepared oldFrame (5001 + (i % 8))

  IO.println ""
  IO.println s!"transition=5000->5001 dirty-rows={dirtyCount}/{bounds.height}"
  IO.println s!"compiled-dirty-ns={dirtyNs}"
  IO.println s!"dirty-ansi-chars={dirtyChars}"
  IO.println s!"direct-ansi-chars={directChars}"
