import Loam.ActualDate
import Loam.SettlementActionPublisher
import Loam.SettlementReview
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.SettlementAction

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Friendly settlement action editor

This is a presentation-only translator from ordinary household intent to the
surface-neutral `SettlementActionPublisher` drafts.

It deliberately does not expose retained row IDs, revision edges, or the word
"extinguishment" in its ordinary workflow.
-/

inductive Mode where
  | menu (choice : Nat := 0)
  | editAmount (input : String)
  | editAmountPreview (quantity : Quantity)
  | retractConfirm
  | reduceAmount (input : String)
  | reduceWhen (quantity : Quantity) (choice : Nat := 0)
  | reduceDate (quantity : Quantity) (input : String)
  | reducePreview (quantity : Quantity) (effectiveOn : Option String)
deriving Repr, DecidableEq

structure State where
  row : Loam.SettlementReview.Row
  today : String
  mode : Mode := .menu
  notice : String := ""
deriving Repr, DecidableEq

inductive Publish where
  | correctAmount (draft : Loam.SettlementActionPublisher.AmountCorrection)
  | retract (draft : Loam.SettlementActionPublisher.Retraction)
  | reduceWithoutPayment
      (draft : Loam.SettlementActionPublisher.NonSettlementReduction)
deriving Repr, DecidableEq

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Publish := none

def initial
    (today : String)
    (row : Loam.SettlementReview.Row) : State :=
  { row := row, today := today }

private def displayName (row : Loam.SettlementReview.Row) : String :=
  match row.label with
  | some label => if label.isEmpty then row.id.token else label
  | none => row.id.token

private def digitsOnly (text : String) : Bool :=
  !text.isEmpty && text.toList.all Char.isDigit

private def positiveQuantity? (text : String) : Except String Quantity := do
  if !digitsOnly text then
    throw "Enter a positive whole-number amount."
  let some amount := text.toInt?
    | throw "Enter a positive whole-number amount."
  if amount <= 0 then
    throw "Amount must be greater than zero."
  pure (Quantity.ofQuanta amount)

private def explainedQuanta (row : Loam.SettlementReview.Row) : Int :=
  row.settled.quanta + row.extinguished.quanta

private def remainingForAmount
    (row : Loam.SettlementReview.Row)
    (quantity : Quantity) : Int :=
  quantity.quanta - explainedQuanta row

private def editText (text : String) (key : Loam.Tui.Terminal.Key) : String :=
  match key with
  | .backspace => String.ofList text.toList.dropLast
  | .input char => if char.isDigit then text.push char else text
  | _ => text

private def menuChoiceCount : Nat := 4
private def whenChoiceCount : Nat := 3

private def moveChoice (choice count : Nat) (back : Bool) : Nat :=
  if count = 0 then 0
  else if back then (choice + count - 1) % count
  else (choice + 1) % count

private def enterMenu (state : State) (choice : Nat) : Step :=
  match choice % menuChoiceCount with
  | 0 =>
      { state := {
          state with
          mode := .editAmount (toString state.row.committed.quanta)
          notice := ""
        } }
  | 1 =>
      if explainedQuanta state.row = 0 then
        { state := { state with mode := .retractConfirm, notice := "" } }
      else
        { state := {
            state with
            notice :=
              "This item already has later payment or adjustment activity, so the whole record cannot be marked wrong here."
          } }
  | 2 =>
      if state.row.outstanding.quanta <= 0 then
        { state := {
            state with
            notice := "There is no remaining amount to reduce."
          } }
      else
        { state := { state with mode := .reduceAmount "", notice := "" } }
  | _ => { state, cancel := true }

private def previewCorrectAmount
    (state : State)
    (input : String) : Step :=
  match positiveQuantity? input with
  | .error message => { state := { state with notice := message } }
  | .ok quantity =>
      if quantity = state.row.committed then
        { state := { state with notice := "That is already the current amount." } }
      else if remainingForAmount state.row quantity < 0 then
        { state := {
            state with
            notice :=
              "The new amount is smaller than payment/adjustment already recorded for this item."
          } }
      else
        { state := {
            state with
            mode := .editAmountPreview quantity
            notice := ""
          } }

private def previewReduceAmount
    (state : State)
    (input : String) : Step :=
  match positiveQuantity? input with
  | .error message => { state := { state with notice := message } }
  | .ok quantity =>
      if quantity.quanta > state.row.outstanding.quanta then
        { state := {
            state with
            notice := "Reduction cannot be larger than the remaining amount."
          } }
      else
        { state := { state with mode := .reduceWhen quantity 0, notice := "" } }

private def enterWhen
    (state : State)
    (quantity : Quantity)
    (choice : Nat) : Step :=
  match choice % whenChoiceCount with
  | 0 =>
      { state := {
          state with
          mode := .reducePreview quantity (some state.today)
          notice := ""
        } }
  | 1 =>
      { state := {
          state with
          mode := .reduceDate quantity state.today
          notice := ""
        } }
  | _ =>
      { state := {
          state with
          mode := .reducePreview quantity none
          notice := ""
        } }

private def previewDate
    (state : State)
    (quantity : Quantity)
    (input : String) : Step :=
  if Loam.ActualDate.validIsoDate input then
    { state := {
        state with
        mode := .reducePreview quantity (some input)
        notice := ""
      } }
  else
    { state := { state with notice := "Date must be a real YYYY-MM-DD calendar date." } }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .menu choice =>
      match key with
      | .escape | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .input 'k' | .input 'K' =>
          { state := { state with mode := .menu (moveChoice choice menuChoiceCount true), notice := "" } }
      | .down | .input 'j' | .input 'J' | .tab =>
          { state := { state with mode := .menu (moveChoice choice menuChoiceCount false), notice := "" } }
      | .input '1' => enterMenu state 0
      | .input '2' => enterMenu state 1
      | .input '3' => enterMenu state 2
      | .enter => enterMenu state choice
      | _ => { state }

  | .editAmount input =>
      match key with
      | .escape => { state := { state with mode := .menu 0, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .enter => previewCorrectAmount state input
      | _ => { state := { state with mode := .editAmount (editText input key), notice := "" } }

  | .editAmountPreview quantity =>
      match key with
      | .enter =>
          { state
            publish := some (.correctAmount {
              target := state.row.id
              quantity := quantity
            }) }
      | .escape | .input 'e' | .input 'E' =>
          { state := {
              state with
              mode := .editAmount (toString quantity.quanta)
              notice := ""
            } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

  | .retractConfirm =>
      match key with
      | .enter =>
          { state
            publish := some (.retract { target := state.row.id }) }
      | .escape => { state := { state with mode := .menu 1, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

  | .reduceAmount input =>
      match key with
      | .escape => { state := { state with mode := .menu 2, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .enter => previewReduceAmount state input
      | _ => { state := { state with mode := .reduceAmount (editText input key), notice := "" } }

  | .reduceWhen quantity choice =>
      match key with
      | .escape =>
          { state := {
              state with
              mode := .reduceAmount (toString quantity.quanta)
              notice := ""
            } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .left | .input 'k' | .input 'K' =>
          { state := {
              state with
              mode := .reduceWhen quantity (moveChoice choice whenChoiceCount true)
              notice := ""
            } }
      | .down | .right | .input 'j' | .input 'J' | .tab =>
          { state := {
              state with
              mode := .reduceWhen quantity (moveChoice choice whenChoiceCount false)
              notice := ""
            } }
      | .input '1' => enterWhen state quantity 0
      | .input '2' => enterWhen state quantity 1
      | .input '3' => enterWhen state quantity 2
      | .enter => enterWhen state quantity choice
      | _ => { state }

  | .reduceDate quantity input =>
      match key with
      | .escape =>
          { state := { state with mode := .reduceWhen quantity 1, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .enter => previewDate state quantity input
      | .backspace =>
          { state := {
              state with
              mode := .reduceDate quantity (String.ofList input.toList.dropLast)
              notice := ""
            } }
      | .input char =>
          if char.isDigit || char = '-' then
            { state := {
                state with
                mode := .reduceDate quantity (input.push char)
                notice := ""
              } }
          else
            { state }
      | _ => { state }

  | .reducePreview quantity effectiveOn =>
      match key with
      | .enter =>
          { state
            publish := some (.reduceWithoutPayment {
              target := state.row.id
              quantity := quantity
              effectiveOn := effectiveOn
            }) }
      | .escape | .input 'e' | .input 'E' =>
          { state := {
              state with
              mode := .reduceWhen quantity
                (if effectiveOn.isNone then 2 else 0)
              notice := ""
            } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

/-- Return a refused publication to a safe editable surface. -/
def withPublishError (state : State) (message : String) : State :=
  match state.mode with
  | .editAmountPreview quantity =>
      { state with mode := .editAmount (toString quantity.quanta), notice := message }
  | .retractConfirm =>
      { state with notice := message }
  | .reducePreview quantity effectiveOn =>
      match effectiveOn with
      | none => { state with mode := .reduceWhen quantity 2, notice := message }
      | some date => { state with mode := .reduceDate quantity date, notice := message }
  | _ => { state with notice := message }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def choiceLine (selected : Bool) (number label : String) : Widget :=
  line ((if selected then "> " else "  ") ++ number ++ ". " ++ label)

private def header (state : State) : List Widget :=
  [ line "Settlement / Action"
  , line (displayName state.row)
  , muted
      ("Remaining " ++ toString state.row.outstanding.quanta ++
        " " ++ state.row.measure.token)
  ]

private def noticeLines (state : State) : List Widget :=
  if state.notice.isEmpty then [] else [line state.notice]

def view (state : State) : Widget :=
  let common := header state
  match state.mode with
  | .menu choice =>
      .column <| common ++
        [ line ""
        , line "What do you want to do?"
        , choiceLine (choice % menuChoiceCount = 0) "1" "Change the original amount"
        , choiceLine (choice % menuChoiceCount = 1) "2" "This record itself is wrong"
        , choiceLine (choice % menuChoiceCount = 2) "3" "Remaining amount decreased without payment"
        , choiceLine (choice % menuChoiceCount = 3) "4" "Back"
        , muted "Up/Down or 1-3 choose   Enter open   Esc/q back"
        ] ++ noticeLines state

  | .editAmount input =>
      .column <| common ++
        [ line ""
        , line ("Current amount: " ++ toString state.row.committed.quanta ++
            " " ++ state.row.measure.token)
        , line ("Correct amount: " ++ if input.isEmpty then "_" else input)
        , muted "This corrects the original amount; earlier evidence stays in history."
        , muted "Digits only   Backspace edit   Enter preview   Esc back"
        ] ++ noticeLines state

  | .editAmountPreview quantity =>
      .column <| common ++
        [ line ""
        , line ("Change amount to " ++ toString quantity.quanta ++
            " " ++ state.row.measure.token ++ "?")
        , line ("Remaining would be " ++
            toString (remainingForAmount state.row quantity) ++
            " " ++ state.row.measure.token)
        , muted "Enter publish   Esc/e edit   q cancel"
        ] ++ noticeLines state

  | .retractConfirm =>
      .column <| common ++
        [ line ""
        , line "Mark this obligation record itself as wrong?"
        , muted "Use this only when the obligation record was erroneous."
        , muted "This does not mean paid, waived, or otherwise reduced."
        , muted "Enter confirm   Esc back   q cancel"
        ] ++ noticeLines state

  | .reduceAmount input =>
      .column <| common ++
        [ line ""
        , line ("Amount no longer due without payment: " ++
            if input.isEmpty then "_" else input)
        , muted ("Maximum: " ++ toString state.row.outstanding.quanta ++
            " " ++ state.row.measure.token)
        , muted "Digits only   Backspace edit   Enter next   Esc back"
        ] ++ noticeLines state

  | .reduceWhen _ choice =>
      .column <| common ++
        [ line ""
        , line "When did the change happen?"
        , choiceLine (choice % whenChoiceCount = 0) "1" ("Today (" ++ state.today ++ ")")
        , choiceLine (choice % whenChoiceCount = 1) "2" "Choose a date"
        , choiceLine (choice % whenChoiceCount = 2) "3" "I don't know"
        , muted "Unknown is kept unknown; LOAM will not guess a date."
        , muted "Up/Down or 1-3 choose   Enter next   Esc back"
        ] ++ noticeLines state

  | .reduceDate _ input =>
      .column <| common ++
        [ line ""
        , line ("Date: " ++ if input.isEmpty then "_" else input)
        , muted "YYYY-MM-DD   Backspace edit   Enter preview   Esc back"
        ] ++ noticeLines state

  | .reducePreview quantity effectiveOn =>
      let whenText := effectiveOn.getD "date unknown"
      .column <| common ++
        [ line ""
        , line ("Reduce remaining amount by " ++ toString quantity.quanta ++
            " " ++ state.row.measure.token ++ "?")
        , line ("When: " ++ whenText)
        , line ("Remaining would be " ++
            toString (state.row.outstanding.quanta - quantity.quanta) ++
            " " ++ state.row.measure.token)
        , muted "This records a real reduction without payment; it does not erase the obligation history."
        , muted "Enter publish   Esc/e edit   q cancel"
        ] ++ noticeLines state

end Loam.Tui.SettlementAction
