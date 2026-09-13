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

private def event?
    (id : String) (fromQuanta toQuanta : Int) : Option Event :=
  Event.ofEffects? ⟨id⟩
    [Effect.ofQuantity ⟨id ++ "-bank"⟩ bank yen (Quantity.ofQuanta fromQuanta),
     Effect.ofQuantity ⟨id ++ "-savings"⟩ savingsAsset yen (Quantity.ofQuanta toQuanta)]

private def project?
    (events : EventMemory)
    (validities : ActualValidityMemory Nat)
    (observedAt : Nat) : Option CurrentCoverageView := do
  let movement ← capacityMovement?
  let capacity ← CapacityMemory.ofMovements? [movement]
  let effective ← CapacityEffectiveMemory.ofEntries?
    [{ movement := movement.id, effectiveOn := (1 : Nat) }]
  let corrections ← EventCorrectionMemory.ofCorrections? []
  let routing ← RoutingHistory.ofEntries?
    [{ subject := savingsAsset,
       effectiveOn := (RoutingEffective.initial : RoutingEffective Nat),
       purpose := some savings }]
  let scheduled ← ScheduledMemory.ofOccurrences? []
  let terminals ← ScheduledTerminalMemory.ofTerminals? []
  let roles ← AccountingRoleMap.ofAssignments?
    [{ locus := bank, role := .asset },
     { locus := savingsAsset, role := .asset }]
  let scheduledRouting ← RoutingHistory.ofEntries?
    ([] : List (RoutingEntry ScheduledRoutingSubject Nat))
  currentCoverageAtCorrectionFrontierEffectiveRouting?
    capacity effective events corrections validities routing
    scheduled terminals roles scheduledRouting
    savings yen (1 : Nat) observedAt (5 : Nat)

def main : IO Unit := do
  let oldBalance ← requireSome
    (event? "old-balance" (-10000) 10000)
    "old savings balance fixture was not admitted"
  let deposit ← requireSome
    (event? "current-deposit" (-5000) 5000)
    "current savings deposit fixture was not admitted"
  let withdrawal ← requireSome
    (event? "current-withdrawal" 2000 (-2000))
    "current savings withdrawal fixture was not admitted"

  let oldOnlyEvents ← requireSome
    (EventMemory.ofEvents? [oldBalance])
    "old-only Event memory was not admitted"
  let oldOnlyValidities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := oldBalance.id, validOn := (0 : Nat) }])
    "old-only validity memory was not admitted"

  let depositEvents ← requireSome
    (EventMemory.ofEvents? [oldBalance, deposit])
    "deposit Event memory was not admitted"
  let depositValidities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := oldBalance.id, validOn := (0 : Nat) },
       { event := deposit.id, validOn := (2 : Nat) }])
    "deposit validity memory was not admitted"

  let withdrawalEvents ← requireSome
    (EventMemory.ofEvents? [oldBalance, deposit, withdrawal])
    "withdrawal Event memory was not admitted"
  let withdrawalValidities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := oldBalance.id, validOn := (0 : Nat) },
       { event := deposit.id, validOn := (2 : Nat) },
       { event := withdrawal.id, validOn := (3 : Nat) }])
    "withdrawal validity memory was not admitted"

  let oldOnly ← requireSome
    (project? oldOnlyEvents oldOnlyValidities 2)
    "old-balance CurrentCoverage failed closed"
  let deposited ← requireSome
    (project? depositEvents depositValidities 2)
    "deposit CurrentCoverage failed closed"
  let withdrawn ← requireSome
    (project? withdrawalEvents withdrawalValidities 3)
    "withdrawal CurrentCoverage failed closed"

  expect ((oldBalance.quantityAt savingsAsset yen).quanta == 10000)
    "old savings fixture lost its positive Asset position"
  expect (oldOnly.entitlement.quanta == 5000)
    "old-balance world changed Capacity Entitlement"
  expect (oldOnly.consumption.quanta == 0 && oldOnly.remaining.quanta == 5000)
    "pre-window savings balance incorrectly satisfied current-cycle savings"

  expect (deposited.entitlement.quanta == 5000)
    "deposit world changed Capacity Entitlement"
  expect (deposited.consumption.quanta == 5000)
    "routed savings deposit did not fulfill ordinary Purpose Capacity"
  expect (deposited.remaining.quanta == 0 && deposited.headroom.quanta == 0)
    "routed savings deposit did not exhaust the selected contribution allocation"

  expect (withdrawn.consumption.quanta == 3000)
    "signed savings withdrawal did not reduce net Purpose realization"
  expect (withdrawn.remaining.quanta == 2000 && withdrawn.headroom.quanta == 2000)
    "signed savings withdrawal did not restore remaining contribution Capacity"

  IO.println "Observation 250 witness: an ordinary Purpose already models current-window net savings contribution; stock position remains a distinct question."
