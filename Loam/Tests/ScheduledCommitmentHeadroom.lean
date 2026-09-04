import Loam.Application.ScheduledCommitmentInspection
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
private def household : PurposeId := ⟨"household"⟩

private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩
private def coffee : LocusId := ⟨"coffee"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id : String) (day : Nat) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def subject (scheduled : String) (locus : LocusId) : ScheduledRoutingSubject :=
  { scheduled := ⟨scheduled⟩, locus := locus }

def main : IO Unit := do
  let capacityMovement ← requireSome
    (do
      let movement ← BalancedMovement.ofChanges? yen
        [capacityChange .unallocated (-100),
         capacityChange (.purpose food) 100]
      pure ({ id := ⟨"capacity-1"⟩, movement := movement } : CapacityMovement))
    "capacity fixture was not admitted"

  let actual ← requireSome
    (Event.ofEffects? ⟨"actual-1"⟩
      [Effect.ofQuantity ⟨"pay"⟩ paypay yen (Quantity.ofQuanta (-30)),
       Effect.ofQuantity ⟨"use"⟩ groceries yen (Quantity.ofQuanta 30)])
    "actual fixture was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [actual])
    "event memory was not admitted"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries?
      [{ event := ⟨"actual-1"⟩, validOn := (1 : Nat) }])
    "actual validity fixture was not admitted"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := groceries, effectiveOn := (1 : Nat), purpose := some food }])
    "actual routing fixture was not admitted"

  let s1 ← requireSome
    (scheduled? "scheduled-1" 2
      [change paypay (-30), change groceries 20, change coffee 10])
    "split Scheduled fixture was not admitted"
  let s2 ← requireSome
    (scheduled? "scheduled-2" 3
      [change paypay (-15), change groceries 15])
    "same-Locus Scheduled fixture was not admitted"
  let s3 ← requireSome
    (scheduled? "scheduled-3" 4
      [change paypay (-40), change groceries 40])
    "end-exclusive Scheduled fixture was not admitted"
  let s4 ← requireSome
    (scheduled? "scheduled-4" 0
      [change paypay (-5), change groceries 5])
    "overdue Scheduled fixture was not admitted"
  let s5 ← requireSome
    (scheduled? "scheduled-5" 2
      [change paypay (-6), change groceries 6])
    "retired Scheduled fixture was not admitted"
  let s6 ← requireSome
    (scheduled? "scheduled-6" 2
      [change paypay (-9), change groceries 9])
    "completed Scheduled fixture was not admitted"
  let s7 ← requireSome
    (scheduled? "scheduled-7" 2
      [change paypay (-7), change groceries 7])
    "interrupted-completion Scheduled fixture was not admitted"
  let s8 ← requireSome
    (scheduled? "scheduled-8" 2
      [change paypay (-8), change groceries 8])
    "unrouted Scheduled fixture was not admitted"

  let scheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [s1, s2, s3, s4, s5, s6, s7, s8])
    "Scheduled memory was not admitted"
  let completionMemory ← requireSome
    (ScheduledCompletionMemory.ofCompletions?
      [{ scheduled := ⟨"scheduled-6"⟩, actual := ⟨"actual-1"⟩ },
       { scheduled := ⟨"scheduled-7"⟩, actual := ⟨"actual-not-yet-published"⟩ }])
    "completion fixture was not admitted"
  let retirementMemory ← requireSome
    (ScheduledRetirementMemory.ofRetirements?
      [{ scheduled := ⟨"scheduled-5"⟩ }])
    "retirement fixture was not admitted"

  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-1" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-1" coffee,
         effectiveOn := (1 : Nat), purpose := some household },
       { subject := subject "scheduled-2" groceries,
         effectiveOn := (1 : Nat), purpose := some household },
       { subject := subject "scheduled-3" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-4" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-5" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-6" groceries,
         effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-7" groceries,
         effectiveOn := (1 : Nat), purpose := none }])
    "Scheduled routing fixture was not admitted"

  let commitment ← requireSome
    (currentScheduledCommitment?
      scheduledMemory completionMemory retirementMemory events scheduledRouting
      food yen (2 : Nat) (4 : Nat))
    "current Scheduled commitment failed closed"

  expect (commitment.managed.quanta == 25)
    s!"expected food commitment 25, got {commitment.managed.quanta}"
  expect (commitment.unmanaged.quanta == 7)
    s!"expected unmanaged commitment 7, got {commitment.unmanaged.quanta}"
  expect (commitment.unrouted.quanta == 8)
    s!"expected unrouted commitment 8, got {commitment.unrouted.quanta}"

  let headroom ← requireSome
    (headroomAtCorrectionFrontier?
      [capacityMovement]
      events corrections validities actualRouting
      scheduledMemory completionMemory retirementMemory scheduledRouting
      food yen (2 : Nat) (4 : Nat))
    "headroom projection failed closed"

  expect (headroom.remaining.quanta == 70)
    s!"expected Remaining 70, got {headroom.remaining.quanta}"
  expect (headroom.commitment.quanta == 25)
    s!"expected Commitment 25, got {headroom.commitment.quanta}"
  expect (headroom.headroom.quanta == 45)
    s!"expected Headroom 45, got {headroom.headroom.quanta}"
  expect (headroom.unmanagedCommitment.quanta == 7)
    "Headroom view lost unmanaged Scheduled pressure"
  expect (headroom.unroutedCommitment.quanta == 8)
    "Headroom view lost unrouted Scheduled pressure"

  -- An unknown Scheduled endpoint makes the whole current-open answer invalid.
  let unknownCompletion ← requireSome
    (ScheduledCompletionMemory.ofCompletions?
      [{ scheduled := ⟨"unknown-scheduled"⟩, actual := ⟨"actual-1"⟩ }])
    "unknown-reference completion fixture shape was not admitted"
  expect
    ((currentScheduledCommitment?
      scheduledMemory unknownCompletion retirementMemory events scheduledRouting
      food yen (2 : Nat) (4 : Nat)).isNone)
    "unknown Scheduled completion reference did not fail closed"

  -- Conflicting completion and retirement evidence also refuses the whole view.
  let conflictRetirement ← requireSome
    (ScheduledRetirementMemory.ofRetirements?
      [{ scheduled := ⟨"scheduled-6"⟩ }])
    "conflicting retirement fixture shape was not admitted"
  expect
    ((currentScheduledCommitment?
      scheduledMemory completionMemory conflictRetirement events scheduledRouting
      food yen (2 : Nat) (4 : Nat)).isNone)
    "conflicting Scheduled terminal evidence did not fail closed"

  IO.println "Scheduled Commitment / Headroom practical story succeeded."
