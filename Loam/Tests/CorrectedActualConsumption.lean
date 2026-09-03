import Loam.Application.ActualValidityFrontier
import Loam.Application.ConsumptionInspection
import Loam.Core.ActualValidityHistory
import Loam.Core.EventCorrectionMemory

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
private def food : PurposeId := ⟨"food"⟩
private def household : PurposeId := ⟨"household"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def coffee : LocusId := ⟨"coffee"⟩

private def movementEvent?
    (id : String)
    (sourceKey useKey : String)
    (amount : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [Effect.ofQuantity ⟨sourceKey⟩ paypay yen (Quantity.ofQuanta (-amount)),
     Effect.ofQuantity ⟨useKey⟩ coffee yen (Quantity.ofQuanta amount)]

private def capacityChange
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement?
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, movement := movement }

def main : IO Unit := do
  let original ← requireSome
    (movementEvent? "event-original" "original-source" "original-use" 30)
    "original Event was not admitted"
  let revised ← requireSome
    (movementEvent? "event-revised" "revised-source" "revised-use" 20)
    "replacement Event was not admitted"

  let events ← requireSome
    (EventMemory.ofEvents? [original, revised])
    "Event memory was not admitted"

  let correction : EventCorrection := {
    id := ⟨"correction-1"⟩
    target := original.id
    replacement := revised.id
  }
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [correction])
    "Event correction memory was not admitted"

  let foodDay1 ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee, effectiveOn := (1 : Nat), purpose := some food }])
    "day-1 food routing was not admitted"

  -- Raw append-only Event memory contains both original and replacement.
  -- With explicit validity for both on the same day, raw Consumption counts 50,
  -- while the correction-aware frontier counts only the 20 replacement.
  let sameDayValidity ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := original.id, validOn := (1 : Nat) },
       { event := revised.id, validOn := (1 : Nat) }])
    "same-day validity memory was not admitted"

  let rawFood ← requireSome
    (consumptionAtRecorded? events sameDayValidity foodDay1 food yen)
    "raw consumption failed unexpectedly"
  let effectiveFood ← requireSome
    (consumptionAtCorrectionFrontier?
      events corrections sameDayValidity foodDay1 food yen)
    "correction-aware consumption failed unexpectedly"

  expect (rawFood.quanta == 50)
    s!"expected raw append-only consumption 50, got {rawFood.quanta}"
  expect (effectiveFood.quanta == 20)
    s!"expected correction-effective consumption 20, got {effectiveFood.quanta}"

  let grant ← requireSome
    (capacityMovement? "capacity-1"
      [capacityChange .unallocated (-100),
       capacityChange (.purpose food) 100])
    "capacity grant was not admitted"

  let effectiveRemaining ← requireSome
    (remainingAtCorrectionFrontier?
      [grant] events corrections sameDayValidity foodDay1 food yen)
    "correction-aware remaining failed unexpectedly"
  expect (effectiveRemaining.quanta == 80)
    s!"expected correction-effective remaining 80, got {effectiveRemaining.quanta}"

  -- The target's date is not inherited semantically. If the current replacement
  -- lacks its own validity evidence, the correction-aware projection fails closed.
  let targetOnlyValidity ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := original.id, validOn := (1 : Nat) }])
    "target-only validity memory was not admitted"
  expect
    (consumptionAtCorrectionFrontier?
      events corrections targetOnlyValidity foodDay1 food yen).isNone
    "replacement without explicit validity did not fail closed"

  -- Actual-validity correction remains an independent frontier. The replacement
  -- moves from day 1 to day 2; historical routing therefore moves its Consumption
  -- from food to household without changing Event correction evidence.
  let validityHistory ← requireSome
    (ActualValidityHistory.ofParts?
      [ { id := ⟨"validity-original"⟩, event := original.id, validOn := (1 : Nat) },
        { id := ⟨"validity-revised-old"⟩, event := revised.id, validOn := (1 : Nat) },
        { id := ⟨"validity-revised-new"⟩, event := revised.id, validOn := (2 : Nat) } ]
      [ { id := ⟨"validity-correction-1"⟩,
          target := ⟨"validity-revised-old"⟩,
          replacement := ⟨"validity-revised-new"⟩ } ])
    "append-only validity history was not admitted"

  let currentValidity ← requireSome
    (admittedActualValidityMemory? validityHistory)
    "validity correction frontier was not admitted"

  let historicalRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee, effectiveOn := (1 : Nat), purpose := some food },
       { subject := coffee, effectiveOn := (2 : Nat), purpose := some household }])
    "historical routing was not admitted"

  let foodAfterDateCorrection ← requireSome
    (consumptionAtCorrectionFrontier?
      events corrections currentValidity historicalRouting food yen)
    "food projection after date correction failed"
  let householdAfterDateCorrection ← requireSome
    (consumptionAtCorrectionFrontier?
      events corrections currentValidity historicalRouting household yen)
    "household projection after date correction failed"

  expect (foodAfterDateCorrection.quanta == 0)
    s!"expected corrected replacement to leave food consumption, got {foodAfterDateCorrection.quanta}"
  expect (householdAfterDateCorrection.quanta == 20)
    s!"expected corrected replacement to route 20 to household, got {householdAfterDateCorrection.quanta}"

  IO.println "Correction-aware Consumption / Remaining composition assertions succeeded."
