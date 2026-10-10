import Loam.Presentation.LocusCatalog
import Loam.Presentation.MeasurePresentation
import Loam.Application.MovementAdmission
import Loam.Persistence.TokenSyntax
import Loam.Presentation.Record
import Loam.Tui.CyclicIndex
import Loam.Tui.Kernel
import Loam.Tui.LocusPicker
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega
import Loam.Tui.Layout

namespace Loam.Tui.Record
open Loam.Tui.Kernel
set_option autoImplicit false

/-- Shared signed posting row; terminal focus remains outside this value. -/
abbrev Row := Loam.Presentation.Record.Row

structure Form where
  date : String
  description : String := ""
  measure : String := "jpy"
  rows : Array Row := #[{}, {}]
  -- Date, description, Measure, two fields per row, then four actions.
  focus : Fin (3 + rows.size * 2 + 4) := ⟨0, by omega⟩

/-- Drop terminal-only focus and expose the shared Record input boundary. -/
def input (form : Form) : Loam.Presentation.Record.Input := {
  date := form.date
  description := form.description
  measure := form.measure
  rows := form.rows
}

structure OriginalAmountValue where
  measure : Loam.Core.MeasureId
  quantity : Loam.Core.Quantity

structure OriginalAmountEditor where
  measure : String := ""
  amount : String := ""
  focus : Fin 2 := ⟨0, by omega⟩

inductive PublishIntent where
  | movement (draft : Loam.MovementAdmission.Draft)
  | movementWithOriginalAmount
      (draft : Loam.MovementAdmission.Draft)
      (original : OriginalAmountValue)

inductive Mode where
  | editing
  | enableUnresolved
  | originalAmount (editor : OriginalAmountEditor)
  | preview (draft : Loam.MovementAdmission.Draft) (choice : Fin 3)

structure State where
  form : Form
  mode : Mode := .editing
  notice : String := ""
  /-- Read-only viewport over the confirmation content; never publication input. -/
  previewScroll : Nat := 0
  /-- Human-facing overlay scoped to exactly the current admitted vocabulary. -/
  candidateCatalog : Loam.LocusCatalog.Catalog := []
  /-- Presentation-only cursor within the currently filtered Locus candidates. -/
  candidateIndex : Nat := 0
  /-- Optional exact fixed-point rendering/parsing convention per Measure. -/
  measurePresentation : List Loam.MeasurePresentation.Metadata := []
  /--
  Optional merchant/card-presented amount retained separately from the ordinary
  Movement Measure. It is presentation state until explicit publication.
  -/
  originalAmount : Option OriginalAmountValue := none

structure Step where
  state : State
  cancel : Bool := false
  enableUnresolved : Bool := false
  publish : Option PublishIntent := none

/-- Entrances already supply the selected date and default Measure; start typing at Description.
Shift-Tab still reaches Date when it needs correction. -/
def initialWithMeasure (measure : Loam.Core.MeasureId) (date : String) : State :=
  { form := { date := date, measure := measure.token, focus := ⟨1, by omega⟩ } }

/-- Backward-compatible no-configuration entrance for the current JPY household. -/
def initial (date : String) : State :=
  initialWithMeasure ⟨"jpy"⟩ date

/-- Attach replaceable Locus display metadata without granting any write permission. -/
def withCatalog (state : State) (catalog : Loam.LocusCatalog.Catalog) : State :=
  { state with candidateCatalog := catalog, candidateIndex := 0 }

/-- Attach an optional fixed-point Measure presentation convention. -/
def withMeasurePresentation
    (state : State) (metadata : List Loam.MeasurePresentation.Metadata) : State :=
  { state with measurePresentation := metadata }

private def originalEditor (state : State) : OriginalAmountEditor :=
  match state.originalAmount with
  | none => {}
  | some original => {
      measure := original.measure.token
      amount := Loam.MeasurePresentation.formatQuanta
        state.measurePresentation original.measure original.quantity.quanta
    }

private def editOriginalActive
    (editor : OriginalAmountEditor) (edit : String → String) :
    OriginalAmountEditor :=
  if editor.focus.val = 0 then
    { editor with measure := edit editor.measure }
  else
    { editor with amount := edit editor.amount }

private def moveOriginalFocus
    (editor : OriginalAmountEditor) : OriginalAmountEditor :=
  if editor.focus.val = 0 then
    { editor with focus := ⟨1, by decide⟩ }
  else
    { editor with focus := ⟨0, by decide⟩ }

def attachOriginalAmount?
    (state : State) (editor : OriginalAmountEditor) : Except String State := do
  if !Loam.Persistence.validToken editor.measure then
    throw "Enter a nonempty single-line original Measure token."
  let measure : Loam.Core.MeasureId := ⟨editor.measure⟩
  let scale := Loam.MeasurePresentation.scaleFor state.measurePresentation measure
  let some quanta :=
      Loam.MeasurePresentation.parseQuanta?
        state.measurePresentation measure editor.amount
    | throw
        ("Enter a positive original amount with at most " ++
          toString scale ++ " decimal places.")
  if quanta <= 0 then
    throw "Original amount must be positive."
  pure {
    state with
    originalAmount := some {
      measure := measure
      quantity := Loam.Core.Quantity.ofQuanta quanta
    }
    mode := .editing
    notice := ""
  }

private def publicationIntent
    (state : State) (draft : Loam.MovementAdmission.Draft) : PublishIntent :=
  match state.originalAmount with
  | none => .movement draft
  | some original => .movementWithOriginalAmount draft original

def moveFocus (form : Form) (back : Bool) : Form :=
  let count := 3 + form.rows.size * 2 + 4
  have hcount : 0 < count := by
    dsimp [count]
    omega
  let next := Loam.Tui.CyclicIndex.move count form.focus.val back
  have hnext : next < count :=
    Loam.Tui.CyclicIndex.move_lt count form.focus.val back hcount
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

/-- Compatibility entrance for existing TUI callers and tests. -/
def draft? (form : Form) : Except String Loam.MovementAdmission.Draft :=
  Loam.Presentation.Record.draft? (input form)

/-- Delegate Measure-aware draft construction to the shared Record boundary. -/
def draftWithPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (form : Form) : Except String Loam.MovementAdmission.Draft :=
  Loam.Presentation.Record.draftWithPresentation? metadata (input form)

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
    let amountText := row.amount.trimAscii.toString
    let some amount :=
        Loam.MeasurePresentation.parseQuanta?
          state.measurePresentation measure amountText
      | throw
          ("Posting " ++ toString (index + 1) ++ " amount '" ++ row.amount ++
            "' is not a valid nonzero amount for unresolved remainder assistance.")
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
          let amountText := row.amount.trimAscii.toString
          let some current :=
              Loam.MeasurePresentation.parseQuanta?
                state.measurePresentation measure amountText
            | throw
                ("The existing unresolved amount '" ++ row.amount ++ "' is not valid.")
          let adjusted := current + adjustment
          if adjusted = 0 then
            pure <| state.form.rows.filter fun item =>
              item.locus != unresolvedLocus.token
          else
            pure <| state.form.rows.set index
              ({ row with
                 amount := Loam.MeasurePresentation.formatQuanta
                   state.measurePresentation measure adjusted } : Row)
        else
          throw "The unresolved posting index is no longer present."
  pure {
    state with
    form := formAtPreview state.form rows
    candidateIndex := 0
    notice := "" }

def preview (world : Loam.MovementAdmission.World) (state : State) : State :=
  match Loam.Presentation.Record.preview?
      world state.measurePresentation (input state.form) with
  | .error message => { state with notice := message }
  | .ok preview => { state with
      mode := .preview preview.draft ⟨0, by omega⟩
      previewScroll := 0
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
    | .enableUnresolved =>
        match key with
        | .enter => { state, enableUnresolved := true }
        | .input 'e' | .input 'E' | .backspace =>
            { state := { state with mode := .editing, notice := "" } }
        | _ => { state }
    | .originalAmount editor =>
        match key with
        | .ctrl 'o' =>
            { state := { state with mode := .editing, notice := "" } }
        | .ctrl 'd' =>
            { state := { state with
                originalAmount := none
                mode := .editing
                notice := "Original amount cleared." } }
        | .tab | .shiftTab =>
            { state := { state with mode := .originalAmount (moveOriginalFocus editor), notice := "" } }
        | .backspace =>
            { state := { state with
                mode := .originalAmount
                  (editOriginalActive editor (fun text => Loam.Tui.Terminal.backspaceText text))
                notice := "" } }
        | .input char =>
            { state := { state with
                mode := .originalAmount
                  (editOriginalActive editor (fun text => text.push char))
                notice := "" } }
        | .paste text =>
            let clean := Loam.Tui.Terminal.singleLinePaste text
            { state := { state with
                mode := .originalAmount
                  (editOriginalActive editor (fun curr => curr ++ clean))
                notice := "" } }
        | .enter =>
            if editor.focus.val = 0 then
              { state := { state with
                  mode := .originalAmount (moveOriginalFocus editor)
                  notice := "" } }
            else
              match attachOriginalAmount? state editor with
              | .ok next => { state := next }
              | .error message => { state := { state with notice := message } }
        | _ => { state }
    | .preview draft choice =>
        match key with
        | .tab | .right =>
            { state := { state with mode := (.preview draft ⟨(choice.val + 1) % 3, Nat.mod_lt _ (by omega)⟩) } }
        | .shiftTab | .left =>
            { state := { state with mode := (.preview draft ⟨(choice.val + 2) % 3, Nat.mod_lt _ (by omega)⟩) } }
        | .enter =>
            if choice.val = 0 then { state, publish := some (publicationIntent state draft) }
            else if choice.val = 1 then { state := { state with mode := .editing } }
            else { state, cancel := true }
        | _ => { state }
    | .editing =>
        match key with
        | .ctrl 'o' =>
            { state := { state with
                mode := .originalAmount (originalEditor state)
                notice := "" } }
        | .ctrl 'u' =>
            if world.locusAdmission.allows unresolvedLocus then
              match fillUnresolvedRemainder? world state with
              | .ok next => { state := next }
              | .error message => { state := { state with notice := message } }
            else
              { state := { state with mode := .enableUnresolved, notice := "" } }
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
                form := editActive state.form (fun text => Loam.Tui.Terminal.backspaceText text),
                notice := "", candidateIndex := 0 } }
        | .input char =>
            { state := { state with
                form := editActive state.form (fun text => text.push char),
                notice := "", candidateIndex := 0 } }
        | .paste text =>
            let clean := Loam.Tui.Terminal.singleLinePaste text
            { state := { state with
                form := editActive state.form (fun curr => curr ++ clean),
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
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []
def field (form : Form) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if form.focus.val = index then .selected else .normal)]

private def originalField
    (editor : OriginalAmountEditor) (index : Nat) (label text : String) : Widget :=
  .row [span (label ++ ": "), span (if text.isEmpty then "_" else text)
    (if editor.focus.val = index then .selected else .normal)]

private def originalSummary (state : State) : String :=
  match state.originalAmount with
  | none => "Original amount: (none)   Ctrl-O add"
  | some original =>
      "Original amount: " ++
        Loam.MeasurePresentation.formatQuanta
          state.measurePresentation original.measure original.quantity.quanta ++
        " " ++ original.measure.token ++ "   Ctrl-O edit"

private def previewMetaRow (label value : String) : Widget :=
  .row
    [ span (Loam.Tui.Layout.padRight 13 label) .muted
    , span value
    ]

private def previewAmount
    (state : State) (measure : Loam.Core.MeasureId) (quanta : Int) : String :=
  Loam.MeasurePresentation.formatGroupedQuanta
    state.measurePresentation measure quanta

private def previewPostingRow (state : State) (effect : Loam.Core.Effect) : Widget :=
  .row
    [ span "  "
    , span (Loam.Tui.Layout.padRight (max 28 (Loam.Tui.Layout.displayWidth effect.locus.token)) effect.locus.token)
    , span (Loam.Tui.Layout.padLeft
        (max 14 (Loam.Tui.Layout.displayWidth (previewAmount state effect.measure effect.quantity.quanta)))
        (previewAmount state effect.measure effect.quantity.quanta))
    , span (" " ++ effect.measure.token) .muted
    ]

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
      let candidateStart := Loam.Tui.Layout.trailingWindowStart selectedIndex 5
      let visible := (options.drop candidateStart).take 5
      let candidateLines := if visible.isEmpty then [line "Loci: (none)"] else
        (visible.zipIdx).map fun (entry, index) =>
          let marker := if candidateStart + index = selectedIndex then "> " else "  "
          line (marker ++ Loam.Tui.LocusPicker.display entry)
      let helpLine :=
        match selectedCatalogCandidate? state with
        | some entry =>
            if entry.help.isEmpty then []
            else [blank, muted ("  ↳ " ++ entry.help)]
        | none => []
      .column <|
        [ line "Record / Edit"
        , field form 0 "Date" form.date
        , field form 1 "Description" form.description
        , field form 2 "Measure" form.measure
        , blank
        ] ++
        rowLines ++
        [ muted ("Posting " ++ form.measure ++
            " is signed; decimal input follows the Measure presentation scale.")
        , muted "Ctrl-U fill unresolved remainder"
        , blank
        , line "Locus catalog:"
        ] ++
        candidateLines ++ helpLine ++
        [ muted "Up / Down choose candidate   Enter accept candidate"
        , blank
        , line (originalSummary state)
        , blank
        , .row ((actions.zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if form.focus.val = 3 + form.rows.size * 2 + index then .selected else .normal))
        , muted "Ctrl-N add row   Ctrl-D drop row   Drop keeps at least two postings"
        , blank
        , muted "Tab / Shift-Tab focus   Enter next / preview   Esc cancel   Backspace delete"
        , line state.notice
        ]
  | .enableUnresolved =>
      .column
        [ line "Unresolved recording / Enable"
        , line ""
        , line "Some of this Movement is not classified yet."
        , line "Enable unresolved recording for this household?"
        , line ""
        , line "This adds one ordinary admitted Locus: suspense"
        , line "It does not record this Movement, change its Measure, or guess a category."
        , line ""
        , line "Enter enable   e/E or Backspace return   Esc cancel Record"
        , line state.notice
        ]
  | .originalAmount editor =>
      .column
        [ line "Record / Original amount"
        , line ""
        , originalField editor 0 "Measure" editor.measure
        , originalField editor 1 "Amount" editor.amount
        , line ""
        , line "This is the merchant/card-presented amount, not another posting."
        , line "It does not infer an FX rate or change the Movement Measure."
        , line ""
        , line "Enter next / attach   Tab switch field"
        , line "Ctrl-D clear   Ctrl-O return   Esc cancel Record"
        , line state.notice
        ]
  | .preview draft choice =>
      let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
      let originalLines :=
        match state.originalAmount with
        | none => []
        | some original =>
            [previewMetaRow "Original"
              (previewAmount state original.measure original.quantity.quanta ++
                " " ++ original.measure.token)]
      .column <|
        [ line "Record / Preview"
        , blank
        , line "Movement"
        , previewMetaRow "Date" draft.validOn
        , previewMetaRow "Description" (draft.description.getD "(no description)")
        , previewMetaRow "Measure" measure.token
        ] ++
        originalLines ++
        [ blank
        , line "Postings"
        ] ++
        draft.effects.map (previewPostingRow state) ++
        [ blank
        , .row
            [ span (Loam.Tui.Layout.padRight 30 "Balanced total") .muted
            , span (Loam.Tui.Layout.padLeft
                (max 14 (Loam.Tui.Layout.displayWidth (previewAmount state measure draft.total)))
                (previewAmount state measure draft.total))
            , span (" " ++ measure.token) .muted
            ]
        , blank
        , line "Publication gate"
        , muted "  recheck current evidence"
        , muted "  recheck Locus admission"
        , blank
        , .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
            span ("[" ++ label ++ "] ")
              (if choice.val = index then .selected else .normal))
        , blank
        , muted "Tab / Shift-Tab select   Enter confirm   Esc cancel"
        , line state.notice
        ]

/-- Complete exact confirmation content, wrapped without losing amounts or identities. -/
private def confirmationLines (width : Nat) (state : State)
    (draft : Loam.MovementAdmission.Draft) : List Widget :=
  let wrapped := fun (text : String) => (Loam.Tui.Layout.wrapColumns width text).map line
  let metadata := fun (text : String) => (Loam.Tui.Layout.wrapColumns width text).map muted
  let original := match state.originalAmount with
    | none => []
    | some value => metadata ("Original: " ++ previewAmount state value.measure value.quantity.quanta ++
        " " ++ value.measure.token ++ " (not another posting)")
  metadata ("Date: " ++ draft.validOn) ++
    wrapped ("Description: " ++ draft.description.getD "(no description)") ++ original ++ [blank] ++
    (draft.effects.flatMap fun effect =>
      let sign := if effect.quantity.quanta >= 0 then "+" else ""
      wrapped (sign ++ previewAmount state effect.measure effect.quantity.quanta ++ " " ++
        effect.measure.token ++ "  " ++ effect.locus.token)) ++ [blank] ++
    wrapped ("Balanced total: " ++ previewAmount state
      ((draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩) draft.total ++ " " ++
      ((draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩).token)

private def confirmationFooter (bounds : Bounds) (state : State) (choice : Fin 3) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := (Loam.Tui.Layout.wrapColumns width state.notice).map line
  (if feedback.isEmpty then [blank] else feedback) ++
    [muted "Publication gate",
     muted "recheck evidence + Locus admission",
     .row ((["Publish", "Edit", "Cancel"].zipIdx).map fun (label, index) =>
       span ("[" ++ label ++ "] ") (if choice.val == index then .selected else .normal)),
     Loam.Tui.Layout.shortcutRow [("↑/↓", "review"), ("PgUp/Dn", "page"), ("Home/End", "edges")] " ",
     Loam.Tui.Layout.shortcutRow [("Tab", "action"), ("Enter", "confirm"), ("Esc", "cancel")] " "]

private def confirmationCapacity (bounds : Bounds) (state : State) (choice : Fin 3) : Nat :=
  Loam.Tui.Layout.footerBodyCapacity bounds (confirmationFooter bounds state choice).length - 3

def previewScrollLimit (bounds : Bounds) (state : State) : Nat :=
  match state.mode with
  | .preview draft choice =>
      (confirmationLines (Loam.Tui.Layout.contentWidth bounds - 2) state draft).length -
        confirmationCapacity bounds state choice
  | _ => 0

/-- Review keys only move presentation, preserving the draft and selected publication action. -/
def scrollPreview (bounds : Bounds) (state : State) (key : Loam.Tui.Terminal.Key) : Option State :=
  match state.mode with
  | .preview _ choice => do
      let limit := previewScrollLimit bounds state
      let current := min state.previewScroll limit
      let page := max 1 (confirmationCapacity bounds state choice)
      let offset ← match key with
        | .up => some (current - 1)
        | .down => some (min limit (current + 1))
        | .pageUp => some (current - page)
        | .pageDown => some (min limit (current + page))
        | .home => some 0
        | .«end» => some limit
        | _ => none
      some { state with previewScroll := offset }
  | _ => none

private def ellipsize (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text <= width then text
  else if width == 0 then ""
  else Loam.Tui.Layout.clip (width - 1) text ++ "…"

/-- Keep the end of an edited field visible without changing its stored text. -/
private def fieldTail (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text <= width then text
  else if width == 0 then ""
  else
    let (chars, _, _) := text.toList.reverse.foldl
      (fun (acc : List Char × Nat × Bool) char =>
        let (chars, used, stopped) := acc
        let next := used + Loam.Tui.Layout.charWidth char
        if stopped || next > width - 1 then (chars, used, true)
        else (char :: chars, next, false)) ([], 0, false)
    "…" ++ String.ofList chars

private def boundedField (width : Nat) (active : Bool) (label text : String) : Widget :=
  let labelWidth := min 13 (width / 2)
  let value := if text.isEmpty then "_" else text
  .row [span (Loam.Tui.Layout.padRight labelWidth (label ++ ": ")) .muted,
    span (if active then fieldTail (width - labelWidth) value
          else ellipsize (width - labelWidth) value)
      (if active then .selected else .normal)]

private def editingField (width : Nat) (form : Form) (index : Nat)
    (label text : String) : Widget :=
  boundedField width (form.focus.val == index) label text

/-- Fit rendered rows above a stable footer and reserve the terminal's final row/column. -/
def boundedWithFooter (bounds : Bounds) (body : Widget) (footer : List Widget) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let rows := Loam.Tui.Layout.widgetRows body
  .column (((Loam.Tui.Layout.fitWithFooter bounds rows footer).take (bounds.height - 1)).map
    fun widget => .column (Loam.Tui.Layout.clippedWidgetRows width widget))

private def originalAmountView (bounds : Bounds) (state : State)
    (editor : OriginalAmountEditor) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := (Loam.Tui.Layout.wrapColumns width state.notice).map line
  let footer := (if feedback.isEmpty then [blank] else feedback) ++
    [Loam.Tui.Layout.shortcutRow [("Tab/⇧Tab", "focus"), ("Enter", "next/attach")] " ",
     Loam.Tui.Layout.shortcutRow [("C-d", "clear"), ("C-o", "return"), ("Esc", "cancel")] " "]
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let fields := Loam.Tui.Layout.framedPanel width 4 "Original amount"
    (.column [boundedField (width - 2) (editor.focus.val == 0) "Measure" editor.measure,
              boundedField (width - 2) (editor.focus.val == 1) "Amount" editor.amount]) true
  let explanation := ["Merchant/card amount; not another posting.",
    "No FX inference or Movement Measure change.",
    "Attach to draft; Publish later in Preview."]
  let meaning := Loam.Tui.Layout.framedPanel width (available - 5) "Meaning"
    (.column (explanation.flatMap fun text =>
      (Loam.Tui.Layout.wrapColumns (width - 2) text).map muted))
  boundedWithFooter bounds (.column [line "Record / Original amount", fields, meaning]) footer

def unresolvedEnableView (bounds : Bounds) (state : State)
    (cancelLabel : String := "cancel Record") : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := (Loam.Tui.Layout.wrapColumns width state.notice).map line
  let footer := (if feedback.isEmpty then [blank] else feedback) ++
    [.row [span "[Enable unresolved recording]" .selected],
     Loam.Tui.Layout.shortcutRow [("Enter", "enable"), ("e/E", "return")] " ",
     Loam.Tui.Layout.shortcutRow [("Backspace", "return"), ("Esc", cancelLabel)] " "]
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let change := Loam.Tui.Layout.framedPanel width 3 "Household vocabulary"
    (line "Admit ordinary Locus: suspense.") true
  let explanation := ["This does not record the Movement.",
    "No Measure change or category guessing.",
    "Return to draft; Preview before Publish."]
  let meaning := Loam.Tui.Layout.framedPanel width (available - 4) "Not a Movement publication"
    (.column (explanation.flatMap fun text =>
      (Loam.Tui.Layout.wrapColumns (width - 2) text).map muted))
  boundedWithFooter bounds (.column [line "Unresolved recording / Enable", change, meaning]) footer

private def editingFields (width : Nat) (form : Form) (dateKept : Bool := false) : List Widget :=
  [boundedField width (!dateKept && form.focus.val == 0) (if dateKept then "Date (kept)" else "Date") form.date,
   editingField width form 1 "Description" form.description,
   editingField width form 2 "Measure" form.measure] ++
  (List.range form.rows.size).flatMap fun index =>
    let row := form.rows[index]!
    [editingField width form (3 + index * 2) (s!"Posting {index + 1}") row.locus,
     editingField width form (4 + index * 2) "Amount" row.amount]

private def editingFooter (bounds : Bounds) (state : State)
    (context : Option String) (originalShortcut : Bool) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := (Loam.Tui.Layout.wrapColumns width state.notice).map line
  [muted (ellipsize width (context.getD (originalSummary state)))] ++
    (if feedback.isEmpty then [blank] else feedback) ++
    [.row ((["Preview", "Add row", "Drop row", "Cancel"].zipIdx).map fun (label, index) =>
      span ("[" ++ label ++ "] ")
        (if state.form.focus.val == 3 + state.form.rows.size * 2 + index then .selected else .normal)),
     Loam.Tui.Layout.shortcutRow [("Tab/⇧Tab", "focus"), ("Enter", "next"), ("Esc", "cancel")] " ",
     Loam.Tui.Layout.shortcutRow ([("C-n/d", "rows"), ("C-u", "remainder")] ++
       (if originalShortcut then [("C-o", "original")] else [])) " "]

private def candidateSummary (width : Nat) (state : State) : Widget :=
  let text := match activeLocus? state.form, selectedCatalogCandidate? state with
    | none, _ => "Locus: focus a Locus field"
    | some _, none => "Locus: no matching candidate"
    | some _, some entry => "↑/↓ Enter: " ++ Loam.Tui.LocusPicker.display entry
  muted (ellipsize width text)

private def candidatesPanel (width height : Nat) (state : State) : Widget :=
  let options := catalogCandidates state
  let selected := if options.isEmpty then 0 else state.candidateIndex % options.length
  let capacity := height - 4
  let start := Loam.Tui.Layout.trailingWindowStart selected capacity
  let visible := (options.drop start).take capacity
  let rows := if options.isEmpty then [candidateSummary (width - 2) state] else
    (visible.zipIdx).map fun (entry, index) =>
      .row [span (if start + index == selected then "> " else "  "),
        span (ellipsize (width - 4) (Loam.Tui.LocusPicker.display entry))
          (if start + index == selected then .normal else .muted)]
  let help := match selectedCatalogCandidate? state with
    | some entry => if entry.help.isEmpty then "↑/↓ choose · Enter accept" else "↳ " ++ entry.help
    | none => "↑/↓ choose · Enter accept"
  let content := rows ++ List.replicate (capacity - rows.length) blank ++
    [muted (ellipsize (width - 2) help), muted "Admitted Locus only"]
  let more := (if start > 0 then " ▲" else "") ++
    (if start + capacity < options.length then " ▼" else "")
  Loam.Tui.Layout.framedPanel width height "Locus candidates" (.column content) false
    (some (if options.isEmpty then "0 candidates" else s!"{selected + 1}/{options.length}" ++ more))

private def postingsPanel (width height : Nat) (state : State) : Widget :=
  let form := state.form
  let capacity := (height - 3) / 2
  let active := form.focus.val >= 3 && form.focus.val < 3 + form.rows.size * 2
  let selected := if active then (form.focus.val - 3) / 2
    else if form.focus.val < 3 then 0 else form.rows.size - 1
  let start := min (form.rows.size - capacity)
    (Loam.Tui.Layout.trailingWindowStart selected capacity)
  let fields := ((editingFields (width - 2) form).drop (3 + start * 2)).take (capacity * 2)
  let context := ellipsize (width - 2)
    ("Signed " ++ form.measure ++ " · decimal scale per Measure")
  let more := (if start > 0 then " ▲" else "") ++
    (if start + capacity < form.rows.size then " ▼" else "")
  Loam.Tui.Layout.framedPanel width height "Postings" (.column (fields ++ [muted context])) active
    (some (s!"{min (start + capacity) form.rows.size}/{form.rows.size} rows" ++ more))

/-- Shared Record-shaped input presentation; fixed-date policy remains in each editor's update. -/
def editingView (bounds : Bounds) (state : State)
    (heading : String := "Record / Edit") (context : Option String := none)
    (dateKept : Bool := false) (originalShortcut : Bool := true) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let footer := editingFooter bounds state context originalShortcut
  let available := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
  let paneHeight := available - 6
  let wide := width >= 72
  let body : Widget := if (wide && paneHeight >= 7) || (!wide && paneHeight >= 11) then
    let metadata := Loam.Tui.Layout.framedPanel width 5 "Movement"
      (.column ((editingFields (width - 2) state.form dateKept).take 3))
        (state.form.focus.val < 3 && (!dateKept || state.form.focus.val > 0))
    let panes := if wide then
        let left := width * 3 / 5
        Widget.column (Loam.Tui.Layout.sideBySide paneHeight left (width - left - 1)
          (postingsPanel left paneHeight state)
          (candidatesPanel (width - left - 1) paneHeight state) " ")
      else .column [postingsPanel width (paneHeight - 6) state, candidatesPanel width 6 state]
    .column [line heading, metadata, panes]
  else
    let height := available - 1
    let capacity := height - 3
    let fields := editingFields (width - 2) state.form dateKept
    let focus := min state.form.focus.val (fields.length - 1)
    let start := min (fields.length - capacity)
      (Loam.Tui.Layout.trailingWindowStart focus capacity)
    let more := (if start > 0 then " ▲" else "") ++
      (if start + capacity < fields.length then " ▼" else "")
    .column [line heading,
      Loam.Tui.Layout.framedPanel width height "Fields"
        (.column ((fields.drop start).take capacity ++ [candidateSummary (width - 2) state]))
        (state.form.focus.val < fields.length)
        (some (s!"{min (start + capacity) fields.length}/{fields.length} fields" ++ more))]
  boundedWithFooter bounds body footer

/-- Bounds-aware standalone Record surfaces; embedded editors retain their contract. -/
def viewForBounds (bounds : Bounds) (_known : List String) (state : State) : Widget :=
  match state.mode with
  | .editing => editingView bounds state
  | .originalAmount editor => originalAmountView bounds state editor
  | .enableUnresolved => unresolvedEnableView bounds state
  | .preview draft choice =>
      let width := Loam.Tui.Layout.contentWidth bounds
      let footer := confirmationFooter bounds state choice
      let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footer.length
      let panelHeight := bodyCapacity - 1
      let lines := confirmationLines (width - 2) state draft
      let capacity := panelHeight - 2
      let offset := min state.previewScroll (lines.length - capacity)
      let more := (if offset > 0 then " ▲" else "") ++
        (if offset + capacity < lines.length then " ▼" else "")
      let panel := Loam.Tui.Layout.framedPanel width panelHeight "Movement / signed postings"
        (.column ((lines.drop offset).take capacity)) true
        (some (s!"{min (offset + capacity) lines.length}/{lines.length} lines" ++ more))
      boundedWithFooter bounds (.column [line "Record / Preview", panel]) footer

end Loam.Tui.Record
