import Loam.ActualEvidence
import Loam.Application.ExchangeEvidenceFrontier
import Loam.MultimeasureSpendReview
import Loam.Persistence.NormalizedActualAdmission

namespace Loam.Observation345

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 345 — security acquisition exposes ExchangeEvidence coupling

The travel work earned production `ExchangeEvidence` as a narrow additive
qualifier for one cross-Measure Event. The Core evidence itself is deliberately
currency-neutral: selected source and destination Effects only need distinct
Measures and opposite direction.

Investment accounting now supplies an independent pressure.

Selected specimen:

    buy three shares for 1,000 JPY

      bank        -1000 jpy
      broker         +3 acme-share

This is physically the same two-Measure sign shape as a currency exchange, but
the household question is different. The acquired security may later need
acquisition basis, disposal provenance and realised-gain semantics.

This observation asks two questions:

1. can current normalized Actual admit the security purchase mechanically by
   reusing `ExchangeEvidence`?
2. if it can, does that reuse also make the investment Event appear as an
   Exchange occurrence to the travel-oriented multicurrency spending lens?

A positive answer to both would show that the current evidence family combines
two responsibilities:

    cross-Measure admission witness
    +
    semantic Exchange classification

That coupling matters once a second domain needs the same physical admission
shape without the same report meaning.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def bank : LocusId := ⟨"bank"⟩
private def broker : LocusId := ⟨"broker"⟩

private def purchaseId : EventId := ⟨"security-purchase"⟩
private def cashKey : EffectKey := ⟨"purchase-cash"⟩
private def securityKey : EffectKey := ⟨"purchase-security"⟩

private def purchase? : Option Event :=
  Event.ofEffects? purchaseId [
    Effect.ofQuantity cashKey bank yen (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity securityKey broker shares (Quantity.ofQuanta 3)
  ]

private def exchangeClaim : ExchangeEvidence := {
  event := purchaseId
  source := cashKey
  destination := securityKey
}

private def eventMemory? : Option EventMemory := do
  let event ← purchase?
  EventMemory.ofEvents? [event]

private def exchangeMemory? : Option ExchangeEvidenceMemory :=
  ExchangeEvidenceMemory.ofEntries? [exchangeClaim]

private def validity : ActualValidityHistory String := {
  facts := [.base purchaseId "2026-09-26"]
  factRefNodup := by
    simp [ActualValidityFact.ref, purchaseId]
  corrections := []
  correctionIdNodup := by simp
}

private def rawEvidenceWithoutExchange? : Option Loam.ActualEvidence := do
  let events ← eventMemory?
  pure {
    Loam.ActualEvidence.empty with
    events := events
    validity := validity
  }

private def rawEvidenceWithExchange? : Option Loam.ActualEvidence := do
  let events ← eventMemory?
  let exchanges ← exchangeMemory?
  pure {
    Loam.ActualEvidence.empty with
    events := events
    validity := validity
    exchanges := exchanges
  }

private def persistenceWithoutExchangeAdmits : Bool :=
  match rawEvidenceWithoutExchange? with
  | none => false
  | some evidence =>
      (Loam.Persistence.admitActualEvidence? evidence).isSome

private def persistenceWithExchangeAdmits : Bool :=
  match rawEvidenceWithExchange? with
  | none => false
  | some evidence =>
      (Loam.Persistence.admitActualEvidence? evidence).isSome

/--
Without a cross-Measure qualifier, the stock purchase fails ordinary
per-Measure closure exactly as intended.
-/
theorem security_purchase_is_not_ordinary_balanced_movement :
    persistenceWithoutExchangeAdmits = false := by
  native_decide

/--
Current `ExchangeEvidence` is mechanically broad enough to admit the same
security purchase even though neither Measure is required to be a currency.
-/
theorem exchange_evidence_can_mechanically_admit_security_purchase :
    persistenceWithExchangeAdmits = true := by
  native_decide

private def roles? : Option AccountingRoleMap :=
  AccountingRoleMap.ofAssignments? [
    { locus := bank, role := .asset },
    { locus := broker, role := .asset }
  ]

private def reportExchangeEvents? : Option (List EventId) := do
  let event ← purchase?
  let exchanges ← exchangeMemory?
  let roles ← roles?
  let snapshot ←
    match Loam.MultimeasureSpendReview.project
        {
          records := [{
            event := event
            date := some "2026-09-26"
            description := "buy ACME shares"
            replacement := none
          }]
          roles := roles
          originalAmounts := []
          exchanges := exchanges
        }
        "2026-09-01"
        "2026-10-01" with
    | .ok snapshot => some snapshot
    | .error _ => none
  pure (snapshot.exchanges.map (·.event))

/--
The same evidence that opens normalized cross-Measure admission also classifies
the stock purchase as an Exchange occurrence in the current travel-oriented
report.

The report has no currency registry and therefore cannot distinguish a
JPY/USD exchange from JPY/security acquisition by Measure identity alone.
-/
theorem exchange_reuse_leaks_security_purchase_into_exchange_report :
    reportExchangeEvents? = some [purchaseId] := by
  native_decide

/-!
## Finding

The neutral Core is not the blocker. It retains the exact physical facts:

    -1000 jpy
       +3 acme-share

without requiring a Currency enum or a security-specific Event type.

The current production admission boundary is narrower:

    ordinary Event
        -> every Measure closes independently

    explicitly qualified Exchange Event
        -> selected two-Measure exception

A security acquisition therefore has no honest production admission path today
unless it reuses `ExchangeEvidence`.

That reuse is mechanically possible, but Observation 345 shows the cost: the
same evidence is also the semantic Exchange classification consumed by
`MultimeasureSpendReview`. A stock purchase then appears as an Exchange
occurrence.

This is the second independent pressure on the same mechanical cross-Measure
shape. It earns a design question that did not exist when only travel exchange
needed the exception:

    shared cross-Measure admission mechanics
        !=
    domain semantic authority

The next candidate should therefore preserve two rules simultaneously:

- do not weaken normalized Actual into a generic arbitrary mixed-Measure escape
  hatch;
- do not force security acquisition to pretend to be currency Exchange merely
  to pass persistence admission.

A plausible candidate is a distinct additive security-trade/acquisition evidence
family that reuses the same *mechanical* two-Measure validation helper while
remaining semantically separate from `ExchangeEvidence`.

This does not yet earn a production schema or a generic transaction-type enum.

Not earned here:

- production SecurityTradeEvidence;
- production acquisition basis;
- disposal provenance;
- LotId;
- FIFO / average-cost / specific-identification policy;
- market-price authority;
- tax gain calculation;
- a generic user-writable cross-Measure bypass.
-/

end Loam.Observation345
