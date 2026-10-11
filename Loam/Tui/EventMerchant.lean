import Loam.Tui.EditorSession
import Loam.Publisher.EventMerchantPublisher
import Loam.Persistence.TokenSyntax
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
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

abbrev Step :=
  Loam.Tui.EditorSession.Step State (Loam.EventMerchantPublisher.Draft)

/-- Bind the editor to the selected Event identity without inferring Merchant from text. -/
def initial (record : Loam.Tui.Main.ReviewRecord) : State :=
  {
    target := record.event.id
    description := record.description
  }

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
              { state := { state with partyInput := Loam.Tui.Terminal.backspaceText state.partyInput, notice := "" } }
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

/-- Wrap complete CJK labels, target IDs and party text in terminal cells. -/
private def wrappedRows (width : Nat) (text : String) : List Widget :=
  (Loam.Tui.Layout.wrapColumns width text).map line

private def contentRows (width : Nat) (state : State) : List Widget :=
  let labels : List String :=
    match state.mode with
    | .editing =>
        [ "Event Merchant / Edit"
        , "Target: " ++ state.target.token
        , "Description: " ++ descriptionText state
        , "Disposition: " ++ choiceText state.choice
        , match state.choice with
          | .merchant => "Party id: " ++ state.partyInput
          | .nonmerchant => "Party id: (not applicable)" ]
    | .preview =>
        [ "Event Merchant / Preview"
        , "Target remains: " ++ state.target.token
        , "Description: " ++ descriptionText state
        , "Proposed: " ++ proposalText state ]
  labels.flatMap (wrappedRows width)

private def footerRows (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let help := match state.mode with
    | .editing => "Tab Merchant/Nonmerchant  Type party id  Enter preview  Esc/q cancel"
    | .preview => "Enter publish  Esc/e edit  q cancel"
  let footer := (wrappedRows width help) ++
    (if state.mode == .preview then
      wrappedRows width "First classification only; replacement is not available here."
     else []) ++
    (if state.notice.isEmpty then [line ""] else wrappedRows width state.notice)
  Loam.Tui.Layout.boundFeedbackFooter bounds footer

/-- Never Publish when target, description or proposal is hidden by clipping.
    Existing first-classification authority stays in EventMerchantPublisher. -/
def reviewVisible (bounds : Bounds) (state : State) : Bool :=
  let width := Loam.Tui.Layout.contentWidth bounds
  bounds.height >= 14 && width >= 46 &&
    (contentRows width state).length <=
      Loam.Tui.Layout.footerBodyCapacity bounds (footerRows bounds state).length

def viewForContentBounds (bounds : Bounds) (state : State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let footer := footerRows bounds state
  .column ((Loam.Tui.Layout.fitWithFooter bounds
    (contentRows width state) footer).map fun row =>
      Loam.Tui.Layout.clipWidgetRow width row)

/-- Keep the local draft on refused, hidden confirmation; resize can recover. -/
def updateForBounds (bounds : Bounds) (state : State)
    (key : Loam.Tui.Terminal.Key) : Step :=
  if state.mode == .preview && key == .enter && !reviewVisible bounds state then
    { state := { state with
        notice := "Enlarge terminal to review the Merchant target and proposal before Publish." } }
  else update state key

def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 72 24 76 21

def editorBounds (bounds : Bounds) : Bounds :=
  Loam.Tui.ModalSurface.contentBounds bounds (floatingGeometry? bounds)

/-- Geometry only, independent of the first-classification publisher. -/
def viewForBounds (bounds : Bounds) (state : State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds)
    "Event Merchant" (fun inner => viewForContentBounds inner state)

end Loam.Tui.EventMerchant
