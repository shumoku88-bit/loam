import Loam.ActualReview
import Loam.Prototype.VerifiedTui04.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Prototype.VerifiedTui07.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record

/-- One admitted read-only household snapshot shared by every composed surface. -/
structure Snapshot where
  today : String
  allRecords : List ReviewRecord
  undatedCount : Nat

/--
Day-local Actual review state. The selected row is structurally bounded by the
currently displayed projection. This is UI orientation only, never authority.
-/
structure ReviewCursor where
  date : String
  totalCount : Nat
  displayed : Array ReviewRecord
  selected : Option (Fin displayed.size)

/--
Composition state keeps impossible list/detail-without-cursor states out of the
surface type. Calendar may cache the cursor for its currently selected day so
Back -> Calendar -> Enter can preserve row orientation without persisting it.
-/
inductive Surface where
  | calendar (lastReview : Option ReviewCursor)
  | list (cursor : ReviewCursor)
  | detail (cursor : ReviewCursor)

structure State where
  day : Fin 30 := ⟨5, by decide⟩
  surface : Surface := .calendar none
  notice : String := ""

inductive Event where
  | left
  | right
  | up
  | down
  | enter
  | back
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  quit : Bool := false


def initialState : State := {}


def monthBoundaryNotice : String :=
  "Adjacent month omitted in this composition prototype."


def reviewBoundaryNotice : String :=
  "No more records in this bounded day review."


def noRecordNotice : String :=
  "No current Actual record is available to open on this day."


def dayNumber (day : Fin 30) : Nat :=
  day.val + 1


def twoDigits (value : Nat) : String :=
  if value < 10 then "0" ++ toString value else toString value


def dayDate (day : Fin 30) : String :=
  "2026-09-" ++ twoDigits (dayNumber day)


def recordsForDay (snapshot : Snapshot) (day : Fin 30) : List ReviewRecord :=
  Loam.ActualReview.select snapshot.allRecords (.day (dayDate day))


def cursorForDay (snapshot : Snapshot) (day : Fin 30) : ReviewCursor :=
  let records := recordsForDay snapshot day
  let displayed := (records.take 10).toArray
  let selected : Option (Fin displayed.size) :=
    if h : 0 < displayed.size then some ⟨0, h⟩ else none
  {
    date := dayDate day
    totalCount := records.length
    displayed := displayed
    selected := selected
  }


def movePreviousDay (state : State) : State :=
  if h : state.day.val = 0 then
    { state with notice := monthBoundaryNotice }
  else
    { state with
      day := ⟨state.day.val - 1, by omega⟩
      surface := .calendar none
      notice := ""
    }


def moveNextDay (state : State) : State :=
  if h : state.day.val + 1 < 30 then
    { state with
      day := ⟨state.day.val + 1, h⟩
      surface := .calendar none
      notice := ""
    }
  else
    { state with notice := monthBoundaryNotice }


def movePreviousWeek (state : State) : State :=
  if h : 7 ≤ state.day.val then
    { state with
      day := ⟨state.day.val - 7, by omega⟩
      surface := .calendar none
      notice := ""
    }
  else
    { state with notice := monthBoundaryNotice }


def moveNextWeek (state : State) : State :=
  if h : state.day.val + 7 < 30 then
    { state with
      day := ⟨state.day.val + 7, h⟩
      surface := .calendar none
      notice := ""
    }
  else
    { state with notice := monthBoundaryNotice }


def moveReviewPrevious (cursor : ReviewCursor) : ReviewCursor × String :=
  match cursor.selected with
  | none => (cursor, noRecordNotice)
  | some index =>
      if h : index.val = 0 then
        (cursor, reviewBoundaryNotice)
      else
        ({ cursor with selected := some ⟨index.val - 1, by omega⟩ }, "")


def moveReviewNext (cursor : ReviewCursor) : ReviewCursor × String :=
  match cursor.selected with
  | none => (cursor, noRecordNotice)
  | some index =>
      if h : index.val + 1 < cursor.displayed.size then
        ({ cursor with selected := some ⟨index.val + 1, h⟩ }, "")
      else
        (cursor, reviewBoundaryNotice)


def openSelectedDay (snapshot : Snapshot) (state : State)
    (cached : Option ReviewCursor) : State :=
  let date := dayDate state.day
  let cursor :=
    match cached with
    | some previous =>
        if previous.date == date then previous else cursorForDay snapshot state.day
    | none => cursorForDay snapshot state.day
  { state with surface := .list cursor, notice := "" }


def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .left =>
      match state.surface with
      | .calendar _ => { state := movePreviousDay state }
      | _ => { state }
  | .right =>
      match state.surface with
      | .calendar _ => { state := moveNextDay state }
      | _ => { state }
  | .up =>
      match state.surface with
      | .calendar _ => { state := movePreviousWeek state }
      | .list cursor =>
          let (nextCursor, notice) := moveReviewPrevious cursor
          { state := { state with surface := .list nextCursor, notice := notice } }
      | .detail _ => { state }
  | .down =>
      match state.surface with
      | .calendar _ => { state := moveNextWeek state }
      | .list cursor =>
          let (nextCursor, notice) := moveReviewNext cursor
          { state := { state with surface := .list nextCursor, notice := notice } }
      | .detail _ => { state }
  | .enter =>
      match state.surface with
      | .calendar cached => { state := openSelectedDay snapshot state cached }
      | .list cursor =>
          match cursor.selected with
          | some _ => { state := { state with surface := .detail cursor, notice := "" } }
          | none => { state := { state with notice := noRecordNotice } }
      | .detail _ => { state }
  | .back =>
      match state.surface with
      | .calendar _ => { state }
      | .detail cursor =>
          { state := { state with surface := .list cursor, notice := "" } }
      | .list cursor =>
          { state := { state with surface := .calendar (some cursor), notice := "" } }
  | .other => { state }


theorem day_bounds (state : State) : state.day.val < 30 :=
  state.day.isLt


theorem review_selection_bounds (cursor : ReviewCursor)
    (index : Fin cursor.displayed.size) (_h : cursor.selected = some index) :
    index.val < cursor.displayed.size :=
  index.isLt


theorem enter_preserves_day (snapshot : Snapshot) (state : State) :
    (update snapshot state .enter).state.day = state.day := by
  cases state with
  | mk day surface notice =>
      cases surface with
      | calendar cached => simp [update, openSelectedDay]
      | list cursor =>
          cases cursor.selected <;> rfl
      | detail cursor => rfl


theorem back_preserves_day (snapshot : Snapshot) (state : State) :
    (update snapshot state .back).state.day = state.day := by
  cases state with
  | mk day surface notice =>
      cases surface <;> rfl


theorem back_from_detail_preserves_cursor
    (snapshot : Snapshot) (day : Fin 30) (cursor : ReviewCursor) (notice : String) :
    (update snapshot { day := day, surface := .detail cursor, notice := notice } .back).state.surface =
      .list cursor := by
  rfl


theorem back_from_list_caches_cursor
    (snapshot : Snapshot) (day : Fin 30) (cursor : ReviewCursor) (notice : String) :
    (update snapshot { day := day, surface := .list cursor, notice := notice } .back).state.surface =
      .calendar (some cursor) := by
  rfl


theorem event_determinism (snapshot : Snapshot) (state : State) (event : Event)
    (left right : Step)
    (hLeft : update snapshot state event = left)
    (hRight : update snapshot state event = right) :
    left = right := by
  rw [← hLeft, ← hRight]


def screenBounds : Bounds :=
  { width := 80, height := 24 }


def plainLine (text : String) : Widget :=
  .row [span text]


def mutedLine (text : String) : Widget :=
  .row [span text .muted]


def blankLine : Widget :=
  .row []


def dayCellText (day : Nat) : String :=
  if day < 10 then " " ++ toString day ++ "  " else toString day ++ "  "


def calendarCell (state : State) (slot : Nat) : Span :=
  if slot = 0 ∨ 30 < slot then
    span "    "
  else
    let style := if dayNumber state.day = slot then Style.selected else Style.normal
    span (dayCellText slot) style


def calendarRow (state : State) (row : Nat) : Widget :=
  .row <| (List.range 7).map fun col => calendarCell state (row * 7 + col)


def calendarView (state : State) : List Widget :=
  [ plainLine "    September 2026"
  , mutedLine "Mon Tue Wed Thu Fri Sat Sun"
  ] ++ (List.range 5).map (calendarRow state)


def selectedDayLine (state : State) : Widget :=
  .row
    [ span "Selected day: "
    , span (" " ++ dayDate state.day ++ " ") .selected
    ]


def homeView (snapshot : Snapshot) (state : State) : Widget :=
  let actualCount := (recordsForDay snapshot state.day).length
  let countText :=
    if actualCount = 0 then "No current Actual records on this day."
    else toString actualCount ++ " current Actual record(s) on this day."
  .column <|
    [ plainLine "LOAM UI Prototype 07  [CANONICAL READ-ONLY]"
    , mutedLine "Calendar -> selected-day Actual -> detail"
    , blankLine
    ] ++
    calendarView state ++
    [ selectedDayLine state
    , blankLine
    , plainLine ("Actual: " ++ countText)
    , mutedLine "Enter opens this day's admitted current Actual records."
    , blankLine
    , mutedLine "←/→ Day    ↑/↓ Week    Enter Actual    q Quit"
    , mutedLine state.notice
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
    else Loam.ActualReview.shortText 44 record.description
  let eventId := Loam.ActualReview.shortText 18 record.event.id.token
  let text := marker ++ description ++ "  [" ++ eventId ++ "]"
  .row [span text (if selected then .selected else .normal)]


def listView (cursor : ReviewCursor) (state : State) : Widget :=
  let countText :=
    if cursor.totalCount = 0 then
      "No current Actual records on this day."
    else
      "Showing " ++ toString cursor.displayed.size ++ " of " ++
        toString cursor.totalCount ++ " current record(s)."
  .column <|
    [ plainLine "Selected-day Actual  [CANONICAL READ-ONLY]"
    , plainLine cursor.date
    , mutedLine countText
    , blankLine
    ] ++
    (List.finRange cursor.displayed.size).map (reviewRow cursor) ++
    [ blankLine
    , mutedLine "↑/↓ Select    Enter Detail    b Calendar    q Quit"
    , mutedLine state.notice
    ]


def detailView (snapshot : Snapshot) (cursor : ReviewCursor) : Widget :=
  match selectedRecord? cursor with
  | none =>
      .column
        [ plainLine "Actual detail  [CANONICAL READ-ONLY]"
        , blankLine
        , mutedLine "No displayed record is selected."
        , mutedLine "b Back    q Quit"
        ]
  | some record =>
      .column <|
        [ plainLine "Actual detail  [CANONICAL READ-ONLY]"
        , blankLine
        ] ++
        ((Loam.ActualReview.detailLines snapshot.allRecords record).map fun line =>
          plainLine (Loam.ActualReview.shortText 76 line)) ++
        [ blankLine
        , mutedLine "b Back    q Quit"
        ]


def view (snapshot : Snapshot) (state : State) : Widget :=
  match state.surface with
  | .calendar _ => homeView snapshot state
  | .list cursor => listView cursor state
  | .detail cursor => detailView snapshot cursor


def screenFor (snapshot : Snapshot) (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Prototype.VerifiedTui07.Main
