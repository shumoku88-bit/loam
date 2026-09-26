import Loam.Core.EventMemory
import Loam.Core.OpenRelation

namespace Loam.Observation366

open Loam.Core

set_option autoImplicit false

/-!
# Observation 366 — zero-net settlement must not require a synthetic physical Effect

Observation 365 earned a distinct netting authority for opposite-direction gross
settlement obligations.

Its selected nonzero case retained:

    gross members
      -1000 + 700 - 20 + 50

    signed member total
      = -270

    physical cash Effect
      = -270 JPY

The next boundary is exact cancellation:

    household -> broker   1000
    broker -> household   1000

    signed member total
      = 0

There may be no physical cash movement to observe.

This is a real settlement shape. DTC end-of-day funds settlement nets intraday
debits and credits, and an end-of-day zero balance has no payment obligation
while still satisfying settlement obligations for the business day.

LOAM Core deliberately permits an Event with no Effects. It also permits exact
zero quantities structurally, because neutral Event / Effect Core does not assign
settlement meaning.

The question is therefore semantic:

> Should settlement netting invent a keyed zero-quantity Effect merely so every
> netting outcome has an Effect anchor?

This observation rejects that pressure. A zero-net outcome is an independently
meaningful result of explicit gross membership and should not require a synthetic
physical movement.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def settlementEventId : EventId := ⟨"o366-settlement-day"⟩
private def cashEffectKey : EffectKey := ⟨"o366-cash"⟩

private def emptySettlementEvent? : Option Event :=
  Event.ofEffects? settlementEventId []

private def syntheticZeroEvent? : Option Event :=
  Event.ofEffects? settlementEventId [
    Effect.ofQuantity
      cashEffectKey bank yen (Quantity.ofQuanta 0)
  ]

private def physicalDebitEvent? : Option Event :=
  Event.ofEffects? settlementEventId [
    Effect.ofQuantity
      cashEffectKey bank yen (Quantity.ofQuanta (-270))
  ]

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

private def broker : ExternalPartyId := ⟨"broker-counterparty"⟩

private def outgoingId : SettlementCommitmentId := ⟨"outgoing"⟩
private def incomingId : SettlementCommitmentId := ⟨"incoming"⟩

private def outgoing1000 : SettlementCommitment := {
  id := outgoingId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def incoming1000 : SettlementCommitment := {
  id := incomingId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def commitments : List SettlementCommitment :=
  [outgoing1000, incoming1000]

structure NettingMember where
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

private def members : List NettingMember := [
  ⟨outgoingId, Quantity.ofQuanta 1000⟩,
  ⟨incomingId, Quantity.ofQuanta 1000⟩
]

private def findCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

private def targetAllocatedTotal
    (members : List NettingMember)
    (target : SettlementCommitmentId) : Int :=
  members.foldl
    (fun total member =>
      if member.target = target then total + member.quantity.quanta else total)
    0

private def membersTargetBounded (members : List NettingMember) : Bool :=
  commitments.all fun commitment =>
    targetAllocatedTotal members commitment.id <= commitment.quantity.quanta

private def membersUseMeasure
    (measure : MeasureId)
    (members : List NettingMember) : Bool :=
  members.all fun member =>
    match findCommitment? member.target with
    | none => false
    | some commitment =>
        commitment.measure = measure &&
        member.quantity.quanta > 0

private def signedMemberContribution?
    (member : NettingMember) : Option Int := do
  let commitment ← findCommitment? member.target
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

private def signedMemberTotal? : List NettingMember -> Option Int
  | [] => some 0
  | member :: rest => do
      let head ← signedMemberContribution? member
      let tail ← signedMemberTotal? rest
      some (head + tail)

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

inductive NetSettlementOutcome where
  | zero
  | physical (anchor : EffectAnchor)
deriving Repr, DecidableEq

structure SettlementNettingEvidence where
  measure : MeasureId
  members : List NettingMember
  outcome : NetSettlementOutcome
deriving Repr, DecidableEq

private def zeroNetting : SettlementNettingEvidence := {
  measure := yen
  members := members
  outcome := .zero
}

private def syntheticZeroNetting : SettlementNettingEvidence := {
  measure := yen
  members := members
  outcome := .physical ⟨settlementEventId, cashEffectKey⟩
}

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def nettingEvidenceAdmitted?
    (memory : EventMemory)
    (evidence : SettlementNettingEvidence) : Bool :=
  if !membersUseMeasure evidence.measure evidence.members ||
      !membersTargetBounded evidence.members then
    false
  else
    match signedMemberTotal? evidence.members, evidence.outcome with
    | some 0, .zero =>
        true
    | some 0, .physical _ =>
        false
    | some total, .physical anchor =>
        match memory.findById? anchor.event with
        | none => false
        | some event =>
            match findEffectByKey? event anchor.effect with
            | none => false
            | some physical =>
                physical.measure = evidence.measure &&
                physical.quantity.quanta = total
    | _, _ =>
        false

/-!
## Pressure 1 — exact gross cancellation has a valid zero-net outcome
-/

theorem opposite_gross_obligations_can_settle_to_zero_without_cash_effect :
    signedMemberTotal? members = some 0 ∧
    membersTargetBounded members = true ∧
    membersUseMeasure yen members = true := by
  native_decide

/-!
## Pressure 2 — Core can retain a settlement-day Event without inventing movement
-/

theorem neutral_core_allows_an_event_with_no_effects :
    emptySettlementEvent?.isSome = true := by
  native_decide

/-!
## Pressure 3 — a synthetic zero Effect is structurally possible but is not the
## selected settlement authority

Neutral Core permits zero quantities. Settlement semantics must therefore make
the stronger choice itself rather than relying on Core construction failure.
-/

theorem synthetic_zero_effect_is_structurally_representable :
    syntheticZeroEvent?.isSome = true := by
  native_decide

private def emptyMemory? : Option EventMemory := do
  let event ← emptySettlementEvent?
  EventMemory.ofEvents? [event]

private def syntheticZeroMemory? : Option EventMemory := do
  let event ← syntheticZeroEvent?
  EventMemory.ofEvents? [event]

theorem zero_outcome_needs_no_physical_effect_anchor :
    (do
      let memory ← emptyMemory?
      pure (nettingEvidenceAdmitted? memory zeroNetting)) =
      some true := by
  native_decide

theorem zero_total_rejects_synthetic_physical_anchor_as_settlement_authority :
    (do
      let memory ← syntheticZeroMemory?
      pure (nettingEvidenceAdmitted? memory syntheticZeroNetting)) =
      some false := by
  native_decide

/-!
## Pressure 4 — nonzero net settlement still requires exact physical evidence
-/

private def outgoing1020 : SettlementCommitment := {
  outgoing1000 with
  quantity := Quantity.ofQuanta 1020
}

private def nonzeroCommitments : List SettlementCommitment :=
  [outgoing1020, incoming1000]

private def nonzeroMembers : List NettingMember := [
  ⟨outgoingId, Quantity.ofQuanta 1020⟩,
  ⟨incomingId, Quantity.ofQuanta 750⟩
]

private def findNonzeroCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  nonzeroCommitments.find? fun commitment => commitment.id = id

private def nonzeroContribution?
    (member : NettingMember) : Option Int := do
  let commitment ← findNonzeroCommitment? member.target
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

private def nonzeroSignedTotal? : List NettingMember -> Option Int
  | [] => some 0
  | member :: rest => do
      let head ← nonzeroContribution? member
      let tail ← nonzeroSignedTotal? rest
      some (head + tail)

theorem selected_nonzero_members_total_minus_270 :
    nonzeroSignedTotal? nonzeroMembers = some (-270) := by
  native_decide

/-!
## Finding

Observation 365's Effect-anchored netting evidence is sufficient only for a
nonzero physical net result.

A real settlement system may instead have:

    retained gross obligations
    signed member total = 0
    settlement obligations satisfied
    no payment obligation
    no physical cash movement

Requiring every such result to point at an Effect would force one of two
unearned representations:

1. invent a synthetic 0-quantity physical Effect;
2. refuse to represent a completed zero-net settlement.

Neither is necessary.

The minimum research candidate therefore separates outcome from membership:

    SettlementNettingEvidence
      settlement Measure
      explicit gross members
      outcome:
        zero
        | physical EffectAnchor

Admission is asymmetric:

    signed total = 0
      -> outcome must be zero
      -> no physical Effect required

    signed total != 0
      -> outcome must be physical
      -> exact Effect Measure / Quantity must equal the signed total

The zero branch is not an accounting Effect. It is a semantic settlement result
derived from retained gross membership.

This preserves neutral Core:

    Event may legitimately have no Effects
    Effect may structurally carry zero
    neither Core fact decides settlement meaning

and keeps settlement authority in the settlement family.

## Architectural consequence

The current research boundary becomes:

    gross SettlementCommitments
      retain independent obligations

    direct SettlementEffectCorrespondence
      physical Effect directly settles one-direction quantities

    SettlementNettingEvidence
      explicit gross membership
      signed aggregate

      outcome:
        physical Effect for nonzero net
        zero for exact cancellation

No synthetic cash event or zero Effect is required.

Still not earned:

- production persistence;
- a stable NettingId;
- correction / replacement semantics for netting evidence;
- date / settlement-cycle identity;
- partial publication of netting members;
- multi-currency netting;
- cross-counterparty netting;
- legal close-out/default netting;
- automatic member inference;
- a universal Core settlement primitive.

The next pressure should determine whether one netting fact needs stable identity
for correction.

A correction can preserve the same gross member coordinates while changing
member quantities or membership, exactly as correspondence correction previously
earned version identity.

That question should be tested before choosing production persistence.
-/

end Loam.Observation366
