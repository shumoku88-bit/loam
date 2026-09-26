import Loam.Core.EventMemory
import Loam.PracticalMovement

namespace Loam.Observation340

open Loam.Core

set_option autoImplicit false

/-!
# Observation 340 — travel exchange needs effect-selected evidence, not a transaction kind

Issue #1351 fixes the practical pressure: a household may need to travel on
short notice and must be able to retain ordinary foreign-currency use without
turning LOAM into a general valuation engine.

Observation 282 tested event-level `ExchangeEvidence(EventId)` on an exactly
two-Effect exchange. Observation 283 then found the important counterexample:
a fee-bearing exchange has a third Effect, so event identity alone no longer
selects which two Effects form the exchanged pair.

This observation tests the next smallest candidate:

    ExchangeEvidence
      event
      source EffectKey
      destination EffectKey

The evidence says only that two retained Effects in one observed occurrence are
the selected unlike-Measure exchange sides.

It does not state or derive:

- market rate;
- valuation authority;
- acquisition basis;
- tax basis;
- realised or unrealised gain;
- fee semantics for any other Effect in the Event.

The pressure specimens are intentionally household-practical:

1. JPY cash -> USD cash;
2. the same exchange with an explicit JPY fee Effect;
3. a Wise-like JPY balance -> USD balance exchange;
4. later USD spending from the Wise balance;
5. return USD cash -> JPY cash.

The selected question is whether one effect-selected exchange relation covers
1, 2, 3 and 5 while case 4 remains an ordinary single-Measure Movement.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def dollar : MeasureId := ⟨"usd"⟩

private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def cashUsd : LocusId := ⟨"cash-usd"⟩
private def wiseJpy : LocusId := ⟨"wise-jpy"⟩
private def wiseUsd : LocusId := ⟨"wise-usd"⟩
private def food : LocusId := ⟨"food"⟩
private def feeLocus : LocusId := ⟨"exchange-fee"⟩

structure ExchangeEvidence where
  event : EventId
  source : EffectKey
  destination : EffectKey
deriving Repr, DecidableEq

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

/--
The bounded candidate admits exactly the relation needed by the travel
specimens:

- both selected Effects exist in the named Event;
- the Effects use distinct Measures;
- source quantity is negative;
- destination quantity is positive.

Additional Effects are allowed and carry no exchange meaning merely by being
present.
-/
def exchangeEvidenceAdmitted?
    (events : EventMemory)
    (evidence : ExchangeEvidence) : Bool :=
  match events.findById? evidence.event with
  | none => false
  | some event =>
      match findEffectByKey? event evidence.source,
            findEffectByKey? event evidence.destination with
      | some source, some destination =>
          source.measure != destination.measure &&
          source.quantity.quanta < 0 &&
          destination.quantity.quanta > 0
      | _, _ => false

private def outboundId : EventId := ⟨"travel-cash-jpy-to-usd"⟩
private def outboundSource : EffectKey := ⟨"outbound-jpy"⟩
private def outboundDestination : EffectKey := ⟨"outbound-usd"⟩

private def outbound? : Option Event :=
  Event.ofEffects? outboundId [
    Effect.ofQuantity
      outboundSource cashJpy yen (Quantity.ofQuanta (-15000)),
    Effect.ofQuantity
      outboundDestination cashUsd dollar (Quantity.ofQuanta 100)
  ]

private def outboundMemory? : Option EventMemory := do
  let event ← outbound?
  EventMemory.ofEvents? [event]

private def outboundEvidence : ExchangeEvidence := {
  event := outboundId
  source := outboundSource
  destination := outboundDestination
}

theorem outbound_cash_exchange_is_selected_without_a_rate :
    (do
      let memory ← outboundMemory?
      pure (exchangeEvidenceAdmitted? memory outboundEvidence)) =
      some true := by
  native_decide

private def feeExchangeId : EventId := ⟨"travel-cash-exchange-with-fee"⟩
private def feeSource : EffectKey := ⟨"fee-exchange-jpy-source"⟩
private def feeDestination : EffectKey := ⟨"fee-exchange-usd-destination"⟩
private def feeEffect : EffectKey := ⟨"fee-exchange-fee"⟩

private def feeExchange? : Option Event :=
  Event.ofEffects? feeExchangeId [
    Effect.ofQuantity
      feeSource cashJpy yen (Quantity.ofQuanta (-15100)),
    Effect.ofQuantity
      feeEffect feeLocus yen (Quantity.ofQuanta 100),
    Effect.ofQuantity
      feeDestination cashUsd dollar (Quantity.ofQuanta 100)
  ]

private def feeExchangeMemory? : Option EventMemory := do
  let event ← feeExchange?
  EventMemory.ofEvents? [event]

private def feeExchangeEvidence : ExchangeEvidence := {
  event := feeExchangeId
  source := feeSource
  destination := feeDestination
}

/--
Unlike the exactly-two-Effect candidate in Observation 282, explicit side
selection survives the fee-bearing three-Effect occurrence.

The fee Effect is retained but is not silently interpreted by ExchangeEvidence.
-/
theorem fee_bearing_exchange_keeps_one_occurrence_and_selects_exchange_sides :
    (do
      let memory ← feeExchangeMemory?
      pure (exchangeEvidenceAdmitted? memory feeExchangeEvidence)) =
      some true := by
  native_decide

private def wiseExchangeId : EventId := ⟨"wise-jpy-to-usd"⟩
private def wiseSource : EffectKey := ⟨"wise-jpy-source"⟩
private def wiseDestination : EffectKey := ⟨"wise-usd-destination"⟩

private def wiseExchange? : Option Event :=
  Event.ofEffects? wiseExchangeId [
    Effect.ofQuantity
      wiseSource wiseJpy yen (Quantity.ofQuanta (-20000)),
    Effect.ofQuantity
      wiseDestination wiseUsd dollar (Quantity.ofQuanta 130)
  ]

private def wiseExchangeMemory? : Option EventMemory := do
  let event ← wiseExchange?
  EventMemory.ofEvents? [event]

private def wiseExchangeEvidence : ExchangeEvidence := {
  event := wiseExchangeId
  source := wiseSource
  destination := wiseDestination
}

/--
Cash exchange and stored-value exchange require no different Core transaction
kind in this bounded vocabulary. Locus identity distinguishes where the
quantities live; ExchangeEvidence only selects the unlike-Measure sides.
-/
theorem wise_exchange_uses_the_same_selected_exchange_shape :
    (do
      let memory ← wiseExchangeMemory?
      pure (exchangeEvidenceAdmitted? memory wiseExchangeEvidence)) =
      some true := by
  native_decide

private def wiseSpendId : EventId := ⟨"wise-usd-food-purchase"⟩

private def wiseSpend? : Option Event :=
  Event.ofEffects? wiseSpendId [
    Effect.ofAnonymousQuantity
      wiseUsd dollar (Quantity.ofQuanta (-25)),
    Effect.ofAnonymousQuantity
      food dollar (Quantity.ofQuanta 25)
  ]

/--
After foreign value already exists at the Wise USD Locus, an ordinary purchase
is just one-Measure movement. No ExchangeEvidence is required for the purchase.
-/
private def wiseSpendIsOrdinaryMovement : Bool :=
  match wiseSpend? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofSingleMeasureEffects? event.effects).isSome

theorem later_wise_usd_purchase_remains_ordinary_movement :
    wiseSpendIsOrdinaryMovement = true := by
  native_decide

private def returnId : EventId := ⟨"travel-cash-usd-to-jpy"⟩
private def returnSource : EffectKey := ⟨"return-usd"⟩
private def returnDestination : EffectKey := ⟨"return-jpy"⟩

private def returnExchange? : Option Event :=
  Event.ofEffects? returnId [
    Effect.ofQuantity
      returnSource cashUsd dollar (Quantity.ofQuanta (-40)),
    Effect.ofQuantity
      returnDestination cashJpy yen (Quantity.ofQuanta 6000)
  ]

private def returnMemory? : Option EventMemory := do
  let event ← returnExchange?
  EventMemory.ofEvents? [event]

private def returnEvidence : ExchangeEvidence := {
  event := returnId
  source := returnSource
  destination := returnDestination
}

/--
No outbound / inbound transaction kind is needed. The same directional rule
accepts USD -> JPY when the observed signs are reversed with the actual source
and destination Effects.
-/
theorem return_exchange_uses_the_same_evidence_shape :
    (do
      let memory ← returnMemory?
      pure (exchangeEvidenceAdmitted? memory returnEvidence)) =
      some true := by
  native_decide

/--
Swapping source and destination is not an equally valid interpretation of the
same retained occurrence because their signs are part of admission.
-/
private def reversedOutboundEvidence : ExchangeEvidence := {
  event := outboundId
  source := outboundDestination
  destination := outboundSource
}

theorem exchange_direction_is_observed_not_inferred_from_measure_names :
    (do
      let memory ← outboundMemory?
      pure (
        exchangeEvidenceAdmitted? memory outboundEvidence,
        exchangeEvidenceAdmitted? memory reversedOutboundEvidence)) =
      some (true, false) := by
  native_decide

/-!
## Finding

For the selected travel pressure, the smallest surviving candidate is stronger
than `ExchangeEvidence(EventId)` but still small:

    one retained Event
    + source EffectKey
    + destination EffectKey

This is sufficient to distinguish the exchanged sides even when a fee Effect is
also retained in the same occurrence.

It also composes cleanly with the existing neutral Core:

- cash and Wise differ by Locus, not transaction kind;
- outbound and return exchange use the same evidence shape;
- later foreign-currency spending is ordinary single-Measure Movement;
- unlike Measures still never arithmetically cancel;
- no rate or valuation is inferred from the observed quantity pair.

What is **not** earned here:

- a production ExchangeEvidence type;
- normalized Actual wire rows;
- publication / authority admission;
- FeeEvidence semantics;
- correction / reversal laws for ExchangeEvidence;
- card purchase / later JPY settlement semantics;
- market valuation, basis, tax, or gain semantics.

The next practical falsification target for #1351 is therefore independent:

> Can a foreign card purchase and later JPY bank debit compose with the existing
> directional Relation / Discharge boundary without creating the expense twice?

That question should not be forced into ExchangeEvidence.
-/

end Loam.Observation340
