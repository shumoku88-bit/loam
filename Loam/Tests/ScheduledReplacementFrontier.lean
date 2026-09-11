import Loam.Application.ScheduledInspection
import Loam.Persistence.ScheduledReplacementPersistence

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
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id : String) (day : String) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-100), change groceries 100]
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def openIds
    (result : CurrentOpenScheduledResult String) : Option (List String) :=
  match result with
  | .open occurrences => some (occurrences.map fun occurrence => occurrence.id.token)
  | _ => none

def main : IO Unit := do
  let a ← requireSome (scheduled? "scheduled-a" "2026-09-10")
    "Scheduled A fixture was not admitted"
  let b ← requireSome (scheduled? "scheduled-b" "2026-09-20")
    "Scheduled B fixture was not admitted"
  let c ← requireSome (scheduled? "scheduled-c" "2026-09-30")
    "Scheduled C fixture was not admitted"
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [a, b, c])
    "Scheduled memory fixture was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"

  let chain ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-a"⟩, target := some (.scheduled ⟨"scheduled-b"⟩) },
       { source := ⟨"scheduled-b"⟩, target := some (.scheduled ⟨"scheduled-c"⟩) }])
    "replacement chain fixture was not admitted"

  let chainIds ← requireSome
    (openIds <| currentOpenScheduled scheduled chain events)
    "valid replacement chain failed closed"
  expect (chainIds == ["scheduled-c"])
    s!"expected only terminal replacement scheduled-c open, got {chainIds}"

  let permuted ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-b"⟩, target := some (.scheduled ⟨"scheduled-c"⟩) },
       { source := ⟨"scheduled-a"⟩, target := some (.scheduled ⟨"scheduled-b"⟩) }])
    "permuted replacement chain fixture was not admitted"
  let permutedIds ← requireSome
    (openIds <| currentOpenScheduled scheduled permuted events)
    "permuted replacement chain failed closed"
  expect (permutedIds == chainIds)
    "replacement row order changed current-open meaning"

  -- The physical v1 replacement codec remains a Persistence-only adapter even
  -- though runtime lifecycle semantics now use one terminal relation.
  let wireChain ← requireSome
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-a"⟩, replacement := ⟨"scheduled-b"⟩ },
       { source := ⟨"scheduled-b"⟩, replacement := ⟨"scheduled-c"⟩ }])
    "replacement wire fixture was not admitted"
  let encoded ← requireSome
    (encodeScheduledReplacementMemory? wireChain)
    "replacement chain could not be encoded"
  let decoded ← requireSome
    (decodeScheduledReplacementMemory? encoded)
    "encoded replacement chain did not decode"
  let reencoded ← requireSome
    (encodeScheduledReplacementMemory? decoded)
    "decoded replacement chain could not be re-encoded"
  expect (reencoded == encoded)
    "replacement decode/encode changed canonical bytes"

  let missing ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-a"⟩,
         target := some (.scheduled ⟨"scheduled-missing"⟩) }])
    "missing-endpoint raw terminal fixture was not admitted"
  match currentOpenScheduled scheduled missing events with
  | .unknownReplacementScheduled => pure ()
  | _ => throw <| IO.userError "missing replacement endpoint did not fail closed"

  let cycle ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-a"⟩, target := some (.scheduled ⟨"scheduled-b"⟩) },
       { source := ⟨"scheduled-b"⟩, target := some (.scheduled ⟨"scheduled-a"⟩) }])
    "cyclic raw terminal fixture was not admitted"
  match currentOpenScheduled scheduled cycle events with
  | .invalidReplacementGraph => pure ()
  | _ => throw <| IO.userError "replacement cycle did not fail closed"

  let completionConflict ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-a"⟩, target := some (.actual ⟨"actual-a"⟩) },
       { source := ⟨"scheduled-a"⟩, target := some (.scheduled ⟨"scheduled-b"⟩) }])
    "completion/replacement conflict fixture was not admitted"
  match currentOpenScheduled scheduled completionConflict events with
  | .conflictingTerminalEvidence => pure ()
  | _ => throw <| IO.userError "completion/replacement conflict was not refused"

  let retirementConflict ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-a"⟩, target := none },
       { source := ⟨"scheduled-a"⟩, target := some (.scheduled ⟨"scheduled-b"⟩) }])
    "retirement/replacement conflict fixture was not admitted"
  match currentOpenScheduled scheduled retirementConflict events with
  | .conflictingTerminalEvidence => pure ()
  | _ => throw <| IO.userError "retirement/replacement conflict was not refused"

  let duplicateSource :=
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\n" ++
    "REPLACEMENT\tscheduled-a\tscheduled-b\n" ++
    "REPLACEMENT\tscheduled-a\tscheduled-c\n"
  expect ((decodeScheduledReplacementMemory? duplicateSource).isNone)
    "duplicate replacement source was admitted"

  let duplicateReplacement :=
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\n" ++
    "REPLACEMENT\tscheduled-a\tscheduled-c\n" ++
    "REPLACEMENT\tscheduled-b\tscheduled-c\n"
  expect ((decodeScheduledReplacementMemory? duplicateReplacement).isNone)
    "shared replacement endpoint was admitted"

  IO.println "Scheduled replacement frontier practical story succeeded."
