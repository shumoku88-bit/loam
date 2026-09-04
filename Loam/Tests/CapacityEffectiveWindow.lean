import Loam.Application.CapacityWindowInspection

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
private def groceries : LocusId := ⟨"groceries"⟩
private def paypay : LocusId := ⟨"paypay"⟩

private def capacityChange
    (coordinate : CapacityCoordinate)
    (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

def main : IO Unit := do
  let balanced ← requireSome
    (BalancedMovement.ofChanges? yen
      [capacityChange .unallocated (-100),
       capacityChange (.purpose food) 100])
    "capacity allocation was not balanced"
  let allocation : CapacityMovement :=
    { id := ⟨"capacity-current"⟩, movement := balanced }
  let capacity ← requireSome
    (CapacityMemory.ofMovements? [allocation])
    "capacity memory was not admitted"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-current"⟩, effectiveOn := (10 : Nat) }])
    "capacity effective evidence was not admitted"

  let oldActual ← requireSome
    (Event.ofEffects? ⟨"actual-old"⟩
      [Effect.ofQuantity ⟨"old-pay"⟩ paypay yen (Quantity.ofQuanta (-20)),
       Effect.ofQuantity ⟨"old-use"⟩ groceries yen (Quantity.ofQuanta 20)])
    "old Actual was not admitted"
  let insideActual ← requireSome
    (Event.ofEffects? ⟨"actual-inside"⟩
      [Effect.ofQuantity ⟨"inside-pay"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"inside-use"⟩ groceries yen (Quantity.ofQuanta 30)])
    "inside Actual was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [oldActual, insideActual])
    "Actual memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"actual-old"⟩, validOn := (9 : Nat) },
       { event := ⟨"actual-inside"⟩, validOn := (10 : Nat) }])
    "Actual validity was not admitted"
  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := groceries,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := some food }])
    "initial food routing was not admitted"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"

  let entitlement ← requireSome
    (entitlementAtEffectiveWindow? capacity effective 10 20 food yen)
    "windowed Entitlement failed closed"
  expect (entitlement.quanta == 100)
    s!"expected windowed Entitlement 100, got {entitlement.quanta}"

  let consumption ← requireSome
    (consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      events corrections validities routing 10 20 food yen)
    "windowed Consumption failed closed"
  expect (consumption.quanta == 30)
    s!"expected windowed Consumption 30, got {consumption.quanta}"

  let remaining ← requireSome
    (remainingAtEffectiveWindow?
      capacity effective events corrections validities routing 10 20 food yen)
    "windowed Remaining failed closed"
  expect (remaining.quanta == 70)
    s!"expected windowed Remaining 70, got {remaining.quanta}"

  let allHistoryRemaining ← requireSome
    (remainingAtRecordedEffectiveRouting?
      capacity.movements events validities routing food yen)
    "all-history comparison failed closed"
  expect (allHistoryRemaining.quanta == 50)
    s!"expected all-history Remaining 50, got {allHistoryRemaining.quanta}"

  let missingEffective ← requireSome
    (CapacityEffectiveMemory.ofEntries? ([] : List (CapacityEffective Nat)))
    "empty effective memory was not admitted"
  expect
    ((entitlementAtEffectiveWindow?
      capacity missingEffective 10 20 food yen).isNone)
    "missing Capacity effective coordinate did not fail closed"

  let orphanEffective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := ⟨"capacity-current"⟩, effectiveOn := (10 : Nat) },
       { movement := ⟨"capacity-orphan"⟩, effectiveOn := (10 : Nat) }])
    "orphan effective fixture itself was not structurally admitted"
  expect
    ((entitlementAtEffectiveWindow?
      capacity orphanEffective 10 20 food yen).isNone)
    "orphan Capacity effective evidence did not fail closed"

  expect
    ((entitlementAtEffectiveWindow?
      capacity effective 20 10 food yen).isNone)
    "reversed Capacity window did not fail closed"
  expect
    ((entitlementAtEffectiveWindow?
      capacity effective 10 10 food yen).isNone)
    "empty Capacity window did not fail closed"

  IO.println "Capacity effective-window practical story succeeded."
