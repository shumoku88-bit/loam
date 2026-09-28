import Loam.ActualAuthority
import Loam.LocusAdmissionAuthority
import Loam.MovementPublisher
import Loam.Tests.DeterministicScenarioSupport

namespace Loam.Tests.DeterministicMovementScenario

open Loam
open Loam.Core
open Loam.Persistence
open Loam.Tests.DeterministicScenarioSupport

set_option autoImplicit false

/-!
A small deterministic-simulation pilot over production Movement publication.

This is intentionally not a generic simulation framework. It runs the existing
production publisher, writer ownership, normalized Actual persistence, and
typed reload boundary against a reproducible generated operation trace.

The fixed seed is printed in every failure context so a failing run can be
replayed exactly.
-/

private structure ScenarioStep where
  seed : Nat
  operation : MovementOperationId
  draft : Loam.MovementAdmission.Draft
  validIfFresh : Bool

private abbrev ExpectedOperations := List (MovementOperationId × EventId)

private structure Stats where
  expected : ExpectedOperations := []
  applied : Nat := 0
  rejectedFresh : Nat := 0
  retries : Nat := 0

/--
Small platform-independent recurrence used only to choose the next scenario
input. It is not a cryptographic or statistical-randomness claim.
-/
private def nextSeed (seed : Nat) : Nat :=
  ((seed * 48271 + 1) % 2147483647) + 1

private def destinationFor (seed : Nat) : LocusId :=
  match seed % 3 with
  | 0 => ⟨"food"⟩
  | 1 => ⟨"books"⟩
  | _ => ⟨"transport"⟩

private def dateFor (seed : Nat) : String :=
  match seed % 5 with
  | 0 => "2026-09-01"
  | 1 => "2026-09-02"
  | 2 => "2026-09-03"
  | 3 => "2026-09-04"
  | _ => "2026-09-05"

private def operationFor (seed kind : Nat) : MovementOperationId :=
  if kind < 3 then
    ⟨s!"scenario-invalid-{kind}-{seed}"⟩
  else
    ⟨s!"scenario-op-{seed % 7}"⟩

private def balancedEffects
    (destination : LocusId)
    (amount : Int) : List Effect :=
  [
    Effect.ofAnonymousQuantity
      ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
    Effect.ofAnonymousQuantity
      destination ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def scenarioStep (seed : Nat) : ScenarioStep :=
  let amount : Int := Int.ofNat ((((seed / 11) % 9) + 1) * 100)
  let destination := destinationFor seed
  let kind := (seed / 7) % 6
  let operation := operationFor seed kind
  let baseDraft : Loam.MovementAdmission.Draft := {
    validOn := dateFor seed
    description := some s!"deterministic scenario {seed}"
    effects := balancedEffects destination amount
    relations := []
    discharges := []
    total := amount
  }
  match kind with
  | 0 =>
      { seed := seed
        operation := operation
        draft := { baseDraft with validOn := "2026-09-99" }
        validIfFresh := false }
  | 1 =>
      { seed := seed
        operation := operation
        draft := {
          baseDraft with
          effects := balancedEffects ⟨"unapproved"⟩ amount
        }
        validIfFresh := false }
  | 2 =>
      { seed := seed
        operation := operation
        draft := { baseDraft with total := amount + 1 }
        validIfFresh := false }
  | _ =>
      { seed := seed
        operation := operation
        draft := baseDraft
        validIfFresh := true }

private def generateTrace : Nat → Nat → List ScenarioStep
  | _, 0 => []
  | seed, Nat.succ remaining =>
      scenarioStep seed :: generateTrace (nextSeed seed) remaining

private def expectedEvent?
    (operation : MovementOperationId) : ExpectedOperations → Option EventId
  | [] => none
  | (stored, event) :: rest =>
      if stored = operation then some event
      else expectedEvent? operation rest

private def stepContext (index seed : Nat) : String :=
  s!"deterministic scenario seed={seed} step={index}"

private def checkSnapshot
    (root : System.FilePath)
    (expected : ExpectedOperations)
    (index seed : Nat) : IO String := do
  let context := stepContext index seed
  let (evidence, canonicalBytes) ← loadCanonicalActual root context

  expect (evidence.events.events.length == expected.length)
    s!"{context}: Event count diverged from successful logical operations"
  expect (evidence.validity.facts.length == expected.length)
    s!"{context}: validity count diverged from successful logical operations"
  expect (evidence.descriptions.entries.length == expected.length)
    s!"{context}: description count diverged from successful logical operations"
  expect (evidence.movementOperations.entries.length == expected.length)
    s!"{context}: operation-evidence count diverged from successful logical operations"
  expect evidence.relations.isEmpty
    s!"{context}: generated Movement trace unexpectedly retained Relation evidence"
  expect evidence.discharges.isEmpty
    s!"{context}: generated Movement trace unexpectedly retained Discharge evidence"

  for pair in expected do
    let operation := pair.1
    let event := pair.2
    match evidence.movementOperations.findEvent? operation with
    | some found =>
        expect (found == event)
          s!"{context}: operation '{operation.token}' changed its retained Event identity"
    | none =>
        throw <| IO.userError
          s!"{context}: operation '{operation.token}' disappeared from retained evidence"
    match evidence.events.findById? event with
    | some _ => pure ()
    | none =>
        throw <| IO.userError
          s!"{context}: retained operation points to missing Event '{event.token}'"

  pure canonicalBytes

private def prepareRoot (root : System.FilePath) : IO Unit := do
  cleanupDir root
  IO.FS.createDirAll root
  let _ ← requireOk
    (← Loam.ActualAuthority.publishActual? root ActualEvidence.empty)
    "deterministic scenario initial Actual publication failed"
  let loci ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [
      ⟨"wallet"⟩,
      ⟨"food"⟩,
      ⟨"books"⟩,
      ⟨"transport"⟩
    ])
    "deterministic scenario Locus admission fixture was not unique"
  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.publishCurrent? root loci)
    "deterministic scenario Locus admission publication failed"
  pure ()

private def runSteps
    (root : System.FilePath) :
    Nat → List ScenarioStep → Stats → IO Stats
  | _, [], stats => pure stats
  | index, step :: rest, stats => do
      let context := stepContext index step.seed
      let before ← authorityBytes root
      let known := expectedEvent? step.operation stats.expected
      let result ←
        Loam.MovementPublisher.publishDraftIdempotent
          root.toString step.operation step.draft

      let nextStats ←
        match known with
        | some expectedEvent =>
            match result with
            | .ok (.alreadyApplied actualEvent) =>
                expect (actualEvent == expectedEvent)
                  s!"{context}: retry changed Event identity for operation '{step.operation.token}'"
                pure { stats with retries := stats.retries + 1 }
            | .ok (.applied event) =>
                throw <| IO.userError
                  s!"{context}: retry unexpectedly republished operation '{step.operation.token}' as '{event.token}'"
            | .error detail =>
                throw <| IO.userError
                  s!"{context}: retained operation retry was rejected: {detail}"
        | none =>
            if step.validIfFresh then
              match result with
              | .ok (.applied event) =>
                  pure {
                    stats with
                    expected := stats.expected ++ [(step.operation, event)]
                    applied := stats.applied + 1
                  }
              | .ok (.alreadyApplied event) =>
                  throw <| IO.userError
                    s!"{context}: fresh operation unexpectedly reused Event '{event.token}'"
              | .error detail =>
                  throw <| IO.userError
                    s!"{context}: generated valid fresh operation was rejected: {detail}"
            else
              match result with
              | .error _ =>
                  let after ← authorityBytes root
                  expect (after == before)
                    s!"{context}: rejected fresh operation changed canonical authority bytes"
                  pure { stats with rejectedFresh := stats.rejectedFresh + 1 }
              | .ok (.applied event) =>
                  throw <| IO.userError
                    s!"{context}: generated invalid fresh operation published Event '{event.token}'"
              | .ok (.alreadyApplied event) =>
                  throw <| IO.userError
                    s!"{context}: fresh invalid operation unexpectedly reused Event '{event.token}'"

      let _ ← checkSnapshot root nextStats.expected index step.seed
      runSteps root (index + 1) rest nextStats

private def runScenario
    (root : System.FilePath)
    (seed steps : Nat) : IO (Stats × String) := do
  prepareRoot root
  let trace := generateTrace seed steps
  let stats ← runSteps root 0 trace {}
  expect (stats.applied > 0)
    s!"deterministic scenario seed={seed}: no valid fresh operation was exercised"
  expect (stats.rejectedFresh > 0)
    s!"deterministic scenario seed={seed}: no invalid fresh operation was exercised"
  expect (stats.retries > 0)
    s!"deterministic scenario seed={seed}: no idempotent retry was exercised"
  let finalBytes ← checkSnapshot root stats.expected steps seed
  pure (stats, finalBytes)

def runTests : IO Unit := do
  let seed : Nat := 3812026
  let steps : Nat := 48
  let rootA := System.FilePath.mk "scratch/test-deterministic-movement-a"
  let rootB := System.FilePath.mk "scratch/test-deterministic-movement-b"

  let (statsA, bytesA) ← runScenario rootA seed steps
  let (statsB, bytesB) ← runScenario rootB seed steps

  expect (bytesA == bytesB)
    s!"deterministic replay diverged for seed={seed}"
  expect (statsA.applied == statsB.applied)
    s!"deterministic replay changed applied count for seed={seed}"
  expect (statsA.rejectedFresh == statsB.rejectedFresh)
    s!"deterministic replay changed rejection count for seed={seed}"
  expect (statsA.retries == statsB.retries)
    s!"deterministic replay changed retry count for seed={seed}"

  cleanupDir rootA
  cleanupDir rootB

  IO.println
    s!"Deterministic Movement scenario passed: seed={seed}, steps={steps}, applied={statsA.applied}, rejectedFresh={statsA.rejectedFresh}, retries={statsA.retries}."

end Loam.Tests.DeterministicMovementScenario

def main : IO Unit :=
  Loam.Tests.DeterministicMovementScenario.runTests
