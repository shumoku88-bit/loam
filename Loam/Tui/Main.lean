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

structure ActualSnapshot where
  today : String
  allRecords : List ReviewRecord
  undatedCount : Nat

/-- One admitted household read snapshot. It is process-local evidence, never TUI authority. -/
structure Snapshot where
  actual : ActualSnapshot
  scheduled : Loam.ScheduledReview.EvidenceSnapshot

structure ReviewCursor where
  date : String
  totalCount : Nat
  displayed : Array ReviewRecord
  selected : Option (Fin displayed.size)

inductive ActualMode where
  | browse
  | detail
  deriving Repr, DecidableEq, BEq

/-- Production interaction surfaces. Browse/detail stay local to one Actual workspace. -/
inductive Surface where
  | home (lastReview : Option ReviewCursor)
  | actual (cursor : ReviewCursor) (mode : ActualMode)
  | scheduled (lastReview : Option ReviewCursor)

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
  let displayed := (records.take 10).toArray
  let selected : Option (Fin displayed.size) :=
    if h : 0 < displayed.size then some ⟨0, h⟩ else none
  { date := date, totalCount := records.length, displayed := displayed, selected := selected }


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


def openActual (snapshot : Snapshot) (state : State) (cached : Option ReviewCursor) : State :=
  let cursor :=
    match cached with
    | some previous =>
        if previous.date == state.selectedDate then previous
        else cursorForDay snapshot state.selectedDate
    | none => cursorForDay snapshot state.selectedDate
  { state with surface := .actual cursor .browse, notice := "" }


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
      | _ => { state }
  | .down =>
      match state.surface with
      | .home _ => { state := moveDate state 7 }
      | .actual cursor .browse =>
          let (nextCursor, notice) := moveReviewNext cursor
          { state := { state with surface := .actual nextCursor .browse, notice := notice } }
      | _ => { state }
  | .tab =>
      match state.surface with
      | .home cached => { state := { state with surface := .scheduled cached, notice := "" } }
      | _ => { state }
  | .enter =>
      match state.surface with
      | .home cached => { state := openActual snapshot state cached }
      | .actual cursor .browse =>
          match cursor.selected with
          | some _ => { state := { state with surface := .actual cursor .detail, notice := "" } }
          | none => { state := { state with notice := "No current Actual record is available on this day." } }
      | _ => { state }
  | .back =>
      match state.surface with
      | .home _ => { state }
      | .scheduled cached => { state := { state with surface := .home cached, notice := "" } }
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
    (snapshot : Snapshot) (state : State) (cached : Option ReviewCursor) :
    (update snapshot { state with surface := .scheduled cached } .back).state.selectedDate =
      state.selectedDate := by
  rfl


theorem enter_preserves_selected_date
    (snapshot : Snapshot) (state : State) :
    (update snapshot state .enter).state.selectedDate = state.selectedDate := by
  cases state with
  | mk date surface notice =>
      cases surface with
      | home cached => simp [update, openActual]
      | scheduled cached => rfl
      | actual cursor mode =>
          cases mode with
          | detail => rfl
          | browse => cases h : cursor.selected <;> simp [update, h]


def selectedMonth (state : State) : Loam.Tui.Calendar.Month :=
  (Loam.Tui.Calendar.monthOf? state.selectedDate).getD { year := 1970, month := 1 }


def calendarSlot (state : State) (row col : Nat) : Option String :=
  match (Loam.Tui.Calendar.slots (selectedMonth state))[row * 7 + col]? with
  | none => none
  | some date => date


def dayText (date : String) : String :=
  match date.splitOn "-" with
  | [_, _, day] => day ++ "  "
  | _ => "    "


def calendarSpans (state : State) (row : Nat) : List Span :=
  (List.range 7).map fun col =>
    match calendarSlot state row col with
    | none => span "    "
    | some date =>
        span (dayText date) (if date == state.selectedDate then .selected else .normal)


def homeActualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.selectedDate


def homeActualPreview (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  (homeActualRecords snapshot state).take 3


def homeScheduledEvidence (snapshot : Snapshot) (state : State) : ScheduledEvidence :=
  Loam.ScheduledReview.dayEvidence snapshot.scheduled state.selectedDate


def homeScheduledRecords (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  Loam.ScheduledReview.explicitDueRecords (homeScheduledEvidence snapshot state)


def homeScheduledPreview (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  (homeScheduledRecords snapshot state).take 2


def listAt? {α : Type} : List α → Nat → Option α
  | [], _ => none
  | value :: _, 0 => some value
  | _ :: rest, index + 1 => listAt? rest index


def actualPreviewSpans (snapshot : Snapshot) (state : State) (index : Nat) : List Span :=
  match listAt? (homeActualPreview snapshot state) index with
  | none => [span ""]
  | some record =>
      let description :=
        if record.description.isEmpty then "(no description)"
        else Loam.ActualReview.shortText 18 record.description
      [span "- " .muted, span description]


def scheduledPreviewSpans (snapshot : Snapshot) (state : State) (index : Nat) : List Span :=
  match listAt? (homeScheduledPreview snapshot state) index with
  | none => [span ""]
  | some record => [span "- " .muted, span (Loam.ActualReview.shortText 32 (Loam.ScheduledReview.summary record))]


def scheduledHeader (snapshot : Snapshot) (state : State) : String :=
  match homeScheduledEvidence snapshot state with
  | .due first rest => "Scheduled / Due / " ++ toString (rest.length + 1) ++ " explicit"
  | .unknown => "Scheduled / Unknown"
  | .unknownCompletionScheduled => "Scheduled / refused completion evidence"
  | .unknownRetirementScheduled => "Scheduled / refused retirement evidence"
  | .unknownReplacementScheduled => "Scheduled / refused replacement evidence"
  | .invalidReplacementGraph => "Scheduled / refused replacement graph"
  | .conflictingTerminalEvidence => "Scheduled / refused terminal evidence"


def homeEvidenceSpans (snapshot : Snapshot) (state : State) : Nat → List Span
  | 0 => [span ("Actual / " ++ toString (homeActualRecords snapshot state).length ++ " current")]
  | 1 => actualPreviewSpans snapshot state 0
  | 2 => actualPreviewSpans snapshot state 1
  | 3 => actualPreviewSpans snapshot state 2
  | 4 => [span (scheduledHeader snapshot state)]
  | 5 => scheduledPreviewSpans snapshot state 0
  | 6 => scheduledPreviewSpans snapshot state 1
  | _ => [span ""]


def homeEvidenceRow (snapshot : Snapshot) (state : State) (row : Nat) : Widget :=
  let calendar := if row < 6 then calendarSpans state row else [span "                            "]
  .row <| calendar ++ [span "    "] ++ homeEvidenceSpans snapshot state row


def homeView (snapshot : Snapshot) (state : State) : Widget :=
  .column <|
    [ .row [span "LOAM Home", span "        ", span (" " ++ state.selectedDate ++ " ") .selected]
    , mutedLine "One selected day drives Actual and Scheduled evidence."
    , blankLine
    , .row
        [ span ("    " ++ Loam.Tui.Calendar.monthLabel (selectedMonth state))
        , span "                  "
        , span "Selected-day evidence"
        ]
    , .row [span "Mon Tue Wed Thu Fri Sat Sun" .muted]
    ] ++
    (List.range 7).map (homeEvidenceRow snapshot state) ++
    [ blankLine
    , mutedLine ("Undated current Actual: " ++ toString snapshot.actual.undatedCount)
    , mutedLine "←/→ day   ↑/↓ week   Enter Actual   Tab Scheduled   r Record   q quit"
    , mutedLine (if state.notice.isEmpty then
        "a Attention   b Balances   c Capacity   p Reports"
      else state.notice)
    ]


def selectedRecord? (cursor : ReviewCursor) : Option ReviewRecord :=
  match cursor.selected with
  | none => none
  | some index => some cursor.displayed[index]


def reviewRow (cursor : ReviewCursor) (index : Fin cursor.displayed.size) : Widget :=
  let record := cursor.displayed[index]
  let selected := decide (cursor.selected = some index)
  let marker := if selected then "▶ " else "  "
  let description :=
    if record.description.isEmpty then "(no description)"
    else Loam.ActualReview.shortText 52 record.description
  .row [span (marker ++ description) (if selected then .selected else .normal)]


def actualBrowseView (cursor : ReviewCursor) (state : State) : Widget :=
  .column <|
    [ plainLine "Actual / Browse"
    , mutedLine "Home > Actual"
    , plainLine cursor.date
    , mutedLine (toString cursor.totalCount ++ " current record(s) on this day")
    , blankLine
    ] ++
    (List.finRange cursor.displayed.size).map (reviewRow cursor) ++
    [ blankLine
    , mutedLine "↑/↓ select   Enter detail   b home   q quit"
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


def scheduledRecordLine (record : ScheduledRecord) : Widget :=
  .row [span "- " .muted, span (Loam.ActualReview.shortText 68 (Loam.ScheduledReview.summary record))]


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


def scheduledView (snapshot : Snapshot) (state : State) : Widget :=
  match homeScheduledEvidence snapshot state with
  | .due first rest =>
      let all := first :: rest
      .column <|
        [ plainLine "Scheduled / Due"
        , mutedLine "Home > Scheduled"
        , plainLine state.selectedDate
        , mutedLine (toString all.length ++ " explicit current-open occurrence(s)")
        , blankLine
        ] ++
        (all.take 10).map scheduledRecordLine ++
        [ blankLine
        , mutedLine "Expectation evidence, not Actual evidence."
        , mutedLine "No recurrence or completeness is inferred beyond retained evidence."
        , mutedLine "b home   q quit"
        ]
  | .unknown =>
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
  | .unknownCompletionScheduled => refusedScheduledView state "Completion evidence references an unknown Scheduled identity."
  | .unknownRetirementScheduled => refusedScheduledView state "Retirement evidence references an unknown Scheduled identity."
  | .unknownReplacementScheduled => refusedScheduledView state "Replacement evidence references an unknown Scheduled identity."
  | .invalidReplacementGraph => refusedScheduledView state "Scheduled replacement topology is invalid."
  | .conflictingTerminalEvidence => refusedScheduledView state "Scheduled terminal evidence conflicts."


def view (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .home _ => homeView snapshot state
  | .actual cursor .browse => actualBrowseView cursor state
  | .actual cursor .detail => actualDetailView snapshot cursor
  | .scheduled _ => scheduledView snapshot state


def screenBounds : Bounds := { width := 80, height := 24 }
def screenFor (snapshot : Snapshot) (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Tui.Main
