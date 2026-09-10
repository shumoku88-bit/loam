import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.ScheduledReview

namespace Loam.Tui.HraScheduled

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

structure State where
  focusDate : String
  scope : Scope := .focusDay
  /-- Scheduled occurrences are the primary browse target; Loci remain an explicit filter pane. -/
  pane : Pane := .occurrences
  locusRow : Nat := 0
  occurrenceRow : Nat := 0
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | focusLeft
  | focusRight
  | cycleFilter
  | createScheduled
  | completeScheduled
  | replaceScheduled
  | cancelScheduled
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | createScheduled
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

abbrev Record := ScheduledOccurrence String

private def unavailableNotice? (snapshot : Snapshot) : Option String :=
  match snapshot.scheduled with
  | .error message => some ("[Unavailable] Scheduled: " ++ message)
  | .ok _ => none


def scopeRecordsResult (snapshot : Snapshot) (state : State) : Except String (List Record) :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled =>
      match state.scope with
      | .focusDay =>
          match Loam.ScheduledReview.dayEvidence scheduled state.focusDate with
          | .due first rest => .ok (first :: rest)
          | .unknown => .ok []
          | .unknownCompletionScheduled => .error "Scheduled completion evidence references an unknown identity."
          | .unknownRetirementScheduled => .error "Scheduled retirement evidence references an unknown identity."
          | .unknownReplacementScheduled => .error "Scheduled replacement evidence references an unknown identity."
          | .invalidReplacementGraph => .error "Scheduled replacement topology is invalid."
          | .conflictingTerminalEvidence => .error "Scheduled terminal evidence conflicts."
      | .allCurrent =>
          match Loam.ScheduledReview.currentOpenRecords scheduled with
          | .ok records =>
              .ok (records.mergeSort fun left right =>
                if left.scheduledOn = right.scheduledOn then left.id.token ≤ right.id.token
                else left.scheduledOn ≤ right.scheduledOn)
          | .error message => .error message

def recordsForScope (snapshot : Snapshot) (state : State) : List Record :=
  match scopeRecordsResult snapshot state with
  | .ok records => records
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

def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := movePrevious snapshot state }
  | .next => { state := moveNext snapshot state }
  | .focusLeft => { state := { state with pane := .loci, notice := "" } }
  | .focusRight => { state := { state with pane := .occurrences, notice := "" } }
  | .cycleFilter => { state := cycleFilter snapshot state }
  | .createScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none => { state, command := .createScheduled }
  | .completeScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          match state.pane with
          | .loci => { state := { state with notice := "Complete is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for completion." } }
              | some _ => { state, command := .completeScheduled }
  | .replaceScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          match state.pane with
          | .loci => { state := { state with notice := "Replace is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for supersede." } }
              | some _ => { state, command := .replaceScheduled }
  | .cancelScheduled =>
      match unavailableNotice? snapshot with
      | some notice => { state := { state with notice := notice } }
      | none =>
          match state.pane with
          | .loci => { state := { state with notice := "Cancel is available from the Scheduled pane." } }
          | .occurrences =>
              match selectedRecord? snapshot state with
              | none => { state := { state with notice := "No current-open Scheduled occurrence is selected for cancellation." } }
              | some _ => { state, command := .cancelScheduled }
  | .back => { state, command := .back }
  | .other => { state }

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
          match scopeRecordsResult snapshot state with
          | .error message => " [Unavailable] " ++ message
          | .ok _ =>
              match state.scope with
              | .focusDay => " (none due on this day)"
              | .allCurrent => " (no current-open Scheduled occurrences)"
        else ""
  .row [span (fit leftWidth leftText), span " | ", span (fit rightWidth rightText)]

private def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedRecord? snapshot state with
  | none =>
      match scopeRecordsResult snapshot state with
      | .error message =>
          [ plainLine " Selected Scheduled Details:"
          , plainLine ("   [Unavailable] " ++ message)
          ]
      | .ok _ =>
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
  let detailed := "[j/k] select  [h/l] pane  [f] scope  [n] new  [c/Enter] complete  [s] replace  [x] cancel  [q] back"
  if Loam.Tui.Layout.displayWidth detailed ≤ Loam.Tui.Layout.contentWidth bounds then
    [ mutedLine detailed ]
  else
    [ mutedLine "[j/k] select [h/l] pane [f] scope [n] new [q] back"
    , mutedLine "[c/Enter] complete [s] replace [x] cancel"
    ]

private def fitWithFooter (bounds : Bounds) (body footerRows : List Widget) : List Widget :=
  let available := if bounds.height > 0 then bounds.height - 1 else 0
  let bodyCapacity := available - footerRows.length
  let visibleBody := body.take bodyCapacity
  let padding := bodyCapacity - visibleBody.length
  visibleBody ++ List.replicate padding blankLine ++ footerRows

/--
HRA-shaped Scheduled workspace over the shared ScheduledReview answer.
Locus filtering, pane focus, windowing, and cursor coordinates are process-local presentation state.
-/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
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
    match snapshot.scheduled with
    | .error _ => fit rightWidth " Scheduled [Unavailable]"
    | .ok _ =>
        fit rightWidth
          (if state.pane == .occurrences then " Scheduled [active] (" ++ toString occCount ++ ")"
           else " Scheduled (" ++ toString occCount ++ ")")
  let body :=
    [ rule bounds '='
    , plainLine " Household Scheduled Workspace"
    , plainLine (" Horizon: " ++ snapshot.actual.today ++ "  |  Scope: " ++ scopeText snapshot state ++ "  |  Locus: " ++ currentLocusName snapshot state)
    , rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range 8).map (paneRow snapshot state leftWidth rightWidth) ++
    [rule bounds '-'] ++ detailLines snapshot state ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (fitWithFooter bounds body (footer bounds))

end Loam.Tui.HraScheduled
