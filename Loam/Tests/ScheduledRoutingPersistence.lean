import Loam.Application.ScheduledCommitmentInspection
import Loam.Persistence.ScheduledRoutingPersistence

open Loam.Core
open Loam.Application
open Loam.Persistence

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

private def subject (scheduled : String) (locus : LocusId) : ScheduledRoutingSubject :=
  { scheduled := ⟨scheduled⟩, locus := locus }

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

def main : IO Unit := do
  let routing ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-1" groceries,
         effectiveOn := "2026-09-01", purpose := some food },
       { subject := subject "scheduled-1" groceries,
         effectiveOn := "2026-09-20", purpose := some household },
       { subject := subject "scheduled-2" groceries,
         effectiveOn := "2026-09-01", purpose := none }])
    "Scheduled routing fixture was not admitted"

  expect (routing.statusAt (subject "scheduled-1" groceries) "2026-09-19" == .managed food)
    "earlier Scheduled routing was not visible before the dated override"
  expect (routing.statusAt (subject "scheduled-1" groceries) "2026-09-20" == .managed household)
    "dated Scheduled routing override was not selected"
  expect (routing.statusAt (subject "scheduled-2" groceries) "2026-09-10" == .unmanaged)
    "explicitly unmanaged Scheduled route was lost"
  expect (routing.statusAt (subject "scheduled-3" groceries) "2026-09-10" == .unrouted)
    "absence of Scheduled routing evidence stopped being unrouted"

  let encoded ← requireSome
    (encodeScheduledRoutingHistory? routing)
    "Scheduled routing fixture could not be encoded"
  let decoded ← requireSome
    (decodeScheduledRoutingHistory? encoded)
    "encoded Scheduled routing fixture did not decode"
  let reencoded ← requireSome
    (encodeScheduledRoutingHistory? decoded)
    "decoded Scheduled routing fixture could not be re-encoded"
  expect (encoded == reencoded)
    "Scheduled routing decode/encode changed canonical bytes"

  expect
    ((RoutingHistory.ofEntries?
      [{ subject := subject "scheduled-1" groceries,
         effectiveOn := "2026-09-01", purpose := some food },
       { subject := subject "scheduled-1" groceries,
         effectiveOn := "2026-09-01", purpose := some household }]).isNone)
    "duplicate Scheduled routing coordinate was admitted"

  let badDate :=
    "LOAM-SCHEDULED-ROUTING\t1\n" ++
    "ROUTE\tscheduled-1\tgroceries\tFROM\t2026-02-29\tMANAGED\tfood\n"
  expect ((decodeScheduledRoutingHistory? badDate).isNone)
    "impossible Scheduled routing effective date was admitted"

  let movement ← requireSome
    (BalancedMovement.ofChanges? yen
      [change paypay (-500), change groceries 500])
    "Scheduled movement fixture was not admitted"
  let occurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-1"⟩
    scheduledOn := "2026-09-15"
    movement := movement
  }
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [occurrence])
    "Scheduled memory fixture was not admitted"
  let completions ← requireSome
    (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let retirements ← requireSome
    (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"

  let beforeOverride ← requireSome
    (currentScheduledCommitment?
      scheduled completions retirements events decoded food yen
      "2026-09-10" "2026-10-01")
    "Scheduled Commitment failed closed before routing override"
  expect (beforeOverride.managed.quanta == 500)
    s!"expected food Commitment 500 before override, got {beforeOverride.managed.quanta}"

  let afterOverride ← requireSome
    (currentScheduledCommitment?
      scheduled completions retirements events decoded household yen
      "2026-09-20" "2026-10-01")
    "Scheduled Commitment failed closed after routing override"
  expect (afterOverride.managed.quanta == 500)
    s!"expected household Commitment 500 after override, got {afterOverride.managed.quanta}"

  IO.println "Scheduled routing persistence practical story succeeded."
