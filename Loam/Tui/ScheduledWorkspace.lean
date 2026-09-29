import Loam.ScheduledCoverageReview
import Loam.ScheduledCoverageSelector
import Loam.Tui.Calendar
import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.Tui.ScheduledCoveragePane
import Loam.ScheduledReview

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
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
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

def latestRecordForRule?
    (snapshot : Snapshot)
    (rule : Loam.ScheduledCoverageConfig.Rule) : Option Record :=
  let allState : State := {
    focusDate := snapshot.actual.today
    scope := .allCurrent
    pane := .occurrences
    viewMode := .coverage
  }
  let candidates :=
    (recordsForScope snapshot allState).filter fun record =>
      Loam.ScheduledCoverageSelector.matchesRule record rule
  (candidates.mergeSort recordBefore).getLast?

def selectedCoverageRecord?
    (snapshot : Snapshot) (coverage : CoverageEvidence) (state : State) : Option Record := do
  let row ← selectedCoverageRow? coverage state
  latestRecordForRule? snapshot row.rule

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

private def cycleFilter (snapshot : Snapshot) (state : State) : State :=
  let scope := match state.scope with
    | .focusDay => Scope.allCurrent
    | .allCurrent => Scope.focusDay
  clampState snapshot { state with scope := scope, locusRow := 0, occurrenceRow := 0, notice := "" }

def updateWithCoverage
    (snapshot : Snapshot) (coverage : CoverageEvidence)
    (rawState : State) (event : Event) : Step :=
  let state := clampCoverageState coverage rawState
  match event with
  | .previous =>
      match state.viewMode with
      | .coverage =>
          if state.coverageRow = 0 then
            { state := { state with notice := "No previous recurring plan." } }
          else
            { state := { state with coverageRow := state.coverageRow - 1, notice := "" } }
      | .futureBoard => { state := movePrevious snapshot state }
      | .list => { state := movePrevious snapshot state }
  | .next =>
      match state.viewMode with
      | .coverage =>
          let count := (coverageRows coverage).length
          if state.coverageRow + 1 < count then
            { state := { state with coverageRow := state.coverageRow + 1, notice := "" } }
          else
            { state := { state with notice := "No next recurring plan." } }
      | .futureBoard => { state := moveNext snapshot state }
      | .list => { state := moveNext snapshot state }
  | .focusLeft =>
      match state.viewMode with
      | .coverage =>
          if state.coverageMonthOffset = 0 then
            { state := { state with notice := "Already at the first coverage month." } }
          else
            { state := { state with
                coverageMonthOffset := state.coverageMonthOffset - 1
                notice := "" } }
      | .futureBoard =>
          { state := { state with notice := "Months uses one Scheduled selection; press v for List." } }
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
      | .futureBoard =>
          { state := { state with notice := "Months uses one Scheduled selection; press v for List." } }
      | .list => { state := { state with pane := .occurrences, notice := "" } }
  | .cycleFilter =>
      match state.viewMode with
      | .coverage =>
          { state := { state with notice := "The overview always uses the current-open frontier." } }
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
                notice := "" } }
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
          | .coverage =>
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
          | .coverage =>
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
          | .coverage =>
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
          match selectedCoverageRecord? snapshot coverage state with
          | none =>
              { state := { state with notice := "This recurring plan has no current-open Scheduled date to inspect." } }
          | some record =>
              let nextBase := clampState snapshot {
                state with
                viewMode := .futureBoard
                scope := .allCurrent
                pane := .occurrences
                locusRow := 0
                notice := ""
              }
              let row := (findRecordRow? (visibleRecords snapshot nextBase) record.id.token).getD 0
              { state := { nextBase with occurrenceRow := row } }
      | .futureBoard => { state }
      | .list => { state }
  | .fillCurrentCycle =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage then
            { state := { state with notice := "Use e to extend the selected recurring plan." } }
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
          if state.viewMode == .coverage then
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
            { state := { state with notice := "Press Enter to inspect exact dates before completing one occurrence." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Complete is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for completion." } }
              | some _ => { state, command := .completeScheduled }
  | .replaceScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          if state.viewMode == .coverage then
            { state := { state with notice := "Press Enter to inspect exact dates before replacing one occurrence." } }
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
            { state := { state with notice := "Press Enter to inspect exact dates before cancelling one occurrence." } }
          else match state.pane with
          | .loci => { state := { state with notice := "Cancel is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for cancellation." } }
              | some _ => { state, command := .cancelScheduled }
  | .back => { state, command := .back }
  | .other => { state }

def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  updateWithCoverage snapshot (.error "coverage unavailable") state event

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

private def locusWindowStart (state : State) : Nat :=
  if state.locusRow > 6 then state.locusRow - 5 else 0

private def occWindowStart (state : State) : Nat :=
  if state.occurrenceRow > 6 then state.occurrenceRow - 5 else 0

private def locusLabel (snapshot : Snapshot) (state : State) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else (lociForScope snapshot state)[row - 1]?

private def paneRow (snapshot : Snapshot) (state : State)
    (leftWidth rightWidth row : Nat) : Widget :=
  let locusIndex := locusWindowStart state + row
  let occIndex := occWindowStart state + row
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

private def footer (bounds : Bounds) : List Widget :=
  let detailed := "[j/k] select  [h/l] pane  [f] scope  [v] overview  [e] extend  [s] undecided  [n] new  [c/Enter] complete  [r] replace  [x] cancel  [q] back"
  if Loam.Tui.Layout.displayWidth detailed ≤ Loam.Tui.Layout.contentWidth bounds then
    [ mutedLine detailed ]
  else
    [ mutedLine "[j/k] select [h/l] pane [f] scope [v] overview [e] extend [s] undecided [n] new [q] back"
    , mutedLine "[c/Enter] complete [r] replace [x] cancel"
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
  let body :=
    [ rule bounds '='
    , plainLine " Household Scheduled Workspace"
    , plainLine (" Horizon: " ++ snapshot.actual.today ++ "  |  " ++ scopeText snapshot state)
    , plainLine (" Locus: " ++ currentLocusName snapshot state)
    , rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range 8).map (paneRow snapshot state leftWidth rightWidth) ++
    [rule bounds '-'] ++ detailLines snapshot state ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (Loam.Tui.Layout.fitWithFooter bounds body (footer bounds))


private def monthsFrom
    (month : Loam.Tui.Calendar.Month) : Nat → List Loam.Tui.Calendar.Month
  | 0 => []
  | n + 1 => month :: monthsFrom (Loam.Tui.Calendar.nextMonth month) n

private def futureBoardMonths (snapshot : Snapshot) : List Loam.Tui.Calendar.Month :=
  let start :=
    (Loam.Tui.Calendar.monthOf? snapshot.actual.today).getD { year := 1970, month := 1 }
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

private def futureBoardDetailedHelp : String :=
  "[j/k] select  [e] extend  [s] undecided  [v] List  [n] new  [c/Enter] complete  [r] replace  [x] cancel  [q] back"

private def futureBoardFooterRowCount (bounds : Bounds) : Nat :=
  if Loam.Tui.Layout.displayWidth futureBoardDetailedHelp ≤
      Loam.Tui.Layout.contentWidth bounds then 1 else 2

private def futureBoardCardHeight
    (bounds : Bounds) (snapshot : Snapshot) (state : State) : Nat :=
  let bodyCapacity :=
    Loam.Tui.Layout.footerBodyCapacity bounds (futureBoardFooterRowCount bounds)
  let fixedBodyRows :=
    5 + 1 + (detailLines snapshot state).length +
      (if state.notice.isEmpty then 0 else 1)
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
    let months := futureBoardMonths snapshot
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
  if futureBoardFooterRowCount bounds = 1 then
    [mutedLine futureBoardDetailedHelp]
  else
    [ mutedLine "[j/k] select [e] extend [s] undecided [v] List [n] new [q] back"
    , mutedLine "[c/Enter] complete [r] replace [x] cancel"
    ]

private def futureBoardView
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let startMonth :=
    (futureBoardMonths snapshot).head?.getD { year := 1970, month := 1 }
  let body :=
    [ rule bounds '='
    , plainLine " Scheduled / Months"
    , mutedLine (" Explicit current-open plans by calendar month, starting " ++
        Loam.Tui.Calendar.monthLabel startMonth)
    , mutedLine " Calendar grouping is presentation only; no recurrence or month authority is inferred."
    , rule bounds '='
    ] ++
    futureBoardRows bounds snapshot state ++
    [rule bounds '-'] ++
    detailLines snapshot state ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (Loam.Tui.Layout.fitWithFooter bounds body (futureBoardFooter bounds))

private def coverageFooter (bounds : Bounds) : List Widget :=
  let detailed :=
    "[j/k] select  [e] extend  [p] pace  [s] undecided  [Enter] exact dates  [h/l] months  [n] new  [q] back"
  if Loam.Tui.Layout.displayWidth detailed ≤ Loam.Tui.Layout.contentWidth bounds then
    [mutedLine detailed]
  else
    [ mutedLine "[j/k] select [e] extend [p] pace [s] undecided [Enter] exact dates"
    , mutedLine "[h/l] months [n] new [v] all plans [q] back"
    ]

private def coverageView
    (bounds : Bounds) (state : State) (coverage : CoverageEvidence) : Widget :=
  let coverageLines :=
    match coverage with
    | .ok snapshot =>
        let monthCount :=
          Loam.Tui.ScheduledCoveragePane.monthWindowSize
            (Loam.Tui.Layout.contentWidth bounds)
        Loam.Tui.ScheduledCoveragePane.linesSelectedWindow
          snapshot state.coverageRow state.coverageMonthOffset monthCount
    | .error message =>
        [ plainLine (" [Coverage unavailable] " ++ message)
        , mutedLine " Months and List remain available with v."
        ]
  let body :=
    [ rule bounds '='
    , plainLine " Scheduled"
    , mutedLine " Series Calendar: rows are plans; columns are months; cells show real explicit Scheduled days."
    , mutedLine " ! marks an expected month with no explicit plan. Unscheduled months stay blank."
    , rule bounds '='
    ] ++ coverageLines ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (Loam.Tui.Layout.fitWithFooter bounds body (coverageFooter bounds))

def viewWithCoverage
    (bounds : Bounds) (snapshot : Snapshot) (rawState : State)
    (coverage : CoverageEvidence) : Widget :=
  match rawState.viewMode with
  | .coverage => coverageView bounds rawState coverage
  | .futureBoard => futureBoardView bounds snapshot rawState
  | .list => listView bounds snapshot rawState

/-- Compatibility rendering for callers that do not own the coverage read. -/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  viewWithCoverage bounds snapshot rawState (.error "coverage not loaded in this surface")

end Loam.Tui.ScheduledWorkspace