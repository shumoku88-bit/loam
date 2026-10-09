import Loam.Review.ScheduledCoverageReview
import Loam.Review.ScheduledCoverageSelector
import Loam.Tui.Main
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.ScheduledCoverageSetup

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def yen : MeasureId := ⟨"jpy"⟩

private def change (locus : String) (quanta : Int) : MovementChange LocusId :=
  { coordinate := ⟨locus⟩, quantity := Quantity.ofQuanta quanta }

private def scheduledRecord?
    (id date fromLocus toLocus : String) (quanta : Int) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change fromLocus (-quanta), change toLocus quanta]
  pure {
    id := ⟨id⟩
    scheduledOn := date
    movement := movement
  }

private def scheduledWorkspaceSnapshot : IO Loam.Tui.Main.Snapshot := do
  let first ← requireSome (scheduledRecord? "scheduled-0" "2026-09-07" "paypay" "food" 100)
    "first Scheduled fixture was not admitted"
  let second ← requireSome (scheduledRecord? "scheduled-1" "2026-09-07" "smbc" "paypay" 200)
    "second Scheduled fixture was not admitted"
  let future ← requireSome (scheduledRecord? "scheduled-2" "2026-09-08" "paypay" "books" 300)
    "future-day Scheduled fixture was not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [first, second, future])
    "Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    terminals := terminals
    events := events
  }
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := []
  }
  pure { actual := actual, scheduled := .ok scheduledSnapshot }

private def longScheduledWorkspaceSnapshot : IO Loam.Tui.Main.Snapshot := do
  let rows ← requireSome
    ((List.range 12).mapM fun index =>
      scheduledRecord? ("scheduled-long-" ++ toString index) "2026-09-07"
        "wallet" "food" (Int.ofNat (index + 1)))
    "long Scheduled fixtures were not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? rows)
    "long Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted for long fixture"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted for long fixture"
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    terminals := terminals
    events := events
  }
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := []
  }
  pure { actual := actual, scheduled := .ok scheduledSnapshot }

def main : IO Unit := do
  let snapshot ← scheduledWorkspaceSnapshot

  -- Shared current-open read order is date first, then Scheduled identity.
  -- Retained order is intentionally reversed for the same-date pair.
  let sameDateZ ← requireSome
    (scheduledRecord? "z-same-day" "2026-09-10" "wallet" "food" 10)
    "same-date z fixture was not admitted"
  let sameDateA ← requireSome
    (scheduledRecord? "a-same-day" "2026-09-10" "wallet" "books" 20)
    "same-date a fixture was not admitted"
  let orderedMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [sameDateZ, sameDateA])
    "same-date ordered Scheduled memory was not admitted"
  let orderedTerminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "same-date empty terminal memory was not admitted"
  let orderedEvents ← requireSome (EventMemory.ofEvents? [])
    "same-date empty Event memory was not admitted"
  let orderedEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := orderedMemory
    terminals := orderedTerminals
    events := orderedEvents
  }
  let ordered ←
    match Loam.ScheduledReview.orderedCurrentOpenRecords orderedEvidence with
    | .error message => throw (IO.userError message)
    | .ok rows => pure rows
  expect (ordered.map (fun row => row.id.token) == ["a-same-day", "z-same-day"])
    "shared Scheduled read order did not use identity as the same-date tie-breaker"
  let earliest ←
    match Loam.ScheduledReview.earliestCurrentOpenRecord orderedEvidence with
    | .error message => throw (IO.userError message)
    | .ok row => pure row
  expect ((earliest.map (fun row => row.id.token)) == some "a-same-day")
    "earliest current-open Scheduled diverged from the shared ordered frontier"

  let overview := Loam.Tui.ScheduledWorkspace.initial "2026-09-07"
  expect (overview.viewMode == .coverage && overview.scope == .allCurrent)
    "Scheduled production initializer did not open on the all-current Coverage overview"

  let start := Loam.Tui.ScheduledWorkspace.initialList "2026-09-07"

  -- 1. Focus Day scope shows only today's Scheduled occurrences
  expect ((Loam.Tui.ScheduledWorkspace.recordsForScope snapshot start).length == 2)
    "Scheduled workspace Focus Day did not return the two scheduled occurrences on 2026-09-07"

  -- Unknown day evidence stays distinct from an empty complete answer.
  let unknownState := Loam.Tui.ScheduledWorkspace.initialList "2026-09-09"
  match Loam.Tui.ScheduledWorkspace.scopeEvidence snapshot unknownState with
  | .ok .unknown => pure ()
  | _ => throw (IO.userError "Scheduled workspace Focus Day did not preserve Unknown evidence")
  let unknownText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot unknownState)
  expect (contains "Scheduled [Unknown]" unknownText &&
    contains "Unknown; no completeness horizon claimed" unknownText)
    "Scheduled workspace did not render open-world Unknown explicitly"
  expect (!contains "none due on this day" unknownText)
    "Scheduled workspace collapsed Unknown into an empty-day claim"

  -- Production Scheduled workspace owns its own eight-row viewport. Pin navigation beyond it
  -- before the older Main Scheduled cursor implementation is retired.
  let longSnapshot ← longScheduledWorkspaceSnapshot
  let longStart := Loam.Tui.ScheduledWorkspace.initialList "2026-09-07"
  let longShifted := (List.range 10).foldl
    (fun current _ => (Loam.Tui.ScheduledWorkspace.update longSnapshot current .next).state)
    longStart
  expect (longShifted.occurrenceRow == 10)
    "Scheduled workspace selection could not reach the eleventh occurrence"
  let selectedLong ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedRecord? longSnapshot longShifted)
    "Scheduled workspace eleventh-row selection disappeared"
  let longViewText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } longSnapshot longShifted)
  expect (contains selectedLong.id.token longViewText)
    "Scheduled workspace moving viewport did not render its selected eleventh occurrence"
  match (Loam.Tui.ScheduledWorkspace.recordsForScope longSnapshot longStart).head? with
  | none => throw (IO.userError "Scheduled workspace long-list fixture became empty")
  | some firstLong =>
      expect (!contains firstLong.id.token longViewText)
        "Scheduled workspace eight-row viewport did not move beyond its first occurrence"
  let longLast := (List.range 11).foldl
    (fun current _ => (Loam.Tui.ScheduledWorkspace.update longSnapshot current .next).state)
    longStart
  let longBlocked := (Loam.Tui.ScheduledWorkspace.update longSnapshot longLast .next).state
  expect (longBlocked.occurrenceRow == longLast.occurrenceRow &&
    contains "No next Scheduled row" longBlocked.notice)
    "Scheduled workspace end-of-list refusal moved selection or lost its notice"

  -- Months uses spare terminal height instead of keeping every month at three rows.
  let longAll := (Loam.Tui.ScheduledWorkspace.update longSnapshot longStart .cycleFilter).state
  let longCoverage := (Loam.Tui.ScheduledWorkspace.update longSnapshot longAll .toggleView).state
  let longBoard := (Loam.Tui.ScheduledWorkspace.update longSnapshot longCoverage .toggleView).state
  let compactBoardText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 } longSnapshot longBoard)
  let tallBoardText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 50 } longSnapshot longBoard)
  expect (!(contains "wallet -> food: 7 jpy" compactBoardText) &&
    contains "wallet -> food: 7 jpy" tallBoardText)
    "Scheduled Months did not expand month-card capacity with terminal height"

  -- 2. Scheduled opens on occurrences so j/k browses records before any explicit Locus filtering.
  expect (start.pane == .occurrences)
    "Scheduled workspace did not open on the Scheduled occurrences pane"
  let second := (Loam.Tui.ScheduledWorkspace.update snapshot start .next).state
  match Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot second with
  | none => throw (IO.userError "Scheduled workspace occurrence selection disappeared")
  | some record =>
      expect (record.id.token == "scheduled-1")
        "Scheduled workspace j/down selection did not move to the second occurrence"

  -- 3. Rendering check
  let viewWidget := Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot second
  let viewText := widgetText viewWidget
  expect (contains "Household Scheduled Workspace" viewText)
    "Scheduled workspace heading was not rendered"
  expect (contains "Selected Scheduled Details:" viewText && contains "scheduled-1" viewText)
    "Scheduled workspace details did not render selected occurrence information"
  let refusalMessage :=
    "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY replacement editor."
  let refusedState := { second with notice := refusalMessage }
  let refusedText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot refusedState)
  expect (contains refusalMessage (refusedText.replace "\n" " "))
    "Scheduled workspace did not render the complete wrapped Scheduled replacement refusal notice"

  -- 4. Cycle Filter expands to allCurrent
  let allCurrent := (Loam.Tui.ScheduledWorkspace.update snapshot second .cycleFilter).state
  expect ((Loam.Tui.ScheduledWorkspace.recordsForScope snapshot allCurrent).length == 3)
    "Scheduled workspace filter cycle did not expand to all current-open Scheduled occurrences"
  expect (allCurrent.pane == .occurrences)
    "Scheduled workspace scope change moved focus into the Locus filter pane"

  let allCurrentText := widgetText (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } snapshot allCurrent)
  expect (contains "All Current-Open" allCurrentText)
    "Scheduled workspace heading did not reflect All Current-Open scope"

  -- Coverage is the Scheduled overview; Months and List are alternate projections.
  let coverage := (Loam.Tui.ScheduledWorkspace.update snapshot allCurrent .toggleView).state
  expect (coverage.viewMode == .coverage && coverage.scope == .allCurrent)
    "Scheduled list did not cycle into the Coverage overview"
  let foodRule : Loam.ScheduledCoverageConfig.Rule := {
    name := "food"
    anchor := "2026-09-07"
    everyMonths := 1
    negativeLoci := ["paypay"]
    positiveLoci := ["food"]
  }
  let paypayRule : Loam.ScheduledCoverageConfig.Rule := {
    name := "paypay-transfer"
    anchor := "2026-09-07"
    everyMonths := 1
    negativeLoci := ["smbc"]
    positiveLoci := ["paypay"]
  }
  let coverageSnapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [foodRule, paypayRule] (Loam.Tui.ScheduledWorkspace.recordsForScope snapshot coverage)
        "2026-09-07" 4 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let coverageText := widgetText
    (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 120, height := 30 } snapshot coverage (.ok coverageSnapshot))
  expect (contains "Scheduled" coverageText &&
    contains "food" coverageText && contains "paypay-transfer" coverageText &&
    contains "Pace" coverageText && contains "Oct" coverageText)
    "Scheduled overview did not render the recurring-plan Series Calendar"
  expect (contains "> food" coverageText &&
    contains "[j/k] plan" coverageText &&
    contains "[e] replenish" coverageText && contains "[p] pace" coverageText &&
    contains "[h/l] months" coverageText && contains "[Enter] detail" coverageText)
    "Scheduled overview did not expose its ordinary recurring-plan actions"
  expect (contains "More:" coverageText &&
    contains "[s] undecided" coverageText &&
    contains "[n] new" coverageText &&
    contains "[v] Months/List" coverageText)
    "Scheduled overview hid advanced projections or less-frequent actions"

  expect (contains "╭ Monitored plans" coverageText && !contains "====" coverageText &&
      contains "known through 2026-09-07" coverageText && contains "Month window:" coverageText)
    "Series Calendar retained heavy rules or lost its observation/month coordinates"

  let manyRules := (List.range 40).map fun index =>
    { foodRule with
      name := "プラン-" ++ toString index
      positiveLoci := ["target-" ++ toString index] }
  let manyCoverage ←
    match Loam.ScheduledCoverageReview.projectRecords manyRules [] "2026-09-07" 18 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let manyState := { coverage with coverageRow := 35 }
  let selectedPlan ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageRow? (.ok manyCoverage) manyState)
    "long Series Calendar selection disappeared"
  let firstPlan ← requireSome (Loam.Tui.ScheduledCoveragePane.orderedRows manyCoverage).head?
    "long Series Calendar first row disappeared"
  for bounds in [{ width := 80, height := 24 }, { width := 120, height := 30 },
      { width := 144, height := 40 }, { width := 48, height := 10 }] do
    let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot manyState (.ok manyCoverage)
    let text := widgetText rendered
    expect (contains selectedPlan.rule.name text && !contains firstPlan.rule.name text &&
        contains "36/40" text &&
        rendered.lines.any (fun cells => cells.any (fun cell => cell.style == .selected)))
      "Series Calendar left its selected plan off-screen or lost selection position"
    expect (rendered.lines.length <= bounds.height - 1 &&
        rendered.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth bounds))
      "Series Calendar exceeded its physical terminal geometry"
    expect (rendered.lines.all fun cells => cells.all fun cell =>
        cell.style == .normal || cell.style == .muted ||
        cell.style == .series1 || cell.style == .selected)
      "Series Calendar added decorative accent colors"
  for width in [0, 1, 2, 10, 20, 32, 48, 80, 120] do
    for height in [0, 1, 2, 6, 10, 18, 24, 30] do
      let bounds : Bounds := { width, height }
      let rendered := Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot manyState (.ok manyCoverage)
      expect (rendered.lines.length <= height - 1 && rendered.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
            Loam.Tui.Layout.contentWidth bounds))
        "Compact or degenerate Series Calendar geometry escaped its bounds"
  let shiftedCalendar := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } snapshot { coverage with coverageMonthOffset := 2 }
    (.ok coverageSnapshot))
  expect (contains "2026-12 .. 2027-01" shiftedCalendar && contains "Dec" shiftedCalendar)
    "Framed Series Calendar changed the selected finite month window"
  let emptyCalendar := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } snapshot coverage (.ok { coverageSnapshot with rows := [] }))
  let failedCalendar := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 120, height := 30 } snapshot coverage (.error "coverage read refused"))
  expect (contains "No recurring plans are being monitored." emptyCalendar &&
      !contains "Coverage unavailable" emptyCalendar &&
      contains "[Coverage unavailable] coverage read refused" failedCalendar &&
      !contains "0/0" failedCalendar && !contains "No recurring plans" failedCalendar)
    "Series Calendar collapsed failed coverage into configured-empty evidence"
  let calendarRefusal := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
    { width := 100, height := 30 } snapshot { coverage with notice := refusalMessage }
    (.ok coverageSnapshot))
  expect (contains refusalMessage (calendarRefusal.replace "\n" " "))
    "Framed Series Calendar clipped a publisher's complete refusal feedback"

  let coverageEvidence : Loam.Tui.ScheduledWorkspace.CoverageEvidence := .ok coverageSnapshot
  let coverageExtend :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .extendPlan
  expect (coverageExtend.command == .extendPlan)
    "Scheduled overview could not replenish its selected recurring plan directly"
  let coverageBatch :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .batchEditScheduled
  expect (coverageBatch.command == .batchEditScheduled && contains "[b] batch amount" coverageText)
    "Scheduled overview could not open the batch candidate sheet directly"
  let coveragePace :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .changePace
  expect (coveragePace.command == .changePace)
    "Scheduled overview could not change its selected recurring-plan pace directly"
  let coverageStop :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .stopMonitoring
  expect (coverageStop.command == .stopMonitoring)
    "Scheduled overview could not mark its selected recurring plan undecided directly"

  let coverageNext :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .next).state
  expect (coverageNext.coverageRow == 1)
    "Scheduled overview j/k selection did not move between recurring plans"
  let coverageLaterMonth :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverage .focusRight).state
  expect (coverageLaterMonth.coverageMonthOffset == 1)
    "Scheduled Series Calendar l did not move the month window"
  let coverageEarlierMonth :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverageLaterMonth .focusLeft).state
  expect (coverageEarlierMonth.coverageMonthOffset == 0)
    "Scheduled Series Calendar h did not move the month window back"
  let selectedCoverage ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageRow? coverageEvidence coverageNext)
    "Scheduled overview selected recurring plan disappeared"
  expect (selectedCoverage.rule.name == "paypay-transfer")
    "Scheduled overview row selection diverged from displayed order"

  -- Coverage replenishment starts before the first monitored gap, not at a later
  -- off-cadence explicit occurrence. This mirrors the household support case
  -- where extra Nov/Jan/Mar/May dates must not shift a bimonthly Oct/Dec/Feb/Apr pace.
  let supportOct ← requireSome
    (scheduledRecord? "support-oct" "2026-10-15" "support" "smbc" 11240)
    "support October fixture was not admitted"
  let supportNov ← requireSome
    (scheduledRecord? "support-nov" "2026-11-15" "support" "smbc" 11240)
    "support November fixture was not admitted"
  let supportFeb ← requireSome
    (scheduledRecord? "support-feb" "2027-02-15" "support" "smbc" 11240)
    "support February fixture was not admitted"
  let supportMar ← requireSome
    (scheduledRecord? "support-mar" "2027-03-15" "support" "smbc" 11240)
    "support March fixture was not admitted"
  let supportMay ← requireSome
    (scheduledRecord? "support-may" "2027-05-15" "support" "smbc" 11240)
    "support May fixture was not admitted"
  let supportRule : Loam.ScheduledCoverageConfig.Rule := {
    name := "support"
    anchor := "2026-10-15"
    everyMonths := 2
    negativeLoci := ["support"]
    positiveLoci := ["smbc"]
  }
  let supportRecords := [supportOct, supportNov, supportFeb, supportMar, supportMay]
  let supportScheduled ← requireSome (ScheduledMemory.ofOccurrences? supportRecords)
    "support Scheduled memory fixture was not admitted"
  let supportTerminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "support terminal memory fixture was not admitted"
  let supportEvents ← requireSome (EventMemory.ofEvents? [])
    "support Event memory fixture was not admitted"
  let supportEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := supportScheduled
    terminals := supportTerminals
    events := supportEvents
  }
  let supportSnapshot : Loam.Tui.Main.Snapshot := {
    actual := { today := "2026-09-30", allRecords := [] }
    scheduled := .ok supportEvidence
  }
  let supportCoverageSnapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [supportRule] supportRecords "2026-09-30" 8 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let some supportRow := supportCoverageSnapshot.rows[0]?
    | throw (IO.userError "support coverage row disappeared")
  expect (supportRow.firstMissing == some "2026-12")
    "support coverage fixture did not expose December as its first gap"
  let supportState := Loam.Tui.ScheduledWorkspace.initial "2026-09-30"
  let supportSource ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageReplenishmentRecord?
      supportSnapshot (.ok supportCoverageSnapshot) supportState)
    "support replenishment source disappeared"
  expect (supportSource.id.token == "support-oct")
    "Scheduled replenishment extended from a later off-cadence occurrence instead of the first gap"

  let supportDec ← requireSome
    (scheduledRecord? "support-dec" "2026-12-15" "support" "smbc" 11240)
    "support December fixture was not admitted"
  let supportFilledRecords := supportRecords ++ [supportDec]
  let supportFilledScheduled ← requireSome
    (ScheduledMemory.ofOccurrences? supportFilledRecords)
    "filled support Scheduled memory fixture was not admitted"
  let supportFilledEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := supportFilledScheduled
    terminals := supportTerminals
    events := supportEvents
  }
  let supportFilledSnapshot : Loam.Tui.Main.Snapshot := {
    actual := { today := "2026-09-30", allRecords := [] }
    scheduled := .ok supportFilledEvidence
  }
  let supportFilledCoverage ←
    match Loam.ScheduledCoverageReview.projectRecords
        [supportRule] supportFilledRecords "2026-09-30" 8 with
    | .error message => throw (IO.userError message)
    | .ok result => pure result
  let some supportFilledRow := supportFilledCoverage.rows[0]?
    | throw (IO.userError "filled support coverage row disappeared")
  expect (supportFilledRow.firstMissing == some "2027-04")
    "support replenishment did not advance from the filled December gap to April"
  let supportNextSource ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedCoverageReplenishmentRecord?
      supportFilledSnapshot (.ok supportFilledCoverage) supportState)
    "second support replenishment source disappeared"
  expect (supportNextSource.id.token == "support-feb")
    "Scheduled replenishment did not resume from the latest on-cadence occurrence before the next gap"

  let openPlan :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverageNext .openSelectedPlan).state
  expect (openPlan.viewMode == .planDetail)
    "Scheduled overview Enter action did not open focused Plan Detail"
  let planBack :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence openPlan .back
  expect (planBack.command == .stay && planBack.state.viewMode == .coverage)
    "Scheduled Plan Detail q/back did not return to the Series Calendar"

  let supportPlan :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportState .openSelectedPlan).state
  expect (supportPlan.viewMode == .planDetail)
    "support Series Calendar row did not open Plan Detail"
  let supportPlanText := widgetText
    (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 120, height := 30 }
      supportFilledSnapshot supportPlan (.ok supportFilledCoverage))
  expect (contains "Scheduled / Plan / support" supportPlanText &&
    contains "2026-11-15" supportPlanText && contains "[outside pace]" supportPlanText &&
    contains "2026-12-15" supportPlanText && contains "[on pace]" supportPlanText &&
    contains "2027-04" supportPlanText && contains "MISSING monitored month" supportPlanText)
    "Scheduled Plan Detail did not combine explicit, outside-pace, and missing rows"

  let supportOutside :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportPlan .next).state
  let outsideRecord ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord?
      supportFilledSnapshot (.ok supportFilledCoverage) supportOutside)
    "Scheduled Plan Detail lost its selected outside-pace occurrence"
  expect (outsideRecord.id.token == "support-nov")
    "Scheduled Plan Detail j/k did not move directly to the next occurrence"
  let cancelOutside :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportOutside .cancelScheduled
  expect (cancelOutside.command == .cancelScheduled)
    "Scheduled Plan Detail could not cancel an explicit outside-pace occurrence directly"

  let supportMissing :=
    (List.range 5).foldl
      (fun current _ =>
        (Loam.Tui.ScheduledWorkspace.updateWithCoverage
          supportFilledSnapshot (.ok supportFilledCoverage) current .next).state)
      supportPlan
  expect
    ((Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord?
      supportFilledSnapshot (.ok supportFilledCoverage) supportMissing).isNone)
    "Scheduled Plan Detail missing marker unexpectedly became an explicit occurrence"
  let cancelMissing :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage
      supportFilledSnapshot (.ok supportFilledCoverage) supportMissing .cancelScheduled
  expect (cancelMissing.command == .stay && contains "missing monitored month" cancelMissing.state.notice)
    "Scheduled Plan Detail did not protect a presentation-only missing row from cancellation"

  let coverageFill :=
    Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverageEvidence coverage .fillCurrentCycle
  expect (coverageFill.command == .stay && contains "Use e" coverageFill.state.notice)
    "Scheduled overview compatibility fill action did not redirect to replenishment"

  let board :=
    (Loam.Tui.ScheduledWorkspace.updateWithCoverage
      snapshot coverageEvidence coverage .toggleView).state
  expect (board.viewMode == .futureBoard && board.scope == .allCurrent &&
    board.pane == .occurrences && board.locusRow == 0)
    "Scheduled Months view did not normalize into the all-current occurrence view"
  let boardText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 } snapshot board)
  expect (contains "Scheduled / Months" boardText &&
    contains "[2026-09]" boardText && contains "[2026-10]" boardText)
    "Scheduled Months view did not render its six-month calendar blocks"
  expect (contains "Selected Scheduled Details:" boardText)
    "Scheduled Months view lost the shared selected-record details"
  let boardLeft := (Loam.Tui.ScheduledWorkspace.update snapshot board .focusLeft).state
  expect (boardLeft.pane == .occurrences && boardLeft.futureBoardMonthOffset == 0 &&
    contains "current calendar month" boardLeft.notice)
    "Scheduled Months left navigation did not stop cleanly at the current month"
  let boardRight :=
    (Loam.Tui.ScheduledWorkspace.update snapshot board .focusRight).state
  expect (boardRight.futureBoardMonthOffset == 1 && boardRight.pane == .occurrences)
    "Scheduled Months right navigation did not shift the six-month window"
  let boardRightText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 120, height := 30 } snapshot boardRight)
  expect (contains "2026-10 .. 2027-03" boardRightText &&
    contains "[2026-10]" boardRightText && contains "[2027-03]" boardRightText &&
    contains "horizontal wheel" boardRightText)
    "Scheduled Months shifted window did not render the expected later calendar range"
  let boardBack :=
    (Loam.Tui.ScheduledWorkspace.update snapshot boardRight .focusLeft).state
  expect (boardBack.futureBoardMonthOffset == 0)
    "Scheduled Months left navigation did not return to the previous calendar window"
  let boardFilter := (Loam.Tui.ScheduledWorkspace.update snapshot board .cycleFilter).state
  expect (boardFilter.scope == .allCurrent &&
    contains "Months always uses the current-open frontier" boardFilter.notice)
    "Scheduled Months view unexpectedly changed its all-current scope"
  let boardExtend := Loam.Tui.ScheduledWorkspace.update snapshot board .extendPlan
  expect (boardExtend.command == .extendPlan)
    "Scheduled Months view did not expose the simple extend action for its selected record"
  let boardStop := Loam.Tui.ScheduledWorkspace.update snapshot board .stopMonitoring
  expect (boardStop.command == .stopMonitoring)
    "Scheduled Months view did not expose the simple undecided action for its selected record"
  let boardFill := Loam.Tui.ScheduledWorkspace.update snapshot board .fillCurrentCycle
  expect (boardFill.command == .fillCurrentCycle)
    "Scheduled Months lost the compatibility fill action"
  let listAgain := (Loam.Tui.ScheduledWorkspace.update snapshot board .toggleView).state
  expect (listAgain.viewMode == .list)
    "Scheduled Months toggle did not continue to List"

  -- 5. Loci navigation and filtering
  let toLoci := (Loam.Tui.ScheduledWorkspace.update snapshot allCurrent .focusLeft).state
  expect (toLoci.pane == .loci)
    "Scheduled workspace focusLeft did not switch to loci pane"

  -- 6. Object-local command emission from occurrences pane
  let occPane := (Loam.Tui.ScheduledWorkspace.update snapshot allCurrent .focusRight).state

  let completeStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .completeScheduled
  expect (completeStep.command == .completeScheduled)
    "Scheduled workspace completeScheduled event did not emit completeScheduled command"

  let batchStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .batchEditScheduled
  expect (batchStep.command == .batchEditScheduled)
    "Scheduled occurrence could not open batch candidate editing"
  let shortNoticeState := { occPane with
    viewMode := Loam.Tui.ScheduledWorkspace.ViewMode.futureBoard
    notice := "Revised 2 Scheduled occurrences." }
  let shortNoticeText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 80, height := 18 } snapshot shortNoticeState)
  expect (contains shortNoticeState.notice shortNoticeText &&
    contains "[b] batch amount" shortNoticeText && contains "[x] cancel" shortNoticeText &&
    contains "[q] back" shortNoticeText)
    "short Months viewport hid batch publication feedback or displaced an existing action"
  for mode in [Loam.Tui.ScheduledWorkspace.ViewMode.list, .coverage, .planDetail] do
    let noticeState := { shortNoticeState with viewMode := mode }
    let text := widgetText (Loam.Tui.ScheduledWorkspace.viewWithCoverage
      { width := 80, height := 18 } snapshot noticeState coverageEvidence)
    expect (contains noticeState.notice text)
      "Scheduled projection hid canonical publication feedback in a short viewport"
  let replaceStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .replaceScheduled
  expect (replaceStep.command == .replaceScheduled)
    "Scheduled workspace replaceScheduled event did not emit replaceScheduled command"

  let cancelStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .cancelScheduled
  expect (cancelStep.command == .cancelScheduled)
    "Scheduled workspace cancelScheduled event did not emit cancelScheduled command"

  let createStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .createScheduled
  expect (createStep.command == .createScheduled)
    "Scheduled workspace createScheduled event did not emit createScheduled command"

  let extendStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .extendPlan
  expect (extendStep.command == .extendPlan)
    "Scheduled workspace extendPlan event did not emit extendPlan command"

  let paceStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .changePace
  expect (paceStep.command == .changePace)
    "Scheduled workspace changePace event did not emit changePace command"

  let stopMonitoringStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .stopMonitoring
  expect (stopMonitoringStep.command == .stopMonitoring)
    "Scheduled workspace stopMonitoring event did not emit stopMonitoring command"

  let fillStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .fillCurrentCycle
  expect (fillStep.command == .fillCurrentCycle)
    "Scheduled workspace fillCurrentCycle event did not emit fillCurrentCycle command"

  let monitorStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .monitorCoverage
  expect (monitorStep.command == .monitorCoverage)
    "Scheduled workspace monitorCoverage event did not emit monitorCoverage command"

  let selectedForMonitor ← requireSome
    (Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot occPane)
    "Scheduled workspace monitoring source disappeared"
  let monitorRule ←
    match Loam.Tui.ScheduledCoverageSetup.ruleFor? selectedForMonitor 1 with
    | .error message => throw (IO.userError message)
    | .ok rule => pure rule
  expect (monitorRule.anchor == selectedForMonitor.scheduledOn &&
    monitorRule.everyMonths == 1 &&
    monitorRule.name == "food")
    "Scheduled monitoring setup did not derive anchor/cadence/display identity from the selected occurrence"
  expect (Loam.ScheduledCoverageSelector.matchesRule selectedForMonitor monitorRule)
    "Scheduled monitoring setup produced a rule that the shared coverage selector would not match"

  let backStep := Loam.Tui.ScheduledWorkspace.update snapshot occPane .back
  expect (backStep.command == .back)
    "Scheduled workspace back event did not emit back command"

  -- 7. From loci pane, complete/replace/cancel are refused and emit .stay with notice
  let lociCompleteStep := Loam.Tui.ScheduledWorkspace.update snapshot toLoci .completeScheduled
  expect (lociCompleteStep.command == .stay)
    "Scheduled workspace completeScheduled from loci pane unexpectedly emitted a non-stay command"
  expect (contains "Scheduled pane" lociCompleteStep.state.notice)
    "Scheduled workspace complete notice from loci pane was missing guidance"
  let lociFillStep := Loam.Tui.ScheduledWorkspace.update snapshot toLoci .fillCurrentCycle
  expect (lociFillStep.command == .stay && contains "Scheduled pane" lociFillStep.state.notice)
    "Scheduled workspace cycle fill from loci pane was not refused with guidance"
  let lociMonitorStep := Loam.Tui.ScheduledWorkspace.update snapshot toLoci .monitorCoverage
  expect (lociMonitorStep.command == .stay && contains "Scheduled pane" lociMonitorStep.state.notice)
    "Scheduled workspace monitoring from loci pane was not refused with guidance"

  -- 8. Startup refusal remains explicit and blocks Scheduled writes.
  let unavailable : Loam.Tui.Main.Snapshot :=
    { snapshot with scheduled := .error "scheduled fixture unavailable" }
  let unavailableText := widgetText
    (Loam.Tui.ScheduledWorkspace.view { width := 100, height := 30 } unavailable start)
  expect (contains "Scheduled [Unavailable]" unavailableText &&
    contains "[Unavailable] scheduled fixture unavailable" unavailableText)
    "Scheduled workspace collapsed startup refusal into an empty Scheduled workspace"
  let unavailableBatch := Loam.Tui.ScheduledWorkspace.update unavailable start .batchEditScheduled
  expect (unavailableBatch.command == .stay)
    "unavailable Scheduled authority admitted batch editing"
  let unavailableCreate := Loam.Tui.ScheduledWorkspace.update unavailable start .createScheduled
  expect (unavailableCreate.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableCreate.state.notice)
    "Scheduled workspace emitted a write intent while Scheduled evidence was unavailable"
  let unavailableExtend := Loam.Tui.ScheduledWorkspace.update unavailable start .extendPlan
  expect (unavailableExtend.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableExtend.state.notice)
    "Scheduled workspace emitted extend intent while Scheduled evidence was unavailable"
  let unavailablePace := Loam.Tui.ScheduledWorkspace.update unavailable start .changePace
  expect (unavailablePace.command == .stay &&
    contains "[Unavailable] Scheduled" unavailablePace.state.notice)
    "Scheduled workspace emitted pace-change intent while Scheduled evidence was unavailable"
  let unavailableStop := Loam.Tui.ScheduledWorkspace.update unavailable start .stopMonitoring
  expect (unavailableStop.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableStop.state.notice)
    "Scheduled workspace emitted monitoring-removal intent while Scheduled evidence was unavailable"
  let unavailableFill := Loam.Tui.ScheduledWorkspace.update unavailable start .fillCurrentCycle
  expect (unavailableFill.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableFill.state.notice)
    "Scheduled workspace emitted cycle-fill intent while Scheduled evidence was unavailable"
  let unavailableMonitor := Loam.Tui.ScheduledWorkspace.update unavailable start .monitorCoverage
  expect (unavailableMonitor.command == .stay &&
    contains "[Unavailable] Scheduled" unavailableMonitor.state.notice)
    "Scheduled workspace emitted monitoring intent while Scheduled evidence was unavailable"

  IO.println "TUI Scheduled: Scheduled workspace mechanics and startup unavailability passed."
