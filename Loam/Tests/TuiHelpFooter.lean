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

  let shortcuts := shortcutRow [("j/k", "select"), ("Enter", "open"), ("q", "back")]
  expect (widgetText shortcuts == "[j/k] select  [Enter] open  [q] back")
    "shortcut row changed key/label spelling or grouping"
  let shortcutCells := shortcuts.lines.head!
  expect ((shortcutCells.take 5).all (fun cell => cell.style == .normal) &&
      ((shortcutCells.drop 5).take 9).all (fun cell => cell.style == .muted) &&
      ((shortcutCells.drop 14).take 7).all (fun cell => cell.style == .normal) &&
      shortcutCells.all (fun cell => cell.style == .normal || cell.style == .muted))
    "shortcut row colored labels, separators, or keys with a decorative accent"
  expect (widgetText (shortcutRow [("q", "")] " ") == "[q]")
    "compact shortcut row invented a label or trailing space"

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

  let expectedTokens := [
    "[h/l] day", "[k/j] week", "[Enter] open", "[r] record",
    "[a] actual", "[s] scheduled", "[i] attention", "[d] daily pace", "[b] balances",
    "[Space] commands", "[q] quit"
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
      contains "Commands" wideText)
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
    "empty Pending evidence disappeared from the calendar status"
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
  for token in ["[i] attention", "[d] daily pace", "[b] balances", "[Space] commands"] do
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
  for token in ["Month Flow (2026-09)", "Measure: jpy", "In: +¥12,000", "Out: -¥2,470", "Net: +¥9,530"] do
    expect (contains token moneyText) s!"money calendar lost its explicit monthly flow label: {token}"
  expect (!contains " = +¥9,530" moneyText && !contains "Out/day:" moneyText)
    "day calendar retained its unexplained summary or added a pace-like average"
  expect (contains "┌" moneyText && contains "┬" moneyText &&
          contains "│" moneyText && contains "┼" moneyText &&
          contains "└" moneyText && contains "┴" moneyText)
    "money calendar did not render visible day-cell boundaries"

  -- Today has one underline on its date row, never on amount or blank rows.
  for todaySnapshot in [snapshot, moneySnapshot] do
    let todayView := Loam.Tui.Home.view mediumBounds todaySnapshot state
    let underlinedRows := todayView.lines.filter fun cells =>
      cells.any fun cell => cell.style == .selectedUnderlined
    expect (underlinedRows.length == 1)
      "selected Today should underline only the date row, including when amounts are blank"
    expect (contains " 10" (String.ofList (underlinedRows.flatten.map Cell.glyph)))
      "selected Today lost its date-row underline"
  for amountText in ["+¥12,000", "-¥2,470"] do
    let amountRow ← requireSome (firstLineContaining? amountText moneyView.lines 0)
      "selected Today lost its daily amount row"
    let amountCells ← requireSome moneyView.lines[amountRow]?
      "selected Today amount row was not addressable"
    expect (amountCells.any (fun cell => cell.style == .selected) &&
      !amountCells.any (fun cell => cell.style == .selectedUnderlined))
      "selected Today amounts should retain selection background without underlines"

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
    "Calendar Home unexpectedly embedded Daily Pace answers"
  for token in expectedTokens do
    expect (contains token narrowText)
      s!"80-column Home lost token {token}; must not be clipped"

  let narrowContentWidth := contentWidth narrowBounds
  for lineCells in narrowView.lines do
    let lineStr := String.ofList (lineCells.map Cell.glyph)
    expect (displayWidth lineStr ≤ narrowContentWidth)
      s!"80-column line exceeded contentWidth: {lineStr} (width {displayWidth lineStr} vs {narrowContentWidth})"


  -- Home Summary and its shortcut are retired at every calendar zoom and pane.
  for bounds in [narrowBounds, mediumBounds, wideBounds] do
    for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
      for pane in [Loam.Tui.Main.HomePane.calendar, .detail] do
        let home := { state with zoomLevel := zoom, activePane := pane }
        let homeText := widgetText (Loam.Tui.Home.view bounds snapshot home)
        expect (!contains "[g]" homeText && !contains "LOAM / Summary" homeText &&
          !contains "Upcoming Scheduled" homeText && !contains "Recent recorded Actual" homeText)
          "retired Summary or its shortcut reappeared on Home"
        for token in ["[i] attention", "[d] daily pace", "[b] balances"] do
          expect (occurrences token homeText == 1)
            s!"Home lost or duplicated the direct shortcut {token} at a zoom/pane"
        for key in [Loam.Tui.Terminal.Key.input 'i', .input 'I', .input 'd', .input 'D', .input 'b', .input 'B'] do
          expect (Loam.Tui.Home.navigationKey bounds snapshot home key).isNone
            "Home navigation intercepted a direct analysis workspace entrance"
        for key in [Loam.Tui.Terminal.Key.input 'g', .input 'G', .input 'c'] do
          expect (Loam.Tui.Home.navigationKey bounds snapshot home key).isNone
            "retired Home mode shortcut is still active"
  expect (!contains "[e] capacity" narrowText && !contains "[p] purpose routing" narrowText)
    "optional budget shortcuts leaked back to the Home footer"
  -- The Home footer lists only habitual actions; rare workspaces are in Commands.
  for token in ["[x] exchange", "[u] settlements", "[v] reports",
      "[m] manage loci", "[o] observe quantities", "[y] copy screen",
      "[Shift+drag]"] do
    expect (!contains token wideText)
      s!"Home footer still advertises a palette-only or retired action: {token}"

  -- All five groups remain reachable. Only Enter on a leaf may dispatch.
  let commandRoot : Loam.Tui.HomeCommandPalette.State := {}
  let envelopes : Loam.Tui.HomeCommandPalette.State := { page := .envelopeBudget }
  for (index, page) in [
      (0, Loam.Tui.HomeCommandPalette.Page.transactions),
      (1, .planning), (2, .analysis), (3, .envelopeBudget), (4, .maintenance)] do
    for key in [Loam.Tui.Terminal.Key.enter, .right] do
      expect (Loam.Tui.HomeCommandPalette.update { commandRoot with selected := index } key ==
        .stay { page := page })
        "command root did not enter the selected group"
  for (index, choice) in [(0, Loam.Tui.HomeCommandPalette.Choice.budget),
      (1, .capacity), (2, .purposeRouting)] do
    let leaf := { envelopes with selected := index }
    expect (Loam.Tui.HomeCommandPalette.update leaf .enter == .open choice)
      "envelope budget leaf no longer opens its existing workspace"
    expect (Loam.Tui.HomeCommandPalette.update leaf .right == .stay leaf)
      "Right must never dispatch a leaf action"
  let transactionGroup : Loam.Tui.HomeCommandPalette.State := { page := .transactions }
  let planningGroup : Loam.Tui.HomeCommandPalette.State := { page := .planning }
  let analysisGroup : Loam.Tui.HomeCommandPalette.State := { page := .analysis }
  let maintenanceGroup : Loam.Tui.HomeCommandPalette.State := { page := .maintenance }
  for (group, choices) in [
      (transactionGroup, [Loam.Tui.HomeCommandPalette.Choice.record, .actual, .exchange]),
      (planningGroup, [.scheduled, .attention, .settlements]),
      (analysisGroup, [.dailyPace, .balances, .report .incomeExpense,
        .report .transactionsFlow, .report .stockFlow, .report .locusTrendCompare,
        .report .balances, .report .liquidity, .report .budgetWindow,
        .report .multimeasureSpend, .report .favaProjection]),
      (maintenanceGroup, [.manageLoci, .observeQuantities])] do
    for (choice, index) in choices.zipIdx do
      let leaf := { group with selected := index }
      expect (Loam.Tui.HomeCommandPalette.update leaf .enter == .open choice &&
        Loam.Tui.HomeCommandPalette.update leaf .right == .stay leaf)
        "grouped command did not dispatch only on Enter"
  for key in [Loam.Tui.Terminal.Key.left, .escape, .input 'q', .input 'Q', .input ' '] do
    for group in [envelopes, transactionGroup, planningGroup, analysisGroup, maintenanceGroup] do
      expect (Loam.Tui.HomeCommandPalette.update { group with selected := 2 } key ==
        .stay commandRoot)
        "group back key did not return to root"
    expect (Loam.Tui.HomeCommandPalette.update commandRoot key == .close)
      "root back key did not close palette"
  for key in [Loam.Tui.Terminal.Key.down, .input 'j', .input 'J'] do
    expect (Loam.Tui.HomeCommandPalette.update commandRoot key ==
      .stay { commandRoot with selected := 1 } &&
      Loam.Tui.HomeCommandPalette.update { commandRoot with selected := 4 } key ==
        .stay { commandRoot with selected := 4 })
      "root selection did not move or clamp"
    expect (Loam.Tui.HomeCommandPalette.update envelopes key ==
      .stay { envelopes with selected := 1 } &&
      Loam.Tui.HomeCommandPalette.update { envelopes with selected := 2 } key ==
        .stay { envelopes with selected := 2 })
      "envelope selection did not move or clamp"
  for key in [Loam.Tui.Terminal.Key.up, .input 'k', .input 'K'] do
    expect (Loam.Tui.HomeCommandPalette.update { envelopes with selected := 2 } key ==
      .stay { envelopes with selected := 1 } &&
      Loam.Tui.HomeCommandPalette.update envelopes key == .stay envelopes)
      "envelope selection did not move back or clamp at first"
  for key in [Loam.Tui.Terminal.Key.other, .input 'x'] do
    for group in [commandRoot, envelopes, transactionGroup, analysisGroup] do
      expect (Loam.Tui.HomeCommandPalette.update group key == .stay group)
        "unhandled command key changed local navigation"
  let invalidSelection := { envelopes with selected := 3 }
  for key in [Loam.Tui.Terminal.Key.enter, .right] do
    expect (Loam.Tui.HomeCommandPalette.update invalidSelection key == .stay invalidSelection)
      "invalid palette index dispatched a household action"
  for bounds in [narrowBounds, mediumBounds, { width := 40, height := 24 }] do
    let rootView := Loam.Tui.HomeCommandPalette.view bounds commandRoot
    let envelopeView := Loam.Tui.HomeCommandPalette.view bounds envelopes
    let rootText := widgetText rootView
    let envelopeText := widgetText envelopeView
    for label in ["Transactions →", "Plans and attention →", "Reports and analysis →",
        "Envelope budget →", "Household setup →"] do
      expect (contains label rootText) s!"palette root lost group: {label}"
    expect (contains "Commands / Envelope budget" envelopeText &&
      contains "Budget / current cycle" envelopeText &&
      contains "Capacity / allocations" envelopeText && contains "Purpose routing" envelopeText &&
      contains "Esc back" envelopeText)
      "envelope group lost its existing actions"
    expect (rootView.lines.length == 13 && envelopeView.lines.length == 13)
      "command pages lost fixed-height geometry"
    for selectedState in [commandRoot, { commandRoot with selected := 4 },
        envelopes, { envelopes with selected := 2 }, transactionGroup, maintenanceGroup] do
      let selectedView := Loam.Tui.HomeCommandPalette.view bounds selectedState
      let selectedRows := selectedView.lines.filter fun cells =>
        cells.any fun cell => cell.style == .selected
      expect (selectedRows.length == 1)
        "command palette must highlight exactly the selected item"
      let selectedCells ← requireSome selectedRows.head?
        "command palette lost its selected row"
      let innerWidth := min 54 (contentWidth bounds) - 2
      expect ((selectedCells.drop 1 |>.take innerWidth).all
        (fun cell => cell.style == .selected))
        "command selection highlight ended before panel edge"
      expect ((selectedCells.take 1 ++ selectedCells.drop (innerWidth + 1)).all
        (fun cell => cell.style == .muted))
        "command selection leaked onto border"
      if selectedState.page == .commands then
        let arrowAndPadding := selectedCells.dropWhile (fun cell => cell.glyph != '→')
        expect (arrowAndPadding.length > 2 &&
          (arrowAndPadding.take 2).all (fun cell => cell.style == .selected))
          "command group arrow lost highlight padding"
    for pageView in [rootView, envelopeView] do
      let pageText := widgetText pageView
      expect (contains "↑/↓ select" pageText && contains "→ group" pageText &&
        contains "← back" pageText && contains "Enter open" pageText)
        "command page hid navigation help"
      for cells in pageView.lines do
        expect (displayWidth (String.ofList (cells.map Cell.glyph)) ==
          min 54 (contentWidth bounds))
          "command page lost fixed-width padding"

  -- Every analysis leaf stays selected/visible at every usable terminal height.
  for width in [1, 2, 8, 32, 48, 80, 120] do
    for height in List.range 20 do
      for index in List.range 11 do
        let bounds : Bounds := { width, height }
        let leaf := { analysisGroup with selected := index }
        let rendered := Loam.Tui.HomeCommandPalette.view bounds leaf
        expect (rendered.lines.length <= height)
          "palette exceeded terminal height"
        for cells in rendered.lines do
          expect (displayWidth (String.ofList (cells.map Cell.glyph)) <= contentWidth bounds)
            "palette exceeded terminal width"
        if height > 0 && contentWidth bounds > 0 then
          expect ((rendered.lines.filter fun cells =>
            cells.any fun cell => cell.style == .selected).length == 1)
            "long palette lost selected row on compact/degenerate geometry"
  for key in [Loam.Tui.Terminal.Key.down, .input 'j'] do
    expect (Loam.Tui.HomeCommandPalette.update { analysisGroup with selected := 10 } key ==
      .stay { analysisGroup with selected := 10 }) "analysis selection exceeded eleven entries"
  for key in [Loam.Tui.Terminal.Key.up, .input 'k'] do
    expect (Loam.Tui.HomeCommandPalette.update { analysisGroup with selected := 10 } key ==
      .stay { analysisGroup with selected := 9 }) "analysis reverse navigation failed"
  for (destination, index) in Loam.Tui.Reports.Destination.all.zipIdx do
    let text := widgetText (Loam.Tui.HomeCommandPalette.view { width := 80, height := 13 }
      { analysisGroup with selected := index + 2 })
    expect (contains destination.label text) "analysis viewport hid a report label"

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
