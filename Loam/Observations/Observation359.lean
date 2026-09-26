import Loam.Application.RelationDischargeFrontier
import Loam.Core.EventMemory

namespace Loam.Observation359

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 359 — delayed security settlement reproduces the cross-Measure settlement gap

Observation 358 composed one investment lifecycle whose purchase and cash
settlement occurred in the same physical Event.

The next pressure separates trade occurrence from later cash settlement.

Selected history:

    trade occurrence
      broker +3 acme-share
      agreed consideration 1000 jpy

    later settlement Event
      bank -1000 jpy
      bank   -10 jpy unrelated fee-like movement

The exact 1000-JPY settlement movement is one Effect inside the later Event.

Two existing boundaries are pressured.

First, the Observation-346/358 SecurityTradeEvidence shape names both the
security Effect and settlement Effect inside one Event. It therefore cannot
represent a later settlement Effect without changing its meaning.

Second, current RelationDischarge is Event-scoped on the later side. It can say
that a later Event discharged relation quantity, but it does not identify which
Effect inside the Event supplied physical settlement and it does not establish a
cross-Measure amount correspondence.

This is the same structural gap Observation 341 found for foreign-card
settlement, now reproduced independently by delayed security settlement.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def brokerLocus : LocusId := ⟨"broker"⟩
private def bank : LocusId := ⟨"bank"⟩

private def tradeId : EventId := ⟨"o359-trade"⟩
private def settlementId : EventId := ⟨"o359-settlement"⟩

private def securityEffect : EffectKey := ⟨"o359-security"⟩
private def settlementEffect : EffectKey := ⟨"o359-cash-settlement"⟩
private def otherCashEffect : EffectKey := ⟨"o359-other-cash"⟩

private def brokerParty : ExternalPartyId := ⟨"broker-counterparty"⟩
private def relationId : RelationUnitId := ⟨"o359-share-relation"⟩

private def trade? : Option Event :=
  Event.ofEffects? tradeId [
    Effect.ofQuantity
      securityEffect brokerLocus shares (Quantity.ofQuanta 3)
  ]

private def settlement1000? : Option Event :=
  Event.ofEffects? settlementId [
    Effect.ofQuantity
      settlementEffect bank yen (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity
      otherCashEffect bank yen (Quantity.ofQuanta (-10))
  ]

private def settlement1? : Option Event :=
  Event.ofEffects? settlementId [
    Effect.ofQuantity
      settlementEffect bank yen (Quantity.ofQuanta (-1)),
    Effect.ofQuantity
      otherCashEffect bank yen (Quantity.ofQuanta (-10))
  ]

private def memoryWith? (settlement : Event) : Option EventMemory := do
  let trade ← trade?
  EventMemory.ofEvents? [trade, settlement]

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

/-!
## Pressure 1 — same-Event SecurityTradeEvidence is too narrow
-/

structure SameEventSecurityTradeEvidence where
  event : EventId
  security : EffectKey
  settlement : EffectKey
deriving Repr, DecidableEq

inductive TradeDirection where
  | acquire
  | dispose
deriving Repr, DecidableEq

private def sameEventTradeDirection?
    (memory : EventMemory)
    (evidence : SameEventSecurityTradeEvidence) :
    Option TradeDirection := do
  let event ← memory.findById? evidence.event
  let security ← findEffectByKey? event evidence.security
  let settlement ← findEffectByKey? event evidence.settlement
  if security.measure = settlement.measure then
    none
  else if security.quantity.quanta > 0 &&
      settlement.quantity.quanta < 0 then
    some .acquire
  else if security.quantity.quanta < 0 &&
      settlement.quantity.quanta > 0 then
    some .dispose
  else
    none

private def delayedTradeThroughOldShape : SameEventSecurityTradeEvidence := {
  event := tradeId
  security := securityEffect
  settlement := settlementEffect
}

/--
The settlement key exists only in the later Event.

Therefore the same-Event evidence shape cannot express this delayed lifecycle.
-/
theorem same_event_trade_evidence_cannot_span_delayed_settlement :
    (do
      let settlement ← settlement1000?
      let memory ← memoryWith? settlement
      pure (sameEventTradeDirection? memory delayedTradeThroughOldShape)) =
      some none := by
  native_decide

/-!
## Pressure 2 — Event-scoped RelationDischarge does not bind physical JPY
-/

/--
The current RelationUnit can anchor to the acquired share Effect.

Because relation Measure is inherited from its source Effect, this relation is
share-denominated, not a 1000-JPY settlement obligation.
-/
private def shareRelation : RelationUnit := {
  id := relationId
  sourceEvent := tradeId
  sourceEffect := securityEffect
  debtor := .household
  creditor := .external brokerParty
  quantity := Quantity.ofQuanta 3
}

private def shareDischarge : RelationDischarge := {
  event := settlementId
  target := relationId
  quantity := Quantity.ofQuanta 3
}

private def outstandingWith?
    (settlement : Event) : Option Int := do
  let memory ← memoryWith? settlement
  let outstanding ← relationOutstandingQuantity?
    memory
    [shareRelation]
    [shareDischarge]
    relationId
  pure outstanding.quanta

private def admittedRelationMeasureWith?
    (settlement : Event) : Option MeasureId := do
  let memory ← memoryWith? settlement
  let admitted ← currentAdmittedRelationById?
    memory [shareRelation] relationId
  pure admitted.measure

theorem current_relation_inherits_security_measure_not_cash_measure :
    (do
      let settlement ← settlement1000?
      admittedRelationMeasureWith? settlement) =
      some shares := by
  native_decide

/--
The current discharge frontier fully discharges the share-denominated relation
for either physical cash amount because the raw discharge correspondence names
the later Event but not one Effect inside it.
-/
theorem event_scoped_discharge_does_not_determine_delayed_cash_amount :
    (do
      let full ← settlement1000?
      let tiny ← settlement1?
      pure (
        outstandingWith? full,
        outstandingWith? tiny)) =
      some (some 0, some 0) := by
  native_decide

theorem falsification_worlds_have_different_physical_settlement_effects :
    (do
      let full ← settlement1000?
      let tiny ← settlement1?
      let fullEffect ← findEffectByKey? full settlementEffect
      let tinyEffect ← findEffectByKey? tiny settlementEffect
      pure (
        fullEffect.quantity.quanta,
        tinyEffect.quantity.quanta,
        full.quantityAt bank yen |>.quanta,
        tiny.quantityAt bank yen |>.quanta)) =
      some (-1000, -1, -1010, -11) := by
  native_decide

/-!
## Observation-local additive candidate

The delayed trade has one agreed settlement obligation whose Measure differs
from the security Effect Measure.

This evidence is deliberately observation-local.
-/

structure SettlementCommitmentId where
  token : String
deriving Repr, DecidableEq

private def commitmentId : SettlementCommitmentId :=
  ⟨"o359-settlement-commitment"⟩

structure SecuritySettlementCommitment where
  id : SettlementCommitmentId
  tradeEvent : EventId
  securityEffect : EffectKey
  creditor : ExternalPartyId
  settlementMeasure : MeasureId
  settlementQuantity : Quantity
deriving Repr, DecidableEq

private def commitment : SecuritySettlementCommitment := {
  id := commitmentId
  tradeEvent := tradeId
  securityEffect := securityEffect
  creditor := brokerParty
  settlementMeasure := yen
  settlementQuantity := Quantity.ofQuanta 1000
}

structure SettlementEffectCorrespondence where
  target : SettlementCommitmentId
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def selectedCorrespondence : SettlementEffectCorrespondence := {
  target := commitmentId
  event := settlementId
  effect := settlementEffect
}

private def settlementCorrespondenceAdmitted?
    (memory : EventMemory)
    (commitment : SecuritySettlementCommitment)
    (correspondence : SettlementEffectCorrespondence) : Bool :=
  if correspondence.target != commitment.id then
    false
  else
    match memory.findById? commitment.tradeEvent,
          memory.findById? correspondence.event with
    | some trade, some later =>
        match findEffectByKey? trade commitment.securityEffect,
              findEffectByKey? later correspondence.effect with
        | some security, some physical =>
            security.quantity.quanta > 0 &&
            physical.measure = commitment.settlementMeasure &&
            commitment.settlementQuantity.quanta > 0 &&
            physical.quantity.quanta =
              -commitment.settlementQuantity.quanta
        | _, _ => false
    | _, _ => false

/--
Effect-level settlement correspondence distinguishes the physically correct
1000-JPY settlement from the 1-JPY falsification world even though both later
Events have the same EventId.
-/
theorem effect_level_correspondence_closes_selected_amount_gap :
    (do
      let full ← settlement1000?
      let tiny ← settlement1?
      let fullMemory ← memoryWith? full
      let tinyMemory ← memoryWith? tiny
      pure (
        settlementCorrespondenceAdmitted?
          fullMemory commitment selectedCorrespondence,
        settlementCorrespondenceAdmitted?
          tinyMemory commitment selectedCorrespondence)) =
      some (true, false) := by
  native_decide

/--
The later Event may contain another JPY Effect without creating ambiguity once
the settlement correspondence names the exact EffectKey.
-/
theorem exact_effect_anchor_is_stronger_than_event_total :
    (do
      let full ← settlement1000?
      let physical ← findEffectByKey? full settlementEffect
      pure (
        physical.quantity.quanta,
        (full.quantityAt bank yen).quanta)) =
      some (-1000, -1010) := by
  native_decide

/-!
## Finding

Delayed security settlement exposes two independent limits in the current
investment/relation composition.

### 1. Same-event trade evidence is not enough

A security trade semantic qualifier that requires both security and cash
settlement Effects inside one Event cannot represent trade-date / settlement-date
separation.

The semantic trade occurrence and the later physical settlement occurrence must
therefore remain separable.

### 2. Event-scoped discharge is not enough for exact physical settlement

Current RelationDischarge can establish that a later Event discharged a
share-denominated relation, but it cannot establish:

    agreed consideration = 1000 JPY
    exact later settlement Effect = -1000 JPY

The falsification world with a -1 JPY Effect produces the same current
RelationDischarge outstanding answer.

An additive observation-local candidate with:

    explicit settlement commitment
      trade Event + security Effect
      settlement Measure + exact Quantity

    explicit later settlement correspondence
      later Event + later EffectKey

can distinguish those worlds without changing neutral Event / Effect Core.

### Independent recurrence

Observation 341 reached the same later-Effect correspondence pressure from a
foreign-card purchase.

Observation 359 reaches it from delayed securities.

That is meaningful repeated pressure for a reusable settlement-correspondence
mechanic.

It still does not automatically earn a neutral Core primitive.

The current OpenRelation family deliberately inherits Measure from its source
Effect and is therefore narrower than this cross-Measure commitment question.
Broadening RelationUnit merely to absorb delayed securities and foreign cards
would change its existing semantic contract.

The next design decision should compare two candidates directly:

1. broaden OpenRelation into an independently measured relation;
2. keep OpenRelation narrow and add a separate cross-Measure settlement
   commitment/correspondence evidence family.

That comparison should happen before production investment persistence.

Still not earned:

- production SecuritySettlementCommitment;
- production SettlementEffectCorrespondence;
- a generic Settlement entity;
- broadening RelationUnit;
- trade-date / settlement-date calendar law;
- brokerage statement import;
- fee capitalization;
- automatic matching by amount/date;
- FX or valuation semantics;
- a new Core transaction kind.
-/

end Loam.Observation359
