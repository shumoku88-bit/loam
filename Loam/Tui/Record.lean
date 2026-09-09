import Loam.LocusCatalog
import Loam.MovementAdmission
import Loam.Tui.Kernel
import Loam.Tui.LocusPicker
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.Record
open Loam.Tui.Kernel
set_option autoImplicit false

/-- One local editor row. Quantity text is signed; row order carries no meaning. -/
structure Row where
  locus : String := ""
  amount : String := ""
  deriving Repr, DecidableEq, Inhabited

structure Form where
  date : String
  description : String := ""
  rows : Array Row := #[{}, {}]
  -- Date, description, two fields per row, then four actions.
  focus : Fin (2 + rows.size * 2 + 4) := ⟨0, by omega⟩

inductive Mode where
  | editing
  | preview (draft : Loam.MovementAdmission.Draft) (choice : Fin 3)

structure State where
  form : Form
  mode : Mode := .editing
  notice : String := ""
  /-- Backwards-compatible token-only presentation copy of current admission. -/
  candidateVocabulary : List String := []
  /-- Human-facing overlay scoped to exactly the current admitted vocabulary. -/
  candidateCatalog : Loam.LocusCatalog.Catalog := []
  /-- Presentation-only cursor within the currently filtered Locus candidates. -/
  candidateIndex : Nat := 0

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.MovementAdmission.Draft := none

def initial (date : String) : State := { form := { date := date } }

/-- Attach replaceable display metadata without granting any write permission. -/
def withCatalog (state : State) (catalog : Loam.LocusCatalog.Catalog) : State :=
  { state with candidateCatalog := catalog, candidateIndex := 0 }

def moveFocus (form : Form) (back : Bool) : Form :=
  let count := 2 + form.rows.size * 2 + 4
  let next := if back then (form.focus.val + count - 1) % count
              else (form.focus.val + 1) % count
  { form with focus := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by dsimp [count]; omega)⟩ }

def replaceRows (form : Form) (rows : Array Row) : Form :=
  { date := form.date, description := form.description, rows := rows,
    focus := ⟨0, by omega⟩ }

/-- Append one neutral posting row and put focus directly on its Locus field. -/
def appendRow (form : Form) : Form :=
  let rows := form.rows.push {}
  { date := form.date, description := form.description, rows := rows,
    focus := ⟨2 + form.rows.size * 2, by simp [rows]; omega⟩ }

def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus.val = 0 then { form with date := edit form.date }
  else if form.focus.val = 1 then { form with description := edit form.description }
  else
    let index := (form.focus.val - 2) / 2
    if h : index < form.rows.size then
      let row := form.rows[index]
      let row := if (form.focus.val - 2) % 2 = 0
        then { row with locus := edit row.locus }
        else { row with amount := edit row.amount }
      { form with
        rows := form.rows.set index row,
        focus := ⟨form.focus.val, by simpa using form.focus.isLt⟩ }
    else form

def activeLocus? (form : Form) : Option String := do
  if form.focus.val < 2 || (form.focus.val - 2) % 2 != 0 then none else do
    let row ← form.rows[(form.focus.val - 2) / 2]?
    some row.locus

/-- Legacy token-only prefix helper retained for the smaller editors during cutover. -/
def candidates (known : List String) (form : Form) : List String :=
  match activeLocus? form with
  | none => []
  | some entered => known.filter fun token => entered.isPrefixOf token && token != entered

/-- Backwards-compatible first token-only match. -/
def candidate? (known : List String) (form : Form) : Option String :=
  (candidates known form).head?

/-- Backwards-compatible token-only cursor helper. -/
def selectedCandidate? (known : List String) (state : State) : Option String :=
  let options := candidates known state.form
  if options.isEmpty then none
  else options[state.candidateIndex % options.length]?

/-- Backwards-compatible token-only completion helper. -/
def acceptCandidate (known : List String) (form : Form) : Form :=
  match candidate? known form with
  | none => form
  | some token => editActive form (fun _ => token)

/-- Current human-facing candidates for the focused Locus. Empty text lists all admitted entries. -/
def catalogCandidates (state : State) : Loam.LocusCatalog.Catalog :=
  match activeLocus? state.form with
  | none => []
  | some entered => Loam.Tui.LocusPicker.candidates state.candidateCatalog entered

/-- Selected human-facing candidate under the local cursor. -/
def selectedCatalogCandidate? (state : State) : Option Loam.LocusCatalog.Entry :=
  match activeLocus? state.form with
  | none => none
  | some entered =>
      Loam.Tui.LocusPicker.selected? state.candidateCatalog entered state.candidateIndex

/-- Move only the local candidate cursor; canonical vocabulary and form text are untouched. -/
def moveCandidate (_known : List String) (state : State) (back : Bool) : State :=
  match activeLocus? state.form with
  | none => { state with candidateIndex := 0 }
  | some entered =>
      { state with candidateIndex :=
          Loam.Tui.LocusPicker.move state.candidateCatalog entered state.candidateIndex back }

/-- Accept exactly the currently selected catalog candidate. -/
def acceptSelectedCandidate (_known : List String) (state : State) : State :=
  match selectedCatalogCandidate? state with
  | none => state
  | some entry =>
      { state with
          form := editActive state.form (fun _ => entry.locus.token)
          candidateIndex := 0 }

/-- Parse local signed posting syntax; semantic validation remains shared production code. -/
def draft? (form : Form) : Except String Loam.MovementAdmission.Draft := do
  let mut effects := []
  let mut total := 0
  for index in List.range form.rows.size do
    let row := form.rows[index]!
    let some amount := row.amount.toInt?
      | throw "Enter a nonzero signed integer JPY amount for every posting."
    if amount = 0 then throw "Enter a nonzero signed integer JPY amount for every posting."
    effects := effects ++ [Loam.Core.Effect.ofQuantity
      ⟨"effect-" ++ toString (index + 1)⟩ ⟨row.locus⟩ ⟨"jpy"⟩
      (Loam.Core.Quantity.ofQuanta amount)]
    if amount > 0 then total := total + amount
  let draft : Loam.MovementAdmission.Draft := {
    validOn := form.date
    description := if form.description.isEmpty then none else some form.description
    effects := effects, relations := [], discharges := [], total := total }
  Loam.MovementAdmission.validateDraft draft
  pure draft

def preview (world : Loam.MovementAdmission.World) (state : State) : State :=
  match draft? state.form with
  | .error message => { state with notice := message }
  | .ok draft =>
      match Loam.MovementAdmission.admit? world draft with
      | .error message => { state with notice := message }
      | .ok _ => { state with
          mode := .preview draft ⟨0, by omega⟩,
          notice := "" }

def dropRow (form : Form) : Form :=
  -- Keep two rows so an ordinary balanced movement remains visible by default.
  if form.rows.size > 2 then replaceRows form form.rows.pop else form

def update (world : Loam.MovementAdmission.World) (_known : List String)
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  let approved := world.locusAdmission.approved.map (fun locus => locus.token)
  let catalog :=
    if state.candidateCatalog.isEmpty then Loam.LocusCatalog.fallback world.locusAdmission
    else Loam.LocusCatalog.restrict world.locusAdmission state.candidateCatalog
  let state := { state with candidateVocabulary := approved, candidateCatalog := catalog }
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
                form := editActive state.form (fun text => String.ofList (text.toList.dropLast)),
                notice := "", candidateIndex := 0 } }
        | .input char =>
            { state := { state with
                form := editActive state.form (fun text => text.push char),
                notice := "", candidateIndex := 0 } }
        | .up => { state := moveCandidate approved state true }
        | .down => { state := moveCandidate approved state false }
        | .right => { state := acceptSelectedCandidate approved state }
        | .enter =>
            let firstAction := 2 + state.form.rows.size * 2
            let focus := state.form.focus.val
            if focus + 1 = firstAction then
              { state := preview world state }
            else if focus < firstAction then
              { state := { state with form := moveFocus state.form false, candidateIndex := 0 } }
            else if focus = firstAction && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else if focus = firstAction then
              { state := { state with form := appendRow state.form, candidateIndex := 0 } }
            else if focus = firstAction + 1 then
              { state := { state with form := dropRow state.form, candidateIndex := 0 } }
            else if focus = firstAction + 2 then
              { state := preview world state }
            else { state, cancel := true }
        | _ => { state }

theorem cancel_never_publishes (world : Loam.MovementAdmission.World)
    (known : List String) (state : State) :
    (update world known state .escape).publish = none := by rfl

theorem focus_always_exists (form : Form) :
    form.focus.val < 2 + form.rows.size * 2 + 4 := form.focus.isLt

theorem preview_edit_preserves_form (world : Loam.MovementAdmission.World)
    (known : List String) (state : State) (draft : Loam.MovementAdmission.Draft) :
    (update world known { state with mode := .preview draft ⟨1, by omega⟩ } .enter).state.form =
      state.form := by rfl

def line (text : String) : Widget := .row [span text]
def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus.val = index then .selected else .normal)]

/-- Render the bounded signed-posting field window shared by Record-shaped editors. -/
def postingFieldLines (form : Form) : List Widget :=
  let activeRow := (form.focus.val - 2) / 2
  let start := if activeRow < form.rows.size then activeRow - 3 else form.rows.size - 6
  ((List.range form.rows.size).drop start |>.take 6).flatMap fun index =>
    let row := form.rows[index]!
    [ field form (2 + index * 2) ("Posting " ++ toString (index + 1)) row.locus
    , field form (3 + index * 2) "  JPY" row.amount
    ]

def view (_known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing =>
      let form := state.form
      let rowLines := postingFieldLines form
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
      .column <| [line "Record / Edit", field form 0 "Date" form.date,
        field form 1 "Description" form.description] ++ rowLines ++
        [.row ((actions.zipIdx).map fun (label, index) =>
          span ("[" ++ label ++ "] ")
            (if form.focus.val = 2 + form.rows.size * 2 + index then .selected else .normal)),
         line "Locus catalog:"] ++ candidateLines ++ helpLine ++
        [line "Posting JPY is signed; negative and positive rows may appear in any order.",
         line "Tab / Shift-Tab focus   Enter next/final amount preview/action",
         line "Up / Down choose Locus   Right accept Locus",
         line "Esc cancel   Backspace delete   Drop keeps at least two postings",
         line state.notice]
  | .preview draft choice =>
      .column <| [line "Record / Preview", line draft.validOn,
        line (draft.description.getD "(no description)")] ++
        (draft.effects.take 12).map (fun effect =>
          line (effect.locus.token ++ "  " ++ toString effect.quantity.quanta ++ " jpy")) ++
        [line ("Balanced total: " ++ toString draft.total ++ " jpy"),
         line "Publication rechecks current evidence and Locus admission.",
         .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
           span ("[" ++ label ++ "] ") (if choice.val = index then .selected else .normal)),
         line "Tab / Shift-Tab select   Enter confirm   Esc cancel", line state.notice]

end Loam.Tui.Record