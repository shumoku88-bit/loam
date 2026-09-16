import Loam.ActualReview
import Loam.ScheduledReview
import Loam.Tui.Calendar
import Loam.Tui.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.Main

open Loam.Tui.Kernel

set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record
abbrev ScheduledRecord := Loam.ScheduledReview.Record
abbrev ScheduledEvidence := Loam.ScheduledReview.DayEvidence
abbrev ScheduledAvailability := Except String Loam.ScheduledReview.EvidenceSnapshot

structure ActualSnapshot where
  today : String
  allRecords : List ReviewRecord

/-- One admitted household read snapshot. It is process-local evidence, never TUI authority. -/
structure Snapshot where
  actual : ActualSnapshot
  /-- Scheduled refusal remains explicit and must never be reinterpreted as an empty household. -/
  scheduled : ScheduledAvailability

structure ReviewCursor where
  date : String
  displayed : Array ReviewRecord
  selected : Option (Fin displayed.size)

structure ScheduledCursor where
  date : String
  displayed : Array ScheduledRecord
  selected : Option (Fin displayed.size)

/-- The browse total is exactly the retained full-day Actual array size. -/
def ReviewCursor.totalCount (cursor : ReviewCursor) : Nat :=
  cursor.displayed.size

/-- The Scheduled browse total is exactly the retained full-day occurrence array size. -/
def ScheduledCursor.totalCount (cursor : ScheduledCursor) : Nat :=
  cursor.displayed.size

inductive ActualMode where
  | browse
  | detail
  deriving Repr, DecidableEq, BEq

inductive ScheduledMode where
  | browse
  | detail
  deriving Repr, DecidableEq, BEq

/-- Production interaction surfaces. Browse/detail stay local to one workspace. -/
inductive Surface where
  | home (lastReview : Option ReviewCursor)
  | actual (cursor : ReviewCursor) (mode : ActualMode)
  | scheduled (lastReview : Option ReviewCursor) (cursor : ScheduledCursor) (mode : ScheduledMode)

structure State where
  selectedDate : String
  surface : Surface := .home none
  notice : String := ""

inductive Event where
  | left
  | right
  | up
  | down
  | tab
  | enter
  | back
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false


def initialState (selectedDate : String) : State :=
  { selectedDate := selectedDate }


def plainLine (text : String) : Widget := .row [span text]
def mutedLine (text : String) : Widget := .row [span text .muted]
def blankLine : Widget := .row []


def recordsForDay (snapshot : Snapshot) (date : String) : List ReviewRecord :=
  Loam.ActualReview.select snapshot.actual.allRecords (.day date)


def cursorForDay (snapshot : Snapshot) (date : String) : ReviewCursor :=
  let records := recordsForDay snapshot date
  let displayed := records.toArray
  let selected : Option (Fin displayed.size) :=
    if h : 0 < displayed.size then some ⟨0, h⟩ else none
  { date := date, displayed := displayed, selected := selected }


def scheduledCursorForDay
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot) (date : String) : ScheduledCursor :=
  let evidence := Loam.ScheduledReview.dayEvidence scheduled date
  let records := Loam.ScheduledReview.explicitDueRecords evidence
  let displayed := records.toArray
  let selected : Option (Fin displayed.size) :=
    if h : 0 < displayed.size then some ⟨0, h⟩ else none
  { date := date, displayed := displayed, selected := selected }


def moveDate (state : State) (offset : Int) : State :=
  match Loam.ActualDate.shiftDays? state.selectedDate offset with
  | none => { state with notice := "Calendar boundary reached." }
  | some date => { state with selectedDate := date, surface := .home none, notice := "" }


def moveReviewPrevious (cursor : ReviewCursor) : ReviewCursor × String :=
  match cursor.selected with
  | none => (cursor, "No current Actual record is available on this day.")
  | some index =>
      if h : index.val = 0 then
        (cursor, "No previous row in this day view.")
      else
        ({ cursor with selected := some ⟨index.val - 1, by omega⟩ }, "")


def moveReviewNext (cursor : ReviewCursor) : ReviewCursor × String :=
  match cursor.selected with
  | none => (cursor, "No current Actual record is available on this day.")
  | some index =>
      if h : index.val + 1 < cursor.displayed.size then
        ({ cursor with selected := some ⟨index.val + 1, h⟩ }, "")
      else
        (cursor, "No next row in this day view.")


def moveScheduledPrevious (cursor : ScheduledCursor) : ScheduledCursor × String :=
  match cursor.selected with
  | none => (cursor, "No explicit current-open Scheduled occurrence is available on this day.")
  | some index =>
      if h : index.val = 0 then
        (cursor, "No previous Scheduled row in this day view.")
      else
        ({ cursor with selected := some ⟨index.val - 1, by omega⟩ }, "")


def moveScheduledNext (cursor : ScheduledCursor) : ScheduledCursor × String :=
  match cursor.selected with
  | none => (cursor, "No explicit current-open Scheduled occurrence is available on this day.")
  | some index =>
      if h : index.val + 1 < cursor.displayed.size then
        ({ cursor with selected := some ⟨index.val + 1, h⟩ }, "")
      else
        (cursor, "No next Scheduled row in this day view.")


def openActual (snapshot : Snapshot) (state : State) (cached : Option ReviewCursor) : State :=
  let cursor :=
    match cached with
    | some previous =>
        if previous.date == state.selectedDate then previous
        else cursorForDay snapshot state.selectedDate
    | none => cursorForDay snapshot state.selectedDate
  { state with surface := .actual cursor .browse, notice := "" }


def openScheduled (snapshot : Snapshot) (state : State) (cached : Option ReviewCursor) : State :=
  match snapshot.scheduled with
  | .error message =>
      { state with surface := .home cached, notice := "[Unavailable] Scheduled: " ++ message }
  | .ok scheduled =>
      let cursor := scheduledCursorForDay scheduled state.selectedDate
      { state with surface := .scheduled cached cursor .browse, notice := "" }


def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left =>
      match state.surface with
      | .home _ => { state := moveDate state (-1) }
      | _ => { state }
  | .right =>
      match state.surface with
      | .home _ => { state := moveDate state 1 }
      | _ => { state }
  | .up =>
      match state.surface with
      | .home _ => { state := moveDate state (-7) }
      | .actual cursor .browse =>
          let (nextCursor, notice) := moveReviewPrevious cursor
          { state := { state with surface := .actual nextCursor .browse, notice := notice } }
      | .scheduled cached cursor .browse =>
          let (nextCursor, notice) := moveScheduledPrevious cursor
          { state := { state with surface := .scheduled cached nextCursor .browse, notice := notice } }
      | _ => { state }
  | .down =>
      match state.surface with
      | .home _ => { state := moveDate state 7 }
      | .actual cursor .browse =>
          let (nextCursor, notice) := moveReviewNext cursor
          { state := { state with surface := .actual nextCursor .browse, notice := notice } }
      | .scheduled cached cursor .browse =>
          let (nextCursor, notice) := moveScheduledNext cursor
          { state := { state with surface := .scheduled cached nextCursor .browse, notice := notice } }
      | _ => { state }
  | .tab =>
      match state.surface with
      | .home cached => { state := openScheduled snapshot state cached }
      | _ => { state }
  | .enter =>
      match state.surface with
      | .home cached => { state := openActual snapshot state cached }
      | .actual cursor .browse =>
          match cursor.selected with
          | some _ => { state := { state with surface := .actual cursor .detail, notice := "" } }
          | none => { state := { state with notice := "No current Actual record is available on this day." } }
      | .scheduled cached cursor .browse =>
          match cursor.selected with
          | some _ => { state := { state with surface := .scheduled cached cursor .detail, notice := "" } }
          | none => { state := { state with notice := "No explicit current-open Scheduled occurrence is available on this day." } }
      | _ => { state }
  | .back =>
      match state.surface with
      | .home _ => { state }
      | .scheduled cached cursor .detail =>
          { state := { state with surface := .scheduled cached cursor .browse, notice := "" } }
      | .scheduled cached _ .browse => { state := { state with surface := .home cached, notice := "" } }
      | .actual cursor .detail =>
          { state := { state with surface := .actual cursor .browse, notice := "" } }
      | .actual cursor .browse =>
          { state := { state with surface := .home (some cursor), notice := "" } }
  | .other => { state }


theorem back_from_actual_detail_preserves_cursor
    (snapshot : Snapshot) (state : State) (cursor : ReviewCursor) :
    (update snapshot { state with surface := .actual cursor .detail } .back).state.surface =
      .actual cursor .browse := by
  rfl


theorem back_from_scheduled_preserves_date
    (snapshot : Snapshot) (state : State) (cached : Option ReviewCursor)
    (cursor : ScheduledCursor) (mode : ScheduledMode) :
    (update snapshot { state with surface := .scheduled cached cursor mode } .back).state.selectedDate =
      state.selectedDate := by
  cases mode <;> rfl


theorem enter_preserves_selected_date
    (snapshot : Snapshot) (state : State) :
    (update snapshot state .enter).state.selectedDate = state.selectedDate := by
  cases state with
  | mk date surface notice =>
      cases surface with
      | home cached => simp [update, openActual]
      | actual cursor mode =>
          cases mode with
          | detail => rfl
          | browse => cases h : cursor.selected <;> simp [update, h]
      | scheduled cached cursor mode =>
          cases mode with
          | detail => rfl
          | browse => cases h : cursor.selected <;> simp [update, h]


def selectedMonth (state : State) : Loam.Tui.Calendar.Month :=
  (Loam.Tui.Calendar.monthOf? state.selectedDate).getD { year := 1970, month := 1 }


def calendarSlot (state : State) (row col : Nat) : Option String :=
  match (Loam.Tui.Calendar.slots (selectedMonth state))[row * 7 + col]? with
  | none => none
  | some date => date


def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.selectedDate

def homeScheduledEvidence
    (snapshot : Snapshot) (state : State) : Except String ScheduledEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled => .ok (Loam.ScheduledReview.dayEvidence scheduled state.selectedDate)


def selectedRecord? (cursor : ReviewCursor) : Option ReviewRecord :=
  match cursor.selected with
  | none => none
  | some index => some cursor.displayed[index]


def selectedScheduledRecord? (cursor : ScheduledCursor) : Option ScheduledRecord :=
  match cursor.selected with
  | none => none
  | some index => some cursor.displayed[index]


def reviewWindowSize : Nat := 10


def reviewWindowStart (cursor : ReviewCursor) : Nat :=
  match cursor.selected with
  | none => 0
  | some index =>
      if index.val < reviewWindowSize then 0
      else index.val + 1 - reviewWindowSize


def visibleReviewRows (cursor : ReviewCursor) : List (Nat × ReviewRecord) :=
  let start := reviewWindowStart cursor
  (List.range reviewWindowSize).filterMap fun offset =>
    let index := start + offset
    match cursor.displayed[index]? with
    | none => none
    | some record => some (index, record)


def scheduledWindowStart (cursor : ScheduledCursor) : Nat :=
  match cursor.selected with
  | none => 0
  | some index =>
      if index.val < reviewWindowSize then 0
      else index.val + 1 - reviewWindowSize


def visibleScheduledRows (cursor : ScheduledCursor) : List (Nat × ScheduledRecord) :=
  let start := scheduledWindowStart cursor
  (List.range reviewWindowSize).filterMap fun offset =>
    let index := start + offset
    match cursor.displayed[index]? with
    | none => none
    | some record => some (index, record)


def reviewRow (cursor : ReviewCursor) (index : Nat) (record : ReviewRecord) : Widget :=
  let selected :=
    match cursor.selected with
    | none => false
    | some current => current.val == index
  let marker := if selected then "▶ " else "  "
  let description :=
    if record.description.isEmpty then "(no description)"
    else Loam.ActualReview.shortText 52 record.description
  .row [span (marker ++ description) (if selected then .selected else .normal)]


def scheduledRow (cursor : ScheduledCursor) (index : Nat) (record : ScheduledRecord) : Widget :=
  let selected :=
    match cursor.selected with
    | none => false
    | some current => current.val == index
  let marker := if selected then "▶ " else "  "
  let text := Loam.ActualReview.shortText 68 (Loam.ScheduledReview.summary record)
  .row [span (marker ++ text) (if selected then .selected else .normal)]


def actualBrowseView (cursor : ReviewCursor) (state : State) : Widget :=
  .column <|
    [ plainLine "Actual / Browse"
    , mutedLine "Home > Actual"
    , plainLine cursor.date
    , mutedLine (toString cursor.totalCount ++ " current record(s) on this day")
    , blankLine
    ] ++
    ((visibleReviewRows cursor).map fun row => reviewRow cursor row.1 row.2) ++
    [ blankLine
    , mutedLine "↑/↓ select/scroll   Enter detail   r Record   b home   q quit"
    , mutedLine state.notice
    ]


def actualDetailView (snapshot : Snapshot) (cursor : ReviewCursor) : Widget :=
  match selectedRecord? cursor with
  | none =>
      .column [plainLine "Actual / Detail", blankLine, mutedLine "No selected record.", mutedLine "b browse   q quit"]
  | some record =>
      .column <|
        [plainLine "Actual / Detail", mutedLine "Home > Actual > Detail", blankLine] ++
        ((Loam.ActualReview.detailLines snapshot.actual.allRecords record).map fun line =>
          plainLine (Loam.ActualReview.shortText 76 line)) ++
        [blankLine, mutedLine "b browse   q quit"]


def refusedScheduledView (state : State) (message : String) : Widget :=
  .column
    [ plainLine "Scheduled / Refused"
    , mutedLine "Home > Scheduled"
    , plainLine state.selectedDate
    , blankLine
    , plainLine message
    , blankLine
    , mutedLine "b home   q quit"
    ]


def scheduledBrowseView (cursor : ScheduledCursor) (state : State) : Widget :=
  .column <|
    [ plainLine "Scheduled / Browse"
    , mutedLine "Home > Scheduled"
    , plainLine cursor.date
    , mutedLine (toString cursor.totalCount ++ " explicit current-open occurrence(s)")
    , blankLine
    ] ++
    ((visibleScheduledRows cursor).map fun row => scheduledRow cursor row.1 row.2) ++
    [ blankLine
    , mutedLine "Expectation evidence, not Actual evidence."
    , mutedLine "↑/↓ select/scroll   Enter detail   b home   q quit"
    , mutedLine state.notice
    ]


def scheduledDetailView (cursor : ScheduledCursor) : Widget :=
  match selectedScheduledRecord? cursor with
  | none =>
      .column
        [ plainLine "Scheduled / Detail"
        , blankLine
        , mutedLine "No selected Scheduled occurrence."
        , mutedLine "b browse   q quit"
        ]
  | some record =>
      .column <|
        [ plainLine "Scheduled / Detail"
        , mutedLine "Home > Scheduled > Detail"
        , blankLine
        , plainLine ("id: " ++ record.id.token)
        , plainLine ("scheduled: " ++ record.scheduledOn)
        , plainLine ("summary: " ++ Loam.ScheduledReview.summary record)
        , blankLine
        , mutedLine "Expected movement"
        ] ++
        ((record.movement.changes.take 10).map fun change =>
          plainLine
            ("  " ++ change.coordinate.token ++ ": " ++
              toString change.quantity.quanta ++ " " ++ record.measure.token)) ++
        [ blankLine
        , mutedLine "Expectation evidence, not Actual evidence."
        , mutedLine "b browse   q quit"
        ]


def scheduledView
    (snapshot : Snapshot) (state : State) (cursor : ScheduledCursor) (mode : ScheduledMode) : Widget :=
  match homeScheduledEvidence snapshot state with
  | .error message => refusedScheduledView state ("Scheduled unavailable: " ++ message)
  | .ok (.due _ _) =>
      match mode with
      | .browse => scheduledBrowseView cursor state
      | .detail => scheduledDetailView cursor
  | .ok .unknown =>
      .column
        [ plainLine "Scheduled / Unknown"
        , mutedLine "Home > Scheduled"
        , plainLine state.selectedDate
        , blankLine
        , plainLine "No explicit current-open Scheduled evidence is retained for this day."
        , mutedLine "Unknown is not NotDue; no completeness horizon is claimed here."
        , blankLine
        , mutedLine "b home   q quit"
        ]
  | .ok .unknownCompletionScheduled => refusedScheduledView state "Completion evidence references an unknown Scheduled identity."
  | .ok .unknownRetirementScheduled => refusedScheduledView state "Retirement evidence references an unknown Scheduled identity."
  | .ok .unknownReplacementScheduled => refusedScheduledView state "Replacement evidence references an unknown Scheduled identity."
  | .ok .invalidReplacementGraph => refusedScheduledView state "Scheduled replacement topology is invalid."
  | .ok .conflictingTerminalEvidence => refusedScheduledView state "Scheduled terminal evidence conflicts."


end Loam.Tui.Main
