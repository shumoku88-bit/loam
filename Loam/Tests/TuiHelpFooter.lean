import Loam.Tui.Layout
import Loam.Tui.HraHome
import Loam.Tui.SelectedDay
import Loam.Tui.HraScheduled
import Loam.Tui.HraActual
import Loam.Tui.CurrentQuantityAnchor

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
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-10"
    allRecords := []
  }
  let scheduled : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    terminals := terminals
    events := events
  }
  pure { actual, scheduled := .ok scheduled }

private def typeAnchorText
    (state : Loam.Tui.CurrentQuantityAnchor.State) (text : String) :
    Loam.Tui.CurrentQuantityAnchor.State :=
  text.toList.foldl
    (fun current char =>
      (Loam.Tui.CurrentQuantityAnchor.update current (.input char)).state)
    state

private def pressAnchor
    (state : Loam.Tui.CurrentQuantityAnchor.State) (key : Loam.Tui.Terminal.Key) :
    Loam.Tui.CurrentQuantityAnchor.State :=
  (Loam.Tui.CurrentQuantityAnchor.update state key).state

private def anchorAssertion
    (locus : String) (quanta : Int) : Loam.CurrentQuantityAnchor.Assertion := {
  coordinate := ⟨⟨locus⟩, ⟨"jpy"⟩⟩
  quantity := Quantity.ofQuanta quanta
}

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
    "[e] capacity", "[u] purpose routes", "[m] loci", "[o] observe qty",
    "[v] reports", "[q] quit"
  ]

  -- 2a. Wide terminal
  let wideBounds : Bounds := { width := 190, height := 45 }
  let wideText := widgetText (Loam.Tui.HraHome.view wideBounds snapshot state)
  for token in expectedTokens do
    expect (contains token wideText) s!"wide Home lost token {token}"

  -- 2b. Target dogfood terminal (150 cols, user environment)
  let mediumBounds : Bounds := { width := 150, height := 45 }
  let mediumView := Loam.Tui.HraHome.view mediumBounds snapshot state
  let mediumText := widgetText mediumView
  for token in expectedTokens do
    expect (contains token mediumText)
      s!"150-column Home lost token {token}; must not be clipped"

  let mediumContentWidth := contentWidth mediumBounds
  for lineCells in mediumView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ mediumContentWidth)
      s!"150-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {mediumContentWidth})"

  -- 2c. Standard terminal (80 cols)
  let narrowBounds : Bounds := { width := 80, height := 24 }
  let narrowView := Loam.Tui.HraHome.view narrowBounds snapshot state
  let narrowText := widgetText narrowView
  for token in expectedTokens do
    expect (contains token narrowText)
      s!"80-column Home lost token {token}; must not be clipped"

  let narrowContentWidth := contentWidth narrowBounds
  let narrowLines := (widgetText narrowView).splitOn "\n"
  let footerLines := narrowLines.reverse.filter (fun l => !l.trimAscii.isEmpty) |>.take 3
  for lineStr in footerLines do
    expect (displayWidth lineStr ≤ narrowContentWidth)
      s!"80-column footer line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {narrowContentWidth})"

  -- 3. Test SelectedDay footer geometry
  let selState := Loam.Tui.SelectedDay.initial "2026-09-10"
  let selBounds100 : Bounds := { width := 100, height := 30 }
  let selView100 := Loam.Tui.SelectedDay.view selBounds100 snapshot selState
  let selText100 := widgetText selView100
  expect (contains "[j/k] select" selText100) "SelectedDay lost navigation help"

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

  -- 5. Current Quantity TUI remains a thin complete-image observation adapter.
  let enteredLocus := typeAnchorText Loam.Tui.CurrentQuantityAnchor.initial "mother-wifi-debt"
  let quantityFocus := pressAnchor (pressAnchor enteredLocus .tab) .tab
  let enteredQuantity := typeAnchorText quantityFocus "-12345"
  let addStep := Loam.Tui.CurrentQuantityAnchor.update enteredQuantity .enter
  expect (decide (addStep.state.assertions = [anchorAssertion "mother-wifi-debt" (-12345)]))
    "quantity Enter did not append the exact observed row"
  expect (addStep.state.form.measure == "jpy")
    "adding an observation did not retain the practical measure default"
  expect (addStep.state.form.locus.isEmpty && addStep.state.form.quantity.isEmpty)
    "adding an observation did not clear the next-row locus and quantity"

  let previewFocus :=
    pressAnchor (pressAnchor (pressAnchor (pressAnchor addStep.state .tab) .tab) .tab) .tab
  let previewState := (Loam.Tui.CurrentQuantityAnchor.update previewFocus .enter).state
  let publishStep := Loam.Tui.CurrentQuantityAnchor.update previewState .enter
  let published ← requireSome publishStep.publish
    "preview Publish did not emit the complete observation image"
  expect (decide (published = [anchorAssertion "mother-wifi-debt" (-12345)]))
    "published TUI intent changed the observed coordinate or quantity"

  let duplicate := anchorAssertion "same-coordinate" 5
  let duplicateState : Loam.Tui.CurrentQuantityAnchor.State := {
    assertions := [duplicate, duplicate]
    form := { focus := 4 }
  }
  let duplicatePreview :=
    (Loam.Tui.CurrentQuantityAnchor.update duplicateState .enter).state
  let duplicatePublish := Loam.Tui.CurrentQuantityAnchor.update duplicatePreview .enter
  let duplicateImage ← requireSome duplicatePublish.publish
    "duplicate-coordinate preview did not reach the publisher boundary"
  expect (duplicateImage.length == 2)
    "TUI silently introduced coordinate uniqueness semantics"

  let badQuantityState : Loam.Tui.CurrentQuantityAnchor.State := {
    form := { locus := "wifi", measure := "jpy", quantity := "12x", focus := 2 }
  }
  let badStep := Loam.Tui.CurrentQuantityAnchor.update badQuantityState .enter
  expect badStep.state.assertions.isEmpty
    "noninteger quantity became an observation"
  expect (!badStep.state.notice.isEmpty)
    "noninteger quantity did not produce local representation feedback"

  let previewText := widgetText (Loam.Tui.CurrentQuantityAnchor.view previewState)
  expect (contains "replaces the current anchor image" previewText)
    "preview no longer explains complete-image replacement semantics"
  expect (contains "shared publisher derives the Event root cut" previewText)
    "preview no longer exposes the publisher-owned cut boundary"

  IO.println "TUI help/footer and current quantity observation boundary checks passed."
