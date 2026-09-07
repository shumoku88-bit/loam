import Loam.CorrectionPublisher
import Loam.Tui.Main
import Loam.Tui.Record
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.Correction

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/--
Correction reuses the production signed-posting form mechanics, but the selected
Actual date is display-only. Description and postings are presentation-prefilled
from the selected current Actual; publication authority remains
`CorrectionPublisher` and re-reads canonical evidence.
-/
structure State where
  target : EventId
  editor : Loam.Tui.Record.State

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.CorrectionPublisher.Draft := none

private def rowsFromRecord (record : Loam.Tui.Main.ReviewRecord) : Array Loam.Tui.Record.Row :=
  (record.event.effects.map fun effect =>
    ({ locus := effect.locus.token, amount := toString effect.quantity.quanta } : Loam.Tui.Record.Row)).toArray

/--
Seed one replacement editor from visible current Actual evidence.

The six-row limit is a presentation limit inherited from the production Record
editor, not a publisher or Core law. Larger retained Events remain readable and
are refused here rather than truncated.
-/
def initial? (record : Loam.Tui.Main.ReviewRecord) : Except String State := do
  let date ←
    match record.date with
    | some date => pure date
    | none => throw "This Actual has no current occurrence date and cannot use the day correction editor."
  let rows := rowsFromRecord record
  if rows.size < 2 then
    throw "This Actual is outside the practical balanced-Movement correction editor."
  if rows.size > 6 then
    throw "This Actual has more than six postings; this correction editor will not truncate it."
  let form : Loam.Tui.Record.Form := {
    date := date
    description := record.description
    rows := rows
    focus := ⟨1, by omega⟩
  }
  pure { target := record.event.id, editor := { form := form } }

/-- Date is a fixed coordinate for this editor, so cycling focus skips field 0. -/
private def skipDateFocus
    (editor : Loam.Tui.Record.State) (back : Bool) : Loam.Tui.Record.State :=
  if editor.form.focus.val = 0 then
    { editor with form := Loam.Tui.Record.moveFocus editor.form back }
  else
    editor

private def publisherDraft
    (target : EventId) (draft : Loam.MovementAdmission.Draft) : Loam.CorrectionPublisher.Draft :=
  { target := target, effects := draft.effects, description := draft.description }

/--
Reuse Record's text/candidate/posting/preview mechanics while suppressing date
editing. The emitted intent contains no editable date; the shared publisher owns
replacement admission and fresh canonical re-checks.
-/
def update
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  let editor := skipDateFocus state.editor false
  let step := Loam.Tui.Record.update world known editor key
  let back := key = .shiftTab
  let nextEditor := skipDateFocus step.state back
  let next := { state with editor := nextEditor }
  if step.cancel then
    { state := next, cancel := true }
  else
    { state := next, publish := step.publish.map (publisherDraft state.target) }

/-- Return a failed publication attempt to editable replacement evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with editor := { state.editor with mode := .editing, notice := message } }

private def replacementTotal (draft : Loam.MovementAdmission.Draft) : Int :=
  draft.effects.foldl
    (fun total effect => if effect.quantity.quanta > 0 then total + effect.quantity.quanta else total)
    0

/-- User-facing correction editor. Date remains visible but never focusable/editable. -/
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
        [ Loam.Tui.Record.line "Correction / Edit"
        , Loam.Tui.Record.line ("Target: " ++ state.target.token)
        , Loam.Tui.Record.line ("Date (kept): " ++ form.date)
        , Loam.Tui.Record.field form 1 "Description" form.description
        ] ++ rowLines ++
        [ .row ((actions.zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if form.focus.val = 2 + form.rows.size * 2 + index then .selected else .normal))
        , Loam.Tui.Record.line
            ("Candidate: " ++ (Loam.Tui.Record.candidate? known form).getD "")
        , Loam.Tui.Record.line
            "Posting JPY is signed; negative and positive rows may appear in any order."
        , Loam.Tui.Record.line
            "Tab / Shift-Tab focus   Enter next/final amount preview/action   Right accept candidate"
        , Loam.Tui.Record.line "Esc cancel   Date is retained from the selected Actual"
        , Loam.Tui.Record.line state.editor.notice
        ]
  | .preview draft choice =>
      .column <|
        [ Loam.Tui.Record.line "Correction / Preview"
        , Loam.Tui.Record.line ("Target remains retained: " ++ state.target.token)
        , Loam.Tui.Record.line ("Date kept: " ++ draft.validOn)
        , Loam.Tui.Record.line (draft.description.getD "(no description)")
        ] ++
        (draft.effects.take 12).map (fun effect =>
          Loam.Tui.Record.line
            (effect.locus.token ++ "  " ++ toString effect.quantity.quanta ++ " jpy")) ++
        [ Loam.Tui.Record.line
            ("Replacement positive total: " ++ toString (replacementTotal draft) ++ " jpy")
        , Loam.Tui.Record.line
            "Publish appends an explicit Correction and replacement Event; it does not rewrite the original."
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice.val = index then .selected else .normal))
        , Loam.Tui.Record.line "Tab / Shift-Tab select   Enter confirm   Esc cancel"
        , Loam.Tui.Record.line state.editor.notice
        ]

end Loam.Tui.Correction
