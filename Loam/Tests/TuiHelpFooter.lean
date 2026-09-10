import Loam.Tui.Layout
import Loam.Tui.HraHome
import Loam.Tui.SelectedDay
import Loam.Tui.HraScheduled
import Loam.Tui.HraActual

open Loam.Core Loam.Tui.Kernel Loam.Tui.Layout

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def buildSnapshot : IO Loam.Tui.Main.Snapshot := do
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [])
    "empty Scheduled memory was not admitted"
  let completions ← requireSome (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let retirements ← requireSome (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let replacements ← requireSome (ScheduledReplacementMemory.ofReplacements? [])
    "empty replacement memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-10"
    allRecords := []
    undatedCount := 0
  }
  let scheduled : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    completions := completions
    retirements := retirements
    replacements := replacements
    events := events
  }
  pure { actual, scheduled }

def main : IO Unit := do
  let snapshot ← buildSnapshot

  -- 1. Test flowTokens primitives
  let emptyTokens : List String := []
  expect (flowTokens 80 "  " emptyTokens == [])
    "empty tokens should produce empty lines"

  let sampleTokens := ["[a] one", "[b] two", "[c] three", "[d] four", "[e] five"]
  let flowed80 := flowTokens 80 "  " sampleTokens
  expect (flowed80.length == 1) "sample tokens should fit on one line at 80 cols"
  expect (flowed80.head! == "[a] one  [b] two  [c] three  [d] four  [e] five")
    "sample tokens should join with separator"

  let flowed20 := flowTokens 20 "  " sampleTokens
  for line in flowed20 do
    expect (displayWidth line ≤ 20)
      s!"flowed line exceeded target width: {line} (width {displayWidth line})"

  -- 2. Test HraHome help lines at various terminal widths
  let state := Loam.Tui.Main.initialState "2026-09-10"
  let expectedTokens := [
    "[h/l] day", "[k/j] week", "[g] known", "[Enter] day", "[r] record",
    "[a] actual", "[p] scheduled", "[i] attention", "[c] budget",
    "[e] capacity", "[u] purpose routes", "[m] loci", "[v] reports", "[q] quit"
  ]

  -- 2a. Wide terminal (190 cols): fits on a single line
  let wideBounds : Bounds := { width := 190, height := 45 }
  let wideText := widgetText (Loam.Tui.HraHome.view wideBounds snapshot state)
  for token in expectedTokens do
    expect (contains token wideText) s!"wide Home lost token {token}"

  -- 2b. Target dogfood terminal (150 cols, user environment):
  -- Previously clipped '[m] loci  [v] reports  [q] quit' due to hardcoded 120 threshold.
  let mediumBounds : Bounds := { width := 150, height := 45 }
  let mediumView := Loam.Tui.HraHome.view mediumBounds snapshot state
  let mediumText := widgetText mediumView
  for token in expectedTokens do
    expect (contains token mediumText)
      s!"150-column Home lost token {token}; must not be clipped"

  -- Ensure every line in the rendered widget respects contentWidth bounds
  let mediumContentWidth := contentWidth mediumBounds
  for lineCells in mediumView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ mediumContentWidth)
      s!"150-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {mediumContentWidth})"

  -- 2c. Standard terminal (80 cols):
  -- Must wrap into multiple lines without clipping any tokens.
  let narrowBounds : Bounds := { width := 80, height := 24 }
  let narrowView := Loam.Tui.HraHome.view narrowBounds snapshot state
  let narrowText := widgetText narrowView
  for token in expectedTokens do
    expect (contains token narrowText)
      s!"80-column Home lost token {token}; must not be clipped"

  -- Ensure every help line in narrowView respects narrowContentWidth
  let narrowContentWidth := contentWidth narrowBounds
  let narrowLines := (widgetText narrowView).splitOn "\n"
  -- The help lines are the trailing non-blank lines at the bottom
  let footerLines := narrowLines.reverse.filter (fun l => !l.trimAscii.isEmpty) |>.take 3
  for lineStr in footerLines do
    expect (displayWidth lineStr ≤ narrowContentWidth)
      s!"80-column footer line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {narrowContentWidth})"

  -- 3. Test SelectedDay footer geometry
  let selState := Loam.Tui.SelectedDay.initial "2026-09-10"

  -- At width 100, Scheduled detailed line (112 cols) must cleanly fall back to compact (84 cols)
  let selBounds100 : Bounds := { width := 100, height := 30 }
  let selView100 := Loam.Tui.SelectedDay.view selBounds100 snapshot selState
  let selText100 := widgetText selView100
  expect (contains "[j/k] select" selText100) "SelectedDay lost navigation help"

  -- At width 130, detailed lines fit comfortably
  let selBounds130 : Bounds := { width := 130, height := 30 }
  let selView130 := Loam.Tui.SelectedDay.view selBounds130 snapshot selState
  let selText130 := widgetText selView130
  expect (contains "Actual/Scheduled" selText130)
    "SelectedDay at 130 cols should expose detailed pane switch"

  -- 4. Test HraScheduled footer geometry
  let schedState := Loam.Tui.HraScheduled.initial "2026-09-10"
  let schedBounds80 : Bounds := { width := 80, height := 24 }
  let schedView80 := Loam.Tui.HraScheduled.view schedBounds80 snapshot schedState
  let schedText80 := widgetText schedView80
  expect (contains "[c/Enter] complete" schedText80)
    "HraScheduled at 80 cols must retain complete action in wrapped footer"

  IO.println "TUI help footer geometry: adaptive flow and bounded width checks passed."
