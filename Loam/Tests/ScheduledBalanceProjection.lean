import Loam.Application.ScheduledBalanceInspection

open Loam.Core
open Loam.Application

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩
private def rent : LocusId := ⟨"rent"⟩
private def wallet : LocusId := ⟨"wallet"⟩
private def yucho : LocusId := ⟨"yucho"⟩

private def coordinate (locus : LocusId) : EffectCoordinate := ⟨locus, yen⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id : String) (day : Nat) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def actualEvent? : Option Event :=
  Event.ofEffects? ⟨"actual-1"⟩
    [Effect.ofQuantity ⟨"effect-1"⟩ bank yen (Quantity.ofQuanta (-9)),
     Effect.ofQuantity ⟨"effect-2"⟩ wallet yen (Quantity.ofQuanta 9)]

def main : IO Unit := do
  let payment ← requireSome
    (scheduled? "scheduled-payment" 2 [change bank (-30), change rent 30])
    "payment fixture was not admitted"
  let transfer ← requireSome
    (scheduled? "scheduled-transfer" 3 [change bank (-20), change wallet 20])
    "transfer fixture was not admitted"
  let boundary ← requireSome
    (scheduled? "scheduled-boundary" 4 [change bank (-40), change rent 40])
    "boundary fixture was not admitted"
  let overdue ← requireSome
    (scheduled? "scheduled-overdue" 0 [change bank (-5), change wallet 5])
    "overdue fixture was not admitted"
  let retired ← requireSome
    (scheduled? "scheduled-retired" 2 [change bank (-6), change wallet 6])
    "retired fixture was not admitted"
  let completed ← requireSome
    (scheduled? "scheduled-completed" 2 [change bank (-9), change wallet 9])
    "completed fixture was not admitted"

  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences?
      [payment, transfer, boundary, overdue, retired, completed])
    "Scheduled memory was not admitted"
  let actual ← requireSome actualEvent? "Actual fixture was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [actual]) "Event memory was not admitted"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-completed"⟩, target := some (.actual ⟨"actual-1"⟩) },
       { source := ⟨"scheduled-retired"⟩, target := none }])
    "terminal memory was not admitted"

  let projected ← requireSome
    (currentScheduledBalanceEffectsBefore?
      scheduledMemory terminals events
      [coordinate bank, coordinate wallet, coordinate bank, coordinate yucho]
      (4 : Nat))
    "Scheduled balance projection failed closed"

  match projected with
  | [bankEffect, walletEffect, yuchoEffect] =>
      expect (bankEffect.coordinate == coordinate bank)
        "balance-view order did not retain bank first"
      expect (bankEffect.quantity.quanta == -55)
        s!"expected bank Scheduled effect -55, got {bankEffect.quantity.quanta}"
      expect (walletEffect.coordinate == coordinate wallet)
        "balance-view order did not retain wallet second"
      expect (walletEffect.quantity.quanta == 25)
        s!"expected wallet Scheduled effect 25, got {walletEffect.quantity.quanta}"
      expect (yuchoEffect.coordinate == coordinate yucho)
        "explicit zero coordinate was not retained"
      expect (yuchoEffect.quantity.quanta == 0)
        s!"expected yucho Scheduled effect 0, got {yuchoEffect.quantity.quanta}"
  | _ =>
      throw <| IO.userError
        "duplicate balance-view coordinate was not normalized to three projected rows"

  let unknownTerminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"unknown-scheduled"⟩, target := some (.actual ⟨"actual-1"⟩) },
       { source := ⟨"scheduled-retired"⟩, target := none }])
    "unknown terminal fixture shape was not admitted"
  expect
    ((currentScheduledBalanceEffectsBefore?
      scheduledMemory unknownTerminals events
      [coordinate bank] (4 : Nat)).isNone)
    "unknown Scheduled completion endpoint did not fail closed"

  IO.println "Scheduled balance-view projection practical story succeeded."
