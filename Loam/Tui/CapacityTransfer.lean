import Loam.CapacityPublisher
import Loam.CapacityReview
import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.CapacityTransfer

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Capacity transfer editor

This is presentation-only state for one practical Capacity movement. It edits the
same four pieces of intent used by the shared publisher: source endpoint,
destination endpoint, effective day, and positive JPY amount.

`unallocated` remains an allocation boundary, not a finite balance. Purpose
entitlement shown in preview is advisory current all-retained evidence only; the
shared publisher re-reads authority and effective evidence under ownership.
-/

structure Form where
  source : String := "unallocated"
  destination : String := ""
  effectiveOn : String
  amount : String := ""
  focus : Nat := 0
  deriving Repr, DecidableEq

inductive Mode where
  | editing
  | preview (draft : Loam.CapacityPublisher.Draft) (choice : Fin 3)

structure State where
  snapshot : Loam.CapacityReview.Snapshot
  form : Form
  mode : Mode := .editing
  notice : String := ""

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.CapacityPublisher.Draft := none

private def knownEndpoints (snapshot : Loam.CapacityReview.Snapshot) : List String :=
  ("unallocated" :: snapshot.rows.map (fun row => row.purpose.token)).eraseDups

private def currentPurposeQuanta
    (rows : List Loam.CapacityReview.Row) (purpose : PurposeId) : Int :=
  match rows with
  | [] => 0
  | row :: rest =>
      if row.purpose = purpose then row.entitlement.quanta
      else currentPurposeQuanta rest purpose

/-- Seed a transfer from the home-selected day and, when available, selected Purpose. -/
def initial
    (snapshot : Loam.CapacityReview.Snapshot)
    (effectiveOn : String)
    (selected : Option PurposeId := none) : State :=
  { snapshot := snapshot
    form := {
      source := "unallocated"
      destination := selected.map (fun purpose => purpose.token) |>.getD ""
      effectiveOn := effectiveOn
    }
  }

private def focusCount : Nat := 6
private def firstAction : Nat := 4

private def moveFocus (form : Form) (back : Bool) : Form :=
  let next := if back then (form.focus + focusCount - 1) % focusCount
              else (form.focus + 1) % focusCount
  { form with focus := next }

private def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus = 0 then { form with source := edit form.source }
  else if form.focus = 1 then { form with destination := edit form.destination }
  else if form.focus = 2 then { form with effectiveOn := edit form.effectiveOn }
  else if form.focus = 3 then { form with amount := edit form.amount }
  else form

private def activeEndpoint? (form : Form) : Option String :=
  if form.focus = 0 then some form.source
  else if form.focus = 1 then some form.destination
  else none

private def candidate? (state : State) : Option String := do
  let entered ← activeEndpoint? state.form
  (knownEndpoints state.snapshot).find? fun token =>
    entered.isPrefixOf token && token != entered

private def acceptCandidate (state : State) : State :=
  match candidate? state with
  | none => state
  | some token =>
      { state with form := editActive state.form (fun _ => token), notice := "" }

/--
Build one advisory typed draft. Shape checks delegate to the shared publisher;
visible source Entitlement is checked locally only to avoid an obviously stale
preview. Publication repeats the current-source check under ownership.
-/
def draft? (state : State) : Except String Loam.CapacityPublisher.Draft := do
  let some source := Loam.CapacityPublisher.parseCoordinate? state.form.source
    | throw "Capacity From must be unallocated or a valid Purpose token."
  let some destination := Loam.CapacityPublisher.parseCoordinate? state.form.destination
    | throw "Capacity To must be unallocated or a valid Purpose token."
  let some quanta := state.form.amount.toInt?
    | throw "Capacity amount must be a positive integer JPY quantity."
  let draft : Loam.CapacityPublisher.Draft := {
    effectiveOn := state.form.effectiveOn
    source := source
    destination := destination
    quanta := quanta
  }
  Loam.CapacityPublisher.validateDraft draft
  match source with
  | .unallocated => pure ()
  | .purpose purpose =>
      let available := currentPurposeQuanta state.snapshot.rows purpose
      if quanta > available then
        throw "Visible current source Entitlement is insufficient; reload Capacity before publishing."
  pure draft

private def preview (state : State) : State :=
  match draft? state with
  | .error message => { state with notice := message }
  | .ok draft =>
      { state with mode := .preview draft ⟨0, by omega⟩, notice := "" }

/-- Local transfer transition. Durable intent is emitted only from Preview/Publish. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | _ =>
      match state.mode with
      | .preview draft choice =>
          match key with
          | .tab | .right =>
              { state := { state with mode := .preview draft
                  ⟨(choice.val + 1) % 3, Nat.mod_lt _ (by omega)⟩ } }
          | .shiftTab | .left =>
              { state := { state with mode := .preview draft
                  ⟨(choice.val + 2) % 3, Nat.mod_lt _ (by omega)⟩ } }
          | .enter =>
              if choice.val = 0 then { state, publish := some draft }
              else if choice.val = 1 then { state := { state with mode := .editing } }
              else { state, cancel := true }
          | _ => { state }
      | .editing =>
          match key with
          | .tab => { state := { state with form := moveFocus state.form false } }
          | .shiftTab => { state := { state with form := moveFocus state.form true } }
          | .backspace =>
              { state := { state with
                  form := editActive state.form
                    (fun text => String.ofList text.toList.dropLast)
                  notice := "" } }
          | .input char =>
              { state := { state with
                  form := editActive state.form (fun text => text.push char)
                  notice := "" } }
          | .right => { state := acceptCandidate state }
          | .enter =>
              let focus := state.form.focus
              if focus + 1 = firstAction then
                { state := preview state }
              else if focus < firstAction then
                { state := { state with form := moveFocus state.form false } }
              else if focus = firstAction then
                { state := preview state }
              else
                { state, cancel := true }
          | _ => { state }

private def line (text : String) : Widget := .row [span text]
private def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus = index then .selected else .normal)]

private def impactLine
    (snapshot : Loam.CapacityReview.Snapshot)
    (coordinate : CapacityCoordinate)
    (quanta : Int)
    (source : Bool) : String :=
  match coordinate with
  | .unallocated =>
      "unallocated: allocation boundary; no finite Entitlement is asserted"
  | .purpose purpose =>
      let current := currentPurposeQuanta snapshot.rows purpose
      let after := if source then current - quanta else current + quanta
      purpose.token ++ ": " ++ toString current ++ " -> " ++ toString after ++ " jpy"

/-- Render one HRA-shaped transfer without importing Envelope identity or backing semantics. -/
def view (state : State) : Widget :=
  match state.mode with
  | .editing =>
      let form := state.form
      .column
        [ line "Capacity / Transfer / Edit"
        , field form 0 "From" form.source
        , field form 1 "To" form.destination
        , field form 2 "Effective" form.effectiveOn
        , field form 3 "Amount JPY" form.amount
        , .row
            [ span "[Preview] " (if form.focus = 4 then .selected else .normal)
            , span "[Cancel]" (if form.focus = 5 then .selected else .normal)
            ]
        , line ("Candidate: " ++ (candidate? state).getD "")
        , line "Endpoints are unallocated or Purpose tokens; new Purpose tokens need no registry."
        , line "unallocated is an allocation boundary, not money available to allocate."
        , line "Tab / Shift-Tab focus   Enter next/preview/action   Right accept candidate"
        , line "Esc cancel   Backspace delete"
        , line state.notice
        ]
  | .preview draft choice =>
      .column
        [ line "Capacity / Transfer / Preview"
        , line ("From: " ++ Loam.CapacityPublisher.coordinateToken draft.source)
        , line ("To: " ++ Loam.CapacityPublisher.coordinateToken draft.destination)
        , line ("Effective: " ++ draft.effectiveOn)
        , line ("Amount: " ++ toString draft.quanta ++ " jpy")
        , line "Current all-retained Entitlement -> after this movement:"
        , line ("  " ++ impactLine state.snapshot draft.source draft.quanta true)
        , line ("  " ++ impactLine state.snapshot draft.destination draft.quanta false)
        , line "Publication re-reads current Capacity and effective evidence under ownership."
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice.val = index then .selected else .normal))
        , line "Tab / Shift-Tab select   Enter confirm   Esc cancel"
        , line state.notice
        ]

end Loam.Tui.CapacityTransfer
