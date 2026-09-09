import Loam.AccountingRolePublisher
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.AccountingRoleAdministration

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Layout
open Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Initial AccountingRole administration

Presentation for the publisher-qualified first-assignment slice only. Candidate
eligibility is supplied by `AccountingRolePublisher.eligibleInitialLoci`; this
state machine does not reclassify existing evidence or infer a role.
-/

inductive Phase where
  | choosing
  | preview
  deriving Repr, DecidableEq

structure State where
  candidates : List LocusId
  cursor : Nat := 0
  role : Option AccountingRole := none
  phase : Phase := .choosing
  notice : String := ""
  deriving Repr

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.AccountingRolePublisher.Draft := none
  deriving Repr


def initial (candidates : List LocusId) : State :=
  { candidates := candidates }

private def roleLabel : AccountingRole → String
  | .asset => "Asset"
  | .liability => "Liability"
  | .equity => "Equity"
  | .income => "Income"
  | .expense => "Expense"

private def selectedLocus? (state : State) : Option LocusId :=
  state.candidates[state.cursor]?

private def validation? (state : State) : Except String Loam.AccountingRolePublisher.Draft := do
  let some locus := selectedLocus? state
    | throw "No virgin admitted Locus is available for initial role assignment."
  let some role := state.role
    | throw "Choose one explicit AccountingRole with 1-5 before preview."
  pure { locus, role }


def draft? (state : State) : Option Loam.AccountingRolePublisher.Draft :=
  match validation? state with
  | .ok draft => some draft
  | .error _ => none

private def chooseRole (state : State) : Char → State
  | '1' => { state with role := some .asset, notice := "" }
  | '2' => { state with role := some .liability, notice := "" }
  | '3' => { state with role := some .equity, notice := "" }
  | '4' => { state with role := some .income, notice := "" }
  | '5' => { state with role := some .expense, notice := "" }
  | _ => state


def update (state : State) (key : Key) : Step :=
  match state.phase with
  | .choosing =>
      match key with
      | .escape => { state := state, cancel := true }
      | .up =>
          let cursor := if state.cursor == 0 then 0 else state.cursor - 1
          { state := { state with cursor, notice := "" } }
      | .down =>
          let cursor :=
            if state.cursor + 1 < state.candidates.length then state.cursor + 1 else state.cursor
          { state := { state with cursor, notice := "" } }
      | .input char => { state := chooseRole state char }
      | .enter =>
          match validation? state with
          | .ok _ => { state := { state with phase := .preview, notice := "" } }
          | .error message => { state := { state with notice := message } }
      | _ => { state := state }
  | .preview =>
      match key with
      | .enter =>
          match validation? state with
          | .ok draft => { state := state, publish := some draft }
          | .error message => { state := { state with phase := .choosing, notice := message } }
      | .escape | .backspace | .input 'e' | .input 'E' =>
          { state := { state with phase := .choosing, notice := "" } }
      | _ => { state := state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := line ""

private def roleText (state : State) : String :=
  match state.role with
  | none => "(not selected)"
  | some role => roleLabel role

private def visibleCandidates (bounds : Bounds) (state : State) : List (Nat × LocusId) :=
  let maxVisible := if bounds.height > 14 then min 12 (bounds.height - 12) else 5
  let selected := if state.candidates.isEmpty then 0 else min state.cursor (state.candidates.length - 1)
  let start :=
    if state.candidates.length <= maxVisible then 0
    else if selected + 1 <= maxVisible then 0
    else min (selected + 1 - maxVisible) (state.candidates.length - maxVisible)
  (state.candidates.drop start |>.take maxVisible).zipIdx.map fun (locus, index) =>
    (start + index, locus)

private def candidateRows (bounds : Bounds) (state : State) : List Widget :=
  if state.candidates.isEmpty then
    [muted "   (no admitted unresolved Locus is still unused by Actual/Scheduled evidence)"]
  else
    (visibleCandidates bounds state).map fun (index, locus) =>
      .row [span ((if index == state.cursor then "▶  " else "   ") ++ locus.token)
        (if index == state.cursor then .selected else .normal)]


def view (bounds : Bounds) (state : State) : Widget :=
  match state.phase with
  | .choosing =>
      .column <|
        [ line "AccountingRole Administration / Initial Assignment"
        , muted "Virgin Locus only; no role replacement or historical reclassification"
        , blank
        , muted "Eligible Loci:"
        ] ++ candidateRows bounds state ++
        [ blank
        , line ("Role: " ++ roleText state)
        , muted "1 Asset   2 Liability   3 Equity   4 Income   5 Expense"
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ choose Locus   1-5 choose role   Enter preview   Esc cancel"
        ]
  | .preview =>
      let locusText := (selectedLocus? state).map (fun locus => locus.token) |>.getD "(none)"
      .column
        [ line "AccountingRole Administration / Preview"
        , muted "First explicit role assertion"
        , blank
        , line ("Locus: " ++ locusText)
        , line ("Role : " ++ roleText state)
        , blank
        , muted "The publisher will re-check admission plus all retained Actual and Scheduled use."
        , muted "Existing roles cannot be replaced by this entrance."
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter publish   e/E or Esc edit"
        ]

end Loam.Tui.AccountingRoleAdministration
