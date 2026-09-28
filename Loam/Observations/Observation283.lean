import Loam.Application.ExchangeEvidenceFrontier

namespace Loam.Observation283

open Loam.Core

set_option autoImplicit false

/-!
# Observation 283 — fee meaning remains independent of exchange evidence

Production now admits fee-bearing cross-Measure occurrences directly:

    selected source Effect       jpy  negative
    additional Effect           jpy  positive
    selected destination Effect usd  positive
      + effect-selected ExchangeEvidence

The additional same-Measure Effect can therefore stay inside the one observed
Event. No split Event is required merely to satisfy exchange admission.

The remaining question is narrower:

> Does production ExchangeEvidence determine that the additional Effect is a fee?

It deliberately does not. This witness keeps the Event and production exchange
claim fixed while varying only explicit fee evidence. The resulting fee answer
changes, so fee meaning remains independently retained information if a future
household question ever requires it.
-/

private def jpy : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩

private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩
private def feeLocus : LocusId := ⟨"exchange-fee"⟩

private def sourceKey : EffectKey := ⟨"jpy-source"⟩
private def feeKey : EffectKey := ⟨"fee-effect"⟩
private def destinationKey : EffectKey := ⟨"usd-destination"⟩
private def providerEventId : EventId := ⟨"provider-exchange-with-fee"⟩

private def providerEvent : Event := {
  id := providerEventId
  effects := [
    Effect.ofQuantity sourceKey cashJpy jpy (Quantity.ofQuanta (-15100)),
    Effect.ofQuantity feeKey feeLocus jpy (Quantity.ofQuanta 100),
    Effect.ofQuantity destinationKey cashUsd usd (Quantity.ofQuanta 100)
  ]
  keyNodup := by native_decide
}

private def providerMemory : EventMemory := {
  events := [providerEvent]
  idNodup := by native_decide
}

private def noCorrections : EventCorrectionMemory := {
  corrections := []
  idNodup := by simp
}

private def providerExchange : ExchangeEvidence := {
  event := providerEventId
  source := sourceKey
  destination := destinationKey
}

/--
The current production boundary accepts the complete fee-bearing occurrence
without assigning semantic meaning to the additional JPY Effect.
-/
theorem production_exchange_admits_fee_bearing_occurrence :
    Loam.Application.exchangeEvidenceAdmitted?
      providerMemory noCorrections providerExchange = true := by
  native_decide

/-- Observation-local candidate for a future explicit fee claim. -/
structure FeeEvidence where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def feeEvidenceAdmitted?
    (events : EventMemory)
    (evidence : FeeEvidence) : Bool :=
  match events.findById? evidence.event with
  | none => false
  | some event =>
      event.effects.any fun effect =>
        decide (effect.key = some evidence.effect)

private def feeKnown
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
The same admitted Event and the same production ExchangeEvidence support two
different fee answers depending only on whether explicit fee evidence exists.
-/
theorem same_exchange_different_fee_evidence_changes_fee_answer :
    feeKnown providerMemory [] providerEventId = false ∧
    feeKnown providerMemory [providerFeeEvidence] providerEventId = true := by
  native_decide

/-!
## Finding

Production has already absorbed the earlier exchange-shape pressure:

    one Event
    + exact selected source/destination Effects
    + additional same-Measure Effects
    + ExchangeEvidence
        -> qualified cross-Measure exchange occurrence

What remains unresolved is semantic attribution of an additional Effect:

    same Event
    + same ExchangeEvidence
    + no fee evidence
        !=
    same Event
    + same ExchangeEvidence
    + explicit fee evidence

Therefore fee meaning is not derivable from Locus spelling, sign, Measure, or the
production exchange claim itself.

This observation does not earn a production FeeEvidence family. It preserves the
information distinction until a concrete household query needs fee semantics.
Rate, valuation, acquisition basis, tax basis, rebate policy, and multi-fee
semantics remain separate questions.
-/

end Loam.Observation283
