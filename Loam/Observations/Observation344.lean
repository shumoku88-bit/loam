import Loam.Application.CorrectionFrontier
import Loam.Core.ActualReversal
import Loam.Observations.Observation340
import Loam.Observations.Observation342

namespace Loam.Observation344

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 344 — travel evidence has two different lifecycle shapes

Observations 340–343 selected two small travel evidence candidates:

- effect-selected ExchangeEvidence;
- Event-scoped OriginalAmountEvidence.

Before production promotion, this observation pressure-tests correction and
reversal behavior.

The selected hypothesis is deliberately asymmetric:

1. OriginalAmountEvidence describes one occurrence as a whole. If publication
   stores it against the stable correction root, a read projection can carry it
   to the current terminal Event without rewriting the evidence.

2. ExchangeEvidence selects concrete EffectKey values. A correction may replace
   those Effects with new keys, so exchange evidence cannot safely follow a
   correction root unless effect correspondence has independently been earned.

3. Reversal proves physical inversion, but it does not manufacture new
   original-amount or exchange evidence for the reversal Event.

The goal is not to add production policy here. It is to determine whether these
two evidence families may share one generic lifecycle rule.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def dollar : MeasureId := ⟨"usd"⟩

private def bank : LocusId := ⟨"bank"⟩
private def food : LocusId := ⟨"food"⟩
private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩

/-! ## Original amount across correction -/

private def purchaseRootId : EventId := ⟨"travel-purchase-root"⟩
private def purchaseReplacementId : EventId := ⟨"travel-purchase-replacement"⟩

private def purchaseRoot? : Option Event :=
  Event.ofEffects? purchaseRootId [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-4700)),
    Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 4700)
  ]

private def purchaseReplacement? : Option Event :=
  Event.ofEffects? purchaseReplacementId [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta (-4650)),
    Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 4650)
  ]

private def purchaseCorrectionWorld? :
    Option (EventMemory × EventCorrectionMemory) := do
  let root ← purchaseRoot?
  let replacement ← purchaseReplacement?
  let events ← EventMemory.ofEvents? [root, replacement]
  let corrections ← EventCorrectionMemory.ofCorrections? [{
    target := purchaseRootId
    replacement := purchaseReplacementId
  }]
  pure (events, corrections)

private def purchaseOriginal :
    Loam.Observation342.OriginalAmountEvidence := {
  event := purchaseRootId
  measure := dollar
  quantity := Quantity.ofQuanta 3000
}

structure CurrentOriginalAmount where
  event : EventId
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
Interpret retained original-amount evidence whose EventId is a stable correction
root against the current terminal Event.

This function does not rewrite retained evidence. It is only a read projection.
-/
def currentOriginalAmounts?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (memory : Loam.Observation342.OriginalAmountMemory) :
    Option (List CurrentOriginalAmount) := do
  let rooted ← correctionRootTerminalEvents? events corrections
  memory.entries.mapM fun evidence => do
    let pair ← rooted.find? fun candidate =>
      decide (candidate.1 = evidence.event)
    pure {
      event := pair.2.id
      measure := evidence.measure
      quantity := evidence.quantity
    }

private def correctedOriginalProjection? :
    Option (List CurrentOriginalAmount) := do
  let (events, corrections) ← purchaseCorrectionWorld?
  let originals ←
    Loam.Observation342.originalAmountsAgainst?
      events [purchaseOriginal]
  currentOriginalAmounts? events corrections originals

/--
An original amount anchored at the stable correction root can be presented on
the replacement Event without copying or mutating the retained evidence.
-/
theorem original_amount_can_follow_correction_root :
    correctedOriginalProjection? =
      some [{
        event := purchaseReplacementId
        measure := dollar
        quantity := Quantity.ofQuanta 3000
      }] := by
  native_decide

/-! ## Exchange evidence across correction -/

private def exchangeRootId : EventId := ⟨"exchange-root"⟩
private def exchangeReplacementId : EventId := ⟨"exchange-replacement"⟩

private def rootSource : EffectKey := ⟨"root-jpy-source"⟩
private def rootDestination : EffectKey := ⟨"root-usd-destination"⟩
private def replacementSource : EffectKey := ⟨"replacement-jpy-source"⟩
private def replacementDestination : EffectKey := ⟨"replacement-usd-destination"⟩

private def exchangeRoot? : Option Event :=
  Event.ofEffects? exchangeRootId [
    Effect.ofQuantity
      rootSource cashJpy yen (Quantity.ofQuanta (-15000)),
    Effect.ofQuantity
      rootDestination cashUsd dollar (Quantity.ofQuanta 10000)
  ]

private def exchangeReplacement? : Option Event :=
  Event.ofEffects? exchangeReplacementId [
    Effect.ofQuantity
      replacementSource cashJpy yen (Quantity.ofQuanta (-14900)),
    Effect.ofQuantity
      replacementDestination cashUsd dollar (Quantity.ofQuanta 10000)
  ]

private def exchangeCorrectionWorld? :
    Option (EventMemory × EventCorrectionMemory) := do
  let root ← exchangeRoot?
  let replacement ← exchangeReplacement?
  let events ← EventMemory.ofEvents? [root, replacement]
  let corrections ← EventCorrectionMemory.ofCorrections? [{
    target := exchangeRootId
    replacement := exchangeReplacementId
  }]
  pure (events, corrections)

private def rootExchangeEvidence :
    Loam.Observation340.ExchangeEvidence := {
  event := exchangeRootId
  source := rootSource
  destination := rootDestination
}

private def staleExchangeEvidenceOnReplacement :
    Loam.Observation340.ExchangeEvidence := {
  event := exchangeReplacementId
  source := rootSource
  destination := rootDestination
}

private def replacementExchangeEvidence :
    Loam.Observation340.ExchangeEvidence := {
  event := exchangeReplacementId
  source := replacementSource
  destination := replacementDestination
}

private def exchangeCorrectionAdmission? :
    Option (Bool × Bool × Bool) := do
  let (events, _) ← exchangeCorrectionWorld?
  pure (
    Loam.Observation340.exchangeEvidenceAdmitted?
      events rootExchangeEvidence,
    Loam.Observation340.exchangeEvidenceAdmitted?
      events staleExchangeEvidenceOnReplacement,
    Loam.Observation340.exchangeEvidenceAdmitted?
      events replacementExchangeEvidence)

/--
The retained root exchange claim remains valid for the historical root Event,
but merely changing its EventId to the correction terminal does not make the old
EffectKey anchors valid there.

Fresh effect-selected evidence for the replacement does admit.
-/
theorem exchange_evidence_requires_effect_level_readmission_after_correction :
    exchangeCorrectionAdmission? = some (true, false, true) := by
  native_decide

/-! ## Reversal does not synthesize semantic evidence -/

private def reversalPurchaseId : EventId := ⟨"travel-purchase-reversal"⟩

private def reversalPurchase? : Option Event :=
  Event.ofEffects? reversalPurchaseId [
    Effect.ofAnonymousQuantity bank yen (Quantity.ofQuanta 4700),
    Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta (-4700))
  ]

private def purchaseReversalWorld? : Option EventMemory := do
  let target ← purchaseRoot?
  let reversal ← reversalPurchase?
  EventMemory.ofEvents? [target, reversal]

private def hasOriginalAmountFor
    (memory : Loam.Observation342.OriginalAmountMemory)
    (event : EventId) : Bool :=
  memory.entries.any fun entry => decide (entry.event = event)

private def purchaseReversalOriginalStatus? :
    Option (Bool × Bool × Bool) := do
  let events ← purchaseReversalWorld?
  let target ← purchaseRoot?
  let reversal ← reversalPurchase?
  let originals ←
    Loam.Observation342.originalAmountsAgainst?
      events [purchaseOriginal]
  pure (
    ActualReversal.exactPhysicalInverse?
      target.effects reversal.effects,
    hasOriginalAmountFor originals purchaseRootId,
    hasOriginalAmountFor originals reversalPurchaseId)

/--
Exact physical reversal leaves the target's original amount retained, but does
not imply a second original-amount fact for the reversal Event.
-/
theorem reversal_does_not_copy_original_amount_evidence :
    purchaseReversalOriginalStatus? = some (true, true, false) := by
  native_decide

private def exchangeReversalId : EventId := ⟨"exchange-reversal"⟩
private def reversalJpy : EffectKey := ⟨"reversal-jpy"⟩
private def reversalUsd : EffectKey := ⟨"reversal-usd"⟩

private def exchangeReversal? : Option Event :=
  Event.ofEffects? exchangeReversalId [
    Effect.ofQuantity
      reversalJpy cashJpy yen (Quantity.ofQuanta 15000),
    Effect.ofQuantity
      reversalUsd cashUsd dollar (Quantity.ofQuanta (-10000))
  ]

private def exchangeReversalWorld? : Option EventMemory := do
  let target ← exchangeRoot?
  let reversal ← exchangeReversal?
  EventMemory.ofEvents? [target, reversal]

private def staleRootKeysOnReversal :
    Loam.Observation340.ExchangeEvidence := {
  event := exchangeReversalId
  source := rootDestination
  destination := rootSource
}

/--
Reversal semantics intentionally ignore EffectKey identity. Therefore exact
physical inversion cannot reconstruct the effect-selected ExchangeEvidence
anchors for the reversal Event.
-/
private def exchangeReversalStatus? : Option (Bool × Bool) := do
  let events ← exchangeReversalWorld?
  let target ← exchangeRoot?
  let reversal ← exchangeReversal?
  pure (
    ActualReversal.exactPhysicalInverse?
      target.effects reversal.effects,
    Loam.Observation340.exchangeEvidenceAdmitted?
      events staleRootKeysOnReversal)

theorem reversal_does_not_reconstruct_exchange_effect_keys :
    exchangeReversalStatus? = some (true, false) := by
  native_decide

/-!
## Finding

The two selected travel evidence families do **not** share one generic lifecycle
rule.

OriginalAmountEvidence
----------------------

The evidence describes the occurrence as a whole. A production publisher can
normalize its subject to the stable correction root, and a read projection can
resolve that root to the current terminal Event. No evidence copy is required.

This observation does not yet qualify replacement of a wrong original amount;
that remains a separate mutation question.

ExchangeEvidence
----------------

The evidence selects concrete EffectKey values. Correction may replace those
Effects with different keys. Stable Event-root continuity therefore does not
supply stable effect correspondence.

A production correction entrance should not silently carry ExchangeEvidence
forward. Until an atomic replacement-evidence rule or independent effect
lineage is qualified, correction of an exchange-qualified Event should fail
closed rather than guess.

Reversal
--------

Exact physical inversion does not synthesize either semantic family:

- an original amount on the target does not imply an original amount on the
  reversal Event;
- reversal identity ignores EffectKey, so it cannot reconstruct exchange-side
  anchors.

This is desirable: reversal records what physically undid a retained Event,
while original-presented amount and exchange-side selection remain explicit
evidence.

## Production consequence

The smallest low-risk promotion order is now:

1. OriginalAmountEvidence with stable-root normalization and current projection;
2. ExchangeEvidence with explicit re-admission and correction refusal until
   effect-level replacement semantics are qualified;
3. only then frontend recording and trip reports.

No generic TravelTransaction or home/foreign currency role is earned.
-/

end Loam.Observation344
