import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.MovementAdmission
import Loam.Persistence.TokenSyntax
import Loam.Tui.CyclicIndex
import Loam.Tui.Kernel
import Loam.Tui.LocusPicker
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega
import Loam.Tui.Layout

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
  measure : String := "jpy"
  rows : Array Row := #[{}, {}]
  -- Date, description, Measure, two fields per row, then four actions.
  focus : Fin (3 + rows.size * 2 + 4) := ⟨0, by omega⟩

inductive Mode where
  | editing
  | preview (draft : Loam.MovementAdmission.Draft) (choice : Fin 3)

structure State where
  form : Form
  mode : Mode := .editing
  notice : String := ""
  /-- Human-facing overlay scoped to exactly the current admitted vocabulary. -/
  candidateCatalog : Loam.LocusCatalog.Catalog := []
  /-- Presentation-only cursor within the currently filtered Locus candidates. -/
  candidateIndex : Nat := 0
  /-- Optional exact fixed-point rendering/parsing convention per Measure. -/
  measurePresentation : List Loam.MeasurePresentation.Metadata := []

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.MovementAdmission.Draft := none

def initial (date : String) : State := { form := { date := date } }

/-- Attach replaceable Locus display metadata without granting any write permission. -/
def withCatalog (state : State) (catalog : Loam.LocusCatalog.Catalog) : State :=
  { state with candidateCatalog := catalog, candidateIndex := 0 }

/-- Attach an optional fixed-point Measure presentation convention. -/
def withMeasurePresentation
    (state : State) (metadata : List Loam.MeasurePresentation.Metadata) : State :=
  { state with measurePresentation := metadata }

def moveFocus (form : Form) (back : Bool) : Form :=
  let count := 3 + form.rows.size * 2 + 4
  have hcount : 0 < count := by
    dsimp [count]
    omega
  let next :=
    if back then Loam.Tui.CyclicIndex.backward count form.focus.val
    else Loam.Tui.CyclicIndex.forward count form.focus.val
  have hnext : next < count := by
    dsimp [next]
    split
    · exact Loam.Tui.CyclicIndex.backward_lt count form.focus.val hcount
    · exact Loam.Tui.CyclicIndex.forward_lt count form.focus.val hcount
  { form with focus := ⟨next, by simpa [count] using hnext⟩ }

def replaceRows (form : Form) (rows : Array Row) : Form :=
  { date := form.date, description := form.description, measure := form.measure,
    rows := rows, focus := ⟨0, by omega⟩ }

/-- Append one neutral posting row and put focus directly on its Locus field. -/
def appendRow (form : Form) : Form :=
  let rows := form.rows.push {}
  { date := form.date, description := form.description, measure := form.measure,
    rows := rows,
    focus := ⟨3 + form.rows.size * 2, by simp [rows]; omega⟩ }

def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus.val = 0 then { form with date := edit form.date }
  else if form.focus.val = 1 then { form with description := edit form.description }
  else if form.focus.val = 2 then { form with measure := edit form.measure }
  else
    let index := (form.focus.val - 3) / 2
    if h : index < form.rows.size then
      let row := form.rows[index]
      let row := if (form.focus.val - 3) % 2 = 0
        then { row with locus := edit row.locus }
        else { row with amount := edit row.amount }
      { form with
        rows := form.rows.set index row,
        focus := ⟨form.focus.val, by simpa using form.focus.isLt⟩ }
    else form

def activeLocus? (form : Form) : Option String := do
  if form.focus.val < 3 || (form.focus.val - 3) % 2 != 0 then none else do
    let row ← form.rows[(form.focus.val - 3) / 2]?
    some row.locus

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
def moveCandidate (state : State) (back : Bool) : State :=
  match activeLocus? state.form with
  | none => { state with candidateIndex := 0 }
  | some entered =>
      { state with candidateIndex :=
          Loam.Tui.LocusPicker.move state.candidateCatalog entered state.candidateIndex back }

/-- Accept exactly the currently selected catalog candidate. -/
def acceptSelectedCandidate (state : State) : State :=
  match selectedCatalogCandidate? state with
  | none => state
  | some entry =>
      { state with
          form := editActive state.form (fun _ => entry.locus.token)
          candidateIndex := 0 }

/-- Accept candidate and advance focus to the Amount field. If a candidate is selected, use it;
    otherwise use the first filtered candidate if available. If the typed text is already an
    exact matching token and the candidate cursor has not moved, preserve the typed token. -/
def acceptCandidateAndAdvance (state : State) : State :=
  match activeLocus? state.form with
  | some entered =>
      if state.candidateIndex == 0 && (Loam.LocusCatalog.exactToken? state.candidateCatalog entered).isSome then
        { state with form := moveFocus state.form false, candidateIndex := 0 }
      else
        match selectedCatalogCandidate? state with
        | some entry =>
            let state' := { state with
              form := editActive state.form (fun _ => entry.locus.token),
              candidateIndex := 0 }
            { state' with form := moveFocus state'.form false }
        | none =>
            match (catalogCandidates state).head? with
            | some entry =>
                let state' := { state with
                  form := editActive state.form (fun _ => entry.locus.token),
                  candidateIndex := 0 }
                { state' with form := moveFocus state'.form false }
            | none =>
                { state with form := moveFocus state.form false, candidateIndex := 0 }
  | none =>
      { state with form := moveFocus state.form false, candidateIndex := 0 }

private def draftUsingPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (form : Form) : Except String Loam.MovementAdmission.Draft := do
  if !Loam.Persistence.validToken form.measure then
    throw "Enter a nonempty single-line Measure token."
  let measure : Loam.Core.MeasureId := ⟨form.measure⟩
  let scale := Loam.MeasurePresentation.scaleFor metadata measure
  let mut effects := []
  let mut total := 0
  for index in List.range form.rows.size do
    let row := form.rows[index]!
    let some amount := Loam.MeasurePresentation.parseQuanta? metadata measure row.amount
      | throw
          ("Enter a nonzero signed " ++ form.measure ++ " amount with at most " ++
            toString scale ++ " decimal places for every posting.")
    if amount = 0 then
      throw
        ("Enter a nonzero signed " ++ form.measure ++ " amount with at most " ++
          toString scale ++ " decimal places for every posting.")
    effects := effects ++ [Loam.Core.Effect.ofQuantity
      ⟨"effect-" ++ toString (index + 1)⟩ ⟨row.locus⟩ measure
      (Loam.Core.Quantity.ofQuanta amount)]
    if amount > 0 then total := total + amount
  let draft : Loam.MovementAdmission.Draft := {
    validOn := form.date
    description := if form.description.isEmpty then none else some form.description
    effects := effects, relations := [], discharges := [], total := total }
  Loam.MovementAdmission.validateDraft draft
  pure draft

/-- Historical scale-0 parser retained for low-level callers and tests. -/
def draft? (form : Form) : Except String Loam.MovementAdmission.Draft :=
  draftUsingPresentation? [] form

/-- Parse local signed posting syntax under one explicit Measure presentation convention. -/
def draftWithPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (form : Form) : Except String Loam.MovementAdmission.Draft :=
  draftUsingPresentation? metadata form

/-- Ordinary Locus token used by the TUI for explicitly unresolved classification. -/
def unresolvedLocus : Loam.Core.LocusId := ⟨"suspense"⟩

private def formAtPreview (form : Form) (rows : Array Row) : Form :=
  { date := form.date
    description := form.description
    measure := form.measure
    rows := rows
    focus := ⟨3 + rows.size * 2, by omega⟩ }

/--
Fill or adjust one ordinary `suspense` posting so the currently completed rows
balance exactly.

This is presentation assistance only. It does not weaken Movement admission,
create a new semantic type, or publish Locus policy. The ordinary `suspense`
Locus must already be admitted for new writes, and the resulting draft still
passes the same preview and publication admission as every other Movement.
-/
def fillUnresolvedRemainder?
    (world : Loam.MovementAdmission.World)
    (state : State) : Except String State := do
  if !Loam.Persistence.validToken state.form.measure then
    throw "Enter a valid Measure before filling the unresolved remainder."
  if !world.locusAdmission.allows unresolvedLocus then
    throw
      "Unresolved recording is not enabled yet. Admit the 'suspense' Locus first."
  let measure : Loam.Core.MeasureId := ⟨state.form.measure⟩
  let mut signedTotal : Int := 0
  let mut unresolvedCount : Nat := 0
  let mut unresolvedIndex : Option Nat := none
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    if !Loam.Persistence.validToken row.locus then
      throw "Complete every current Locus before filling the unresolved remainder."
    if !world.locusAdmission.allows ⟨row.locus⟩ then
      throw "Every current posting must use an admitted Locus."
    let some amount :=
        Loam.MeasurePresentation.parseQuanta?
          state.measurePresentation measure row.amount
      | throw
          "Complete every current nonzero amount before filling the unresolved remainder."
    if amount = 0 then
      throw
        "Complete every current nonzero amount before filling the unresolved remainder."
    signedTotal := signedTotal + amount
    if row.locus == unresolvedLocus.token then
      unresolvedCount := unresolvedCount + 1
      unresolvedIndex := some index
  if unresolvedCount > 1 then
    throw "Keep at most one unresolved posting before using this action."
  if signedTotal = 0 then
    throw "This Movement is already balanced; there is no unresolved remainder."
  let adjustment := -signedTotal
  let rows ←
    match unresolvedIndex with
    | none =>
        if state.form.rows.size >= 6 then
          throw "No row is available for the unresolved remainder."
        pure <| state.form.rows.push {
          locus := unresolvedLocus.token
          amount := Loam.MeasurePresentation.formatQuanta
            state.measurePresentation measure adjustment }
    | some index =>
        if h : index < state.form.rows.size then
          let row := state.form.rows[index]
          let some current :=
              Loam.MeasurePresentation.parseQuanta?
                state.measurePresentation measure row.amount
            | throw "The existing unresolved amount is not valid."
          let adjusted := current + adjustment
          if adjusted = 0 then
            pure <| state.form.rows.filter fun item =>
              item.locus != unresolvedLocus.token
          else
            pure <| state.form.rows.set index {
              row with amount := Loam.MeasurePresentation.formatQuanta
                state.measurePresentation measure adjusted }
        else
          throw "The unresolved posting index is no longer present."
  pure {
    state with
    form := formAtPreview state.form rows
    candidateIndex := 0
    notice := "" }

def preview (world : Loam.MovementAdmission.World) (state : State) : State :=
  match draftWithPresentation? state.measurePresentation state.form with
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
  let catalog :=
    if state.candidateCatalog.isEmpty then Loam.LocusCatalog.fallback world.locusAdmission
    else Loam.LocusCatalog.restrict world.locusAdmission state.candidateCatalog
  let state := { state with candidateCatalog := catalog }
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
        | .ctrl 'u' =>
            match fillUnresolvedRemainder? world state with
            | .ok next => { state := next }
            | .error message => { state := { state with notice := message } }
        | .ctrl 'n' =>
            if state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else
              { state := { state with form := appendRow state.form, candidateIndex := 0, notice := "" } }
        | .ctrl 'd' =>
            { state := { state with form := dropRow state.form, candidateIndex := 0, notice := "" } }
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
        | .up => { state := moveCandidate state true }
        | .down => { state := moveCandidate state false }
        | .right => { state := acceptCandidateAndAdvance state }
        | .enter =>
            let firstAction := 3 + state.form.rows.size * 2
            let focus := state.form.focus.val
            if activeLocus? state.form != none then
              { state := acceptCandidateAndAdvance state }
            else if focus + 1 = firstAction then
              { state := preview world state }
            else if focus < firstAction then
              { state := { state with form := moveFocus state.form false, candidateIndex := 0 } }
            else if focus = firstAction then
              { state := preview world state }
            else if focus = firstAction + 1 && state.form.rows.size >= 6 then
              { state := { state with notice := "This editor supports up to six posting rows." } }
            else if focus = firstAction + 1 then
              { state := { state with form := appendRow state.form, candidateIndex := 0 } }
            else if focus = firstAction + 2 then
              { state := { state with form := dropRow state.form, candidateIndex := 0 } }
            else { state, cancel := true }
        | _ => { state }

theorem cancel_never_publishes (world : Loam.MovementAdmission.World)
    (known : List String) (state : State) :
    (update world known state .escape).publish = none := by rfl

theorem focus_always_exists (form : Form) :
    form.focus.val < 3 + form.rows.size * 2 + 4 := form.focus.isLt

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
  let activeRow := (form.focus.val - 3) / 2
  let start := if activeRow < form.rows.size then activeRow - 3 else form.rows.size - 6
  ((List.range form.rows.size).drop start |>.take 6).flatMap fun index =>
    let row := form.rows[index]!
    [ field form (3 + index * 2) ("Posting " ++ toString (index + 1)) row.locus
    , field form (4 + index * 2) ("  " ++ form.measure) row.amount
    ]

def view (_known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing =>
      let form := state.form
      let rowLines := postingFieldLines form
      let actions := ["Preview", "Add posting", "Drop last row", "Cancel"]
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
        field form 1 "Description" form.description,
        field form 2 "Measure" form.measure] ++ rowLines ++
        [.row ((actions.zipIdx).map fun (label, index) =>
          span ("[" ++ label ++ "] ")
            (if form.focus.val = 3 + form.rows.size * 2 + index then .selected else .normal)),
         line "Locus catalog:"] ++ candidateLines ++ helpLine ++
        [line ("Posting " ++ form.measure ++ " is signed; decimal input follows the Measure presentation scale."),
         line "Tab / Shift-Tab focus   Enter accept candidate / next / preview",
         line "Up / Down choose candidate   Ctrl-U fill unresolved remainder",
         line "Ctrl-N add row   Ctrl-D drop row",
         line "Esc cancel   Backspace delete   Drop keeps at least two postings",
         line state.notice]
  | .preview draft choice =>
      let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
      .column <| [line "Record / Preview", line draft.validOn,
        line ("Measure: " ++ measure.token),
        line (draft.description.getD "(no description)")] ++
        (draft.effects.take 12).map (fun effect =>
          line (Loam.Tui.Layout.padRight 20 effect.locus.token ++
            Loam.Tui.Layout.padLeft 10
              (Loam.MeasurePresentation.formatQuanta
                state.measurePresentation effect.measure effect.quantity.quanta) ++
            " " ++ effect.measure.token)) ++
        [line ("Balanced total: " ++
            Loam.MeasurePresentation.formatQuanta
              state.measurePresentation measure draft.total ++ " " ++ measure.token),
         line "Publication rechecks current evidence and Locus admission.",
         .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
           span ("[" ++ label ++ "] ") (if choice.val = index then .selected else .normal)),
         line "Tab / Shift-Tab select   Enter confirm   Esc cancel", line state.notice]

end Loam.Tui.Record
