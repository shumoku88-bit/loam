import Loam.ActualDate
import Loam.LocusCatalog
import Loam.Persistence.TokenSyntax
import Loam.ScheduledCreationPublisher
import Loam.Tui.Kernel
import Loam.Tui.LocusPicker
import Loam.Tui.Main
import Loam.Tui.Record
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.ScheduledCreation

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# New Scheduled editor

This state is presentation-only. It edits one explicit due date plus signed JPY
postings. It carries no recurrence, continuation, replacement source, routing,
or Actual evidence. Publication authority remains `ScheduledCreationPublisher`.
-/

structure Form where
  date : String
  rows : Array Loam.Tui.Record.Row := #[{}, {}]
  focus : Nat := 0
  deriving Repr, DecidableEq

inductive Mode where
  | editing
  | preview (draft : Loam.ScheduledCreationPublisher.Draft) (choice : Fin 3)

structure State where
  form : Form
  mode : Mode := .editing
  notice : String := ""
  candidateCatalog : Loam.LocusCatalog.Catalog := []
  candidateIndex : Nat := 0

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ScheduledCreationPublisher.Draft := none

/-- Seed a new Scheduled occurrence on the currently focused household date. -/
def initial (date : String) : State :=
  { form := { date := date } }

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
  if record.measure != ⟨"jpy"⟩ then
    throw "This Scheduled occurrence uses a non-JPY measure and cannot seed the JPY next-Scheduled editor."
  let rows := rowsFromScheduled record
  if rows.size < 2 then
    throw "This Scheduled occurrence is outside the practical balanced-Movement next-Scheduled editor."
  if rows.size > 6 then
    throw "This Scheduled occurrence has more than six postings; the next-Scheduled editor will not truncate it."
  pure {
    form := { date := "", rows := rows, focus := 0 }
    notice := "Completion is already published. Enter the next due date, or Esc for completion only."
  }

private def focusCount (form : Form) : Nat :=
  1 + form.rows.size * 2 + 4

private def firstAction (form : Form) : Nat :=
  1 + form.rows.size * 2

private def moveFocus (form : Form) (back : Bool) : Form :=
  let count := focusCount form
  let next := if back then (form.focus + count - 1) % count
              else (form.focus + 1) % count
  { form with focus := next }

private def replaceRows (form : Form) (rows : Array Loam.Tui.Record.Row) : Form :=
  { form with rows := rows, focus := 0 }

private def appendRow (form : Form) : Form :=
  let rows := form.rows.push {}
  { form with rows := rows, focus := 1 + form.rows.size * 2 }

private def dropRow (form : Form) : Form :=
  if form.rows.size > 2 then replaceRows form form.rows.pop else form

private def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus = 0 then
    { form with date := edit form.date }
  else
    let offset := form.focus - 1
    let index := offset / 2
    if h : index < form.rows.size then
      let row := form.rows[index]
      let row := if offset % 2 = 0
        then { row with locus := edit row.locus }
        else { row with amount := edit row.amount }
      { form with rows := form.rows.set index row }
    else form

private def activeLocus? (form : Form) : Option String := do
  if form.focus = 0 then none else do
    let offset := form.focus - 1
    if offset % 2 != 0 then none else do
      let row ← form.rows[offset / 2]?
      some row.locus

private def catalogCandidates (state : State) : Loam.LocusCatalog.Catalog :=
  match activeLocus? state.form with
  | none => []
  | some entered => Loam.Tui.LocusPicker.candidates state.candidateCatalog entered

private def selectedCatalogCandidate? (state : State) : Option Loam.LocusCatalog.Entry :=
  match activeLocus? state.form with
  | none => none
  | some entered =>
      Loam.Tui.LocusPicker.selected? state.candidateCatalog entered state.candidateIndex

private def moveCandidate (state : State) (back : Bool) : State :=
  match activeLocus? state.form with
  | none => { state with candidateIndex := 0 }
  | some entered =>
      { state with candidateIndex :=
          Loam.Tui.LocusPicker.move state.candidateCatalog entered state.candidateIndex back }

private def acceptSelectedCandidate (state : State) : State :=
  match selectedCatalogCandidate? state with
  | none => state
  | some entry =>
      { state with
          form := editActive state.form (fun _ => entry.locus.token)
          candidateIndex := 0 }

/-- Pure advisory parsing before preview; the shared publisher re-validates under ownership. -/
def draft? (state : State) : Except String Loam.ScheduledCreationPublisher.Draft := do
  if !Loam.ActualDate.validIsoDate state.form.date then
    throw "Scheduled date must be a real calendar date in YYYY-MM-DD form."
  let mut effects : List Effect := []
  let mut positive := 0
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    let some amount := row.amount.toInt?
      | throw "Enter a nonzero signed integer JPY amount for every posting."
    if amount = 0 then
      throw "Enter a nonzero signed integer JPY amount for every posting."
    if !Loam.Persistence.validToken row.locus then
      throw "Enter a valid Locus token for every posting."
    effects := effects ++ [Effect.ofQuantity
      ⟨"scheduled-create-effect-" ++ toString (index + 1)⟩ ⟨row.locus⟩ ⟨"jpy"⟩
      (Quantity.ofQuanta amount)]
    if amount > 0 then positive := positive + amount
  let changes : List (MovementChange LocusId) :=
    effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  if (BalancedMovement.ofChanges? ⟨"jpy"⟩ changes).isNone then
    throw "Scheduled posting totals differ."
  if positive <= 0 then
    throw "Scheduled creation requires a positive balanced total."
  pure {
    scheduledOn := state.form.date
    effects := effects
    total := positive
  }

private def preview (state : State) : State :=
  match draft? state with
  | .error message => { state with notice := message }
  | .ok draft => { state with mode := .preview draft ⟨0, by omega⟩, notice := "" }

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
        | .tab => { state := { state with form := moveFocus state.form false, candidateIndex := 0 } }
        | .shiftTab => { state := { state with form := moveFocus state.form true, candidateIndex := 0 } }
        | .backspace =>
            { state := { state with
                form := editActive state.form (fun text => String.ofList text.toList.dropLast)
                notice := "", candidateIndex := 0 } }
        | .input char =>
            { state := { state with
                form := editActive state.form (fun text => text.push char)
                notice := "", candidateIndex := 0 } }
        | .up => { state := moveCandidate state true }
        | .down => { state := moveCandidate state false }
        | .right => { state := acceptSelectedCandidate state }
        | .enter =>
            let action := firstAction state.form
            let focus := state.form.focus
            if focus + 1 = action then
              { state := preview state }
            else if focus < action then
              { state := { state with form := moveFocus state.form false, candidateIndex := 0 } }
            else if focus = action && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else if focus = action then
              { state := { state with form := appendRow state.form, candidateIndex := 0 } }
            else if focus = action + 1 then
              { state := { state with form := dropRow state.form, candidateIndex := 0 } }
            else if focus = action + 2 then
              { state := preview state }
            else
              { state, cancel := true }
        | _ => { state }

/-- Failed shared publication returns to editable local evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget := .row [span text]

private def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus = index then .selected else .normal)]

/-- Creation exposes only Scheduled content and does not invent an Actual description. -/
def view (_known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing =>
      let form := state.form
      let activeRow := (form.focus - 1) / 2
      let start := if activeRow < form.rows.size then activeRow - 3 else form.rows.size - 6
      let rowLines := ((List.range form.rows.size).drop start |>.take 6).flatMap fun index =>
        let row := form.rows[index]!
        [ field form (1 + index * 2) ("Posting " ++ toString (index + 1)) row.locus
        , field form (2 + index * 2) "  JPY" row.amount
        ]
      let actions := ["Add posting", "Drop last row", "Preview", "Cancel"]
      let options := catalogCandidates state
      let selectedIndex := if options.isEmpty then 0 else state.candidateIndex % options.length
      let candidateStart := if selectedIndex < 5 then 0 else selectedIndex - 4
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
              (if form.focus = firstAction form + index then .selected else .normal))
        , line "Locus catalog:"
        ] ++ candidateLines ++ helpLine ++
        [ line "Signed JPY postings describe one independent expected movement."
        , line "No recurrence, continuation, replacement relation, or Actual is created."
        , line "Tab / Shift-Tab focus   Enter next/preview/action"
        , line "Up / Down choose Locus   Right accept Locus"
        , line "Esc cancel   Backspace delete   Drop keeps at least two postings"
        , line state.notice
        ]
  | .preview draft choice =>
      .column <|
        [ line "Scheduled / New / Preview"
        , line ("Due: " ++ draft.scheduledOn)
        ] ++
        (draft.effects.take 12).map (fun effect =>
          line (effect.locus.token ++ "  " ++ toString effect.quantity.quanta ++ " jpy")) ++
        [ line ("Balanced total: " ++ toString draft.total ++ " jpy")
        , line "Publish appends one independent Scheduled occurrence."
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice.val = index then .selected else .normal))
        , line "Tab / Shift-Tab select   Enter confirm   Esc cancel"
        , line state.notice
        ]

end Loam.Tui.ScheduledCreation