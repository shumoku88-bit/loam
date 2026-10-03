import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.SelectedDay

open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

inductive Pane where
  | actual
  | scheduled
  deriving Repr, DecidableEq, BEq

structure State where
  focusDate : String
  pane : Pane := .actual
  actualRow : Nat := 0
  scheduledRow : Nat := 0
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
  | recordNew
  | createScheduled
  | correctActual
  | reverseActual
  | correctDate
  | classifyMerchant
  | manageLoci
  | completeScheduled
  | cancelScheduled
  | replaceScheduled
  | back
  | yank
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | recordNew
  | createScheduled
  | correctActual
  | reverseActual
  | correctDate
  | classifyMerchant
  | manageLoci
  | completeScheduled
  | cancelScheduled
  | replaceScheduled
  | back
  | yank
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  command : Command := .stay


def initial (focusDate : String) : State :=
  { focusDate := focusDate }

/-- Open one dated current Actual with that exact Event selected in the day workspace. -/
def initialForActual? (snapshot : Snapshot) (record : ReviewRecord) : Option State := do
  let date ← record.date
  let index ← (recordsForDay snapshot date).findIdx? fun item =>
    item.event.id == record.event.id
  some { focusDate := date, pane := .actual, actualRow := index }

/-- Selected-day Actual is exactly the existing shared ActualReview day answer. -/
def actualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.focusDate

/-- Selected-day Scheduled evidence preserves both startup refusal and the shared open-world answer. -/
def scheduledEvidence
    (snapshot : Snapshot) (state : State) : Except String ScheduledEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled => Loam.ScheduledReview.dayEvidence scheduled state.focusDate


def scheduledRecords (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  match scheduledEvidence snapshot state with
  | .error _ => []
  | .ok evidence => Loam.ScheduledReview.explicitDueRecords evidence


def selectedActual? (snapshot : Snapshot) (state : State) : Option ReviewRecord :=
  (actualRecords snapshot state)[state.actualRow]?


def selectedScheduled? (snapshot : Snapshot) (state : State) : Option ScheduledRecord :=
  (scheduledRecords snapshot state)[state.scheduledRow]?

private def scheduledUnavailableNotice? (snapshot : Snapshot) : Option String :=
  match snapshot.scheduled with
  | .error message => some ("[Unavailable] Scheduled: " ++ message)
  | .ok _ => none

private def clampState (snapshot : Snapshot) (state : State) : State :=
  let actualCount := (actualRecords snapshot state).length
  let scheduledCount := (scheduledRecords snapshot state).length
  let actualRow := if actualCount = 0 then 0 else min state.actualRow (actualCount - 1)
  let scheduledRow := if scheduledCount = 0 then 0 else min state.scheduledRow (scheduledCount - 1)
  { state with actualRow := actualRow, scheduledRow := scheduledRow }

/-- Re-clamp only process-local selection after canonical evidence changes. -/
def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with notice := "" }

private def movePrevious (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      if state.actualRow = 0 then { state with notice := "No previous Actual row on this day." }
      else { state with actualRow := state.actualRow - 1, notice := "" }
  | .scheduled =>
      if state.scheduledRow = 0 then { state with notice := "No previous Scheduled row on this day." }
      else { state with scheduledRow := state.scheduledRow - 1, notice := "" }

private def moveNext (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      if state.actualRow + 1 < count then
        { state with actualRow := state.actualRow + 1, notice := "" }
      else
        { state with notice := "No next Actual row on this day." }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      if state.scheduledRow + 1 < count then
        { state with scheduledRow := state.scheduledRow + 1, notice := "" }
      else
        { state with notice := "No next Scheduled row on this day." }

private def movePageUp (snapshot : Snapshot) (state : State) (pageSize : Nat := 8) : State :=
  match state.pane with
  | .actual =>
      if state.actualRow == 0 then { state with notice := "Top of Actual list." }
      else { state with actualRow := state.actualRow - min state.actualRow pageSize, notice := "" }
  | .scheduled =>
      if state.scheduledRow == 0 then { state with notice := "Top of Scheduled list." }
      else { state with scheduledRow := state.scheduledRow - min state.scheduledRow pageSize, notice := "" }

private def movePageDown (snapshot : Snapshot) (state : State) (pageSize : Nat := 8) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      if count == 0 || state.actualRow + 1 >= count then { state with notice := "End of Actual list." }
      else { state with actualRow := min (count - 1) (state.actualRow + pageSize), notice := "" }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      if count == 0 || state.scheduledRow + 1 >= count then { state with notice := "End of Scheduled list." }
      else { state with scheduledRow := min (count - 1) (state.scheduledRow + pageSize), notice := "" }

private def moveHome (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual => { state with actualRow := 0, notice := "" }
  | .scheduled => { state with scheduledRow := 0, notice := "" }

private def moveEnd (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with actualRow := row, notice := "" }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with scheduledRow := row, notice := "" }

def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := movePrevious snapshot state }
  | .next => { state := moveNext snapshot state }
  | .pageUp => { state := movePageUp snapshot state }
  | .pageDown => { state := movePageDown snapshot state }
  | .home => { state := moveHome snapshot state }
  | .«end» => { state := moveEnd snapshot state }
  | .focusLeft => { state := { state with pane := .actual, notice := "" } }
  | .focusRight => { state := { state with pane := .scheduled, notice := "" } }
  | .recordNew =>
      match state.pane with
      | .actual => { state, command := .recordNew }
      | .scheduled =>
          { state := { state with notice := "New Actual is available from the Actual pane." } }
  | .createScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "New Scheduled is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none => { state, command := .createScheduled }
  | .correctActual =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Correction is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for correction." } }
          | some _ => { state, command := .correctActual }
  | .reverseActual =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Reversal is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for reversal." } }
          | some _ => { state, command := .reverseActual }
  | .correctDate =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Date correction is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for date correction." } }
          | some _ => { state, command := .correctDate }
  | .classifyMerchant =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Merchant classification is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for Merchant classification." } }
          | some _ => { state, command := .classifyMerchant }
  | .manageLoci =>
      match state.pane with
      | .actual => { state, command := .manageLoci }
      | .scheduled =>
          { state := { state with notice := "Locus management is available from the Actual pane." } }
  | .completeScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Completion is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none =>
              match selectedScheduled? snapshot state with
              | none =>
                  { state := { state with notice := "No current-open Scheduled occurrence is selected for completion." } }
              | some _ => { state, command := .completeScheduled }
  | .cancelScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Cancellation is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none =>
              match selectedScheduled? snapshot state with
              | none =>
                  { state := { state with notice := "No current-open Scheduled occurrence is selected for cancellation." } }
              | some _ => { state, command := .cancelScheduled }
  | .replaceScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Supersede is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none =>
              match selectedScheduled? snapshot state with
              | none =>
                  { state := { state with notice := "No current-open Scheduled occurrence is selected for supersede." } }
              | some _ => { state, command := .replaceScheduled }
  | .back => { state, command := .back }
  | .yank => { state, command := .yank }
  | .other => { state }

/-- Update workspace state, optionally scaling directional navigation by repeat count. -/
def updateWithRepeat (snapshot : Snapshot) (state : State) (event : Event) (repeatCount : Nat := 1) : Step :=
  if repeatCount <= 1 then update snapshot state event
  else
    match event with
    | .previous => { state := movePageUp snapshot state repeatCount }
    | .next => { state := movePageDown snapshot state repeatCount }
    | other => update snapshot state other

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def fit (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padRight width text

private def rule (bounds : Bounds) (char : Char) : Widget :=
  plainLine (repeatChar (Loam.Tui.Layout.contentWidth bounds) char)

private def actualSummary (record : ReviewRecord) : String :=
  Loam.ActualReview.summary record

private def scheduledSummary (record : ScheduledRecord) : String :=
  record.scheduledOn ++ "  " ++ Loam.ScheduledReview.summary record

private def paneWindowStart (selected visibleRows : Nat) : Nat :=
  Loam.Tui.Layout.trailingWindowStart selected (max 1 visibleRows)

private def paneRow (snapshot : Snapshot) (state : State)
    (leftWidth rightWidth visibleRows row : Nat) : Widget :=
  let actualIndex := paneWindowStart state.actualRow visibleRows + row
  let scheduledIndex := paneWindowStart state.scheduledRow visibleRows + row
  let actualPrefix :=
    if actualIndex = state.actualRow && !(actualRecords snapshot state).isEmpty then
      if state.pane == .actual then " > " else " * "
    else "   "
  let scheduledPrefix :=
    if scheduledIndex = state.scheduledRow && !(scheduledRecords snapshot state).isEmpty then
      if state.pane == .scheduled then " > " else " * "
    else "   "
  let actualText :=
    match (actualRecords snapshot state)[actualIndex]? with
    | some record => actualPrefix ++ actualSummary record
    | none => if row = 0 && (actualRecords snapshot state).isEmpty then " (none recorded)" else ""
  let scheduledText :=
    match (scheduledRecords snapshot state)[scheduledIndex]? with
    | some record => scheduledPrefix ++ scheduledSummary record
    | none =>
        if row = 0 && (scheduledRecords snapshot state).isEmpty then
          match scheduledEvidence snapshot state with
          | .error message => " [Unavailable] " ++ message
          | .ok .unknown => " (Unknown; no completeness horizon claimed)"
          | .ok (.due _ _) => " (none due)"
        else ""
  .row [span (fit leftWidth actualText), span " | ", span (fit rightWidth scheduledText)]

private def actualDetail (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedActual? snapshot state with
  | none =>
      [ plainLine " Selected Actual:"
      , mutedLine "   (no Actual selected)"
      ]
  | some record =>
      [ plainLine " Selected Actual:"
      , plainLine ("   Identity    : " ++ record.event.id.token)
      , plainLine ("   Description : " ++ if record.description.isEmpty then "(no description)" else Loam.ActualReview.displayText record.description)
      , plainLine "   Effects:"
      ] ++
      (record.event.effects.map fun effect =>
        plainLine ("     " ++ fit 28 effect.locus.token ++ " " ++ toString effect.quantity.quanta ++ " " ++ effect.measure.token))

private def scheduledUnavailableDetail
    (evidence : Except String ScheduledEvidence) : List Widget :=
  match evidence with
  | .error message =>
      [ plainLine " Selected Scheduled:"
      , plainLine ("   [Unavailable] " ++ message)
      ]
  | .ok .unknown =>
      [ plainLine " Selected Scheduled:"
      , mutedLine "   Unknown: absence of an explicit due occurrence is not NotDue."
      ]
  | .ok (.due _ _) =>
      [plainLine " Selected Scheduled:", mutedLine "   (no Scheduled selected)"]

private def scheduledDetail (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedScheduled? snapshot state with
  | none => scheduledUnavailableDetail (scheduledEvidence snapshot state)
  | some record =>
      [ plainLine " Selected Scheduled:"
      , plainLine ("   Identity : " ++ record.id.token)
      , plainLine ("   Due      : " ++ record.scheduledOn)
      , plainLine "   Expected effects:"
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
  let rawLines :=
    match state.pane with
    | .actual => actualDetail snapshot state
    | .scheduled => scheduledDetail snapshot state
  let visible := rawLines.take capacity
  let padding := capacity - visible.length
  visible ++ List.replicate padding blankLine

def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  fixedDetailLines snapshot state 6

private def footer (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  match state.pane with
  | .actual =>
      let detailed := "[j/k] select  [h/l] Actual/Scheduled  [n] new  [c] correct  [r] reverse  [d] date  [m] merchant  [g] loci  [y] copy  [q] back"
      if Loam.Tui.Layout.displayWidth detailed ≤ width then
        [mutedLine detailed]
      else
        [ mutedLine "[j/k] select [h/l] pane [n] new [c] correct [r] reverse [y] copy [q] back"
        , mutedLine "[d] date [m] merchant [g] loci"
        ]
  | .scheduled =>
      let detailed := "[j/k] select  [h/l] Actual/Scheduled  [n] new  [c/Enter] complete  [r] supersede  [x] cancel  [y] copy  [q] back"
      if Loam.Tui.Layout.displayWidth detailed ≤ width then
        [mutedLine detailed]
      else
        [ mutedLine "[j/k] select [h/l] pane [n] new [c/Enter] complete [r] supersede [x] cancel [y] copy [q] back" ]

/--
One-date operational workspace. It composes the shared Actual and Scheduled read
answers and owns only pane/cursor state. Actual Record/Correction/Reversal/date/Merchant actions, the Manage Loci
navigation entrance, and Scheduled creation/completion/cancellation/replacement
are local interaction intents; publication authority stays in shared publishers.
-/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := clampState snapshot rawState
  let writable := Loam.Tui.Layout.contentWidth bounds
  let leftWidth := if writable > 3 then (writable - 3) / 2 else 0
  let rightWidth := if writable > leftWidth + 3 then writable - leftWidth - 3 else 0
  let actualCount := (actualRecords snapshot state).length
  let scheduledCount := (scheduledRecords snapshot state).length
  let leftHeader := fit leftWidth
    (if state.pane == .actual then " Actual [active] (" ++ toString actualCount ++ ")"
     else " Actual (" ++ toString actualCount ++ ")")
  let rightHeader :=
    match snapshot.scheduled with
    | .error _ => fit rightWidth " Scheduled [Unavailable]"
    | .ok _ => fit rightWidth
        (if state.pane == .scheduled then " Scheduled [active] (" ++ toString scheduledCount ++ ")"
         else " Scheduled (" ++ toString scheduledCount ++ ")")
  let footerLines := footer bounds state
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length
  let detailCap := detailCapacityForBounds bounds
  let details := fixedDetailLines snapshot state detailCap
  let noticeRows := if state.notice.isEmpty then 0 else 1
  let fixedBodyRows := 6 + detailCap + noticeRows
  let paneRows := max 1 (bodyCapacity - fixedBodyRows)
  let body :=
    [ rule bounds '='
    , plainLine " Household Day Workspace"
    , plainLine (" Focus: " ++ state.focusDate ++ "  |  Known through: " ++ snapshot.actual.today)
    , rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range paneRows).map (paneRow snapshot state leftWidth rightWidth paneRows) ++
    [rule bounds '-'] ++ details ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (Loam.Tui.Layout.fitWithFooter bounds body footerLines)

end Loam.Tui.SelectedDay