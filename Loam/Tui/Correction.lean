import Loam.Publisher.CorrectionPublisher
import Loam.Presentation.MeasurePresentation
import Loam.Application.PracticalMovement
import Loam.Tui.Main
import Loam.Tui.Record
import Lean.Elab.Tactic.Omega
import Loam.Tui.Layout
import Loam.Tui.Scroll

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
  /-- Selected read snapshot for before/after display only; the publisher re-reads authority. -/
  before : Loam.Tui.Main.ReviewRecord
  editor : Loam.Tui.Record.State

structure Step where
  state : State
  cancel : Bool := false
  enableUnresolved : Bool := false
  publish : Option Loam.CorrectionPublisher.Draft := none

private def rowsFromRecord
    (metadata : List Loam.MeasurePresentation.Metadata)
    (record : Loam.Tui.Main.ReviewRecord) : Array Loam.Tui.Record.Row :=
  (record.event.effects.map fun effect =>
    ({ locus := effect.locus.token,
       amount := Loam.MeasurePresentation.formatQuanta
         metadata effect.measure effect.quantity.quanta } : Loam.Tui.Record.Row)).toArray

/--
Seed one replacement editor from visible current Actual evidence.

The single-Measure and six-row checks are presentation representability checks
only. They do not authorize correction publication; the shared publisher still
re-reads current canonical evidence and applies the qualified correction
entrance.
-/
def initialWithPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (record : Loam.Tui.Main.ReviewRecord) : Except String State := do
  let date ←
    match record.date with
    | some date => pure date
    | none => throw "This Actual has no current occurrence date and cannot use the day correction editor."
  let movement ←
    match Loam.PracticalMovement.ofSingleMeasureEffects? record.event.effects with
    | some movement => pure movement
    | none =>
        throw "This Actual is outside the practical balanced single-Measure correction editor."
  let rows := rowsFromRecord metadata record
  if rows.size < 2 then
    throw "This Actual is outside the practical balanced-Movement correction editor."
  if rows.size > 6 then
    throw "This Actual has more than six postings; this correction editor will not truncate it."
  let form : Loam.Tui.Record.Form := {
    date := date
    description := record.description
    measure := movement.measure.token
    rows := rows
    focus := ⟨1, by omega⟩
  }
  pure {
    target := record.event.id
    before := record
    editor := { form := form, measurePresentation := metadata }
  }

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
  match key with
  | .ctrl 'o' =>
      { state := { state with editor := {
          state.editor with
          mode := .editing
          notice := "Original amount is not changed by the current Correction editor."
        } } }
  | _ =>
      let editor := skipDateFocus state.editor false
      let step := Loam.Tui.Record.update world known editor key
      let back := key = .shiftTab
      let nextEditor := skipDateFocus step.state back
      let next := { state with editor := nextEditor }
      if step.cancel then
        { state := next, cancel := true }
      else
        { state := next
          enableUnresolved := step.enableUnresolved
          publish := step.publish.bind fun intent =>
            match intent with
            | .movement draft => some (publisherDraft state.target draft)
            | .movementWithOriginalAmount _ _ => none }

/-- Return a failed publication attempt to editable replacement evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with editor := { state.editor with mode := .editing, notice := message } }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def previewLines (width : Nat) (state : State)
    (draft : Loam.MovementAdmission.Draft) : List Widget :=
  let wrapped := fun text => (Loam.Tui.Layout.wrapColumns width text).map line
  let metadata := fun text => (Loam.Tui.Layout.wrapColumns width text).map muted
  let effects := fun (items : List Effect) => items.flatMap fun effect =>
    wrapped ((if effect.quantity.quanta >= 0 then "+" else "") ++
      Loam.MeasurePresentation.formatGroupedQuanta state.editor.measurePresentation
        effect.measure effect.quantity.quanta ++ " " ++ effect.measure.token ++ "  " ++ effect.locus.token)
  let measure := (draft.effects.head?.map Effect.measure).getD ⟨"?"⟩
  metadata ("Target retained: " ++ state.target.token) ++ metadata ("Date kept: " ++ draft.validOn) ++
    [line "Before / selected snapshot"] ++ effects state.before.event.effects ++
    wrapped ("Description: " ++ state.before.description) ++ [.row []] ++
    [line "Replacement"] ++ effects draft.effects ++
    wrapped ("Description: " ++ draft.description.getD "(no description)") ++
    wrapped ("Replacement positive total: " ++
      Loam.MeasurePresentation.formatGroupedQuanta state.editor.measurePresentation
        measure (Effect.positiveQuantaTotal draft.effects) ++ " " ++ measure.token)

private def previewFooter (bounds : Bounds) (state : State) (choice : Fin 3) : List Widget :=
  let feedback := (Loam.Tui.Layout.wrapColumns (Loam.Tui.Layout.contentWidth bounds)
    state.editor.notice).map line
  (if feedback.isEmpty then [.row []] else feedback) ++
    [muted "Appends Correction + replacement Event.",
     muted "Original stays retained; date stays kept.",
     .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
       span ("[" ++ label ++ "] ") (if choice.val == index then .selected else .normal)),
     Loam.Tui.Layout.shortcutRow [("↑/↓", "review"), ("PgUp/Dn", "page"), ("Home/End", "edges")] " ",
     Loam.Tui.Layout.shortcutRow [("Tab", "action"), ("Enter", "confirm"), ("Esc", "cancel")] " "]

private def previewCapacity (bounds : Bounds) (state : State) (choice : Fin 3) : Nat :=
  Loam.Tui.Layout.footerBodyCapacity bounds (previewFooter bounds state choice).length - 3

def previewScrollLimit (bounds : Bounds) (state : State) : Nat :=
  match state.editor.mode with
  | .preview draft choice => Loam.Tui.Scroll.maxOffset
      (previewLines (Loam.Tui.Layout.contentWidth bounds - 2) state draft).length
      (previewCapacity bounds state choice)
  | _ => 0

/-- Clamp only presentation scrolling after resize; target and replacement inputs stay intact. -/
def normalizedForBounds (bounds : Bounds) (state : State) : State :=
  let offset := min state.editor.previewScroll (previewScrollLimit bounds state)
  { state with editor := { state.editor with previewScroll := offset } }

/-- Review keys never emit Correction or policy publication intents. -/
def scrollPreview (bounds : Bounds) (state : State) (key : Loam.Tui.Terminal.Key) : Option State :=
  match state.editor.mode with
  | .preview _ choice => do
      let limit := previewScrollLimit bounds state
      let current := min state.editor.previewScroll limit
      let page := max 1 (previewCapacity bounds state choice)
      let offset ← match key with
        | .up => some (current - 1)
        | .down => some (min limit (current + 1))
        | .pageUp => some (current - page)
        | .pageDown => some (min limit (current + page))
        | .home => some 0
        | .«end» => some limit
        | _ => none
      some { state with editor := { state.editor with previewScroll := offset } }
  | _ => none

/-- Correction shares input geometry with Record, but owns its before/after and retained-target meaning. -/
def view (bounds : Bounds) (known : List String) (rawState : State) : Widget :=
  let state := { rawState with editor := skipDateFocus rawState.editor false }
  match state.editor.mode with
  | .editing =>
      Loam.Tui.Record.editingView bounds state.editor "Correction / Edit"
        (some ("Target: " ++ state.target.token)) true false
  | .enableUnresolved =>
      Loam.Tui.Record.unresolvedEnableView bounds state.editor "cancel Correction"
  | .originalAmount _ =>
      Loam.Tui.Record.viewForBounds bounds known state.editor
  | .preview draft choice =>
      let width := Loam.Tui.Layout.contentWidth bounds
      let footer := previewFooter bounds state choice
      let height := Loam.Tui.Layout.footerBodyCapacity bounds footer.length - 1
      let capacity := height - 2
      let lines := previewLines (width - 2) state draft
      let offset := Loam.Tui.Scroll.clamp lines.length capacity state.editor.previewScroll
      let more := (if offset > 0 then " ▲" else "") ++
        (if offset + capacity < lines.length then " ▼" else "")
      let panel := Loam.Tui.Layout.framedPanel width height "Correction / signed postings"
        (.column ((lines.drop offset).take capacity)) true
        (some (s!"{min (offset + capacity) lines.length}/{lines.length} lines" ++ more))
      Loam.Tui.Record.boundedWithFooter bounds (.column [line "Correction / Preview", panel]) footer

end Loam.Tui.Correction
