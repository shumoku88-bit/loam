import Loam.ActualDate
import Loam.Persistence
import Loam.ScheduledReplacementPublisher
import Loam.Tui.Main
import Loam.Tui.Record
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.ScheduledReplacement

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected Scheduled replacement editor

This state is presentation-only. It edits exactly the retained replacement content:
one date plus signed JPY postings. It deliberately has no Actual description,
Movement Event, recurrence, continuation, or routing state. Publication authority
remains `ScheduledReplacementPublisher`, which re-reads current Scheduled and
Movement evidence under ownership.
-/

structure Form where
  date : String
  rows : Array Loam.Tui.Record.Row
  focus : Nat := 0
  deriving Repr, DecidableEq

inductive Mode where
  | editing
  | preview (draft : Loam.ScheduledReplacementPublisher.Draft) (choice : Fin 3)

structure State where
  target : ScheduledId
  originalOn : String
  form : Form
  mode : Mode := .editing
  notice : String := ""

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ScheduledReplacementPublisher.Draft := none

private def rowsFromScheduled
    (record : Loam.Tui.Main.ScheduledRecord) : Array Loam.Tui.Record.Row :=
  (record.movement.changes.map fun change =>
    ({ locus := change.coordinate.token,
       amount := toString change.quantity.quanta } : Loam.Tui.Record.Row)).toArray

/-- Seed replacement content from one visible current-open Scheduled occurrence. -/
def initial?
    (record : Loam.Tui.Main.ScheduledRecord) : Except String State := do
  if record.measure != ⟨"jpy"⟩ then
    throw "This Scheduled occurrence uses a non-JPY measure and cannot be represented by the JPY replacement editor."
  let rows := rowsFromScheduled record
  if rows.size < 2 then
    throw "This Scheduled occurrence is outside the practical balanced replacement editor."
  if rows.size > 6 then
    throw "This Scheduled occurrence has more than six postings; this replacement editor will not truncate it."
  pure {
    target := record.id
    originalOn := record.scheduledOn
    form := { date := record.scheduledOn, rows := rows }
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

private def candidate? (known : List String) (form : Form) : Option String := do
  let entered ← activeLocus? form
  known.find? fun token => entered.isPrefixOf token && token != entered

private def acceptCandidate (known : List String) (form : Form) : Form :=
  match candidate? known form with
  | none => form
  | some token => editActive form (fun _ => token)

/--
Parse the local form and perform advisory pure checks before preview. The shared
publisher repeats authoritative validation under ownership, so this helper is not
a second write authority.
-/
def draft? (state : State) : Except String Loam.ScheduledReplacementPublisher.Draft := do
  if !Loam.ActualDate.validIsoDate state.form.date then
    throw "Replacement date must be a real calendar date in YYYY-MM-DD form."
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
      ⟨"replacement-effect-" ++ toString (index + 1)⟩ ⟨row.locus⟩ ⟨"jpy"⟩
      (Quantity.ofQuanta amount)]
    if amount > 0 then positive := positive + amount
  let changes : List (MovementChange LocusId) :=
    effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  if (BalancedMovement.ofChanges? ⟨"jpy"⟩ changes).isNone then
    throw "Scheduled replacement posting totals differ."
  if positive <= 0 then
    throw "Scheduled replacement requires a positive balanced total."
  pure {
    source := state.target
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
        | .tab => { state := { state with form := moveFocus state.form false } }
        | .shiftTab => { state := { state with form := moveFocus state.form true } }
        | .backspace =>
            { state := { state with
                form := editActive state.form (fun text => String.ofList text.toList.dropLast)
                notice := "" } }
        | .input char =>
            { state := { state with
                form := editActive state.form (fun text => text.push char)
                notice := "" } }
        | .right => { state := { state with form := acceptCandidate known state.form } }
        | .enter =>
            let action := firstAction state.form
            let focus := state.form.focus
            if focus + 1 = action then
              { state := preview state }
            else if focus < action then
              { state := { state with form := moveFocus state.form false } }
            else if focus = action && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else if focus = action then
              { state := { state with form := appendRow state.form } }
            else if focus = action + 1 then
              { state := { state with form := dropRow state.form } }
            else if focus = action + 2 then
              { state := preview state }
            else
              { state, cancel := true }
        | _ => { state }

/-- Failed shared publication returns to editable replacement evidence. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget := .row [span text]

private def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus = index then .selected else .normal)]

/-- Replacement exposes only Scheduled content, never an invented Actual description. -/
def view (known : List String) (state : State) : Widget :=
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
      .column <|
        [ line "Scheduled / Supersede / Edit replacement"
        , line ("Source: " ++ state.target.token ++ "   Original due: " ++ state.originalOn)
        , field form 0 "Replacement due" form.date
        ] ++ rowLines ++
        [ .row ((actions.zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if form.focus = firstAction form + index then .selected else .normal))
        , line ("Candidate: " ++ (candidate? known form).getD "")
        , line "Signed JPY postings are editable replacement content; no Actual is created."
        , line "Tab / Shift-Tab focus   Enter next/preview/action   Right accept candidate"
        , line "Esc cancel   Backspace delete   Drop keeps at least two postings"
        , line state.notice
        ]
  | .preview draft choice =>
      .column <|
        [ line "Scheduled / Supersede / Preview"
        , line ("Source: " ++ state.target.token)
        , line ("Replacement due: " ++ draft.scheduledOn)
        ] ++
        (draft.effects.take 12).map (fun effect =>
          line (effect.locus.token ++ "  " ++ toString effect.quantity.quanta ++ " jpy")) ++
        [ line ("Balanced total: " ++ toString draft.total ++ " jpy")
        , line "Publish appends an explicit Scheduled replacement relation plus its endpoint."
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice.val = index then .selected else .normal))
        , line "Tab / Shift-Tab select   Enter confirm   Esc cancel"
        , line state.notice
        ]

end Loam.Tui.ScheduledReplacement
