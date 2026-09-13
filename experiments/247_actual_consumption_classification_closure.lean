import Loam.Application.CurrentCoverageInspection
import Loam.Core.Capacity
import Loam.Core.EventCorrection

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
private def general : PurposeId := ⟨"general"⟩
private def cash : LocusId := ⟨"cash"⟩
private def expense : LocusId := ⟨"expense"⟩

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement? (quanta : Int) : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen
    [capacityChange .unallocated (-quanta),
     capacityChange (.purpose food) quanta]
  pure { id := ⟨"capacity-food"⟩, movement := movement }

private def project?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory Nat)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Nat)
    (actualRouting : RoutingHistory LocusId (RoutingEffective Nat))
    (scheduled : ScheduledMemory Nat)
    (terminals : ScheduledTerminalMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Nat) :
    Option CurrentCoverageView :=
  currentCoverageAtCorrectionFrontierEffectiveRouting?
    capacity effective events corrections validities actualRouting
    scheduled terminals roles scheduledRouting
    food yen (1 : Nat) (2 : Nat) (4 : Nat)

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := cash, role := .asset },
       { locus := expense, role := .expense }])
    "AccountingRole fixture was not admitted"
  expect (roles.roleOf? expense == some .expense)
    "selected Actual Locus was not explicitly Expense"

  let actual ← requireSome
    (Event.ofEffects? ⟨"actual-expense"⟩
      [Effect.ofQuantity ⟨"pay"⟩ cash yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"use"⟩ expense yen (Quantity.ofQuanta 30)])
    "Actual fixture was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [actual])
    "Event memory was not admitted"
  let corrections ← requireSome (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := actual.id, validOn := (2 : Nat) }])
    "Actual validity fixture was not admitted"

  let capacityMovement ← requireSome (capacityMovement? 100)
    "Capacity fixture was not admitted"
  let capacity ← requireSome (CapacityMemory.ofMovements? [capacityMovement])
    "Capacity memory was not admitted"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := capacityMovement.id, effectiveOn := (1 : Nat) }])
    "Capacity effective evidence was not admitted"

  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [])
    "empty Scheduled memory was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty Scheduled terminal memory was not admitted"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      ([] : List (RoutingEntry ScheduledRoutingSubject Nat)))
    "empty Scheduled routing history was not admitted"

  let managedFood ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := some food }])
    "food-managed Actual routing was not admitted"
  let managedOther ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := some general }])
    "other-managed Actual routing was not admitted"
  let unmanaged ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := none }])
    "explicitly unmanaged Actual routing was not admitted"
  let unrouted ← requireSome
    (RoutingHistory.ofEntries?
      ([] : List (RoutingEntry LocusId (RoutingEffective Nat))))
    "empty Actual routing history was not admitted"
  let lateManagedFood ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := expense,
         effectiveOn := RoutingEffective.dated (3 : Nat),
         purpose := some food }])
    "late food routing was not admitted"

  let eventCoordinate := RoutingEffective.dated (2 : Nat)
  expect (managedFood.statusAt expense eventCoordinate == .managed food)
    "managed-food world did not classify the Event at its valid coordinate"
  expect (managedOther.statusAt expense eventCoordinate == .managed general)
    "managed-other world did not classify the Event at its valid coordinate"
  expect (unmanaged.statusAt expense eventCoordinate == .unmanaged)
    "unmanaged world lost explicit no-Purpose evidence"
  expect (unrouted.statusAt expense eventCoordinate == .unrouted)
    "unrouted world invented routing evidence"
  expect (lateManagedFood.statusAt expense eventCoordinate == .unrouted)
    "later current routing rewrote earlier Event meaning"
  expect (lateManagedFood.statusAt expense (RoutingEffective.dated (3 : Nat)) == .managed food)
    "late route was not visible at its own effective coordinate"

  let foodView ← requireSome
    (project? capacity effective events corrections validities managedFood
      scheduled terminals roles scheduledRouting)
    "food-managed CurrentCoverage failed closed"
  let otherView ← requireSome
    (project? capacity effective events corrections validities managedOther
      scheduled terminals roles scheduledRouting)
    "other-managed CurrentCoverage failed closed"
  let unmanagedView ← requireSome
    (project? capacity effective events corrections validities unmanaged
      scheduled terminals roles scheduledRouting)
    "unmanaged CurrentCoverage failed closed"
  let unroutedView ← requireSome
    (project? capacity effective events corrections validities unrouted
      scheduled terminals roles scheduledRouting)
    "unrouted CurrentCoverage failed closed"
  let lateView ← requireSome
    (project? capacity effective events corrections validities lateManagedFood
      scheduled terminals roles scheduledRouting)
    "late-routed CurrentCoverage failed closed"

  expect (foodView.entitlement.quanta == 100)
    "food-managed Entitlement changed"
  expect (foodView.consumption.quanta == 30)
    "food-managed Consumption did not include the routed Expense"
  expect (foodView.remaining.quanta == 70)
    "food-managed Remaining was not Entitlement minus Consumption"
  expect (foodView.commitment.quanta == 0 && foodView.headroom.quanta == 70)
    "empty Scheduled evidence changed food-managed Headroom"

  expect (otherView.consumption.quanta == 0 && otherView.remaining.quanta == 100 &&
      otherView.headroom.quanta == 100)
    "other-managed world changed the selected food value"
  expect (unmanagedView.consumption.quanta == 0 && unmanagedView.remaining.quanta == 100 &&
      unmanagedView.headroom.quanta == 100)
    "explicitly unmanaged world changed the selected food value"
  expect (unroutedView.consumption.quanta == 0 && unroutedView.remaining.quanta == 100 &&
      unroutedView.headroom.quanta == 100)
    "unrouted world changed the selected food value"

  -- The current selected numeric answer collapses three distinct routing states.
  expect (otherView == unmanagedView && unmanagedView == unroutedView)
    "CurrentCoverage unexpectedly distinguished resolved-other, unmanaged, and unrouted states"

  -- A route learned only after the Event must not close its historical classification.
  expect (lateView == unroutedView)
    "later routing retroactively changed the Event-valid CurrentCoverage answer"

  -- Adding routing evidence visible at the Event's valid coordinate can change all
  -- downstream CurrentCoverage arithmetic without changing the retained Actual.
  expect (foodView.consumption.quanta != unroutedView.consumption.quanta)
    "event-valid routing evidence could not change Consumption"
  expect (foodView.remaining.quanta != unroutedView.remaining.quanta)
    "event-valid routing evidence could not change Remaining"
  expect (foodView.headroom.quanta != unroutedView.headroom.quanta)
    "event-valid routing evidence could not change Headroom"

  IO.println "Observation 247 witness: selected value and Actual classification closure are distinct."
