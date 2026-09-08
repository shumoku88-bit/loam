import Loam.ActualDate
import Loam.ActualReversalPublisher
import Loam.Tui.Main
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.ActualReversal

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

inductive Mode where
  | editing
  | preview
  deriving Repr, DecidableEq, BEq

/--
Presentation-only reversal confirmation for one selected Actual.

Only the occurrence date is editable. Inverse postings are derived from the
selected visible Actual solely for preview; `ActualReversalPublisher` re-reads
and re-derives the authoritative inverse under writer ownership.
-/
structure State where
  target : EventId
  targetDate : Option String
  description : String
  targetEffects : List Effect
  inputDate : String
  mode : Mode := .editing
  notice : String := ""

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ActualReversalPublisher.Draft := none

/--
Seed the editable occurrence coordinate from today as a presentation convenience.
Reversal itself does not imply temporal ordering relative to the target Actual.
-/
def initial?
    (record : Loam.Tui.Main.ReviewRecord) (today : String) : Except String State := do
  if !Loam.ActualDate.validIsoDate today then
    throw "Current date is unavailable for the reversal editor."
  if !record.event.effects.all (fun effect => decide (effect.measure = ⟨"jpy"⟩)) then
    throw "This Actual uses a non-JPY measure and cannot use the practical reversal entrance."
  if record.event.effects.length < 2 then
    throw "This Actual is outside the practical balanced-Movement reversal entrance."
  pure {
    target := record.event.id
    targetDate := record.date
    description := record.description
    targetEffects := record.event.effects
    inputDate := today
  }

private def allowedDateChar (char : Char) : Bool :=
  char.isDigit || char = '-'

private def dropLast (text : String) : String :=
  String.ofList text.toList.dropLast

/-- Local preview-only inverse of the selected visible target. -/
def inversePreview (state : State) : List (LocusId × Quantity × MeasureId) :=
  state.targetEffects.map fun effect =>
    (effect.locus, -effect.quantity, effect.measure)

/-- Emit a durable intent only after exact-inverse preview confirmation. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .editing =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .backspace =>
          { state := { state with inputDate := dropLast state.inputDate, notice := "" } }
      | .input char =>
          if allowedDateChar char && state.inputDate.length < 10 then
            { state := { state with inputDate := state.inputDate.push char, notice := "" } }
          else
            { state }
      | .enter =>
          if Loam.ActualDate.validIsoDate state.inputDate then
            { state := { state with mode := .preview, notice := "" } }
          else
            { state := { state with notice := "Date must be a real YYYY-MM-DD calendar date." } }
      | _ => { state }
  | .preview =>
      match key with
      | .enter =>
          { state, publish := some { target := state.target, validOn := state.inputDate } }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with mode := .editing, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

/-- Failed shared publication returns to the date editor; inverse postings remain derived. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def targetDateText (state : State) : String :=
  state.targetDate.getD "(unknown)"

private def descriptionText (state : State) : String :=
  if state.description.isEmpty then "(no description)" else state.description

/-- Minimal exact-reversal editor/preview. No posting field is editable. -/
def view (state : State) : Widget :=
  match state.mode with
  | .editing =>
      .column [
        line "Actual / Reverse / Date",
        line ("Target: " ++ state.target.token),
        line ("Target date: " ++ targetDateText state),
        line ("Description: " ++ descriptionText state),
        line ("Reversal date: " ++ state.inputDate),
        muted "The postings themselves are not editable: reversal means exact additive inverse.",
        muted "Type YYYY-MM-DD   Backspace edit   Enter preview   Esc/q cancel",
        line state.notice
      ]
  | .preview =>
      .column <|
        [ line "Actual / Reverse / Preview"
        , line ("Target: " ++ state.target.token)
        , line ("Target date: " ++ targetDateText state)
        , line ("Reversal date: " ++ state.inputDate)
        , line "Inverse postings:"
        ] ++
        ((inversePreview state).map fun (locus, quantity, measure) =>
          line ("  " ++ locus.token ++ "  " ++ toString quantity.quanta ++ " " ++ measure.token)) ++
        [ muted "Both Actuals remain retained. This is not an input correction."
        , muted "Enter publish   Esc/e edit date   q cancel"
        , line state.notice
        ]

end Loam.Tui.ActualReversal
