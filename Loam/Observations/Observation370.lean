import Loam.Core.EventMemory
import Loam.Core.OpenRelation

namespace Loam.Observation370

open Loam.Core

set_option autoImplicit false

/-!
# Observation 370 — direct and net settlement need one composed conservation boundary

Observations 359-369 qualified the settlement pieces separately:

- cross-Measure SettlementCommitment;
- exact direct Effect correspondence;
- bidirectional debtor / creditor orientation;
- explicit netting membership;
- zero-net outcome without synthetic cash;
- member-row correction;
- optional as-finalized publication.

A consolidation pass exposes one composition question that none of those local
observations could answer alone.

Suppose one commitment is partly settled directly and also participates in a
netting context.

Each family can be locally valid while their combined attribution exceeds the
commitment quantity.

Likewise, one physical Effect can satisfy a netting equation exactly while a
direct correspondence independently claims part of that same Effect.

Those are cross-family double-use bugs.

The production boundary therefore cannot be only:

    direct rules
    +
    netting rules

It also needs shared conservation across both modes without collapsing their
different semantic authorities into one permissive row type.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def directEventId : EventId := ⟨"o370-direct"⟩
private def directEffectKey : EffectKey := ⟨"o370-direct-cash"⟩

private def netEventId : EventId := ⟨"o370-net"⟩
private def netEffectKey : EffectKey := ⟨"o370-net-cash"⟩

private def directEvent? : Option Event :=
  Event.ofEffects? directEventId [
    Effect.ofQuantity
      directEffectKey bank yen (Quantity.ofQuanta (-700))
  ]

private def netEvent? : Option Event :=
  Event.ofEffects? netEventId [
    Effect.ofQuantity
      netEffectKey bank yen (Quantity.ofQuanta (-300))
  ]

private def events? : Option EventMemory := do
  let directEvent ← directEvent?
  let netEvent ← netEvent?
  EventMemory.ofEvents? [directEvent, netEvent]

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

private def outgoingId : SettlementCommitmentId := ⟨"outgoing"⟩
private def incomingId : SettlementCommitmentId := ⟨"incoming"⟩
private def extraOutgoingId : SettlementCommitmentId := ⟨"extra-outgoing"⟩

private def outgoing1000 : SettlementCommitment := {
  id := outgoingId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def incoming700 : SettlementCommitment := {
  id := incomingId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 700
}

private def extraOutgoing100 : SettlementCommitment := {
  id := extraOutgoingId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 100
}

private def commitments : List SettlementCommitment :=
  [outgoing1000, incoming700, extraOutgoing100]

private def findCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def directAnchor : EffectAnchor :=
  ⟨directEventId, directEffectKey⟩

private def netAnchor : EffectAnchor :=
  ⟨netEventId, netEffectKey⟩

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def anchoredEffect?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Effect := do
  let event ← memory.findById? anchor.event
  findEffectByKey? event anchor.effect

private def magnitude (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

private def signAgrees
    (commitment : SettlementCommitment)
    (physical : Effect) : Bool :=
  match commitment.debtor, commitment.creditor with
  | .household, .external _ => physical.quantity.quanta < 0
  | .external _, .household => physical.quantity.quanta > 0
  | _, _ => false

structure DirectCorrespondence where
  target : SettlementCommitmentId
  physical : EffectAnchor
  quantity : Quantity
deriving Repr, DecidableEq

private def directLocallyAdmitted?
    (memory : EventMemory)
    (row : DirectCorrespondence) : Bool :=
  match findCommitment? row.target, anchoredEffect? memory row.physical with
  | some commitment, some physical =>
      row.quantity.quanta > 0 &&
      commitment.quantity.quanta > 0 &&
      physical.measure = commitment.measure &&
      signAgrees commitment physical &&
      row.quantity.quanta <= commitment.quantity.quanta &&
      row.quantity.quanta <= magnitude physical.quantity
  | _, _ => false

structure NettingContextId where
  token : String
deriving Repr, DecidableEq

inductive NetSettlementOutcome where
  | zero
  | physical (anchor : EffectAnchor)
deriving Repr, DecidableEq

structure NettingContext where
  id : NettingContextId
  measure : MeasureId
  outcome : NetSettlementOutcome
deriving Repr, DecidableEq

structure NettingMember where
  context : NettingContextId
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

private def selectedContextId : NettingContextId := ⟨"selected"⟩

private def selectedContext : NettingContext := {
  id := selectedContextId
  measure := yen
  outcome := .physical netAnchor
}

private def selectedMembers : List NettingMember := [
  {
    context := selectedContextId
    target := outgoingId
    quantity := Quantity.ofQuanta 600
  },
  {
    context := selectedContextId
    target := incomingId
    quantity := Quantity.ofQuanta 300
  }
]

private def memberSignedContribution?
    (context : NettingContext)
    (member : NettingMember) : Option Int := do
  let commitment ← findCommitment? member.target
  if member.context != context.id ||
      member.quantity.quanta <= 0 ||
      member.quantity.quanta > commitment.quantity.quanta ||
      commitment.measure != context.measure then
    none
  else
    match commitment.debtor, commitment.creditor with
    | .household, .external _ => some (-member.quantity.quanta)
    | .external _, .household => some member.quantity.quanta
    | _, _ => none

private def signedTotal?
    (context : NettingContext) : List NettingMember -> Option Int
  | [] => some 0
  | member :: rest => do
      let head ← memberSignedContribution? context member
      let tail ← signedTotal? context rest
      some (head + tail)

private def netContextLocallyAdmitted?
    (memory : EventMemory)
    (context : NettingContext)
    (members : List NettingMember) : Bool :=
  match signedTotal? context members, context.outcome with
  | some 0, .zero => true
  | some 0, .physical _ => false
  | some total, .physical anchor =>
      match anchoredEffect? memory anchor with
      | none => false
      | some physical =>
          physical.measure = context.measure &&
          physical.quantity.quanta = total
  | _, _ => false

/-!
## Pressure 1 — local rules permit cross-mode over-settlement of one commitment

The same 1000-JPY outgoing commitment can be locally attributed as:

    direct 700
    net member 600

Each row is individually bounded by the 1000 commitment.

The netting context itself remains exactly tied to -300 physical cash:

    -600 + 300 = -300

But the combined target use is 1300.
-/

private def targetOveruseDirect : DirectCorrespondence := {
  target := outgoingId
  physical := directAnchor
  quantity := Quantity.ofQuanta 700
}

private def validDirect : DirectCorrespondence := {
  target := outgoingId
  physical := directAnchor
  quantity := Quantity.ofQuanta 400
}

theorem local_families_can_accept_cross_mode_target_overuse :
    (do
      let memory ← events?
      pure (
        directLocallyAdmitted? memory targetOveruseDirect,
        netContextLocallyAdmitted? memory selectedContext selectedMembers)) =
      some (true, true) := by
  native_decide

private def directTargetTotal
    (rows : List DirectCorrespondence)
    (target : SettlementCommitmentId) : Int :=
  rows.foldl
    (fun total row =>
      if row.target = target then total + row.quantity.quanta else total)
    0

private def netTargetTotal
    (members : List NettingMember)
    (target : SettlementCommitmentId) : Int :=
  members.foldl
    (fun total member =>
      if member.target = target then total + member.quantity.quanta else total)
    0

private def targetBudgetRespected
    (directRows : List DirectCorrespondence)
    (members : List NettingMember) : Bool :=
  commitments.all fun commitment =>
    directTargetTotal directRows commitment.id +
      netTargetTotal members commitment.id <= commitment.quantity.quanta

theorem composed_target_budget_rejects_1300_against_1000 :
    directTargetTotal [targetOveruseDirect] outgoingId = 700 ∧
    netTargetTotal selectedMembers outgoingId = 600 ∧
    targetBudgetRespected [targetOveruseDirect] selectedMembers = false := by
  native_decide

theorem valid_mixed_target_use_can_exactly_consume_the_commitment :
    directTargetTotal [validDirect] outgoingId = 400 ∧
    netTargetTotal selectedMembers outgoingId = 600 ∧
    targetBudgetRespected [validDirect] selectedMembers = true := by
  native_decide

/-!
## Pressure 2 — local rules also permit cross-mode reuse of one physical Effect

The selected netting context already explains the whole -300 physical Effect.

A separate 100-JPY direct correspondence for another outgoing commitment can
nevertheless pass its own local rule against that same -300 Effect.

That would count one physical movement under two incompatible authorities.
-/

private def conflictingDirectPhysical : DirectCorrespondence := {
  target := extraOutgoingId
  physical := netAnchor
  quantity := Quantity.ofQuanta 100
}

theorem local_families_can_accept_cross_mode_physical_reuse :
    (do
      let memory ← events?
      pure (
        directLocallyAdmitted? memory conflictingDirectPhysical,
        netContextLocallyAdmitted? memory selectedContext selectedMembers)) =
      some (true, true) := by
  native_decide

private def contextPhysicalAnchor?
    (context : NettingContext) : Option EffectAnchor :=
  match context.outcome with
  | .zero => none
  | .physical anchor => some anchor

private def directUsesAnchor
    (rows : List DirectCorrespondence)
    (anchor : EffectAnchor) : Bool :=
  rows.any fun row => row.physical = anchor

private def netPhysicalExclusive
    (directRows : List DirectCorrespondence)
    (contexts : List NettingContext) : Bool :=
  contexts.all fun context =>
    match contextPhysicalAnchor? context with
    | none => true
    | some anchor => !directUsesAnchor directRows anchor

private def physicalNetAnchorsUnique
    (contexts : List NettingContext) : Bool :=
  let anchors := contexts.filterMap contextPhysicalAnchor?
  anchors.Nodup

theorem net_physical_outcome_must_be_exclusive_from_direct_use :
    netPhysicalExclusive [conflictingDirectPhysical] [selectedContext] = false ∧
    netPhysicalExclusive [validDirect] [selectedContext] = true := by
  native_decide

/-!
## Pressure 3 — a valid mixed world should remain representable

The composed laws must not ban a legitimate hybrid history.

Here:

    outgoing commitment 1000

is settled:

    direct 400
    net member 600

while the net context also contains:

    incoming member 300

so:

    net physical = -300

The direct and net physical Effects are distinct.
-/

private def allLocallyAdmitted?
    (memory : EventMemory)
    (directRows : List DirectCorrespondence)
    (contexts : List (NettingContext × List NettingMember)) : Bool :=
  directRows.all (directLocallyAdmitted? memory) &&
  contexts.all fun entry =>
    netContextLocallyAdmitted? memory entry.1 entry.2

private def composedAdmitted?
    (memory : EventMemory)
    (directRows : List DirectCorrespondence)
    (contexts : List (NettingContext × List NettingMember)) : Bool :=
  let contextHeaders := contexts.map Prod.fst
  let allMembers := contexts.flatMap Prod.snd
  allLocallyAdmitted? memory directRows contexts &&
  targetBudgetRespected directRows allMembers &&
  netPhysicalExclusive directRows contextHeaders &&
  physicalNetAnchorsUnique contextHeaders

theorem valid_direct_plus_net_composition_is_admitted :
    (do
      let memory ← events?
      pure (
        composedAdmitted?
          memory
          [validDirect]
          [(selectedContext, selectedMembers)])) =
      some true := by
  native_decide

theorem cross_mode_target_overuse_is_rejected_only_at_composed_boundary :
    (do
      let memory ← events?
      pure (
        allLocallyAdmitted?
          memory
          [targetOveruseDirect]
          [(selectedContext, selectedMembers)],
        composedAdmitted?
          memory
          [targetOveruseDirect]
          [(selectedContext, selectedMembers)])) =
      some (true, false) := by
  native_decide

theorem cross_mode_physical_reuse_is_rejected_only_at_composed_boundary :
    (do
      let memory ← events?
      pure (
        allLocallyAdmitted?
          memory
          [conflictingDirectPhysical]
          [(selectedContext, selectedMembers)],
        composedAdmitted?
          memory
          [conflictingDirectPhysical]
          [(selectedContext, selectedMembers)])) =
      some (true, false) := by
  native_decide

/-!
## Finding

The consolidation pass finds one missing production-level invariant.

Direct settlement and net settlement have intentionally different local
authorities and should remain different evidence families.

But their admitted current views must compose through one shared conservation
boundary.

### Shared target conservation

For every SettlementCommitment:

    direct current correspondence quantity
      +
    current netting-member quantity across all contexts
      <= commitment quantity

This prevents the same semantic obligation from being discharged twice through
different settlement modes.

The law must span contexts because Observation 367 established that one
commitment may legitimately participate in more than one settlement occasion.

### Shared physical-use conservation

A nonzero netting context explains the exact whole physical Effect:

    signed current members = physical Effect quantity

Therefore that physical Effect must not simultaneously serve direct settlement
correspondences.

Likewise, two independent netting contexts must not both claim the same physical
Effect anchor under the current candidate.

This is not a reason to merge direct correspondence and netting into one type.

It is a reason to admit them together through one composed read/application
boundary.

### Zero-net remains clean

A zero-net context has no physical Effect anchor, so it participates in target
conservation but consumes no physical Effect.

No synthetic zero Effect is required.

## Production consequence

The minimum reusable settlement family is not ready as several unrelated local
memories.

It needs one admitted settlement image / projection that can see:

    commitments
    current direct correspondence frontier
    current netting-member frontier
    netting contexts / outcomes
    physical Event memory

and enforce cross-mode conservation before callers receive exact outstanding or
settled answers.

This boundary can reuse:

    Event / Effect / Quantity
    RelationEndpoint / ExternalPartyId
    ReplacementFrontier mechanics

without adding settlement meaning to neutral Core.

## What this consolidation still does not require

- one universal Settlement row;
- broadening OpenRelation;
- a universal group primitive;
- aggregate mutable net amounts;
- synthetic zero cash Effects;
- finality for ordinary household payments;
- fee/tax component ownership inside settlement;
- FX valuation semantics;
- automatic matching;
- legal close-out/default netting.

## Next step

With the cross-mode conservation seam now explicit, the next step should be the
actual production promotion checkpoint.

That checkpoint should choose:

1. the smallest Core/domain vocabulary;
2. one Application admitted-settlement image that owns composed conservation;
3. which evidence enters the first production persistence slice;
4. which layers remain optional:
   - complete allocation publication;
   - finality publication;
5. a stop condition that prevents securities-market semantics from becoming
   mandatory household-accounting machinery.
-/

end Loam.Observation370
