import Loam.Application.CapacityInspection
import Loam.Application.ConsumptionInspection
import Loam.Core.ActualValidity
import Loam.Core.Capacity
import Loam.Core.CapacityMemory
import Loam.Core.Effect
import Loam.Core.Event
import Loam.Core.EventMemory
import Loam.Core.HistoricalRouting

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
private def groceries : LocusId := ⟨"groceries"⟩

private def capacityChange
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement?
    (id : String)
    (fromCoordinate toCoordinate : CapacityCoordinate)
    (quanta : Int) : Option CapacityMovement := do
  if quanta <= 0 || fromCoordinate = toCoordinate then
    none
  else
    let balanced ← BalancedMovement.ofChanges? yen
      [capacityChange fromCoordinate (-quanta), capacityChange toCoordinate quanta]
    pure { id := ⟨id⟩, movement := balanced }

private def addCurrentMovement?
    (memory : CapacityMemory)
    (movement : CapacityMovement)
    (source : CapacityCoordinate)
    (quanta : Int) : Option CapacityMemory := do
  if canMoveCapacityFrom memory.movements source yen quanta then
    CapacityMemory.add? memory movement
  else
    none

def main : IO Unit := do
  /-
  One deliberately small development household story.

  It is not canonical household data. The shapes mirror ordinary evidence seen
  in real household operation without copying private dates, names, or amounts:

    unallocated -> Purpose
    Purpose -> Purpose
    Purpose -> unallocated
    Actual occurrence + historical routing -> Consumption / Remaining
  -/
  let empty ← requireSome
    (CapacityMemory.ofMovements? [])
    "empty capacity memory was not admitted"

  let initialFood ← requireSome
    (capacityMovement? "capacity-1" .unallocated (.purpose food) 120)
    "initial food capacity movement was not admitted"
  let memory1 ← requireSome
    (addCurrentMovement? empty initialFood .unallocated 120)
    "initial food capacity was rejected"

  let initialHousehold ← requireSome
    (capacityMovement? "capacity-2" .unallocated (.purpose household) 80)
    "initial household capacity movement was not admitted"
  let memory2 ← requireSome
    (addCurrentMovement? memory1 initialHousehold .unallocated 80)
    "initial household capacity was rejected"

  let reallocation ← requireSome
    (capacityMovement? "capacity-3" (.purpose food) (.purpose household) 20)
    "capacity reallocation was not admitted"
  let memory3 ← requireSome
    (addCurrentMovement? memory2 reallocation (.purpose food) 20)
    "valid food-to-household reallocation was rejected"

  let release ← requireSome
    (capacityMovement? "capacity-4" (.purpose household) .unallocated 10)
    "capacity return movement was not admitted"
  let capacityMemory ← requireSome
    (addCurrentMovement? memory3 release (.purpose household) 10)
    "valid household-to-unallocated return was rejected"

  let foodEntitlement := entitlementAt capacityMemory.movements food yen
  let householdEntitlement := entitlementAt capacityMemory.movements household yen
  expect (foodEntitlement.quanta == 100)
    s!"expected food entitlement 100, got {foodEntitlement.quanta}"
  expect (householdEntitlement.quanta == 90)
    s!"expected household entitlement 90, got {householdEntitlement.quanta}"

  -- One food use and one household use after the capacity history above.
  let coffeeActual ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [Effect.ofQuantity ⟨"pay"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"use"⟩ coffee yen (Quantity.ofQuanta 30)])
    "coffee actual was not admitted"

  let groceriesActual ← requireSome
    (Event.ofEffects? ⟨"actual-2"⟩
      [Effect.ofQuantity ⟨"pay"⟩ paypay yen (Quantity.ofQuanta (-40)),
       Effect.ofQuantity ⟨"use"⟩ groceries yen (Quantity.ofQuanta 40)])
    "groceries actual was not admitted"

  let eventMemory ← requireSome
    (EventMemory.ofEvents? [coffeeActual, groceriesActual])
    "development actual memory was not admitted"

  let actualValidity ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"actual-1"⟩, validOn := (1 : Nat) },
       { event := ⟨"actual-2"⟩, validOn := (2 : Nat) }])
    "development actual validity was not admitted"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee, effectiveOn := (1 : Nat), purpose := some food },
       { subject := groceries, effectiveOn := (1 : Nat), purpose := some household }])
    "development routing history was not admitted"

  let foodConsumption ← requireSome
    (consumptionAtRecorded? eventMemory actualValidity routing food yen)
    "food consumption failed closed"
  let householdConsumption ← requireSome
    (consumptionAtRecorded? eventMemory actualValidity routing household yen)
    "household consumption failed closed"

  expect (foodConsumption.quanta == 30)
    s!"expected food consumption 30, got {foodConsumption.quanta}"
  expect (householdConsumption.quanta == 40)
    s!"expected household consumption 40, got {householdConsumption.quanta}"

  let foodRemaining ← requireSome
    (remainingAtRecorded?
      capacityMemory.movements eventMemory actualValidity routing food yen)
    "food remaining failed closed"
  let householdRemaining ← requireSome
    (remainingAtRecorded?
      capacityMemory.movements eventMemory actualValidity routing household yen)
    "household remaining failed closed"

  expect (foodRemaining.quanta == 70)
    s!"expected food remaining 70, got {foodRemaining.quanta}"
  expect (householdRemaining.quanta == 50)
    s!"expected household remaining 50, got {householdRemaining.quanta}"

  IO.println "Capacity household development story succeeded."
