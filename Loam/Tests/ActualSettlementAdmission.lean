import Loam.Persistence.NormalizedActualAdmission

namespace Loam.Tests.ActualSettlementAdmission

open Loam
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

private def usd : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def sourceLocus : LocusId := ⟨"source"⟩
private def sourceCounterpartyLocus : LocusId := ⟨"source-counterparty"⟩
private def bank : LocusId := ⟨"bank"⟩
private def paymentCounterpartyLocus : LocusId := ⟨"payment-counterparty"⟩

private def issuer : ExternalPartyId := ⟨"issuer"⟩

private def sourceEventId : EventId := ⟨"actual-settlement-source"⟩
private def sourceEffectKey : EffectKey := ⟨"source-usd"⟩
private def paymentEventId : EventId := ⟨"actual-settlement-payment"⟩
private def paymentEffectKey : EffectKey := ⟨"payment-jpy"⟩

private def sourceEvent? : Option Event :=
  Event.ofEffects? sourceEventId [
    Effect.ofQuantity sourceEffectKey sourceLocus usd (Quantity.ofQuanta 30),
    Effect.ofQuantity
      ⟨"source-usd-counter"⟩
      sourceCounterpartyLocus
      usd
      (Quantity.ofQuanta (-30))
  ]

private def paymentEvent? : Option Event :=
  Event.ofEffects? paymentEventId [
    Effect.ofQuantity paymentEffectKey bank yen (Quantity.ofQuanta (-4700)),
    Effect.ofQuantity
      ⟨"payment-jpy-counter"⟩
      paymentCounterpartyLocus
      yen
      (Quantity.ofQuanta 4700)
  ]

private def actualFixture? : Option ActualEvidence := do
  let source ← sourceEvent?
  let payment ← paymentEvent?
  let events ← EventMemory.ofEvents? [source, payment]
  let validity ← ActualValidityHistory.ofParts? [
    .base sourceEventId "2026-09-01",
    .base paymentEventId "2026-09-02"
  ] []
  let settlement : SettlementEvidence := {
    commitments := [{
      id := ⟨"card-commitment"⟩
      sourceEvent := sourceEventId
      sourceEffect := sourceEffectKey
      debtor := .household
      creditor := .external issuer
      measure := yen
      quantity := Quantity.ofQuanta 4700
    }]
    correspondences := [{
      id := ⟨"card-correspondence"⟩
      target := ⟨"card-commitment"⟩
      event := paymentEventId
      effect := paymentEffectKey
      quantity := Quantity.ofQuanta 4700
    }]
    correspondenceRevisions := []
    nettingContexts := []
    nettingMembers := []
    nettingMemberRevisions := []
  }
  some {
    ActualEvidence.empty with
    events := events
    validity := validity
    settlements := settlement
  }

private def retainedSettlementProjectsInsideActualImage : IO Unit := do
  let actual ← requireSome actualFixture?
    "D2 fixture construction failed"
  let image ← requireSome (admitActualImage? actual)
    "valid retained settlement evidence was rejected by Actual admission"

  expect (image.settlement.commitments.length == 1)
    "Actual image did not retain one admitted settlement commitment"
  expect (image.settlement.correspondences.length == 1)
    "Actual image did not retain one admitted direct correspondence"

  let outstanding ← requireSome
    (image.settlement.outstanding? ⟨"card-commitment"⟩)
    "admitted Actual settlement image lost the commitment"
  expect (outstanding.quanta == 0)
    s!"expected zero outstanding quantity, got {outstanding.quanta}"

private def malformedSettlementFailsWholeActualGeneration : IO Unit := do
  let actual ← requireSome actualFixture?
    "D2 malformed fixture construction failed"
  let badCorrespondence : SettlementEffectCorrespondence := {
    id := ⟨"bad-correspondence"⟩
    target := ⟨"card-commitment"⟩
    event := paymentEventId
    effect := ⟨"missing-physical-effect"⟩
    quantity := Quantity.ofQuanta 4700
  }
  let malformed : ActualEvidence := {
    actual with
    settlements := {
      actual.settlements with
      correspondences := [badCorrespondence]
    }
  }

  expect (admitActualImage? malformed).isNone
    "Actual admission accepted settlement evidence with a missing physical Effect"

private def emptySettlementRemainsAdmissible : IO Unit := do
  let actual ← requireSome actualFixture?
    "D2 empty-settlement fixture construction failed"
  let withoutSettlement : ActualEvidence := {
    actual with
    settlements := SettlementEvidence.empty
  }
  let image ← requireSome (admitActualImage? withoutSettlement)
    "empty retained settlement evidence changed existing Actual admission"

  expect image.settlement.commitments.isEmpty
    "empty settlement evidence produced admitted commitments"
  expect image.settlement.correspondences.isEmpty
    "empty settlement evidence produced admitted correspondences"
  expect image.settlement.netting.isEmpty
    "empty settlement evidence produced admitted netting contexts"

def runAll : IO Unit := do
  retainedSettlementProjectsInsideActualImage
  malformedSettlementFailsWholeActualGeneration
  emptySettlementRemainsAdmissible
  IO.println "Settlement D2 Actual-image admission qualification succeeded."

end Loam.Tests.ActualSettlementAdmission

def main : IO Unit :=
  Loam.Tests.ActualSettlementAdmission.runAll
