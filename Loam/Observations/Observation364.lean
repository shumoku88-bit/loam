import Loam.Application.OpenRelationFrontier
import Loam.Core.EventMemory

namespace Loam.Observation364

open Loam.Core

set_option autoImplicit false

/-!
# Observation 364 — settlement direction belongs to obligation endpoints, not quantity sign

The production settlement boundary, together with the remaining live
correspondence studies, has refined a settlement family around:

    SettlementCommitment
      source provenance
      debtor / creditor
      settlement Measure
      positive exact Quantity

    SettlementEffectCorrespondence
      target commitment
      later Event + EffectKey
      positive exact settled Quantity

    ReplacementFrontier
      correspondence revision

The selected physical examples so far were mostly outgoing cash payments.

Observation 361 therefore used a local admission rule that required:

    physical settlement Effect < 0

That is too narrow for a reusable securities settlement family.

A security purchase may produce a later cash debit.

A security sale may produce a later cash credit.

External post-trade conventions also distinguish gross trade amount from net
money. FIX defines buy-side net money as principal plus commissions / fees and
sell-side net money as proceeds less commissions / fees. DTCC end-of-day funds
settlement likewise resolves participants to a net debit or net credit.

The question is whether settlement needs a signed commitment Quantity, or
whether direction is already carried by the debtor / creditor endpoints while
Quantity remains a positive magnitude.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def brokerLocus : LocusId := ⟨"broker"⟩
private def bank : LocusId := ⟨"bank"⟩

private def buyTradeId : EventId := ⟨"o364-buy-trade"⟩
private def sellTradeId : EventId := ⟨"o364-sell-trade"⟩
private def buySettlementId : EventId := ⟨"o364-buy-settlement"⟩
private def sellSettlementId : EventId := ⟨"o364-sell-settlement"⟩
private def wrongBuySettlementId : EventId := ⟨"o364-wrong-buy-settlement"⟩
private def wrongSellSettlementId : EventId := ⟨"o364-wrong-sell-settlement"⟩

private def buySecurityEffect : EffectKey := ⟨"o364-buy-security"⟩
private def sellSecurityEffect : EffectKey := ⟨"o364-sell-security"⟩
private def buyCashEffect : EffectKey := ⟨"o364-buy-cash"⟩
private def sellCashEffect : EffectKey := ⟨"o364-sell-cash"⟩
private def wrongBuyCashEffect : EffectKey := ⟨"o364-wrong-buy-cash"⟩
private def wrongSellCashEffect : EffectKey := ⟨"o364-wrong-sell-cash"⟩

private def brokerParty : ExternalPartyId := ⟨"broker-counterparty"⟩

private def buyTrade? : Option Event :=
  Event.ofEffects? buyTradeId [
    Effect.ofQuantity
      buySecurityEffect brokerLocus shares (Quantity.ofQuanta 3)
  ]

private def sellTrade? : Option Event :=
  Event.ofEffects? sellTradeId [
    Effect.ofQuantity
      sellSecurityEffect brokerLocus shares (Quantity.ofQuanta (-1))
  ]

/--
Selected buy-side net cash.

The 1012 amount is intentionally larger than a hypothetical 1000 principal.
Settlement authority cares about the exact net amount due, not whether the
difference arose from commission, fee, tax, accrued interest, or another
domain-specific component.
-/
private def buySettlement? : Option Event :=
  Event.ofEffects? buySettlementId [
    Effect.ofQuantity
      buyCashEffect bank yen (Quantity.ofQuanta (-1012))
  ]

/--
Selected sell-side net cash.

The 490 amount is intentionally smaller than a hypothetical 500 gross proceeds
amount, mirroring the ordinary possibility that charges reduce net proceeds.
-/
private def sellSettlement? : Option Event :=
  Event.ofEffects? sellSettlementId [
    Effect.ofQuantity
      sellCashEffect bank yen (Quantity.ofQuanta 490)
  ]

private def wrongBuySettlement? : Option Event :=
  Event.ofEffects? wrongBuySettlementId [
    Effect.ofQuantity
      wrongBuyCashEffect bank yen (Quantity.ofQuanta 1012)
  ]

private def wrongSellSettlement? : Option Event :=
  Event.ofEffects? wrongSellSettlementId [
    Effect.ofQuantity
      wrongSellCashEffect bank yen (Quantity.ofQuanta (-490))
  ]

private def events? : Option EventMemory := do
  let buyTrade ← buyTrade?
  let sellTrade ← sellTrade?
  let buySettlement ← buySettlement?
  let sellSettlement ← sellSettlement?
  let wrongBuy ← wrongBuySettlement?
  let wrongSell ← wrongSellSettlement?
  EventMemory.ofEvents?
    [buyTrade, sellTrade, buySettlement, sellSettlement, wrongBuy, wrongSell]

structure SettlementCommitmentId where
  token : String
deriving Repr, DecidableEq

structure SettlementCommitment where
  id : SettlementCommitmentId
  sourceEvent : EventId
  sourceEffect : EffectKey
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

structure SettlementEffectCorrespondence where
  target : SettlementCommitmentId
  event : EventId
  effect : EffectKey
  quantity : Quantity
deriving Repr, DecidableEq

private def buyCommitmentId : SettlementCommitmentId :=
  ⟨"o364-buy-commitment"⟩

private def sellCommitmentId : SettlementCommitmentId :=
  ⟨"o364-sell-commitment"⟩

private def buyCommitment : SettlementCommitment := {
  id := buyCommitmentId
  sourceEvent := buyTradeId
  sourceEffect := buySecurityEffect
  debtor := .household
  creditor := .external brokerParty
  measure := yen
  quantity := Quantity.ofQuanta 1012
}

private def sellCommitment : SettlementCommitment := {
  id := sellCommitmentId
  sourceEvent := sellTradeId
  sourceEffect := sellSecurityEffect
  debtor := .external brokerParty
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 490
}

private def commitments : List SettlementCommitment :=
  [buyCommitment, sellCommitment]

private def buyCorrespondence : SettlementEffectCorrespondence := {
  target := buyCommitmentId
  event := buySettlementId
  effect := buyCashEffect
  quantity := Quantity.ofQuanta 1012
}

private def sellCorrespondence : SettlementEffectCorrespondence := {
  target := sellCommitmentId
  event := sellSettlementId
  effect := sellCashEffect
  quantity := Quantity.ofQuanta 490
}

private def wrongBuyCorrespondence : SettlementEffectCorrespondence := {
  target := buyCommitmentId
  event := wrongBuySettlementId
  effect := wrongBuyCashEffect
  quantity := Quantity.ofQuanta 1012
}

private def wrongSellCorrespondence : SettlementEffectCorrespondence := {
  target := sellCommitmentId
  event := wrongSellSettlementId
  effect := wrongSellCashEffect
  quantity := Quantity.ofQuanta 490
}

private def findCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def sourceEffectOf?
    (memory : EventMemory)
    (commitment : SettlementCommitment) : Option Effect := do
  let source ← memory.findById? commitment.sourceEvent
  findEffectByKey? source commitment.sourceEffect

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

/--
Direction is not encoded in the commitment quantity.

The commitment quantity is a positive magnitude. The debtor / creditor endpoints
determine whether household cash settlement should physically leave or enter the
household locus.
-/
private def physicalSignAgreesWithEndpoints
    (commitment : SettlementCommitment)
    (physical : Effect) : Bool :=
  match commitment.debtor, commitment.creditor with
  | .household, .external _ =>
      physical.quantity.quanta < 0
  | .external _, .household =>
      physical.quantity.quanta > 0
  | _, _ =>
      false

private def correspondenceAdmitted?
    (memory : EventMemory)
    (row : SettlementEffectCorrespondence) : Bool :=
  match findCommitment? row.target, memory.findById? row.event with
  | some commitment, some settlement =>
      match sourceEffectOf? memory commitment,
            findEffectByKey? settlement row.effect with
      | some _, some physical =>
          commitment.quantity.quanta > 0 &&
          row.quantity.quanta > 0 &&
          physical.measure = commitment.measure &&
          physicalSignAgreesWithEndpoints commitment physical &&
          row.quantity.quanta <= commitment.quantity.quanta &&
          row.quantity.quanta <= magnitudeQuanta physical.quantity
      | _, _ => false
  | _, _ => false

/-!
## Pressure 1 — one positive-magnitude family supports buy and sell settlement
-/

theorem positive_commitment_magnitude_supports_both_cash_directions :
    (do
      let memory ← events?
      pure (
        correspondenceAdmitted? memory buyCorrespondence,
        correspondenceAdmitted? memory sellCorrespondence,
        buyCommitment.quantity.quanta,
        sellCommitment.quantity.quanta)) =
      some (true, true, 1012, 490) := by
  native_decide

/-!
## Pressure 2 — endpoint direction rejects physically reversed settlement
-/

theorem physical_cash_sign_must_agree_with_obligation_direction :
    (do
      let memory ← events?
      pure (
        correspondenceAdmitted? memory wrongBuyCorrespondence,
        correspondenceAdmitted? memory wrongSellCorrespondence)) =
      some (false, false) := by
  native_decide

/-!
## Pressure 3 — settlement magnitude need not equal gross trade consideration
-/

theorem selected_net_amounts_remain_exact_positive_commitments :
    buyCommitment.quantity.quanta = 1012 ∧
    sellCommitment.quantity.quanta = 490 ∧
    buyCommitment.quantity.quanta > 1000 ∧
    sellCommitment.quantity.quanta < 500 := by
  native_decide

/-!
## Finding

A reusable settlement family should not inherit Observation 361's temporary law:

    physical settlement Effect < 0

That law encoded one outgoing-payment example, not settlement itself.

The cleaner candidate keeps:

    SettlementCommitment.quantity
      positive exact magnitude

    SettlementCommitment.debtor / creditor
      obligation direction

    SettlementEffectCorrespondence.quantity
      positive exact attributed magnitude

and derives the required physical Effect sign from the endpoints:

    household debtor
      -> household cash Effect must be negative

    household creditor
      -> household cash Effect must be positive

This serves both:

    security purchase
      later cash debit

    security sale
      later cash credit

without adding:

- signed commitment quantities;
- a separate receivable settlement type;
- buy/sell-specific correspondence records;
- direction-specific mutation mechanics.

## Fee / tax consequence

External securities workflows make a second distinction visible.

FIX carries gross trade amount, commission / miscellaneous fee information, and
NetMoney separately. NetMoney is the total amount due from the transaction; for
a buy it can exceed principal, while for a sell charges can reduce proceeds.

Therefore settlement should be allowed to retain the exact net cash obligation
without claiming that settlement itself owns the semantic decomposition of:

    principal
    commission
    tax
    accrued interest
    other fee

Those component meanings may be represented by investment/accounting evidence
and may affect basis, realised gain, expense, or tax projections. They do not
need to become fields on SettlementCommitment merely so that the later cash
movement can settle the exact net amount.

Observation 364 therefore strengthens the minimum candidate to:

    SettlementCommitment
      stable identity
      source provenance
      debtor / creditor
      settlement Measure
      positive exact net Quantity

    SettlementEffectCorrespondence
      version identity if correction is promised
      target commitment
      later Event + EffectKey
      positive exact settled Quantity

    endpoint-directed physical sign rule

    dual aggregate bounds from Observation 361

    generic ReplacementFrontier for revision

Still not earned:

- production persistence / writer;
- a universal settlement component list;
- commission / tax ownership inside settlement;
- tax-jurisdiction rules;
- basis capitalization policy;
- automatic NetMoney derivation;
- settlement netting across several independent commitments;
- short-sale lifecycle semantics;
- dividends / corporate actions;
- FX valuation semantics.

The next pressure should test netting directly.

A single physical bank / broker cash movement can represent the net result of
several buys, sells, fees, credits, or other obligations. Observation 361 already
allows one Effect to cover several same-direction commitments.

The harder remaining question is whether one physical **net** Effect may settle
commitments in opposite directions without losing the gross obligations that
produced the net result.

That pressure should be tested before production settlement persistence.
-/

end Loam.Observation364
