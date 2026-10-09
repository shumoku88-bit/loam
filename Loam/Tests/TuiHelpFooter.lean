import Loam.Tui.Layout
import Loam.Tui.Home
import Loam.Tui.HomeCommandPalette
import Loam.Tui.SelectedDay
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.ActualWorkspace
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

private def firstLineContaining?
    (needle : String) : List (List Cell) → Nat → Option Nat
  | [], _ => none
  | cells :: rest, index =>
      let line := String.ofList (cells.map Cell.glyph)
      if contains needle line then some index
      else firstLineContaining? needle rest (index + 1)

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

  -- 0. Money calendar is role-aware: assets/transfers do not become fake +/- flow.
  let incomeEvent ← requireSome
    (Event.ofEffects? ⟨"income-event"⟩
      [ Effect.ofQuantity ⟨"income-wallet"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 12000)
      , Effect.ofQuantity ⟨"income-role"⟩ ⟨"salary"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-12000))
      ])
    "money calendar income fixture"
  let expenseEvent ← requireSome
    (Event.ofEffects? ⟨"expense-event"⟩
      [ Effect.ofQuantity ⟨"expense-wallet"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-2470))
      , Effect.ofQuantity ⟨"expense-role"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 2470)
      ])
    "money calendar expense fixture"
  let transferEvent ← requireSome
    (Event.ofEffects? ⟨"transfer-event"⟩
      [ Effect.ofQuantity ⟨"transfer-wallet"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-3000))
      , Effect.ofQuantity ⟨"transfer-paypay"⟩ ⟨"paypay"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 3000)
      ])
    "money calendar transfer fixture"
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := ⟨"wallet"⟩, role := .asset }
      , { locus := ⟨"paypay"⟩, role := .asset }
      , { locus := ⟨"salary"⟩, role := .income }
      , { locus := ⟨"food"⟩, role := .expense }
      ])
    "money calendar role map fixture"
  let records : List Loam.ActualReview.Record :=
    [ { event := incomeEvent, date := some "2026-09-10", description := "", replacement := none }
    , { event := expenseEvent, date := some "2026-09-10", description := "", replacement := none }
    , { event := transferEvent, date := some "2026-09-10", description := "", replacement := none }
    ]
  let moneyProjection := Loam.CalendarMoneyReview.project records roles
  let moneyRow ← requireSome (moneyProjection.rowFor? "2026-09-10" ⟨"jpy"⟩)
    "money calendar lost the represented day"
  let direction := moneyRow.directional
  expect (direction.plus.quanta == 12000 && direction.minus.quanta == 2470)
    "money calendar counted an asset transfer or changed Income/Expense direction"
  let monthSummary :=
    moneyProjection.summaryForWindow "2026-09-01" "2026-10-01" ⟨"jpy"⟩
  expect (monthSummary.plus.quanta == 12000 &&
          monthSummary.minus.quanta == 2470 &&
          monthSummary.unresolvedEffectCount == 0)
    "money calendar month summary changed daily directional semantics"

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

  -- 2. Test Home help lines at various terminal widths
  let state := Loam.Tui.Main.initialState "2026-09-10"
  expect (state.homeMode == .calendar)
    "TUI pure Home state lost its Calendar fixture default"

  let expectedTokens := [
    "[h/l] day", "[k/j] week", "[Enter] open", "[r] record",
    "[a] actual", "[s] scheduled", "[d] daily pace", "[i] attention", "[b] balances", "[u] settlements", "[g] summary",
    "[Space] commands", "[m] manage loci", "[o] observe quantities",
    "[v] reports", "[q] quit"
  ]

  -- 2a. Wide terminal
  let wideBounds : Bounds := { width := 190, height := 45 }
  let wideView := Loam.Tui.Home.view wideBounds snapshot state
  let wideText := widgetText wideView
  let _ ← requireSome
    (firstLineContaining? "underline = today" wideView.lines 0)
    "wide Home lost the calendar Today legend"
  expect (contains "± not requested" wideText)
    "wide Home did not use the unified money calendar when flow evidence is not requested"
  expect (!contains "[f] flow" wideText && !contains "[f] calendar" wideText)
    "retired small-calendar switch leaked into the Home command deck"
  for token in expectedTokens do
    expect (contains token wideText) s!"wide Home lost token {token}"
  expect
    (contains "Day" wideText && contains "View" wideText && contains "Action" wideText &&
      contains "Household" wideText && contains "Manage" wideText)
    "wide Home lost command-deck groups"
  let dayFooterRow ← requireSome
    (firstLineContaining? "[h/l] day" wideView.lines 0)
    "wide Home lost Day command-deck row"
  let dayFooterCells ← requireSome wideView.lines[dayFooterRow]?
    "wide Home Day command-deck row was not addressable"
  expect
    (dayFooterCells.any (fun cell => cell.style == .normal) &&
      dayFooterCells.any (fun cell => cell.style == .muted))
    "Home command deck no longer distinguishes keys/categories from descriptions"
  expect (contains "Pending: 0" wideText)
    "empty Pending evidence disappeared from the glance status"
  expect (!contains "Pending Scheduled:" wideText)
    "empty Pending evidence should not allocate a body section"
  expect (!contains "Household Shortcuts:" wideText)
    "Home body regained a duplicate shortcut section"
  expect (!contains "Attention is current-open evidence" wideText)
    "Home body regained explanatory shortcut prose"
  -- The divider is long enough to fill a wide terminal, independent of
  -- whether flow evidence happens to be loaded or unavailable.
  let dividerCount := occurrences " │ " wideText
  expect (dividerCount > 12)
    "unified money calendar lost its stable wide side-by-side geometry"
  for token in ["[d] daily pace", "[i] attention", "[b] balances", "[u] settlements", "[g] summary",
                "[Space] commands", "[m] manage loci", "[o] observe quantities",
                "[v] reports"] do
    expect (occurrences token wideText == 1)
      s!"Home should advertise {token} exactly once in the footer"

  -- 2b. Target dogfood terminal (150 cols, user environment)
  let mediumBounds : Bounds := { width := 150, height := 45 }
  let mediumView := Loam.Tui.Home.view mediumBounds snapshot state
  let mediumText := widgetText mediumView
  for token in expectedTokens do
    expect (contains token mediumText)
      s!"150-column Home lost token {token}; must not be clipped"

  let moneyFlow : Loam.CalendarMoneyReview.Snapshot := {
    rows := [{
      date := "2026-09-10"
      measure := ⟨"jpy"⟩
      income := Quantity.ofQuanta 12000
      expense := Quantity.ofQuanta 2470
      unresolvedEffectCount := 0
    }]
  }
  let moneySnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with
    moneyCalendar := .loaded { flow := moneyFlow, presentation := [] }
  }
  let moneyView := Loam.Tui.Home.view mediumBounds moneySnapshot state
  let moneyText := widgetText moneyView
  expect ((Loam.Tui.Home.view wideBounds moneySnapshot state).lines.length == wideView.lines.length)
    "loaded money projection changed fixed Home viewport height"
  expect (!contains "[f] calendar" moneyText && !contains "[f] flow" moneyText)
    "unified calendar still advertised its retired layout toggle"
  expect (contains "± jpy" moneyText)
    "money calendar did not expose its selected Measure"
  expect (contains "+¥12,000" moneyText && contains "-¥2,470" moneyText)
    "money calendar did not render grouped daily + / - totals with the JPY symbol"
  expect (contains "+¥12,000   -¥2,470   = +¥9,530" moneyText)
    "money calendar did not render the symbolic monthly + / - / net summary"
  expect (contains "┌" moneyText && contains "┬" moneyText &&
          contains "│" moneyText && contains "┼" moneyText &&
          contains "└" moneyText && contains "┴" moneyText)
    "money calendar did not render visible day-cell boundaries"

  let scrollBounds : Bounds := { width := 150, height := 15 }
  for (key, event) in [(Loam.Tui.Terminal.Key.up, Loam.Tui.Main.Event.up),
      (.down, .down), (.left, .left), (.right, .right)] do
    let moved ← requireSome (Loam.Tui.Home.navigationKey scrollBounds snapshot state key)
      "Home navigation key was not handled"
    expect (moved.selectedDate == (Loam.Tui.Main.update state event).state.selectedDate)
      "layout stole an arrow key from Calendar navigation"
  for b in [scrollBounds, { width := 80, height := 15 }] do
    let scrolled ← requireSome (Loam.Tui.Home.navigationKey b snapshot state (.ctrl 'd'))
      "Home lost Ctrl-D scrolling"
    expect (scrolled.overviewScroll > 0)
      "Home overview did not scroll in a short terminal"
    let scrolledText := widgetText (Loam.Tui.Home.view b snapshot scrolled)
    expect (contains "[Ctrl-u/d] scroll" scrolledText)
      "overflowing Home did not advertise its local scroll affordance"
    let resetStep := Loam.Tui.Main.update scrolled .right
    expect (resetStep.state.overviewScroll == 0 && resetStep.state.detailScroll == 0)
      "changing Home date did not reset the viewports"

  let mediumContentWidth := contentWidth mediumBounds
  for lineCells in mediumView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ mediumContentWidth)
      s!"150-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {mediumContentWidth})"

  -- 2c. Standard terminal (80 cols)
  let narrowBounds : Bounds := { width := 80, height := 24 }
  let narrowView := Loam.Tui.Home.view narrowBounds snapshot state
  let narrowText := widgetText narrowView
  expect (contains "┬" narrowText && contains "Mon" narrowText)
    "80-column Calendar Home lost its full money-grid geometry"
  expect (contains "± not requested" narrowText)
    "80-column Home fell back to the retired plain calendar"
  expect (!contains "Daily pace:" narrowText)
    "Calendar Home still duplicated Summary answers"
  for token in expectedTokens do
    expect (contains token narrowText)
      s!"80-column Home lost token {token}; must not be clipped"

  let narrowContentWidth := contentWidth narrowBounds
  for lineCells in narrowView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ narrowContentWidth)
      s!"80-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {narrowContentWidth})"


  -- Summary is a temporary glance, never a second calendar navigation state.
  let summaryState : Loam.Tui.Main.State := { state with homeMode := .summary }
  let summaryText := widgetText (Loam.Tui.Home.view narrowBounds snapshot summaryState)
  expect (contains "LOAM / Summary" summaryText)
    "Summary did not expose the short everyday glance"
  expect (contains "Upcoming Scheduled" summaryText && contains "Recent recorded Actual" summaryText)
    "Summary lost recorded entries and open payments"
  expect (!contains "Mon  Tue  Wed" summaryText)
    "Summary kept the small calendar"
  expect (contains "[g/Esc] back to calendar" summaryText && contains "[Space] commands" summaryText)
    "Summary did not offer calendar and command palette access"
  expect (!contains "[e] capacity" summaryText && !contains "[p] purpose routing" summaryText)
    "optional budget shortcuts leaked back to the Home footer"
  expect (contains "Attention: not requested" summaryText)
    "Summary lost the Attention read-state"
  let toCalendar ← requireSome
    (Loam.Tui.Home.navigationKey narrowBounds snapshot summaryState (.input 'g'))
    "Summary g did not return to Calendar"
  expect (toCalendar.homeMode == .calendar &&
          contains "┬" (widgetText (Loam.Tui.Home.view narrowBounds snapshot toCalendar)))
    "Summary g did not open the full-grid calendar"
  let toSummary ← requireSome
    (Loam.Tui.Home.navigationKey narrowBounds snapshot toCalendar (.input 'g'))
    "Calendar g did not open Summary"
  expect (toSummary.homeMode == .summary && toSummary.selectedDate == toCalendar.selectedDate)
    "Summary changed the preserved calendar date"
  expect (Loam.Tui.Home.navigationKey narrowBounds snapshot state (.input 'c')).isNone
    "retired c toggle is still active"
  let preserved : Loam.Tui.Main.State := { state with
    selectedDate := "2025-04-17"
    zoomLevel := .year
    overviewScroll := 3
    detailScroll := 5
    detailCursor := 2
    activePane := .detail
    notice := "preserve me" }
  let glance := Loam.Tui.Main.toggleHomeMode preserved
  expect (glance.homeMode == .summary &&
      (Loam.Tui.Home.reconcileState narrowBounds snapshot glance).detailScroll == 5)
    "Summary reconciled away the saved detail viewport"
  expect (Loam.Tui.Main.actionDate snapshot glance == snapshot.actual.today &&
      Loam.Tui.Main.actionDate snapshot preserved == preserved.selectedDate)
    "Summary actions did not use today independently of calendar focus"
  for key in [Loam.Tui.Terminal.Key.input 'g', .escape] do
    let restored ← requireSome
      (Loam.Tui.Home.navigationKey narrowBounds snapshot glance key)
      "Summary did not return with g/Esc"
    expect (restored.homeMode == .calendar && restored.selectedDate == preserved.selectedDate &&
        restored.zoomLevel == preserved.zoomLevel && restored.overviewScroll == 3 &&
        restored.detailScroll == 5 && restored.detailCursor == 2 &&
        restored.activePane == .detail && restored.notice == preserved.notice)
      "Summary return changed saved Calendar presentation state"
  let ignored ← requireSome
    (Loam.Tui.Home.navigationKey narrowBounds snapshot glance .right)
    "Summary arrow did not stay local"
  expect (ignored.selectedDate == preserved.selectedDate)
    "Summary arrow changed saved Calendar focus"
  expect (Loam.Tui.HomeCommandPalette.choiceAt? 0 ==
            some .budget &&
          Loam.Tui.HomeCommandPalette.choiceAt? 1 ==
            some .capacity &&
          Loam.Tui.HomeCommandPalette.choiceAt? 2 ==
            some .purposeRouting)
    "Home commands did not preserve all three optional budget actions"
  let commandText := widgetText (Loam.Tui.HomeCommandPalette.view narrowBounds 0)
  expect (contains "Budget / current cycle" commandText &&
          contains "Capacity / allocations" commandText &&
          contains "Purpose routing" commandText)
    "Home command palette hid an optional budget operation"
  expect (Loam.Tui.HomeCommandPalette.next 0 false == 1 &&
          Loam.Tui.HomeCommandPalette.next 1 false == 2 &&
          Loam.Tui.HomeCommandPalette.next 2 true == 1)
    "Home command palette selection does not navigate all actions"

  -- 3. Test SelectedDay footer geometry
  let selState := Loam.Tui.SelectedDay.initial "2026-09-10"
  let selBounds100 : Bounds := { width := 100, height := 30 }
  let selView100 := Loam.Tui.SelectedDay.view selBounds100 snapshot selState
  let selText100 := widgetText selView100
  expect (contains "[j/k] select" selText100) "SelectedDay lost navigation help"
  expect (contains "[g] loci" selText100)
    "SelectedDay compact Actual footer lost Manage Loci navigation"

  let selBounds130 : Bounds := { width := 130, height := 30 }
  let selView130 := Loam.Tui.SelectedDay.view selBounds130 snapshot selState
  let selText130 := widgetText selView130
  expect (contains "Actual/Scheduled" selText130)
    "SelectedDay at 130 cols should expose detailed pane switch"

  -- 4. Test ScheduledWorkspace footer geometry
  let schedState := Loam.Tui.ScheduledWorkspace.initialList "2026-09-10"
  let schedBounds80 : Bounds := { width := 80, height := 24 }
  let schedView80 := Loam.Tui.ScheduledWorkspace.view schedBounds80 snapshot schedState
  let schedText80 := widgetText schedView80
  expect (contains "[c/Enter] complete" schedText80)
    "ScheduledWorkspace at 80 cols must retain complete action in wrapped footer"

  -- 5. Current Quantity TUI remains a thin reconciliation-group observation adapter.
  let usdAnchor := Loam.Tui.CurrentQuantityAnchor.initialWithMeasure ⟨"usd"⟩
  expect (usdAnchor.form.measure == "usd")
    "Current Quantity Anchor did not retain the configured Measure"
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
  expect (contains "Unmentioned prior observations are preserved" previewText)
    "preview no longer explains incremental observation semantics"
  expect (contains "shared publisher derives the Event root cut" previewText)
    "preview no longer exposes the publisher-owned cut boundary"

  IO.println "TUI help/footer and current quantity observation boundary checks passed."
