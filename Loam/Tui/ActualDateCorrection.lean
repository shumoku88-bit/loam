import Loam.ActualDate
import Loam.ActualValidityPublisher
import Loam.Tui.Main
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.ActualDateCorrection

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

inductive Mode where
  | editing
  | preview
  deriving Repr, DecidableEq, BEq

/-- Presentation-only date editor bound to one selected current Actual identity. -/
structure State where
  target : EventId
  originalDate : String
  input : String
  mode : Mode := .editing
  notice : String := ""
  deriving Repr, DecidableEq

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ActualValidityPublisher.Draft := none

/-- Prefill visible current date evidence. This is convenience, never publication authority. -/
def initial? (record : Loam.Tui.Main.ReviewRecord) : Except String State := do
  let date ←
    match record.date with
    | some date => pure date
    | none => throw "This Actual has no current occurrence date to edit from the selected-day workspace."
  pure {
    target := record.event.id
    originalDate := date
    input := date
  }

private def allowedDateChar (char : Char) : Bool :=
  char.isDigit || char = '-'

private def dropLast (text : String) : String :=
  String.ofList text.toList.dropLast

/--
Pure local interaction. Calendar validity is checked with the existing shared date
utility for preview feedback, then checked again by ActualValidityPublisher under
writer ownership before any canonical change.
-/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .editing =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .backspace =>
          { state := { state with input := dropLast state.input, notice := "" } }
      | .input char =>
          if allowedDateChar char && state.input.length < 10 then
            { state := { state with input := state.input.push char, notice := "" } }
          else
            { state }
      | .enter =>
          if Loam.ActualDate.validIsoDate state.input then
            { state := { state with mode := .preview, notice := "" } }
          else
            { state := { state with notice := "Date must be a real YYYY-MM-DD calendar date." } }
      | _ => { state }
  | .preview =>
      match key with
      | .enter =>
          { state, publish := some { target := state.target, validOn := state.input } }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with mode := .editing, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

/-- Return a failed publication attempt to the local editor without changing its draft. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget :=
  .row [span text]

private def muted (text : String) : Widget :=
  .row [span text .muted]

/-- Minimal date-only editor. It contains no ActualValidity frontier or writer logic. -/
def view (state : State) : Widget :=
  match state.mode with
  | .editing =>
      .column [
        line "Actual Date / Edit",
        line ("Target: " ++ state.target.token),
        line ("Current: " ++ state.originalDate),
        line ("New date: " ++ state.input),
        muted "Type YYYY-MM-DD   Backspace edit   Enter preview   Esc/q cancel",
        line state.notice
      ]
  | .preview =>
      .column [
        line "Actual Date / Preview",
        line ("Target remains: " ++ state.target.token),
        line ("Current date: " ++ state.originalDate),
        line ("Proposed date: " ++ state.input),
        muted "Enter publish   Esc/e edit   q cancel",
        line state.notice
      ]

end Loam.Tui.ActualDateCorrection
