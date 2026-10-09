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

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def fit (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padRight width text

private def rule (bounds : Bounds) (char : Char) : Widget :=
  plainLine (repeatChar (Loam.Tui.Layout.contentWidth bounds) char)

private def scopeText (snapshot : Snapshot) (state : State) : String :=
  match state.scope with
  | .focusDay => "Focus Day (" ++ state.focusDate ++ ")"
  | .allCurrent => "All Current-Open (known through " ++ snapshot.actual.today ++ ")"

private def currentLocusName (snapshot : Snapshot) (state : State) : String :=
  (selectedLocus? snapshot state).getD "All loci"

private def scheduledSummary (record : Record) : String :=
  record.scheduledOn ++ "  " ++ Loam.ScheduledReview.summary record

private def paneWindowStart (selected visibleRows : Nat) : Nat :=
  Loam.Tui.Layout.trailingWindowStart selected (max 1 visibleRows)

private def locusLabel (snapshot : Snapshot) (state : State) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else (lociForScope snapshot state)[row - 1]?

private def paneRow (snapshot : Snapshot) (state : State)
    (leftWidth rightWidth visibleRows row : Nat) : Widget :=
  let locusIndex := paneWindowStart state.locusRow visibleRows + row
  let occIndex := paneWindowStart state.occurrenceRow visibleRows + row
  let leftPrefix :=
    if locusIndex = state.locusRow then
      if state.pane == .loci then " > " else " * "
    else "   "
  let rightPrefix :=
    if occIndex = state.occurrenceRow && (visibleRecords snapshot state).length > 0 then
      if state.pane == .occurrences then " > " else " * "
    else "   "
  let leftText :=
    match locusLabel snapshot state locusIndex with
    | some label => leftPrefix ++ label
    | none => ""
  let rightText :=
    match (visibleRecords snapshot state)[occIndex]? with
    | some record => rightPrefix ++ scheduledSummary record
    | none =>
        if row = 0 && (visibleRecords snapshot state).isEmpty then
          match scopeEvidence snapshot state with
          | .error message => " [Unavailable] " ++ message
          | .ok .unknown => " (Unknown; no completeness horizon claimed)"
          | .ok (.records _) =>
              match state.scope with
              | .focusDay => " (none due on this day)"
              | .allCurrent => " (no current-open Scheduled occurrences)"
        else ""
  .row [span (fit leftWidth leftText), span " | ", span (fit rightWidth rightText)]

private def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedRecord? snapshot state with
  | none =>
      match scopeEvidence snapshot state with
      | .error message =>
          [ plainLine " Selected Scheduled Details:"
          , plainLine ("   [Unavailable] " ++ message)
          ]
      | .ok .unknown =>
          [ plainLine " Selected Scheduled Details:"
          , mutedLine "   (Unknown; no completeness horizon claimed)"
          ]
      | .ok (.records _) =>
          [ plainLine " Selected Scheduled Details:"
          , mutedLine "   (no Scheduled selected)"
          ]
  | some record =>
      [ plainLine " Selected Scheduled Details:"
      , plainLine ("   Identity    : " ++ record.id.token)
      , plainLine ("   Due Date    : " ++ record.scheduledOn)
      , plainLine ("   Summary     : " ++ Loam.ScheduledReview.summary record)
      , plainLine "   Expected Effects:"
      ] ++
      (record.movement.changes.map fun change =>
        plainLine ("     " ++ fit 28 change.coordinate.token ++ " " ++ toString change.quantity.quanta ++ " " ++ record.measure.token))

/--
Stable details presentation across bounds heights, preventing whole-screen layout
jitter and desynchronization when moving between records.
-/
def detailCapacityForBounds (bounds : Bounds) : Nat :=
  if bounds.height ≥ 48 then 10 else if bounds.height ≥ 36 then 8 else 6

private def fixedDetailLines
    (snapshot : Snapshot) (state : State) (capacity : Nat) : List Widget :=
  let rawLines := detailLines snapshot state
  let visible := rawLines.take capacity
  let padding := capacity - visible.length
  visible ++ List.replicate padding blankLine

private def noticeLines (bounds : Bounds) (state : State) : List String :=
  if state.notice.isEmpty then []
  else Loam.Tui.Layout.flowTokens (Loam.Tui.Layout.contentWidth bounds) " "
    (state.notice.splitOn " ")

/-- Publication/refusal feedback stays visible even when the browse body is truncated. -/
private def withNoticeFooter (bounds : Bounds) (state : State) (help : List Widget) : List Widget :=
  (noticeLines bounds state).map plainLine ++ help

private def footer (bounds : Bounds) : List Widget :=
  let detailed := "[j/k] select  [h/l] pane  [f] scope  [v] overview  [e] extend  [s] undecided  [n] new  [c/Enter] complete  [r] replace  [b] batch amount  [x] cancel  [q] back"
  if Loam.Tui.Layout.displayWidth detailed ≤ Loam.Tui.Layout.contentWidth bounds then
    [ mutedLine detailed ]
  else
    [ mutedLine "[j/k] select [h/l] pane [f] scope [v] overview [e] extend [s] undecided [n] new [q] back"
    , mutedLine "[c/Enter] complete [r] replace [b] batch amount [x] cancel"
    ]

/--
Production Scheduled workspace over the shared ScheduledReview answer.
Locus filtering, pane focus, windowing, and cursor coordinates are process-local presentation state.
-/
private def listView (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let writable := Loam.Tui.Layout.contentWidth bounds
  let leftWidth :=
    if writable >= 70 then min 28 (writable / 3) else min 22 (writable / 2)
  let rightWidth := if writable > leftWidth + 3 then writable - leftWidth - 3 else 0
  let lociCount := (lociForScope snapshot state).length
  let occCount := (visibleRecords snapshot state).length
  let leftHeader :=
    fit leftWidth
      (if state.pane == .loci then " Loci [active] (" ++ toString lociCount ++ ")"
       else " Loci (" ++ toString lociCount ++ ")")
  let rightHeader :=
    match scopeEvidence snapshot state with
    | .error _ => fit rightWidth " Scheduled [Unavailable]"
    | .ok .unknown => fit rightWidth " Scheduled [Unknown]"
    | .ok (.records _) =>
        fit rightWidth
          (if state.pane == .occurrences then " Scheduled [active] (" ++ toString occCount ++ ")"
           else " Scheduled (" ++ toString occCount ++ ")")
  let footerLines := withNoticeFooter bounds state (footer bounds)
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length
  let detailCap := detailCapacityForBounds bounds
  let details := fixedDetailLines snapshot state detailCap
  let fixedBodyRows := 7 + detailCap
  let paneRows := max 1 (bodyCapacity - fixedBodyRows)
  let body :=
    [ rule bounds '='
    , plainLine " Household Scheduled Workspace"
    , plainLine (" Horizon: " ++ snapshot.actual.today ++ "  |  " ++ scopeText snapshot state)
    , plainLine (" Locus: " ++ currentLocusName snapshot state)
    , rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range paneRows).map (paneRow snapshot state leftWidth rightWidth paneRows) ++
    [rule bounds '-'] ++ details
  .column (Loam.Tui.Layout.fitWithFooter bounds body footerLines)


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

private def monthCard
    (width maxVisible : Nat) (snapshot : Snapshot) (state : State)
    (selectedId? : Option String) (month : Loam.Tui.Calendar.Month) : Widget :=
  let records := recordsInMonth snapshot state month
  let shown := monthWindow records selectedId? maxVisible
  let header :=
    "[" ++ Loam.Tui.Calendar.monthLabel month ++ "]  " ++
      toString records.length ++ " plan" ++ (if records.length = 1 then "" else "s")
  let recordLines := shown.map fun (_, record) =>
    let selected :=
      match selectedId? with
      | some id => id == record.id.token
      | none => false
    let marker := if selected then "> " else "  "
    let text :=
      marker ++ recordDay record ++ "  " ++ Loam.ScheduledReview.summary record
    .row [span (Loam.Tui.Layout.clip width text)
      (if selected then .selected else .normal)]
  let padding := List.replicate (maxVisible - recordLines.length) (.row [])
  let footerText :=
    if records.length > maxVisible then
      "  " ++ toString records.length ++ " explicit plans; j/k moves the selection"
    else if records.isEmpty then
      "  (no explicit plan)"
    else
      ""
  .column <|
    [.row [span (Loam.Tui.Layout.clip width header) .muted]] ++
    recordLines ++ padding ++
    [.row [span (Loam.Tui.Layout.clip width footerText) .muted]]

private def emptyMonthCard (height : Nat) : Widget :=
  .column (List.replicate height (.row []))

private def futureBoardHelpLines (bounds : Bounds) : List String :=
  Loam.Tui.Layout.flowTokens (Loam.Tui.Layout.contentWidth bounds) "  "
    ["[j/k or wheel] select", "[h/l or ←/→] months", "[e] extend", "[s] undecided",
     "[v] List", "[n] new", "[c/Enter] complete", "[r] replace", "[b] batch amount",
     "[x] cancel", "[q] back"]

private def futureBoardFooterRowCount (bounds : Bounds) : Nat :=
  (futureBoardHelpLines bounds).length

private def futureBoardCardHeight
    (bounds : Bounds) (snapshot : Snapshot) (state : State) : Nat :=
  let bodyCapacity :=
    Loam.Tui.Layout.footerBodyCapacity bounds (futureBoardFooterRowCount bounds)
  let fixedBodyRows :=
    5 + 1 + (detailLines snapshot state).length +
      (noticeLines bounds state).length
  let available := bodyCapacity - fixedBodyRows
  max 5 (available / 3)

private def futureBoardRows
    (bounds : Bounds) (snapshot : Snapshot) (state : State) : List Widget :=
  let writable := Loam.Tui.Layout.contentWidth bounds
  if writable < 80 then
    [ mutedLine " Months needs at least 80 terminal columns; press v for List." ]
  else
    let leftWidth := (writable - 3) / 2
    let rightWidth := writable - leftWidth - 3
    let months := futureBoardMonths snapshot state
    let selectedId? := (selectedRecord? snapshot state).map fun record => record.id.token
    let cardHeight := futureBoardCardHeight bounds snapshot state
    let maxVisible := cardHeight - 2
    (List.range 3).flatMap fun row =>
      let left :=
        match months[row * 2]? with
        | some month => monthCard leftWidth maxVisible snapshot state selectedId? month
        | none => emptyMonthCard cardHeight
      let right :=
        match months[row * 2 + 1]? with
        | some month => monthCard rightWidth maxVisible snapshot state selectedId? month
        | none => emptyMonthCard cardHeight
      Loam.Tui.Layout.sideBySide cardHeight leftWidth rightWidth left right

private def futureBoardFooter (bounds : Bounds) : List Widget :=
  (futureBoardHelpLines bounds).map mutedLine

private def futureBoardView
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let months := futureBoardMonths snapshot state
  let startMonth :=
    months.head?.getD { year := 1970, month := 1 }
  let endMonth :=
    months.getLast?.getD startMonth
  let body :=
    [ rule bounds '='
    , plainLine " Scheduled / Months"
    , mutedLine (" Explicit current-open plans: " ++
        Loam.Tui.Calendar.monthLabel startMonth ++ " .. " ++
        Loam.Tui.Calendar.monthLabel endMonth)
    , mutedLine " Wheel/j/k moves the selected plan; h/l or horizontal wheel freely shifts the six-month window."
    , rule bounds '='
    ] ++
    futureBoardRows bounds snapshot state ++
    [rule bounds '-'] ++
    detailLines snapshot state
  .column (Loam.Tui.Layout.fitWithFooter bounds body
    (withNoticeFooter bounds state (futureBoardFooter bounds)))

private def paceLabel (rule : Loam.ScheduledCoverageConfig.Rule) : String :=
  match rule.everyMonths with
  | 0 => "undecided"
  | 1 => "monthly"
  | n => "every " ++ toString n ++ " months"

/-- Align quantity summaries without inventing a total or guessing a display scale. -/
private def planDetailQuantity : PlanDetailEntry → String
  | .missing _ => "—"
  | .occurrence record _ =>
      let negative := record.movement.changes.filter (fun change => change.quantity.quanta < 0)
      let positive := record.movement.changes.filter (fun change => 0 < change.quantity.quanta)
      match negative, positive with
      | [_], [destination] =>
          Loam.MeasurePresentation.groupDisplayedNumber (toString destination.quantity.quanta) ++
            " " ++ record.measure.token
      | _, _ => if record.movement.changes.isEmpty then "—"
          else s!"split ({record.movement.changes.length})"

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

private def planDetailFooter (bounds : Bounds) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let compact := bounds.height < 18
  let legend := if compact then
      [["MISSING = gap only;", "quantities are quanta"]]
    else
      [["Explicit dates are authoritative;", "on/outside pace is monitoring guidance."],
       ["MISSING is a monitored gap, not an occurrence.", "Quantities are exact quanta."]]
  let help := if compact then
      [["[j/k] select", "[c/Enter] complete", "[q] overview"],
       ["[e] replenish", "[x] cancel", "[r] replace"]]
    else
      [["[j/k] select", "[e] replenish", "[x] cancel", "[r] replace", "[c/Enter] complete", "[q] overview"],
       ["[b] batch amount", "[p] pace", "[s] undecided"]]
  (Loam.Tui.Layout.flowLines width " " legend ++
    Loam.Tui.Layout.flowLines width "  " help).map mutedLine

/-- Shared physical clipping for the two framed Scheduled workspaces. -/
private def boundedWorkspace (bounds : Bounds) (body : Widget) (footerLines : List Widget) : Widget :=
  let writable := Loam.Tui.Layout.contentWidth bounds
  let bodyLines := body.lines.map fun cells =>
    Widget.row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)
  let fitted := Loam.Tui.Layout.fitWithFooter bounds bodyLines footerLines
  .column ((fitted.take (bounds.height - 1)).map fun row =>
    .column (row.lines.map fun cells => .row
      ((Loam.Tui.Layout.clipCells writable cells).map fun cell =>
        span (String.singleton cell.glyph) cell.style)))

private def planDetailView
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State)
    (coverage : CoverageEvidence) : Widget :=
  let state := clampPlanDetailState snapshot coverage (clampCoverageState coverage rawState)
  let footerLines := if state.notice.isEmpty then
      mutedLine "" :: planDetailFooter bounds
    else withNoticeFooter bounds state (planDetailFooter bounds)
  let writable := Loam.Tui.Layout.contentWidth bounds
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length
  let contextRows := if bodyCapacity >= 9 then 3 else if bodyCapacity >= 6 then 2
    else if bodyCapacity >= 4 then 1 else 0
  let panelHeight := bodyCapacity - contextRows
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
  boundedWorkspace bounds (.column (context.take contextRows ++ [panel])) footerLines

private def coverageFooter (bounds : Bounds) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let primary :=
    Loam.Tui.Layout.flowTokens width "  "
      ["[j/k] plan", "[h/l] months", "[Enter] detail", "[e] replenish", "[b] batch amount", "[p] pace", "[q] back"]
  let more :=
    Loam.Tui.Layout.flowTokens width "  "
      ["More:", "[s] undecided", "[n] new", "[v] Months/List"]
  (primary ++ more).map mutedLine

private def coverageView
    (bounds : Bounds) (state : State) (coverage : CoverageEvidence) : Widget :=
  let state := clampCoverageState coverage state
  let writable := Loam.Tui.Layout.contentWidth bounds
  let compact := bounds.height < 18
  let legend :=
    if compact then [mutedLine "day = plan; ! = gap; blank = not expected"]
    else (Loam.Tui.Layout.flowLines writable " "
      [["dd = explicit day(s);", "! = expected month without a plan;", "blank = not expected."],
       ["Pace guides extension; it does not create recurrence authority."]]).map mutedLine
  let help := if compact then
      [ mutedLine "[j/k] plan [h/l] months [Enter] detail"
      , mutedLine "[e] extend [q] back [v] views" ]
    else coverageFooter bounds
  -- Publication/refusal notices retain their complete wrapped text.
  let footerLines := withNoticeFooter bounds state (legend ++ help)
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length
  let contextRows := if bodyCapacity >= 7 then 2 else if bodyCapacity >= 4 then 1 else 0
  let panelHeight := bodyCapacity - contextRows
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
  boundedWorkspace bounds (.column (context.take contextRows ++ [panel])) footerLines

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