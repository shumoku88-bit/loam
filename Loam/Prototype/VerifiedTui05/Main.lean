import Loam.Prototype.VerifiedTui04.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Prototype.VerifiedTui05.Main

open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

/-- Synthetic presentation-only row for the second UI pressure test. -/
structure ReviewItem where
  date : String
  eventId : String
  description : String
  effects : List String
  deriving Repr, DecidableEq

def reviewItem : Fin 5 → ReviewItem
  | ⟨0, _⟩ =>
      { date := "2026-09-06"
        eventId := "synthetic-105"
        description := "coffee"
        effects := ["PayPay: -138 JPY", "coffee: +138 JPY"] }
  | ⟨1, _⟩ =>
      { date := "2026-09-05"
        eventId := "synthetic-104"
        description := "train fare"
        effects := ["transit-card: -420 JPY", "transport: +420 JPY"] }
  | ⟨2, _⟩ =>
      { date := "2026-09-04"
        eventId := "synthetic-103"
        description := "groceries"
        effects := ["card: -2480 JPY", "groceries: +2480 JPY"] }
  | ⟨3, _⟩ =>
      { date := "2026-09-03"
        eventId := "synthetic-102"
        description := "book"
        effects := ["PayPay: -1650 JPY", "books: +1650 JPY"] }
  | _ =>
      { date := "2026-09-02"
        eventId := "synthetic-101"
        description := "wallet transfer"
        effects := ["bank: -3000 JPY", "wallet: +3000 JPY"] }

inductive Surface where
  | list
  | detail
  deriving Repr, DecidableEq, BEq

structure State where
  surface : Surface := .list
  selected : Fin 5 := ⟨0, by decide⟩
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

structure Step where
  state : State
  quit : Bool := false
  deriving Repr, DecidableEq

def initialState : State := {}

def boundaryNotice : String :=
  "No more synthetic records in this bounded review."

def movePrevious (state : State) : State :=
  if h : state.selected.val = 0 then
    { state with notice := boundaryNotice }
  else
    { state with
      selected := ⟨state.selected.val - 1, by omega⟩
      notice := ""
    }

def moveNext (state : State) : State :=
  if h : state.selected.val + 1 < 5 then
    { state with
      selected := ⟨state.selected.val + 1, h⟩
      notice := ""
    }
  else
    { state with notice := boundaryNotice }

def update (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .up =>
      if state.surface == .list then { state := movePrevious state } else { state }
  | .down =>
      if state.surface == .list then { state := moveNext state } else { state }
  | .enter =>
      if state.surface == .list then
        { state := { state with surface := .detail, notice := "" } }
      else
        { state }
  | .back =>
      if state.surface == .detail then
        { state := { state with surface := .list, notice := "" } }
      else
        { state }
  | .other => { state }

theorem selection_bounds (state : State) : state.selected.val < 5 :=
  state.selected.isLt

theorem enter_preserves_selection (state : State) :
    (update state .enter).state.selected = state.selected := by
  simp [update]

theorem back_preserves_selection (state : State) :
    (update state .back).state.selected = state.selected := by
  simp [update]

theorem event_determinism (state : State) (event : Event) (left right : Step)
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

def reviewRow (state : State) (index : Fin 5) : Widget :=
  let item := reviewItem index
  let selected := state.selected = index
  let marker := if selected then "▶ " else "  "
  let text := marker ++ item.date ++ "  " ++ item.description ++ "  [" ++ item.eventId ++ "]"
  .row [span text (if selected then .selected else .normal)]

def listView (state : State) : Widget :=
  .column <|
    [ plainLine "LOAM UI Prototype 05  [SYNTHETIC / NO READS / NO WRITES]"
    , mutedLine "Second pressure test: Recent Actual vertical list/detail"
    , blankLine
    , plainLine "Week through 2026-09-06  (occurrence dates, not entry time)"
    , mutedLine "Date unknown (current): 0"
    , blankLine
    ] ++
    (List.finRange 5).map (reviewRow state) ++
    [ blankLine
    , mutedLine "↑/↓ Select    Enter Detail    q Quit"
    , mutedLine state.notice
    ]

def detailView (state : State) : Widget :=
  let item := reviewItem state.selected
  .column <|
    [ plainLine "Recent Actual detail  [SYNTHETIC]"
    , blankLine
    , plainLine (item.date ++ "  " ++ item.description ++ "  [" ++ item.eventId ++ "]")
    , blankLine
    ] ++
    item.effects.map (fun effect => plainLine ("    " ++ effect)) ++
    [ blankLine
    , mutedLine "Selection is preserved when returning to the review list."
    , mutedLine "b Back    q Quit"
    ]

def view (state : State) : Widget :=
  match state.surface with
  | .list => listView state
  | .detail => detailView state

def screenFor (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view state)

end Loam.Prototype.VerifiedTui05.Main
