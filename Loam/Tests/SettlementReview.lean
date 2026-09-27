import Loam.SettlementReview
import Loam.Persistence.NormalizedActualAdmission

namespace Loam.Tests.SettlementReview

open Loam
open Loam.Core
open Loam.Application
open Loam.Persistence

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private def usd : MeasureId := ⟨"usd"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def sourceEventId : EventId := ⟨"review-source"⟩
private def sourceEffectKey : EffectKey := ⟨"review-source-usd"⟩
private def directEventId : EventId := ⟨"review-direct"⟩
private def directEffectKey : EffectKey := ⟨"review-direct-jpy"⟩
private def netEventId : EventId := ⟨"review-net"⟩
private def netEffectKey : EffectKey := ⟨"review-net-jpy"⟩
private def correctionEventId : EventId := ⟨"review-correction"⟩
private def correctionEffectKey : EffectKey := ⟨"review-correction-jpy"⟩

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

private def fixture? : Option ActualEvidence := do
  let source ← balancedEvent?
    sourceEventId
    sourceEffectKey
    ⟨"review-source-counter"⟩
    ⟨"review-source-locus"⟩
    ⟨"review-source-counter-locus"⟩
    usd
    1
  let direct ← balancedEvent?
    directEventId
    directEffectKey
    ⟨"review-direct-counter"⟩
    ⟨"review-bank"⟩
    ⟨"review-direct-counter-locus"⟩
    yen
    (-400)
  let net ← balancedEvent?
    netEventId
    netEffectKey
    ⟨"review-net-counter"⟩
    ⟨"review-bank"⟩
    ⟨"review-net-counter-locus"⟩
    yen
    (-300)
  let correction ← balancedEvent?
    correctionEventId
    correctionEffectKey
    ⟨"review-correction-counter"⟩
    ⟨"review-bank"⟩
    ⟨"review-correction-counter-locus"⟩
    yen
    (-600)

  let events ← EventMemory.ofEvents? [source, direct, net, correction]
  let validity ← ActualValidityHistory.ofParts? [
    .base sourceEventId "2026-09-01",
    .base directEventId "2026-09-02",
    .base netEventId "2026-09-03",
    .base correctionEventId "2026-09-04"
  ] []

  let settlements : SettlementEvidence := {
    commitments := [
      {
        id := ⟨"review-mixed-out"⟩
        sourceEvent := sourceEventId
        sourceEffect := sourceEffectKey
        debtor := .household
        creditor := .external ⟨"review-broker"⟩
        measure := yen
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"review-mixed-in"⟩
        sourceEvent := sourceEventId
        sourceEffect := sourceEffectKey
        debtor := .external ⟨"review-broker"⟩
        creditor := .household
        measure := yen
        quantity := Quantity.ofQuanta 300
      },
      {
        id := ⟨"review-corrected"⟩
        sourceEvent := sourceEventId
        sourceEffect := sourceEffectKey
        debtor := .household
        creditor := .external ⟨"review-broker"⟩
        measure := yen
        quantity := Quantity.ofQuanta 1000
      },
      {
        id := ⟨"review-zero-out"⟩
        sourceEvent := sourceEventId
        sourceEffect := sourceEffectKey
        debtor := .household
        creditor := .external ⟨"review-broker"⟩
        measure := yen
        quantity := Quantity.ofQuanta 500
      },
      {
        id := ⟨"review-zero-in"⟩
        sourceEvent := sourceEventId
        sourceEffect := sourceEffectKey
        debtor := .external ⟨"review-broker"⟩
        creditor := .household
        measure := yen
        quantity := Quantity.ofQuanta 500
      }
    ]
    correspondences := [
      {
        id := ⟨"review-mixed-direct"⟩
        target := ⟨"review-mixed-out"⟩
        event := directEventId
        effect := directEffectKey
        quantity := Quantity.ofQuanta 400
      },
      {
        id := ⟨"review-correction-old"⟩
        target := ⟨"review-corrected"⟩
        event := ⟨"review-missing-event"⟩
        effect := ⟨"review-missing-effect"⟩
        quantity := Quantity.ofQuanta 700
      },
      {
        id := ⟨"review-correction-new"⟩
        target := ⟨"review-corrected"⟩
        event := correctionEventId
        effect := correctionEffectKey
        quantity := Quantity.ofQuanta 600
      }
    ]
    correspondenceRevisions := [{
      target := ⟨"review-correction-old"⟩
      replacement := ⟨"review-correction-new"⟩
    }]
    nettingContexts := [
      {
        id := ⟨"review-mixed-context"⟩
        measure := yen
        outcome := .physical netEventId netEffectKey
      },
      {
        id := ⟨"review-zero-context"⟩
        measure := yen
        outcome := .zero
      }
    ]
    nettingMembers := [
      {
        id := ⟨"review-mixed-member-out"⟩
        context := ⟨"review-mixed-context"⟩
        target := ⟨"review-mixed-out"⟩
        quantity := Quantity.ofQuanta 600
      },
      {
        id := ⟨"review-mixed-member-in"⟩
        context := ⟨"review-mixed-context"⟩
        target := ⟨"review-mixed-in"⟩
        quantity := Quantity.ofQuanta 300
      },
      {
        id := ⟨"review-zero-member-out"⟩
        context := ⟨"review-zero-context"⟩
        target := ⟨"review-zero-out"⟩
        quantity := Quantity.ofQuanta 500
      },
      {
        id := ⟨"review-zero-member-in"⟩
        context := ⟨"review-zero-context"⟩
        target := ⟨"review-zero-in"⟩
        quantity := Quantity.ofQuanta 500
      }
    ]
    nettingMemberRevisions := []
  }

  some {
    ActualEvidence.empty with
    events := events
    validity := validity
    settlements := settlements
  }

private def qualifiedImage : IO Loam.ActualAuthority.Image := do
  let evidence ← requireSome fixture? "settlement review fixture construction failed"
  requireSome (admitActualImage? evidence)
    "settlement review fixture failed canonical Actual admission"

private def mixedModeSummary : IO Unit := do
  let image ← qualifiedImage
  let snapshot := Loam.SettlementReview.projectImage image
  let row ← requireSome
    (snapshot.find? ⟨"review-mixed-out"⟩)
    "mixed commitment missing from review"

  expect (row.measure == yen)
    "mixed commitment review changed settlement Measure"
  expect (row.committed.quanta == 1000)
    "mixed commitment amount changed"
  expect (row.settled.quanta == 1000)
    "mixed settled total did not compose direct + netting"
  expect (row.outstanding.quanta == 0)
    "mixed commitment should be fully settled"
  expect (row.direct.length == 1)
    "mixed commitment lost direct provenance"
  expect (row.direct.head?.map (·.quantity.quanta) == some 400)
    "mixed direct allocation should be 400"
  expect (row.netting.length == 1)
    "mixed commitment lost netting provenance"
  expect (row.netting.head?.map (·.quantity.quanta) == some 600)
    "mixed netting allocation should be 600"

  match row.netting.head? with
  | some allocation =>
      match allocation.outcome with
      | NetSettlementOutcome.physical event effect =>
          expect (event == netEventId && effect == netEffectKey)
            "mixed netting review lost physical outcome anchor"
      | NetSettlementOutcome.zero =>
          throw <| IO.userError "mixed netting review exposed zero outcome"
  | none =>
      throw <| IO.userError "mixed netting review did not expose netting allocation"

private def correctionUsesCurrentFrontierOnly : IO Unit := do
  let image ← qualifiedImage
  let snapshot := Loam.SettlementReview.projectImage image
  let row ← requireSome
    (snapshot.find? ⟨"review-corrected"⟩)
    "corrected commitment missing from review"

  expect (row.settled.quanta == 600)
    "review re-counted superseded correspondence quantity"
  expect (row.outstanding.quanta == 400)
    "corrected commitment outstanding should be 400"
  expect (row.direct.length == 1)
    "review exposed superseded direct correspondence"
  expect (row.direct.head?.map (·.correspondence.token) ==
    some "review-correction-new")
    "review did not expose replacement correspondence identity"

private def zeroNetExplainsWithoutPhysicalEvent : IO Unit := do
  let image ← qualifiedImage
  let snapshot := Loam.SettlementReview.projectImage image
  let outgoing ← requireSome
    (snapshot.find? ⟨"review-zero-out"⟩)
    "zero-net outgoing commitment missing from review"

  expect (outgoing.settled.quanta == 500)
    "zero-net outgoing settled quantity changed"
  expect (outgoing.outstanding.quanta == 0)
    "zero-net outgoing should be fully settled"
  expect outgoing.direct.isEmpty
    "zero-net review invented a direct physical allocation"
  expect (outgoing.netting.length == 1)
    "zero-net review lost netting provenance"
  match outgoing.netting.head? with
  | some allocation =>
      match allocation.outcome with
      | NetSettlementOutcome.zero => pure ()
      | NetSettlementOutcome.physical _ _ =>
          throw <| IO.userError "zero-net review invented a physical outcome"
  | none =>
      throw <| IO.userError "zero-net review lost netting allocation"

private def openRowsUseDerivedOutstanding : IO Unit := do
  let image ← qualifiedImage
  let snapshot := Loam.SettlementReview.projectImage image
  let openIds := snapshot.openRows.map (·.id.token)
  expect (openIds == ["review-corrected"])
    s!"expected only corrected commitment open, got {openIds}"

def runAll : IO Unit := do
  mixedModeSummary
  correctionUsesCurrentFrontierOnly
  zeroNetExplainsWithoutPhysicalEvent
  openRowsUseDerivedOutstanding
  IO.println "Settlement shared review qualification succeeded."

end Loam.Tests.SettlementReview

def main : IO Unit :=
  Loam.Tests.SettlementReview.runAll
