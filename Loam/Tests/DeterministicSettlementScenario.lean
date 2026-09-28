import Loam.ActualAuthority
import Loam.HouseholdCommand
import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Tests.DeterministicSettlementScenario

open Loam
open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private structure Stats where
  amountCorrections : Nat := 0
  reductions : Nat := 0
  reductionCorrections : Nat := 0
  reductionRetractions : Nat := 0
  commitmentRetractions : Nat := 0
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

private def usd : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def sourceEventId : EventId := ⟨"scenario-settlement-source"⟩
private def sourceEffectKey : EffectKey := ⟨"scenario-source-usd"⟩
private def paymentEventId : EventId := ⟨"scenario-settlement-payment"⟩
private def paymentEffectKey : EffectKey := ⟨"scenario-payment-jpy"⟩
private def initialCommitmentId : SettlementCommitmentId :=
  ⟨"scenario-card-commitment"⟩

private def balancedEvent?
    (id : EventId)
    (firstKey secondKey : EffectKey)
    (firstLocus secondLocus : LocusId)
    (measure : MeasureId)
    (amount : Int) : Option Event :=
  Event.ofEffects? id [
    Effect.ofQuantity firstKey firstLocus measure (Quantity.ofQuanta amount),
    Effect.ofQuantity secondKey secondLocus measure (Quantity.ofQuanta (-amount))
  ]

private def initialActual : IO ActualEvidence := do
  let source ← requireSome
    (balancedEvent?
      sourceEventId
      sourceEffectKey
      ⟨"scenario-source-counter-key"⟩
      ⟨"scenario-source"⟩
      ⟨"scenario-source-counter"⟩
      usd
      30)
    "settlement scenario source Event construction failed"
  let payment ← requireSome
    (balancedEvent?
      paymentEventId
      paymentEffectKey
      ⟨"scenario-payment-counter-key"⟩
      ⟨"scenario-bank"⟩
      ⟨"scenario-payment-counter"⟩
      yen
      (-1000))
    "settlement scenario payment Event construction failed"
  let events ← requireSome
    (EventMemory.ofEvents? [source, payment])
    "settlement scenario Event memory construction failed"
  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base sourceEventId "2026-09-01",
      .base paymentEventId "2026-09-02"
    ] [])
    "settlement scenario validity construction failed"
  pure {
    ActualEvidence.empty with
    events := events
    validity := validity
  }

private def seedBatch : Loam.SettlementPublisher.Draft := {
  commitments := [{
    id := initialCommitmentId
    sourceEvent := sourceEventId
    sourceEffect := sourceEffectKey
    debtor := .household
    creditor := .external ⟨"scenario-card-issuer"⟩
    measure := yen
    quantity := Quantity.ofQuanta 1000
  }]
  correspondences := [{
    id := ⟨"scenario-card-payment-row"⟩
    target := initialCommitmentId
    event := paymentEventId
    effect := paymentEffectKey
    quantity := Quantity.ofQuanta 700
  }]
}

private def retractableBatch : Loam.SettlementPublisher.Draft := {
  commitments := [{
    id := ⟨"scenario-retractable"⟩
    sourceEvent := sourceEventId
    sourceEffect := sourceEffectKey
    debtor := .household
    creditor := .external ⟨"scenario-card-issuer"⟩
    measure := yen
    quantity := Quantity.ofQuanta 250
  }]
}

private def authorityBytes (root : System.FilePath) : IO String :=
  IO.FS.readFile (Loam.ActualAuthority.actualPath root)

private def loadActual
    (root : System.FilePath)
    (context : String) : IO ActualEvidence := do
  requireOk (← Loam.ActualAuthority.loadActual? root)
    s!"{context}: typed Actual reload failed"

private def loadImage
    (root : System.FilePath)
    (context : String) : IO Loam.ActualAuthority.Image := do
  requireOk (← Loam.ActualAuthority.loadImage? root)
    s!"{context}: admitted Actual image reload failed"

private def checkCanonical
    (root : System.FilePath)
    (context : String) : IO String := do
  let evidence ← loadActual root context
  let encoded ← requireSome
    (encodeNormalizedActual? evidence)
    s!"{context}: admitted Actual failed canonical encoding"
  let decoded ← requireSome
    (decodeNormalizedActual? encoded)
    s!"{context}: canonical bytes failed typed decoding"
  let reencoded ← requireSome
    (encodeNormalizedActual? decoded)
    s!"{context}: decoded Actual failed canonical re-encoding"
  expect (encoded == reencoded)
    s!"{context}: normalized Actual encode/decode was not canonical"
  let disk ← authorityBytes root
  expect (disk == encoded)
    s!"{context}: authority bytes diverged from canonical encoding"
  pure disk

private def outstanding
    (root : System.FilePath)
    (target : SettlementCommitmentId)
    (context : String) : IO Int := do
  let image ← loadImage root context
  let quantity ← requireSome
    (image.settlement.outstanding? target)
    s!"{context}: current commitment '{target.token}' missing"
  pure quantity.quanta

private def expectOutstanding
    (root : System.FilePath)
    (target : SettlementCommitmentId)
    (expected : Int)
    (context : String) : IO Unit := do
  let actual ← outstanding root target context
  expect (actual == expected)
    s!"{context}: expected outstanding {expected}, got {actual}"

private def expectRefusal {α : Type}
    (root : System.FilePath)
    (context : String)
    (action : IO (Except String α)) : IO Unit := do
  let before ← authorityBytes root
  match ← action with
  | .ok _ =>
      throw <| IO.userError s!"{context}: operation unexpectedly succeeded"
  | .error _ => pure ()
  let after ← authorityBytes root
  expect (after == before)
    s!"{context}: refused operation changed Actual authority bytes"
  let _ ← checkCanonical root context
  pure ()

private def prepareRoot (root : System.FilePath) : IO Unit := do
  cleanupDir root
  IO.FS.createDirAll root
  let initial ← initialActual
  let _ ← requireOk
    (← Loam.ActualAuthority.publishActual? root initial)
    "settlement scenario initial Actual publication failed"
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root seedBatch)
    "settlement scenario seed publication failed"
  expectOutstanding root initialCommitmentId 300
    "after initial physical settlement"
  let _ ← checkCanonical root "after settlement seed"
  pure ()

private def runScenario
    (root : System.FilePath) : IO (Stats × String) := do
  prepareRoot root
  let mut stats : Stats := {}

  -- Correct the obligation amount while preserving the historical physical
  -- settlement row against the original commitment identity.
  let correctedCommitment ← requireOk
    (← Loam.HouseholdCommand.correctSettlementAmount root {
      target := initialCommitmentId
      quantity := Quantity.ofQuanta 1200
    })
    "step 1 settlement amount correction failed"
  stats := { stats with amountCorrections := stats.amountCorrections + 1 }
  expect (correctedCommitment != initialCommitmentId)
    "step 1 amount correction reused the superseded commitment identity"
  expectOutstanding root correctedCommitment 500
    "step 1 corrected commitment outstanding"
  let _ ← checkCanonical root "step 1 amount correction"

  -- Existing settlement already explains 700, so correcting the obligation
  -- below that amount must fail closed.
  expectRefusal root "step 2 too-small amount correction"
    (Loam.HouseholdCommand.correctSettlementAmount root {
      target := correctedCommitment
      quantity := Quantity.ofQuanta 600
    })
  stats := { stats with refusals := stats.refusals + 1 }

  -- The current amount is also not a meaningful correction.
  expectRefusal root "step 3 unchanged amount correction"
    (Loam.HouseholdCommand.correctSettlementAmount root {
      target := correctedCommitment
      quantity := Quantity.ofQuanta 1200
    })
  stats := { stats with refusals := stats.refusals + 1 }

  let reduction ← requireOk
    (← Loam.HouseholdCommand.reduceSettlementWithoutPayment root {
      target := correctedCommitment
      quantity := Quantity.ofQuanta 200
      effectiveOn := none
    })
    "step 4 non-payment reduction failed"
  stats := { stats with reductions := stats.reductions + 1 }
  expectOutstanding root correctedCommitment 300
    "step 4 non-payment reduction outstanding"
  let afterReduction ← loadActual root "step 4 reduction"
  let retainedReduction ← requireSome
    (afterReduction.settlements.extinguishments.find?
      (fun row => row.id = reduction))
    "step 4 reduction row missing"
  expect retainedReduction.effectiveOn.isNone
    "step 4 unknown effective time was fabricated"
  let _ ← checkCanonical root "step 4 reduction"

  let correctedReduction ← requireOk
    (← Loam.HouseholdCommand.correctSettlementReduction root {
      target := reduction
      quantity := Quantity.ofQuanta 150
      effectiveOn := some "2026-09-20"
    })
    "step 5 reduction correction failed"
  stats := {
    stats with
    reductionCorrections := stats.reductionCorrections + 1
  }
  expect (correctedReduction != reduction)
    "step 5 reduction correction reused superseded identity"
  let correctedImage ← loadImage root "step 5 reduction correction"
  expect
    (correctedImage.settlement.extinguishedQuanta correctedCommitment == 150)
    "step 5 corrected extinguishment quantity was not current"
  expectOutstanding root correctedCommitment 350
    "step 5 corrected reduction outstanding"
  let _ ← checkCanonical root "step 5 reduction correction"

  let _ ← requireOk
    (← Loam.HouseholdCommand.retractSettlementReduction root {
      target := correctedReduction
    })
    "step 6 reduction retraction failed"
  stats := {
    stats with
    reductionRetractions := stats.reductionRetractions + 1
  }
  let afterRetractionImage ← loadImage root "step 6 reduction retraction"
  expect
    (afterRetractionImage.settlement.extinguishedQuanta correctedCommitment == 0)
    "step 6 retracted reduction remained current"
  expect
    (afterRetractionImage.settlement.settledQuanta correctedCommitment == 700)
    "step 6 reduction retraction changed physical settlement"
  expectOutstanding root correctedCommitment 500
    "step 6 reduction retraction outstanding"
  let _ ← checkCanonical root "step 6 reduction retraction"

  expectRefusal root "step 7 invalid reduction date"
    (Loam.HouseholdCommand.reduceSettlementWithoutPayment root {
      target := correctedCommitment
      quantity := Quantity.ofQuanta 10
      effectiveOn := some "2026-02-29"
    })
  stats := { stats with refusals := stats.refusals + 1 }

  -- The physical settlement row still depends on the corrected lineage, so the
  -- current commitment cannot be retracted as merely erroneous.
  expectRefusal root "step 8 dependent commitment retraction"
    (Loam.HouseholdCommand.retractSettlement root {
      target := correctedCommitment
    })
  stats := { stats with refusals := stats.refusals + 1 }

  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root retractableBatch)
    "step 9 independent commitment seed failed"
  expectOutstanding root ⟨"scenario-retractable"⟩ 250
    "step 9 independent commitment"

  let _ ← requireOk
    (← Loam.HouseholdCommand.retractSettlement root {
      target := ⟨"scenario-retractable"⟩
    })
    "step 10 independent commitment retraction failed"
  stats := {
    stats with
    commitmentRetractions := stats.commitmentRetractions + 1
  }
  let afterIndependentRetraction ← loadImage root "step 10 independent retraction"
  expect
    ((afterIndependentRetraction.settlement.outstanding?
      ⟨"scenario-retractable"⟩).isNone)
    "step 10 retracted independent commitment remained current"
  let _ ← checkCanonical root "step 10 independent retraction"

  -- Explicit publisher retries are intentionally not idempotent. Reusing stable
  -- settlement row identities must fail rather than duplicate history.
  expectRefusal root "step 11 duplicate explicit settlement batch"
    (Loam.HouseholdCommand.recordSettlementEvidence root seedBatch)
  stats := { stats with refusals := stats.refusals + 1 }

  let final ← loadActual root "final settlement scenario"
  expect (final.events.events.length == 2)
    "Settlement actions invented or removed Actual Events"
  expect (final.settlements.commitments.length == 3)
    "final raw commitment count changed"
  expect (final.settlements.commitmentRevisions.length == 2)
    "final commitment revision count changed"
  expect (final.settlements.correspondences.length == 1)
    "final correspondence count changed"
  expect (final.settlements.extinguishments.length == 2)
    "final extinguishment row count changed"
  expect (final.settlements.extinguishmentRevisions.length == 2)
    "final extinguishment revision count changed"
  expect final.settlements.nettingContexts.isEmpty
    "deterministic settlement scenario unexpectedly retained netting contexts"
  expect final.settlements.nettingMembers.isEmpty
    "deterministic settlement scenario unexpectedly retained netting members"

  let finalImage ← loadImage root "final settlement image"
  expect
    (finalImage.settlement.settledQuanta correctedCommitment == 700)
    "historical physical settlement did not survive commitment correction lineage"
  expect
    (finalImage.settlement.extinguishedQuanta correctedCommitment == 0)
    "retracted non-payment reduction remained in current settlement image"
  expectOutstanding root correctedCommitment 500
    "final corrected commitment outstanding"

  let bytes ← checkCanonical root "final settlement scenario"
  pure (stats, bytes)

def runTests : IO Unit := do
  let rootA := System.FilePath.mk "scratch/test-deterministic-settlement-a"
  let rootB := System.FilePath.mk "scratch/test-deterministic-settlement-b"

  let (statsA, bytesA) ← runScenario rootA
  let (statsB, bytesB) ← runScenario rootB

  expect (statsA == statsB)
    "deterministic Settlement replay changed scenario counters"
  expect (bytesA == bytesB)
    "deterministic Settlement replay produced different canonical bytes"

  expect (statsA.amountCorrections == 1)
    "deterministic Settlement scenario missed amount correction"
  expect (statsA.reductions == 1)
    "deterministic Settlement scenario missed non-payment reduction"
  expect (statsA.reductionCorrections == 1)
    "deterministic Settlement scenario missed reduction correction"
  expect (statsA.reductionRetractions == 1)
    "deterministic Settlement scenario missed reduction retraction"
  expect (statsA.commitmentRetractions == 1)
    "deterministic Settlement scenario missed independent commitment retraction"
  expect (statsA.refusals == 5)
    "deterministic Settlement scenario missed expected refusal branches"

  cleanupDir rootA
  cleanupDir rootB

  IO.println
    s!"Deterministic Settlement scenario passed: amountCorrections={statsA.amountCorrections}, reductions={statsA.reductions}, reductionCorrections={statsA.reductionCorrections}, reductionRetractions={statsA.reductionRetractions}, commitmentRetractions={statsA.commitmentRetractions}, refusals={statsA.refusals}."

end Loam.Tests.DeterministicSettlementScenario

def main : IO Unit :=
  Loam.Tests.DeterministicSettlementScenario.runTests
