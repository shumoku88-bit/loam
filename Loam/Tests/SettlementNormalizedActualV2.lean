import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Tests.SettlementNormalizedActualV2

open Loam
open Loam.Core
open Loam.Application
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def usd : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def sourceLocus : LocusId := ⟨"source"⟩
private def sourceCounter : LocusId := ⟨"source-counter"⟩
private def bank : LocusId := ⟨"bank"⟩
private def paymentCounter : LocusId := ⟨"payment-counter"⟩

private def issuer : ExternalPartyId := ⟨"issuer"⟩
private def broker : ExternalPartyId := ⟨"broker"⟩

private def balancedEvent?
    (id : String)
    (keyA : String)
    (locusA : LocusId)
    (measure : MeasureId)
    (amount : Int)
    (keyB : String)
    (locusB : LocusId) : Option Event :=
  Event.ofEffects? ⟨id⟩ [
    Effect.ofQuantity ⟨keyA⟩ locusA measure (Quantity.ofQuanta amount),
    Effect.ofQuantity ⟨keyB⟩ locusB measure (Quantity.ofQuanta (-amount))
  ]

private def fixture? : Option ActualEvidence := do
  let cardSource ← balancedEvent?
    "v2-card-source" "v2-card-usd" sourceLocus usd 30
    "v2-card-usd-counter" sourceCounter
  let cardPayment ← balancedEvent?
    "v2-card-payment" "v2-card-jpy" bank yen (-4700)
    "v2-card-jpy-counter" paymentCounter

  let zeroSource ← balancedEvent?
    "v2-zero-source" "v2-zero-usd" sourceLocus usd 1
    "v2-zero-usd-counter" sourceCounter

  let corrSource ← balancedEvent?
    "v2-corr-source" "v2-corr-usd" sourceLocus usd 1
    "v2-corr-usd-counter" sourceCounter
  let corrPayment ← balancedEvent?
    "v2-corr-payment" "v2-corr-jpy" bank yen (-600)
    "v2-corr-jpy-counter" paymentCounter

  let memberSource ← balancedEvent?
    "v2-member-source" "v2-member-usd" sourceLocus usd 1
    "v2-member-usd-counter" sourceCounter
  let memberPayment ← balancedEvent?
    "v2-member-payment" "v2-member-jpy" bank yen (-300)
    "v2-member-jpy-counter" paymentCounter

  let events ← EventMemory.ofEvents? [
    cardSource, cardPayment,
    zeroSource,
    corrSource, corrPayment,
    memberSource, memberPayment
  ]

  let validity ← ActualValidityHistory.ofParts? [
    .base ⟨"v2-card-source"⟩ "2026-09-01",
    .base ⟨"v2-card-payment"⟩ "2026-09-02",
    .base ⟨"v2-zero-source"⟩ "2026-09-03",
    .base ⟨"v2-corr-source"⟩ "2026-09-04",
    .base ⟨"v2-corr-payment"⟩ "2026-09-05",
    .base ⟨"v2-member-source"⟩ "2026-09-06",
    .base ⟨"v2-member-payment"⟩ "2026-09-07"
  ] []

  let settlements : SettlementEvidence := {
    commitments := [
      {
        id := ⟨"v2-card-commitment"⟩
        sourceEvent := ⟨"v2-card-source"⟩
        sourceEffect := ⟨"v2-card-usd"⟩
        debtor := .household
        creditor := .external issuer
        measure := yen
        quantity := Quantity.ofQuanta 4700
      },
      {
        id := ⟨"v2-zero-out"⟩
        sourceEvent := ⟨"v2-zero-source"⟩
        sourceEffect := ⟨"v2-zero-usd"⟩
        debtor := .household
        creditor := .external broker
        measure := yen
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-zero-in"⟩
        sourceEvent := ⟨"v2-zero-source"⟩
        sourceEffect := ⟨"v2-zero-usd"⟩
        debtor := .external broker
        creditor := .household
        measure := yen
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-corr-target"⟩
        sourceEvent := ⟨"v2-corr-source"⟩
        sourceEffect := ⟨"v2-corr-usd"⟩
        debtor := .household
        creditor := .external broker
        measure := yen
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-member-out"⟩
        sourceEvent := ⟨"v2-member-source"⟩
        sourceEffect := ⟨"v2-member-usd"⟩
        debtor := .household
        creditor := .external broker
        measure := yen
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-member-in"⟩
        sourceEvent := ⟨"v2-member-source"⟩
        sourceEffect := ⟨"v2-member-usd"⟩
        debtor := .external broker
        creditor := .household
        measure := yen
        quantity := Quantity.ofQuanta 700
      }
    ]
    correspondences := [
      {
        id := ⟨"v2-card-row"⟩
        target := ⟨"v2-card-commitment"⟩
        event := ⟨"v2-card-payment"⟩
        effect := ⟨"v2-card-jpy"⟩
        quantity := Quantity.ofQuanta 4700
      },
      {
        id := ⟨"v2-corr-old"⟩
        target := ⟨"v2-corr-target"⟩
        event := ⟨"v2-missing-event"⟩
        effect := ⟨"v2-missing-effect"⟩
        quantity := Quantity.ofQuanta 700
      },
      {
        id := ⟨"v2-corr-new"⟩
        target := ⟨"v2-corr-target"⟩
        event := ⟨"v2-corr-payment"⟩
        effect := ⟨"v2-corr-jpy"⟩
        quantity := Quantity.ofQuanta 600
      }
    ]
    correspondenceRevisions := [
      {
        target := ⟨"v2-corr-old"⟩
        replacement := ⟨"v2-corr-new"⟩
      }
    ]
    nettingContexts := [
      {
        id := ⟨"v2-zero-context"⟩
        measure := yen
        outcome := .zero
      },
      {
        id := ⟨"v2-member-context"⟩
        measure := yen
        outcome := .physical ⟨"v2-member-payment"⟩ ⟨"v2-member-jpy"⟩
      }
    ]
    nettingMembers := [
      {
        id := ⟨"v2-zero-member-out"⟩
        context := ⟨"v2-zero-context"⟩
        target := ⟨"v2-zero-out"⟩
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-zero-member-in"⟩
        context := ⟨"v2-zero-context"⟩
        target := ⟨"v2-zero-in"⟩
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-member-old"⟩
        context := ⟨"v2-member-context"⟩
        target := ⟨"v2-member-out"⟩
        quantity := Quantity.ofQuanta 900
      },
      {
        id := ⟨"v2-member-new"⟩
        context := ⟨"v2-member-context"⟩
        target := ⟨"v2-member-out"⟩
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"v2-member-in-row"⟩
        context := ⟨"v2-member-context"⟩
        target := ⟨"v2-member-in"⟩
        quantity := Quantity.ofQuanta 700
      }
    ]
    nettingMemberRevisions := [
      {
        target := ⟨"v2-member-old"⟩
        replacement := ⟨"v2-member-new"⟩
      }
    ]
  }

  some {
    ActualEvidence.empty with
    events := events
    validity := validity
    settlements := settlements
  }

private def v3Fixture? : Option ActualEvidence := do
  let base ← fixture?
  let corrected : SettlementCommitment := {
    id := ⟨"v3-corr-current"⟩
    sourceEvent := ⟨"v2-corr-source"⟩
    sourceEffect := ⟨"v2-corr-usd"⟩
    debtor := .household
    creditor := .external broker
    measure := yen
    quantity := Quantity.ofQuanta 900
  }
  let retractable : SettlementCommitment := {
    id := ⟨"v3-retract-target"⟩
    sourceEvent := ⟨"v2-zero-source"⟩
    sourceEffect := ⟨"v2-zero-usd"⟩
    debtor := .household
    creditor := .external broker
    measure := yen
    quantity := Quantity.ofQuanta 250
  }
  some {
    base with
    settlements := {
      base.settlements with
      commitments := base.settlements.commitments ++ [corrected, retractable]
      commitmentRevisions := [
        {
          target := ⟨"v2-corr-target"⟩
          replacement := some ⟨"v3-corr-current"⟩
        },
        {
          target := ⟨"v3-retract-target"⟩
          replacement := none
        }
      ]
    }
  }

private def v4Fixture? : Option ActualEvidence := do
  let base ← v3Fixture?
  some {
    base with
    settlements := {
      base.settlements with
      extinguishments := [
        {
          id := ⟨"v4-unknown"⟩
          target := ⟨"v2-corr-target"⟩
          quantity := Quantity.ofQuanta 100
          effectiveOn := none
        },
        {
          id := ⟨"v4-old"⟩
          target := ⟨"v2-corr-target"⟩
          quantity := Quantity.ofQuanta 80
          effectiveOn := some "2026-02-29"
        },
        {
          id := ⟨"v4-new"⟩
          target := ⟨"v2-corr-target"⟩
          quantity := Quantity.ofQuanta 50
          effectiveOn := some "2026-09-08"
        },
        {
          id := ⟨"v4-retracted"⟩
          target := ⟨"v2-corr-target"⟩
          quantity := Quantity.ofQuanta 40
          effectiveOn := none
        }
      ]
      extinguishmentRevisions := [
        {
          target := ⟨"v4-old"⟩
          replacement := some ⟨"v4-new"⟩
        },
        {
          target := ⟨"v4-retracted"⟩
          replacement := none
        }
      ]
    }
  }

private def v1RemainsV1WhenSettlementEmpty : IO Unit := do
  let actual ← requireSome fixture? "v2 fixture construction failed"
  let empty : ActualEvidence := {
    actual with
    settlements := SettlementEvidence.empty
  }
  let wire ← requireSome (encodeNormalizedActual? empty)
    "empty settlement evidence failed to encode"
  expect (wire.startsWith (normalizedActualHeaderV1 ++ "\n"))
    "empty settlement evidence did not retain the v1 header"
  expect (!wire.contains "SETTLEMENT-")
    "v1 encoding unexpectedly emitted settlement rows"
  let decoded ← requireSome (decodeNormalizedActual? wire)
    "v1 round-trip failed"
  expect decoded.settlements.commitments.isEmpty
    "v1 decode did not reconstruct empty SettlementEvidence"

private def v2RoundTripsAllBaseSettlementRows : IO Unit := do
  let actual ← requireSome fixture? "v2 fixture construction failed"
  let wire ← requireSome (encodeNormalizedActual? actual)
    "nonempty settlement evidence failed to encode"

  expect (wire.startsWith (normalizedActualHeaderV2 ++ "\n"))
    "nonempty settlement evidence did not select the v2 header"
  for rowType in [
      "SETTLEMENT-COMMITMENT\t",
      "SETTLEMENT-CORRESPONDENCE\t",
      "SETTLEMENT-CORRESPONDENCE-REVISION\t",
      "SETTLEMENT-NETTING\t",
      "SETTLEMENT-MEMBER\t",
      "SETTLEMENT-MEMBER-REVISION\t"
    ] do
    expect (wire.contains rowType)
      s!"v2 encoder omitted {rowType}"

  let decoded ← requireSome (decodeNormalizedActual? wire)
    "v2 settlement round-trip failed"

  expect (decoded.settlements.commitments.length == actual.settlements.commitments.length)
    "v2 round-trip changed commitment count"
  expect (decoded.settlements.correspondences == actual.settlements.correspondences)
    "v2 round-trip changed direct correspondence history"
  expect (decoded.settlements.correspondenceRevisions == actual.settlements.correspondenceRevisions)
    "v2 round-trip changed correspondence revisions"
  expect (decoded.settlements.nettingContexts == actual.settlements.nettingContexts)
    "v2 round-trip changed netting contexts"
  expect (decoded.settlements.nettingMembers == actual.settlements.nettingMembers)
    "v2 round-trip changed netting member history"
  expect (decoded.settlements.nettingMemberRevisions == actual.settlements.nettingMemberRevisions)
    "v2 round-trip changed netting member revisions"

  let image ← requireSome (decodeNormalizedActualImage? wire)
    "v2 admitted image decode failed"
  let corrOutstanding ← requireSome
    (image.settlement.outstanding? ⟨"v2-corr-target"⟩)
    "v2 correspondence correction target missing"
  expect (corrOutstanding.quanta == 400)
    "v2 round-trip re-admitted superseded direct correspondence"
  let memberOutstanding ← requireSome
    (image.settlement.outstanding? ⟨"v2-member-out"⟩)
    "v2 member correction target missing"
  expect (memberOutstanding.quanta == 0)
    "v2 round-trip re-admitted superseded netting member"

private def v3RoundTripsCommitmentRevisionAuthority : IO Unit := do
  let actual ← requireSome v3Fixture? "v3 fixture construction failed"
  let wire ← requireSome (encodeNormalizedActual? actual)
    "commitment revision evidence failed to encode"

  expect (wire.startsWith (normalizedActualHeaderV3 ++ "\n"))
    "commitment revision evidence did not select the v3 header"
  expect (wire.contains
      "SETTLEMENT-COMMITMENT-REVISION\tv2-corr-target\tREPLACEMENT\tv3-corr-current")
    "v3 encoder omitted positive commitment correction"
  expect (wire.contains
      "SETTLEMENT-COMMITMENT-REVISION\tv3-retract-target\tRETRACT")
    "v3 encoder omitted explicit commitment retraction"

  let decoded ← requireSome (decodeNormalizedActual? wire)
    "v3 settlement round-trip failed"
  expect (decoded.settlements.commitmentRevisions ==
      actual.settlements.commitmentRevisions)
    "v3 round-trip changed commitment revision authority"

  let image ← requireSome (decodeNormalizedActualImage? wire)
    "v3 admitted image decode failed"
  let correctedOutstanding ← requireSome
    (image.settlement.outstanding? ⟨"v3-corr-current"⟩)
    "corrected commitment missing after v3 round-trip"
  expect (correctedOutstanding.quanta == 300)
    s!"expected corrected outstanding 300, got {correctedOutstanding.quanta}"
  expect ((image.settlement.outstanding? ⟨"v2-corr-target"⟩).isNone)
    "superseded commitment remained current after v3 round-trip"
  expect ((image.settlement.outstanding? ⟨"v3-retract-target"⟩).isNone)
    "retracted commitment remained current after v3 round-trip"

private def v4RoundTripsExtinguishmentAuthority : IO Unit := do
  let actual ← requireSome v4Fixture? "v4 fixture construction failed"
  let wire ← requireSome (encodeNormalizedActual? actual)
    "extinguishment evidence failed to encode"

  expect (wire.startsWith (normalizedActualHeaderV4 ++ "\n"))
    "extinguishment evidence did not select the v4 header"
  expect (wire.contains
      "SETTLEMENT-EXTINGUISHMENT\tv4-unknown\tTARGET\tv2-corr-target\t100\tUNKNOWN")
    "v4 encoder omitted unknown-time extinguishment"
  expect (wire.contains
      "SETTLEMENT-EXTINGUISHMENT\tv4-new\tTARGET\tv2-corr-target\t50\tEFFECTIVE\t2026-09-08")
    "v4 encoder omitted effective extinguishment date"
  expect (wire.contains
      "SETTLEMENT-EXTINGUISHMENT-REVISION\tv4-old\tREPLACEMENT\tv4-new")
    "v4 encoder omitted extinguishment correction"
  expect (wire.contains
      "SETTLEMENT-EXTINGUISHMENT-REVISION\tv4-retracted\tRETRACT")
    "v4 encoder omitted extinguishment retraction"

  let decoded ← requireSome (decodeNormalizedActual? wire)
    "v4 extinguishment round-trip failed"
  expect (decoded.settlements.extinguishments ==
      actual.settlements.extinguishments)
    "v4 round-trip changed extinguishment history"
  expect (decoded.settlements.extinguishmentRevisions ==
      actual.settlements.extinguishmentRevisions)
    "v4 round-trip changed extinguishment revision authority"

  let image ← requireSome (decodeNormalizedActualImage? wire)
    "v4 admitted image decode failed"
  expect (image.settlement.extinguishedQuanta ⟨"v3-corr-current"⟩ == 150)
    "v4 did not resolve historical extinguishment targets to current commitment"
  let outstanding ← requireSome
    (image.settlement.outstanding? ⟨"v3-corr-current"⟩)
    "v4 corrected commitment missing"
  expect (outstanding.quanta == 150)
    s!"expected v4 outstanding 150, got {outstanding.quanta}"

private def v3RejectsExtinguishmentRows : IO Unit := do
  let wire :=
    normalizedActualHeaderV3 ++ "\n" ++
    "SETTLEMENT-EXTINGUISHMENT\text\tTARGET\ttarget\t10\tUNKNOWN\n"
  expect (decodeNormalizedActual? wire).isNone
    "v3 decoder accepted a v4-only extinguishment row"

private def invalidCurrentExtinguishmentDateFails : IO Unit := do
  let actual ← requireSome v3Fixture? "invalid v4 date fixture failed"
  let malformed : ActualEvidence := {
    actual with
    settlements := {
      actual.settlements with
      extinguishments := [{
        id := ⟨"v4-invalid-current"⟩
        target := ⟨"v3-corr-current"⟩
        quantity := Quantity.ofQuanta 10
        effectiveOn := some "2026-02-29"
      }]
    }
  }
  expect (encodeNormalizedActual? malformed).isNone
    "v4 encoder admitted an impossible current effective date"

private def v2RejectsCommitmentRevisionRows : IO Unit := do
  let wire :=
    normalizedActualHeaderV2 ++ "\n" ++
    "SETTLEMENT-COMMITMENT-REVISION\told\tRETRACT\n"
  expect (decodeNormalizedActual? wire).isNone
    "v2 decoder accepted a v3-only commitment revision row"

private def v1RejectsSettlementRows : IO Unit := do
  let wire :=
    normalizedActualHeaderV1 ++ "\n" ++
    "SETTLEMENT-NETTING\tv1-zero\tjpy\tZERO\n"
  expect (decodeNormalizedActual? wire).isNone
    "v1 decoder accepted a settlement row"

private def v2RejectsSettlementInsideTx : IO Unit := do
  let wire :=
    normalizedActualHeaderV2 ++ "\n" ++
    "TX\tev\t2026-09-01\tNODESC\n" ++
    "SETTLEMENT-NETTING\tinside\tjpy\tZERO\n" ++
    "ENDTX\n"
  expect (decodeNormalizedActual? wire).isNone
    "v2 decoder accepted a document-level settlement row inside TX"

private def v2RejectsTxAfterSettlementRegion : IO Unit := do
  let wire :=
    normalizedActualHeaderV2 ++ "\n" ++
    "SETTLEMENT-NETTING\tfirst\tjpy\tZERO\n" ++
    "TX\tev\t2026-09-01\tNODESC\n" ++
    "ENDTX\n"
  expect (decodeNormalizedActual? wire).isNone
    "v2 decoder reopened TX parsing after settlement region"

private def v2RejectsUnknownDocumentRow : IO Unit := do
  let wire :=
    normalizedActualHeaderV2 ++ "\n" ++
    "UNKNOWN-V2\tvalue\n"
  expect (decodeNormalizedActual? wire).isNone
    "v2 decoder accepted an unknown document-level row"

private def v2RejectsMalformedCurrentReference : IO Unit := do
  let actual ← requireSome fixture? "malformed-current fixture failed"
  let malformed : ActualEvidence := {
    actual with
    settlements := {
      actual.settlements with
      correspondences := [{
        id := ⟨"v2-current-bad"⟩
        target := ⟨"v2-card-commitment"⟩
        event := ⟨"v2-missing-current-event"⟩
        effect := ⟨"v2-missing-current-effect"⟩
        quantity := Quantity.ofQuanta 4700
      }]
      correspondenceRevisions := []
    }
  }
  expect (encodeNormalizedActual? malformed).isNone
    "v2 encoder admitted a current correspondence with missing physical provenance"

def runAll : IO Unit := do
  v1RemainsV1WhenSettlementEmpty
  v2RoundTripsAllBaseSettlementRows
  v3RoundTripsCommitmentRevisionAuthority
  v4RoundTripsExtinguishmentAuthority
  v3RejectsExtinguishmentRows
  invalidCurrentExtinguishmentDateFails
  v2RejectsCommitmentRevisionRows
  v1RejectsSettlementRows
  v2RejectsSettlementInsideTx
  v2RejectsTxAfterSettlementRegion
  v2RejectsUnknownDocumentRow
  v2RejectsMalformedCurrentReference
  IO.println "Settlement normalized Actual v1-v4 qualification succeeded."

end Loam.Tests.SettlementNormalizedActualV2

def main : IO Unit :=
  Loam.Tests.SettlementNormalizedActualV2.runAll
