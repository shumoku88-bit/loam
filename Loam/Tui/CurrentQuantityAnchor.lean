import Loam.CurrentQuantityAnchor
import Loam.Persistence.TokenSyntax
import Loam.Tui.CyclicIndex
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.CurrentQuantityAnchor

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Current quantity observation editor

This is presentation-only state for one complete current reconciliation image.
It collects one or more `Locus × Measure × observed Quantity` rows and emits the
whole image at once. It does not derive the Event root cut, merge with a prior
anchor image, decide support-family precedence, or write persistence directly.
-/

structure Form where
  locus : String := ""
  measure : String := "jpy"
  quantity : String := ""
  focus : Nat := 0
  deriving Repr, DecidableEq

inductive Mode where
  | editing
  | preview (choice : Nat)
  deriving Repr, DecidableEq, BEq

structure State where
  assertions : List Loam.CurrentQuantityAnchor.Assertion := []
  form : Form := {}
  mode : Mode := .editing
  notice : String := ""
  deriving Repr, DecidableEq

structure Step where
  state : State
  cancel : Bool := false
  publish : Option (List Loam.CurrentQuantityAnchor.Assertion) := none


def initial : State := {}

private def focusCount : Nat := 6
private def firstAction : Nat := 3

private def moveFocus (form : Form) (back : Bool) : Form :=
  let next :=
    if back then Loam.Tui.CyclicIndex.backward focusCount form.focus
    else Loam.Tui.CyclicIndex.forward focusCount form.focus
  { form with focus := next }

private def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus = 0 then { form with locus := edit form.locus }
  else if form.focus = 1 then { form with measure := edit form.measure }
  else if form.focus = 2 then { form with quantity := edit form.quantity }
  else form

private def dropLast (text : String) : String :=
  String.ofList text.toList.dropLast

/-- Parse only one human-entered row. Reconciliation laws remain below this adapter. -/
def currentAssertion? (state : State) : Except String Loam.CurrentQuantityAnchor.Assertion := do
  if !Loam.Persistence.validToken state.form.locus then
    throw "Locus must be a nonempty single-line token."
  if !Loam.Persistence.validToken state.form.measure then
    throw "Measure must be a nonempty single-line token."
  let some quanta := state.form.quantity.toInt?
    | throw "Observed quantity must be an integer."
  return {
    coordinate := ⟨⟨state.form.locus⟩, ⟨state.form.measure⟩⟩
    quantity := Quantity.ofQuanta quanta
  }

private def addCurrent (state : State) : State :=
  match currentAssertion? state with
  | .error message => { state with notice := message }
  | .ok assertion =>
      { state with
          assertions := state.assertions ++ [assertion]
          form := { measure := state.form.measure }
          notice := "" }

private def enterPreview (state : State) : State :=
  if state.assertions.isEmpty then
    { state with notice := "Add at least one observed quantity before preview." }
  else
    { state with mode := .preview 0, notice := "" }

/--
Pure local interaction. Duplicate coordinates are deliberately not rejected here;
the shared publisher owns uniqueness together with every other anchor law.
-/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | _ =>
      match state.mode with
      | .preview choice =>
          match key with
          | .input 'e' | .input 'E' =>
              { state := { state with mode := .editing, form := { state.form with focus := 0 }, notice := "" } }
          | .tab | .right =>
              { state := { state with mode := .preview (Loam.Tui.CyclicIndex.forward 3 choice) } }
          | .shiftTab | .left =>
              { state := { state with mode := .preview (Loam.Tui.CyclicIndex.backward 3 choice) } }
          | .enter =>
              if choice = 0 then
                { state, publish := some state.assertions }
              else if choice = 1 then
                { state := { state with mode := .editing, form := { state.form with focus := 0 }, notice := "" } }
              else
                { state, cancel := true }
          | .input 'q' | .input 'Q' => { state, cancel := true }
          | _ => { state }
      | .editing =>
          match key with
          | .tab => { state := { state with form := moveFocus state.form false } }
          | .shiftTab => { state := { state with form := moveFocus state.form true } }
          | .backspace =>
              { state := { state with
                  form := editActive state.form dropLast
                  notice := "" } }
          | .input char =>
              { state := { state with
                  form := editActive state.form (fun text => text.push char)
                  notice := "" } }
          | .enter =>
              let focus := state.form.focus
              if focus < 2 then
                { state := { state with form := moveFocus state.form false } }
              else if focus = 2 || focus = firstAction then
                { state := addCurrent state }
              else if focus = 4 then
                { state := enterPreview state }
              else
                { state, cancel := true }
          | _ => { state }

/-- Keep a refused publication visible without changing the proposed image. -/
def withPublishError (state : State) (message : String) : State :=
  { state with notice := message }

private def line (text : String) : Widget := .row [span text]

private def muted (text : String) : Widget := .row [span text .muted]

private def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus = index then .selected else .normal)]

private def assertionLine (index : Nat) (assertion : Loam.CurrentQuantityAnchor.Assertion) : Widget :=
  line
    ("  " ++ toString (index + 1) ++ ". " ++ assertion.coordinate.locus.token ++
      "  " ++ toString assertion.quantity.quanta ++ " " ++ assertion.coordinate.measure.token)

private def assertionLines (assertions : List Loam.CurrentQuantityAnchor.Assertion) : List Widget :=
  assertions.zipIdx.map fun (assertion, index) => assertionLine index assertion

private def actionRow (form : Form) : Widget :=
  .row [
    span "[Add] " (if form.focus = 3 then .selected else .normal),
    span "[Preview] " (if form.focus = 4 then .selected else .normal),
    span "[Cancel]" (if form.focus = 5 then .selected else .normal)
  ]

/-- Render a thin observation collector; all reconciliation semantics remain downstream. -/
def view (state : State) : Widget :=
  match state.mode with
  | .editing =>
      .column <|
        [ line "Current Quantity / Observe"
        , muted "Build one complete set of quantities observed together now."
        , line ""
        ] ++
        (if state.assertions.isEmpty then [muted "  (no observations added yet)"]
         else assertionLines state.assertions) ++
        [ line ""
        , field state.form 0 "Locus" state.form.locus
        , field state.form 1 "Measure" state.form.measure
        , field state.form 2 "Observed quantity" state.form.quantity
        , actionRow state.form
        , muted "Enter moves fields; Enter on Quantity/Add appends one row."
        , muted "Tab / Shift-Tab focus   Backspace edit   Esc cancel"
        , line state.notice
        ]
  | .preview choice =>
      .column <|
        [ line "Current Quantity / Preview"
        , muted "Complete replacement image:"
        , line ""
        ] ++
        assertionLines state.assertions ++
        [ line ""
        , muted "All rows must describe quantities observed together at this reconciliation boundary."
        , muted "Publish replaces the current anchor image; it does not merge with an older image."
        , muted "The shared publisher derives the Event root cut and enforces support separation."
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice = index then .selected else .normal))
        , muted "Tab / Shift-Tab select   Enter confirm   e edit   Esc/q cancel"
        , line state.notice
        ]

end Loam.Tui.CurrentQuantityAnchor
