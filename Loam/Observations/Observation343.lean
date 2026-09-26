import Loam.Observations.Observation340
import Loam.Observations.Observation342
import Loam.PracticalMovement

namespace Loam.Observation343

open Loam.Core

set_option autoImplicit false

/-!
# Observation 343 — travel evidence is symmetric in household and destination Measures

Observations 340 and 342 were motivated by a JPY household travelling into
USD / ILS use. This observation checks that the surviving evidence shapes did
not accidentally encode that direction.

Selected counter-direction specimen:

- household normally operates in EUR;
- EUR cash is exchanged into JPY cash for a Japan trip;
- retained JPY cash is spent as an ordinary JPY Movement;
- a EUR-funded debit-card purchase is presented by the merchant as JPY;
- remaining JPY cash is exchanged back into EUR.

No new evidence family is introduced here. The observation reuses exactly:

    Observation340.ExchangeEvidence
    Observation342.OriginalAmountEvidence

The selected question is whether those candidates remain valid when JPY is the
destination / presented Measure and EUR is the household funding Measure.
-/

private def euro : MeasureId := ⟨"eur"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def cashEur : LocusId := ⟨"cash-eur"⟩
private def cashJpy : LocusId := ⟨"cash-jpy"⟩
private def bankEur : LocusId := ⟨"bank-eur"⟩
private def food : LocusId := ⟨"food"⟩
private def transport : LocusId := ⟨"transport"⟩

private def outboundId : EventId := ⟨"eur-household-japan-cash-exchange"⟩
private def outboundSource : EffectKey := ⟨"eur-source"⟩
private def outboundDestination : EffectKey := ⟨"jpy-destination"⟩

private def outbound? : Option Event :=
  Event.ofEffects? outboundId [
    Effect.ofQuantity
      outboundSource cashEur euro (Quantity.ofQuanta (-10000)),
    Effect.ofQuantity
      outboundDestination cashJpy yen (Quantity.ofQuanta 16000)
  ]

private def cashSpendId : EventId := ⟨"japan-cash-lunch"⟩

private def cashSpend? : Option Event :=
  Event.ofEffects? cashSpendId [
    Effect.ofAnonymousQuantity cashJpy yen (Quantity.ofQuanta (-1800)),
    Effect.ofAnonymousQuantity food yen (Quantity.ofQuanta 1800)
  ]

private def debitId : EventId := ⟨"eur-debit-japan-transport"⟩

private def debitPurchase? : Option Event :=
  Event.ofEffects? debitId [
    Effect.ofAnonymousQuantity bankEur euro (Quantity.ofQuanta (-3120)),
    Effect.ofAnonymousQuantity transport euro (Quantity.ofQuanta 3120)
  ]

private def returnId : EventId := ⟨"japan-cash-return-to-eur"⟩
private def returnSource : EffectKey := ⟨"jpy-return-source"⟩
private def returnDestination : EffectKey := ⟨"eur-return-destination"⟩

private def returnExchange? : Option Event :=
  Event.ofEffects? returnId [
    Effect.ofQuantity
      returnSource cashJpy yen (Quantity.ofQuanta (-9000)),
    Effect.ofQuantity
      returnDestination cashEur euro (Quantity.ofQuanta 5500)
  ]

private def tripEvents? : Option EventMemory := do
  let outbound ← outbound?
  let cashSpend ← cashSpend?
  let debit ← debitPurchase?
  let returnExchange ← returnExchange?
  EventMemory.ofEvents? [outbound, cashSpend, debit, returnExchange]

private def outboundEvidence : Loam.Observation340.ExchangeEvidence := {
  event := outboundId
  source := outboundSource
  destination := outboundDestination
}

private def returnEvidence : Loam.Observation340.ExchangeEvidence := {
  event := returnId
  source := returnSource
  destination := returnDestination
}

/--
The exchange evidence does not care that EUR, rather than JPY, is the household
source Measure.
-/
theorem eur_to_jpy_exchange_uses_the_same_evidence_shape :
    (do
      let events ← tripEvents?
      pure
        (Loam.Observation340.exchangeEvidenceAdmitted?
          events outboundEvidence)) =
      some true := by
  native_decide

/--
The same evidence shape also handles the return JPY -> EUR exchange. No
home/foreign direction bit is required.
-/
theorem jpy_to_eur_return_exchange_uses_the_same_evidence_shape :
    (do
      let events ← tripEvents?
      pure
        (Loam.Observation340.exchangeEvidenceAdmitted?
          events returnEvidence)) =
      some true := by
  native_decide

/--
Once JPY cash exists, spending it in Japan is an ordinary one-Measure Movement.
The travel evidence layer is not involved.
-/
private def cashSpendIsOrdinaryJpyMovement : Bool :=
  match cashSpend? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofEffects? yen event.effects).isSome

theorem japan_cash_spend_remains_ordinary_jpy_movement :
    cashSpendIsOrdinaryJpyMovement = true := by
  native_decide

/--
A EUR-funded debit purchase remains ordinary EUR household accounting even when
the merchant presents a JPY amount.
-/
private def debitPurchaseIsOrdinaryEurMovement : Bool :=
  match debitPurchase? with
  | none => false
  | some event =>
      (Loam.PracticalMovement.ofEffects? euro event.effects).isSome

theorem eur_funded_debit_purchase_remains_ordinary_eur_movement :
    debitPurchaseIsOrdinaryEurMovement = true := by
  native_decide

private def debitOriginal :
    Loam.Observation342.OriginalAmountEvidence := {
  event := debitId
  measure := yen
  quantity := Quantity.ofQuanta 5000
}

/--
The original-amount evidence is equally valid with JPY as the presented Measure
and EUR as the accounting Measure.
-/
theorem jpy_original_amount_is_admitted_against_eur_accounting :
    (do
      let events ← tripEvents?
      let memory ←
        Loam.Observation342.originalAmountsAgainst?
          events [debitOriginal]
      pure
        ((Loam.Observation342.originalTotalAt memory yen).quanta,
         (Loam.Observation342.originalTotalAt memory euro).quanta)) =
      some (5000, 0) := by
  native_decide

/--
The original JPY amount remains observational. It does not mutate the EUR
accounting Event or create a JPY holding.
-/
theorem jpy_original_amount_does_not_enter_eur_event_balance :
    (do
      let event ← debitPurchase?
      pure (
        (event.quantityAt bankEur euro).quanta,
        (event.quantityAt transport euro).quanta,
        (event.quantityAt bankEur yen).quanta,
        (event.quantityAt transport yen).quanta)) =
      some (-3120, 3120, 0, 0) := by
  native_decide

/--
The complete selected journey composes the same three mechanics in the opposite
geographic direction:

1. cross-Measure exchange evidence;
2. ordinary destination-Measure cash spending;
3. home-Measure debit accounting plus destination-Measure original amount;
4. return exchange with the same exchange evidence shape.
-/
private def fullSymmetryWitness? : Option (Bool × Bool × Bool × Bool) := do
  let events ← tripEvents?
  let original ←
    Loam.Observation342.originalAmountsAgainst?
      events [debitOriginal]
  pure (
    Loam.Observation340.exchangeEvidenceAdmitted?
      events outboundEvidence,
    cashSpendIsOrdinaryJpyMovement,
    debitPurchaseIsOrdinaryEurMovement &&
      (Loam.Observation342.originalTotalAt original yen).quanta = 5000,
    Loam.Observation340.exchangeEvidenceAdmitted?
      events returnEvidence)

theorem eur_household_japan_trip_is_supported_by_the_same_candidate_shapes :
    fullSymmetryWitness? = some (true, true, true, true) := by
  native_decide

/-!
## Finding

The selected travel evidence shapes are Measure-symmetric for this pressure.

Nothing in either surviving candidate names:

- a home currency;
- a foreign currency;
- JPY as privileged;
- USD / EUR / ILS as foreign;
- outbound versus inbound geography.

ExchangeEvidence observes selected unlike-Measure source and destination
Effects. OriginalAmountEvidence records one Event-scoped observed amount in
one explicit Measure. Ordinary spending remains an ordinary Movement in whatever
single Measure the retained Effects actually use.

Therefore the earlier JPY -> USD / ILS specimens should be understood as test
fixtures, not as the semantic direction of the model.

This does not prove the whole product UI is household-currency-neutral.
Current input surfaces may still choose JPY as a convenience default. That is a
presentation / configuration concern and should not be promoted into Core law.

No new production type is earned by this observation. Its result instead reduces
the risk of promoting the already-selected ExchangeEvidence and
OriginalAmountEvidence candidates.
-/

end Loam.Observation343
