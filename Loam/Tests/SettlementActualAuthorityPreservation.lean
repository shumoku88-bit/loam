import Loam.Authority.ActualAuthority
import Loam.Publisher.ActualValidityPublisher
import Loam.Publisher.EventMerchantPublisher
import Loam.Persistence.NormalizedActualPersistence
import Loam.Tests.ActualWorldFixture

namespace Loam.Tests.SettlementActualAuthorityPreservation

open Loam
open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw <| IO.userError s!"{message}: {detail}"

private def usd : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def sourceEventId : EventId := ⟨"d4-source"⟩
private def sourceEffectKey : EffectKey := ⟨"d4-source-usd"⟩
private def paymentEventId : EventId := ⟨"d4-payment"⟩
private def paymentEffectKey : EffectKey := ⟨"d4-payment-jpy"⟩

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

private def settlementEvidence : SettlementEvidence := {
  commitments := [{
    id := ⟨"d4-card-commitment"⟩
    sourceEvent := sourceEventId
    sourceEffect := sourceEffectKey
    debtor := .household
    creditor := .external ⟨"d4-card-issuer"⟩
    measure := yen
    quantity := Quantity.ofQuanta 4700
  }]
  correspondences := [{
    id := ⟨"d4-card-correspondence"⟩
    target := ⟨"d4-card-commitment"⟩
    event := paymentEventId
    effect := paymentEffectKey
    quantity := Quantity.ofQuanta 4700
  }]
  correspondenceRevisions := []
  nettingContexts := []
  nettingMembers := []
  nettingMemberRevisions := []
}

private def initialEvidence : IO ActualEvidence := do
  let source ← requireSome
    (balancedEvent?
      sourceEventId
      sourceEffectKey
      ⟨"d4-source-usd-counter"⟩
      ⟨"d4-source"⟩
      ⟨"d4-source-counter"⟩
      usd
      30)
    "D4 source Event construction failed"
  let payment ← requireSome
    (balancedEvent?
      paymentEventId
      paymentEffectKey
      ⟨"d4-payment-jpy-counter"⟩
      ⟨"d4-bank"⟩
      ⟨"d4-payment-counter"⟩
      yen
      (-4700))
    "D4 payment Event construction failed"
  let events ← requireSome
    (EventMemory.ofEvents? [source, payment])
    "D4 EventMemory construction failed"
  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base sourceEventId "2026-09-01",
      .base paymentEventId "2026-09-02"
    ] [])
    "D4 validity construction failed"
  pure {
    ActualEvidence.empty with
    events := events
    validity := validity
    settlements := settlementEvidence
  }

private def cleanupDir (dir : System.FilePath) : IO Unit := do
  if ← dir.pathExists then
    IO.FS.removeDirAll dir

private def loadActual (root : System.FilePath) (label : String) : IO ActualEvidence := do
  match ← Loam.ActualAuthority.loadActual? root with
  | .ok evidence => pure evidence
  | .error detail => throw <| IO.userError s!"{label}: {detail}"

private def loadImage (root : System.FilePath) (label : String) :
    IO Loam.ActualAuthority.Image := do
  match ← Loam.ActualAuthority.loadImage? root with
  | .ok image => pure image
  | .error detail => throw <| IO.userError s!"{label}: {detail}"

private def expectSettlementPreserved
    (evidence : ActualEvidence)
    (label : String) : IO Unit := do
  expect (decide (evidence.settlements = settlementEvidence))
    s!"{label}: retained settlement evidence changed"

private def actualWire (root : System.FilePath) (label : String) : IO String := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    s!"{label}: load Household generation"
  requireSome
    (Loam.Persistence.HouseholdImage.body? generation.image "Actual")
    s!"{label}: Household Actual section missing"

private def expectV2 (root : System.FilePath) (label : String) : IO Unit := do
  let wire ← actualWire root label
  expect (wire.startsWith (normalizedActualHeaderV2 ++ "\n"))
    s!"{label}: settlement-bearing Household Actual did not remain v2"
  expect (wire.contains "SETTLEMENT-COMMITMENT\td4-card-commitment")
    s!"{label}: v2 authority lost settlement commitment row"
  expect (wire.contains "SETTLEMENT-CORRESPONDENCE\td4-card-correspondence")
    s!"{label}: v2 authority lost settlement correspondence row"

private def expectSettled (root : System.FilePath) (label : String) : IO Unit := do
  let image ← loadImage root label
  let outstanding ← requireSome
    (image.settlement.outstanding? ⟨"d4-card-commitment"⟩)
    s!"{label}: settlement commitment missing from admitted image"
  expect (outstanding.quanta == 0)
    s!"{label}: expected fully settled commitment, got outstanding {outstanding.quanta}"

def runAll : IO Unit := do
  let root := System.FilePath.mk "scratch/test-settlement-actual-authority-d4"
  cleanupDir root
  IO.FS.createDirAll root

  let householdPath := Loam.HouseholdAuthority.path root
  let stagePath := System.FilePath.mk (householdPath.toString ++ ".loam-stage")

  let initial ← initialEvidence

  -- D4-A: first settlement-bearing Household Actual is v2.
  let initialBody ← requireSome
    (encodeNormalizedActual? initial)
    "D4-A initial v2 Actual failed to encode"
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Actual" initialBody)
    "D4-A initial Household Actual publication failed"
  let loadedInitial ← loadActual root "D4-A load"
  expectSettlementPreserved loadedInitial "D4-A"
  expectV2 root "D4-A"
  expectSettled root "D4-A"

  -- D4-B: a torn/corrupt Household stage is off-authority and cannot affect readers.
  IO.FS.writeFile stagePath
    "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tActual\t999\npartial"
  let afterTornStage ← loadActual root "D4-B load after torn stage"
  expectSettlementPreserved afterTornStage "D4-B"
  expectV2 root "D4-B"
  expectSettled root "D4-B"

  -- D4-C: even a complete valid next generation remains invisible before rename.
  let descriptions ← requireSome
    (EventDescriptionMemory.ofEntries? [{
      event := sourceEventId
      text := "card purchase provenance"
    }])
    "D4-C description fixture failed"
  let preRenameCandidate : ActualEvidence := {
    loadedInitial with
    descriptions := descriptions
  }
  let nextActualBody ← requireSome
    (encodeNormalizedActual? preRenameCandidate)
    "D4-C candidate Actual failed to encode"
  let currentGeneration ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "D4-C load current Household generation"
  let nextImage ← requireSome
    (Loam.Persistence.HouseholdImage.replaceBody?
      currentGeneration.image "Actual" nextActualBody)
    "D4-C replace Household Actual section"
  let stageWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? nextImage)
    "D4-C candidate Household generation failed to encode"
  IO.FS.writeFile stagePath stageWire

  let beforeRename ← loadActual root "D4-C pre-rename load"
  expectSettlementPreserved beforeRename "D4-C pre-rename"
  expect (beforeRename.descriptions.findText? sourceEventId).isNone
    "D4-C: staged Household content became visible before authority rename"

  IO.FS.rename stagePath householdPath

  let afterRename ← loadActual root "D4-C post-rename load"
  expectSettlementPreserved afterRename "D4-C post-rename"
  expect (afterRename.descriptions.findText? sourceEventId ==
    some "card purchase provenance")
    "D4-C: atomic rename did not switch to complete next generation"
  expectV2 root "D4-C post-rename"
  expectSettled root "D4-C post-rename"

  -- D4-D: malformed current settlement evidence is rejected and old authority survives.
  let malformedCorrespondence : SettlementEffectCorrespondence := {
    id := ⟨"d4-bad-current"⟩
    target := ⟨"d4-card-commitment"⟩
    event := paymentEventId
    effect := ⟨"d4-missing-physical-effect"⟩
    quantity := Quantity.ofQuanta 4700
  }
  let malformed : ActualEvidence := {
    afterRename with
    settlements := {
      afterRename.settlements with
      correspondences := [malformedCorrespondence]
    }
  }
  match ← Loam.ActualAuthority.publishActual? root malformed with
  | .ok () =>
      throw <| IO.userError
        "D4-D: malformed current settlement evidence replaced authority"
  | .error _ => pure ()

  let afterRejectedPublish ← loadActual root "D4-D load"
  expectSettlementPreserved afterRejectedPublish "D4-D"
  expect (afterRejectedPublish.descriptions.findText? sourceEventId ==
    some "card purchase provenance")
    "D4-D: failed publish changed unrelated retained description"
  expectV2 root "D4-D"
  expectSettled root "D4-D"

  -- D4-E: an unrelated Merchant publisher re-reads the v2 generation and preserves settlement.
  let _ ← requireOk
    (← Loam.EventMerchantPublisher.publishDisposition root.toString {
      target := sourceEventId
      disposition := .merchant ⟨"d4-shop"⟩
    })
    "D4-E Merchant publication failed"

  let afterMerchant ← loadActual root "D4-E load"
  expectSettlementPreserved afterMerchant "D4-E"
  expect (afterMerchant.merchants.findDisposition? sourceEventId ==
    some (.merchant ⟨"d4-shop"⟩))
    "D4-E: Merchant publication did not retain its own evidence"
  expectV2 root "D4-E"
  expectSettled root "D4-E"

  -- D4-F: a second independent publisher must re-read the Merchant-updated generation,
  -- not overwrite it from stale pre-Merchant evidence.
  let _ ← requireOk
    (← Loam.ActualValidityPublisher.publishDate root.toString {
      target := sourceEventId
      validOn := "2026-09-03"
    })
    "D4-F occurrence-date publication failed"

  let afterDate ← loadActual root "D4-F load"
  expectSettlementPreserved afterDate "D4-F"
  expect (afterDate.merchants.findDisposition? sourceEventId ==
    some (.merchant ⟨"d4-shop"⟩))
    "D4-F: date publisher overwrote newer Merchant evidence"
  let imageAfterDate ← loadImage root "D4-F admitted image"
  let currentDate ← requireSome
    (imageAfterDate.currentValidities.findByEventId? sourceEventId)
    "D4-F: corrected current occurrence date missing"
  expect (currentDate == "2026-09-03")
    s!"D4-F: expected current date 2026-09-03, got {currentDate}"
  expectV2 root "D4-F"
  expectSettled root "D4-F"

  cleanupDir root
  IO.println "Settlement D4 Household Actual-authority preservation qualification succeeded."

end Loam.Tests.SettlementActualAuthorityPreservation

def main : IO Unit :=
  Loam.Tests.SettlementActualAuthorityPreservation.runAll
