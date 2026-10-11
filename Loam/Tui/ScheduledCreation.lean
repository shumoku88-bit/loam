import Loam.ActualDate
import Loam.Presentation.LocusCatalog
import Loam.Persistence.TokenSyntax
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.LocusPicker
import Loam.Tui.Main
import Loam.Tui.Record
import Loam.Tui.ScheduledPostingForm
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega
import Loam.Tui.Layout
import Loam.Tui.Scroll

namespace Loam.Tui.ScheduledCreation

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# New Scheduled editor

This state is presentation-only. It edits one explicit due date plus signed
single-Measure postings. It carries no recurrence, continuation, replacement source, routing,
or Actual evidence. Publication authority remains `ScheduledCreationPublisher`.
-/

abbrev Form := Loam.Tui.ScheduledPostingForm.Form

inductive Mode where
  | editing
  | preview (draft : Loam.ScheduledCreationPublisher.Draft) (choice : Fin 3)

structure State where
  measure : MeasureId := ⟨"jpy"⟩
  form : Form
  mode : Mode := .editing
  notice : String := ""
  candidateCatalog : Loam.LocusCatalog.Catalog := []
  candidateIndex : Nat := 0
  /-- Offset within the wrapped confirmation postings, never household state. -/
  previewScroll : Nat := 0

abbrev Step :=
  Loam.Tui.EditorSession.Step State Loam.ScheduledCreationPublisher.Draft

/-- Seed a new Scheduled occurrence for one explicit Measure. -/
def initialWithMeasure (measure : MeasureId) (date : String) : State :=
  { measure := measure, form := { date := date, rows := #[{}, {}] } }

/-- Backward-compatible no-configuration entrance for the current JPY household. -/
def initial (date : String) : State :=
  initialWithMeasure ⟨"jpy"⟩ date

/-- Attach display-only metadata to one Scheduled creation editor. -/
def withCatalog (state : State) (catalog : Loam.LocusCatalog.Catalog) : State :=
  { state with candidateCatalog := catalog, candidateIndex := 0 }

private def rowsFromScheduled
    (record : Loam.Tui.Main.ScheduledRecord) : Array Loam.Tui.Record.Row :=
  (record.movement.changes.map fun change =>
    ({ locus := change.coordinate.token, amount := toString change.quantity.quanta } :
      Loam.Tui.Record.Row)).toArray

/--
Seed an independent next Scheduled editor from the expectation that was just
completed.

The original expected movement is only a presentation seed. The completed
Actual is deliberately not consulted, so a one-off Actual amount/date change
cannot silently rewrite the next expectation. The next due date starts blank:
continuation is explicit user intent and no recurrence or date inference is
introduced. Durable publication still goes through `ScheduledCreationPublisher`.
-/
def initialFromScheduled?
    (record : Loam.Tui.Main.ScheduledRecord) : Except String State := do
  let rows := rowsFromScheduled record
  if rows.size < 2 then
    throw "This Scheduled occurrence is outside the practical balanced-Movement next-Scheduled editor."
  if rows.size > 6 then
    throw "This Scheduled occurrence has more than six postings; the next-Scheduled editor will not truncate it."
  pure {
    measure := record.measure
    form := { date := "", rows := rows, focus := 0 }
    notice := "Completion is already published. Enter the next due date, or Esc for completion only."
  }

private def catalogCandidates (state : State) : Loam.LocusCatalog.Catalog :=
  match Loam.Tui.ScheduledPostingForm.activeLocus? state.form with
  | none => []
  | some entered => Loam.Tui.LocusPicker.candidates state.candidateCatalog entered

private def selectedCatalogCandidate? (state : State) : Option Loam.LocusCatalog.Entry :=
  match Loam.Tui.ScheduledPostingForm.activeLocus? state.form with
  | none => none
  | some entered =>
      Loam.Tui.LocusPicker.selected? state.candidateCatalog entered state.candidateIndex

private def moveCandidate (state : State) (back : Bool) : State :=
  match Loam.Tui.ScheduledPostingForm.activeLocus? state.form with
  | none => { state with candidateIndex := 0 }
  | some entered =>
      { state with candidateIndex :=
          Loam.Tui.LocusPicker.move state.candidateCatalog entered state.candidateIndex back }

private def acceptSelectedCandidate (state : State) : State :=
  match selectedCatalogCandidate? state with
  | none => state
  | some entry =>
      { state with
          form := Loam.Tui.ScheduledPostingForm.editActive state.form (fun _ => entry.locus.token)
          candidateIndex := 0 }

/-- Pure advisory parsing before preview; the shared publisher re-validates under ownership. -/
def draft? (state : State) : Except String Loam.ScheduledCreationPublisher.Draft := do
  if !Loam.ActualDate.validIsoDate state.form.date then
    throw "Scheduled date must be a real calendar date in YYYY-MM-DD form."
  let mut changes : List (MovementChange LocusId) := []
  let mut positive := 0
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    let some amount := row.amount.toInt?
      | throw ("Enter a nonzero signed integer " ++ state.measure.token ++ " amount for every posting.")
    if amount = 0 then
      throw ("Enter a nonzero signed integer " ++ state.measure.token ++ " amount for every posting.")
    if !Loam.Persistence.validToken row.locus then
      throw "Enter a valid Locus token for every posting."
    changes := changes ++ [{
      coordinate := ⟨row.locus⟩
      quantity := Quantity.ofQuanta amount
    }]
    if amount > 0 then positive := positive + amount
  let some movement := BalancedMovement.ofChanges? state.measure changes
    | throw "Scheduled posting totals differ."
  if positive <= 0 then
    throw "Scheduled creation requires a positive balanced total."
  pure {
    scheduledOn := state.form.date
    movement := movement
  }

private def preview (state : State) : State :=
  match draft? state with
  | .error message => { state with notice := message }
  | .ok draft => { state with mode := .preview draft ⟨0, by omega⟩, previewScroll := 0, notice := "" }

/-- Local editor transition. Durable intent is emitted only from preview Publish. -/
def update
    (_known : List String) (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | _ =>
    match state.mode with
    | .preview draft choice =>
        match key with
        | .tab | .right =>
            { state := { state with mode := (.preview draft ⟨(choice.val + 1) % 3, Nat.mod_lt _ (by omega)⟩) } }
        | .shiftTab | .left =>
            { state := { state with mode := (.preview draft ⟨(choice.val + 2) % 3, Nat.mod_lt _ (by omega)⟩) } }
        | .enter =>
            if choice.val = 0 then { state, publish := some draft }
            else if choice.val = 1 then { state := { state with mode := .editing } }
            else { state, cancel := true }
        | _ => { state }
    | .editing =>
        match key with
        | .tab => { state := { state with form := Loam.Tui.ScheduledPostingForm.moveFocus state.form false, candidateIndex := 0 } }
        | .shiftTab => { state := { state with form := Loam.Tui.ScheduledPostingForm.moveFocus state.form true, candidateIndex := 0 } }
        | .backspace =>
            { state := { state with
                form := Loam.Tui.ScheduledPostingForm.editActive state.form (fun text => Loam.Tui.Terminal.backspaceText text)
                notice := "", candidateIndex := 0 } }
        | .input char =>
            { state := { state with
                form := Loam.Tui.ScheduledPostingForm.editActive state.form (fun text => text.push char)
                notice := "", candidateIndex := 0 } }
        | .paste text =>
            let clean := Loam.Tui.Terminal.singleLinePaste text
            { state := { state with
                form := Loam.Tui.ScheduledPostingForm.editActive state.form (fun curr => curr ++ clean)
                notice := "", candidateIndex := 0 } }
        | .up => { state := moveCandidate state true }
        | .down => { state := moveCandidate state false }
        | .right => { state := acceptSelectedCandidate state }
        | .enter =>
            let action := Loam.Tui.ScheduledPostingForm.firstAction state.form
            let focus := state.form.focus
            if focus + 1 = action then
              { state := preview state }
            else if focus < action then
              { state := { state with form := Loam.Tui.ScheduledPostingForm.moveFocus state.form false, candidateIndex := 0 } }
            else if focus = action && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else if focus = action then
              { state := { state with form := Loam.Tui.ScheduledPostingForm.appendRow state.form, candidateIndex := 0 } }
            else if focus = action + 1 then
              { state := { state with form := Loam.Tui.ScheduledPostingForm.dropRow state.form, candidateIndex := 0 } }
            else if focus = action + 2 then
              { state := preview state }
            else
              { state, cancel := true }
        | _ => { state }

/-- Failed shared publication returns to editable local evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, previewScroll := 0, notice := message }

private def line (text : String) : Widget := .row [span text]

private def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus = index then .selected else .normal)]

private def wrapped (columns : Nat) (text : String) (style : Style) : List Widget :=
  (Loam.Tui.Layout.wrapColumns columns text).map fun piece => .row [span piece style]

/-- Exact signed quanta and full Locus/Measure tokens, including long Unicode values. -/
private def previewPostingRows (columns : Nat)
    (draft : Loam.ScheduledCreationPublisher.Draft) : List Widget :=
  let postings := draft.movement.changes.flatMap fun change =>
    let signed := (if change.quantity.quanta > 0 then "+" else "") ++
      toString change.quantity.quanta
    wrapped columns
      (" " ++ change.coordinate.token ++ "  " ++ signed ++
        " " ++ draft.movement.measure.token) .normal
  postings ++ wrapped columns
    (" Balanced total: " ++ toString
      (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++
      " " ++ draft.movement.measure.token) .muted

private def previewFooter (bounds : Bounds) (state : State) (choice : Fin 3) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := wrapped width state.notice .normal
  Loam.Tui.Layout.boundFeedbackFooter bounds <|
    (if feedback.isEmpty then [line ""] else feedback) ++
    [ .row ((["Publish Scheduled", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
        span ("[" ++ label ++ "] ")
          (if choice.val = index then .selected else .normal))
    , .row [span " Tab/Left/Right select  Enter confirm  Esc cancel" .muted]
    , .row [span " Up/Down/PgUp/PgDn/Home/End review postings" .muted]
    ]

/-- Capacity is derived from the actual terminal and the reserved confirmation footer. -/
def previewCapacity (bounds : Bounds) (state : State) : Nat :=
  match state.mode with
  | .editing => 0
  | .preview _ choice =>
      (Loam.Tui.Layout.footerBodyCapacity bounds
        (previewFooter bounds state choice).length - 5) - 2

def previewScrollLimit (bounds : Bounds) (state : State) : Nat :=
  match state.mode with
  | .editing => 0
  | .preview draft _ =>
      Loam.Tui.Scroll.maxOffset
        (previewPostingRows (Loam.Tui.Layout.contentWidth bounds - 2) draft).length
        (previewCapacity bounds state)

/-- Review navigation never changes an editable field or the publish draft. -/
def updateForBounds (bounds : Bounds) (known : List String) (state : State)
    (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .editing => update known state key
  | .preview _ choice =>
      let limit := previewScrollLimit bounds state
      let current := min state.previewScroll limit
      let page := max 1 (previewCapacity bounds state)
      match key with
      | .up => { state := { state with previewScroll := current - 1 } }
      | .down => { state := { state with previewScroll := min limit (current + 1) } }
      | .pageUp => { state := { state with previewScroll := current - page } }
      | .pageDown => { state := { state with previewScroll := min limit (current + page) } }
      | .home => { state := { state with previewScroll := 0 } }
      | .«end» => { state := { state with previewScroll := limit } }
      | .enter =>
          if choice.val == 0 && previewCapacity bounds state < 2 then
            { state := { state with
                notice := "Enlarge terminal to review Scheduled postings before publishing." } }
          else update known state key
      | _ => update known state key

/-- Creation exposes only Scheduled content and does not invent an Actual description. -/
def view (bounds : Bounds) (_known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing =>
      let form := state.form
      let activeRow := (form.focus - 1) / 2
      let start := if activeRow < form.rows.size then activeRow - 3 else form.rows.size - 6
      let rowLines := ((List.range form.rows.size).drop start |>.take 6).flatMap fun index =>
        let row := form.rows[index]!
        [ field form (1 + index * 2) ("Posting " ++ toString (index + 1)) row.locus
        , field form (2 + index * 2) ("  " ++ state.measure.token) row.amount
        ]
      let actions := ["Add posting", "Drop last row", "Preview", "Cancel"]
      let options := catalogCandidates state
      let selectedIndex := if options.isEmpty then 0 else state.candidateIndex % options.length
      let candidateStart := Loam.Tui.Layout.trailingWindowStart selectedIndex 5
      let visible := (options.drop candidateStart).take 5
      let candidateLines := if visible.isEmpty then [line "Loci: (none)"] else
        (visible.zipIdx).map fun (entry, index) =>
          let marker := if candidateStart + index = selectedIndex then "> " else "  "
          line (marker ++ Loam.Tui.LocusPicker.display entry)
      let helpLine :=
        match selectedCatalogCandidate? state with
        | some entry => if entry.help.isEmpty then [] else [line ("  " ++ entry.help)]
        | none => []
      .column <|
        [ line "Scheduled / New / Edit"
        , field form 0 "Due" form.date
        ] ++ rowLines ++
        [ .row ((actions.zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if form.focus = Loam.Tui.ScheduledPostingForm.firstAction form + index then .selected else .normal))
        , line "Locus catalog:"
        ] ++ candidateLines ++ helpLine ++
        [ line ("Signed " ++ state.measure.token ++ " postings describe one independent expected movement.")
        , line "No recurrence, continuation, replacement relation, or Actual is created."
        , line "Tab / Shift-Tab focus   Enter next/preview/action"
        , line "Up / Down choose Locus   Right accept Locus"
        , line "Esc cancel   Backspace delete   Drop keeps at least two postings"
        , line state.notice
        ]
  | .preview draft choice =>
      let width := Loam.Tui.Layout.contentWidth bounds
      let footer := previewFooter bounds state choice
      let capacity := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
      let summary := Loam.Tui.Layout.framedPanel width (min 5 capacity)
        "Scheduled / New / Preview"
        (.column [
          .row [span " Due: " .muted, span draft.scheduledOn],
          .row [span " Measure: " .muted, span draft.movement.measure.token],
          .row [span " Independent expectation; no Actual or recurrence." .muted]
        ]) true
      let postings := previewPostingRows (width - 2) draft
      let visible := previewCapacity bounds state
      let offset := Loam.Tui.Scroll.clamp postings.length visible state.previewScroll
      let count := min (offset + visible) postings.length
      let progress := s!"{count}/{postings.length} lines" ++
        (if offset > 0 then " ▲" else "") ++
        (if count < postings.length then " ▼" else "")
      let review := Loam.Tui.Layout.framedPanel width (capacity - 5)
        "Expected postings" (.column ((postings.drop offset).take visible))
        false (some progress)
      .column ((Loam.Tui.Layout.fitWithFooter bounds
        (Loam.Tui.Layout.widgetRows (.column [summary, review])) footer).map fun row =>
          Loam.Tui.Layout.clipWidgetRow width row)

end Loam.Tui.ScheduledCreation