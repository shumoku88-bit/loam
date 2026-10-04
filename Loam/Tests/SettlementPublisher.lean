import Loam.HouseholdCommand
import Loam.Persistence.NormalizedActualPersistence
import Loam.Tests.ActualWorldFixture

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

private def publishInitialActual
    (root : System.FilePath)
    (evidence : ActualEvidence) : IO Unit := do
  let body ← requireSome
    (Loam.Persistence.encodeNormalizedActual? evidence)
    "initial settlement Actual did not encode"
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root "Actual" body)
    "initial Household Actual publication failed"
  pure ()

private def actualWire (root : System.FilePath) : IO String := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "load Household generation for settlement wire"
  requireSome
    (Loam.Persistence.HouseholdImage.body? generation.image "Actual")
    "Household settlement Actual section missing"

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

private def extinguishmentBatch : Loam.SettlementPublisher.Draft := {
  extinguishments := [{
    id := ⟨"writer-ext-v1"⟩
    target := ⟨"writer-card-commitment-v2"⟩
    quantity := Quantity.ofQuanta 100
    effectiveOn := none
  }]
}

private def extinguishmentCorrectionBatch : Loam.SettlementPublisher.Draft := {
  extinguishments := [{
    id := ⟨"writer-ext-v2"⟩
    target := ⟨"writer-card-commitment-v2"⟩
    quantity := Quantity.ofQuanta 50
    effectiveOn := some "2026-09-10"
  }]
  extinguishmentRevisions := [{
    target := ⟨"writer-ext-v1"⟩
    replacement := some ⟨"writer-ext-v2"⟩
  }]
}

private def extinguishmentRetractionBatch : Loam.SettlementPublisher.Draft := {
  extinguishmentRevisions := [{
    target := ⟨"writer-ext-v2"⟩
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

private def friendlyActionBoundary : IO Unit := do
  let root := System.FilePath.mk "scratch/test-settlement-friendly-actions"
  cleanupDir root
  IO.FS.createDirAll root

  let initial ← initialActual
  publishInitialActual root initial
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root directBatch)
    "friendly action direct settlement seed failed"

  -- A1: amount correction needs no caller-supplied replacement identity.
  let replacementId ← requireOk
    (← Loam.HouseholdCommand.correctSettlementAmount root {
      target := ⟨"writer-card-commitment"⟩
      quantity := Quantity.ofQuanta 1200
    })
    "friendly amount correction failed"
  expect (replacementId.token.startsWith "settlement-commitment-")
    "friendly amount correction did not allocate an internal commitment identity"
  expectOutstanding root replacementId.token 500
    "friendly amount correction"

  -- A2: an amount smaller than already-settled quantity fails closed.
  let beforeTooSmall ← loadActual root "before too-small friendly correction"
  match ← Loam.HouseholdCommand.correctSettlementAmount root {
      target := replacementId
      quantity := Quantity.ofQuanta 600
    } with
  | .ok _ =>
      throw <| IO.userError
        "friendly amount correction admitted amount below existing settlement"
  | .error _ => pure ()
  let afterTooSmall ← loadActual root "after too-small friendly correction"
  expect (decide (afterTooSmall.settlements = beforeTooSmall.settlements))
    "failed friendly amount correction changed settlement authority"

  -- A3: non-payment reduction allocates its own stable row identity and keeps
  -- unknown effective time unknown.
  let extinguishmentId ← requireOk
    (← Loam.HouseholdCommand.reduceSettlementWithoutPayment root {
      target := replacementId
      quantity := Quantity.ofQuanta 200
      effectiveOn := none
    })
    "friendly non-payment reduction failed"
  expect (extinguishmentId.token.startsWith "settlement-extinguishment-")
    "friendly reduction did not allocate an internal extinguishment identity"
  expectOutstanding root replacementId.token 300
    "friendly non-payment reduction"
  let afterReduction ← loadActual root "after friendly reduction"
  let retainedReduction ← requireSome
    (afterReduction.settlements.extinguishments.find?
      (fun row => row.id = extinguishmentId))
    "friendly reduction row missing"
  expect retainedReduction.effectiveOn.isNone
    "friendly unknown-date reduction fabricated an effective date"

  -- A4: an earlier non-payment decrease can be corrected without the caller
  -- constructing replacement-row identity or revision evidence.
  let correctedReductionId ← requireOk
    (← Loam.HouseholdCommand.correctSettlementReduction root {
      target := extinguishmentId
      quantity := Quantity.ofQuanta 150
      effectiveOn := some "2026-09-20"
    })
    "friendly reduction correction failed"
  expect (correctedReductionId != extinguishmentId)
    "friendly reduction correction reused the superseded row identity"
  expect (correctedReductionId.token.startsWith "settlement-extinguishment-")
    "friendly reduction correction did not allocate an internal replacement identity"
  let correctedReductionImage ← loadImage root "after friendly reduction correction"
  expect (correctedReductionImage.settlement.extinguishedQuanta replacementId == 150)
    "friendly reduction correction did not replace the current quantity"
  expectOutstanding root replacementId.token 350
    "friendly corrected reduction"

  let afterReductionCorrection ← loadActual root "after friendly reduction correction"
  expect (afterReductionCorrection.settlements.extinguishments.length == 2)
    "friendly reduction correction did not retain old and replacement rows"
  expect (afterReductionCorrection.settlements.extinguishmentRevisions.length == 1)
    "friendly reduction correction did not retain revision evidence"
  let correctedRetained ← requireSome
    (afterReductionCorrection.settlements.extinguishments.find?
      (fun row => row.id = correctedReductionId))
    "friendly corrected reduction row missing"
  expect (correctedRetained.effectiveOn == some "2026-09-20")
    "friendly reduction correction lost corrected effective date"

  -- A5: retracting the corrected decrease restores only that decrease while
  -- leaving the commitment and physical settlement current.
  let _ ← requireOk
    (← Loam.HouseholdCommand.retractSettlementReduction root {
      target := correctedReductionId
    })
    "friendly reduction retraction failed"
  let afterReductionRetraction ← loadImage root "after friendly reduction retraction"
  expect (afterReductionRetraction.settlement.extinguishedQuanta replacementId == 0)
    "friendly reduction retraction left decrease current"
  expect (afterReductionRetraction.settlement.settledQuanta replacementId == 700)
    "friendly reduction retraction changed physical settlement"
  expectOutstanding root replacementId.token 500
    "friendly reduction retraction"

  -- A6: explicit known date is checked before publication.
  let beforeBadDate ← loadActual root "before bad friendly date"
  match ← Loam.HouseholdCommand.reduceSettlementWithoutPayment root {
      target := replacementId
      quantity := Quantity.ofQuanta 10
      effectiveOn := some "2026-02-29"
    } with
  | .ok _ =>
      throw <| IO.userError "friendly reduction accepted impossible date"
  | .error _ => pure ()
  let afterBadDate ← loadActual root "after bad friendly date"
  expect (decide (afterBadDate.settlements = beforeBadDate.settlements))
    "failed friendly dated reduction changed settlement authority"

  -- A7: whole-record retraction remains semantically distinct and refuses
  -- while later payment/reduction evidence survives.
  let beforeBlockedRetraction ← loadActual root "before friendly blocked retraction"
  match ← Loam.HouseholdCommand.retractSettlement root {
      target := replacementId
    } with
  | .ok () =>
      throw <| IO.userError
        "friendly retraction erased a commitment with later activity"
  | .error _ => pure ()
  let afterBlockedRetraction ← loadActual root "after friendly blocked retraction"
  expect (decide
      (afterBlockedRetraction.settlements = beforeBlockedRetraction.settlements))
    "failed friendly retraction changed settlement authority"

  -- A8: a genuinely erroneous independent commitment can be retracted without
  -- the caller constructing revision evidence.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root {
      commitments := [{
        id := ⟨"friendly-retractable"⟩
        sourceEvent := sourceEventId
        sourceEffect := sourceEffectKey
        debtor := .household
        creditor := .external ⟨"writer-card-issuer"⟩
        measure := yen
        quantity := Quantity.ofQuanta 250
      }]
    })
    "friendly retractable commitment seed failed"
  expectOutstanding root "friendly-retractable" 250
    "friendly retractable before retraction"
  let _ ← requireOk
    (← Loam.HouseholdCommand.retractSettlement root {
      target := ⟨"friendly-retractable"⟩
    })
    "friendly whole-record retraction failed"
  let image ← loadImage root "after friendly whole-record retraction"
  expect ((image.settlement.outstanding? ⟨"friendly-retractable"⟩).isNone)
    "friendly whole-record retraction left commitment current"

  cleanupDir root

def runAll : IO Unit := do
  let root := System.FilePath.mk "scratch/test-settlement-explicit-publisher"
  cleanupDir root
  IO.FS.createDirAll root

  let initial ← initialActual
  publishInitialActual root initial

  let initialWire ← actualWire root
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

  let v2Wire ← actualWire root
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
  let v3Wire ← actualWire root
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

  let zeroWire ← actualWire root
  expect (zeroWire.contains "SETTLEMENT-NETTING\twriter-zero-context\tjpy\tZERO")
    "zero-net settlement did not persist explicit ZERO outcome"

  -- E5: non-settlement extinguishment reduces current outstanding without
  -- inventing a physical Event or changing settled quantity.
  let eventCountBeforeExtinguishment := afterZero.events.events.length
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root extinguishmentBatch)
    "extinguishment publication failed"

  let afterExtinguishment ← loadActual root "after extinguishment"
  expect (afterExtinguishment.events.events.length == eventCountBeforeExtinguishment)
    "extinguishment publisher invented an Actual Event"
  expectOutstanding root "writer-card-commitment-v2" 200
    "after extinguishment"
  let extImage ← loadImage root "after extinguishment"
  expect (extImage.settlement.settledQuanta ⟨"writer-card-commitment-v2"⟩ == 600)
    "extinguishment changed settled quantity"
  expect (extImage.settlement.extinguishedQuanta ⟨"writer-card-commitment-v2"⟩ == 100)
    "extinguishment quantity missing from current image"
  let v4Wire ← actualWire root
  expect (v4Wire.startsWith (normalizedActualHeaderV4 ++ "\n"))
    "extinguishment publication did not promote canonical Actual to v4"
  expect (v4Wire.contains
      "SETTLEMENT-EXTINGUISHMENT\twriter-ext-v1\tTARGET\twriter-card-commitment-v2\t100\tUNKNOWN")
    "unknown-time extinguishment row was not persisted"

  -- E6: extinguishment evidence itself is append-only correctable.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root extinguishmentCorrectionBatch)
    "extinguishment correction publication failed"
  let correctedExtImage ← loadImage root "after extinguishment correction"
  expect (correctedExtImage.settlement.extinguishedQuanta
      ⟨"writer-card-commitment-v2"⟩ == 50)
    "extinguishment correction did not select replacement row"
  expectOutstanding root "writer-card-commitment-v2" 250
    "after extinguishment correction"

  -- E7: retracting erroneous extinguishment evidence restores only that
  -- non-settlement reduction; the valid commitment and physical settlement stay.
  let _ ← requireOk
    (← Loam.HouseholdCommand.recordSettlementEvidence root extinguishmentRetractionBatch)
    "extinguishment retraction publication failed"
  let retractedExtImage ← loadImage root "after extinguishment retraction"
  expect (retractedExtImage.settlement.extinguishedQuanta
      ⟨"writer-card-commitment-v2"⟩ == 0)
    "retracted extinguishment remained current"
  expect (retractedExtImage.settlement.settledQuanta
      ⟨"writer-card-commitment-v2"⟩ == 600)
    "extinguishment retraction changed physical settlement"
  expectOutstanding root "writer-card-commitment-v2" 300
    "after extinguishment retraction"
  let extRetractionWire ← actualWire root
  expect (extRetractionWire.contains
      "SETTLEMENT-EXTINGUISHMENT-REVISION\twriter-ext-v2\tRETRACT")
    "extinguishment retraction row was not persisted"

  -- E8: an independent commitment may be explicitly retracted through the
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
  let retractionWire ← actualWire root
  expect (retractionWire.contains
      "SETTLEMENT-COMMITMENT-REVISION\twriter-retractable\tRETRACT")
    "commitment retraction row was not persisted"

  -- E9: retracting a commitment with still-current dependent settlement evidence
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
  expect (decide
      (afterBlockedRetraction.settlements = beforeBlockedRetraction.settlements))
    "failed commitment retraction changed retained settlement authority"

  -- E10: a mixed batch is all-or-nothing. One invalid row prevents the valid row too.
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

  -- E11: retrying the same stable row identities is refused, not duplicated.
  match ← Loam.HouseholdCommand.recordSettlementEvidence root directBatch with
  | .ok () =>
      throw <| IO.userError "duplicate settlement row identities were silently republished"
  | .error _ => pure ()

  let afterDuplicate ← loadActual root "after duplicate retry"
  expect (decide (afterDuplicate.settlements = beforeInvalid.settlements))
    "duplicate retry changed retained settlement evidence"

  -- E12: an empty command is not a meaningful publication.
  match ← Loam.HouseholdCommand.recordSettlementEvidence root {} with
  | .ok () => throw <| IO.userError "empty settlement batch was accepted"
  | .error _ => pure ()

  cleanupDir root
  friendlyActionBoundary
  IO.println "Explicit settlement publisher Slice E and friendly action boundary qualification succeeded."

end Loam.Tests.SettlementPublisher

def main : IO Unit :=
  Loam.Tests.SettlementPublisher.runAll
