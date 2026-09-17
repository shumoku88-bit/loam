import Loam.EventMerchantPublisher
import Loam.Persistence.TokenSyntax
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Terminal

namespace Loam.Tui.EventMerchant

open Loam.Core Loam.Tui.Kernel

set_option autoImplicit false

inductive Choice where
  | merchant
  | nonmerchant
  deriving Repr, DecidableEq, BEq

inductive Mode where
  | editing
  | preview
  deriving Repr, DecidableEq, BEq

/-- Presentation-only first-classification editor for one selected Actual Event. -/
structure State where
  target : EventId
  description : String
  choice : Choice := .merchant
  partyInput : String := ""
  mode : Mode := .editing
  notice : String := ""
  deriving Repr, DecidableEq

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.EventMerchantPublisher.Draft := none

/-- Bind the editor to the selected Event identity without inferring Merchant from text. -/
def initial (record : Loam.Tui.Main.ReviewRecord) : State :=
  {
    target := record.event.id
    description := record.description
  }

private def dropLast (text : String) : String :=
  String.ofList text.toList.dropLast

private def nextChoice : Choice → Choice
  | .merchant => .nonmerchant
  | .nonmerchant => .merchant

/-- Human-facing rendering of the retained relation-specific disposition. -/
def dispositionText : MerchantDisposition → String
  | .merchant party => "Merchant " ++ party.token
  | .nonmerchant => "Nonmerchant"

private def draft? (state : State) : Except String Loam.EventMerchantPublisher.Draft := do
  match state.choice with
  | .merchant =>
      if !Loam.Persistence.validToken state.partyInput then
        throw "Merchant party id must be a non-empty single text field."
      return {
        target := state.target
        disposition := .merchant ⟨state.partyInput⟩
      }
  | .nonmerchant =>
      return {
        target := state.target
        disposition := .nonmerchant
      }

/--
Local interaction only. `Tab` switches Merchant / Nonmerchant. Merchant identity
is typed explicitly and never inferred from Event description. Publication
re-validates everything against current Actual authority under writer ownership.
-/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .editing =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .tab | .shiftTab =>
          { state := { state with choice := nextChoice state.choice, notice := "" } }
      | .backspace =>
          match state.choice with
          | .merchant =>
              { state := { state with partyInput := dropLast state.partyInput, notice := "" } }
          | .nonmerchant => { state }
      | .input char =>
          match state.choice with
          | .merchant =>
              if state.partyInput.length < 80 then
                { state := { state with partyInput := state.partyInput.push char, notice := "" } }
              else
                { state }
          | .nonmerchant => { state }
      | .enter =>
          match draft? state with
          | .ok _ => { state := { state with mode := .preview, notice := "" } }
          | .error message => { state := { state with notice := message } }
      | _ => { state }
  | .preview =>
      match key with
      | .enter =>
          match draft? state with
          | .ok draft => { state, publish := some draft }
          | .error message =>
              { state := { state with mode := .editing, notice := message } }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with mode := .editing, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

/-- Return a refused publish attempt to editing without changing the user's draft. -/
def withPublishError (state : State) (message : String) : State :=
  { state with mode := .editing, notice := message }

private def line (text : String) : Widget :=
  .row [span text]

private def muted (text : String) : Widget :=
  .row [span text .muted]

private def choiceText : Choice → String
  | .merchant => "Merchant"
  | .nonmerchant => "Nonmerchant"

private def descriptionText (state : State) : String :=
  if state.description.isEmpty then "(no description)"
  else Loam.ActualReview.displayText state.description

private def proposalText (state : State) : String :=
  match state.choice with
  | .merchant => "Merchant " ++ state.partyInput
  | .nonmerchant => "Nonmerchant"

/-- Minimal first-classification editor; replacement semantics are intentionally absent. -/
def view (state : State) : Widget :=
  match state.mode with
  | .editing =>
      .column ([
        line "Event Merchant / Edit",
        line ("Target: " ++ state.target.token),
        line ("Description: " ++ descriptionText state),
        line ("Disposition: " ++ choiceText state.choice)
      ] ++
      (match state.choice with
       | .merchant => [line ("Party id: " ++ state.partyInput)]
       | .nonmerchant => [muted "Party id: (not applicable)"]) ++
      [ muted "Tab Merchant/Nonmerchant   Type party id   Enter preview   Esc/q cancel"
      , line state.notice
      ])
  | .preview =>
      .column [
        line "Event Merchant / Preview",
        line ("Target remains: " ++ state.target.token),
        line ("Description: " ++ descriptionText state),
        line ("Proposed: " ++ proposalText state),
        muted "Enter publish   Esc/e edit   q cancel",
        muted "First classification only; replacement is not available here.",
        line state.notice
      ]

end Loam.Tui.EventMerchant
