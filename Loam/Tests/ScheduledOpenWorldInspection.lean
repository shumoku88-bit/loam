import Loam.Application.ScheduledOpenWorldInspection

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
private def bank : LocusId := ⟨"bank"⟩
private def rent : LocusId := ⟨"rent"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id : String) (day : Nat) (amount : Int) : Option (ScheduledOccurrence Nat) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change bank (-amount), change rent amount]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def expectDueId
    (result : CurrentScheduledDayEvidenceResult Nat)
    (expectedId : String)
    (message : String) : IO Unit :=
  match result with
  | .due first rest => do
      expect (first.id.token == expectedId) message
      expect rest.isEmpty "expected exactly one explicit Scheduled occurrence"
  | _ => throw <| IO.userError message

private def expectUnknown
    (result : CurrentScheduledDayEvidenceResult Nat)
    (message : String) : IO Unit :=
  match result with
  | .unknown => pure ()
  | _ => throw <| IO.userError message

def main : IO Unit := do
  let old ← requireSome (scheduled? "rent-old" 2 50)
    "old Scheduled fixture was not admitted"
  let replacement ← requireSome (scheduled? "rent-new" 4 50)
    "replacement Scheduled fixture was not admitted"
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [old, replacement])
    "Scheduled memory was not admitted"
  let emptyTerminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"

  expectDueId
    (currentScheduledDayEvidence scheduled emptyTerminals events (2 : Nat))
    "rent-old"
    "explicit Scheduled evidence on the queried day did not produce Due"

  expectUnknown
    (currentScheduledDayEvidence scheduled emptyTerminals events (3 : Nat))
    "missing explicit Scheduled evidence was incorrectly treated as Due"

  let replacements ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"rent-old"⟩, target := some (.scheduled ⟨"rent-new"⟩) }])
    "replacement terminal relation was not admitted"

  expectUnknown
    (currentScheduledDayEvidence scheduled replacements events (2 : Nat))
    "superseded Scheduled evidence leaked into the old day"

  expectDueId
    (currentScheduledDayEvidence scheduled replacements events (4 : Nat))
    "rent-new"
    "replacement Scheduled evidence did not appear on the replacement day"

  let unknownTarget ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"rent-old"⟩, target := some (.scheduled ⟨"missing"⟩) }])
    "unknown-target terminal memory was not retained for frontier testing"

  match currentScheduledDayEvidence scheduled unknownTarget events (2 : Nat) with
  | .unknownReplacementScheduled => pure ()
  | _ =>
      throw <| IO.userError
        "open-world query collapsed an invalid replacement endpoint into ordinary Unknown"

  IO.println "Scheduled open-world day evidence story succeeded."
