import Loam.Application.OpenRelationFrontier
import Loam.Core.EventMemory

namespace Loam.Observation365

open Loam.Core

set_option autoImplicit false

/-!
# Observation 365 — opposite-direction netting requires authority above direct correspondence

Observation 364 established a bidirectional settlement convention:

    SettlementCommitment.quantity
      positive exact magnitude

    debtor / creditor
      obligation direction

    physical Effect sign
      must agree with that direction

That works while a physical Effect directly settles obligations in one direction.

The harder case is net settlement.

Selected gross obligations, all in JPY:

    household -> broker   1000
    broker -> household    700
    household -> broker     20
    broker -> household     50

From the household cash perspective:

    -1000 + 700 - 20 + 50 = -270

but the only physical bank movement is:

    bank Effect = -270 JPY

This is not a hypothetical edge case.

DTCC end-of-day funds settlement consolidates settlement-related activity into
one net debit or credit per participant. BIS terminology for obligation netting
likewise describes replacing multiple gross obligations with one netted
obligation.

The question is whether Observation 364's direct Effect correspondence can
retain the gross semantics, or whether netting needs a distinct authority that
names the gross members whose signed sum produced the physical net Effect.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def settlementEventId : EventId := ⟨"o365-net-settlement"⟩
private def settlementEffectKey : EffectKey := ⟨"o365-net-cash"⟩

private def settlementEvent? : Option Event :=
  Event.ofEffects? settlementEventId [
    Effect.ofQuantity
      settlementEffectKey bank yen (Quantity.ofQuanta (-270))
  ]

private def events? : Option EventMemory := do
  let settlement ← settlementEvent?
  EventMemory.ofEvents? [settlement]

private def broker : ExternalPartyId := ⟨"broker-counterparty"⟩

structure SettlementCommitmentId where
  token : String
deriving Repr, DecidableEq

structure SettlementCommitment where
  id : SettlementCommitmentId
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

private def buyId : SettlementCommitmentId := ⟨"buy"⟩
private def saleId : SettlementCommitmentId := ⟨"sale"⟩
private def feeId : SettlementCommitmentId := ⟨"fee"⟩
private def creditId : SettlementCommitmentId := ⟨"credit"⟩

private def buy1000 : SettlementCommitment := {
  id := buyId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def sale700 : SettlementCommitment := {
  id := saleId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 700
}

private def fee20 : SettlementCommitment := {
  id := feeId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 20
}

private def credit50 : SettlementCommitment := {
  id := creditId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 50
}

private def grossCommitments : List SettlementCommitment :=
  [buy1000, sale700, fee20, credit50]

private def buy900 : SettlementCommitment := {
  buy1000 with quantity := Quantity.ofQuanta 900
}

private def sale600 : SettlementCommitment := {
  sale700 with quantity := Quantity.ofQuanta 600
}

private def alternateGrossCommitments : List SettlementCommitment :=
  [buy900, sale600, fee20, credit50]

private def findCommitment?
    (commitments : List SettlementCommitment)
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

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

/-!
## Pressure 1 — direct correspondence cannot explain the gross obligations
-/

structure DirectCorrespondence where
  target : SettlementCommitmentId
  event : EventId
  effect : EffectKey
  quantity : Quantity
deriving Repr, DecidableEq

private def directCorrespondenceAdmitted?
    (memory : EventMemory)
    (commitments : List SettlementCommitment)
    (row : DirectCorrespondence) : Bool :=
  match findCommitment? commitments row.target,
        memory.findById? row.event with
  | some commitment, some event =>
      match findEffectByKey? event row.effect with
      | none => false
      | some physical =>
          commitment.quantity.quanta > 0 &&
          row.quantity.quanta > 0 &&
          physical.measure = commitment.measure &&
          physicalSignAgreesWithEndpoints commitment physical &&
          row.quantity.quanta <= commitment.quantity.quanta &&
          row.quantity.quanta <= magnitudeQuanta physical.quantity
  | _, _ => false

private def directBuy : DirectCorrespondence := {
  target := buyId
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 1000
}

private def directSale : DirectCorrespondence := {
  target := saleId
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 700
}

private def directFee : DirectCorrespondence := {
  target := feeId
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 20
}

private def directCredit : DirectCorrespondence := {
  target := creditId
  event := settlementEventId
  effect := settlementEffectKey
  quantity := Quantity.ofQuanta 50
}

theorem one_net_effect_cannot_directly_correspond_to_all_gross_obligations :
    (do
      let memory ← events?
      pure (
        directCorrespondenceAdmitted? memory grossCommitments directBuy,
        directCorrespondenceAdmitted? memory grossCommitments directSale,
        directCorrespondenceAdmitted? memory grossCommitments directFee,
        directCorrespondenceAdmitted? memory grossCommitments directCredit)) =
      some (false, false, true, false) := by
  native_decide

/-!
The failure is structural, not a bad amount choice.

The outgoing buy is larger than the physical -270 movement.

The incoming sale / credit have the opposite direction from that same physical
Effect.

Only the small outgoing fee happens to satisfy direct-correspondence rules.

So the physical -270 Effect cannot be treated as if it were independently
consumed by every gross obligation.
-/

/-!
## Candidate — explicit netting membership above retained gross commitments
-/

structure NettingMember where
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

structure SettlementNettingEvidence where
  event : EventId
  effect : EffectKey
  members : List NettingMember
deriving Repr, DecidableEq

private def selectedMembers : List NettingMember := [
  ⟨buyId, Quantity.ofQuanta 1000⟩,
  ⟨saleId, Quantity.ofQuanta 700⟩,
  ⟨feeId, Quantity.ofQuanta 20⟩,
  ⟨creditId, Quantity.ofQuanta 50⟩
]

private def alternateMembers : List NettingMember := [
  ⟨buyId, Quantity.ofQuanta 900⟩,
  ⟨saleId, Quantity.ofQuanta 600⟩,
  ⟨feeId, Quantity.ofQuanta 20⟩,
  ⟨creditId, Quantity.ofQuanta 50⟩
]

private def selectedNetting : SettlementNettingEvidence := {
  event := settlementEventId
  effect := settlementEffectKey
  members := selectedMembers
}

private def alternateNetting : SettlementNettingEvidence := {
  event := settlementEventId
  effect := settlementEffectKey
  members := alternateMembers
}

private def targetAllocatedTotal
    (members : List NettingMember)
    (target : SettlementCommitmentId) : Int :=
  members.foldl
    (fun total member =>
      if member.target = target then total + member.quantity.quanta else total)
    0

private def memberSignedContribution?
    (commitments : List SettlementCommitment)
    (member : NettingMember) : Option Int := do
  let commitment ← findCommitment? commitments member.target
  if member.quantity.quanta <= 0 ||
      member.quantity.quanta > commitment.quantity.quanta then
    none
  else
    match commitment.debtor, commitment.creditor with
    | .household, .external _ =>
        some (-member.quantity.quanta)
    | .external _, .household =>
        some member.quantity.quanta
    | _, _ =>
        none

private def signedMemberTotal?
    (commitments : List SettlementCommitment) :
    List NettingMember -> Option Int
  | [] => some 0
  | member :: rest => do
      let head ← memberSignedContribution? commitments member
      let tail ← signedMemberTotal? commitments rest
      some (head + tail)

private def membersTargetBounded
    (commitments : List SettlementCommitment)
    (members : List NettingMember) : Bool :=
  commitments.all fun commitment =>
    targetAllocatedTotal members commitment.id <= commitment.quantity.quanta

private def membersUseSettlementMeasure
    (commitments : List SettlementCommitment)
    (measure : MeasureId)
    (members : List NettingMember) : Bool :=
  members.all fun member =>
    match findCommitment? commitments member.target with
    | none => false
    | some commitment =>
        commitment.measure = measure &&
        member.quantity.quanta > 0

private def nettingEvidenceAdmitted?
    (memory : EventMemory)
    (commitments : List SettlementCommitment)
    (evidence : SettlementNettingEvidence) : Bool :=
  match memory.findById? evidence.event with
  | none => false
  | some event =>
      match findEffectByKey? event evidence.effect with
      | none => false
      | some physical =>
          membersUseSettlementMeasure commitments physical.measure evidence.members &&
          membersTargetBounded commitments evidence.members &&
          match signedMemberTotal? commitments evidence.members with
          | none => false
          | some signedTotal =>
              signedTotal = physical.quantity.quanta

theorem explicit_netting_membership_explains_the_physical_minus_270 :
    (do
      let memory ← events?
      pure (
        nettingEvidenceAdmitted? memory grossCommitments selectedNetting,
        signedMemberTotal? grossCommitments selectedMembers,
        selectedMembers.map (fun member => member.quantity.quanta))) =
      some (true, some (-270), [1000, 700, 20, 50]) := by
  native_decide

/-!
## Pressure 2 — net physical quantity does not identify the gross composition

A different retained gross world can produce exactly the same -270 JPY physical
settlement:

    -900 + 600 - 20 + 50 = -270

Therefore the net Effect is not an authority for reconstructing the gross
members. Explicit attribution is independently observable.
-/

theorem different_gross_obligations_can_have_the_same_physical_net :
    (do
      let memory ← events?
      pure (
        nettingEvidenceAdmitted?
          memory grossCommitments selectedNetting,
        nettingEvidenceAdmitted?
          memory alternateGrossCommitments alternateNetting,
        signedMemberTotal? grossCommitments selectedMembers,
        signedMemberTotal? alternateGrossCommitments alternateMembers,
        selectedMembers ≠ alternateMembers)) =
      some (true, true, some (-270), some (-270), true) := by
  native_decide

/-!
## Finding

Opposite-direction net settlement is the first selected case where direct
SettlementEffectCorrespondence is intentionally the wrong abstraction.

The retained gross commitments answer:

    what independent obligations existed?

The physical net Effect answers:

    what cash actually moved?

Neither determines the other.

For:

    outgoing 1000
    incoming  700
    outgoing   20
    incoming   50

the one physical -270 Effect cannot directly satisfy every gross correspondence:

- some gross quantities exceed physical magnitude;
- incoming commitments have the opposite sign from the physical debit.

Weakening direct correspondence until all four rows pass would destroy the
meaning earned by Observation 364.

A distinct netting authority is therefore earned at the research level:

    SettlementNettingEvidence
      exact physical Event + EffectKey
      explicit members:
        target commitment
        exact positive contributed Quantity

with admission requiring:

    every member is positive and target-bounded
    every member uses the physical settlement Measure
    signed(member quantities from debtor/creditor direction)
      = physical Effect quantity

The gross commitments remain first-class facts. Netting does not replace them
with one synthetic commitment in retained history.

This is precisely why membership is semantic evidence rather than a convenience
group: two different gross obligation sets can produce the same physical -270
Effect.

## Architectural consequence

The settlement family is now separating into two physical correspondence modes:

    direct settlement
      one physical Effect directly supplies attributed quantity
      physical magnitude bounds correspondence quantity
      physical sign agrees with commitment direction

    net settlement
      one physical Effect is the signed result of several gross obligations
      explicit netting membership preserves those gross semantics
      signed member total equals the physical Effect

These should not be collapsed into one permissive correspondence record. Their
admission authorities differ.

Still not earned:

- production SettlementNettingEvidence;
- NettingId / version identity;
- correction semantics for a netting set;
- legally enforceable financial-market netting policy;
- automatic discovery of netting members;
- multi-currency netting;
- cross-counterparty netting;
- close-out/default netting;
- a universal Core group type.

The next pressure should test the boundary case:

    gross obligations offset exactly
    signed net = 0
    no physical cash Effect occurs

If zero-net settlement is a real supported workflow, an Effect-anchored netting
record is still too narrow because there may be no physical movement to anchor.

That question should be answered before production settlement persistence.
-/

end Loam.Observation365
