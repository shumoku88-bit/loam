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

private def occurrences (needle haystack : String) : Nat :=
  if needle.isEmpty then 0 else (haystack.splitOn needle).length - 1

private def requireSome {α : Type} (value : Option α) (message : String) : IO α := do
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

  -- 1b. Stable footer geometry owns only body capacity and vertical fitting.
  let frameBounds : Bounds := { width := 80, height := 6 }
  expect (footerBodyCapacity frameBounds 2 == 3)
    "footer body capacity did not reserve the terminal row and footer rows"
  let frameBody : List Widget := [.row [span "body"]]
  let frameFooter : List Widget := [.row [span "footer-a"], .row [span "footer-b"]]
  let fittedFrame := fitWithFooter frameBounds frameBody frameFooter
  expect (fittedFrame.length == 5)
    "stable footer fitting did not fill the usable terminal rows"
  expect (contains "body\n\n\nfooter-a\nfooter-b" (widgetText (.column fittedFrame)))
    "stable footer fitting did not pad short body content above the footer"

  -- 2. Test HraHome help lines at various terminal widths
  let state := Loam.Tui.Main.initialState "2026-09-10"
  let expectedTokens := [
    "[h/l] day", "[k/j] week", "[t] today", "[Enter] open", "[r] record",
    "[a] actual", "[s] scheduled", "[i] attention", "[b] balances", "[c] budget",
    "[e] capacity", "[p] purpose routing", "[m] manage loci", "[o] observe quantities",
    "[v] reports", "[q] quit"
  ]

  -- 2a. Wide terminal
  let wideBounds : Bounds := { width := 190, height := 45 }
  let wideText := widgetText (Loam.Tui.HraHome.view wideBounds snapshot state)
  for token in expectedTokens do
    expect (contains token wideText) s!"wide Home lost token {token}"
  expect (contains "Day:" wideText && contains "Household:" wideText && contains "Manage:" wideText)
    "wide Home lost semantic footer groups"
  expect (contains "Pending: 0" wideText)
    "empty Pending evidence disappeared from the glance status"
  expect (!contains "Pending Scheduled:" wideText)
    "empty Pending evidence should not allocate a body section"
  expect (!contains "Household Shortcuts:" wideText)
    "Home body regained a duplicate shortcut section"
  expect (!contains "Attention is current-open evidence" wideText)
    "Home body regained explanatory shortcut prose"
  -- Home now reserves three fixed rows for Daily Pace / next Scheduled
  -- summary and its separator above the two-pane viewport.
  let expectedWidePanelRows := footerBodyCapacity wideBounds 4 - 7
  expect (occurrences " │ " wideText == expectedWidePanelRows)
    "wide Home divider height changed with content instead of filling the fixed viewport"
  for token in ["[i] attention", "[b] balances", "[c] budget", "[e] capacity",
                "[p] purpose routing", "[m] manage loci", "[o] observe quantities",
                "[v] reports"] do
    expect (occurrences token wideText == 1)
      s!"Home should advertise {token} exactly once in the footer"

  -- 2b. Target dogfood terminal (150 cols, user environment)
  let mediumBounds : Bounds := { width := 150, height := 45 }
  let mediumView := Loam.Tui.HraHome.view mediumBounds snapshot state
  let mediumText := widgetText mediumView
  for token in expectedTokens do
    expect (contains token mediumText)
      s!"150-column Home lost token {token}; must not be clipped"

  let scrollBounds : Bounds := { width := 150, height := 15 }
  expect (Loam.Tui.HraHome.detailScrollDirection? scrollBounds .up == none)
    "wide layout stole Up from Calendar navigation"
  expect (Loam.Tui.HraHome.detailScrollDirection? scrollBounds .down == none)
    "wide layout stole Down from Calendar navigation"
  expect (Loam.Tui.HraHome.detailScrollDirection? scrollBounds .left == none)
    "wide layout stole Left from Calendar navigation"
  expect (Loam.Tui.HraHome.detailScrollDirection? scrollBounds .right == none)
    "wide layout stole Right from Calendar navigation"
  expect (Loam.Tui.HraHome.detailScrollDirection? scrollBounds (.ctrl 'u') == some false)
    "wide layout lost Ctrl-U detail scrolling"
  expect (Loam.Tui.HraHome.detailScrollDirection? scrollBounds (.ctrl 'd') == some true)
    "wide layout lost Ctrl-D detail scrolling"
  let narrowScrollBounds : Bounds := { width := 80, height := 15 }
  expect (Loam.Tui.HraHome.detailScrollDirection? narrowScrollBounds (.ctrl 'd') == none)
    "narrow layout unexpectedly captured detail-scroll input"
  let scrolled := Loam.Tui.HraHome.scrollWideDetail scrollBounds snapshot state true
  expect (scrolled.detailScroll == 1)
    "wide Home detail viewport did not advance by one row"
  let scrolledText := widgetText (Loam.Tui.HraHome.view scrollBounds snapshot scrolled)
  expect (contains "scroll  (Ctrl-U/D)" scrolledText)
    "overflowing wide Home did not advertise its local scroll affordance"
  let resetStep := Loam.Tui.Main.update scrolled .right
  expect (resetStep.state.detailScroll == 0)
    "changing Home date did not reset the detail viewport to its origin"

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
  for lineCells in narrowView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ narrowContentWidth)
      s!"80-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {narrowContentWidth})"

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
