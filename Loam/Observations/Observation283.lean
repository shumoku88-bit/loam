import Loam.Core.EventMemory
import Loam.Observations.Observation282

namespace Loam.Observation283

open Loam.Core

set_option autoImplicit false

/-!
# Observation 283 — fee-bearing cross-Measure exchange pressure

Observation 282 qualified the smallest no-fee specimen:

    cash-jpy  -15000 jpy
    cash-usd     +100 usd
      + ExchangeEvidence(EventId)

That candidate deliberately named only the Event because the selected specimen
contained exactly the two unlike quantities being exchanged.

This observation adds one independently observable fee while preserving one
external occurrence:

    cash-jpy  -15100 jpy
    fee          +100 jpy
    cash-usd     +100 usd

The question is whether the event-level exchange claim from Observation 282 is
still sufficient, or whether fee-bearing exchange forces finer evidence.

The test also compares a tempting workaround: split the source occurrence into a
no-fee exchange Event plus an ordinary fee Event. That decomposition preserves
the selected quantity projection, but it does not preserve occurrence identity.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def dollar : MeasureId := ⟨"usd"⟩

private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩
private def feeLocus : LocusId := ⟨"exchange-fee"⟩

private def providerEventId : EventId := ⟨"provider-exchange-with-fee"⟩
private def feeKey : EffectKey := ⟨"fee-effect"⟩

/--
One provider-observed occurrence.

Only the fee Effect receives stable local identity in this bounded observation.
The physical Core still does not infer that the Locus is an expense or that the
Effect is a fee.
-/
private def providerEvent : Event := {
  id := providerEventId
  effects := [
    Effect.ofAnonymousQuantity cashJpy yen (Quantity.ofQuanta (-15100)),
    Effect.ofQuantity feeKey feeLocus yen (Quantity.ofQuanta 100),
    Effect.ofAnonymousQuantity cashUsd dollar (Quantity.ofQuanta 100)
  ]
  keyNodup := by
    simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def providerMemory : EventMemory := {
  events := [providerEvent]
  idNodup := by simp
}

/-- The neutral Core retains all three exact physical quantities directly. -/
theorem core_retains_fee_bearing_exchange_facts :
    providerEvent.quantityAt cashJpy yen = Quantity.ofQuanta (-15100) ∧
    providerEvent.quantityAt feeLocus yen = Quantity.ofQuanta 100 ∧
    providerEvent.quantityAt cashUsd dollar = Quantity.ofQuanta 100 := by
  native_decide

/--
The event-level candidate from Observation 282 is intentionally too narrow for
this specimen: it recognizes exactly two unlike Effects and therefore refuses
the three-Effect fee-bearing occurrence.
-/
private def providerExchangeEvidence : Loam.Observation282.ExchangeEvidence := {
  event := providerEventId
}

theorem observation282_event_level_exchange_claim_is_not_fee_complete :
    Loam.Observation282.exchangeEvidenceAdmitted?
      providerMemory providerExchangeEvidence = false := by
  native_decide

/-!
## Tempting decomposition

A caller can make today's qualified pieces fit by inventing two Events:

    split-exchange
      cash-jpy  -15000 jpy
      cash-usd     +100 usd

    split-fee
      cash-jpy    -100 jpy
      fee         +100 jpy

This is arithmetically convenient, but the provider supplied one occurrence.
The next theorems make the trade-off explicit.
-/

private def splitExchangeId : EventId := ⟨"split-exchange"⟩
private def splitFeeId : EventId := ⟨"split-fee"⟩

private def splitExchangeEvent : Event := {
  id := splitExchangeId
  effects := [
    Effect.ofAnonymousQuantity cashJpy yen (Quantity.ofQuanta (-15000)),
    Effect.ofAnonymousQuantity cashUsd dollar (Quantity.ofQuanta 100)
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def splitFeeEvent : Event := {
  id := splitFeeId
  effects := [
    Effect.ofAnonymousQuantity cashJpy yen (Quantity.ofQuanta (-100)),
    Effect.ofAnonymousQuantity feeLocus yen (Quantity.ofQuanta 100)
  ]
  keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
}

private def splitMemory : EventMemory := {
  events := [splitExchangeEvent, splitFeeEvent]
  idNodup := by
    simp [splitExchangeEvent, splitFeeEvent, splitExchangeId, splitFeeId]
}

private def splitExchangeMemory : EventMemory := {
  events := [splitExchangeEvent]
  idNodup := by simp
}

private def splitExchangeEvidence : Loam.Observation282.ExchangeEvidence := {
  event := splitExchangeId
}

/-- The old no-fee exchange candidate accepts the manufactured exchange half. -/
theorem observation282_candidate_accepts_split_exchange_half :
    Loam.Observation282.exchangeEvidenceAdmitted?
      splitExchangeMemory splitExchangeEvidence = true := by
  native_decide

/--
The one-Event source observation and the two-Event decomposition have identical
selected recorded quantities.
-/
theorem split_preserves_selected_quantity_projection :
    EventMemory.quantityAtRecorded providerMemory cashJpy yen =
      EventMemory.quantityAtRecorded splitMemory cashJpy yen ∧
    EventMemory.quantityAtRecorded providerMemory feeLocus yen =
      EventMemory.quantityAtRecorded splitMemory feeLocus yen ∧
    EventMemory.quantityAtRecorded providerMemory cashUsd dollar =
      EventMemory.quantityAtRecorded splitMemory cashUsd dollar := by
  native_decide

/--
But the decomposition does not preserve occurrence identity.

This matters because Event identity is observable to correction, provenance and
later evidence. Equal quantity projections therefore do not justify replacing
one observed occurrence with two invented occurrences.
-/
theorem split_does_not_preserve_provider_occurrence_identity :
    (providerMemory.findById? providerEventId).isSome = true ∧
    (splitMemory.findById? providerEventId).isNone = true ∧
    providerMemory.events.length = 1 ∧
    splitMemory.events.length = 2 := by
  native_decide

/-!
## Minimal additive pressure

The physical event alone still does not say which positive JPY Effect is the
fee. A small observation-local evidence family can state that meaning without
turning Locus names, signs or Measures into fee semantics.

This is not a production proposal. It tests only whether finer evidence can
preserve the original Event instead of manufacturing a split.
-/

/-- Observation-local claim that one retained Effect is the fee-bearing Effect. -/
structure FeeEvidence where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

/-- A fee claim is structurally admissible only when its named Effect exists. -/
def feeEvidenceAdmitted?
    (events : EventMemory)
    (evidence : FeeEvidence) : Bool :=
  match events.findById? evidence.event with
  | none => false
  | some event =>
      event.effects.any fun effect =>
        decide (effect.key = some evidence.effect)

/-- Selected query: is there admitted fee evidence for this Event? -/
def feeKnown
    (events : EventMemory)
    (evidence : List FeeEvidence)
    (event : EventId) : Bool :=
  evidence.any fun item =>
    decide (item.event = event) && feeEvidenceAdmitted? events item

private def providerFeeEvidence : FeeEvidence := {
  event := providerEventId
  effect := feeKey
}

/--
The complete physical Event can remain fixed while the fee answer changes.

Therefore fee meaning is not determined by Event geometry, Measure identity,
quantity sign, or the event-level exchange claim alone.
-/
theorem same_event_different_fee_evidence_changes_fee_answer :
    feeKnown providerMemory [] providerEventId = false ∧
    feeKnown providerMemory [providerFeeEvidence] providerEventId = true := by
  native_decide

/-!
## Finding

The fee-bearing specimen breaks the Observation-282 candidate in a useful way.

What survives:

- neutral Core can retain the exact JPY outflow, JPY fee Effect and USD inflow;
- unlike Measures still must not be arithmetically cancelled;
- valuation/rate authority still need not enter Event Core.

What fails:

- `ExchangeEvidence(EventId)` plus an exactly-two-Effect shape is not sufficient
  for a fee-bearing exchange;
- splitting one externally observed occurrence into exchange + fee Events can
  preserve selected balances while destroying occurrence identity.

The bounded pressure favors keeping one observed Event and adding independently
qualified finer evidence when the semantics truly require it. In particular, a
future exchange publisher may need to be an independent reason to retain stable
Effect identity, rather than relying on the ordinary Movement canonicalization
rule that currently keeps keys only when another relation earns them.

Not earned here:

- a production `FeeEvidence` type or wire row;
- a final Exchange evidence schema;
- exchange-rate, market-price, acquisition-basis, or tax semantics;
- multi-fee, fee-in-destination-currency, rebate, or net-settlement policy;
- correction and reversal laws for fee-bearing exchange.

Those remain separate falsification targets.
-/

end Loam.Observation283
