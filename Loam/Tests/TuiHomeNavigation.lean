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

  -- Reloads can remove a selected transaction. Rendering and Enter must use the same clamp.
  let fresh := {snapshot with actual := {snapshot.actual with allRecords := snapshot.actual.allRecords.take 2}}
  let state := Loam.Tui.Home.reconcileState wide fresh {base with activePane := .detail, detailCursor := 9}
  expect (state.detailCursor == 1 && (selectedDetailRecord? fresh state).isSome)
    "reload left an invalid cursor"
  let empty := {fresh with actual := {fresh.actual with allRecords := []}}
  let emptyState := Loam.Tui.Home.reconcileState wide empty state
  expect (emptyState.detailCursor == 0 && (selectedDetailRecord? empty emptyState).isNone)
    "empty reload manufactured a selection"

  -- Exact per-measure sums, explicit uncertainty, and no layout-dependent read semantics.
  for bounds in [wide, {width := 80, height := 24}, {width := 120, height := 20}] do
    for zoom in [Loam.Tui.DateJump.ZoomLevel.month, .year] do
      let state := {base with zoomLevel := zoom}
      let rendered ← browseOverview bounds snapshot state
      for token in ["jpy", "usd", "Out: -100", "? 2 unresolved effects", "Net:", "(full"] do
        expect (contains token rendered) s!"period overview lost {token}"
      expect (contains (if zoom == .month then "Out: -3,100" else "Out: -3,720") rendered)
        "period sum changed or mixed measures"
      expect (!contains "[h/l] day" rendered && !contains "[k/j] week" rendered)
        "zoom footer advertised daily navigation"
      let cases : List (Loam.Presentation.ReadState MoneyCalendarSnapshot × String) :=
        [(.notRequested, "flow not requested"), (.unavailable, "flow unavailable"),
         (.failed "role-map broken", "flow read failed"),
         (.loaded {flow := {rows := []}, presentation := []}, "No recorded income/expense flow.")]
      for (availability, marker) in cases do
        let observed ← browseOverview bounds {snapshot with moneyCalendar := availability} state
        expect (contains marker observed) s!"availability collapsed: {marker}"
        if marker == "flow read failed" then
          expect (contains "role-map broken" observed) "read diagnostic disappeared"

  -- Presentation scales remain attached to their measure, including rounded averages.
  let .loaded money := snapshot.moneyCalendar | throw (IO.userError "money fixture")
  let scaled := {snapshot with moneyCalendar := .loaded {money with
    presentation := [{measure := ⟨"usd"⟩, scale := 2}]
  }}
  let scaledText ← browseOverview wide scaled base
  expect (contains "Out: -1.00" scaledText && contains "Out/day: ~0.03" scaledText)
    "USD summary ignored presentation scale"
  expect (contains "usd [partial]" scaledText) "partial sum looked complete"

  -- Lexical period bounds also include December in the last supported year.
  let lastYear := {snapshot with moneyCalendar := .loaded {money with
    flow := {rows := money.flow.rows.map fun row => {row with date := "9999-12-31"}}
  }}
  for zoom in [Loam.Tui.DateJump.ZoomLevel.month, .year] do
    let rendered ← browseOverview wide lastYear {base with selectedDate := "9999-12-31", zoomLevel := zoom}
    expect (contains "Out: -3,720" rendered && contains "Out: -100" rendered)
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
