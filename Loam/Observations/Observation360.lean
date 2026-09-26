import Loam.Application.OpenRelationFrontier
import Loam.Core.EventMemory

namespace Loam.Observation360

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 360 — source-bounded relation and cross-Measure settlement commitment are distinct semantics

Observation 359 reproduced the same delayed-settlement gap from two independent
domains:

- foreign-card purchase -> later bank settlement;
- security trade -> later cash settlement.

It left two candidate architectures:

A. broaden OpenRelation so one relation may carry a Measure / Quantity independent
   of its source Effect;

B. preserve current OpenRelation semantics and add a separate cross-Measure
   settlement-commitment / physical-correspondence family.

This observation compares them directly.

Current production OpenRelation has two deliberate semantic laws:

    relation Measure = source Effect Measure

    relation quantity <= |source Effect quantity|

Those laws are not incidental storage details. They support the current
source-local relation-plane interpretation and aggregate source coverage bound.

Selected ordinary relation:

    source Effect = 400 JPY
    relation      = 400 JPY

Selected cross-Measure commitments:

    card source Effect  = 30 USD
    later settlement    = 4700 JPY

    stock source Effect = 3 shares
    later settlement    = 1000 JPY

The question is whether one broadened relation can represent all three without
silently changing what "relation quantity" means.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def dollar : MeasureId := ⟨"usd"⟩
private def shares : MeasureId := ⟨"acme-share"⟩

private def expense : LocusId := ⟨"expense"⟩
private def broker : LocusId := ⟨"broker"⟩
private def bank : LocusId := ⟨"bank"⟩

private def ordinaryEventId : EventId := ⟨"o360-ordinary"⟩
private def cardEventId : EventId := ⟨"o360-card-purchase"⟩
private def stockEventId : EventId := ⟨"o360-stock-trade"⟩
private def cardSettlementId : EventId := ⟨"o360-card-settlement"⟩
private def stockSettlementId : EventId := ⟨"o360-stock-settlement"⟩

private def ordinaryEffect : EffectKey := ⟨"o360-ordinary-effect"⟩
private def cardEffect : EffectKey := ⟨"o360-card-effect"⟩
private def stockEffect : EffectKey := ⟨"o360-stock-effect"⟩
private def cardSettlementEffect : EffectKey := ⟨"o360-card-cash"⟩
private def stockSettlementEffect : EffectKey := ⟨"o360-stock-cash"⟩

private def friend : ExternalPartyId := ⟨"friend"⟩
private def cardIssuer : ExternalPartyId := ⟨"card-issuer"⟩
private def stockCounterparty : ExternalPartyId := ⟨"stock-counterparty"⟩

private def ordinaryEvent? : Option Event :=
  Event.ofEffects? ordinaryEventId [
    Effect.ofQuantity ordinaryEffect expense yen (Quantity.ofQuanta 400)
  ]

private def cardEvent? : Option Event :=
  Event.ofEffects? cardEventId [
    Effect.ofQuantity cardEffect expense dollar (Quantity.ofQuanta 30)
  ]

private def stockEvent? : Option Event :=
  Event.ofEffects? stockEventId [
    Effect.ofQuantity stockEffect broker shares (Quantity.ofQuanta 3)
  ]

private def cardSettlement? : Option Event :=
  Event.ofEffects? cardSettlementId [
    Effect.ofQuantity
      cardSettlementEffect bank yen (Quantity.ofQuanta (-4700))
  ]

private def stockSettlement? : Option Event :=
  Event.ofEffects? stockSettlementId [
    Effect.ofQuantity
      stockSettlementEffect bank yen (Quantity.ofQuanta (-1000))
  ]

private def events? : Option EventMemory := do
  let ordinary ← ordinaryEvent?
  let card ← cardEvent?
  let stock ← stockEvent?
  let cardSettlement ← cardSettlement?
  let stockSettlement ← stockSettlement?
  EventMemory.ofEvents?
    [ordinary, card, stock, cardSettlement, stockSettlement]

private def ordinaryRelationId : RelationUnitId := ⟨"o360-ordinary-relation"⟩
private def cardRelationId : RelationUnitId := ⟨"o360-card-relation"⟩
private def stockRelationId : RelationUnitId := ⟨"o360-stock-relation"⟩

private def ordinaryRelation : RelationUnit := {
  id := ordinaryRelationId
  sourceEvent := ordinaryEventId
  sourceEffect := ordinaryEffect
  debtor := .external friend
  creditor := .household
  quantity := Quantity.ofQuanta 400
}

/--
If current RelationUnit is asked to retain the independent JPY settlement amount,
the source-magnitude law rejects both cross-Measure examples.
-/
private def cardAsCurrentRelation4700 : RelationUnit := {
  id := cardRelationId
  sourceEvent := cardEventId
  sourceEffect := cardEffect
  debtor := .household
  creditor := .external cardIssuer
  quantity := Quantity.ofQuanta 4700
}

private def stockAsCurrentRelation1000 : RelationUnit := {
  id := stockRelationId
  sourceEvent := stockEventId
  sourceEffect := stockEffect
  debtor := .household
  creditor := .external stockCounterparty
  quantity := Quantity.ofQuanta 1000
}

theorem current_open_relation_preserves_ordinary_source_bounded_meaning :
    (do
      let memory ← events?
      let admitted ← admitRelationUnit? memory ordinaryRelation
      pure (
        admitted.relation.quantity.quanta,
        admitted.measure)) =
      some (400, yen) := by
  native_decide

theorem current_open_relation_rejects_cross_measure_settlement_magnitudes :
    (do
      let memory ← events?
      pure (
        admitRelationUnit? memory cardAsCurrentRelation4700,
        admitRelationUnit? memory stockAsCurrentRelation1000)) =
      some (none, none) := by
  native_decide

/--
Using source-sized quantities makes the rows admissible, but then they retain
30 USD / 3 shares, not the independently observed 4700 / 1000 JPY settlement
commitments.
-/
private def cardAsCurrentRelation30 : RelationUnit := {
  id := cardRelationId
  sourceEvent := cardEventId
  sourceEffect := cardEffect
  debtor := .household
  creditor := .external cardIssuer
  quantity := Quantity.ofQuanta 30
}

private def stockAsCurrentRelation3 : RelationUnit := {
  id := stockRelationId
  sourceEvent := stockEventId
  sourceEffect := stockEffect
  debtor := .household
  creditor := .external stockCounterparty
  quantity := Quantity.ofQuanta 3
}

theorem admissible_source_sized_relations_retain_source_measures :
    (do
      let memory ← events?
      let card ← admitRelationUnit? memory cardAsCurrentRelation30
      let stock ← admitRelationUnit? memory stockAsCurrentRelation3
      pure (
        card.relation.quantity.quanta,
        card.measure,
        stock.relation.quantity.quanta,
        stock.measure)) =
      some (30, dollar, 3, shares) := by
  native_decide

/-!
## Candidate A — broaden one relation
-/

structure BroadRelationId where
  token : String
deriving Repr, DecidableEq

structure BroadRelation where
  id : BroadRelationId
  sourceEvent : EventId
  sourceEffect : EffectKey
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

private def broadOrdinary : BroadRelation := {
  id := ⟨"broad-ordinary"⟩
  sourceEvent := ordinaryEventId
  sourceEffect := ordinaryEffect
  debtor := .external friend
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 400
}

private def broadCard : BroadRelation := {
  id := ⟨"broad-card"⟩
  sourceEvent := cardEventId
  sourceEffect := cardEffect
  debtor := .household
  creditor := .external cardIssuer
  measure := yen
  quantity := Quantity.ofQuanta 4700
}

private def broadStock : BroadRelation := {
  id := ⟨"broad-stock"⟩
  sourceEvent := stockEventId
  sourceEffect := stockEffect
  debtor := .household
  creditor := .external stockCounterparty
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def sourceEffectOf?
    (memory : EventMemory)
    (eventId : EventId)
    (effectKey : EffectKey) : Option Effect := do
  let event ← memory.findById? eventId
  event.effects.find? fun effect => effect.key = some effectKey

private def endpointsAdmissible
    (debtor creditor : RelationEndpoint) : Bool :=
  match debtor, creditor with
  | .household, .external _ => true
  | .external _, .household => true
  | _, _ => false

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

/--
Broad relation under the *existing* source-slice semantics.

The duplicated measure must equal the source measure and the quantity remains
source-bounded.
-/
private def broadSourceBoundedAdmitted?
    (memory : EventMemory)
    (relation : BroadRelation) : Bool :=
  match sourceEffectOf?
      memory relation.sourceEvent relation.sourceEffect with
  | none => false
  | some source =>
      endpointsAdmissible relation.debtor relation.creditor &&
      relation.quantity.quanta > 0 &&
      relation.measure = source.measure &&
      relation.quantity.quanta <= magnitudeQuanta source.quantity

theorem broad_relation_with_old_laws_still_rejects_cross_measure_cases :
    (do
      let memory ← events?
      pure (
        broadSourceBoundedAdmitted? memory broadOrdinary,
        broadSourceBoundedAdmitted? memory broadCard,
        broadSourceBoundedAdmitted? memory broadStock)) =
      some (true, false, false) := by
  native_decide

/--
Broad relation under independent-commitment semantics.

This admits the cross-Measure cases, but source magnitude and source Measure no
longer constrain relation quantity.
-/
private def broadIndependentAdmitted?
    (memory : EventMemory)
    (relation : BroadRelation) : Bool :=
  match sourceEffectOf?
      memory relation.sourceEvent relation.sourceEffect with
  | none => false
  | some _ =>
      endpointsAdmissible relation.debtor relation.creditor &&
      relation.quantity.quanta > 0

theorem broad_relation_only_admits_all_three_after_source_laws_are_removed :
    (do
      let memory ← events?
      pure (
        broadIndependentAdmitted? memory broadOrdinary,
        broadIndependentAdmitted? memory broadCard,
        broadIndependentAdmitted? memory broadStock)) =
      some (true, true, true) := by
  native_decide

/--
Once source magnitude no longer has semantic authority, the same broad shape
also admits an arbitrary independently measured amount from the same card source.

That is not intrinsically invalid if separate evidence authorizes it. It proves
only that the old source Effect no longer supplies the admission law.
-/
private def broadCardHuge : BroadRelation := {
  broadCard with
  id := ⟨"broad-card-huge"⟩
  quantity := Quantity.ofQuanta 999999
}

theorem independent_broad_relation_needs_new_authority_beyond_source_effect :
    (do
      let memory ← events?
      pure (
        broadIndependentAdmitted? memory broadCard,
        broadIndependentAdmitted? memory broadCardHuge)) =
      some (true, true) := by
  native_decide

inductive BroadMeaning where
  | sourceBoundedRelation
  | independentSettlementCommitment
deriving Repr, DecidableEq

/--
To keep both old and new semantics inside one broad type, admission needs an
extra discriminator telling it which law applies.

The shared record shape does not determine that choice.
-/
private def broadAdmitted?
    (memory : EventMemory)
    (meaning : BroadMeaning)
    (relation : BroadRelation) : Bool :=
  match meaning with
  | .sourceBoundedRelation =>
      broadSourceBoundedAdmitted? memory relation
  | .independentSettlementCommitment =>
      broadIndependentAdmitted? memory relation

theorem broadening_requires_explicit_semantic_mode_to_preserve_old_law :
    (do
      let memory ← events?
      pure (
        broadAdmitted? memory .sourceBoundedRelation broadCard,
        broadAdmitted? memory .independentSettlementCommitment broadCard)) =
      some (false, true) := by
  native_decide

/-!
## Candidate B — preserve OpenRelation and add settlement commitment
-/

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
deriving Repr, DecidableEq

private def cardCommitmentId : SettlementCommitmentId :=
  ⟨"card-settlement-commitment"⟩

private def stockCommitmentId : SettlementCommitmentId :=
  ⟨"stock-settlement-commitment"⟩

private def cardCommitment : SettlementCommitment := {
  id := cardCommitmentId
  sourceEvent := cardEventId
  sourceEffect := cardEffect
  debtor := .household
  creditor := .external cardIssuer
  measure := yen
  quantity := Quantity.ofQuanta 4700
}

private def stockCommitment : SettlementCommitment := {
  id := stockCommitmentId
  sourceEvent := stockEventId
  sourceEffect := stockEffect
  debtor := .household
  creditor := .external stockCounterparty
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def cardCorrespondence : SettlementEffectCorrespondence := {
  target := cardCommitmentId
  event := cardSettlementId
  effect := cardSettlementEffect
}

private def stockCorrespondence : SettlementEffectCorrespondence := {
  target := stockCommitmentId
  event := stockSettlementId
  effect := stockSettlementEffect
}

private def settlementCorrespondenceAdmitted?
    (memory : EventMemory)
    (commitment : SettlementCommitment)
    (correspondence : SettlementEffectCorrespondence) : Bool :=
  if correspondence.target != commitment.id then
    false
  else if !endpointsAdmissible commitment.debtor commitment.creditor then
    false
  else if commitment.quantity.quanta <= 0 then
    false
  else
    match sourceEffectOf?
        memory commitment.sourceEvent commitment.sourceEffect,
        memory.findById? correspondence.event with
    | some _, some later =>
        match later.effects.find? fun effect =>
          effect.key = some correspondence.effect with
        | none => false
        | some physical =>
            physical.measure = commitment.measure &&
            physical.quantity.quanta = -commitment.quantity.quanta
    | _, _ => false

theorem separate_commitment_serves_card_and_delayed_security :
    (do
      let memory ← events?
      pure (
        settlementCorrespondenceAdmitted?
          memory cardCommitment cardCorrespondence,
        settlementCorrespondenceAdmitted?
          memory stockCommitment stockCorrespondence)) =
      some (true, true) := by
  native_decide

/--
Adding the new commitment family does not alter the existing source-bounded
OpenRelation answer.
-/
theorem separate_commitment_preserves_existing_open_relation_contract :
    (do
      let memory ← events?
      let admitted ← admitRelationUnit? memory ordinaryRelation
      pure (
        admitted.relation.quantity.quanta,
        admitted.measure,
        settlementCorrespondenceAdmitted?
          memory cardCommitment cardCorrespondence,
        settlementCorrespondenceAdmitted?
          memory stockCommitment stockCorrespondence)) =
      some (400, yen, true, true) := by
  native_decide

/--
The two semantic families can intentionally coexist on one source Effect.

This does not make one reconstructable from the other.
-/
private def cardSourceRelation : RelationUnit := {
  id := cardRelationId
  sourceEvent := cardEventId
  sourceEffect := cardEffect
  debtor := .household
  creditor := .external cardIssuer
  quantity := Quantity.ofQuanta 30
}

theorem source_relation_and_settlement_commitment_answer_different_questions :
    (do
      let memory ← events?
      let sourceRelation ← admitRelationUnit? memory cardSourceRelation
      pure (
        sourceRelation.relation.quantity.quanta,
        sourceRelation.measure,
        cardCommitment.quantity.quanta,
        cardCommitment.measure)) =
      some (30, dollar, 4700, yen) := by
  native_decide

/-!
## Finding

Candidate A can represent all selected cases only after changing the semantic
contract that made current OpenRelation useful.

Under the existing laws:

    relation Measure = source Effect Measure
    relation quantity <= |source Effect quantity|

ordinary source-bounded relations remain coherent, while:

    30 USD -> 4700 JPY
    3 shares -> 1000 JPY

are correctly outside that vocabulary.

Adding independent Measure / Quantity fields is not enough by itself.

If the old laws remain, cross-Measure cases are still rejected.

If the old laws are removed, the source Effect no longer authorizes or bounds
the independent settlement quantity. New semantic authority is required.

If one broad type supports both modes, an explicit discriminator is required:

    source-bounded relation
    vs
    independent settlement commitment

At that point the design has two meanings inside one record rather than one
genuinely broader law.

Candidate B therefore has the cleaner current boundary:

    OpenRelation
      source-Effect Measure
      source-bounded quantity
      directional outstanding relation semantics

    SettlementCommitment
      source provenance
      independently observed settlement Measure / Quantity

    SettlementEffectCorrespondence
      exact later Event + EffectKey
      physical settlement equality

This preserves every current OpenRelation admission theorem and serves both
independent cross-Measure consumers discovered so far.

The result does not claim these exact observation-local structures are the final
production schema.

It does establish a stronger architectural direction:

> preserve OpenRelation's current source-slice contract; do not broaden it merely
> to absorb cross-Measure settlement.

The repeated foreign-card and delayed-security pressure is now strong enough to
continue refining a separate settlement-commitment/correspondence family.

Still not earned:

- production SettlementCommitment;
- production SettlementEffectCorrespondence;
- persistence / writers;
- generic Settlement entity;
- automatic commitment inference;
- FX semantics;
- one universal debtor/creditor ontology;
- partial settlement across multiple physical Effects;
- correction/reversal semantics for settlement correspondences;
- settlement-date calendar rules.

The next pressure should test partial and multi-Event settlement of one
cross-Measure commitment.

That asks whether the correspondence itself needs an exact settled Quantity,
mirroring the earlier RelationDischarge quantity pressure, or whether each
correspondence can always bind one whole physical Effect.
-/

end Loam.Observation360
