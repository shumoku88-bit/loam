import Loam.BudgetWindowReview
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.Reports

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Reports / Budget Window

This local interaction state edits only explicit query coordinates. It does not
choose a cycle, month, selected-day window, or persisted report identity.
Canonical evidence loading and budget semantics remain outside this module in
`BudgetWindowReview` / Application.
-/

structure Form where
  start : String := ""
  endExclusive : String := ""
  focus : Fin 3 := ⟨0, by decide⟩
  deriving Repr, DecidableEq

structure Query where
  start : String
  endExclusive : String
  deriving Repr, DecidableEq

structure State where
  form : Form := {}
  snapshot : Option Loam.BudgetWindowReview.Snapshot := none
  notice : String := ""
  deriving Repr, DecidableEq

structure Step where
  state : State
  back : Bool := false
  query : Option Query := none


def initial : State := {}


def withSnapshot
    (state : State) (snapshot : Loam.BudgetWindowReview.Snapshot) : State :=
  { state with snapshot := some snapshot, notice := "" }


def withError (state : State) (message : String) : State :=
  { state with notice := message }


def moveFocus (form : Form) (back : Bool) : Form :=
  let next := if back then (form.focus.val + 2) % 3 else (form.focus.val + 1) % 3
  { form with focus := ⟨next, Nat.mod_lt _ (by decide)⟩ }


def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus.val = 0 then { form with start := edit form.start }
  else if form.focus.val = 1 then { form with endExclusive := edit form.endExclusive }
  else form


def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, back := true }
  | .tab => { state := { state with form := moveFocus state.form false, notice := "" } }
  | .shiftTab => { state := { state with form := moveFocus state.form true, notice := "" } }
  | .backspace =>
      { state := { state with
          form := editActive state.form (fun text => String.ofList text.toList.dropLast)
          notice := "" } }
  | .input char =>
      { state := { state with
          form := editActive state.form (fun text => text.push char)
          notice := "" } }
  | .enter =>
      if state.form.focus.val < 2 then
        { state := { state with form := moveFocus state.form false, notice := "" } }
      else
        { state, query := some {
            start := state.form.start
            endExclusive := state.form.endExclusive
          } }
  | _ => { state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def field (state : State) (index : Nat) (label text : String) : Widget :=
  .row
    [ span (label ++ ": ")
    , span (if text.isEmpty then "_" else text)
        (if state.form.focus.val = index then .selected else .normal)
    ]

private def rowLine (row : Loam.BudgetWindowReview.Row) : Widget :=
  line
    ("- " ++ row.purpose.token ++
      ": entitlement " ++ toString row.entitlement.quanta ++
      " | consumption " ++ toString row.consumption.quanta ++
      " | remaining " ++ toString row.remaining.quanta ++ " jpy")

private def resultLines (state : State) : List Widget :=
  match state.snapshot with
  | none => [muted "No explicit window has been run yet."]
  | some snapshot =>
      [ line ("Budget window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
      , muted (toString snapshot.rows.length ++ " remembered purpose(s)")
      ] ++
      (snapshot.rows.take 10).map rowLine ++
      [ muted "Remaining is derived exactly as Entitlement - Consumption." ]

/-- Render one explicit-coordinate Budget Window report editor/result surface. -/
def view (state : State) : Widget :=
  .column <|
    [ line "Reports / Budget Window"
    , muted "Home > Reports > Budget Window"
    , blank
    , field state 0 "Start" state.form.start
    , field state 1 "End (exclusive)" state.form.endExclusive
    , .row [span "[Run]" (if state.form.focus.val = 2 then .selected else .normal)]
    , muted "Window is explicit [start, end); no cycle, month, or selected day is inferred."
    , blank
    ] ++
    resultLines state ++
    [ blank
    , muted "Tab / Shift-Tab focus   Enter next/run   Backspace delete"
    , muted "b / Esc home   q quit"
    , line state.notice
    ]

end Loam.Tui.Reports
