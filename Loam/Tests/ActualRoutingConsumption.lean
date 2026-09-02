import Loam.Application.CapacityInspection
import Loam.Application.ConsumptionInspection
import Loam.Core.Effect
import Loam.Core.Event
import Loam.Core.EventMemory
import Loam.Core.Capacity
import Loam.Core.HistoricalRouting
import Loam.Core.ActualValidity

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
private def usd : MeasureId := ⟨"usd"⟩

private def food : PurposeId := ⟨"food"⟩
private def household : PurposeId := ⟨"household"⟩

private def paypay : LocusId := ⟨"paypay"⟩
private def coffee : LocusId := ⟨"coffee"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) :
    MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement?
    (id : String)
    (changes : List (MovementChange CapacityCoordinate)) : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, movement := movement }

def main : IO Unit := do
  -- 1. Capacity evidence
  let capMv ← requireSome
    (capacityMovement? "cap-1"
      [capacityChange .unallocated (-100),
       capacityChange (.purpose food) 100])
    "capacity grant specimen was not admitted"
  let movements := [capMv]

  let foodEntitlement := entitlementAt movements food yen
  expect (foodEntitlement.quanta == 100)
    s!"expected food entitlement 100, got {foodEntitlement.quanta}"

  -- 2. Actual events
  -- Day 1: paypay -30, coffee +30
  let ev1 ← requireSome
    (Event.ofEffects? ⟨"ev-1"⟩
      [Effect.ofQuantity ⟨"k1"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"k2"⟩ coffee yen (Quantity.ofQuanta 30)])
    "event 1 was not admitted"

  -- Day 2: paypay -20, coffee +20
  let ev2 ← requireSome
    (Event.ofEffects? ⟨"ev-2"⟩
      [Effect.ofQuantity ⟨"k1"⟩ paypay yen (Quantity.ofQuanta (-20)),
       Effect.ofQuantity ⟨"k2"⟩ coffee yen (Quantity.ofQuanta 20)])
    "event 2 was not admitted"

  let eventMemory ← requireSome
    (EventMemory.ofEvents? [ev1, ev2])
    "event memory was not admitted"

  -- 3. Actual valid coordinates
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"ev-1"⟩, validOn := (1 : Nat) },
       { event := ⟨"ev-2"⟩, validOn := (2 : Nat) }])
    "actual validity memory was not admitted"

  -- 4. Historical Locus routing
  -- coffee @ day 1 -> food
  -- coffee @ day 2 -> explicitly unmanaged
  let routingHistory ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee, effectiveOn := (1 : Nat), purpose := some food },
       { subject := coffee, effectiveOn := (2 : Nat), purpose := none }])
    "routing history was not admitted"

  -- Verification of three-way routing states:
  -- Day 1 coffee effect is food managed
  expect (routingHistory.statusAt coffee 1 == .managed food)
    "coffee at day 1 was not managed under food"

  -- Day 2 coffee effect is explicitly unmanaged
  expect (routingHistory.statusAt coffee 2 == .unmanaged)
    "coffee at day 2 was not explicitly unmanaged"

  -- Prior to day 1, coffee is unrouted
  expect (routingHistory.statusAt coffee 0 == .unrouted)
    "coffee at day 0 was not unrouted"

  -- Unrouted locus (paypay) is distinct from explicitly unmanaged
  expect (routingHistory.statusAt paypay 1 == .unrouted)
    "unrouted paypay at day 1 was conflated with managed/unmanaged"
  expect (routingHistory.statusAt paypay 2 == .unrouted)
    "unrouted paypay at day 2 was conflated with managed/unmanaged"

  -- Current (day 2) routing does not retroactively rewrite day 1 meaning
  expect (routingHistory.statusAt coffee 1 != routingHistory.statusAt coffee 2)
    "historical routing retroactively collapsed across day 1 and day 2"

  -- Projections:
  -- food Consumption = 30
  let foodConsumption ← requireSome
    (consumptionAtRecorded? eventMemory validities routingHistory food yen)
    "food consumption projection failed closed"
  expect (foodConsumption.quanta == 30)
    s!"expected food consumption 30, got {foodConsumption.quanta}"

  -- food Remaining = 70
  let foodRemaining ← requireSome
    (remainingAtRecorded? movements eventMemory validities routingHistory food yen)
    "food remaining projection failed closed"
  expect (foodRemaining.quanta == 70)
    s!"expected food remaining 70 (100 - 30), got {foodRemaining.quanta}"

  -- 5. Multi-purpose single event
  -- One Event with coffee +60, groceries +40, paypay -100
  let ev3 ← requireSome
    (Event.ofEffects? ⟨"ev-3"⟩
      [Effect.ofQuantity ⟨"k-coffee"⟩ coffee yen (Quantity.ofQuanta 60),
       Effect.ofQuantity ⟨"k-groceries"⟩ groceries yen (Quantity.ofQuanta 40),
       Effect.ofQuantity ⟨"k-paypay"⟩ paypay yen (Quantity.ofQuanta (-100))])
    "multi-purpose event 3 was not admitted"

  -- Distinct EffectKeys are preserved within the event
  expect (ev3.effects.map Effect.key == [⟨"k-coffee"⟩, ⟨"k-groceries"⟩, ⟨"k-paypay"⟩])
    "effect keys were not preserved in multi-purpose event"

  let eventMemoryMulti ← requireSome
    (EventMemory.ofEvents? [ev3])
    "multi-purpose event memory was not admitted"

  let validitiesMulti ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"ev-3"⟩, validOn := (1 : Nat) }])
    "multi-purpose validity memory was not admitted"

  let routingMulti ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee, effectiveOn := (1 : Nat), purpose := some food },
       { subject := groceries, effectiveOn := (1 : Nat), purpose := some household }])
    "multi-purpose routing history was not admitted"

  let foodConsMulti ← requireSome
    (consumptionAtRecorded? eventMemoryMulti validitiesMulti routingMulti food yen)
    "multi-purpose food consumption failed closed"
  let hhConsMulti ← requireSome
    (consumptionAtRecorded? eventMemoryMulti validitiesMulti routingMulti household yen)
    "multi-purpose household consumption failed closed"

  expect (foodConsMulti.quanta == 60)
    s!"expected food consumption 60 from multi-purpose event, got {foodConsMulti.quanta}"
  expect (hhConsMulti.quanta == 40)
    s!"expected household consumption 40 from multi-purpose event, got {hhConsMulti.quanta}"

  -- 6. Measure isolation
  -- An effect in USD does not mix into JPY consumption
  let evUsd ← requireSome
    (Event.ofEffects? ⟨"ev-usd"⟩
      [Effect.ofQuantity ⟨"k-usd"⟩ coffee usd (Quantity.ofQuanta 500)])
    "USD event was not admitted"
  let eventMemoryUsd ← requireSome
    (EventMemory.ofEvents? [ev1, evUsd])
    "combined JPY and USD event memory was not admitted"
  let validitiesUsd ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"ev-1"⟩, validOn := (1 : Nat) },
       { event := ⟨"ev-usd"⟩, validOn := (1 : Nat) }])
    "validities for USD event memory was not admitted"

  let jpyConsWithUsd ← requireSome
    (consumptionAtRecorded? eventMemoryUsd validitiesUsd routingHistory food yen)
    "JPY consumption with USD event failed closed"
  expect (jpyConsWithUsd.quanta == 30)
    s!"USD effect leaked into JPY consumption, got {jpyConsWithUsd.quanta}"

  let usdCons ← requireSome
    (consumptionAtRecorded? eventMemoryUsd validitiesUsd routingHistory food usd)
    "USD consumption failed closed"
  expect (usdCons.quanta == 500)
    s!"expected USD consumption 500, got {usdCons.quanta}"

  -- 7. Refund handling (signed quantities summed as-is)
  -- coffee -10 refund on day 1
  let evRefund ← requireSome
    (Event.ofEffects? ⟨"ev-refund"⟩
      [Effect.ofQuantity ⟨"k1"⟩ paypay yen (Quantity.ofQuanta 10),
       Effect.ofQuantity ⟨"k2"⟩ coffee yen (Quantity.ofQuanta (-10))])
    "refund event was not admitted"
  let eventMemoryWithRefund ← requireSome
    (EventMemory.ofEvents? [ev1, ev2, evRefund])
    "event memory with refund was not admitted"
  let validitiesWithRefund ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"ev-1"⟩, validOn := (1 : Nat) },
       { event := ⟨"ev-2"⟩, validOn := (2 : Nat) },
       { event := ⟨"ev-refund"⟩, validOn := (1 : Nat) }])
    "validities with refund was not admitted"

  let foodConsWithRefund ← requireSome
    (consumptionAtRecorded? eventMemoryWithRefund validitiesWithRefund routingHistory food yen)
    "consumption with refund failed closed"
  expect (foodConsWithRefund.quanta == 20)
    s!"expected food consumption 20 (30 - 10) after refund, got {foodConsWithRefund.quanta}"

  let remainingWithRefund ← requireSome
    (remainingAtRecorded? movements eventMemoryWithRefund validitiesWithRefund routingHistory food yen)
    "remaining with refund failed closed"
  expect (remainingWithRefund.quanta == 80)
    s!"expected food remaining 80 (100 - 20) after refund, got {remainingWithRefund.quanta}"

  -- 8. Fail-closed admission: duplicate (subject, effectiveOn) routing evidence
  let duplicateRouting := RoutingHistory.ofEntries?
    [{ subject := coffee, effectiveOn := (1 : Nat), purpose := some food },
     { subject := coffee, effectiveOn := (1 : Nat), purpose := none }]
  expect duplicateRouting.isNone
    "duplicate (subject, effectiveOn) routing evidence was admitted"

  -- 9. Fail-closed admission: duplicate EventId validity evidence
  let duplicateValidity := ActualValidityMemory.ofEntries?
    [{ event := ⟨"ev-1"⟩, validOn := (1 : Nat) },
     { event := ⟨"ev-1"⟩, validOn := (2 : Nat) }]
  expect duplicateValidity.isNone
    "duplicate EventId actual validity evidence was admitted"

  -- 10. Fail-closed projection: missing validity evidence for remembered Event
  let incompleteValidity ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"ev-1"⟩, validOn := (1 : Nat) }])
    "single validity entry was not admitted"
  -- ev2 in eventMemory lacks validity evidence
  let missingValidityConsumption :=
    consumptionAtRecorded? eventMemory incompleteValidity routingHistory food yen
  expect missingValidityConsumption.isNone
    "consumption did not fail closed when an Event lacked validity evidence"

  let missingValidityRemaining :=
    remainingAtRecorded? movements eventMemory incompleteValidity routingHistory food yen
  expect missingValidityRemaining.isNone
    "remaining did not fail closed when an Event lacked validity evidence"

  -- 11. Storage order does not determine latest routing semantics
  let reverseRoutingHistory ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := coffee, effectiveOn := (2 : Nat), purpose := none },
       { subject := coffee, effectiveOn := (1 : Nat), purpose := some food }])
    "reverse routing history was not admitted"
  expect (reverseRoutingHistory.statusAt coffee 1 == .managed food)
    "reverse routing storage order broke day 1 latest status"
  expect (reverseRoutingHistory.statusAt coffee 2 == .unmanaged)
    "reverse routing storage order broke day 2 latest status"

  let reverseFoodConsumption ← requireSome
    (consumptionAtRecorded? eventMemory validities reverseRoutingHistory food yen)
    "consumption with reverse routing history failed closed"
  expect (reverseFoodConsumption.quanta == 30)
    "reverse routing storage order changed consumption quantity"

  IO.println "All Slice A2 executable specimen assertions succeeded."
