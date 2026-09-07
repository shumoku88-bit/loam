import Loam.CapacityReview
import Loam.ActualReview
import Loam.Tui.Kernel
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.Capacity

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Read-only Capacity workspace

This surface consumes the shared all-retained `CapacityReview` answer. It does
not choose a cycle, infer a time window, classify operation kinds, or publish
Capacity movements.
-/

structure State where
  snapshot : Loam.CapacityReview.Snapshot
  selected : Option (Fin snapshot.rows.length)
  notice : String := ""

inductive Event where
  | up
  | down
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Step where
  | stay (state : State)
  | back


def initial (snapshot : Loam.CapacityReview.Snapshot) : State :=
  let selected : Option (Fin snapshot.rows.length) :=
    if h : 0 < snapshot.rows.length then some ⟨0, h⟩ else none
  { snapshot := snapshot, selected := selected }


def movePrevious (state : State) : State :=
  match state.selected with
  | none => { state with notice := "No remembered Capacity purpose is available." }
  | some index =>
      if h : index.val = 0 then
        { state with notice := "No previous Capacity row." }
      else
        { state with
            selected := some ⟨index.val - 1, by omega⟩
            notice := "" }


def moveNext (state : State) : State :=
  match state.selected with
  | none => { state with notice := "No remembered Capacity purpose is available." }
  | some index =>
      if h : index.val + 1 < state.snapshot.rows.length then
        { state with selected := some ⟨index.val + 1, h⟩, notice := "" }
      else
        { state with notice := "No next Capacity row." }


def update (state : State) (event : Event) : Step :=
  match event with
  | .back => .back
  | .up => .stay (movePrevious state)
  | .down => .stay (moveNext state)
  | .other => .stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []


def windowSize : Nat := 12


def windowStart (state : State) : Nat :=
  match state.selected with
  | none => 0
  | some index =>
      if index.val < windowSize then 0
      else index.val + 1 - windowSize


def visibleRows (state : State) : List (Nat × Loam.CapacityReview.Row) :=
  let start := windowStart state
  (List.range windowSize).filterMap fun offset =>
    let index := start + offset
    match state.snapshot.rows[index]? with
    | none => none
    | some row => some (index, row)

private def rowLine
    (state : State) (index : Nat) (row : Loam.CapacityReview.Row) : Widget :=
  let selected :=
    match state.selected with
    | none => false
    | some current => current.val == index
  let marker := if selected then "▶ " else "  "
  let purpose := Loam.ActualReview.shortText 44 row.purpose.token
  .row
    [ span
        (marker ++ purpose ++ ": " ++ toString row.entitlement.quanta ++ " jpy")
        (if selected then .selected else .normal)
    ]

/-- Render the current all-retained JPY entitlement projection only. -/
def view (state : State) : Widget :=
  if state.snapshot.rows.isEmpty then
    .column
      [ line "Capacity / Current"
      , muted "Home > Capacity"
      , muted "0 remembered purposes"
      , blank
      , line "No spending-purpose capacity is retained."
      , blank
      , muted "All-retained view; no cycle or time window is inferred."
      , muted "b home   q quit"
      ]
  else
    .column <|
      [ line "Capacity / Current"
      , muted "Home > Capacity"
      , muted (toString state.snapshot.rows.length ++ " remembered purpose(s)")
      , blank
      ] ++
      ((visibleRows state).map fun row => rowLine state row.1 row.2) ++
      [ blank
      , muted "Entitlement is derived from all retained JPY Capacity movements."
      , muted "Order shown is first retained appearance, not priority."
      , muted "No cycle, period, or selected-day meaning is inferred here."
      , muted "Read-only: Capacity publication remains outside this surface."
      , muted "↑/↓ select/scroll   b home   q quit"
      , muted state.notice
      ]

end Loam.Tui.Capacity
