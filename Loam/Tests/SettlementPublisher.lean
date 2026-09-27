import Loam.HouseholdCommand
import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Tests.SettlementPublisher

open Loam
open Loam.Core
open Loam.Persistence

set_option autoImplicit false

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

private def usd : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def sourceEventId : EventId := ⟨"writer-source"⟩
private def sourceEffectKey : EffectKey := ⟨"writer-source-usd"⟩
private def paymentEventId : EventId := ⟨"writer-payment"⟩
private def paymentEffectKey : EffectKey := ⟨"writer-payment-jpy"⟩

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
      ⟨"writer-source-usd-counter"⟩
      ⟨"writer-source"⟩
      ⟨"writer-source-counter"⟩
      usd
      30)
    "writer source Event construction failed"
  let payment ← requireSome
    (balancedEvent?
      paymentEventId
      paymentEffectKey
      ⟨"writer-payment-jpy-counter"⟩
      ⟨"writer-bank"⟩
      ⟨"writer-payment-counter"⟩
      yen
      (-1000))
    "writer payment Event construction failed"
  let events ← requireSome
    (EventMemory.ofEvents? [source, payment])
    "writer EventMemory construction failed"
  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base sourceEventId "2026-09-01",
      .base paymentEventId "2026-09-02"
    ] [])
    "writer validity construction failed"
  pure {
    ActualEvidence.empty with
    events := events
    validity := validity
  }

private def loadActual (root : System.FilePath) (label : String) : IO ActualEvidence := do
  match ← Loam.ActualAuthority.loadActual? root with
  | .ok evidence => pure evidence
  | .error detail => throw <| IO.userError s!"{label}: {detail}"

private def loadImage (root : System.FilePath) (label : String) :
    IO Loam.ActualAuthority.Image := do
  match ← Loam.ActualAuthority.loadImage? root with
  | .ok image => pure image
  | .error detail => throw <| IO.userError s!"{label}: {detail}"

private def expectOutstanding
    (root : System.FilePath)
    (target : String)
    (expected : Int)
    (label : String) : IO Unit := do
  let image ← loadImage root label
  let amount ← requireSome
    (image.settlement.outstanding? ⟨target⟩)
    s!"{label}: commitment '{target}' missing"
  expect (amount.quanta == expected)
    s!"{label}: expected outstanding {expected}, got {amount.quanta}"

private def directBatch : Loam.SettlementPublisher.Draft := {
  commitments := [{
    id := ⟨"writer-card-commitment"⟩
    sourceEvent := sourceEventId
    sourceEffect := sourceEffectKey
    debtor := .household
    creditor := .external ⟨"writer-card-issuer"⟩
    measure := yen
    quantity := Quantity.ofQuanta 1000
  }]
  correspondences := [{
    id := ⟨"writer-card-row-v1"⟩
    target := ⟨"writer-card-commitment"⟩
    event := paymentEventId
    effect := paymentEffectKey
    quantity := Quantity.ofQuanta 700
  }]
}

private def correctionBatch : Loam.SettlementPublisher.Draft := {
  correspondences := [{
    id := ⟨"writer-card-row-v2"⟩
    target := ⟨"writer-card-commitment"⟩
    event := paymentEventId
    effect := paymentEffectKey
    quantity := Quantity.ofQuanta 600
  }]
  correspondenceRevisions := [{
    target := ⟨"writer-card-row-v1"⟩
    replacement := ⟨"writer-card-row-v2"⟩
  }]
}

private def commitmentCorrectionBatch : Loam.SettlementPublisher.Draft := {
  commitments := [{
    id := ⟨"writer-card-commitment-v2"⟩
    sourceEvent := sourceEventId
    sourceEffect := sourceEffectKey
    debtor := .household
    creditor := .external ⟨"writer-card-issuer"⟩
    measure := yen
    quantity := Quantity.ofQuanta 900
  }]
  commitmentRevisions := [{
    target := ⟨"writer-card-commitment"⟩
    replacement := some ⟨"writer-card-commitment-v2"⟩
  }]
}

private def retractableCommitmentBatch : Loam.SettlementPublisher.Draft := {
  commitments := [{
    id := ⟨"writer-retractable"⟩
    sourceEvent := sourceEventId
    sourceEffect := sourceEffectKey
    debtor := .household
    creditor := .external ⟨"writer-card-issuer"⟩
    measure := yen
    quantity := Quantity.ofQuanta 250
  }]
}

private def retractCommitmentBatch : Loam.SettlementPublisher.Draft := {
  commitmentRevisions := [{
    target := ⟨"writer-retractable"⟩
    replacement := none
  }]
}

private def zeroNetBatch : Loam.SettlementPublisher.Draft := {
  commitments := [
    {
      id := ⟨"writer-zero-out"⟩
      sourceEvent := sourceEventId
      sourceEffect := sourceEffectKey
      debtor := .household
      creditor := .external ⟨"writer-broker"⟩
      measure := yen
      quantity := Quantity.ofQuanta 500
    },
    {
      id := ⟨"writer-zero-in"⟩
      sourceEvent := sourceEventId
      sourceEffect := sourceEffectKey
      debtor := .external ⟨"writer-broker"⟩
      creditor := .household
      measure := yen
      quantity := Quantity.ofQuanta 500
    }
  ]
  nettingContexts := [{
    id := ⟨"writer-zero-context"⟩
    measure := yen
    outcome := .zero
  }]
  nettingMembers := [
    {
      id := ⟨"writer-zero-member-out"⟩
      context := ⟨"writer-zero-context"⟩
      target := ⟨"writer-zero-out"⟩
      quantity := Quantity.ofQuanta 500
    },
    {
      id := ⟨"writer-zero-member-in"⟩
      context := ⟨"writer-zero-context"⟩
      target := ⟨"writer-zero-in"⟩
      quantity := Quantity.ofQuanta 500
    }
  ]
}

private def cleanupDir (dir : System.FilePath) : IO Unit := do
  if ← dir.pathExists then
    IO.FS.removeDirAll dir

def runAll : IO Unit := do
  let root := System.FilePath.mk "scratch/test-settlement-explicit-publisher"
  cleanupDir root
  IO.FS.createDirAll root

  let initial ← initialActual
  let _ ← requireOk
    (← Loam.ActualAuthority.publishActual? root initial)
    "initial v1 Actual publication failed"

  let initialWire ← IO.FS.readFile (Loam.ActualAuthority.actualPath root)
  expect (initialWire.startsWith (normalizedActualHeaderV1 ++ "\n"))
    "initial settlement-empty authority was not v1"

  -- E1: explicit direct evidence atomically promotes the authority to v2.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root directBatch)
    "direct settlement publication failed"

  let afterDirect ← loadActual root "after direct settlement"
  expect (afterDirect.settlements.commitments.length == 1)
    "direct writer did not retain commitment"
  expect (afterDirect.settlements.correspondences.length == 1)
    "direct writer did not retain correspondence"
  expectOutstanding root "writer-card-commitment" 300
    "after direct settlement"

  let v2Wire ← IO.FS.readFile (Loam.ActualAuthority.actualPath root)
  expect (v2Wire.startsWith (normalizedActualHeaderV2 ++ "\n"))
    "first settlement publication did not promote authority to v2"

  -- E2: append-only correction publishes replacement row + edge atomically.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root correctionBatch)
    "correspondence correction publication failed"

  let afterCorrection ← loadActual root "after correspondence correction"
  expect (afterCorrection.settlements.correspondences.length == 2)
    "correction did not retain old and replacement correspondence rows"
  expect (afterCorrection.settlements.correspondenceRevisions.length == 1)
    "correction did not retain revision edge"
  expectOutstanding root "writer-card-commitment" 400
    "after correspondence correction"

  -- E3: commitment correction publishes the replacement commitment and the
  -- revision edge atomically. Existing correspondence evidence keeps its
  -- historical target and is re-admitted against the replacement commitment.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root commitmentCorrectionBatch)
    "commitment correction publication failed"

  let afterCommitmentRevision ← loadActual root "after commitment correction"
  expect (afterCommitmentRevision.settlements.commitments.length == 2)
    "commitment correction did not retain old and replacement commitment rows"
  expect (afterCommitmentRevision.settlements.commitmentRevisions.length == 1)
    "commitment correction did not retain revision authority"
  expectOutstanding root "writer-card-commitment-v2" 300
    "after commitment correction"
  let v3Wire ← IO.FS.readFile (Loam.ActualAuthority.actualPath root)
  expect (v3Wire.startsWith (normalizedActualHeaderV3 ++ "\n"))
    "commitment correction publication did not promote canonical Actual to v3"
  expect (v3Wire.contains
      "SETTLEMENT-COMMITMENT-REVISION\twriter-card-commitment\tREPLACEMENT\twriter-card-commitment-v2")
    "commitment correction revision row was not persisted"

  -- E4: unrelated settlement evidence must preserve existing commitment
  -- revision authority without inventing another Event.
  let eventCountBeforeZero := afterCommitmentRevision.events.events.length
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root zeroNetBatch)
    "zero-net settlement publication failed"

  let afterZero ← loadActual root "after zero-net settlement"
  expect (afterZero.events.events.length == eventCountBeforeZero)
    "zero-net settlement publisher invented a physical Event"
  expectOutstanding root "writer-zero-out" 0
    "zero-net outgoing"
  expectOutstanding root "writer-zero-in" 0
    "zero-net incoming"
  expect (afterZero.settlements.commitmentRevisions ==
      afterCommitmentRevision.settlements.commitmentRevisions)
    "ordinary settlement publication dropped commitment revision authority"
  expectOutstanding root "writer-card-commitment-v2" 300
    "commitment revision after unrelated settlement publication"

  let zeroWire ← IO.FS.readFile (Loam.ActualAuthority.actualPath root)
  expect (zeroWire.contains "SETTLEMENT-NETTING\twriter-zero-context\tjpy\tZERO")
    "zero-net settlement did not persist explicit ZERO outcome"

  -- E5: an independent commitment may be explicitly retracted through the
  -- same append-only publisher. The retained row remains evidence, but it leaves
  -- the current settlement projection.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root retractableCommitmentBatch)
    "retractable commitment publication failed"
  expectOutstanding root "writer-retractable" 250
    "before explicit commitment retraction"

  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root retractCommitmentBatch)
    "commitment retraction publication failed"

  let afterRetraction ← loadActual root "after commitment retraction"
  expect (afterRetraction.settlements.commitmentRevisions.length == 2)
    "commitment retraction was not retained"
  let retractedImage ← loadImage root "after commitment retraction"
  expect ((retractedImage.settlement.outstanding? ⟨"writer-retractable"⟩).isNone)
    "retracted commitment remained current"
  let retractionWire ← IO.FS.readFile (Loam.ActualAuthority.actualPath root)
  expect (retractionWire.contains
      "SETTLEMENT-COMMITMENT-REVISION\twriter-retractable\tRETRACT")
    "commitment retraction row was not persisted"

  -- E6: retracting a commitment with still-current dependent settlement evidence
  -- fails closed and leaves the canonical generation unchanged.
  let beforeBlockedRetraction ← loadActual root "before blocked retraction"
  let blockedRetraction : Loam.SettlementPublisher.Draft := {
    commitmentRevisions := [{
      target := ⟨"writer-card-commitment-v2"⟩
      replacement := none
    }]
  }
  match ← Loam.HouseholdCommand.recordSettlementEvidence root blockedRetraction with
  | .ok () =>
      throw <| IO.userError
        "commitment with current dependent settlement evidence was retracted"
  | .error _ => pure ()
  let afterBlockedRetraction ← loadActual root "after blocked retraction"
  expect (afterBlockedRetraction.settlements == beforeBlockedRetraction.settlements)
    "failed commitment retraction changed retained settlement authority"

  -- E7: a mixed batch is all-or-nothing. One invalid row prevents the valid row too.
  let beforeInvalid ← loadActual root "before invalid batch"
  let invalidBatch : Loam.SettlementPublisher.Draft := {
    commitments := [{
      id := ⟨"writer-should-not-appear"⟩
      sourceEvent := sourceEventId
      sourceEffect := sourceEffectKey
      debtor := .household
      creditor := .external ⟨"writer-card-issuer"⟩
      measure := yen
      quantity := Quantity.ofQuanta 100
    }]
    correspondences := [{
      id := ⟨"writer-invalid-row"⟩
      target := ⟨"missing-target"⟩
      event := paymentEventId
      effect := paymentEffectKey
      quantity := Quantity.ofQuanta 100
    }]
  }

  match ← Loam.HouseholdCommand.recordSettlementEvidence root invalidBatch with
  | .ok () =>
      throw <| IO.userError "invalid mixed settlement batch was published"
  | .error _ => pure ()

  let afterInvalid ← loadActual root "after invalid batch"
  expect (decide (afterInvalid.settlements = beforeInvalid.settlements))
    "invalid batch partially changed settlement authority"

  -- E8: retrying the same stable row identities is refused, not duplicated.
  match ← Loam.HouseholdCommand.recordSettlementEvidence root directBatch with
  | .ok () =>
      throw <| IO.userError "duplicate settlement row identities were silently republished"
  | .error _ => pure ()

  let afterDuplicate ← loadActual root "after duplicate retry"
  expect (decide (afterDuplicate.settlements = beforeInvalid.settlements))
    "duplicate retry changed retained settlement evidence"

  -- E9: an empty command is not a meaningful publication.
  match ← Loam.HouseholdCommand.recordSettlementEvidence root {} with
  | .ok () => throw <| IO.userError "empty settlement batch was accepted"
  | .error _ => pure ()

  cleanupDir root
  IO.println "Explicit settlement publisher Slice E qualification succeeded."

end Loam.Tests.SettlementPublisher

def main : IO Unit :=
  Loam.Tests.SettlementPublisher.runAll
