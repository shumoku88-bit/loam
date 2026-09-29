import Loam.Tui.EditorSession
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

This presentation-only workflow keeps the routine vocabulary small. The top
level remains three ordinary household intents. Existing non-payment reductions
are managed only inside the third branch, so repair capability does not make the
main Settlement surface denser.

Retained row IDs, revision edges, and backend lifecycle vocabulary are never
entered by the user.
-/

inductive Mode where
  | menu (choice : Nat := 0)
  | editAmount (input : String)
  | editAmountPreview (quantity : Quantity)
  | retractConfirm
  | reductionHub (choice : Nat := 0)
  | reductionList (index : Nat := 0)
  | reductionItem (index : Nat) (choice : Nat := 0)
  | reduceAmount (input : String)
  | reduceWhen (quantity : Quantity) (choice : Nat := 0)
  | reduceDate (quantity : Quantity) (input : String)
  | reducePreview (quantity : Quantity) (effectiveOn : Option String)
  | repairAmount (index : Nat) (input : String)
  | repairWhen (index : Nat) (quantity : Quantity) (choice : Nat := 0)
  | repairDate (index : Nat) (quantity : Quantity) (input : String)
  | repairPreview (index : Nat) (quantity : Quantity) (effectiveOn : Option String)
  | repairRetractConfirm (index : Nat)
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
  | correctReduction
      (draft : Loam.SettlementActionPublisher.ReductionCorrection)
  | retractReduction
      (draft : Loam.SettlementActionPublisher.ReductionRetraction)
deriving Repr, DecidableEq

abbrev Step :=
  Loam.Tui.EditorSession.Step State Publish

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

private def reductionAt?
    (state : State)
    (index : Nat) : Option Loam.SettlementReview.ExtinguishmentAllocation :=
  state.row.extinguishments[index]?

private def remainingAfterRepair
    (state : State)
    (current : Loam.SettlementReview.ExtinguishmentAllocation)
    (quantity : Quantity) : Int :=
  state.row.outstanding.quanta + current.quantity.quanta - quantity.quanta

private def remainingAfterReductionRetraction
    (state : State)
    (current : Loam.SettlementReview.ExtinguishmentAllocation) : Int :=
  state.row.outstanding.quanta + current.quantity.quanta

private def editText (text : String) (key : Loam.Tui.Terminal.Key) : String :=
  match key with
  | .backspace => Loam.Tui.Terminal.backspaceText text
  | .input char => if char.isDigit then text.push char else text
  | _ => text

private def menuChoiceCount : Nat := 4
private def hubChoiceCount : Nat := 3
private def itemChoiceCount : Nat := 3
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
      if state.row.extinguishments.isEmpty then
        if state.row.outstanding.quanta <= 0 then
          { state := {
              state with
              notice := "There is no remaining amount to reduce."
            } }
        else
          { state := { state with mode := .reduceAmount "", notice := "" } }
      else
        { state := { state with mode := .reductionHub 0, notice := "" } }
  | _ => { state, cancel := true }

private def enterReductionHub (state : State) (choice : Nat) : Step :=
  match choice % hubChoiceCount with
  | 0 =>
      if state.row.outstanding.quanta <= 0 then
        { state := {
            state with
            notice := "There is no remaining amount to reduce further."
          } }
      else
        { state := { state with mode := .reduceAmount "", notice := "" } }
  | 1 =>
      if state.row.extinguishments.isEmpty then
        { state := { state with notice := "There are no earlier reductions to review." } }
      else
        { state := { state with mode := .reductionList 0, notice := "" } }
  | _ => { state := { state with mode := .menu 2, notice := "" } }

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

private def previewRepairAmount
    (state : State)
    (index : Nat)
    (input : String) : Step :=
  match reductionAt? state index with
  | none => { state := { state with mode := .reductionList 0, notice := "That earlier reduction is no longer available." } }
  | some current =>
      match positiveQuantity? input with
      | .error message => { state := { state with notice := message } }
      | .ok quantity =>
          if remainingAfterRepair state current quantity < 0 then
            { state := {
                state with
                notice := "The corrected reduction would be larger than the amount that can remain explained."
              } }
          else
            { state := {
                state with
                mode := .repairWhen index quantity 0
                notice := ""
              } }

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

private def enterRepairWhen
    (state : State)
    (index : Nat)
    (quantity : Quantity)
    (choice : Nat) : Step :=
  match reductionAt? state index with
  | none =>
      { state := {
          state with
          mode := .reductionList 0
          notice := "That earlier reduction is no longer available."
        } }
  | some current =>
      match choice % whenChoiceCount with
      | 0 =>
          { state := {
              state with
              mode := .repairPreview index quantity current.effectiveOn
              notice := ""
            } }
      | 1 =>
          { state := {
              state with
              mode := .repairDate index quantity (current.effectiveOn.getD state.today)
              notice := ""
            } }
      | _ =>
          { state := {
              state with
              mode := .repairPreview index quantity none
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

private def previewRepairDate
    (state : State)
    (index : Nat)
    (quantity : Quantity)
    (input : String) : Step :=
  if Loam.ActualDate.validIsoDate input then
    { state := {
        state with
        mode := .repairPreview index quantity (some input)
        notice := ""
      } }
  else
    { state := { state with notice := "Date must be a real YYYY-MM-DD calendar date." } }

private def moveReductionIndex
    (state : State)
    (index : Nat)
    (back : Bool) : Nat :=
  let count := state.row.extinguishments.length
  if count = 0 then 0
  else moveChoice index count back

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

  | .reductionHub choice =>
      match key with
      | .escape => { state := { state with mode := .menu 2, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .input 'k' | .input 'K' =>
          { state := { state with mode := .reductionHub (moveChoice choice hubChoiceCount true), notice := "" } }
      | .down | .input 'j' | .input 'J' | .tab =>
          { state := { state with mode := .reductionHub (moveChoice choice hubChoiceCount false), notice := "" } }
      | .input '1' => enterReductionHub state 0
      | .input '2' => enterReductionHub state 1
      | .input '3' => enterReductionHub state 2
      | .enter => enterReductionHub state choice
      | _ => { state }

  | .reductionList index =>
      match key with
      | .escape => { state := { state with mode := .reductionHub 1, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .input 'k' | .input 'K' =>
          { state := { state with mode := .reductionList (moveReductionIndex state index true), notice := "" } }
      | .down | .input 'j' | .input 'J' =>
          { state := { state with mode := .reductionList (moveReductionIndex state index false), notice := "" } }
      | .enter =>
          match reductionAt? state index with
          | none => { state := { state with mode := .reductionHub 1, notice := "There are no earlier reductions to review." } }
          | some _ => { state := { state with mode := .reductionItem index 0, notice := "" } }
      | _ => { state }

  | .reductionItem index choice =>
      match key with
      | .escape => { state := { state with mode := .reductionList index, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .input 'k' | .input 'K' =>
          { state := { state with mode := .reductionItem index (moveChoice choice itemChoiceCount true), notice := "" } }
      | .down | .input 'j' | .input 'J' | .tab =>
          { state := { state with mode := .reductionItem index (moveChoice choice itemChoiceCount false), notice := "" } }
      | .input '1' =>
          match reductionAt? state index with
          | some current => { state := { state with mode := .repairAmount index (toString current.quantity.quanta), notice := "" } }
          | none => { state := { state with mode := .reductionHub 1, notice := "That earlier reduction is no longer available." } }
      | .input '2' =>
          match reductionAt? state index with
          | some _ => { state := { state with mode := .repairRetractConfirm index, notice := "" } }
          | none => { state := { state with mode := .reductionHub 1, notice := "That earlier reduction is no longer available." } }
      | .input '3' => { state := { state with mode := .reductionList index, notice := "" } }
      | .enter =>
          match choice % itemChoiceCount with
          | 0 =>
              match reductionAt? state index with
              | some current => { state := { state with mode := .repairAmount index (toString current.quantity.quanta), notice := "" } }
              | none => { state := { state with mode := .reductionHub 1, notice := "That earlier reduction is no longer available." } }
          | 1 =>
              match reductionAt? state index with
              | some _ => { state := { state with mode := .repairRetractConfirm index, notice := "" } }
              | none => { state := { state with mode := .reductionHub 1, notice := "That earlier reduction is no longer available." } }
          | _ => { state := { state with mode := .reductionList index, notice := "" } }
      | _ => { state }

  | .reduceAmount input =>
      match key with
      | .escape =>
          if state.row.extinguishments.isEmpty then
            { state := { state with mode := .menu 2, notice := "" } }
          else
            { state := { state with mode := .reductionHub 0, notice := "" } }
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
              mode := .reduceDate quantity (Loam.Tui.Terminal.backspaceText input)
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

  | .repairAmount index input =>
      match key with
      | .escape => { state := { state with mode := .reductionItem index 0, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .enter => previewRepairAmount state index input
      | _ => { state := { state with mode := .repairAmount index (editText input key), notice := "" } }

  | .repairWhen index quantity choice =>
      match key with
      | .escape => { state := { state with mode := .repairAmount index (toString quantity.quanta), notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .up | .left | .input 'k' | .input 'K' =>
          { state := { state with mode := .repairWhen index quantity (moveChoice choice whenChoiceCount true), notice := "" } }
      | .down | .right | .input 'j' | .input 'J' | .tab =>
          { state := { state with mode := .repairWhen index quantity (moveChoice choice whenChoiceCount false), notice := "" } }
      | .input '1' => enterRepairWhen state index quantity 0
      | .input '2' => enterRepairWhen state index quantity 1
      | .input '3' => enterRepairWhen state index quantity 2
      | .enter => enterRepairWhen state index quantity choice
      | _ => { state }

  | .repairDate index quantity input =>
      match key with
      | .escape => { state := { state with mode := .repairWhen index quantity 1, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | .enter => previewRepairDate state index quantity input
      | .backspace =>
          { state := { state with mode := .repairDate index quantity (Loam.Tui.Terminal.backspaceText input), notice := "" } }
      | .input char =>
          if char.isDigit || char = '-' then
            { state := { state with mode := .repairDate index quantity (input.push char), notice := "" } }
          else
            { state }
      | _ => { state }

  | .repairPreview index quantity effectiveOn =>
      match key with
      | .enter =>
          match reductionAt? state index with
          | none => { state := { state with mode := .reductionHub 1, notice := "That earlier reduction is no longer available." } }
          | some current =>
              { state
                publish := some (.correctReduction {
                  target := current.id
                  quantity := quantity
                  effectiveOn := effectiveOn
                }) }
      | .escape | .input 'e' | .input 'E' =>
          { state := { state with mode := .repairWhen index quantity 0, notice := "" } }
      | .input 'q' | .input 'Q' => { state, cancel := true }
      | _ => { state }

  | .repairRetractConfirm index =>
      match key with
      | .enter =>
          match reductionAt? state index with
          | none => { state := { state with mode := .reductionHub 1, notice := "That earlier reduction is no longer available." } }
          | some current =>
              { state
                publish := some (.retractReduction { target := current.id }) }
      | .escape => { state := { state with mode := .reductionItem index 1, notice := "" } }
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
  | .repairPreview index quantity effectiveOn =>
      match effectiveOn with
      | none => { state with mode := .repairWhen index quantity 2, notice := message }
      | some date => { state with mode := .repairDate index quantity date, notice := message }
  | .repairRetractConfirm _ =>
      { state with notice := message }
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

private def reductionLabel
    (index : Nat)
    (allocation : Loam.SettlementReview.ExtinguishmentAllocation) : String :=
  let whenText := allocation.effectiveOn.getD "date unknown"
  toString (index + 1) ++ ". " ++
    toString allocation.quantity.quanta ++ "  " ++ whenText

private def reductionListLines
    (state : State)
    (selectedIndex : Nat) : List Widget :=
  if state.row.extinguishments.isEmpty then
    [muted "  (none)"]
  else
    (state.row.extinguishments.zipIdx).map fun (allocation, index) =>
      line ((if index = selectedIndex then "> " else "  ") ++
        reductionLabel index allocation)

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

  | .reductionHub choice =>
      .column <| common ++
        [ line ""
        , line "Non-payment changes"
        , choiceLine (choice % hubChoiceCount = 0) "1" "Record another decrease"
        , choiceLine (choice % hubChoiceCount = 1) "2" "Review an earlier decrease"
        , choiceLine (choice % hubChoiceCount = 2) "3" "Back"
        , muted "This submenu appears only because earlier decreases exist."
        , muted "Up/Down or 1-3 choose   Enter open   Esc back"
        ] ++ noticeLines state

  | .reductionList index =>
      .column <| common ++
        [ line ""
        , line "Earlier decreases"
        ] ++ reductionListLines state index ++
        [ muted "Up/Down select   Enter open   Esc back" ] ++ noticeLines state

  | .reductionItem index choice =>
      match reductionAt? state index with
      | none =>
          .column <| common ++
            [line "", line "That earlier decrease is no longer available."] ++ noticeLines state
      | some current =>
          .column <| common ++
            [ line ""
            , line ("Earlier decrease: " ++
                toString current.quantity.quanta ++ " " ++ state.row.measure.token)
            , line ("When: " ++ current.effectiveOn.getD "date unknown")
            , choiceLine (choice % itemChoiceCount = 0) "1" "Change this decrease"
            , choiceLine (choice % itemChoiceCount = 1) "2" "This decrease record is wrong"
            , choiceLine (choice % itemChoiceCount = 2) "3" "Back"
            , muted "The original history is retained when a correction is published."
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

  | .repairAmount index input =>
      match reductionAt? state index with
      | none => .column <| common ++ [line "", line "That earlier decrease is no longer available."]
      | some current =>
          .column <| common ++
            [ line ""
            , line ("Current decrease: " ++ toString current.quantity.quanta ++
                " " ++ state.row.measure.token)
            , line ("Correct decrease: " ++ if input.isEmpty then "_" else input)
            , muted ("Maximum while keeping the item consistent: " ++
                toString (state.row.outstanding.quanta + current.quantity.quanta) ++
                " " ++ state.row.measure.token)
            , muted "Digits only   Backspace edit   Enter next   Esc back"
            ] ++ noticeLines state

  | .repairWhen index _ choice =>
      match reductionAt? state index with
      | none => .column <| common ++ [line "", line "That earlier decrease is no longer available."]
      | some current =>
          .column <| common ++
            [ line ""
            , line "When should this corrected decrease belong?"
            , choiceLine (choice % whenChoiceCount = 0) "1"
                ("Keep current (" ++ current.effectiveOn.getD "date unknown" ++ ")")
            , choiceLine (choice % whenChoiceCount = 1) "2" "Choose a date"
            , choiceLine (choice % whenChoiceCount = 2) "3" "Date unknown"
            , muted "Unknown is kept unknown; LOAM will not guess a date."
            , muted "Up/Down or 1-3 choose   Enter next   Esc back"
            ] ++ noticeLines state

  | .repairDate _ _ input =>
      .column <| common ++
        [ line ""
        , line ("Correct date: " ++ if input.isEmpty then "_" else input)
        , muted "YYYY-MM-DD   Backspace edit   Enter preview   Esc back"
        ] ++ noticeLines state

  | .repairPreview index quantity effectiveOn =>
      match reductionAt? state index with
      | none => .column <| common ++ [line "", line "That earlier decrease is no longer available."]
      | some current =>
          .column <| common ++
            [ line ""
            , line ("Change earlier decrease from " ++
                toString current.quantity.quanta ++ " to " ++
                toString quantity.quanta ++ " " ++ state.row.measure.token ++ "?")
            , line ("When: " ++ effectiveOn.getD "date unknown")
            , line ("Remaining would be " ++
                toString (remainingAfterRepair state current quantity) ++
                " " ++ state.row.measure.token)
            , muted "The earlier entry stays in history and is superseded by the correction."
            , muted "Enter publish   Esc/e edit   q cancel"
            ] ++ noticeLines state

  | .repairRetractConfirm index =>
      match reductionAt? state index with
      | none => .column <| common ++ [line "", line "That earlier decrease is no longer available."]
      | some current =>
          .column <| common ++
            [ line ""
            , line ("Mark this " ++ toString current.quantity.quanta ++
                " " ++ state.row.measure.token ++ " decrease record as wrong?")
            , line ("Remaining would return to " ++
                toString (remainingAfterReductionRetraction state current) ++
                " " ++ state.row.measure.token)
            , muted "This removes only this decrease from the current view; the obligation stays."
            , muted "Enter confirm   Esc back   q cancel"
            ] ++ noticeLines state

end Loam.Tui.SettlementAction
