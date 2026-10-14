import Loam.Tui.Home
import Loam.Tui.HomeCommandPalette
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

/-- Collect every reachable overview viewport, without re-rendering the
    unchanged last page after the scroll position stops advancing. -/
private def browseOverview (bounds : Bounds) (snapshot : Snapshot) (state : State) : IO String := do
  let mut state := {state with overviewManualScroll := true, overviewScroll := 0}
  let mut frames : Array String := #[]
  for _ in List.range 100 do
    frames := frames.push ("\n" ++ text (Loam.Tui.Home.view bounds snapshot state))
    let next ← press bounds snapshot state (.ctrl 'd')
    if next.overviewManualScroll && next.overviewScroll == state.overviewScroll then
      return String.intercalate "" frames.toList
    state := next
  pure (String.intercalate "" frames.toList)

/-- Page through complete daily evidence without transaction selection undoing
    explicit browsing. This also qualifies long non-selectable read diagnostics. -/
private def browseDetail (bounds : Bounds) (snapshot : Snapshot) (state : State) : IO String := do
  let mut state := {state with activePane := .detail, detailManualScroll := true, detailScroll := 0}
  let mut frames : Array String := #[]
  for _ in List.range 100 do
    frames := frames.push ("\n" ++ text (Loam.Tui.Home.view bounds snapshot state))
    let next ← press bounds snapshot state .pageDown
    if next.detailScroll == state.detailScroll then
      return String.intercalate "" frames.toList
    state := next
  throw (IO.userError "Detail browsing did not reach its last page")

/-- Growth decorates current, known occurrence dates; it never scores money or
    input frequency, claims recording timestamps, or retains a second history. -/
private def testBonsaiGrowth (snapshot : Snapshot) : IO Unit := do
  let source ← requireSome snapshot.actual.allRecords.head? "growth fixture record"
  let recordsForDays := fun days => (List.range days).map fun i =>
    { source with
      event := {source.event with id := ⟨s!"growth-{i}"⟩}
      date := Loam.ActualDate.shiftDays? "2026-01-01" (Int.ofNat i)
    }
  let growth := Loam.Tui.HomeLauncher.growthStage
  for (days, expected) in [(0, 0), (1, 1), (2, 1), (3, 2), (6, 2), (7, 3),
      (13, 3), (14, 4), (29, 4), (30, 5), (100, 5)] do
    let records := recordsForDays days
    expect (growth records == expected) s!"bonsai growth threshold changed at {days}"
    expect (growth records.reverse == expected && growth (records ++ records) == expected)
      "bonsai rewarded order or duplicate/same-day entries"
  let records := recordsForDays 3
  let first ← requireSome records.head? "growth first date"
  expect (growth [{first with date := none}, {first with date := some "2026-02-29"}] == 0)
    "bonsai guessed an unknown or malformed date"
  let corrected := {first with replacement := some ⟨"growth-1"⟩} :: records.tail
  expect (growth corrected == 1) "bonsai counted a superseded Correction target"
  let dateCorrected := {first with date := (records[1]?).bind (·.date)} :: records.tail
  expect (growth dateCorrected == 1) "bonsai counted an old validity date after correction"
  let reversed := {first with reversedBy := some ⟨"growth-1"⟩} :: records.tail
  expect (growth reversed == 2) "bonsai erased a still-current reversed Actual date"
  for multiplier in [-1, 1, 1000000000000000000000000000000000000000000] do
    let changed ← records.mapM fun record => do
      let event ← requireSome (Event.ofEffects? record.event.id
        (record.event.effects.map fun effect => Effect.ofAnonymousQuantity effect.locus effect.measure
          (Quantity.ofQuanta (effect.quantity.quanta * multiplier)))) "growth amount fixture"
      pure {record with event, description := "different amount/description"}
    expect (growth changed == 2) "bonsai growth depended on money or description"
  let root := initialState "2026-10-01"
  let observed := {snapshot with actual := {snapshot.actual with allRecords := records}}
  let before := Loam.Tui.Home.view {width := 80, height := 24} observed root
  let idle := { observed with
    actual := {observed.actual with today := "2027-10-01"}
    scheduled := .error "unavailable"
    attention := .unavailable
  }
  expect (before.lines == (Loam.Tui.Home.view {width := 80, height := 24} idle root).lines)
    "bonsai decayed with elapsed time or depended on Scheduled/Attention"
  let grown := {observed with actual := {observed.actual with allRecords := recordsForDays 7}}
  expect (!(before.lines == (Loam.Tui.Home.view {width := 80, height := 24} grown root).lines))
    "new admitted dates did not change Home's bonsai"
  let mut previousLeaves := 0
  for stage in List.range 6 do
    let roomy := Loam.Tui.HomeLauncher.view {width := 80, height := 24} "2026-10-01" "" stage
    let leaves := roomy.lines.flatten.countP (fun cell => cell.style == .series4)
    expect (leaves > previousLeaves) "later bonsai stage did not add foliage"
    previousLeaves := leaves
    for bounds in [{width := 32, height := 9}, {width := 48, height := 14},
        {width := 80, height := 24}, {width := 150, height := 45}] do
      let view := Loam.Tui.HomeLauncher.view bounds "2026-10-01" "" stage
      expect (view.height <= bounds.height - 1 && view.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= Loam.Tui.Layout.contentWidth bounds)
        "growth stage escaped terminal geometry"
      for label in ["Record", "Scheduled", "Calendar", "Actual", "Balances", "Daily Pace"] do
        expect (contains label (text view)) "growth decoration displaced an entrance"
      expect (contains "\\___________/" (text view) == (bounds.height >= 24))
        "growth stage changed its stable fold/restore footprint"

private def paletteStay
    (state : Loam.Tui.HomeCommandPalette.State)
    (key : Loam.Tui.Terminal.Key) : IO Loam.Tui.HomeCommandPalette.State :=
  match Loam.Tui.HomeCommandPalette.update state key with
  | .stay state => pure state
  | _ => throw (IO.userError "Commands unexpectedly opened or closed")

private def testCommandsSearch : IO Unit := do
  let initial : Loam.Tui.HomeCommandPalette.State := {}
  let selected ← paletteStay initial .down
  let nested ← paletteStay selected .enter
  expect (nested.page == .planning && nested.selected == 0)
    "Commands hierarchy group entrance changed"
  let nested ← paletteStay nested .down
  let searching ← paletteStay nested (.input '/')
  expect (searching.search == some "" && searching.page == .planning &&
    searching.selected == 1) "opening search lost the browse context"
  let matching ← "balance".toList.foldlM
    (fun state char => paletteStay state (.input char)) searching
  expect ((searchResults "balance").length >= 2 &&
    (searchResults "blnc").length >= 2 &&
    (searchResults "BALANCE") == (searchResults "balance"))
    "case-folded fuzzy search or shared report destinations missing"
  let opened := Loam.Tui.HomeCommandPalette.update matching .enter
  expect (opened == .open .balances)
    "search did not dispatch the existing Balances choice"
  let fuzzy ← "blnc".toList.foldlM
    (fun state char => paletteStay state (.input char)) searching
  expect (Loam.Tui.HomeCommandPalette.update fuzzy .enter == .open .balances)
    "fuzzy search did not resolve an ordered subsequence"
  let noMatches ← "qzznotfound".toList.foldlM
    (fun state char => paletteStay state (.input char)) searching
  expect (noMatches.search == some "qzznotfound" &&
    (searchResults "qzznotfound").isEmpty &&
    Loam.Tui.HomeCommandPalette.update noMatches .enter == .stay noMatches)
    "search swallowed letter q or opened a nonexistent command"
  let deleted ← paletteStay noMatches .backspace
  expect (deleted.search == some "qzznotfoun")
    "search Backspace failed"
  let pasted ← paletteStay searching (.paste "balances\nshould-not-join")
  expect (pasted.search == some "balances" &&
    Loam.Tui.HomeCommandPalette.update pasted .enter == .open .balances)
    "search paste crossed its single-line boundary"
  let restored ← paletteStay noMatches .escape
  expect (restored.search.isNone && restored.page == .planning &&
    restored.selected == nested.selected)
    "Esc left search but lost prior hierarchical selection"
  let parent ← paletteStay restored .escape
  expect (parent.page == .commands && parent.selected == 1)
    "Esc did not resume the original Commands navigation"
  expect (Loam.Tui.HomeCommandPalette.update parent .escape == .close)
    "Commands root Esc no longer closes the palette"
  -- The all-candidate view must remain bounded on narrow terminals. Selection
  -- follows its own cursor and must not modify the saved hierarchy cursor.
  let many ← paletteStay searching .down
  expect (many.searchSelected == 1 && many.selected == searching.selected)
    "search selection unexpectedly changed browse selection"
  for bounds in [{width := 32, height := 9}, {width := 48, height := 14},
      {width := 80, height := 24}, {width := 120, height := 40}] do
    for state in [searching, many, matching, noMatches, restored] do
      let v := Loam.Tui.HomeCommandPalette.view bounds state
      expect (v.height <= bounds.height &&
        v.lines.all fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth bounds)
        s!"Commands search overflowed {bounds.width}x{bounds.height}"
    let missing := text (Loam.Tui.HomeCommandPalette.view bounds noMatches)
    expect (contains "No matches" missing || bounds.height < 9)
      "empty search failed to show its safe browsing escape"

def main : IO Unit := do
  let snapshot ← fixture
  testBonsaiGrowth snapshot
  testCommandsSearch
  let launcher := initialState "2026-10-01"
  expect launcher.launcherOpen "production startup did not open the bonsai Home"
  for bounds in [{width := 32, height := 9}, {width := 32, height := 11},
      {width := 32, height := 13}, {width := 48, height := 14},
      {width := 32, height := 23}, {width := 32, height := 24},
      {width := 80, height := 24}, {width := 150, height := 45},
      {width := 1, height := 1}] do
    let view := Loam.Tui.Home.view bounds snapshot launcher
    expect (view.height <= bounds.height - 1) "launcher overflowed writable rows"
    expect (view.lines.all fun cells => Loam.Tui.Layout.displayWidth
      (String.ofList (cells.map Cell.glyph)) <= Loam.Tui.Layout.contentWidth bounds)
      "launcher overflowed terminal columns"
    if bounds.height >= 9 then
      let shown := text view
      for label in ["Record", "Scheduled", "Calendar", "Actual", "Balances", "Daily Pace"] do
        expect (contains label shown) s!"launcher lost {label} at {bounds.width}x{bounds.height}"
      expect (contains "loam" shown && contains launcher.selectedDate shown)
        "launcher hid its name or Record seed date"
      let treeFits := bounds.height >= 24
      expect (contains "\\___________/" shown == treeFits)
        "bonsai was cropped instead of folded, or disappeared on a fitting screen"
      expect ((view.lines.flatten.any fun cell => cell.style == .series4) == treeFits)
        "bonsai leaf color escaped its decoration boundary"
      expect (!contains "RECORD-" shown && !contains "Net:" shown)
        "launcher became a second household dashboard"
  let entered ← press {width := 80, height := 24} snapshot launcher .enter
  expect (!entered.launcherOpen && entered.selectedDate == launcher.selectedDate)
    "launcher Calendar entrance changed the selected date"
  let returned ← press {width := 80, height := 24} snapshot entered .escape
  expect (returned.launcherOpen && returned.selectedDate == launcher.selectedDate)
    "Calendar did not return to the launcher"
  for key in ['r', 's', 'a', 'b', 'd', 'i', ' ', 'q'] do
    expect ((Loam.Tui.Home.navigationKey {width := 80, height := 24} snapshot launcher (.input key)).isNone)
      s!"launcher swallowed workspace/quit key {key}"
  let ignored ← press {width := 80, height := 24} snapshot launcher (.input 'l')
  expect (ignored.selectedDate == launcher.selectedDate && ignored.launcherOpen)
    "launcher leaked Calendar navigation"
  let base : State := {selectedDate := "2026-10-01", zoomLevel := .month}
  let wide : Bounds := {width := 150, height := 45}

  -- Compact Day first shows the selected date and exact, per-Measure flow.
  -- The complete monthly projection and every read-state remain scrollable.
  for width in [32, 48, 72, 79] do
    let bounds : Bounds := {width, height := 24}
    let state : State := {base with zoomLevel := .day}
    let first := text (Loam.Tui.Home.view bounds snapshot state)
    expect (contains "Focus: 2026-10-01" first && contains "RECORD-9#" first)
      s!"compact Day lost its date or selected-day Actual at {width}"
    let overview ← browseOverview bounds snapshot state
    let detail ← browseDetail bounds snapshot state
    let rendered := overview ++ detail
    for marker in ["jpy", "usd", "In:+", "Out:-", "Net:", "? 2 unresolved",
                   "Scheduled", "Unknown; completeness", "Month Flow (2026-10)"] do
      expect (contains marker rendered)
        s!"compact Day omitted admitted evidence at {width}: {marker}"
  -- Medium terminals reflow into simultaneous calendar/detail frames.
  for bounds in [{width := 80, height := 24}, {width := 100, height := 20},
      {width := 119, height := 20}] do
    let state : State := {base with zoomLevel := .day}
    let rendered := text (Loam.Tui.Home.view bounds snapshot state)
    expect (contains "Calendar / 2026-10" rendered &&
      contains "Day 2026-10-01 / Detail" rendered &&
      contains "RECORD-9#" rendered)
      s!"stacked Day lost calendar or Actual detail at {bounds.width}"
    let focused ← press bounds snapshot state .tab
    let detailView := text (Loam.Tui.Home.view bounds snapshot focused)
    expect (contains "Day 2026-10-01 / Detail" detailView && contains "RECORD-9#" detailView &&
      (Loam.Tui.Home.view bounds snapshot focused).lines.flatten.any (fun cell => cell.style == .selected))
      s!"stacked Day lost visible focused detail at {bounds.width}"
    let back ← press bounds snapshot focused .tab
    expect (back.activePane == .calendar && back.selectedDate == state.selectedDate)
      "stacked pane focus changed the date"
  let tinyDay := text (Loam.Tui.Home.view {width := 48, height := 14}
    snapshot {base with zoomLevel := .day})
  expect (contains "▶ - RECORD-9#" tinyDay)
    "tiny Day no longer exposes the selected date's first Actual"
  let regularDay := text (Loam.Tui.Home.view {width := 120, height := 24}
    snapshot {base with zoomLevel := .day})
  expect (contains "┬" regularDay) "wide Day unexpectedly lost its money grid"

  -- Very wide terminals retain a bounded money grid with intentional whitespace,
  -- rather than stretching all seven money cells to fill the left pane.
  let roomy : Bounds := {width := 240, height := 45}
  let roomyState : State := {base with zoomLevel := .day, selectedDate := "2026-10-13"}
  let roomyView := Loam.Tui.Home.view roomy snapshot roomyState
  let gridTop ← requireSome (roomyView.lines.find? fun row =>
    row.any (fun cell => cell.glyph == '┬')) "centered money grid top was not visible"
  let leftCorner ← requireSome (gridTop.zipIdx.find? fun (cell, _) =>
    cell.glyph == '┌') "money grid left corner hidden"
  let rightCorner ← requireSome (gridTop.zipIdx.find? fun (cell, _) =>
    cell.glyph == '┐') "money grid right corner hidden"
  expect (rightCorner.2 + 1 - leftCorner.2 == 106 && leftCorner.2 > 2)
    "money grid exceeded its 14-column cell cap or failed to center"
  expect (roomyState.selectedDate == "2026-10-13" &&
    contains "2026-10-13" (text roomyView))
    "sizing experiment disturbed selected-day context"
  let weekGeometry ← requireSome
    (Loam.Tui.CalendarGeometry.centeredSeven? 116 8 12 1)
    "week geometry unexpectedly refused normal compact bounds"
  expect (weekGeometry.cellColumns == 12 && weekGeometry.gridColumns == 90 &&
    weekGeometry.leftColumns == 13 && weekGeometry.rightColumns == 13)
    "week strip cap / centering geometry changed"

  -- Narrow Day mode automatically presents the quiet weekly ribbon; wide Day retains the full money grid.
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24}, {width := 119, height := 20}] do
    let state : State := {base with zoomLevel := .day, selectedDate := "2026-10-01"}
    let rendered ← browseOverview bounds snapshot state
    expect (contains "Week 2026-09-28 .. 2026-10-04" rendered)
      s!"week ribbon lost month-boundary coordinates at {bounds.width}: {rendered}"
    expect (contains "Focus: 2026-10-01" rendered)
      s!"week ribbon lost focused date at {bounds.width}: {rendered}"
    expect (contains "Month Flow (2026-10)" rendered)
      "week ribbon lost independent monthly-money overview"
    let focused ← press bounds snapshot state .tab
    expect (contains "▶ - " (text (Loam.Tui.Home.view bounds snapshot focused)))
      s!"compact Day hid exact Detail at {bounds.width}"
  for bounds in [{width := 120, height := 24}, {width := 150, height := 45}] do
    let state : State := {base with zoomLevel := .day, selectedDate := "2026-10-01"}
    let rendered ← browseOverview bounds snapshot state
    expect (contains "┬" rendered)
      s!"wide Day unexpectedly lost its money grid at {bounds.width}"

  -- Day/week alignment and evidence-preserving status marks on narrow Day bounds.
  let movement ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩
    [{coordinate := ⟨"wallet"⟩, quantity := Quantity.ofQuanta (-1)},
     {coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 1}]) "week Scheduled movement"
  let openRecords := (List.range 6).map fun i =>
    { id := ⟨s!"week-due-{i}"⟩, scheduledOn := "2026-10-15", movement }
  let openScheduled ← requireSome (ScheduledMemory.ofOccurrences? openRecords)
    "week Scheduled memory"
  let .ok originalScheduled := snapshot.scheduled |
    throw (IO.userError "week Scheduled fixture unavailable")
  let withScheduled := {snapshot with
    actual := {snapshot.actual with today := "2026-10-12"}
    scheduled := .ok {originalScheduled with scheduled := openScheduled} }
  let narrowDay : State := {
    base with
    zoomLevel := .day
    selectedDate := "2026-10-15"
  }
  for bounds in [{width := 32, height := 20}, {width := 48, height := 14},
      {width := 80, height := 24}, {width := 119, height := 20}] do
    let shown ← browseOverview bounds withScheduled narrowDay
    expect (contains "15" shown && contains "S6" shown && contains "Focus: 2026-10-15" shown)
      s!"week Scheduled marker or selected date hidden at {bounds.width}"
    expect (contains "Mon" shown && contains "Sun" shown)
      s!"week days did not fit at {bounds.width}"
    expect (!contains "Out/day:" shown && contains "Month Flow (2026-10)" shown)
      "week strip invented a pace-like sum or lost the monthly evidence"
    let view := Loam.Tui.Home.view bounds withScheduled narrowDay
    for row in view.lines do
      expect (Loam.Tui.Layout.displayWidth (String.ofList (row.map Cell.glyph)) ≤ bounds.width - 1)
        s!"week strip exceeds writable width at {bounds.width}"
    let badRead := {withScheduled with scheduled := .error "scheduled lifecycle read failed"}
    let shownFailure ← browseOverview bounds badRead narrowDay
    expect (contains "S?" shownFailure && contains "unavailable" shownFailure)
      s!"week strip hid Scheduled failure at {bounds.width}"
  -- The two roles never collapse into a Calendar containing transaction details.
  -- Dates, weekday and status remain contiguous before the first Actual heading.
  for bounds in [{width := 32, height := 9}, {width := 48, height := 14},
      {width := 64, height := 30}, {width := 79, height := 24},
      {width := 80, height := 24}, {width := 119, height := 30}] do
    let state := {base with zoomLevel := .day}
    let view := Loam.Tui.Home.view bounds snapshot state
    let actualRow ← requireSome (rowIndex? "RECORD-9#" view) "Actual hidden after compact resize"
    let dateRow ← requireSome (rowIndex? "1" view) "compact date navigator hidden"
    expect (dateRow < actualRow && !contains "Actual: RECORD" (text view))
      "compact Day merged Actual preview into date navigation"
    expect (view.lines.length == bounds.height - 1) "compact Day height changed"
    for row in view.lines do
      expect (Loam.Tui.Layout.displayWidth (String.ofList (row.map Cell.glyph)) ≤ bounds.width - 1)
        "compact two-role layout exceeded terminal width"
    let datesBefore := view.lines.take actualRow
    expect (datesBefore.flatten.any (fun cell => cell.style == .selected || cell.style == .selectedUnderlined))
      "compact date navigator lost its selected-day marker"
  -- Spare height exposes the complete month projection rather than truncating
  -- the upper frame above an empty lower frame (the supplied screenshot seam).
  let sparse := {snapshot with actual := {snapshot.actual with allRecords := []}}
  let sparseView := text (Loam.Tui.Home.view {width := 100, height := 40}
    sparse {base with zoomLevel := .day})
  expect (contains "Month Flow (2026-10)" sparseView && contains "Scheduled" sparseView)
    "empty Detail still hid month evidence despite available height"

  let yearBorder : State := {base with zoomLevel := .day, selectedDate := "2026-12-31"}
  let yearView ← browseOverview {width := 80, height := 24} snapshot yearBorder
  expect (contains "Week 2026-12-28 .. 2027-01-03" yearView)
    "weekly ribbon lost December-to-January coordinates"
  let zoomed ← press wide snapshot yearBorder (.input 'z')
  expect (zoomed.zoomLevel == .month)
    "zoom did not advance to month overview"

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
    let header := text (Loam.Tui.Home.view bounds snapshot scrolled)
    expect (contains "Mon" header || contains "Week 2026-10-26 .. 2026-11-01" header)
      "manual overview browsing could not reach the calendar header"
    let moved ← press bounds snapshot scrolled (.input 'h')
    expect (!moved.overviewManualScroll && moved.overviewScroll == 0)
      "date navigation did not resume focus-following"
    expect (contains "30" (String.ofList ((Loam.Tui.Home.view bounds snapshot moved).lines.filter
      (fun cells => cells.any fun cell => cell.style == .selected) |>.flatten.map Cell.glyph)))
      "date navigation left calendar focus outside its viewport"

  -- Enter/z reset changed-period geometry. Esc now returns Home, preserving it.
  let stale : State := {base with
    zoomLevel := .year
    detailCursor := 11
    detailScroll := 100
    overviewScroll := 5
  }
  let home ← press wide snapshot stale .escape
  expect (home.launcherOpen && home.zoomLevel == stale.zoomLevel &&
    home.detailCursor == stale.detailCursor && home.detailScroll == stale.detailScroll &&
    home.overviewScroll == stale.overviewScroll) "Home return reset Calendar context"
  for key in [Loam.Tui.Terminal.Key.enter, .input 'z'] do
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
        let qBack ← press bounds snapshot last (.input 'q')
        expect (qBack.activePane == .calendar) "q did not leave detail"
        let capQBack ← press bounds snapshot last (.input 'Q')
        expect (capQBack.activePane == .calendar) "Q did not leave detail"
        for key in [Loam.Tui.Terminal.Key.input 'q', .input 'Q', .escape, .input 'g', .input 'G'] do
          let home ← press bounds snapshot base key
          expect (home.launcherOpen && home.selectedDate == base.selectedDate &&
            home.zoomLevel == base.zoomLevel)
            "Calendar return lost Home, date or zoom"

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
          .home, .«end», .up, .escape, .ctrl 'd', .ctrl 'u', .tab] do
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
  -- An empty Actual pane must scroll its already prepared read diagnostics rather
  -- than reconstructing the Scheduled failure content just to count its rows.
  let unavailable : Snapshot := {
    snapshot with
    actual := {snapshot.actual with allRecords := []}
    scheduled := .error (String.ofList (List.replicate 240 'X'))
  }
  let emptyBounds : Bounds := {width := 48, height := 14}
  let emptyStart := {base with zoomLevel := .day, activePane := .detail}
  let emptyCache := some (Loam.Tui.Home.prepareDetail emptyBounds unavailable emptyStart)
  let mut cachedEmpty := emptyStart
  let mut freshEmpty := emptyStart
  for key in [Loam.Tui.Terminal.Key.ctrl 'd', .ctrl 'd', .ctrl 'u'] do
    cachedEmpty ← requireSome
      (Loam.Tui.Home.navigationKey emptyBounds unavailable cachedEmpty key 1 emptyCache)
      "cached empty-detail scroll unhandled"
    freshEmpty ← press emptyBounds unavailable freshEmpty key
    expect (cachedEmpty.detailScroll == freshEmpty.detailScroll)
      "prepared empty-detail row count changed scrolling"
    expect ((Loam.Tui.Home.view emptyBounds unavailable cachedEmpty emptyCache).lines ==
      (Loam.Tui.Home.view emptyBounds unavailable freshEmpty).lines)
      "prepared empty-detail scroll changed read diagnostics"

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
    expect (contains "10 records" rendered && contains "2 records" rendered && contains "0 records" rendered)
      "month reflow lost exact labelled counts"
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

  -- Month names/counts occupy separate aligned rows, and zoom-specific frame
  -- titles replace the ambiguous Calendar/date + inset Year/Years Overview labels.
  for bounds in [{width := 32, height := 14}, {width := 48, height := 14},
      {width := 64, height := 30}, {width := 116, height := 40}, wide] do
    let month := Loam.Tui.Home.view bounds snapshot {base with zoomLevel := .month}
    expect (contains "Months / 2026" (text month) && !contains "10t" (text month) &&
      !contains "underline = current month" (text month)) "month retained obsolete headings or count shorthand"
    let selected ← requireSome (rowIndex? "[10 Oct]" month) "selected month missing"
    expect (contains "10 records" (String.ofList ((month.lines[selected + 1]?.getD []).map Cell.glyph)))
      "selected month's count did not remain beside its name after resize"
    let countRow := month.lines[selected + 1]?.getD []
    expect (countRow.all fun cell => cell.style != .selected && cell.style != .selectedUnderlined &&
      cell.style != .underlined) "month count borrowed selection or Today meaning"
    let year := Loam.Tui.Home.view bounds snapshot {base with zoomLevel := .year}
    expect (contains "Years" (text year) && contains "Records" (text year) &&
      contains "[2026]" (text year) && !contains "Years Overview" (text year) &&
      !contains "underline = current year" (text year)) "year retained ambiguous or duplicate headings"
    let yearRendered ← browseOverview bounds snapshot {base with zoomLevel := .year}
    expect (contains "Year Flow (2026)" yearRendered && contains "12 transactions recorded" yearRendered)
      "year refinement lost the period count or financial summary"
    for view in [month, year] do
      for cells in view.lines do
        expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
          "month/year refinement exceeded writable columns"
  -- Year choices stay in the existing jump/navigation domain near its edges.
  for (date, firstYear, lastYear) in [("1000-01-01", "1000", "1004"),
      ("9999-12-31", "9995", "9999")] do
    let view ← browseOverview {width := 48, height := 24} snapshot
      {base with selectedDate := date, zoomLevel := .year}
    expect (contains firstYear view && contains lastYear view && !contains "10000" view)
      "neighboring-year choices escaped the admitted navigation range"

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

  -- Full help replaces only presentation, captures household entrances, and
  -- survives resize without changing date, record identity or underlying scroll.
  for bounds in [{width := 32, height := 9}, {width := 48, height := 14}, wide] do
    let start := {base with zoomLevel := .day, activePane := .detail}
    let help ← press bounds snapshot start (.input '?')
    expect (help.helpOpen && contains "[?] close" (text (Loam.Tui.Home.view bounds snapshot help)))
      "Home help did not open with a visible exit"
    for key in [Loam.Tui.Terminal.Key.input 'r', .input 'a', .input 's', .input 'i',
        .input 'd', .input 'b', .input ' ', .enter, .input '/', .input 'z'] do
      let captured ← press bounds snapshot help key
      expect (captured.helpOpen && captured.selectedDate == help.selectedDate &&
        captured.detailCursor == help.detailCursor && captured.activePane == help.activePane)
        "help delegated a household entrance or changed the workspace context"
    let mut browsing := help
    let mut collected := ""
    for _ in List.range 100 do
      let view := Loam.Tui.Home.view bounds snapshot browsing
      let content := view.lines.drop 3 |>.take (bounds.height - 8)
      collected := collected ++ String.ofList (content.flatten.map Cell.glyph)
      browsing ← press bounds snapshot browsing (.ctrl 'd')
    for marker in ["amount too wide", "completeness claim", "retained quanta", "[i]", "[b]"] do
      expect (contains (marker.replace " " "") (collected.replace " " "" |>.replace "\n" "" |>.replace "│" "")) s!"full help lost {marker}"
    for resized in [{width := 48, height := 14}, {width := 120, height := 24}] do
      let rendered := Loam.Tui.Home.view resized snapshot browsing
      expect (rendered.lines.length == resized.height - 1) "help resize exceeded terminal height"
    let back ← press bounds snapshot browsing .escape
    expect (!back.helpOpen && back.selectedDate == help.selectedDate &&
      back.detailScroll == help.detailScroll && back.detailCursor == help.detailCursor)
      "closing help lost the underlying Home context"
  -- Manual evidence pages include daily flow and Scheduled even when Actual is
  -- nonempty; moving the cursor resumes identity-based focus-following.
  let detailPages ← browseDetail {width := 48, height := 14} failed {base with zoomLevel := .day}
  expect (contains "-tail" detailPages && contains "RECORD-9#" detailPages &&
    contains "Unknown; completeness" detailPages) "Detail paging omitted a diagnostic or Scheduled"
  let browsing ← press {width := 48, height := 14} snapshot
    {base with zoomLevel := .day, activePane := .detail} .pageDown
  expect browsing.detailManualScroll "manual evidence page retained selection-following"
  let selecting ← press {width := 48, height := 14} snapshot browsing .up
  expect (!selecting.detailManualScroll && contains "▶ - RECORD" (text
    (Loam.Tui.Home.view {width := 48, height := 14} snapshot selecting)))
    "transaction selection did not resume after evidence browsing"

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
