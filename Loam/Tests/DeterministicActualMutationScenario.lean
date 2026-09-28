import Loam.ActualAuthority
import Loam.HouseholdCommand
import Loam.LocusAdmissionAuthority
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.Tests.DeterministicActualMutationScenario

open Loam
open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private structure Stats where
  corrections : Nat := 0
  reversals : Nat := 0
  refusals : Nat := 0
deriving Repr, DecidableEq

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw <| IO.userError s!"{message}: {detail}"

private def cleanupDir (dir : System.FilePath) : IO Unit := do
  if ← dir.pathExists then
    IO.FS.removeDirAll dir

private def emptyLifecycle : IO ScheduledLifecycleImage := do
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [])
    "empty Scheduled memory was not admitted"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "empty Scheduled terminal memory was not admitted"
  pure { scheduled, terminals }

private def movementEffects
    (destination : LocusId)
    (amount : Int) : List Effect :=
  [
    Effect.ofAnonymousQuantity
      ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
    Effect.ofAnonymousQuantity
      destination ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def movementDraft
    (date description : String)
    (destination : LocusId)
    (amount : Int) : Loam.MovementAdmission.Draft := {
  validOn := date
  description := some description
  effects := movementEffects destination amount
  relations := []
  discharges := []
  total := amount
}

private def correctionDraft
    (target : EventId)
    (description : String)
    (destination : LocusId)
    (amount : Int) : Loam.CorrectionPublisher.Draft := {
  target := target
  effects := movementEffects destination amount
  description := some description
}

private def authorityBytes (root : System.FilePath) : IO String :=
  IO.FS.readFile (Loam.ActualAuthority.actualPath root)

private def loadEvidence (root : System.FilePath) (context : String) : IO ActualEvidence := do
  requireOk (← Loam.ActualAuthority.loadActual? root)
    s!"{context}: typed Actual reload failed"

private def replacementFor
    (evidence : ActualEvidence)
    (target : EventId)
    (context : String) : IO EventId :=
  match evidence.corrections.corrections.find? (fun c => c.target == target) with
  | some correction => pure correction.replacement
  | none => throw <| IO.userError s!"{context}: correction replacement missing"

private def reversalFor
    (evidence : ActualEvidence)
    (target : EventId)
    (context : String) : IO EventId :=
  match evidence.reversals.findByTarget? target with
  | some relation => pure relation.reversal
  | none => throw <| IO.userError s!"{context}: reversal relation missing"

private def checkCanonical
    (root : System.FilePath)
    (context : String) : IO String := do
  let evidence ← loadEvidence root context
  let encoded ← requireSome
    (encodeNormalizedActual? evidence)
    s!"{context}: admitted Actual failed canonical encoding"
  let decoded ← requireSome
    (decodeNormalizedActual? encoded)
    s!"{context}: canonical Actual failed typed decoding"
  let reencoded ← requireSome
    (encodeNormalizedActual? decoded)
    s!"{context}: decoded Actual failed canonical re-encoding"
  expect (encoded == reencoded)
    s!"{context}: normalized Actual encoding was not canonical"
  let disk ← authorityBytes root
  expect (disk == encoded)
    s!"{context}: authority bytes diverged from canonical admitted encoding"
  pure disk

private def expectRefusal
    (root : System.FilePath)
    (context : String)
    (action : IO (Except String Unit)) : IO Unit := do
  let before ← authorityBytes root
  match ← action with
  | .ok () =>
      throw <| IO.userError s!"{context}: operation unexpectedly succeeded"
  | .error _ => pure ()
  let after ← authorityBytes root
  expect (after == before)
    s!"{context}: refused operation changed Actual authority bytes"
  let _ ← checkCanonical root context
  pure ()

private def expectCorrection
    (root : System.FilePath)
    (draft : Loam.CorrectionPublisher.Draft)
    (context : String) : IO EventId := do
  let before ← loadEvidence root s!"{context} before"
  let oldEvents := before.events.events.length
  let oldCorrections := before.corrections.corrections.length
  let _ ← requireOk
    (← Loam.HouseholdCommand.correctActual root draft)
    s!"{context}: correction failed"
  let after ← loadEvidence root s!"{context} after"
  expect (after.events.events.length == oldEvents + 1)
    s!"{context}: successful correction did not append exactly one Event"
  expect (after.corrections.corrections.length == oldCorrections + 1)
    s!"{context}: successful correction did not append exactly one correction edge"
  let replacement ← replacementFor after draft.target context
  let _ ← requireSome
    (after.events.findById? draft.target)
    s!"{context}: correction removed its target Event"
  let _ ← requireSome
    (after.events.findById? replacement)
    s!"{context}: correction replacement Event missing"
  let _ ← checkCanonical root context
  pure replacement

private def expectReversal
    (root : System.FilePath)
    (target : EventId)
    (validOn context : String) : IO EventId := do
  let before ← loadEvidence root s!"{context} before"
  let oldEvents := before.events.events.length
  let oldReversals := before.reversals.reversals.length
  let _ ← requireOk
    (← Loam.HouseholdCommand.reverseActual root { target := target, validOn := validOn })
    s!"{context}: reversal failed"
  let after ← loadEvidence root s!"{context} after"
  expect (after.events.events.length == oldEvents + 1)
    s!"{context}: successful reversal did not append exactly one Event"
  expect (after.reversals.reversals.length == oldReversals + 1)
    s!"{context}: successful reversal did not append exactly one provenance edge"
  let reversal ← reversalFor after target context
  let targetEvent ← requireSome
    (after.events.findById? target)
    s!"{context}: reversal target Event disappeared"
  let reversalEvent ← requireSome
    (after.events.findById? reversal)
    s!"{context}: reversal Event missing"
  expect (ActualReversal.exactPhysicalInverse? targetEvent.effects reversalEvent.effects)
    s!"{context}: reversal Event is not the exact physical inverse"
  let _ ← checkCanonical root context
  pure reversal

private def prepareRoot (root : System.FilePath) : IO (List EventId) := do
  cleanupDir root
  IO.FS.createDirAll root

  let _ ← requireOk
    (← Loam.ActualAuthority.publishActual? root ActualEvidence.empty)
    "initialize empty Actual authority"

  let loci ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [
      ⟨"wallet"⟩,
      ⟨"food"⟩,
      ⟨"books"⟩,
      ⟨"transport"⟩
    ])
    "deterministic mutation Locus vocabulary was not unique"
  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.publishCurrent? root loci)
    "publish deterministic mutation Locus policy"

  let lifecycle ← emptyLifecycle
  expect
    (← Loam.Persistence.saveScheduledLifecycleImage?
      (Loam.HouseholdPaths.scheduled root) lifecycle)
    "publish explicit empty Scheduled lifecycle"

  let fixtures : List (MovementOperationId × Loam.MovementAdmission.Draft) := [
    (⟨"mutation-base-a"⟩, movementDraft "2026-09-01" "base A" ⟨"food"⟩ 500),
    (⟨"mutation-base-b"⟩, movementDraft "2026-09-02" "base B" ⟨"books"⟩ 600),
    (⟨"mutation-base-c"⟩, movementDraft "2026-09-03" "base C" ⟨"transport"⟩ 700),
    (⟨"mutation-base-d"⟩, movementDraft "2026-09-04" "base D" ⟨"food"⟩ 800)
  ]

  let mut ids : List EventId := []
  for fixture in fixtures do
    let operation := fixture.1
    let draft := fixture.2
    match ← Loam.HouseholdCommand.recordIdempotent root operation draft with
    | .ok (.applied event) =>
        ids := ids ++ [event]
    | .ok (.alreadyApplied event) =>
        throw <| IO.userError
          s!"fresh base operation '{operation.token}' unexpectedly reused '{event.token}'"
    | .error detail =>
        throw <| IO.userError
          s!"fresh base operation '{operation.token}' failed: {detail}"

  expect (ids.length == 4)
    "deterministic mutation fixture did not create four base Events"
  let _ ← checkCanonical root "base fixture"
  pure ids

private def runScenario (root : System.FilePath) : IO (Stats × String) := do
  let ids ← prepareRoot root
  let [a, b, c, d] := ids
    | throw <| IO.userError "deterministic mutation fixture shape changed"

  let mut stats : Stats := {}

  let a1 ← expectCorrection root
    (correctionDraft a "A correction 1" ⟨"books"⟩ 550)
    "step 1 correction A"
  stats := { stats with corrections := stats.corrections + 1 }

  let bRev ← expectReversal root b "2026-09-10" "step 2 reversal B"
  stats := { stats with reversals := stats.reversals + 1 }

  expectRefusal root "step 3 reverse corrected original A"
    (Loam.HouseholdCommand.reverseActual root {
      target := a
      validOn := "2026-09-10"
    })
  stats := { stats with refusals := stats.refusals + 1 }

  expectRefusal root "step 4 correct reversal target B"
    (Loam.HouseholdCommand.correctActual root
      (correctionDraft b "illegal B correction" ⟨"food"⟩ 610))
  stats := { stats with refusals := stats.refusals + 1 }

  expectRefusal root "step 5 correct reversal endpoint B"
    (Loam.HouseholdCommand.correctActual root
      (correctionDraft bRev "illegal B inverse correction" ⟨"food"⟩ 610))
  stats := { stats with refusals := stats.refusals + 1 }

  let a2 ← expectCorrection root
    (correctionDraft a1 "A correction 2" ⟨"transport"⟩ 575)
    "step 6 correction replacement A1"
  stats := { stats with corrections := stats.corrections + 1 }

  expectRefusal root "step 7 reverse stale replacement A1"
    (Loam.HouseholdCommand.reverseActual root {
      target := a1
      validOn := "2026-09-11"
    })
  stats := { stats with refusals := stats.refusals + 1 }

  let _a2Rev ← expectReversal root a2 "2026-09-11" "step 8 reversal current A2"
  stats := { stats with reversals := stats.reversals + 1 }

  expectRefusal root "step 9 correct reversed current A2"
    (Loam.HouseholdCommand.correctActual root
      (correctionDraft a2 "illegal A2 correction" ⟨"food"⟩ 590))
  stats := { stats with refusals := stats.refusals + 1 }

  let _cRev ← expectReversal root c "2026-09-12" "step 10 reversal C"
  stats := { stats with reversals := stats.reversals + 1 }

  expectRefusal root "step 11 duplicate reversal C"
    (Loam.HouseholdCommand.reverseActual root {
      target := c
      validOn := "2026-09-12"
    })
  stats := { stats with refusals := stats.refusals + 1 }

  expectRefusal root "step 12 reversal of reversal B"
    (Loam.HouseholdCommand.reverseActual root {
      target := bRev
      validOn := "2026-09-12"
    })
  stats := { stats with refusals := stats.refusals + 1 }

  let invalidD : Loam.CorrectionPublisher.Draft := {
    target := d
    effects := [
      Effect.ofAnonymousQuantity
        ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-825))
    ]
    description := some "unbalanced D"
  }
  expectRefusal root "step 13 unbalanced correction D"
    (Loam.HouseholdCommand.correctActual root invalidD)
  stats := { stats with refusals := stats.refusals + 1 }

  let d1 ← expectCorrection root
    (correctionDraft d "D correction" ⟨"books"⟩ 825)
    "step 14 correction D"
  stats := { stats with corrections := stats.corrections + 1 }

  let _d1Rev ← expectReversal root d1 "2026-09-13" "step 15 reversal replacement D1"
  stats := { stats with reversals := stats.reversals + 1 }

  expectRefusal root "step 16 correct reversed replacement D1"
    (Loam.HouseholdCommand.correctActual root
      (correctionDraft d1 "illegal D1 correction" ⟨"transport"⟩ 830))
  stats := { stats with refusals := stats.refusals + 1 }

  let final ← loadEvidence root "final"
  expect (final.events.events.length == 11)
    "final Event count did not match four bases + three corrections + four reversals"
  expect (final.validity.facts.length == 11)
    "final validity count did not match retained Event count"
  expect (final.descriptions.entries.length == 7)
    "final description count did not match bases plus successful corrections"
  expect (final.movementOperations.entries.length == 4)
    "mutation writers changed Movement operation evidence"
  expect (final.corrections.corrections.length == 3)
    "final correction edge count changed"
  expect (final.reversals.reversals.length == 4)
    "final reversal edge count changed"
  expect final.relations.isEmpty
    "deterministic mutation scenario unexpectedly retained Relation evidence"
  expect final.discharges.isEmpty
    "deterministic mutation scenario unexpectedly retained Discharge evidence"
  expect final.settlements.commitments.isEmpty
    "deterministic mutation scenario unexpectedly retained Settlement commitments"

  let bytes ← checkCanonical root "final"
  pure (stats, bytes)

def runTests : IO Unit := do
  let rootA := System.FilePath.mk "scratch/test-deterministic-actual-mutation-a"
  let rootB := System.FilePath.mk "scratch/test-deterministic-actual-mutation-b"

  let (statsA, bytesA) ← runScenario rootA
  let (statsB, bytesB) ← runScenario rootB

  expect (statsA == statsB)
    "deterministic Actual mutation replay changed scenario counters"
  expect (bytesA == bytesB)
    "deterministic Actual mutation replay produced different canonical bytes"

  expect (statsA.corrections == 3)
    "deterministic mutation scenario did not exercise three successful Corrections"
  expect (statsA.reversals == 4)
    "deterministic mutation scenario did not exercise four successful Reversals"
  expect (statsA.refusals == 9)
    "deterministic mutation scenario did not exercise nine cross-writer refusals"

  cleanupDir rootA
  cleanupDir rootB

  IO.println
    s!"Deterministic Actual mutation scenario passed: corrections={statsA.corrections}, reversals={statsA.reversals}, refusals={statsA.refusals}."

end Loam.Tests.DeterministicActualMutationScenario

def main : IO Unit :=
  Loam.Tests.DeterministicActualMutationScenario.runTests
