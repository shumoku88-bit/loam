import Loam.Application.CurrentCoverageInspection
import Loam.Core.Capacity
import Loam.Core.EventCorrection

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def yen : MeasureId := ⟨"jpy"⟩
private def savings : PurposeId := ⟨"savings"⟩
private def bank : LocusId := ⟨"bank"⟩
private def savingsAsset : LocusId := ⟨"savings-asset"⟩

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement? : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen
    [capacityChange .unallocated (-5000),
     capacityChange (.purpose savings) 5000]
  pure { id := ⟨"capacity-savings"⟩, movement := movement }

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
    savings yen (1 : Nat) (2 : Nat) (4 : Nat)

/--
Observation-local stand-in for Observation 248's candidate boundary.
It deliberately notices only explicitly-Expense coordinates.
-/
private def expenseOnlyUnroutedCount
    (event : Event)
    (validOn : Nat)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory LocusId (RoutingEffective Nat)) : Nat :=
  event.effects.foldl
    (fun count effect =>
      if effect.measure = yen &&
          roles.roleOf? effect.locus = some .expense &&
          routing.statusAt effect.locus (.dated validOn) = .unrouted then
        count + 1
      else
        count)
    0

def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := bank, role := .asset },
       { locus := savingsAsset, role := .asset }])
    "AccountingRole fixture was not admitted"
  expect (roles.roleOf? bank == some .asset && roles.roleOf? savingsAsset == some .asset)
    "asset roles were not retained"

  let actual ← requireSome
    (Event.ofEffects? ⟨"move-to-savings"⟩
      [Effect.ofQuantity ⟨"from-bank"⟩ bank yen (Quantity.ofQuanta (-5000)),
       Effect.ofQuantity ⟨"to-savings"⟩ savingsAsset yen (Quantity.ofQuanta 5000)])
    "Actual fixture was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [actual])
    "Event memory was not admitted"
  let corrections ← requireSome (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := actual.id, validOn := (2 : Nat) }])
    "Actual validity fixture was not admitted"

  let movement ← requireSome capacityMovement? "Capacity fixture was not admitted"
  let capacity ← requireSome (CapacityMemory.ofMovements? [movement])
    "Capacity memory was not admitted"
  let effective ← requireSome
    (CapacityEffectiveMemory.ofEntries?
      [{ movement := movement.id, effectiveOn := (1 : Nat) }])
    "Capacity effective evidence was not admitted"

  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [])
    "empty Scheduled memory was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty Scheduled terminal memory was not admitted"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      ([] : List (RoutingEntry ScheduledRoutingSubject Nat)))
    "empty Scheduled routing history was not admitted"

  let unrouted ← requireSome
    (RoutingHistory.ofEntries?
      ([] : List (RoutingEntry LocusId (RoutingEffective Nat))))
    "empty Actual routing history was not admitted"
  let routedSavings ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := savingsAsset,
         effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
         purpose := some savings }])
    "savings-Asset routing was not admitted"

  let eventCoordinate := RoutingEffective.dated (2 : Nat)
  expect (unrouted.statusAt savingsAsset eventCoordinate == .unrouted)
    "unrouted world invented savings routing"
  expect (routedSavings.statusAt savingsAsset eventCoordinate == .managed savings)
    "routed world did not classify the savings Asset"

  -- Observation 248's Expense-only boundary is empty in both worlds because the
  -- coordinate that matters to this Purpose is explicitly an Asset.
  expect (expenseOnlyUnroutedCount actual 2 roles unrouted == 0)
    "Expense-only frontier unexpectedly included an Asset"
  expect (expenseOnlyUnroutedCount actual 2 roles routedSavings == 0)
    "Expense-only frontier changed after routing an Asset"

  let openView ← requireSome
    (project? capacity effective events corrections validities unrouted
      scheduled terminals roles scheduledRouting)
    "unrouted CurrentCoverage failed closed"
  let routedView ← requireSome
    (project? capacity effective events corrections validities routedSavings
      scheduled terminals roles scheduledRouting)
    "routed CurrentCoverage failed closed"

  expect (openView.entitlement.quanta == 5000 && routedView.entitlement.quanta == 5000)
    "routing evidence changed Capacity Entitlement"
  expect (openView.commitment.quanta == 0 && routedView.commitment.quanta == 0)
    "empty Scheduled evidence changed Commitment"

  -- With no route, the selected value is numerically silent even though routing
  -- the Asset at the Event-valid coordinate can change the answer.
  expect (openView.consumption.quanta == 0)
    "unrouted Asset unexpectedly contributed to Consumption"
  expect (openView.remaining.quanta == 5000 && openView.headroom.quanta == 5000)
    "unrouted savings world did not preserve the full selected remainder"

  expect (routedView.consumption.quanta == 5000)
    "routed savings Asset did not contribute to selected Consumption"
  expect (routedView.remaining.quanta == 0 && routedView.headroom.quanta == 0)
    "routed savings world did not consume selected Capacity"

  expect (openView != routedView)
    "routing an Asset could not change CurrentCoverage"

  IO.println "Observation 249 witness: an empty Expense-only frontier does not establish CurrentCoverage classification closure."
