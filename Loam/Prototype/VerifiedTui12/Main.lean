import Loam.Core.BalancedMovement
import Loam.Prototype.VerifiedTui04.Kernel

namespace Loam.Prototype.VerifiedTui12.Main

open Loam.Core
open Loam.Prototype.VerifiedTui04.Kernel

set_option autoImplicit false

/-- Presentation-only editing mode. No draft is canonical evidence. -/
inductive Mode where
  | edit
  | preview
  deriving Repr, DecidableEq, BEq

/-- Small fixed draft for the first form-pressure experiment. -/
structure Draft where
  description : String := ""
  fromLocus : String := ""
  fromAmount : String := ""
  toLocus : String := ""
  toAmount : String := ""
  deriving Repr, DecidableEq

/--
Five fields are enough to pressure focus, text editing, candidate acceptance,
validation, and preview without prematurely earning a generic form framework.
-/
abbrev FieldIndex := Fin 5
abbrev CandidateIndex := Fin 6

structure State where
  mode : Mode := .edit
  focus : FieldIndex := ⟨0, by decide⟩
  candidate : CandidateIndex := ⟨0, by decide⟩
  draft : Draft := {}
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | tab
  | shiftTab
  | up
  | down
  | enter
  | edit
  | back
  | backspace
  | input (char : Char)
  | quit
  | other
  deriving Repr, DecidableEq

structure Step where
  state : State
  quit : Bool := false
  deriving Repr, DecidableEq

def initialState : State := {}

def selectedDay : String := "2026-09-07"

def candidateLocus : CandidateIndex → String
  | ⟨0, _⟩ => "paypay"
  | ⟨1, _⟩ => "smbc"
  | ⟨2, _⟩ => "cash"
  | ⟨3, _⟩ => "coffee"
  | ⟨4, _⟩ => "books"
  | _ => "groceries"

def nextField : FieldIndex → FieldIndex
  | ⟨0, _⟩ => ⟨1, by decide⟩
  | ⟨1, _⟩ => ⟨2, by decide⟩
  | ⟨2, _⟩ => ⟨3, by decide⟩
  | ⟨3, _⟩ => ⟨4, by decide⟩
  | _ => ⟨0, by decide⟩

def previousField : FieldIndex → FieldIndex
  | ⟨0, _⟩ => ⟨4, by decide⟩
  | ⟨1, _⟩ => ⟨0, by decide⟩
  | ⟨2, _⟩ => ⟨1, by decide⟩
  | ⟨3, _⟩ => ⟨2, by decide⟩
  | _ => ⟨3, by decide⟩

def nextCandidate : CandidateIndex → CandidateIndex
  | ⟨0, _⟩ => ⟨1, by decide⟩
  | ⟨1, _⟩ => ⟨2, by decide⟩
  | ⟨2, _⟩ => ⟨3, by decide⟩
  | ⟨3, _⟩ => ⟨4, by decide⟩
  | ⟨4, _⟩ => ⟨5, by decide⟩
  | _ => ⟨0, by decide⟩

def previousCandidate : CandidateIndex → CandidateIndex
  | ⟨0, _⟩ => ⟨5, by decide⟩
  | ⟨1, _⟩ => ⟨0, by decide⟩
  | ⟨2, _⟩ => ⟨1, by decide⟩
  | ⟨3, _⟩ => ⟨2, by decide⟩
  | ⟨4, _⟩ => ⟨3, by decide⟩
  | _ => ⟨4, by decide⟩

def locusField (focus : FieldIndex) : Bool :=
  focus.val = 1 || focus.val = 3

def dropLastCharList : List Char → List Char
  | [] => []
  | _ :: [] => []
  | char :: rest => char :: dropLastCharList rest

def dropLastChar (text : String) : String :=
  String.ofList (dropLastCharList text.toList)

def appendAtFocus (state : State) (char : Char) : State :=
  let draft := state.draft
  match state.focus.val with
  | 0 => { state with draft := { draft with description := draft.description ++ toString char }, notice := "" }
  | 1 => { state with draft := { draft with fromLocus := draft.fromLocus ++ toString char }, notice := "" }
  | 2 => { state with draft := { draft with fromAmount := draft.fromAmount ++ toString char }, notice := "" }
  | 3 => { state with draft := { draft with toLocus := draft.toLocus ++ toString char }, notice := "" }
  | _ => { state with draft := { draft with toAmount := draft.toAmount ++ toString char }, notice := "" }

def eraseAtFocus (state : State) : State :=
  let draft := state.draft
  match state.focus.val with
  | 0 => { state with draft := { draft with description := dropLastChar draft.description }, notice := "" }
  | 1 => { state with draft := { draft with fromLocus := dropLastChar draft.fromLocus }, notice := "" }
  | 2 => { state with draft := { draft with fromAmount := dropLastChar draft.fromAmount }, notice := "" }
  | 3 => { state with draft := { draft with toLocus := dropLastChar draft.toLocus }, notice := "" }
  | _ => { state with draft := { draft with toAmount := dropLastChar draft.toAmount }, notice := "" }

def acceptCandidate (state : State) : State :=
  let locus := candidateLocus state.candidate
  let draft := state.draft
  match state.focus.val with
  | 1 =>
      { state with
        draft := { draft with fromLocus := locus }
        focus := nextField state.focus
        notice := "" }
  | 3 =>
      { state with
        draft := { draft with toLocus := locus }
        focus := nextField state.focus
        notice := "" }
  | _ => { state with focus := nextField state.focus, notice := "" }

private def positiveAmount? (text : String) : Option Int :=
  match text.toInt? with
  | none => none
  | some amount => if 0 < amount then some amount else none

/--
Admit the current UI draft through the production balanced-movement algebra.
The UI retains no separate debit/credit or transaction-kind meaning.
-/
def draftMovement? (draft : Draft) : Option (BalancedMovement LocusId) := do
  if draft.fromLocus.isEmpty || draft.toLocus.isEmpty then
    none
  else
    let fromAmount ← positiveAmount? draft.fromAmount
    let toAmount ← positiveAmount? draft.toAmount
    let changes : List (MovementChange LocusId) :=
      [ { coordinate := ⟨draft.fromLocus⟩, quantity := Quantity.ofQuanta (-fromAmount) }
      , { coordinate := ⟨draft.toLocus⟩, quantity := Quantity.ofQuanta toAmount }
      ]
    BalancedMovement.ofChanges? ⟨"jpy"⟩ changes

def previewFailure : String :=
  "Need nonempty loci, positive integer amounts, and exact From = To balance."

def attemptPreview (state : State) : State :=
  match draftMovement? state.draft with
  | none => { state with notice := previewFailure }
  | some _ => { state with mode := .preview, notice := "" }

def enterEdit (state : State) : State :=
  if locusField state.focus then
    acceptCandidate state
  else if state.focus.val = 4 then
    attemptPreview state
  else
    { state with focus := nextField state.focus, notice := "" }

def update (state : State) (event : Event) : Step :=
  match event with
  | .quit => { state, quit := true }
  | .edit =>
      match state.mode with
      | .edit => { state }
      | .preview => { state := { state with mode := .edit, notice := "" } }
  | .back =>
      match state.mode with
      | .edit => { state }
      | .preview => { state := { state with mode := .edit, notice := "" } }
  | .tab =>
      match state.mode with
      | .edit => { state := { state with focus := nextField state.focus, notice := "" } }
      | .preview => { state }
  | .shiftTab =>
      match state.mode with
      | .edit => { state := { state with focus := previousField state.focus, notice := "" } }
      | .preview => { state }
  | .up =>
      if state.mode == .edit && locusField state.focus then
        { state := { state with candidate := previousCandidate state.candidate, notice := "" } }
      else
        { state }
  | .down =>
      if state.mode == .edit && locusField state.focus then
        { state := { state with candidate := nextCandidate state.candidate, notice := "" } }
      else
        { state }
  | .enter =>
      match state.mode with
      | .edit => { state := enterEdit state }
      | .preview =>
          { state := { state with notice := "NO WRITES: publication is deliberately outside Prototype 12." } }
  | .backspace =>
      match state.mode with
      | .edit => { state := eraseAtFocus state }
      | .preview => { state }
  | .input char =>
      match state.mode with
      | .edit => { state := appendAtFocus state char }
      | .preview => { state }
  | .other => { state }

theorem focus_bounds (state : State) : state.focus.val < 5 :=
  state.focus.isLt

theorem candidate_bounds (state : State) : state.candidate.val < 6 :=
  state.candidate.isLt

theorem admitted_preview_is_balanced
    (draft : Draft) (movement : BalancedMovement LocusId)
    (h : draftMovement? draft = some movement) :
    movementTotalQuanta movement.changes = 0 := by
  exact movement.balanced

theorem attemptPreview_preserves_draft (state : State) :
    (attemptPreview state).draft = state.draft := by
  simp [attemptPreview]
  split <;> rfl

theorem edit_preserves_draft (state : State) :
    (update state .edit).state.draft = state.draft := by
  cases state.mode <;> rfl

theorem preview_enter_preserves_draft (state : State) :
    state.mode = .preview → (update state .enter).state.draft = state.draft := by
  intro h
  cases state.mode <;> simp_all [update]

def screenBounds : Bounds :=
  { width := 80, height := 24 }

def plainLine (text : String) : Widget :=
  .row [span text]

def mutedLine (text : String) : Widget :=
  .row [span text .muted]

def blankLine : Widget :=
  .row []

def fieldLabel : FieldIndex → String
  | ⟨0, _⟩ => "Description"
  | ⟨1, _⟩ => "From locus "
  | ⟨2, _⟩ => "From amount"
  | ⟨3, _⟩ => "To locus   "
  | _ => "To amount  "

def fieldValue (draft : Draft) : FieldIndex → String
  | ⟨0, _⟩ => draft.description
  | ⟨1, _⟩ => draft.fromLocus
  | ⟨2, _⟩ => draft.fromAmount
  | ⟨3, _⟩ => draft.toLocus
  | _ => draft.toAmount

def fieldLine (state : State) (field : FieldIndex) : Widget :=
  let selected := state.mode == .edit && state.focus = field
  let marker := if selected then "▶ " else "  "
  let value := fieldValue state.draft field
  .row
    [ span (marker ++ fieldLabel field ++ " : ") (if selected then .selected else .normal)
    , span value (if selected then .selected else .normal)
    ]

def candidateLine (state : State) (candidate : CandidateIndex) : Widget :=
  let selected := state.candidate = candidate
  let marker := if selected then "▶ " else "  "
  .row [span (marker ++ candidateLocus candidate) (if selected then .selected else .normal)]

def candidateView (state : State) : List Widget :=
  if locusField state.focus then
    [mutedLine "Known loci  ↑/↓ select, Enter accept"] ++
      (List.finRange 6).map (candidateLine state)
  else
    [mutedLine "Known loci appear when a locus field has focus."]

def editView (state : State) : Widget :=
  .column <|
    [ plainLine "LOAM UI Prototype 12  [SYNTHETIC FORM / NO WRITES]"
    , mutedLine "Third TUI pressure shape: balanced Movement record editor"
    , blankLine
    , plainLine ("Selected day seed: " ++ selectedDay)
    , blankLine
    ] ++
    (List.finRange 5).map (fieldLine state) ++
    [ blankLine ] ++
    candidateView state ++
    [ blankLine
    , mutedLine "Tab/Shift-Tab field    Enter next/accept/preview    Backspace erase"
    , mutedLine "Ctrl-Q quit    ASCII input only in this mechanics spike"
    , mutedLine state.notice
    ]

def previewView (state : State) : Widget :=
  match draftMovement? state.draft with
  | none =>
      .column
        [ plainLine "Record preview  [INVALID PRESENTATION STATE]"
        , blankLine
        , mutedLine "Preview mode has no admitted BalancedMovement. Return to edit."
        , mutedLine "e/b Edit    Ctrl-Q quit"
        ]
  | some movement =>
      .column <|
        [ plainLine "Record preview  [SYNTHETIC / NO WRITES]"
        , blankLine
        , plainLine ("Date        : " ++ selectedDay)
        , plainLine ("Description : " ++ state.draft.description)
        , blankLine
        ] ++
        movement.changes.map (fun change =>
          plainLine
            ("  " ++ change.coordinate.token ++ " : " ++
              toString change.quantity.quanta ++ " " ++ movement.measure.token)) ++
        [ blankLine
        , mutedLine "BalancedMovement admission proves the represented signed total is exactly zero."
        , mutedLine "Enter publication boundary (disabled)    e/b Edit    Ctrl-Q quit"
        , mutedLine state.notice
        ]

def view (state : State) : Widget :=
  match state.mode with
  | .edit => editView state
  | .preview => previewView state

def screenFor (state : State) : Screen screenBounds :=
  renderAt screenBounds 1 1 (view state)

end Loam.Prototype.VerifiedTui12.Main