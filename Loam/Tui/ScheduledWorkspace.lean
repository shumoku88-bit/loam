import Loam.Review.ScheduledCoverageReview
import Loam.Review.ScheduledCoverageSelector
import Loam.Tui.Calendar
import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.Tui.ScheduledCoveragePane
import Loam.Review.ScheduledReview

namespace Loam.Tui.ScheduledWorkspace

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

inductive Scope where
  | focusDay
  | allCurrent
  deriving Repr, DecidableEq, BEq

inductive Pane where
  | loci
  | occurrences
  deriving Repr, DecidableEq, BEq

inductive ViewMode where
  | coverage
  | planDetail
  | futureBoard
  | list
  deriving Repr, DecidableEq, BEq

structure State where
  focusDate : String
  scope : Scope := .allCurrent
  /-- Scheduled occurrences are the primary browse target; Loci remain an explicit filter pane. -/
  pane : Pane := .occurrences
  viewMode : ViewMode := .coverage
  locusRow : Nat := 0
  occurrenceRow : Nat := 0
  coverageRow : Nat := 0
  coverageMonthOffset : Nat := 0
  futureBoardMonthOffset : Nat := 0
  planRow : Nat := 0
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | pageUp
  | pageDown
  | home
  | «end»
  | focusLeft
  | focusRight
  | cycleFilter
  | toggleView
  | createScheduled
  | extendPlan
  | changePace
  | stopMonitoring
  | openSelectedPlan
  | fillCurrentCycle
  | monitorCoverage
  | completeScheduled
  | replaceScheduled
  | batchEditScheduled
  | cancelScheduled
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | createScheduled
  | extendPlan
  | changePace
  | stopMonitoring
  | fillCurrentCycle
  | monitorCoverage
  | completeScheduled
  | replaceScheduled
  | batchEditScheduled
  | cancelScheduled
  | back
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  command : Command := .stay


def initial (focusDate : String) : State :=
  { focusDate := focusDate }

/-- Compatibility/list-focused initializer used by focused mechanics and tests. -/
def initialList (focusDate : String) : State :=
  { focusDate := focusDate, scope := .focusDay, viewMode := .list }

abbrev Record := ScheduledOccurrence String
abbrev CoverageEvidence := Except String Loam.ScheduledCoverageReview.Snapshot

inductive PlanDetailEntry where
  | occurrence (record : Record) (onPace : Bool)
  | missing (month : String)

private def planDetailEntryKey : PlanDetailEntry → String
  | .occurrence record _ => record.scheduledOn
  | .missing month => month ++ "-00"

private def planDetailEntryBefore (left right : PlanDetailEntry) : Bool :=
  planDetailEntryKey left <= planDetailEntryKey right

/-- Presentation result for one Scheduled workspace scope. Unknown is not an empty answer. -/
inductive ScopeEvidence where
  | records (rows : List Record)
  | unknown

private def unavailableNotice? (snapshot : Snapshot) : Option String :=
  match snapshot.scheduled with
  | .error message => some ("[Unavailable] Scheduled: " ++ message)
  | .ok _ => none


def scopeEvidence (snapshot : Snapshot) (state : State) : Except String ScopeEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled =>
      match state.scope with
      | .focusDay =>
          match Loam.ScheduledReview.dayEvidence scheduled state.focusDate with
          | .error message => .error message
          | .ok (.due first rest) => .ok (.records (first :: rest))
          | .ok .unknown => .ok .unknown
      | .allCurrent =>
          match Loam.ScheduledReview.orderedCurrentOpenRecords scheduled with
          | .ok records => .ok (.records records)
          | .error message => .error message

/-- Local browse mechanics project only explicit rows; presentation completeness uses `scopeEvidence`. -/
def recordsForScope (snapshot : Snapshot) (state : State) : List Record :=
  match scopeEvidence snapshot state with
  | .ok (.records records) => records
  | .ok .unknown => []
  | .error _ => []

def lociForScope (snapshot : Snapshot) (state : State) : List String :=
  (recordsForScope snapshot state).flatMap (fun record =>
    record.movement.changes.map (fun change => change.coordinate.token)) |>.eraseDups

def selectedLocus? (snapshot : Snapshot) (state : State) : Option String :=
  if state.locusRow = 0 then none
  else (lociForScope snapshot state)[state.locusRow - 1]?

def visibleRecords (snapshot : Snapshot) (state : State) : List Record :=
  match selectedLocus? snapshot state with
  | none => recordsForScope snapshot state
  | some locus =>
      (recordsForScope snapshot state).filter fun record =>
        record.movement.changes.any fun change => change.coordinate.token == locus

def selectedRecord? (snapshot : Snapshot) (state : State) : Option Record :=
  (visibleRecords snapshot state)[state.occurrenceRow]?

def coverageRows (coverage : CoverageEvidence) : List Loam.ScheduledCoverageReview.Row :=
  match coverage with
  | .error _ => []
  | .ok snapshot => Loam.Tui.ScheduledCoveragePane.orderedRows snapshot

def selectedCoverageRow?
    (coverage : CoverageEvidence) (state : State) :
    Option Loam.ScheduledCoverageReview.Row :=
  (coverageRows coverage)[state.coverageRow]?

def coverageRowForRecord?
    (coverage : CoverageEvidence) (record : Record) : Option Nat :=
  ((coverageRows coverage).zipIdx.find? fun (row, _) =>
    Loam.ScheduledCoverageSelector.matchesRule record row.rule).map (·.2)

private def recordBefore (left right : Record) : Bool :=
  if left.scheduledOn = right.scheduledOn then
    left.id.token <= right.id.token
  else
    left.scheduledOn <= right.scheduledOn

private def recordsForRule
    (snapshot : Snapshot)
    (rule : Loam.ScheduledCoverageConfig.Rule) : List Record :=
  let allState : State := {
    focusDate := snapshot.actual.today
    scope := .allCurrent
    pane := .occurrences
    viewMode := .coverage
  }
  (recordsForScope snapshot allState).filter fun record =>
    Loam.ScheduledCoverageSelector.matchesRule record rule

def latestRecordForRule?
    (snapshot : Snapshot)
    (rule : Loam.ScheduledCoverageConfig.Rule) : Option Record :=
  ((recordsForRule snapshot rule).mergeSort recordBefore).getLast?

/--
Choose the explicit Scheduled template that should replenish one monitored row.

When the finite coverage projection exposes a gap, ignore later off-cadence
occurrences and anchor construction at the latest explicit occurrence on the
configured cadence before that first missing month. Repeated replenishment
therefore fills gaps in calendar order instead of extending from an unrelated
later explicit date.

If the visible monitored horizon has no gap, preserve the older extension
behavior by using the latest matching current-open occurrence.
-/
def replenishmentSourceForRow?
    (snapshot : Snapshot)
    (row : Loam.ScheduledCoverageReview.Row) : Option Record :=
  match row.firstMissing with
  | none => latestRecordForRule? snapshot row.rule
  | some missingMonth =>
      let missingStart := missingMonth ++ "-01"
      let candidates :=
        (recordsForRule snapshot row.rule).filter fun record =>
          decide (record.scheduledOn < missingStart) &&
            Loam.ScheduledCoverageReview.dateFallsOnExpectedMonth
              row.rule record.scheduledOn
      (candidates.mergeSort recordBefore).getLast?

def selectedCoverageRecord?
    (snapshot : Snapshot) (coverage : CoverageEvidence) (state : State) : Option Record := do
  let row ← selectedCoverageRow? coverage state
  latestRecordForRule? snapshot row.rule

def selectedCoverageReplenishmentRecord?
    (snapshot : Snapshot) (coverage : CoverageEvidence) (state : State) : Option Record := do
  let row ← selectedCoverageRow? coverage state
  replenishmentSourceForRow? snapshot row

/--
Project one monitored plan into a focused management list.

Explicit current-open Scheduled occurrences are always retained, including dates
outside the configured pace. Missing rows are presentation-only markers from the
finite coverage horizon. No series or recurrence identity is created.
-/
def planDetailEntries
    (snapshot : Snapshot)
    (row : Loam.ScheduledCoverageReview.Row) : List PlanDetailEntry :=
  let explicit :=
    (recordsForRule snapshot row.rule).map fun record =>
      .occurrence record
        (Loam.ScheduledCoverageReview.dateFallsOnExpectedMonth
          row.rule record.scheduledOn)
  let missing :=
    row.cells.filterMap fun cell =>
      if cell.expected && cell.explicitCount == 0 then some (.missing cell.month) else none
  (explicit ++ missing).mergeSort planDetailEntryBefore

def selectedPlanDetailEntry?
    (snapshot : Snapshot) (coverage : CoverageEvidence) (state : State) :
    Option PlanDetailEntry := do
  let row ← selectedCoverageRow? coverage state
  (planDetailEntries snapshot row)[state.planRow]?

def selectedPlanDetailRecord?
    (snapshot : Snapshot) (coverage : CoverageEvidence) (state : State) :
    Option Record := do
  match ← selectedPlanDetailEntry? snapshot coverage state with
  | .occurrence record _ => some record
  | .missing _ => none

private def clampPlanDetailState
    (snapshot : Snapshot) (coverage : CoverageEvidence) (state : State) : State :=
  match selectedCoverageRow? coverage state with
  | none => { state with planRow := 0 }
  | some row =>
      let count := (planDetailEntries snapshot row).length
      let planRow := if count = 0 then 0 else min state.planRow (count - 1)
      { state with planRow := planRow }

private def findRecordRow? (records : List Record) (id : String) : Option Nat :=
  let indexed := records.zipIdx
  (indexed.find? fun (record, _) => record.id.token == id).map (·.2)

private def clampCoverageState (coverage : CoverageEvidence) (state : State) : State :=
  let count := (coverageRows coverage).length
  let coverageRow := if count = 0 then 0 else min state.coverageRow (count - 1)
  let monthCount :=
    match coverage with
    | .error _ => 0
    | .ok snapshot => snapshot.months.length
  let coverageMonthOffset :=
    if monthCount = 0 then 0 else min state.coverageMonthOffset (monthCount - 1)
  { state with
    coverageRow := coverageRow
    coverageMonthOffset := coverageMonthOffset }

private def clampState (snapshot : Snapshot) (state : State) : State :=
  let lociCount := (lociForScope snapshot state).length
  let locusRow := min state.locusRow lociCount
  let withLocus := { state with locusRow := locusRow }
  let occCount := (visibleRecords snapshot withLocus).length
  let occurrenceRow :=
    if occCount = 0 then 0 else min withLocus.occurrenceRow (occCount - 1)
  { withLocus with occurrenceRow := occurrenceRow }

private def monthOrdinal (month : Loam.Tui.Calendar.Month) : Nat :=
  month.year * 12 + (month.month - 1)

private def futureBoardBaseMonth (snapshot : Snapshot) : Loam.Tui.Calendar.Month :=
  (Loam.Tui.Calendar.monthOf? snapshot.actual.today).getD { year := 1970, month := 1 }

private def followFutureBoardSelection (snapshot : Snapshot) (state : State) : State :=
  match selectedRecord? snapshot state with
  | none => state
  | some record =>
      match Loam.Tui.Calendar.monthOf? record.scheduledOn with
      | none => state
      | some selectedMonth =>
          let baseOrdinal := monthOrdinal (futureBoardBaseMonth snapshot)
          let selectedOrdinal := monthOrdinal selectedMonth
          if selectedOrdinal < baseOrdinal then
            { state with futureBoardMonthOffset := 0 }
          else
            let selectedOffset := selectedOrdinal - baseOrdinal
            let start := state.futureBoardMonthOffset
            if selectedOffset < start then
              { state with futureBoardMonthOffset := selectedOffset }
            else if start + 6 ≤ selectedOffset then
              { state with futureBoardMonthOffset := selectedOffset - 5 }
            else
              state

def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with notice := "" }

private def movePrevious (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      if state.locusRow = 0 then { state with notice := "No previous Locus row." }
      else clampState snapshot { state with locusRow := state.locusRow - 1, occurrenceRow := 0, notice := "" }
  | .occurrences =>
      if state.occurrenceRow = 0 then { state with notice := "No previous Scheduled row." }
      else { state with occurrenceRow := state.occurrenceRow - 1, notice := "" }

private def moveNext (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      if state.locusRow < count then
        clampState snapshot { state with locusRow := state.locusRow + 1, occurrenceRow := 0, notice := "" }
      else
        { state with notice := "No next Locus row." }
  | .occurrences =>
      let count := (visibleRecords snapshot state).length
      if state.occurrenceRow + 1 < count then
        { state with occurrenceRow := state.occurrenceRow + 1, notice := "" }
      else
        { state with notice := "No next Scheduled row." }

private def movePageUp (snapshot : Snapshot) (state : State) (pageSize : Nat := 8) : State :=
  match state.pane with
  | .loci =>
      if state.locusRow == 0 then { state with notice := "Top of Locus list." }
      else clampState snapshot { state with locusRow := state.locusRow - min state.locusRow pageSize, occurrenceRow := 0, notice := "" }
  | .occurrences =>
      if state.occurrenceRow == 0 then { state with notice := "Top of Scheduled list." }
      else { state with occurrenceRow := state.occurrenceRow - min state.occurrenceRow pageSize, notice := "" }

private def movePageDown (snapshot : Snapshot) (state : State) (pageSize : Nat := 8) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      if state.locusRow >= count then { state with notice := "End of Locus list." }
      else clampState snapshot { state with locusRow := min count (state.locusRow + pageSize), occurrenceRow := 0, notice := "" }
  | .occurrences =>
      let count := (visibleRecords snapshot state).length
      if count == 0 || state.occurrenceRow + 1 >= count then { state with notice := "End of Scheduled list." }
      else { state with occurrenceRow := min (count - 1) (state.occurrenceRow + pageSize), notice := "" }

private def moveHome (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci => clampState snapshot { state with locusRow := 0, occurrenceRow := 0, notice := "" }
  | .occurrences => { state with occurrenceRow := 0, notice := "" }

private def moveEnd (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      clampState snapshot { state with locusRow := count, occurrenceRow := 0, notice := "" }
  | .occurrences =>
      let count := (visibleRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with occurrenceRow := row, notice := "" }

private def cycleFilter (snapshot : Snapshot) (state : State) : State :=
  let scope := match state.scope with
    | .focusDay => Scope.allCurrent
    | .allCurrent => Scope.focusDay
  clampState snapshot { state with scope := scope, locusRow := 0, occurrenceRow := 0, notice := "" }

def updateWithCoverage
    (snapshot : Snapshot) (coverage : CoverageEvidence)
    (rawState : State) (event : Event) : Step :=
  let state := clampPlanDetailState snapshot coverage <| clampCoverageState coverage rawState
  match event with
  | .previous =>
      match state.viewMode with
      | .coverage =>
          if state.coverageRow = 0 then
            { state := { state with notice := "No previous recurring plan." } }
          else
            { state := { state with coverageRow := state.coverageRow - 1, notice := "" } }
      | .planDetail =>
          if state.planRow = 0 then
            { state := { state with notice := "Already at the first plan entry." } }
          else
            { state := { state with planRow := state.planRow - 1, notice := "" } }
      | .futureBoard => { state := followFutureBoardSelection snapshot (movePrevious snapshot state) }
      | .list => { state := movePrevious snapshot state }
  | .next =>
      match state.viewMode with
      | .coverage =>
          let count := (coverageRows coverage).length
          if state.coverageRow + 1 < count then
            { state := { state with coverageRow := state.coverageRow + 1, notice := "" } }
          else
            { state := { state with notice := "No next recurring plan." } }
      | .planDetail =>
          match selectedCoverageRow? coverage state with
          | none => { state := { state with notice := "Plan details are unavailable." } }
          | some row =>
              let count := (planDetailEntries snapshot row).length
              if state.planRow + 1 < count then
                { state := { state with planRow := state.planRow + 1, notice := "" } }
              else
                { state := { state with notice := "Already at the last plan entry." } }
      | .futureBoard => { state := followFutureBoardSelection snapshot (moveNext snapshot state) }
      | .list => { state := moveNext snapshot state }
  | .pageUp =>
      match state.viewMode with
      | .coverage =>
          { state := { state with coverageRow := state.coverageRow - min state.coverageRow 8, notice := "" } }
      | .planDetail =>
          { state := { state with planRow := state.planRow - min state.planRow 8, notice := "" } }
      | .futureBoard => { state := followFutureBoardSelection snapshot (movePageUp snapshot state) }
      | .list => { state := movePageUp snapshot state }
  | .pageDown =>
      match state.viewMode with
      | .coverage =>
          let count := (coverageRows coverage).length
          let target := if count == 0 then 0 else min (count - 1) (state.coverageRow + 8)
          { state := { state with coverageRow := target, notice := "" } }
      | .planDetail =>
          match selectedCoverageRow? coverage state with
          | none => { state := { state with notice := "Plan details are unavailable." } }
          | some row =>
              let count := (planDetailEntries snapshot row).length
              let target := if count == 0 then 0 else min (count - 1) (state.planRow + 8)
              { state := { state with planRow := target, notice := "" } }
      | .futureBoard => { state := followFutureBoardSelection snapshot (movePageDown snapshot state) }
      | .list => { state := movePageDown snapshot state }
  | .home =>
      match state.viewMode with
      | .coverage => { state := { state with coverageRow := 0, notice := "" } }
      | .planDetail => { state := { state with planRow := 0, notice := "" } }
      | .futureBoard => { state := followFutureBoardSelection snapshot (moveHome snapshot state) }
      | .list => { state := moveHome snapshot state }
  | .«end» =>
      match state.viewMode with
      | .coverage =>
          let count := (coverageRows coverage).length
          let target := if count == 0 then 0 else count - 1
          { state := { state with coverageRow := target, notice := "" } }
      | .planDetail =>
          match selectedCoverageRow? coverage state with
          | none => { state := { state with notice := "Plan details are unavailable." } }
          | some row =>
              let count := (planDetailEntries snapshot row).length
              let target := if count == 0 then 0 else count - 1
              { state := { state with planRow := target, notice := "" } }
      | .futureBoard => { state := followFutureBoardSelection snapshot (moveEnd snapshot state) }
      | .list => { state := moveEnd snapshot state }
  | .focusLeft =>
      match state.viewMode with
      | .coverage =>
          if state.coverageMonthOffset = 0 then
            { state := { state with notice := "Already at the first coverage month." } }
          else
            { state := { state with
                coverageMonthOffset := state.coverageMonthOffset - 1
                notice := "" } }
      | .planDetail =>
          { state := { state with notice := "Plan Detail uses one vertical plan list; j/k moves the selection." } }
      | .futureBoard =>
          if state.futureBoardMonthOffset = 0 then
            { state := { state with notice := "Already at the current calendar month." } }
          else
            { state := { state with
                futureBoardMonthOffset := state.futureBoardMonthOffset - 1
                notice := "" } }
      | .list => { state := { state with pane := .loci, notice := "" } }
  | .focusRight =>
      match state.viewMode with
      | .coverage =>
          match coverage with
          | .error _ =>
              { state := { state with notice := "Coverage months are unavailable." } }
          | .ok coverageSnapshot =>
              if state.coverageMonthOffset + 1 < coverageSnapshot.months.length then
                { state := { state with
                    coverageMonthOffset := state.coverageMonthOffset + 1
                    notice := "" } }
              else
                { state := { state with notice := "No later coverage month is loaded." } }
      | .planDetail =>
          { state := { state with notice := "Plan Detail uses one vertical plan list; j/k moves the selection." } }
      | .futureBoard =>
          { state := { state with
              futureBoardMonthOffset := state.futureBoardMonthOffset + 1
              notice := "" } }
      | .list => { state := { state with pane := .occurrences, notice := "" } }
  | .cycleFilter =>
      match state.viewMode with
      | .coverage =>
          { state := { state with notice := "The overview always uses the current-open frontier." } }
      | .planDetail =>
          { state := { state with notice := "Plan Detail always shows the selected plan's current-open occurrences." } }
      | .futureBoard =>
          { state := { state with notice := "Months always uses the current-open frontier; press v for scoped List." } }
      | .list => { state := cycleFilter snapshot state }
  | .toggleView =>
      match state.viewMode with
      | .coverage =>
          { state := clampState snapshot
              { state with
                viewMode := .futureBoard
                scope := .allCurrent
                pane := .occurrences
                locusRow := 0
                occurrenceRow := 0
                futureBoardMonthOffset := 0
                notice := "" } }
      | .planDetail =>
          { state := { state with viewMode := .coverage, notice := "" } }
      | .futureBoard =>
          { state := { state with viewMode := .list, notice := "" } }
      | .list =>
          { state := clampCoverageState coverage <| clampState snapshot
              { state with
                viewMode := .coverage
                scope := .allCurrent
                pane := .occurrences
                locusRow := 0
                occurrenceRow := 0
                notice := "" } }
  | .createScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none => { state, command := .createScheduled }
  | .extendPlan =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          match state.viewMode with
          | .coverage | .planDetail =>
              match selectedCoverageRecord? snapshot coverage state with
              | some _ => { state, command := .extendPlan }
              | none =>
                  { state := { state with notice :=
                      "This recurring plan has no current-open Scheduled occurrence to use as an extension template." } }
          | .futureBoard =>
              match state.pane with
              | .loci =>
                  { state := { state with notice := "Extend is available from the Scheduled plan pane." } }
              | .occurrences =>
                  match selectedRecord? snapshot state with
                  | none => { state := { state with notice := "No Scheduled plan is selected to extend." } }
                  | some _ => { state, command := .extendPlan }
          | .list =>
              match state.pane with
              | .loci =>
                  { state := { state with notice := "Extend is available from the Scheduled plan pane." } }
              | .occurrences =>
                  match selectedRecord? snapshot state with
                  | none => { state := { state with notice := "No Scheduled plan is selected to extend." } }
                  | some _ => { state, command := .extendPlan }
  | .changePace =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          match state.viewMode with
          | .coverage | .planDetail =>
              match selectedCoverageRecord? snapshot coverage state with
              | some _ => { state, command := .changePace }
              | none =>
                  { state := { state with notice :=
                      "This recurring plan has no current-open Scheduled occurrence from which to change its pace." } }
          | .futureBoard =>
              match state.pane with
              | .loci =>
                  { state := { state with notice := "Pace editing is available from the Scheduled plan pane." } }
              | .occurrences =>
                  match selectedRecord? snapshot state with
                  | none => { state := { state with notice := "No Scheduled plan is selected." } }
                  | some _ => { state, command := .changePace }
          | .list =>
              match state.pane with
              | .loci =>
                  { state := { state with notice := "Pace editing is available from the Scheduled plan pane." } }
              | .occurrences =>
                  match selectedRecord? snapshot state with
                  | none => { state := { state with notice := "No Scheduled plan is selected." } }
                  | some _ => { state, command := .changePace }
  | .stopMonitoring =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          match state.viewMode with
          | .coverage | .planDetail =>
              match selectedCoverageRow? coverage state with
              | some _ => { state, command := .stopMonitoring }
              | none => { state := { state with notice := "No recurring plan is selected." } }
          | .futureBoard =>
              match state.pane with
              | .loci =>
                  { state := { state with notice := "Stop monitoring is available from the Scheduled plan pane." } }
              | .occurrences =>
                  match selectedRecord? snapshot state with
                  | none => { state := { state with notice := "No Scheduled plan is selected." } }
                  | some _ => { state, command := .stopMonitoring }
          | .list =>
              match state.pane with
              | .loci =>
                  { state := { state with notice := "Stop monitoring is available from the Scheduled plan pane." } }
              | .occurrences =>
                  match selectedRecord? snapshot state with
                  | none => { state := { state with notice := "No Scheduled plan is selected." } }
                  | some _ => { state, command := .stopMonitoring }
  | .openSelectedPlan =>
      match state.viewMode with
      | .coverage =>
          match selectedCoverageRow? coverage state with
          | none =>
              { state := { state with notice := "No recurring plan is selected." } }
          | some _ =>
              { state := clampPlanDetailState snapshot coverage
                  { state with viewMode := .planDetail, planRow := 0, notice := "" } }
      | .planDetail => { state }
      | .futureBoard => { state }
      | .list => { state }
  | .fillCurrentCycle =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage || state.viewMode == .planDetail then
            { state := { state with notice := "Use e to replenish the selected recurring plan." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Fill cycle is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice :=
                  "No current-open Scheduled occurrence is selected as the cycle-fill source." } }
              | some _ => { state, command := .fillCurrentCycle }
  | .monitorCoverage =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage || state.viewMode == .planDetail then
            match selectedCoverageRecord? snapshot coverage state with
            | some _ => { state, command := .changePace }
            | none => { state := { state with notice :=
                "This recurring plan has no current-open Scheduled occurrence from which to change its pace." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Plan monitoring is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice :=
                  "No current-open Scheduled occurrence is selected for monitoring." } }
              | some _ => { state, command := .monitorCoverage }
  | .completeScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage then
            { state := { state with notice := "Press Enter to inspect the selected plan before completing one occurrence." } }
          else if state.viewMode == .planDetail then
            match selectedPlanDetailRecord? snapshot coverage state with
            | some _ => { state, command := .completeScheduled }
            | none => { state := { state with notice := "The selected row is a missing monitored month, not an explicit Scheduled occurrence. Use e to replenish it." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Complete is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for completion." } }
              | some _ => { state, command := .completeScheduled }
  | .batchEditScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          let source :=
            if state.viewMode == .coverage || state.viewMode == .planDetail then
              selectedCoverageRecord? snapshot coverage state
            else if state.pane == .occurrences then selectedRecord? snapshot state
            else none
          match source with
          | some _ => { state, command := .batchEditScheduled }
          | none => { state := { state with notice := "Select an explicit Scheduled reference for batch amount editing." } }
  | .replaceScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage then
            { state := { state with notice := "Press Enter to inspect the selected plan before replacing one occurrence." } }
          else if state.viewMode == .planDetail then
            match selectedPlanDetailRecord? snapshot coverage state with
            | some _ => { state, command := .replaceScheduled }
            | none => { state := { state with notice := "The selected row is a missing monitored month, not an explicit Scheduled occurrence." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Replace is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for supersede." } }
              | some _ => { state, command := .replaceScheduled }
  | .cancelScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage then
            { state := { state with notice := "Press Enter to inspect the selected plan before cancelling one occurrence." } }
          else if state.viewMode == .planDetail then
            match selectedPlanDetailRecord? snapshot coverage state with
            | some _ => { state, command := .cancelScheduled }
            | none => { state := { state with notice := "The selected row is a missing monitored month, not an explicit Scheduled occurrence." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Cancel is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for cancellation." } }
              | some _ => { state, command := .cancelScheduled }
  | .back =>
      if state.viewMode == .planDetail then
        { state := { state with viewMode := .coverage, planRow := 0, notice := "" } }
      else
        { state, command := .back }
  | .other => { state }

def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  updateWithCoverage snapshot (.error "coverage unavailable") state event

/-- Update workspace state with coverage evidence, optionally scaling directional navigation by repeat count. -/
def updateWithCoverageWithRepeat
    (snapshot : Snapshot) (coverage : CoverageEvidence)
    (rawState : State) (event : Event) (repeatCount : Nat := 1) : Step :=
  if repeatCount <= 1 then updateWithCoverage snapshot coverage rawState event
  else
    let state := clampPlanDetailState snapshot coverage <| clampCoverageState coverage rawState
    match event with
    | .previous =>
        match state.viewMode with
        | .coverage =>
            { state := { state with coverageRow := state.coverageRow - min state.coverageRow repeatCount, notice := "" } }
        | .planDetail =>
            { state := { state with planRow := state.planRow - min state.planRow repeatCount, notice := "" } }
        | .futureBoard => { state := followFutureBoardSelection snapshot (movePageUp snapshot state repeatCount) }
        | .list => { state := movePageUp snapshot state repeatCount }
    | .next =>
        match state.viewMode with
        | .coverage =>
            let count := (coverageRows coverage).length
            let target := if count == 0 then 0 else min (count - 1) (state.coverageRow + repeatCount)
            { state := { state with coverageRow := target, notice := "" } }
        | .planDetail =>
            match selectedCoverageRow? coverage state with
            | none => { state := { state with notice := "Plan details are unavailable." } }
            | some row =>
                let count := (planDetailEntries snapshot row).length
                let target := if count == 0 then 0 else min (count - 1) (state.planRow + repeatCount)
                { state := { state with planRow := target, notice := "" } }
        | .futureBoard => { state := followFutureBoardSelection snapshot (movePageDown snapshot state repeatCount) }
        | .list => { state := movePageDown snapshot state repeatCount }
    | other => updateWithCoverage snapshot coverage rawState other

def updateWithRepeat (snapshot : Snapshot) (state : State) (event : Event) (repeatCount : Nat := 1) : Step :=
  updateWithCoverageWithRepeat snapshot (.error "coverage unavailable") state event repeatCount

private def fit (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padRight width text

private def scopeText (snapshot : Snapshot) (state : State) : String :=
  match state.scope with
  | .focusDay => "Focus Day (" ++ state.focusDate ++ ")"
  | .allCurrent => "All Current-Open (known through " ++ snapshot.actual.today ++ ")"

private def currentLocusName (snapshot : Snapshot) (state : State) : String :=
  (selectedLocus? snapshot state).getD "All loci"

private def paneWindowStart (selected visibleRows : Nat) : Nat :=
  Loam.Tui.Layout.trailingWindowStart selected (max 1 visibleRows)

private def locusLabel (snapshot : Snapshot) (state : State) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else (lociForScope snapshot state)[row - 1]?

/-- Bounds-only target for the List detail viewport; its frame adds two rows. -/
def detailCapacityForBounds (bounds : Bounds) : Nat :=
  if bounds.height ≥ 48 then 10 else if bounds.height ≥ 36 then 8 else 6

private def noticeLines (bounds : Bounds) (state : State) : List String :=
  if state.notice.isEmpty then []
  else
    let width := Loam.Tui.Layout.contentWidth bounds
    (Loam.Tui.Layout.flowTokens width " " (state.notice.splitOn " ")).flatMap
      (Loam.Tui.Layout.wrapColumns width)




private def monthsFrom
    (month : Loam.Tui.Calendar.Month) : Nat → List Loam.Tui.Calendar.Month
  | 0 => []
  | n + 1 => month :: monthsFrom (Loam.Tui.Calendar.nextMonth month) n

private def monthAfter
    (month : Loam.Tui.Calendar.Month) : Nat → Loam.Tui.Calendar.Month
  | 0 => month
  | n + 1 => monthAfter (Loam.Tui.Calendar.nextMonth month) n

private def futureBoardMonths
    (snapshot : Snapshot) (state : State) : List Loam.Tui.Calendar.Month :=
  let start := monthAfter (futureBoardBaseMonth snapshot) state.futureBoardMonthOffset
  monthsFrom start 6

private def recordDay (record : Record) : String :=
  match Loam.Tui.Calendar.parseDate? record.scheduledOn with
  | some (_, _, day) => Loam.Tui.Calendar.padded 2 day
  | none => "??"

private def recordsInMonth
    (snapshot : Snapshot) (state : State) (month : Loam.Tui.Calendar.Month) : List Record :=
  (visibleRecords snapshot state).filter fun record =>
    match Loam.Tui.Calendar.monthOf? record.scheduledOn with
    | none => false
    | some actual => decide (actual = month)

private def findRecordIndex? (id : String) : List Record → Nat → Option Nat
  | [], _ => none
  | record :: rest, index =>
      if record.id.token == id then some index
      else findRecordIndex? id rest (index + 1)

private def monthWindow
    (records : List Record) (selectedId? : Option String)
    (maxVisible : Nat) : List (Nat × Record) :=
  let selectedIndex? := selectedId?.bind fun id => findRecordIndex? id records 0
  match selectedIndex? with
  | some selected => Loam.Tui.Layout.centeredListWindow records selected maxVisible
  | none => (records.take maxVisible).zipIdx.map fun (record, index) => (index, record)

/-- A receiving quantity, never an invented total across split movement changes. -/
private def recordQuantity (record : Record) : String :=
  let negative := record.movement.changes.filter (fun change => change.quantity.quanta < 0)
  let positive := record.movement.changes.filter (fun change => 0 < change.quantity.quanta)
  match negative, positive with
  | [_], [destination] =>
      Loam.MeasurePresentation.groupDisplayedNumber (toString destination.quantity.quanta) ++
        " " ++ record.measure.token
  | _, _ => if record.movement.changes.isEmpty then "—"
      else s!"split ({record.movement.changes.length})"

private def fitLabel (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text <= width then fit width text
  else fit width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

private def monthCard
    (width height : Nat) (snapshot : Snapshot) (state : State)
    (selectedId? : Option String) (month : Loam.Tui.Calendar.Month) : Widget :=
  let records := recordsInMonth snapshot state month
  let maxVisible := height - 2
  let innerWidth := width - 2
  let shown := monthWindow records selectedId? maxVisible
  let focused := records.any (fun record => selectedId? == some record.id.token)
  let quantityWidth := min (innerWidth - 16) (min 22 (max 12
    (records.foldl (fun widest record => max widest
      (Loam.Tui.Layout.displayWidth (recordQuantity record))) 0)))
  let recordLines := shown.map fun (_, record) =>
    let selected := selectedId? == some record.id.token
    let marker := if selected then "> " else "  "
    let selector := Loam.ScheduledCoverageSelector.ofRecord record
    let shape := String.intercalate "," selector.negativeLoci ++ " -> " ++
      String.intercalate "," selector.positiveLoci
    let quantity := recordQuantity record
    let text := marker ++ recordDay record ++ "  " ++
      fitLabel (innerWidth - 8 - quantityWidth) shape ++ "  " ++
      Loam.Tui.Layout.padLeft quantityWidth
        (if Loam.Tui.Layout.displayWidth quantity <= quantityWidth then quantity else "too wide")
    .row [span (fit innerWidth text) (if selected then .selected else .normal)]
  let start := shown.head?.map Prod.fst |>.getD 0
  let more := (if start > 0 then " ▲" else "") ++
    (if start + shown.length < records.length then " ▼" else "")
  let content := if records.isEmpty then [mutedLine " No explicit plan"] else recordLines
  Loam.Tui.Layout.framedPanel width height (Loam.Tui.Calendar.monthLabel month)
    (.column content) focused (some (s!"{records.length} explicit" ++ more))

private def futureBoardRows
    (width cardHeight : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let leftWidth := (width - 1) / 2
  let rightWidth := width - leftWidth - 1
  let months := futureBoardMonths snapshot state
  let selectedId? := (selectedRecord? snapshot state).map fun record => record.id.token
  (List.range 3).flatMap fun row =>
    let left := months[row * 2]?.map
      (monthCard leftWidth cardHeight snapshot state selectedId?) |>.getD (.row [])
    let right := months[row * 2 + 1]?.map
      (monthCard rightWidth cardHeight snapshot state selectedId?) |>.getD (.row [])
    Loam.Tui.Layout.sideBySide cardHeight leftWidth rightWidth left right " "

private def paceLabel (rule : Loam.ScheduledCoverageConfig.Rule) : String :=
  match rule.everyMonths with
  | 0 => "undecided"
  | 1 => "monthly"
  | n => "every " ++ toString n ++ " months"

/-- Align quantity summaries without inventing a total or guessing a display scale. -/
private def planDetailQuantity : PlanDetailEntry → String
  | .missing _ => "—"
  | .occurrence record _ => recordQuantity record

private def planDetailTableRow
    (width quantityWidth : Nat) (date status quantity : String) : String :=
  let statusWidth := width - 10 - 4 - quantityWidth
  Loam.Tui.Layout.padRight 10 date ++ "  " ++
    Loam.Tui.Layout.padRight statusWidth status ++ "  " ++
    Loam.Tui.Layout.padLeft quantityWidth
      (if Loam.Tui.Layout.displayWidth quantity <= quantityWidth then quantity else "too wide")

private def planDetailEntryLine
    (width quantityWidth : Nat) (state : State) (index : Nat) (entry : PlanDetailEntry) : Widget :=
  let selected := index == state.planRow
  let marker := if selected then "> " else "  "
  let tabular := width >= 42
  let statusWidth := (width - 2) - 10 - 4 - quantityWidth
  let (date, status) := match entry with
    | .missing month =>
        (month, if tabular && statusWidth >= 22 then "MISSING monitored month" else "MISSING")
    | .occurrence record onPace =>
        (record.scheduledOn, if onPace then "[on pace]" else "[outside pace]")
  let text := marker ++ (if tabular then
      planDetailTableRow (width - 2) quantityWidth date status (planDetailQuantity entry)
    else date ++ " " ++ status)
  let fitted := if Loam.Tui.Layout.displayWidth text <= width then
      Loam.Tui.Layout.padRight width text
    else Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")
  .row [span fitted (if selected then .selected else .normal)]

/-- Two operation-only rows, independent of notice text and terminal height. -/
private def navigationFooter (bounds : Bounds) (mode : ViewMode) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let planDetail := mode == .planDetail
  let months := mode == .futureBoard
  let list := mode == .list
  let (primary, secondary) : List (String × String) × List (String × String) :=
    if width >= 79 then
      if list then
        ([("j/k", "select"), ("h/l", "pane"), ("f", "scope"), ("c/Enter", "complete"), ("q", "back")],
         [("e", "extend"), ("s", "undecided"), ("n", "new"), ("r", "replace"),
          ("b", "batch"), ("x", "cancel"), ("v", "overview")])
      else if months then
        ([("j/k", "select"), ("h/l", "months"), ("c/Enter", "complete"), ("q", "back")],
         [("e", "extend"), ("b", "batch"), ("r", "replace"), ("x", "cancel"),
          ("s", "undecided"), ("n", "new"), ("v", "List")])
      else if planDetail then
        ([("j/k", "select"), ("c/Enter", "complete"), ("q", "overview")],
         [("e", "replenish"), ("b", "batch"), ("r", "replace"), ("x", "cancel"),
          ("p", "pace"), ("s", "undecided")])
      else
        ([("j/k", "plan"), ("h/l", "months"), ("Enter", "detail"), ("q", "back")],
         [("e", "replenish"), ("b", "batch"), ("p", "pace"), ("s", "undecided"),
          ("n", "new"), ("v", "views")])
    else if width >= 47 then
      if list then
        ([("j/k", "select"), ("h/l", "pane"), ("f", "scope"), ("q", "back")],
         [("c/Enter", "complete"), ("b", "batch"), ("v", "overview")])
      else if months then
        ([("j/k", "select"), ("c/Enter", "complete"), ("q", "back")],
         [("h/l", "months"), ("b", "batch"), ("x", "cancel"), ("v", "List")])
      else if planDetail then
        ([("j/k", "select"), ("c/Enter", "complete"), ("q", "overview")],
         [("e", "replenish"), ("b", "batch"), ("r", "replace"), ("x", "cancel")])
      else
        ([("j/k", "plan"), ("h/l", "months"), ("Enter", "detail"), ("q", "back")],
         [("e", "replenish"), ("b", "batch"), ("p", "pace"), ("s", "undecided")])
    else if width >= 29 then
      if list then
        ([("j/k", "select"), ("q", "back")], [("h/l", "pane"), ("f", "scope")])
      else if months then
        ([("j/k", "select"), ("q", "back")], [("h/l", "months"), ("v", "List")])
      else if planDetail then
        ([("j/k", "select"), ("q", "overview")], [("c/Enter", "complete"), ("x", "cancel")])
      else
        ([("j/k", "plan"), ("q", "back")], [("Enter", "detail"), ("v", "views")])
    else if width >= 14 then
      ([("j/k", ""), ("q", "back")],
        if planDetail || months || list then [("c/Enter", ""), ("x", "")]
        else [("Enter", ""), ("e", "")])
    else ([("q", "back")], [(if planDetail || months || list then "c/Enter" else "Enter", "")])
  let separator := if width >= 79 && !months && !list then "  " else " "
  [Loam.Tui.Layout.shortcutRow primary separator, Loam.Tui.Layout.shortcutRow secondary separator]

/-- Meaning belongs next to the table, not in its operation bar. -/
private def workspaceLegend (bounds : Bounds) (planDetail : Bool) : List Widget :=
  let compact := bounds.height < 18
  let tokens := if planDetail then
      if compact then ["MISSING = gap only;", "quantities are quanta"]
      else ["Explicit dates;", "pace = guidance;", "MISSING is not an occurrence;", "exact quanta."]
    else
      if compact then ["days = plan;", "! = gap;", "blank = not expected"]
      else ["days = explicit;", "! = expected gap;", "blank = not expected;", "pace = guidance only"]
  (Loam.Tui.Layout.flowTokens (Loam.Tui.Layout.contentWidth bounds) " " tokens).map mutedLine

/-- Reserve ordinary one-line feedback; longer refusals still keep their complete text. -/
private def reservedNoticeFooter (bounds : Bounds) (state : State) (help : List Widget) : List Widget :=
  let feedback := noticeLines bounds state
  (if feedback.isEmpty then [mutedLine ""] else feedback.map plainLine) ++ help

/-- Shared physical clipping for all framed Scheduled workspaces. -/
private def boundedWorkspace (bounds : Bounds) (body : Widget) (footerLines : List Widget) : Widget :=
  let writable := Loam.Tui.Layout.contentWidth bounds
  let bodyLines := Loam.Tui.Layout.widgetRows body
  let fitted := Loam.Tui.Layout.fitWithFooter bounds bodyLines footerLines
  .column ((fitted.take (bounds.height - 1)).map fun row =>
    .column (Loam.Tui.Layout.clippedWidgetRows writable row))

private def selectedDetailLines
    (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  let metadata := fun (text : String) => (Loam.Tui.Layout.wrapColumns width text).map mutedLine
  match selectedRecord? snapshot state with
  | none => match scopeEvidence snapshot state with
      | .error message => (Loam.Tui.Layout.wrapColumns width ("[Unavailable] " ++ message)).map plainLine
      | .ok .unknown => [mutedLine " Unknown; no completeness horizon claimed."]
      | .ok (.records _) => [mutedLine " No Scheduled occurrence selected."]
  | some record =>
      [mutedLine " Expected Effects (exact quanta):"] ++
      (record.movement.changes.flatMap fun change =>
        let sign := if change.quantity.quanta >= 0 then "+" else ""
        let text := sign ++ Loam.MeasurePresentation.groupDisplayedNumber
          (toString change.quantity.quanta) ++ " " ++ record.measure.token ++
          "  " ++ change.coordinate.token
        (Loam.Tui.Layout.wrapColumns width text).map plainLine) ++
      metadata ("Date: " ++ record.scheduledOn) ++ metadata ("ID: " ++ record.id.token)

private def listPosition (selected capacity total : Nat) : String :=
  let start := paneWindowStart selected capacity
  (if total == 0 then "0/0" else s!"{selected + 1}/{total}") ++
    (if start > 0 then " ▲" else "") ++ (if start + capacity < total then " ▼" else "")

private def listLociPanel
    (width height : Nat) (snapshot : Snapshot) (state : State) : Widget :=
  let innerWidth := width - 2
  let capacity := height - 2
  let focused := state.pane == .loci
  let (title, content, position) : String × List Widget × Option String :=
    match scopeEvidence snapshot state with
    | .error _ => ("Loci [Unavailable]", [mutedLine " Locus evidence unavailable."], none)
    | .ok .unknown => ("Loci [Unknown]", [mutedLine " Locus evidence unknown."], none)
    | .ok (.records _) =>
        let total := (lociForScope snapshot state).length + 1
        let start := paneWindowStart state.locusRow capacity
        let rows := (List.range (min capacity (total - start))).map fun offset =>
          let index := start + offset
          let selected := index == state.locusRow
          let marker := if selected then (if focused then "> " else "* ") else "  "
          Widget.row [span (marker ++ fitLabel (innerWidth - 2)
            ((locusLabel snapshot state index).getD ""))
            (if selected && focused then .selected else .normal)]
        ("Loci", rows, some (listPosition state.locusRow capacity total))
  Loam.Tui.Layout.framedPanel width height title (.column content) focused position

private def listTableRow
    (width quantityWidth : Nat) (date shape quantity : String) : String :=
  fit 10 date ++ "  " ++ fitLabel (width - 14 - quantityWidth) shape ++ "  " ++
    Loam.Tui.Layout.padLeft quantityWidth
      (if Loam.Tui.Layout.displayWidth quantity <= quantityWidth then quantity else "too wide")

private def listOccurrencesPanel
    (width height : Nat) (snapshot : Snapshot) (state : State) : Widget :=
  let innerWidth := width - 2
  let focused := state.pane == .occurrences
  let showHeader := height >= 4 && innerWidth >= 32
  let capacity := height - 2 - (if showHeader then 1 else 0)
  let records := visibleRecords snapshot state
  let quantityWidth := min (innerWidth - 24) (min 22 (max 12
    (records.foldl (fun widest record => max widest
      (Loam.Tui.Layout.displayWidth (recordQuantity record))) 0)))
  let (title, content, position) : String × List Widget × Option String :=
    match scopeEvidence snapshot state with
    | .error message => ("Scheduled [Unavailable]",
        (Loam.Tui.Layout.wrapColumns innerWidth ("[Unavailable] " ++ message)).map plainLine, none)
    | .ok .unknown => ("Scheduled [Unknown]",
        (Loam.Tui.Layout.wrapColumns innerWidth "Unknown; no completeness horizon claimed").map mutedLine, none)
    | .ok (.records _) =>
        let start := paneWindowStart state.occurrenceRow capacity
        let header := if showHeader then [mutedLine ("  " ++
            listTableRow (innerWidth - 2) quantityWidth "Date" "Shape" "Quanta")] else []
        let rows := ((records.drop start).take capacity).zipIdx.map fun (record, offset) =>
          let selected := start + offset == state.occurrenceRow
          let marker := if selected then (if focused then "> " else "* ") else "  "
          let selector := Loam.ScheduledCoverageSelector.ofRecord record
          let shape := String.intercalate "," selector.negativeLoci ++ " -> " ++
            String.intercalate "," selector.positiveLoci
          let quantity := recordQuantity record
          let text := if innerWidth >= 32 then marker ++
              listTableRow (innerWidth - 2) quantityWidth record.scheduledOn shape quantity
            else marker ++ record.scheduledOn ++ " " ++
              (if Loam.Tui.Layout.displayWidth quantity <= innerWidth - 13 then quantity else "too wide")
          Widget.row [span (fitLabel innerWidth text)
            (if selected && focused then .selected else .normal)]
        let empty := if state.locusRow > 0 then "No matching Scheduled occurrences for this Locus."
          else match state.scope with
            | .focusDay => "(none due on this day)"
            | .allCurrent => "(no current-open Scheduled occurrences)"
        (s!"Scheduled ({records.length})",
          if records.isEmpty then (Loam.Tui.Layout.wrapColumns innerWidth empty).map mutedLine
          else header ++ rows, some (listPosition state.occurrenceRow capacity records.length))
  Loam.Tui.Layout.framedPanel width height title (.column content) focused position

private def listView (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let writable := Loam.Tui.Layout.contentWidth bounds
  let footerLines := reservedNoticeFooter bounds state (navigationFooter bounds .list)
  let legend := (Loam.Tui.Layout.flowTokens writable " "
    ["Exact quanta;", "split = multiple changes."]).map mutedLine
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length - legend.length
  let contextRows := if bodyCapacity >= 9 then 2 else if bodyCapacity >= 4 then 1 else 0
  let available := bodyCapacity - contextRows
  let detailHeight := if available >= 13 then min (detailCapacityForBounds bounds + 2)
      (available - 5) else 0
  let panelHeight := available - detailHeight
  let context :=
    [plainLine (" Scheduled / List  |  " ++ scopeText snapshot state),
     mutedLine (" Locus: " ++ currentLocusName snapshot state)]
  let context := context.map fun widget => Widget.column (widget.lines.map fun cells =>
    let text := String.ofList (cells.map Cell.glyph)
    if Loam.Tui.Layout.displayWidth text <= writable then Widget.row
        (cells.map fun cell => span (String.singleton cell.glyph) cell.style)
    else mutedLine (Loam.Tui.Layout.clip (writable - 1) text ++ "…"))
  let panels := if bounds.width >= 80 then
      let leftWidth := min 30 (max 20 (writable / 4))
      let rightWidth := writable - leftWidth - 1
      Loam.Tui.Layout.sideBySide panelHeight leftWidth rightWidth
        (listLociPanel leftWidth panelHeight snapshot state)
        (listOccurrencesPanel rightWidth panelHeight snapshot state) " "
    else [if state.pane == .loci then listLociPanel writable panelHeight snapshot state
      else listOccurrencesPanel writable panelHeight snapshot state]
  let detailContent := selectedDetailLines (writable - 2) snapshot state
  let detailOverflow := if detailContent.length > detailHeight - 2 then
      some (s!"{detailHeight - 2}/{detailContent.length} lines ▼") else none
  let details := if detailHeight == 0 then [] else
      [Loam.Tui.Layout.framedPanel writable detailHeight "Selected Scheduled"
        (.column detailContent) false detailOverflow]
  boundedWorkspace bounds (.column (context.take contextRows ++ panels ++ details ++ legend)) footerLines

private def futureBoardView
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let writable := Loam.Tui.Layout.contentWidth bounds
  let footerLines := reservedNoticeFooter bounds state (navigationFooter bounds .futureBoard)
  let legend := (Loam.Tui.Layout.flowTokens writable " "
    ["Explicit plans;", "exact quanta;", "wheel = select;", "horizontal wheel = months"]).map mutedLine
  let tableCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length - legend.length
  let contextRows := if tableCapacity >= 11 then 2 else if tableCapacity >= 4 then 1 else 0
  let available := tableCapacity - contextRows
  let months := futureBoardMonths snapshot state
  let window := match months.head?, months.getLast? with
    | some first, some last => Loam.Tui.Calendar.monthLabel first ++ " .. " ++ Loam.Tui.Calendar.monthLabel last
    | _, _ => "(no visible month window)"
  let context := [plainLine " Scheduled / Months",
    mutedLine (" " ++ window ++ "  |  known through " ++ snapshot.actual.today)]
  let content : List Widget := match scopeEvidence snapshot state with
    | .error message =>
        [Loam.Tui.Layout.framedPanel writable available "Months [Unavailable]"
          (.column ((Loam.Tui.Layout.wrapColumns (writable - 2)
            ("[Unavailable] " ++ message)).map plainLine))]
    | .ok .unknown =>
        [Loam.Tui.Layout.framedPanel writable available "Months [Unknown]"
          (mutedLine " Unknown; no completeness horizon claimed.")]
    | .ok (.records _) =>
        let canShowBoard := bounds.width >= 80 && available >= 9
        let detailRoom := if canShowBoard then available - 9 else available / 2
        let detailHeight := if detailRoom >= 3 then min 8 detailRoom else 0
        let boardHeight := available - detailHeight
        let board := if canShowBoard then
            futureBoardRows writable (boardHeight / 3) snapshot state ++
              List.replicate (boardHeight % 3) blankLine
          else
            [Loam.Tui.Layout.framedPanel writable boardHeight "Months [compact]"
              (.column ((Loam.Tui.Layout.wrapColumns (writable - 2)
                "The six-month board needs 80 columns and more height; v opens List.").map mutedLine))]
        let detailContent := selectedDetailLines (writable - 2) snapshot state
        let visibleDetails := detailHeight - 2
        let overflow := if detailContent.length > visibleDetails then some
            (s!"{visibleDetails}/{detailContent.length} lines ▼") else none
        board ++ (if detailHeight == 0 then [] else
          [Loam.Tui.Layout.framedPanel writable detailHeight "Selected Scheduled"
            (.column detailContent) false overflow])
  boundedWorkspace bounds (.column (context.take contextRows ++ content ++ legend)) footerLines

private def planDetailView
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State)
    (coverage : CoverageEvidence) : Widget :=
  let state := clampPlanDetailState snapshot coverage (clampCoverageState coverage rawState)
  let footerLines := reservedNoticeFooter bounds state (navigationFooter bounds .planDetail)
  let legend := workspaceLegend bounds true
  let writable := Loam.Tui.Layout.contentWidth bounds
  let tableCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length - legend.length
  let contextRows := if tableCapacity >= 9 then 3 else if tableCapacity >= 6 then 2
    else if tableCapacity >= 4 then 1 else 0
  let panelHeight := tableCapacity - contextRows
  let innerWidth := writable - 2
  let innerHeight := panelHeight - 2
  let showHeader := innerHeight >= 2 && innerWidth >= 42
  let capacity := innerHeight - (if showHeader then 1 else 0)
  let readError := match scopeEvidence snapshot { state with scope := .allCurrent }, coverage with
    | .error message, _ => some ("[Unavailable] Scheduled: " ++ message)
    | _, .error message => some ("[Coverage unavailable] " ++ message)
    | _, _ => none
  let (context, title, content, position) : List Widget × String × List Widget × Option String :=
    match readError with
    | some message =>
        ([plainLine " Scheduled / Plan", mutedLine " Evidence unavailable"], "Plan [Unavailable]",
          (Loam.Tui.Layout.wrapColumns innerWidth message).map plainLine, none)
    | none => match selectedCoverageRow? coverage state with
      | none =>
          ([plainLine " Scheduled / Plan"], "Plan",
            [mutedLine " No recurring plan is selected."], none)
      | some row =>
          let entries := planDetailEntries snapshot row
          let total := entries.length
          let start := Loam.Tui.Layout.trailingWindowStart state.planRow (max 1 capacity)
          let shown := (entries.drop start).take capacity
          let quantityWidth := min (innerWidth - 2 - 10 - 4 - 14)
            (min 22 (max 14 (entries.foldl (fun widest entry =>
              max widest (Loam.Tui.Layout.displayWidth (planDetailQuantity entry))) 0)))
          let header := if showHeader then
              [mutedLine ("  " ++ planDetailTableRow (innerWidth - 2) quantityWidth
                "Date/Month" "Status" "Quanta")]
            else []
          let shape := String.intercalate "," row.rule.negativeLoci ++ " -> " ++
            String.intercalate "," row.rule.positiveLoci
          let context :=
            [plainLine (" Scheduled / Plan / " ++ row.rule.name),
             mutedLine (" Pace: " ++ paceLabel row.rule ++ " from " ++ row.rule.anchor),
             mutedLine (" Shape: " ++ shape)]
          let context := context.map fun widget => .column (widget.lines.map fun cells =>
            let text := String.ofList (cells.map Cell.glyph)
            if Loam.Tui.Layout.displayWidth text <= writable then Widget.row
                (cells.map fun cell => span (String.singleton cell.glyph) cell.style)
            else mutedLine (Loam.Tui.Layout.clip (writable - 1) text ++ "…"))
          let more := (if start > 0 then " ▲" else "") ++
            (if start + capacity < total then " ▼" else "")
          (context, "Occurrences / monitored gaps",
            (if entries.isEmpty then
              [mutedLine " No current-open occurrences or monitored gaps in the loaded horizon."]
            else header ++ shown.zipIdx.map fun (entry, offset) =>
              planDetailEntryLine innerWidth quantityWidth state (start + offset) entry),
            some ((if total == 0 then "0/0" else s!"{state.planRow + 1}/{total}") ++ more))
  let panel := Loam.Tui.Layout.framedPanel writable panelHeight title (.column content) true position
  boundedWorkspace bounds (.column (context.take contextRows ++ [panel] ++ legend)) footerLines

private def coverageView
    (bounds : Bounds) (state : State) (coverage : CoverageEvidence) : Widget :=
  let state := clampCoverageState coverage state
  let writable := Loam.Tui.Layout.contentWidth bounds
  let legend := workspaceLegend bounds false
  let footerLines := reservedNoticeFooter bounds state (navigationFooter bounds .coverage)
  let tableCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length - legend.length
  let contextRows := if tableCapacity >= 7 then 2 else if tableCapacity >= 4 then 1 else 0
  let panelHeight := tableCapacity - contextRows
  let innerWidth := writable - 2
  let innerHeight := panelHeight - 2
  let (context, title, content, position) : List Widget × String × List Widget × Option String :=
    match coverage with
    | .ok snapshot =>
        let monthCount := Loam.Tui.ScheduledCoveragePane.monthWindowSize innerWidth
        let months := (snapshot.months.drop state.coverageMonthOffset).take monthCount
        let window := match months.head?, months.getLast? with
          | some first, some last => first ++ " .. " ++ last
          | _, _ => if snapshot.months.isEmpty then "(empty loaded horizon)" else "(widen for months)"
        let total := snapshot.rows.length
        let capacity := innerHeight - (if innerHeight >= 2 then 1 else 0)
        let start := Loam.Tui.Layout.trailingWindowStart state.coverageRow (max 1 capacity)
        let more := (if start > 0 then " ▲" else "") ++
          (if start + capacity < total then " ▼" else "")
        let title := if contextRows < 2 then "Monitored plans " ++ window
          else s!"Monitored plans ({total})"
        ([.row [span " Scheduled Series Calendar",
            span ("  |  known through " ++ snapshot.observedAt) .muted],
          mutedLine (" Month window: " ++ window)], title,
          Loam.Tui.ScheduledCoveragePane.tableWindow snapshot state.coverageRow
            state.coverageMonthOffset monthCount innerWidth innerHeight,
          some ((if total == 0 then "0/0" else s!"{state.coverageRow + 1}/{total}") ++ more))
    | .error message =>
        ([plainLine " Scheduled Series Calendar", mutedLine " Coverage unavailable"],
          "Monitored plans [Unavailable]",
          [plainLine (" [Coverage unavailable] " ++ message),
           mutedLine " Months and List remain available with v."], none)
  let panel := Loam.Tui.Layout.framedPanel writable panelHeight title (.column content) true position
  boundedWorkspace bounds (.column (context.take contextRows ++ [panel] ++ legend)) footerLines

def viewWithCoverage
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State)
    (coverage : CoverageEvidence) : Widget :=
  match rawState.viewMode with
  | .coverage => coverageView bounds rawState coverage
  | .planDetail => planDetailView bounds snapshot rawState coverage
  | .futureBoard => futureBoardView bounds snapshot rawState
  | .list => listView bounds snapshot rawState

/-- Compatibility rendering for callers that do not own the coverage read. -/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  viewWithCoverage bounds snapshot rawState (.error "coverage not loaded in this surface")

end Loam.Tui.ScheduledWorkspace