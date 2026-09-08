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
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩
private def fixedExpense : LocusId := ⟨"fixed-expense"⟩
private def mystery : LocusId := ⟨"mystery"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def capacityMovement? (id : String) (quanta : Int) : Option CapacityMovement := do
  let movement ← BalancedMovement.ofChanges? yen
    [capacityChange .unallocated (-quanta),
     capacityChange (.purpose food) quanta]
  pure { id := ⟨id⟩, movement := movement }

private def scheduled?
    (id : String) (day : Nat) (destination : LocusId) (quanta : Int) :
    Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-quanta), change destination quanta]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def subject (scheduled : String) (locus : LocusId) : ScheduledRoutingSubject :=
  { scheduled := ⟨scheduled⟩, locus := locus }

private def assertCoverage
    (label : String)
    (view : CurrentCoverageView)
    (entitlement consumption remaining commitment headroom unresolved : Int) : IO Unit := do
  expect (view.entitlement.quanta == entitlement)
    s!"{label}: expected Entitlement {entitlement}, got {view.entitlement.quanta}"
  expect (view.consumption.quanta == consumption)
    s!"{label}: expected Consumption {consumption}, got {view.consumption.quanta}"
  expect (view.remaining.quanta == remaining)
    s!"{label}: expected Remaining {remaining}, got {view.remaining.quanta}"
  expect (view.commitment.quanta == commitment)
    s!"{label}: expected Commitment {commitment}, got {view.commitment.quanta}"
  expect (view.headroom.quanta == headroom)
    s!"{label}: expected Headroom {headroom}, got {view.headroom.quanta}"
  expect (view.unresolvedEligibility.quanta == unresolved)
    s!"{label}: expected unresolved eligibility {unresolved}, got {view.unresolvedEligibility.quanta}"
  expect (view.unmanagedCommitment.quanta == 0)
    s!"{label}: fixture unexpectedly retained unmanaged Commitment"
  expect (view.unroutedCommitment.quanta == 0)
    s!"{label}: fixture unexpectedly retained role-qualified unrouted Commitment"


def main : IO Unit := do
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := paypay, role := .asset },
       { locus := groceries, role := .expense },
       { locus := fixedExpense, role := .expense }])
    "AccountingRole fixture was not admitted"

  let actual ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [Effect.ofQuantity ⟨"pay"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"use"⟩ groceries yen (Quantity.ofQuanta 30)])
    "Actual fixture was not admitted"
  let oldActual ← requireSome
    (Event.ofEffects? ⟨"actual-old"⟩
      [Effect.ofQuantity ⟨"old-pay"⟩ paypay yen (Quantity.ofQuanta (-70)),
       Effect.ofQuantity ⟨"old-use"⟩ groceries yen (Quantity.ofQuanta 70)])
    "old Actual fixture was not admitted"
  let futureActual ← requireSome
    (Event.ofEffects? ⟨"actual-future"⟩
      [Effect.ofQuantity ⟨"future-pay"⟩ paypay yen (Quantity.ofQuanta (-80)),
       Effect.ofQuantity ⟨"future-use"⟩ groceries yen (Quantity.ofQuanta 80)])
    "future Actual fixture was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [oldActual, actual, futureActual])
    "Event memory was not admitted"
  let corrections ← requireSome (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"actual-old"⟩, validOn := (0 : Nat) },
       { event := ⟨"actual-1"⟩, validOn := (2 : Nat) },
       { event := ⟨"actual-future"⟩, validOn := (3 : Nat) }])
    "Actual validity fixture was not admitted"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := groceries, effectiveOn := (0 : Nat), purpose := some food }])
    "Actual routing fixture was not admitted"

  let managed ← requireSome (scheduled? "scheduled-managed" 3 fixedExpense 35)
    "managed Scheduled fixture was not admitted"
  let historicalOpen ← requireSome (scheduled? "scheduled-historical-open" 1 fixedExpense 65)
    "historical open Scheduled fixture was not admitted"
  let unresolved ← requireSome (scheduled? "scheduled-unresolved" 3 mystery 9)
    "unresolved Scheduled fixture was not admitted"
  let managedMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [historicalOpen, managed])
    "managed Scheduled memory was not admitted"
  let mixedMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [historicalOpen, managed, unresolved])
    "mixed Scheduled memory was not admitted"
  let completions ← requireSome (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let retirements ← requireSome (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let replacements ← requireSome (ScheduledReplacementMemory.ofReplacements? [])
    "empty replacement memory was not admitted"
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-historical-open" fixedExpense,
         effectiveOn := (0 : Nat), purpose := some food },
       { subject := subject "scheduled-managed" fixedExpense,
         effectiveOn := (2 : Nat), purpose := some food }])
    "Scheduled routing fixture was not admitted"

  let capacity100 ← requireSome (capacityMovement? "capacity-100" 100)
    "100-unit Capacity fixture was not admitted"
  let capacity20 ← requireSome (capacityMovement? "capacity-20" 20)
    "20-unit Capacity fixture was not admitted"
  let capacity60 ← requireSome (capacityMovement? "capacity-60" 60)
    "60-unit Capacity fixture was not admitted"

  -- Covered now and after known managed Scheduled pressure.
  let covered ← requireSome
    (currentCoverageAtCorrectionFrontierWithReplacement?
      [capacity100] events corrections validities actualRouting
      managedMemory completions retirements replacements roles scheduledRouting
      food yen (1 : Nat) (2 : Nat) (4 : Nat))
    "covered current projection failed closed"
  assertCoverage "covered" covered 100 30 70 35 35 0

  -- Already-consumed pressure is visible before any presentation label exists.
  let overNow ← requireSome
    (currentCoverageAtCorrectionFrontierWithReplacement?
      [capacity20] events corrections validities actualRouting
      managedMemory completions retirements replacements roles scheduledRouting
      food yen (1 : Nat) (2 : Nat) (4 : Nat))
    "over-now current projection failed closed"
  assertCoverage "over-now" overNow 20 30 (-10) 35 (-45) 0

  -- Remaining can still be positive while known future Commitment makes Headroom negative.
  let futureShort ← requireSome
    (currentCoverageAtCorrectionFrontierWithReplacement?
      [capacity60] events corrections validities actualRouting
      managedMemory completions retirements replacements roles scheduledRouting
      food yen (1 : Nat) (2 : Nat) (4 : Nat))
    "future-short current projection failed closed"
  assertCoverage "future-short" futureShort 60 30 30 35 (-5) 0

  -- Missing AccountingRole on an unrouted positive Scheduled coordinate remains
  -- visible instead of being silently counted or discarded.
  let unresolvedView ← requireSome
    (currentCoverageAtCorrectionFrontierWithReplacement?
      [capacity100] events corrections validities actualRouting
      mixedMemory completions retirements replacements roles scheduledRouting
      food yen (1 : Nat) (2 : Nat) (4 : Nat))
    "unresolved current projection failed closed"
  assertCoverage "unresolved" unresolvedView 100 30 70 35 35 9

  IO.println "Current Capacity coverage inspection succeeded."
