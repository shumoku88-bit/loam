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
  expect (state.calendarMode == .plain)
    "Home calendar did not default to the quiet plain lens"
  let moneyState := Loam.Tui.Main.toggleCalendarMode state
  expect (moneyState.calendarMode == .money)
    "Home calendar toggle did not enter the money lens"
  expect ((Loam.Tui.Main.toggleCalendarMode moneyState).calendarMode == .plain)
    "Home calendar toggle did not return to the plain lens"

  let expectedTokens := [
    "[h/l] day", "[k/j] week", "[t] today", "[f] flow", "[Enter] open", "[r] record",
    "[a] actual", "[s] scheduled", "[d] pace", "[i] attention", "[b] balances", "[u] settlements", "[c] daily",
    "[Space] commands", "[m] manage loci", "[o] observe quantities",
    "[v] reports", "[q] quit"
  ]

  -- 2a. Wide terminal
  let wideBounds : Bounds := { width := 190, height := 45 }
  let wideView := Loam.Tui.Home.view wideBounds snapshot state
  let wideText := widgetText wideView
  let wideCalendarEnd ← requireSome
    (firstLineContaining? "underline = today" wideView.lines 0)
    "wide Home lost the calendar Today legend"
  let widePaceLine ← requireSome
    (firstLineContaining? "Daily pace" wideView.lines 0)
    "wide Home lost Daily Pace"
  expect (wideCalendarEnd < widePaceLine)
    "wide Home moved Daily Pace away from the space below the calendar"
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
  -- Glance answers now live inside the left calendar pane, so they do
  -- not consume an outer frame row.
  let expectedWidePanelRows := footerBodyCapacity wideBounds 5 - 4
  expect (occurrences " │ " wideText == expectedWidePanelRows)
    "wide Home divider height changed with content instead of filling the fixed viewport"
  for token in ["[d] pace", "[i] attention", "[b] balances", "[u] settlements", "[c] daily",
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
  let moneyView := Loam.Tui.Home.view mediumBounds moneySnapshot moneyState
  let moneyText := widgetText moneyView
  expect (contains "[f] calendar" moneyText && !contains "[f] flow" moneyText)
    "money calendar footer did not advertise the return-to-calendar action"
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
  let narrowCalendarEnd ← requireSome
    (firstLineContaining? "underline = today" narrowView.lines 0)
    "narrow Home lost the calendar Today legend"
  let narrowPaceLine ← requireSome
    (firstLineContaining? "Daily pace" narrowView.lines 0)
    "narrow Home lost Daily Pace"
  expect (narrowCalendarEnd < narrowPaceLine)
    "narrow Home moved Daily Pace away from the space below the calendar"
  for token in expectedTokens do
    expect (contains token narrowText)
      s!"80-column Home lost token {token}; must not be clipped"

  let narrowContentWidth := contentWidth narrowBounds
  for lineCells in narrowView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ narrowContentWidth)
      s!"80-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {narrowContentWidth})"


  -- 2d. Daily glance is quiet, and the calendar remains one reversible key away.
  let dailyState : Loam.Tui.Main.State := { state with homeMode := .daily }
  let dailyText := widgetText (Loam.Tui.Home.view narrowBounds snapshot dailyState)
  expect (contains "LOAM / Today" dailyText)
    "Daily Home did not expose the short everyday glance"
  expect (contains "Next payments" dailyText && contains "Recent recorded Actual" dailyText)
    "Daily Home lost confirmation of recorded entries and open payments"
  expect (!contains "Mon  Tue  Wed" dailyText)
    "Daily Home kept the small calendar in the everyday glance"
  expect (contains "[c] calendar" dailyText && contains "[Space] commands" dailyText)
    "Daily Home did not offer calendar and command palette access"
  expect (!contains "[e] capacity" dailyText && !contains "[p] purpose routing" dailyText)
    "optional budget shortcuts leaked back to the Home footer"
  let toCalendar ← requireSome
    (Loam.Tui.Home.navigationKey narrowBounds snapshot dailyState (.input 'c'))
    "Daily c did not switch to the calendar"
  expect (toCalendar.homeMode == .calendar &&
          contains "Mon  Tue  Wed" (widgetText (Loam.Tui.Home.view narrowBounds snapshot toCalendar)))
    "Daily c did not restore the original date navigator"
  let toDaily ← requireSome
    (Loam.Tui.Home.navigationKey narrowBounds snapshot toCalendar (.input 'c'))
    "Calendar c did not return to Daily"
  expect (toDaily.homeMode == .daily && toDaily.selectedDate == snapshot.actual.today)
    "Calendar c failed to return to today's glance"
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
