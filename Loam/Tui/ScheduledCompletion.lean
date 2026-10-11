import Loam.Presentation.MeasurePresentation
import Loam.Publisher.ScheduledTerminalPublisher
import Loam.Tui.Main
import Loam.Tui.Record
import Loam.Tui.Layout
import Loam.Tui.Scroll
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
  enableUnresolved : Bool := false
  publish : Option Loam.ScheduledTerminalPublisher.CompletionDraft := none

private def rowsFromScheduled
    (metadata : List Loam.MeasurePresentation.Metadata)
    (record : Loam.Tui.Main.ScheduledRecord) : Array Loam.Tui.Record.Row :=
  (record.movement.changes.map fun change =>
    ({ locus := change.coordinate.token,
       amount := Loam.MeasurePresentation.formatQuanta
         metadata record.measure change.quantity.quanta } : Loam.Tui.Record.Row)).toArray

/--
Seed an editable Actual draft from one visible current-open Scheduled occurrence.

The single-Measure Scheduled value and the six-row bound are editor
representability checks only. They do not admit completion. Expected values
remain editable conveniences, never authority.
-/
def initialWithPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (record : Loam.Tui.Main.ScheduledRecord)
    (actualDate : String) : Except String State := do
  let rows := rowsFromScheduled metadata record
  if rows.size < 2 then
    throw "This Scheduled occurrence is outside the practical balanced-Movement completion editor."
  if rows.size > 6 then
    throw "This Scheduled occurrence has more than six postings; this completion editor will not truncate it."
  let form : Loam.Tui.Record.Form := {
    date := actualDate
    description := ""
    measure := record.measure.token
    rows := rows
    focus := ⟨0, by omega⟩
  }
  pure {
    target := record.id
    expectedOn := record.scheduledOn
    editor := { form := form, measurePresentation := metadata }
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
  match key with
  | .ctrl 'o' =>
      { state := { state with editor := {
          state.editor with
          mode := .editing
          notice := "Original amount is available from new Actual Record, not Scheduled completion."
        } } }
  | _ =>
      let step := Loam.Tui.Record.update world known state.editor key
      let next := { state with editor := step.state }
      if step.cancel then
        { state := next, cancel := true }
      else
        { state := next
          enableUnresolved := step.enableUnresolved
          publish := step.publish.bind fun intent =>
            match intent with
            | .movement draft => some (publisherDraft state.target draft)
            | .movementWithOriginalAmount _ _ => none }

/-- Failed publication returns to editable Actual evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with editor := { state.editor with mode := .editing, notice := message } }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

/-- Keep confirmation controls in the footer, even if refusal feedback wraps. -/
private def foot (bounds : Bounds) (state : State) (controls : List Widget) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let notes := (Loam.Tui.Layout.wrapColumns width state.editor.notice).map line
  let available := (bounds.height - 1) - controls.length
  let feedback :=
    if notes.length > available && available > 0 then
      notes.take (available - 1) ++ [muted "… more feedback; enlarge terminal"]
    else
      notes.take available
  feedback ++ controls

private def planHeader (bounds : Bounds) (state : State)
    (available : Nat) (title : String) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  if available >= 8 then
    [ line title
    , line (Loam.Tui.Layout.clip width ("Plan due: " ++ state.expectedOn))
    , line (Loam.Tui.Layout.clip width ("Plan ID: " ++ state.target.token)) ]
  else if available >= 5 then
    [ line title
    , line (Loam.Tui.Layout.clip width
        ("Plan: " ++ state.expectedOn ++ "  " ++ state.target.token)) ]
  else
    [ line title ]

private def editingRows (state : State) : List Widget :=
  let form := state.editor.form
  let fields := [ Loam.Tui.Record.field form 0 "Actual date" form.date
                , Loam.Tui.Record.field form 1 "Actual description" form.description
                , Loam.Tui.Record.field form 2 "Actual Measure" form.measure ]
  let postings := (List.range form.rows.size).flatMap fun index =>
    let row := form.rows[index]!
    [ Loam.Tui.Record.field form (3 + index * 2)
        ("Posting " ++ toString (index + 1)) row.locus
    , Loam.Tui.Record.field form (4 + index * 2)
        ("  " ++ form.measure) row.amount ]
  -- Record.update dispatches these actions in this exact focus order.
  let actions := (["Preview", "Add posting", "Drop last row", "Cancel"].zipIdx).map
    fun (label, index) =>
      .row [span ("[" ++ label ++ "]")
        (if form.focus.val == 3 + form.rows.size * 2 + index
         then .selected else .normal)]
  fields ++ postings ++ actions

private def editingView (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let candidate := ((Loam.Tui.Record.selectedCatalogCandidate? state.editor).map
    (fun entry => entry.locus.token)).getD "(none)"
  let help := if width < 55 then
    "Tab focus  Enter next  Esc cancel"
  else
    "Tab focus  Enter next/preview  Right accept  Esc cancel"
  let controls :=
    [ muted ("Candidate: " ++ Loam.Tui.Layout.clip (width - 11) candidate)
    , muted help ]
  let footer := foot bounds state controls
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let header := planHeader bounds state available "Scheduled / Complete / Actual"
  let height := available - header.length
  let capacity := height - 2
  let rows := editingRows state
  let focus := min state.editor.form.focus.val (rows.length - 1)
  let offset := min (rows.length - capacity)
    (Loam.Tui.Layout.trailingWindowStart focus capacity)
  let visible := (rows.drop offset).take capacity
  let more := (if offset > 0 then " ▲" else "") ++
    (if offset + capacity < rows.length then " ▼" else "")
  let panel := Loam.Tui.Layout.framedPanel width height "Actual draft (editable)"
    (.column visible) true
    (some (s!"{focus + 1}/{rows.length}" ++ more))
  let body : Widget := .column (header ++ [panel])
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows body) footer).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)

private def previewRows (bounds : Bounds) (state : State)
    (draft : Loam.MovementAdmission.Draft) : List Widget :=
  let columns := Loam.Tui.Layout.contentWidth bounds - 4
  let effects := draft.effects.flatMap fun effect =>
    let amount := Loam.MeasurePresentation.formatQuanta
      state.editor.measurePresentation effect.measure effect.quantity.quanta
    let signed := (if effect.quantity.quanta > 0 then "+" else "") ++ amount
    (Loam.Tui.Layout.wrapColumns columns
      (" " ++ effect.locus.token ++ "  " ++ signed ++ " " ++ effect.measure.token)).map line
  let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
  let total := Loam.MeasurePresentation.formatQuanta
    state.editor.measurePresentation measure
    (Effect.positiveQuantaTotal draft.effects)
  effects ++
    (Loam.Tui.Layout.wrapColumns columns
      ("Actual positive total: " ++ total ++ " " ++ measure.token)).map muted ++
    (Loam.Tui.Layout.wrapColumns columns
      ("Plan reference (not overwritten): " ++ state.target.token)).map muted

private def previewFooter (bounds : Bounds) (state : State) (choice : Fin 3) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  foot bounds state
    [ muted (Loam.Tui.Layout.clip width "Publish = Actual Event + Scheduled completion relation")
    , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
        span ("[" ++ label ++ "] ")
          (if choice.val == index then .selected else .normal))
    , muted (if width < 55 then
        "↑/↓ review  Tab select  Enter  Esc cancel"
      else
        "Up/Down/PgUp/PgDn review  Tab select  Enter confirm  Esc cancel") ]

private def previewContext (bounds : Bounds) (state : State)
    (draft : Loam.MovementAdmission.Draft) (available : Nat) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let title := "Scheduled / Complete / Actual"
  let header := planHeader bounds state available title
  let actualDate := line (Loam.Tui.Layout.clip width ("Actual date: " ++ draft.validOn))
  let description := line (Loam.Tui.Layout.clip width
    ("Actual description: " ++ draft.description.getD "(no description)"))
  if available >= 10 then header ++ [actualDate, description]
  else if available >= 5 then header ++ [actualDate]
  else header

/-- Physical review rows available below the Plan/Actual context and above actions. -/
def previewCapacity (bounds : Bounds) (state : State)
    (draft : Loam.MovementAdmission.Draft) (choice : Fin 3) : Nat :=
  let available := Loam.Tui.Layout.footerBodyCapacity bounds
    (previewFooter bounds state choice).length
  available - (previewContext bounds state draft available).length - 2

/-- Preview scrolling is presentation-only. The publisher still owns completion. -/
def updateForBounds (bounds : Bounds)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.editor.mode with
  | .preview draft choice =>
      let visible := previewCapacity bounds state draft choice
      let count := (previewRows bounds state draft).length
      let current := Loam.Tui.Scroll.clamp count visible state.editor.previewScroll
      let page := max 1 visible
      let moved (offset : Nat) : Step :=
        { state := { state with editor := { state.editor with previewScroll := offset } } }
      match key with
      | .up => moved (Loam.Tui.Scroll.backward count visible current 1)
      | .down => moved (Loam.Tui.Scroll.forward count visible current 1)
      | .pageUp => moved (Loam.Tui.Scroll.backward count visible current page)
      | .pageDown => moved (Loam.Tui.Scroll.forward count visible current page)
      | .home => moved 0
      | .«end» => moved (Loam.Tui.Scroll.maxOffset count visible)
      | .enter =>
          if choice.val == 0 && visible < 2 then
            { state := { state with editor := { state.editor with
                notice := "Enlarge terminal to review the Actual postings before Publish." } } }
          else update world known state key
      | _ => update world known state key
  | _ => update world known state key

private def previewView (bounds : Bounds) (state : State)
    (draft : Loam.MovementAdmission.Draft) (choice : Fin 3) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let footer := previewFooter bounds state choice
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let context := previewContext bounds state draft available
  let height := available - context.length
  let capacity := height - 2
  let rows := previewRows bounds state draft
  let offset := Loam.Tui.Scroll.clamp rows.length capacity state.editor.previewScroll
  let count := min rows.length (offset + capacity)
  let status := s!"{count}/{rows.length} lines" ++
    (if offset > 0 then " ▲" else "") ++
    (if count < rows.length then " ▼" else "")
  let panel := Loam.Tui.Layout.framedPanel width height "Actual effects (to record)"
    (.column ((rows.drop offset).take capacity)) true (some status)
  let body : Widget := .column (context ++ [panel])
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (Loam.Tui.Layout.widgetRows body) footer).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)

/-- Plan reference is retained separately from the edited/new Actual evidence. -/
def view (bounds : Bounds) (known : List String) (state : State) : Widget :=
  match state.editor.mode with
  | .editing => editingView bounds state
  | .enableUnresolved | .originalAmount _ =>
      Loam.Tui.Record.view known state.editor
  | .preview draft choice => previewView bounds state draft choice

end Loam.Tui.ScheduledCompletion
