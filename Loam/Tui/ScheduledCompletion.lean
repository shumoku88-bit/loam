import Loam.ScheduledTerminalPublisher
import Loam.Tui.Main
import Loam.Tui.Record
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.ScheduledCompletion

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected Scheduled completion editor

Completion reuses the production signed-posting Record mechanics. The expected
Scheduled movement is only an editable presentation seed. The Actual date starts
from the current household observation day, and every field may be changed before
preview. Publication authority remains `ScheduledTerminalPublisher`, which
re-reads current Scheduled and Movement evidence under ownership.
-/
structure State where
  target : ScheduledId
  expectedOn : String
  editor : Loam.Tui.Record.State

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ScheduledTerminalPublisher.CompletionDraft := none

private def rowsFromScheduled
    (record : Loam.Tui.Main.ScheduledRecord) : Array Loam.Tui.Record.Row :=
  (record.movement.changes.map fun change =>
    ({ locus := change.coordinate.token,
       amount := toString change.quantity.quanta } : Loam.Tui.Record.Row)).toArray

/--
Seed an editable Actual draft from one visible current-open Scheduled occurrence.

JPY and the six-row bound are editor representability checks only. They do not
admit completion. Expected values remain editable conveniences, never authority.
-/
def initial?
    (record : Loam.Tui.Main.ScheduledRecord)
    (actualDate : String) : Except String State := do
  if record.measure != ⟨"jpy"⟩ then
    throw "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY completion editor."
  let rows := rowsFromScheduled record
  if rows.size < 2 then
    throw "This Scheduled occurrence is outside the practical balanced-Movement completion editor."
  if rows.size > 6 then
    throw "This Scheduled occurrence has more than six postings; this completion editor will not truncate it."
  let form : Loam.Tui.Record.Form := {
    date := actualDate
    description := ""
    rows := rows
    focus := ⟨0, by omega⟩
  }
  pure {
    target := record.id
    expectedOn := record.scheduledOn
    editor := { form := form }
  }

private def publisherDraft
    (target : ScheduledId)
    (movement : Loam.MovementAdmission.Draft) :
    Loam.ScheduledTerminalPublisher.CompletionDraft :=
  { scheduled := target, movement := movement }

/--
Reuse Record editing, candidate and preview mechanics. The only emitted durable
intent binds the independently built Actual draft to the selected Scheduled id.
-/
def update
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  let step := Loam.Tui.Record.update world known state.editor key
  let next := { state with editor := step.state }
  if step.cancel then
    { state := next, cancel := true }
  else
    { state := next, publish := step.publish.map (publisherDraft state.target) }

/-- Failed publication returns to editable Actual evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with editor := { state.editor with mode := .editing, notice := message } }

private def positiveTotal (draft : Loam.MovementAdmission.Draft) : Int :=
  draft.effects.foldl
    (fun total effect => if effect.quantity.quanta > 0 then total + effect.quantity.quanta else total)
    0

/-- HRA-shaped completion interaction: identify Plan/Scheduled, then edit Actual. -/
def view (known : List String) (state : State) : Widget :=
  match state.editor.mode with
  | .editing =>
      let form := state.editor.form
      let activeRow := (form.focus.val - 2) / 2
      let start := if activeRow < form.rows.size then activeRow - 3 else form.rows.size - 6
      let rowLines := ((List.range form.rows.size).drop start |>.take 6).flatMap fun index =>
        let row := form.rows[index]!
        [ Loam.Tui.Record.field form (2 + index * 2)
            ("Posting " ++ toString (index + 1)) row.locus
        , Loam.Tui.Record.field form (3 + index * 2) "  JPY" row.amount
        ]
      let actions := ["Add posting", "Drop last row", "Preview", "Cancel"]
      .column <|
        [ Loam.Tui.Record.line "Scheduled / Complete / Edit Actual"
        , Loam.Tui.Record.line
            ("Target: " ++ state.target.token ++ "   Expected: " ++ state.expectedOn)
        , Loam.Tui.Record.field form 0 "Actual date" form.date
        , Loam.Tui.Record.field form 1 "Description" form.description
        ] ++ rowLines ++
        [ .row ((actions.zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if form.focus.val = 2 + form.rows.size * 2 + index then .selected else .normal))
        , Loam.Tui.Record.line
            ("Candidate: " ++ (Loam.Tui.Record.candidate? known form).getD "")
        , Loam.Tui.Record.line
            "Expected postings are editable defaults; Actual evidence is independent."
        , Loam.Tui.Record.line
            "Tab / Shift-Tab focus   Enter next/preview/action   Right accept candidate"
        , Loam.Tui.Record.line "Esc cancel   Backspace delete"
        , Loam.Tui.Record.line state.editor.notice
        ]
  | .preview draft choice =>
      .column <|
        [ Loam.Tui.Record.line "Scheduled / Complete / Preview Actual"
        , Loam.Tui.Record.line
            ("Target: " ++ state.target.token ++ "   Expected: " ++ state.expectedOn)
        , Loam.Tui.Record.line ("Actual date: " ++ draft.validOn)
        , Loam.Tui.Record.line (draft.description.getD "(no description)")
        ] ++
        (draft.effects.take 12).map (fun effect =>
          Loam.Tui.Record.line
            (effect.locus.token ++ "  " ++ toString effect.quantity.quanta ++ " jpy")) ++
        [ Loam.Tui.Record.line
            ("Actual positive total: " ++ toString (positiveTotal draft) ++ " jpy")
        , Loam.Tui.Record.line
            "Publish appends an Actual Event plus explicit Scheduled completion relation."
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice.val = index then .selected else .normal))
        , Loam.Tui.Record.line "Tab / Shift-Tab select   Enter confirm   Esc cancel"
        , Loam.Tui.Record.line state.editor.notice
        ]

end Loam.Tui.ScheduledCompletion
