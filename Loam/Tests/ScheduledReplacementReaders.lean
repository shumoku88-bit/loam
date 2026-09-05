import Loam.Application.ScheduledBalanceInspection
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
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def coordinate (locus : LocusId) : EffectCoordinate := ⟨locus, yen⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def capacityChange
    (coordinate : CapacityCoordinate) (quanta : Int) : MovementChange CapacityCoordinate :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id : String) (day : Nat) (amount : Int) : Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-amount), change groceries amount]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def subject (scheduled : String) : ScheduledRoutingSubject :=
  { scheduled := ⟨scheduled⟩, locus := groceries }

def main : IO Unit := do
  let old ← requireSome (scheduled? "scheduled-old" 2 20)
    "old Scheduled fixture was not admitted"
  let replacement ← requireSome (scheduled? "scheduled-new" 3 12)
    "replacement Scheduled fixture was not admitted"
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [old, replacement])
    "Scheduled memory was not admitted"
  let completions ← requireSome
    (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let retirements ← requireSome
    (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let replacements ← requireSome
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-old"⟩, replacement := ⟨"scheduled-new"⟩ }])
    "replacement relation was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-old", effectiveOn := (1 : Nat), purpose := some food },
       { subject := subject "scheduled-new", effectiveOn := (1 : Nat), purpose := some food }])
    "Scheduled routing fixture was not admitted"

  let commitment ← requireSome
    (currentScheduledCommitmentWithReplacement?
      scheduled completions retirements replacements events routing
      food yen (3 : Nat) (4 : Nat))
    "replacement-aware Commitment failed closed"
  expect (commitment.managed.quanta == 12)
    s!"superseded Scheduled quantity leaked into Commitment: {commitment.managed.quanta}"

  let balance ← requireSome
    (currentScheduledBalanceEffectsBeforeWithReplacement?
      scheduled completions retirements replacements events
      [coordinate paypay, coordinate groceries] (4 : Nat))
    "replacement-aware Scheduled balance failed closed"
  match balance with
  | [paypayEffect, groceriesEffect] =>
      expect (paypayEffect.quantity.quanta == -12)
        s!"superseded source leaked into paypay balance effect: {paypayEffect.quantity.quanta}"
      expect (groceriesEffect.quantity.quanta == 12)
        s!"superseded source leaked into groceries balance effect: {groceriesEffect.quantity.quanta}"
  | _ => throw <| IO.userError "replacement-aware balance returned an unexpected shape"

  let capacityMovement ← requireSome
    (do
      let movement ← BalancedMovement.ofChanges? yen
        [capacityChange .unallocated (-100), capacityChange (.purpose food) 100]
      pure ({ id := ⟨"capacity-1"⟩, movement := movement } : CapacityMovement))
    "capacity fixture was not admitted"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [])
    "empty correction memory was not admitted"
  let validities ← requireSome
    (ActualValidityMemory.ofEntries? ([] : List (ActualValidityEntry Nat)))
    "empty Actual validity memory was not admitted"
  let actualRouting ← requireSome
    (RoutingHistory.ofEntries? ([] : List (RoutingEntry LocusId Nat)))
    "empty Actual routing history was not admitted"

  let headroom ← requireSome
    (headroomAtCorrectionFrontierWithReplacement?
      [capacityMovement] events corrections validities actualRouting
      scheduled completions retirements replacements routing
      food yen (3 : Nat) (4 : Nat))
    "replacement-aware Headroom failed closed"
  expect (headroom.remaining.quanta == 100)
    s!"expected Remaining 100, got {headroom.remaining.quanta}"
  expect (headroom.commitment.quanta == 12)
    s!"expected replacement-aware Commitment 12, got {headroom.commitment.quanta}"
  expect (headroom.headroom.quanta == 88)
    s!"expected replacement-aware Headroom 88, got {headroom.headroom.quanta}"

  IO.println "Scheduled replacement reader cutover story succeeded."
