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
    (result : CurrentOpenScheduledWithReplacementResult String) : Option (List String) :=
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
  let completions ← requireSome
    (ScheduledCompletionMemory.ofCompletions? [])
    "empty completion memory was not admitted"
  let retirements ← requireSome
    (ScheduledRetirementMemory.ofRetirements? [])
    "empty retirement memory was not admitted"
  let events ← requireSome
    (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"

  let chain ← requireSome
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-a"⟩, replacement := ⟨"scheduled-b"⟩ },
       { source := ⟨"scheduled-b"⟩, replacement := ⟨"scheduled-c"⟩ }])
    "replacement chain fixture was not admitted"

  let chainIds ← requireSome
    (openIds <| currentOpenScheduledWithReplacement
      scheduled completions retirements chain events)
    "valid replacement chain failed closed"
  expect (chainIds == ["scheduled-c"])
    s!"expected only terminal replacement scheduled-c open, got {chainIds}"

  let permuted ← requireSome
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-b"⟩, replacement := ⟨"scheduled-c"⟩ },
       { source := ⟨"scheduled-a"⟩, replacement := ⟨"scheduled-b"⟩ }])
    "permuted replacement chain fixture was not admitted"
  let permutedIds ← requireSome
    (openIds <| currentOpenScheduledWithReplacement
      scheduled completions retirements permuted events)
    "permuted replacement chain failed closed"
  expect (permutedIds == chainIds)
    "replacement row order changed current-open meaning"

  let encoded ← requireSome
    (encodeScheduledReplacementMemory? chain)
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
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-a"⟩, replacement := ⟨"scheduled-missing"⟩ }])
    "missing-endpoint raw replacement fixture was not admitted"
  match currentOpenScheduledWithReplacement
      scheduled completions retirements missing events with
  | .unknownReplacementScheduled => pure ()
  | _ => throw <| IO.userError "missing replacement endpoint did not fail closed"

  let cycle ← requireSome
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-a"⟩, replacement := ⟨"scheduled-b"⟩ },
       { source := ⟨"scheduled-b"⟩, replacement := ⟨"scheduled-a"⟩ }])
    "cyclic raw replacement fixture was not admitted"
  match currentOpenScheduledWithReplacement
      scheduled completions retirements cycle events with
  | .invalidReplacementGraph => pure ()
  | _ => throw <| IO.userError "replacement cycle did not fail closed"

  let completionConflict ← requireSome
    (ScheduledCompletionMemory.ofCompletions?
      [{ scheduled := ⟨"scheduled-a"⟩, actual := ⟨"actual-a"⟩ }])
    "completion conflict fixture was not admitted"
  let oneReplacement ← requireSome
    (ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-a"⟩, replacement := ⟨"scheduled-b"⟩ }])
    "single replacement fixture was not admitted"
  match currentOpenScheduledWithReplacement
      scheduled completionConflict retirements oneReplacement events with
  | .conflictingTerminalEvidence => pure ()
  | _ => throw <| IO.userError "completion/replacement conflict was not refused"

  let retirementConflict ← requireSome
    (ScheduledRetirementMemory.ofRetirements?
      [{ scheduled := ⟨"scheduled-a"⟩ }])
    "retirement conflict fixture was not admitted"
  match currentOpenScheduledWithReplacement
      scheduled completions retirementConflict oneReplacement events with
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
