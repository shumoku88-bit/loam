import Loam.ActualReview
import Loam.Prototype.VerifiedTui04.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Prototype.VerifiedTui06.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

abbrev ReviewRecord := Loam.ActualReview.Record

/-- One admitted read-only household snapshot for the canonical review specimen. -/
structure Snapshot where
  today : String
  allRecords : List ReviewRecord
  recentCount : Nat
  displayed : Array ReviewRecord
  undatedCount : Nat

inductive Surface where
  | list
  | detail
  deriving Repr, DecidableEq, BEq

/--
Selection carries the displayed-row bound in its type. `none` is the empty-list
state; a detail surface is opened only from `some index`.
-/
structure State (count : Nat) where
  surface : Surface := .list
  selected : Option (Fin count) := none
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | up
  | down
  | enter
  | back
  | quit
  | other
  deriving Repr, DecidableEq, BEq

structure Step (count : Nat) where
  state : State count
  quit : Bool := false
  deriving Repr, DecidableEq

def initialState (count : Nat) : State count :=
  if h : 0 < count then
    { selected := some ⟨0, h⟩ }
  else
    {}

def boundaryNotice : String :=
  "No more records in this bounded review page."

def movePrevious {count : Nat} (state : State count) : State count :=
  match state.selected with
  | none => state
  | some index =>
      if h : index.val = 0 then
        { state with notice := boundaryNotice }
      else
        { state with
          selected := some ⟨index.val - 1, by omega⟩
          notice := ""
        }

def moveNext {count : Nat} (state : State count) : State count :=
  match state.selected with
  | none => state
  | some index =>
      if h : index.val + 1 < count then
        { state with
          selected := some ⟨index.val + 1, h⟩
          notice := ""
        }
      else
        { state with notice := boundaryNotice }

def update {count : Nat} (state : State count) (event : Event) : Step count :=
  match event with
  | .quit => { state, quit := true }
  | .up =>
      match state.surface with
      | .list => { state := movePrevious state }
      | .detail => { state }
  | .down =>
      match state.surface with
      | .list => { state := moveNext state }
      | .detail => { state }
  | .enter =>
      match state.surface, state.selected with
      | .list, some _ => { state := { state with surface := .detail, notice := "" } }
      | _, _ => { state }
  | .back =>
      match state.surface with
      | .detail => { state := { state with surface := .list, notice := "" } }
      | .list => { state }
  | .other => { state }

theorem selection_bounds {count : Nat} (state : State count) (index : Fin count)
    (_h : state.selected = some index) : index.val < count := by
  exact index.isLt

theorem enter_preserves_selection {count : Nat} (state : State count) :
    (update state .enter).state.selected = state.selected := by
  cases state with
  | mk surface selected notice =>
      cases surface <;> cases selected <;> rfl

theorem back_preserves_selection {count : Nat} (state : State count) :
    (update state .back).state.selected = state.selected := by
  cases state with
  | mk surface selected notice =>
      cases surface <;> cases selected <;> rfl

theorem event_determinism {count : Nat}
    (state : State count) (event : Event) (left right : Step count)
    (hLeft : update state event = left) (hRight : update state event = right) :
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

def selectedRecord? (snapshot : Snapshot)
    (state : State snapshot.displayed.size) : Option ReviewRecord :=
  match state.selected with
  | none => none
  | some index => some (snapshot.displayed.get index)

def reviewRow (snapshot : Snapshot)
    (state : State snapshot.displayed.size)
    (index : Fin snapshot.displayed.size) : Widget :=
  let record := snapshot.displayed.get index
  let selected := decide (state.selected = some index)
  let marker := if selected then "▶ " else "  "
  let date := Loam.ActualReview.displayText (record.date.getD "date unknown")
  let description :=
    if record.description.isEmpty then "(no description)"
    else Loam.ActualReview.shortText 34 record.description
  let eventId := Loam.ActualReview.shortText 18 record.event.id.token
  let text := marker ++ date ++ "  " ++ description ++ "  [" ++ eventId ++ "]"
  .row [span text (if selected then .selected else .normal)]

def listView (snapshot : Snapshot)
    (state : State snapshot.displayed.size) : Widget :=
  let countLine :=
    if snapshot.recentCount = 0 then
      "No matches in the recent week; this does not prove something was never recorded."
    else
      "Showing " ++ toString snapshot.displayed.size ++ " of " ++
        toString snapshot.recentCount ++ " current matches."
  .column <|
    [ plainLine "LOAM UI Prototype 06  [CANONICAL READ-ONLY]"
    , mutedLine "Actual review through the shared fail-closed review boundary"
    , blankLine
    , plainLine ("Week through " ++ snapshot.today ++ "  (occurrence dates, not entry time)")
    , mutedLine ("Date unknown (current): " ++ toString snapshot.undatedCount)
    , mutedLine countLine
    , blankLine
    ] ++
    (List.finRange snapshot.displayed.size).map (reviewRow snapshot state) ++
    [ blankLine
    , mutedLine "↑/↓ Select    Enter Detail    q Quit"
    , mutedLine state.notice
    ]

def detailView (snapshot : Snapshot)
    (state : State snapshot.displayed.size) : Widget :=
  match selectedRecord? snapshot state with
  | none =>
      .column
        [ plainLine "Recent Actual detail  [CANONICAL READ-ONLY]"
        , blankLine
        , mutedLine "No displayed record is selected."
        , mutedLine "b Back    q Quit"
        ]
  | some record =>
      .column <|
        [ plainLine "Recent Actual detail  [CANONICAL READ-ONLY]"
        , blankLine
        ] ++
        ((Loam.ActualReview.detailLines snapshot.allRecords record).map fun line =>
          plainLine (Loam.ActualReview.shortText 76 line)) ++
        [ blankLine
        , mutedLine "The selected EventId is presentation state only; this surface cannot write."
        , mutedLine "b Back    q Quit"
        ]

def view (snapshot : Snapshot)
    (state : State snapshot.displayed.size) : Widget :=
  match state.surface with
  | .list => listView snapshot state
  | .detail => detailView snapshot state

def screenFor (snapshot : Snapshot)
    (state : State snapshot.displayed.size) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view snapshot state)

end Loam.Prototype.VerifiedTui06.Main
