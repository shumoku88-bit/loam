import Loam.ActualDate
import Loam.Persistence.TokenSyntax
import Loam.Publisher.ScheduledReplacementPublisher
import Loam.Tui.EditorSession
import Loam.Tui.Main
import Loam.Tui.Record
import Loam.Tui.LocusPicker
import Loam.Tui.InputEdit
import Loam.Tui.Layout
import Loam.Tui.Scroll
import Loam.Tui.ScheduledPostingForm
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.ScheduledReplacement

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected Scheduled replacement editor

This state is presentation-only. It edits exactly the retained replacement content:
one date plus signed single-Measure postings. It deliberately has no Actual description,
Movement Event, recurrence, continuation, or routing state. Publication authority
remains `ScheduledReplacementPublisher`, which re-reads current Scheduled and
Movement evidence under ownership.
-/

abbrev Form := Loam.Tui.ScheduledPostingForm.Form

inductive Mode where
  | editing
  | preview (draft : Loam.ScheduledReplacementPublisher.Draft) (choice : Fin 3)

structure State where
  measure : MeasureId := ⟨"jpy"⟩
  target : ScheduledId
  originalOn : String
  form : Form
  mode : Mode := .editing
  notice : String := ""
  previewScroll : Nat := 0
  /-- Local highlight in the current admitted Locus candidate list. -/
  candidateIndex : Nat := 0

abbrev Step :=
  Loam.Tui.EditorSession.Step State Loam.ScheduledReplacementPublisher.Draft

private def rowsFromScheduled
    (record : Loam.Tui.Main.ScheduledRecord) : Array Loam.Tui.Record.Row :=
  (record.movement.changes.map fun change =>
    ({ locus := change.coordinate.token,
       amount := toString change.quantity.quanta } : Loam.Tui.Record.Row)).toArray

/-- Seed replacement content from one visible current-open Scheduled occurrence. -/
def initial?
    (record : Loam.Tui.Main.ScheduledRecord) : Except String State := do
  let rows := rowsFromScheduled record
  if rows.size < 2 then
    throw "This Scheduled occurrence is outside the practical balanced replacement editor."
  if rows.size > 6 then
    throw "This Scheduled occurrence has more than six postings; this replacement editor will not truncate it."
  pure {
    measure := record.measure
    target := record.id
    originalOn := record.scheduledOn
    form := { date := record.scheduledOn, rows := rows }
  }

/-- Existing write-admitted token vocabulary, without inventing label metadata. -/
private def candidateCatalog (known : List String) : Loam.LocusCatalog.Catalog :=
  Loam.LocusCatalog.forLoci (known.map fun token => (⟨token⟩ : LocusId)) []

private def selectedToken? (known : List String) (state : State) : Option String := do
  let entered ← Loam.Tui.ScheduledPostingForm.activeLocus? state.form
  Loam.Tui.LocusPicker.commitToken?
    (candidateCatalog known) entered state.candidateIndex

private def moveCandidate (known : List String) (state : State) (back : Bool) : State :=
  match Loam.Tui.ScheduledPostingForm.activeLocus? state.form with
  | none => { state with candidateIndex := 0 }
  | some entered =>
      { state with candidateIndex :=
          Loam.Tui.LocusPicker.move (candidateCatalog known) entered state.candidateIndex back }

private def acceptCandidate (known : List String) (state : State) : State :=
  match selectedToken? known state with
  | none => state
  | some token =>
      { state with
          form := Loam.Tui.ScheduledPostingForm.editActive state.form (fun _ => token)
          candidateIndex := 0 }

private def acceptCandidateAndAdvance (known : List String) (state : State) : State :=
  let committed := acceptCandidate known state
  { committed with
      form := Loam.Tui.ScheduledPostingForm.moveFocus committed.form false
      candidateIndex := 0 }

/--
Parse the local form and perform advisory pure checks before preview. The shared
publisher repeats authoritative validation under ownership, so this helper is not
a second write authority.
-/
def draft? (state : State) : Except String Loam.ScheduledReplacementPublisher.Draft := do
  if !Loam.ActualDate.validIsoDate state.form.date then
    throw "Replacement date must be a real calendar date in YYYY-MM-DD form."
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
    | throw "Scheduled replacement posting totals differ."
  if positive <= 0 then
    throw "Scheduled replacement requires a positive balanced total."
  pure {
    source := state.target
    scheduledOn := state.form.date
    movement := movement
  }

private def preview (state : State) : State :=
  match draft? state with
  | .error message => { state with notice := message }
  | .ok draft => { state with mode := .preview draft ⟨0, by omega⟩, notice := "" }

/-- Local editor transition. Durable intent is emitted only from preview Publish. -/
def update
    (known : List String) (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape => { state, cancel := true }
  | _ =>
    match state.mode with
    | .preview draft choice =>
        match key with
        | .tab | .right =>
            { state := { state with mode := .preview draft ⟨(choice.val + 1) % 3, Nat.mod_lt _ (by omega)⟩ } }
        | .shiftTab | .left =>
            { state := { state with mode := .preview draft ⟨(choice.val + 2) % 3, Nat.mod_lt _ (by omega)⟩ } }
        | .enter =>
            if choice.val = 0 then { state, publish := some draft }
            else if choice.val = 1 then { state := { state with mode := .editing } }
            else { state, cancel := true }
        | _ => { state }
    | .editing =>
        match key with
        | .tab => { state := { state with form := Loam.Tui.ScheduledPostingForm.moveFocus state.form false, candidateIndex := 0 } }
        | .shiftTab => { state := { state with form := Loam.Tui.ScheduledPostingForm.moveFocus state.form true, candidateIndex := 0 } }
        | .backspace | .input _ | .paste _ =>
            match Loam.Tui.InputEdit.operation? key with
            | none => { state }
            | some edit =>
                { state := { state with
                    form := Loam.Tui.ScheduledPostingForm.editActive state.form edit
                    notice := "", candidateIndex := 0 } }
        | .up => { state := moveCandidate known state true }
        | .down => { state := moveCandidate known state false }
        | .right => { state := acceptCandidate known state }
        | .enter =>
            let action := Loam.Tui.ScheduledPostingForm.firstAction state.form
            let focus := state.form.focus
            if (Loam.Tui.ScheduledPostingForm.activeLocus? state.form).isSome then
              { state := acceptCandidateAndAdvance known state }
            else if focus + 1 = action then
              { state := preview state }
            else if focus < action then
              { state := { state with form := Loam.Tui.ScheduledPostingForm.moveFocus state.form false, candidateIndex := 0 } }
            else if focus = action && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else if focus = action then
              { state := { state with form := Loam.Tui.ScheduledPostingForm.appendRow state.form } }
            else if focus = action + 1 then
              { state := { state with form := Loam.Tui.ScheduledPostingForm.dropRow state.form } }
            else if focus = action + 2 then
              { state := preview state }
            else
              { state, cancel := true }
        | _ => { state }

/-- Failed shared publication returns to editable replacement evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

/-- Review/paint behavior is terminal-size dependent; edit and publication semantics
    remain in the existing `update` state machine. -/
private def line (text : String) : Widget := .row [span text]

private def boundedField (width : Nat) (form : Form) (index : Nat)
    (label value : String) : Widget :=
  let labelText := label ++ ": "
  let available := width - Loam.Tui.Layout.displayWidth labelText
  let active := form.focus == index
  let content := if value.isEmpty then "_" else value
  .row [span labelText .muted,
        span (if active then Loam.Tui.Layout.inputTail available content
              else Loam.Tui.Layout.ellipsize available content)
          (if active then .selected else .normal)]

private def editingFields (width : Nat) (state : State) : List Widget :=
  let form := state.form
  [boundedField width form 0 "Replacement due" form.date] ++
    (List.range form.rows.size).flatMap fun i =>
      let row := form.rows[i]!
      [boundedField width form (1 + i * 2) ("Posting " ++ toString (i + 1)) row.locus,
       boundedField width form (2 + i * 2) ("  " ++ state.measure.token) row.amount]

private def actionRow (state : State) (labels : List (Nat × String)) : Widget :=
  let start := Loam.Tui.ScheduledPostingForm.firstAction state.form
  .row (labels.map fun (offset, label) =>
    span ("[" ++ label ++ "] ")
      (if state.form.focus == start + offset then .selected else .normal))

private def editingFooter (bounds : Bounds) (known : List String)
    (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let actions := if width < 50 then
    [actionRow state [(0, "Add"), (1, "Drop")],
     actionRow state [(2, "Preview"), (3, "Cancel")]]
    else
    [actionRow state [(0, "Add posting"), (1, "Drop last row"),
                      (2, "Preview"), (3, "Cancel")]]
  let candidate := line ("Candidate: " ++ (selectedToken? known state).getD "")
  let help := line "Tab/Shift-Tab focus  Right accept  Enter next  Esc cancel"
  let feedback := if state.notice.isEmpty then [line ""] else
    (Loam.Tui.Layout.wrapColumns width state.notice).map line
  -- The action bar remains visible even when long feedback overflows a short terminal.
  Loam.Tui.Layout.boundFeedbackFooter bounds (actions ++ [candidate, help] ++ feedback)

/-- Keep the focused Due, Posting, or action reachable in a height-bounded editor. -/
private def editingView (bounds : Bounds) (known : List String) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let footer := editingFooter bounds known state
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let fields := editingFields width state
  let contextHeight := if available >= 3 then 2 else if available > 0 then 1 else 0
  let capacity := available - contextHeight
  let focus := min state.form.focus (fields.length - 1)
  let start := min (fields.length - capacity)
    (Loam.Tui.Layout.trailingWindowStart focus capacity)
  let context :=
    if contextHeight >= 2 then
      [line "Scheduled / Supersede / Edit replacement",
       line (Loam.Tui.Layout.ellipsize width
         ("Source: " ++ state.target.token ++ "   Original due: " ++ state.originalOn))]
    else if contextHeight == 1 then
      [line "Scheduled / Supersede / Edit replacement"]
    else []
  let rows := context ++ (fields.drop start).take capacity
  .column ((Loam.Tui.Layout.fitWithFooter bounds rows footer).map fun row =>
    Loam.Tui.Layout.clipWidgetRow width row)

private def wrapped (columns : Nat) (text : String) : List Widget :=
  (Loam.Tui.Layout.wrapColumns columns text).map line

/-- The exact source, due and effects are all part of the scrollable review. -/
private def previewRows (width : Nat)
    (draft : Loam.ScheduledReplacementPublisher.Draft) : List Widget :=
  let columns := width - 1
  wrapped columns ("Source: " ++ draft.source.token) ++
    wrapped columns ("Replacement due: " ++ draft.scheduledOn) ++
    (draft.movement.changes.flatMap fun change =>
      wrapped columns
        (change.coordinate.token ++ "  " ++ toString change.quantity.quanta ++
          " " ++ draft.movement.measure.token)) ++
    wrapped columns ("Balanced total: " ++ toString
      (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++
      " " ++ draft.movement.measure.token)

private def previewFooter (bounds : Bounds) (state : State) (choice : Fin 3) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let choices : Widget := .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, i) =>
    span ("[" ++ label ++ "] ")
      (if choice.val == i then .selected else .normal))
  let feedback := if state.notice.isEmpty then [line ""] else
    (Loam.Tui.Layout.wrapColumns width state.notice).map line
  Loam.Tui.Layout.boundFeedbackFooter bounds <|
    [choices, line "Tab/Shift-Tab choose  Enter confirm  Esc cancel"] ++ feedback

/-- Only an adequately visible review may produce a Scheduled replacement write. -/
def previewCapacity (bounds : Bounds) (state : State) : Nat :=
  match state.mode with
  | .editing => 0
  | .preview _ choice =>
      Loam.Tui.Layout.footerBodyCapacity bounds (previewFooter bounds state choice).length - 1

def previewScrollLimit (bounds : Bounds) (state : State) : Nat :=
  match state.mode with
  | .editing => 0
  | .preview draft _ =>
      Loam.Tui.Scroll.maxOffset
        (previewRows (Loam.Tui.Layout.contentWidth bounds) draft).length
        (previewCapacity bounds state)

/-- Preserve the old key grammar. Only preview scrolling and visibility-gated
    Publish depend on current terminal bounds. -/
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
          if choice.val == 0 && previewCapacity bounds state < 5 then
            { state := { state with
                notice := "Enlarge terminal to review the Scheduled replacement before publishing." } }
          else update known state key
      | _ => update known state key

/-- All rows are clipped to the active terminal, with a focus-following editor
    and a bounded review whose action bar stays visible. -/
def viewForBounds (bounds : Bounds) (known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing => editingView bounds known state
  | .preview draft choice =>
      let width := Loam.Tui.Layout.contentWidth bounds
      let footer := previewFooter bounds state choice
      let visible := previewCapacity bounds state
      let rows := previewRows width draft
      let offset := Loam.Tui.Scroll.clamp rows.length visible state.previewScroll
      let progress := s!"{min (offset + visible) rows.length}/{rows.length} review lines" ++
        (if offset > 0 then " ▲" else "") ++
        (if offset + visible < rows.length then " ▼" else "")
      let body := [line "Scheduled / Supersede / Preview"] ++
        (rows.drop offset).take visible
      let body := if visible > 0 then body else [line progress] ++ body
      .column ((Loam.Tui.Layout.fitWithFooter bounds body footer).map fun row =>
        Loam.Tui.Layout.clipWidgetRow width row)

/-- Retain a stable test-facing renderer; production always supplies live bounds. -/
def view (known : List String) (state : State) : Widget :=
  viewForBounds {width := 120, height := 40} known state

end Loam.Tui.ScheduledReplacement
