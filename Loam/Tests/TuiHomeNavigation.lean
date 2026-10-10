import Loam.Tui.Home
import Loam.Tui.SelectedDay

open Loam.Core Loam.Tui.Kernel Loam.Tui.Main

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def rowIndex? (needle : String) (view : Widget) : Option Nat :=
  (view.lines.zipIdx.find? fun (cells, _) =>
    contains needle (String.ofList (cells.map Cell.glyph))).map Prod.snd

private def compactText (view : Widget) : String :=
  String.ofList (view.lines.flatten.map Cell.glyph |>.filter fun char =>
    char != ' ' && char != '\n' && char != '│')

private def press (bounds : Bounds) (snapshot : Snapshot) (state : State)
    (key : Loam.Tui.Terminal.Key) : IO State :=
  requireSome (Loam.Tui.Home.navigationKey bounds snapshot state key) "unhandled local key"

private def fixture : IO Snapshot := do
  let records ← (List.range 12).mapM fun i => do
    let id := s!"event-{i}"
    let event ← requireSome (Event.ofEffects? ⟨id⟩
      [ Effect.ofQuantity ⟨id ++ "-wallet"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-310))
      , Effect.ofQuantity ⟨id ++ "-food"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 310)
      ]) "event fixture"
    pure ({
      event
      date := some (if i < 10 then "2026-10-01" else "2026-09-01")
      description := s!"RECORD-{i}#"
      replacement := none
    } : ReviewRecord)
  let roles ← requireSome (AccountingRoleMap.ofAssignments?
    [{locus := ⟨"wallet"⟩, role := .asset}, {locus := ⟨"food"⟩, role := .expense}]) "roles fixture"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? []) "Scheduled fixture"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? []) "terminal fixture"
  let events ← requireSome (EventMemory.ofEvents? []) "Event memory fixture"
  let flow := Loam.CalendarMoneyReview.project records roles
  -- USD unresolved evidence must not disappear behind the alphabetically first measure.
  let flow := { flow with rows := flow.rows ++ [{
    date := "2026-10-01"
    measure := ⟨"usd"⟩
    income := Quantity.ofQuanta 0
    expense := Quantity.ofQuanta 100
    unresolvedEffectCount := 2
  }] }
  pure {
    actual := {today := "2026-10-01", allRecords := records}
    scheduled := .ok {scheduled, terminals, events}
    moneyCalendar := .loaded {flow, presentation := []}
  }

/-- Collect actual rendered viewports, not private summary strings. -/
private def browseOverview (bounds : Bounds) (snapshot : Snapshot) (state : State) : IO String := do
  let mut state := state
  let mut seen := ""
  for _ in List.range 30 do
    seen := seen ++ "\n" ++ text (Loam.Tui.Home.view bounds snapshot state)
    state ← press bounds snapshot state (.ctrl 'd')
  pure seen

def main : IO Unit := do
  let snapshot ← fixture
  let base : State := {selectedDate := "2026-10-01", zoomLevel := .month}
  let wide : Bounds := {width := 150, height := 45}

  -- Quiet frames and stable feedback: one-line notices cannot move borders/help.
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24}, wide] do
    for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
      for pane in [Loam.Tui.Main.HomePane.calendar, .detail] do
        let state := {base with zoomLevel := zoom, activePane := pane}
        let before := Loam.Tui.Home.view bounds snapshot state
        let after := Loam.Tui.Home.view bounds snapshot {state with notice := "Saved."}
        expect (contains "╭" (text before) && contains "╰" (text before) &&
          !contains "====" (text before)) "Home retained heavy rules or lost rounded frames"
        expect (before.lines.length == bounds.height - 1 && after.lines.length == before.lines.length)
          "Home feedback changed frame height"
        expect (rowIndex? "╭" before == rowIndex? "╭" after &&
          rowIndex? "╰" before == rowIndex? "╰" after &&
          rowIndex? "[q]" before == rowIndex? "[q]" after)
          "short feedback moved panes or navigation"
        expect (contains "Saved." (text after)) "short feedback was hidden"
        expect (before.lines.flatten.all fun cell =>
          cell.style == .normal || cell.style == .muted || cell.style == .series1 ||
          cell.style == .selected || cell.style == .selectedUnderlined || cell.style == .underlined)
          "Home introduced a decorative accent"
        for cells in before.lines do
          expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
            "compact Home exceeded its writable width"
        if pane == .detail then
          expect (contains "▶ - " (text before)) "compact Detail hid the selected record"
  let notice := String.ofList (List.replicate 65 '界') ++ "通知末尾"
  let feedbackView := Loam.Tui.Home.view {width := 48, height := 14} snapshot {base with notice}
  expect (contains notice (compactText feedbackView)) "long feedback lost its complete cause"
  let enormousNotice := String.ofList (List.replicate 600 '界')
  let overflow := Loam.Tui.Home.view {width := 48, height := 14} snapshot {base with notice := enormousNotice}
  expect (overflow.lines.length == 13 && contains "more feedback/help; enlarge terminal" (text overflow))
    "over-height feedback was silently truncated"

  -- Small calendars follow the selected date; explicit scrolling remains free.
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24}, {width := 120, height := 20}] do
    let state := {base with selectedDate := "2026-10-31", zoomLevel := .day}
    let view := Loam.Tui.Home.view bounds snapshot state
    let focusRows := view.lines.filter fun cells => cells.any fun cell => cell.style == .selected
    expect (contains "31" (String.ofList (focusRows.flatten.map Cell.glyph)))
      "short calendar hid its selected date"
    let mut scrolled := state
    for _ in List.range 10 do
      scrolled ← press bounds snapshot scrolled (.ctrl 'u')
    expect (scrolled.overviewManualScroll && scrolled.overviewScroll == 0 &&
      scrolled.selectedDate == state.selectedDate) "manual overview browsing changed date or snapped back"
    expect (contains "Mon" (text (Loam.Tui.Home.view bounds snapshot scrolled)))
      "manual overview browsing could not reach the calendar header"
    let moved ← press bounds snapshot scrolled (.input 'h')
    expect (!moved.overviewManualScroll && moved.overviewScroll == 0)
      "date navigation did not resume focus-following"
    expect (contains "30" (String.ofList ((Loam.Tui.Home.view bounds snapshot moved).lines.filter
      (fun cells => cells.any fun cell => cell.style == .selected) |>.flatten.map Cell.glyph)))
      "date navigation left calendar focus outside its viewport"

  -- All entrances use the same reset, including shrinking the record set via Enter/Esc.
  for key in [Loam.Tui.Terminal.Key.enter, .escape, .input 'z'] do
    let stale : State := {base with
      zoomLevel := .year
      detailCursor := 11
      detailScroll := 100
      overviewScroll := 5
    }
    let next ← press wide snapshot stale key
    expect (next.detailCursor == 0 && next.detailScroll == 0 && next.overviewScroll == 0)
      "zoom retained stale selection/scroll"
    expect (next.activePane == .calendar) "zoom retained hidden detail focus"
  let today ← press wide snapshot {base with detailCursor := 9, activePane := .detail} (.input 't')
  expect (today.detailCursor == 0 && today.activePane == .calendar) "today retained detail selection"

  -- Render/select/open agree at both sides of the layout breakpoint and short heights.
  for width in [80, 100, 119, 120, 150] do
    for height in [20, 30, 45] do
      let bounds : Bounds := {width, height}
      for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
        let focused ← press bounds snapshot {base with zoomLevel := zoom} .tab
        let moved ← press bounds snapshot focused (.ctrl 'd')
        expect (moved.detailCursor == 5) "page did not move selection"
        let last := Loam.Tui.Home.moveDetailCursor bounds snapshot moved 100
        let record ← requireSome (selectedDetailRecord? snapshot last) "selected record missing"
        let view := Loam.Tui.Home.view bounds snapshot last
        expect (contains ("▶ - " ++ (if zoom == .day then "" else record.date.getD "" ++ "  ") ++ record.description) (text view))
          s!"selected title hidden at {width}x{height}"
        expect (view.lines.length ≤ height - 1) "Home exceeded terminal height"
        for cells in view.lines do
          expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ width - 1)
            s!"Home exceeded terminal width at {width}x{height}"
        expect (Loam.Tui.Home.navigationKey bounds snapshot last .enter |>.isNone)
          "detail Enter did not delegate to workspace"
        let hStayed ← press bounds snapshot last (.input 'h')
        expect (hStayed.activePane == .detail && hStayed.selectedDate == last.selectedDate)
          "detail h unexpectedly changed focus or date"
        let lStayed ← press bounds snapshot last (.input 'l')
        expect (lStayed.activePane == .detail && lStayed.selectedDate == last.selectedDate)
          "detail l unexpectedly changed focus or date"
        let tabBack ← press bounds snapshot last .tab
        expect (tabBack.activePane == .calendar) "Tab did not leave detail"
        let wBack ← press bounds snapshot last (.input 'w')
        expect (wBack.activePane == .calendar) "w did not leave detail"
        let day ← requireSome (Loam.Tui.SelectedDay.initialForActual? snapshot record)
          "selected transaction cannot open its day workspace"
        expect (day.focusDate == record.date.getD "") "opened another date"
        let opened ← requireSome (Loam.Tui.SelectedDay.selectedActual? snapshot day) "workspace lost selection"
        expect (opened.event.id == record.event.id) "workspace opened a different transaction"
        let back ← press bounds snapshot last .escape
        expect (back.activePane == .calendar) "Escape did not leave detail"

  -- An oversized record must not scroll its own selected title out of view.
  let effects := (List.range 40).map fun i =>
    Effect.ofQuantity ⟨s!"large-{i}"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 1)
  let largeEvent ← requireSome (Event.ofEffects? ⟨"large"⟩
    (Effect.ofQuantity ⟨"large-wallet"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-40)) :: effects))
    "oversized event fixture"
  let largeRecord : ReviewRecord := {
    event := largeEvent
    date := some "2026-10-01"
    description := "OVERSIZED"
    replacement := none
  }
  let large := {snapshot with actual := {snapshot.actual with allRecords := [largeRecord]}}
  for width in [80, 120] do
    let bounds : Bounds := {width, height := 20}
    let selected ← press bounds large base .tab
    expect (contains "▶ - 2026-10-01  OVERSIZED" (text (Loam.Tui.Home.view bounds large selected)))
      "oversized selected record hid its title"

  -- Wrapped CJK descriptions and exact oversized Effects share selection geometry.
  let huge : Int := 12345678901234567890123456789012345678901234567890123456789012345678901234567890
  let longLocus := String.ofList (List.replicate 30 '界') ++ "-end"
  let longDescription := "長い説明先頭" ++ String.ofList (List.replicate 70 '界') ++ "説明末尾"
  let longEvent ← requireSome (Event.ofEffects? ⟨"wrapped"⟩
    [Effect.ofQuantity ⟨"wrapped-from"⟩ ⟨longLocus⟩ ⟨"usd"⟩ (Quantity.ofQuanta (-huge)),
     Effect.ofQuantity ⟨"wrapped-to"⟩ ⟨"food"⟩ ⟨"usd"⟩ (Quantity.ofQuanta huge)]) "wrapped event"
  let longRecord : ReviewRecord := {
    event := longEvent, date := some "2026-10-01"
    description := longDescription, replacement := none}
  let wrappedSnapshot := {snapshot with actual := {snapshot.actual with allRecords := [longRecord]}}
  let wrappedState := {base with activePane := .detail}
  let fullView := Loam.Tui.Home.view {width := 80, height := 80} wrappedSnapshot wrappedState
  let joined := compactText fullView
  expect (contains longDescription joined && contains longLocus joined)
    "wrapped Detail lost Japanese description or Locus text"
  let grouped := Loam.MeasurePresentation.formatGroupedQuanta [] ⟨"usd"⟩ huge
  expect (contains ("+" ++ grouped ++ "usd") joined && contains ("-" ++ grouped ++ "usd") joined)
    "wrapped Detail truncated or changed exact signed quantities"
  let .loaded calendarMoney := snapshot.moneyCalendar | throw (IO.userError "calendar money fixture")
  let moneyReads : List (Loam.Presentation.ReadState MoneyCalendarSnapshot) :=
    [.loaded {calendarMoney with presentation := [{measure := ⟨"usd"⟩, scale := 2}]},
     .unavailable, .failed "role map unreadable"]
  for moneyCalendar in moneyReads do
    let observed := Loam.Tui.Home.view {width := 80, height := 80}
      {wrappedSnapshot with moneyCalendar} wrappedState
    expect (contains ("+" ++ grouped ++ "usd") (compactText observed))
      "optional money-calendar availability changed retained Detail quanta"
  for width in [48, 80, 120, 150] do
    let bounds : Bounds := {width, height := 20}
    let selected := Loam.Tui.Home.moveDetailCursor bounds wrappedSnapshot wrappedState 0
    expect (contains "▶ - 2026-10-01  長い説明先頭" (text (Loam.Tui.Home.view bounds wrappedSnapshot selected)))
      "wrapped oversized record hid its selected title"
    expect ((selectedDetailRecord? wrappedSnapshot selected).map (fun record => record.event.id) == some longEvent.id)
      "wrapped presentation changed selected identity"
  let hugeMoney := {snapshot with moneyCalendar := .loaded {
    presentation := []
    flow := {rows := [{
      date := "2026-10-01", measure := ⟨"usd"⟩
      income := Quantity.ofQuanta 0, expense := Quantity.ofQuanta huge, unresolvedEffectCount := 0}]}
  }}
  let calendar := Loam.Tui.Home.view {width := 150, height := 45} hugeMoney {base with zoomLevel := .day}
  expect (contains "…" (text calendar)) "calendar silently clipped an oversized daily amount"

  -- Prepared rows are a projection, not another selection/evidence owner. The same
  -- cache survives rapid reversals and height-only resize; width/period changes rebuild.
  for source in [snapshot, wrappedSnapshot, large] do
    for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
      let start := {base with zoomLevel := zoom, activePane := .detail}
      let cache := some (Loam.Tui.Home.prepareDetail wide source start)
      let mut cachedState := start
      let mut freshState := start
      for key in [Loam.Tui.Terminal.Key.down, .down, .up, .pageDown, .pageUp,
          .home, .«end», .up, .escape, .tab] do
        cachedState ← requireSome (Loam.Tui.Home.navigationKey wide source cachedState key 1 cache)
          "cached navigation unhandled"
        freshState ← press wide source freshState key
        expect (cachedState.detailCursor == freshState.detailCursor &&
          cachedState.detailScroll == freshState.detailScroll &&
          cachedState.activePane == freshState.activePane) "prepared geometry changed navigation"
        expect ((Loam.Tui.Home.view wide source cachedState cache).lines ==
          (Loam.Tui.Home.view wide source freshState).lines) "prepared viewport changed cells/styles"
      for bounds in [{width := 150, height := 14}, {width := 48, height := 14},
          {width := 119, height := 24}, {width := 120, height := 20}] do
        expect ((Loam.Tui.Home.view bounds source cachedState cache).lines ==
          (Loam.Tui.Home.view bounds source cachedState).lines) "resize retained stale wrapping"
      for changed in [{start with selectedDate := "2026-09-01"},
          {start with zoomLevel := .year}, {start with zoomLevel := .day}] do
        expect ((Loam.Tui.Home.view wide source changed cache).lines ==
          (Loam.Tui.Home.view wide source changed).lines) "period change retained stale rows"
  let longRecords := (List.range 2000).map fun i =>
    {longRecord with description := s!"LONG-{i}"}
  let longSnapshot := {snapshot with actual := {snapshot.actual with allRecords := longRecords}}
  let longState := {base with zoomLevel := .year, activePane := .detail}
  let longCache := some (Loam.Tui.Home.prepareDetail wide longSnapshot longState)
  let batched ← requireSome
    (Loam.Tui.Home.navigationKey wide longSnapshot longState .down 37 longCache) "wheel batch"
  let mut individual := longState
  for _ in List.range 37 do
    individual ← requireSome
      (Loam.Tui.Home.navigationKey wide longSnapshot individual (.input 'j') 1 longCache) "key burst"
  expect (batched.detailCursor == 37 && individual.detailCursor == 37 &&
    batched.detailScroll == individual.detailScroll) "wheel/key count or geometry diverged"
  let reversed ← requireSome
    (Loam.Tui.Home.navigationKey wide longSnapshot batched .up 37 longCache) "reverse batch"
  expect (reversed.detailCursor == 0 && reversed.detailScroll ≤ 1 &&
    contains "▶ - 2026-10-01  LONG-1999" (text (Loam.Tui.Home.view wide longSnapshot reversed longCache)))
    "rapid reversal did not return to the visible first record"

  -- Reloads can remove a selected transaction. Rendering and Enter must use the same clamp.
  let fresh := {snapshot with actual := {snapshot.actual with allRecords := snapshot.actual.allRecords.take 2}}
  let state := Loam.Tui.Home.reconcileState wide fresh {base with activePane := .detail, detailCursor := 9}
  expect (state.detailCursor == 1 && (selectedDetailRecord? fresh state).isSome)
    "reload left an invalid cursor"
  let empty := {fresh with actual := {fresh.actual with allRecords := []}}
  let emptyState := Loam.Tui.Home.reconcileState wide empty state
  expect (emptyState.detailCursor == 0 && (selectedDetailRecord? empty emptyState).isNone)
    "empty reload manufactured a selection"

  -- Numeric month labels retain selection/Today styles and complete counts through
  -- width reflow. Browse actual viewports to include every quarter on short screens.
  let monthLabels := ["01 Jan", "02 Feb", "03 Mar", "04 Apr", "05 May", "06 Jun",
    "07 Jul", "08 Aug", "09 Sep", "10 Oct", "11 Nov", "12 Dec"]
  for bounds in [{width := 32, height := 14}, {width := 48, height := 14},
      {width := 80, height := 24}, {width := 120, height := 20}, wide] do
    let rendered ← browseOverview bounds snapshot {base with
      selectedDate := "2026-01-01", overviewManualScroll := true}
    for label in monthLabels do
      expect (contains label rendered) s!"month label clipped at {bounds.width}: {label}"
    expect (contains "10t" rendered && contains "2t" rendered) "month reflow lost exact counts"
    for month in List.range 12 do
      let date := Loam.Tui.Calendar.dateForDay {year := 2026, month := month + 1} 1
      let state := {base with selectedDate := date}
      let view := Loam.Tui.Home.view bounds snapshot state
      let selected := view.lines.flatten.filter fun cell =>
        cell.style == .selected || cell.style == .selectedUnderlined
      expect (contains ("[" ++ monthLabels[month]! ++ "]")
        (String.ofList (selected.map Cell.glyph))) "month selection hidden after reflow"
      let today := view.lines.flatten.filter fun cell =>
        cell.style == .underlined || cell.style == .selectedUnderlined
      if month == 9 then
        expect (contains "10 Oct" (String.ofList (today.map Cell.glyph)))
          "current month lost its underline"

  -- Exact per-measure sums, explicit uncertainty, and no layout-dependent read semantics.
  for bounds in [wide, {width := 48, height := 14}, {width := 80, height := 24}, {width := 120, height := 20}] do
    for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
      let state := {base with zoomLevel := zoom}
      let rendered ← browseOverview bounds snapshot state
      for token in ["Measure: jpy", "Measure: usd [partial]", "In: +¥0", "Out: -$100",
          "? 2 unresolved effects", "Net: -¥", if zoom == .year then "Year Flow (2026)" else "Month Flow (2026-10)"] do
        expect (contains token rendered) s!"period overview lost {token}"
      expect (contains (if zoom == .year then "Out: -¥3,720" else "Out: -¥3,100") rendered)
        "period sum changed or mixed measures"
      if zoom != .day then
        expect (contains "(full" rendered && !contains "[h/l] day" rendered && !contains "[k/j] week" rendered)
          "zoom footer advertised daily navigation or lost its existing average"
      else
        expect (!contains "Out/day:" rendered && !contains "(full month)" rendered)
          "day footer added a pace-like average"
      let cases : List (Loam.Presentation.ReadState MoneyCalendarSnapshot × String) :=
        [(.notRequested, "flow not requested"), (.unavailable, "flow unavailable"),
         (.failed "role-map broken", "flow read failed"),
         (.loaded {flow := {rows := []}, presentation := []}, "No recorded income/expense flow.")]
      for (availability, marker) in cases do
        let observed ← browseOverview bounds {snapshot with moneyCalendar := availability} state
        expect (contains marker observed) s!"availability collapsed: {marker}"
        if marker == "flow read failed" then
          expect (contains "role-map broken" observed) "read diagnostic disappeared"

  -- Day flow failures also preserve complete diagnostics through overview scrolling.
  let failure := "read-failed-" ++ String.ofList (List.replicate 90 '界') ++ "-tail"
  let failed := {snapshot with moneyCalendar := .failed failure}
  let rendered ← browseOverview {width := 80, height := 24} failed {base with zoomLevel := .day}
  expect (contains "read failed" rendered && contains "-tail" rendered)
    "day calendar collapsed a failed read or hid its diagnostic tail"

  -- Positive/negative directions and Net reuse the existing summary, including
  -- reversal-shaped rows. Long exact numbers wrap without losing digits.
  let signedMoney := {snapshot with moneyCalendar := .loaded {
    presentation := []
    flow := {rows := [{
      date := "2026-10-01", measure := ⟨"usd"⟩
      income := Quantity.ofQuanta (-25), expense := Quantity.ofQuanta (-100), unresolvedEffectCount := 0
    }, {
      date := "2026-09-30", measure := ⟨"usd"⟩
      income := Quantity.ofQuanta 999, expense := Quantity.ofQuanta 0, unresolvedEffectCount := 0
    }]}
  }}
  for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month] do
    let rendered ← browseOverview {width := 48, height := 14} signedMoney {base with zoomLevel := zoom}
    for token in ["Month Flow (2026-10)", "Measure: usd", "In: +$100", "Out: -$25", "Net: +$75"] do
      expect (contains token rendered) s!"directional sign/window changed: {token}"
  for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
    let rendered := compactText (Loam.Tui.Home.view {width := 48, height := 200}
      hugeMoney {base with zoomLevel := zoom, overviewManualScroll := true})
    expect (contains ("Out:-$" ++ Loam.MeasurePresentation.groupDisplayedNumber (toString huge)) rendered &&
      contains ("Net:-$" ++ Loam.MeasurePresentation.groupDisplayedNumber (toString huge)) rendered)
      "flow footer lost oversized exact digits"

  -- Presentation scales remain attached to their measure, including rounded averages.
  let .loaded money := snapshot.moneyCalendar | throw (IO.userError "money fixture")
  let scaled := {snapshot with moneyCalendar := .loaded {money with
    presentation := [{measure := ⟨"usd"⟩, scale := 2}]
  }}
  for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month] do
    let scaledText ← browseOverview wide scaled {base with zoomLevel := zoom}
    expect (contains "Out: -$1.00" scaledText && contains "Net: -$1.00" scaledText)
      "USD summary ignored presentation scale"
    if zoom == .month then
      expect (contains "Out/day: ~$0.03" scaledText) "existing average changed"
    expect (contains "Measure: usd [partial]" scaledText) "partial sum looked complete"

  -- Lexical period bounds also include December in the last supported year.
  let lastYear := {snapshot with moneyCalendar := .loaded {money with
    flow := {rows := money.flow.rows.map fun row => {row with date := "9999-12-31"}}
  }}
  for zoom in [Loam.Tui.DateJump.ZoomLevel.day, .month, .year] do
    let rendered ← browseOverview wide lastYear {base with selectedDate := "9999-12-31", zoomLevel := zoom}
    expect (contains "Out: -¥3,720" rendered && contains "Out: -$100" rendered)
      "last supported period lost flow"

  -- With no Actual rows, paging still exposes non-selectable pending evidence.
  let movement ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩
    [{coordinate := ⟨"wallet"⟩, quantity := Quantity.ofQuanta (-1)},
     {coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 1}]) "pending movement"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? ((List.range 20).map fun i =>
    {id := ⟨s!"pending-{i}"⟩, scheduledOn := "2026-09-01", movement := movement})) "pending memory"
  let .ok evidence := snapshot.scheduled | throw (IO.userError "pending evidence")
  let pendingOnly := {empty with scheduled := .ok {evidence with scheduled := scheduled}}
  for width in [80, 120] do
    let bounds : Bounds := {width, height := 20}
    let focused ← press bounds pendingOnly {base with zoomLevel := .day} .tab
    let paged ← press bounds pendingOnly focused (.ctrl 'd')
    expect (paged.detailScroll > 0) "empty Actual blocked pending evidence scroll"
    expect ((Loam.Tui.Home.reconcileState bounds pendingOnly paged).detailScroll == paged.detailScroll)
      "reconciliation undid non-selectable evidence scroll"

  -- Focus and jump are modal; invalid input does not escape into household commands.
  let prompt ← press wide snapshot base (.input '/')
  let ignored ← press wide snapshot prompt (.input 'q')
  expect (ignored.jumpPrompt == some "") "prompt leaked quit"
  let typed ← "2024-02-29".toList.foldlM (fun state char => press wide snapshot state (.input char)) prompt
  let jumped ← press wide snapshot typed .enter
  expect (jumped.selectedDate == "2024-02-29" && jumped.zoomLevel == .day && jumped.jumpPrompt.isNone)
    "jump changed leap-day semantics"
  expect ((moveMonth {base with selectedDate := "2024-01-31"} 1).selectedDate == "2024-02-29")
    "month navigation did not clamp leap-day boundary"
  expect ((moveYear {base with selectedDate := "2024-02-29"} 1).selectedDate == "2025-02-28")
    "year navigation did not clamp leap-day boundary"
  IO.println "Home navigation: responsive selection, period summaries, availability, reloads and jumps passed."
