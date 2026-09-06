import Loam.MovementAdmission
import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.Record
open Loam.Tui.Kernel
set_option autoImplicit false

/-- FROM/TO is form grammar only. It becomes ordinary signed Effects. -/
structure Row where
  fromSide : Bool
  locus : String := ""
  amount : String := ""
  deriving Repr, DecidableEq, Inhabited

structure Form where
  date : String
  description : String := ""
  rows : Array Row := #[{ fromSide := true }, { fromSide := false }]
  -- Date, description, two fields per row, then five actions.
  focus : Fin (2 + rows.size * 2 + 5) := ⟨0, by omega⟩

inductive Mode where
  | editing
  | preview (draft : Loam.MovementAdmission.Draft) (choice : Fin 3)

structure State where
  form : Form
  mode : Mode := .editing
  notice : String := ""

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.MovementAdmission.Draft := none

def initial (date : String) : State := { form := { date := date } }

def moveFocus (form : Form) (back : Bool) : Form :=
  let count := 2 + form.rows.size * 2 + 5
  let next := if back then (form.focus.val + count - 1) % count
              else (form.focus.val + 1) % count
  { form with focus := ⟨next, by
      dsimp [next]
      split <;> exact Nat.mod_lt _ (by dsimp [count]; omega)⟩ }

def replaceRows (form : Form) (rows : Array Row) : Form :=
  { date := form.date, description := form.description, rows := rows,
    focus := ⟨0, by omega⟩ }

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
      { form with rows := form.rows.set index row,
        focus := ⟨form.focus.val, by simpa using form.focus.isLt⟩ }
    else form

def activeLocus? (form : Form) : Option String := do
  if form.focus.val < 2 || (form.focus.val - 2) % 2 != 0 then none else do
    let row ← form.rows[(form.focus.val - 2) / 2]?
    some row.locus

def candidate? (known : List String) (form : Form) : Option String := do
  let entered ← activeLocus? form
  known.find? fun token => entered.isPrefixOf token && token != entered

/-- Candidates change only the focused text field and carry no write authority. -/
def acceptCandidate (known : List String) (form : Form) : Form :=
  match candidate? known form with
  | none => form
  | some token => editActive form (fun _ => token)

/-- Parse form syntax; semantic validation and admission remain shared production code. -/
def draft? (form : Form) : Except String Loam.MovementAdmission.Draft := do
  let mut effects := []
  let mut total := 0
  for index in List.range form.rows.size do
    let row := form.rows[index]!
    let some amount := row.amount.toInt?
      | throw "Enter a positive integer amount for every row."
    if amount <= 0 then throw "Enter a positive integer amount for every row."
    let quantity := if row.fromSide then -amount else amount
    effects := effects ++ [Loam.Core.Effect.ofQuantity
      ⟨"effect-" ++ toString (index + 1)⟩ ⟨row.locus⟩ ⟨"jpy"⟩
      (Loam.Core.Quantity.ofQuanta quantity)]
    if !row.fromSide then total := total + amount
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
      | .ok _ => { state with mode := .preview draft ⟨0, by omega⟩, notice := "" }

def dropRow (form : Form) : Form :=
  -- The action removes the last row; at least one row on each side remains.
  match form.rows.back? with
  | none => form
  | some last =>
      if (form.rows.toList.filter fun row => row.fromSide == last.fromSide).length > 1 then
        replaceRows form form.rows.pop
      else form

def update (world : Loam.MovementAdmission.World) (known : List String)
    (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
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
        | .tab => { state := { state with form := moveFocus state.form false } }
        | .shiftTab => { state := { state with form := moveFocus state.form true } }
        | .backspace =>
            { state := { state with form := editActive state.form
                (fun text => String.ofList (text.toList.dropLast)), notice := "" } }
        | .input char =>
            { state := { state with form := editActive state.form (fun text => text.push char), notice := "" } }
        | .right => { state := { state with form := acceptCandidate known state.form } }
        | .enter =>
            let firstAction := 2 + state.form.rows.size * 2
            let focus := state.form.focus.val
            if focus < firstAction then
              { state := { state with form := moveFocus state.form false } }
            else if (focus = firstAction || focus = firstAction + 1) && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six effect rows." } }
            else if focus = firstAction then
              { state := { state with form := replaceRows state.form
                  (state.form.rows.push { fromSide := true }) } }
            else if focus = firstAction + 1 then
              { state := { state with form := replaceRows state.form
                  (state.form.rows.push { fromSide := false }) } }
            else if focus = firstAction + 2 then
              { state := { state with form := dropRow state.form } }
            else if focus = firstAction + 3 then
              { state := preview world state }
            else { state, cancel := true }
        | _ => { state }

theorem cancel_never_publishes (world : Loam.MovementAdmission.World)
    (known : List String) (state : State) :
    (update world known state .escape).publish = none := by rfl

theorem focus_always_exists (form : Form) :
    form.focus.val < 2 + form.rows.size * 2 + 5 := form.focus.isLt

theorem preview_edit_preserves_form (world : Loam.MovementAdmission.World)
    (known : List String) (state : State) (draft : Loam.MovementAdmission.Draft) :
    (update world known { state with mode := .preview draft ⟨1, by omega⟩ } .enter).state.form =
      state.form := by rfl

def line (text : String) : Widget := .row [span text]
def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus.val = index then .selected else .normal)]

def view (known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing =>
      let form := state.form
      let activeRow := (form.focus.val - 2) / 2
      let start := if activeRow < form.rows.size then activeRow - 3 else form.rows.size - 6
      let rowLines := ((List.range form.rows.size).drop start |>.take 6).flatMap fun index =>
        let row := form.rows[index]!
        [field form (2 + index * 2) (if row.fromSide then "FROM" else "TO") row.locus,
         field form (3 + index * 2) "  JPY" row.amount]
      let actions := ["Add FROM", "Add TO", "Drop last row", "Preview", "Cancel"]
      .column <| [line "Record / Edit", field form 0 "Date" form.date,
        field form 1 "Description" form.description] ++ rowLines ++
        [.row ((actions.zipIdx).map fun (label, index) =>
          span ("[" ++ label ++ "] ")
            (if form.focus.val = 2 + form.rows.size * 2 + index then .selected else .normal)),
         line ("Candidate: " ++ (candidate? known form).getD ""),
         line "Tab / Shift-Tab focus   Enter next/action   Right accept candidate",
         line "Esc cancel   Backspace delete   Drop keeps one FROM and one TO",
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
