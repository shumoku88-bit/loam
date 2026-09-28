import Loam.Core.OpenRelation

namespace Loam.Core

set_option autoImplicit false

/-!
# Settlement vocabulary

The settlement research sequence beginning with Observations 359–360 and
continuing through later lifecycle probes qualified a family that remains
additive beside `OpenRelation`.

The distinction is intentional:

- `RelationUnit` remains source-Effect Measure and magnitude bounded;
- settlement commitments may carry an independently evidenced settlement Measure
  and Quantity;
- direct physical settlement and net settlement remain different semantic
  authorities;
- row correction reuses generic Application-level replacement-frontier mechanics;
- cross-family conservation belongs to a later admitted settlement image.

This module therefore contains raw retained provenance only.

It deliberately does **not** decide:

- whether referenced Events / Effects / commitments / contexts exist;
- whether quantities are positive;
- whether endpoint direction is currently supported;
- whether a physical Effect sign agrees with debtor / creditor direction;
- whether direct or net attribution exceeds one commitment;
- whether one physical Effect is reused across settlement modes;
- which revision rows are current;
- whether a netting outcome is arithmetically coherent.

Those are Application admission / projection questions.
-/

/--
Stable identity for one retained settlement commitment.

Identity is independent of source provenance, endpoints, settlement Measure, and
Quantity. The raw identifier does not itself imply revision semantics.
-/
structure SettlementCommitmentId where
  token : String
deriving Repr, DecidableEq

/--
One raw independently measured settlement obligation.

`sourceEvent` and `sourceEffect` preserve provenance for the fact that gave
rise to the obligation. Unlike `RelationUnit`, `measure` and `quantity` are
independent settlement evidence rather than values inherited or bounded by the
source Effect.

Direction belongs to `debtor` / `creditor`. Raw `Quantity` remains the
existing signed scalar; semantic admission later requires the positive magnitude
law qualified by the settlement observations.
-/
structure SettlementCommitment where
  id : SettlementCommitmentId
  sourceEvent : EventId
  sourceEffect : EffectKey
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
One append-only evidence-side revision of a retained settlement commitment.

Observation 376 qualified one family-specific authority for both positive
correction and explicit retraction:

- `replacement = some id` means the target row is superseded by another retained
  commitment version;
- `replacement = none` means the target row is explicitly retracted with no
  positive successor.

This is evidence lifecycle only. It must not be used for physical/net settlement
or for quantity-bearing non-settlement extinguishment.
-/
structure SettlementCommitmentRevision where
  target : SettlementCommitmentId
  replacement : Option SettlementCommitmentId
deriving Repr, DecidableEq

/--
Stable identity for one retained non-settlement extinguishment row.

Observation 377 showed that `target + quantity` is not enough: two independent
rows may share that coordinate, and append-only repair must be able to address
exactly one retained row.
-/
structure SettlementExtinguishmentId where
  token : String
deriving Repr, DecidableEq

/--
One exact non-settlement reduction of a valid settlement commitment.

This is not physical/net fulfillment and not commitment retraction. The target
commitment remains valid historical evidence while `quantity` records how much
later ceased to bind without settlement.

`effectiveOn` is optional semantic placement in the same practical ISO date
spelling used by Actual validity. Observation 378 requires absence to remain
meaningful: unknown placement must not be silently replaced by commitment date,
recording date, or today.
-/
structure SettlementCommitmentExtinguishment where
  id : SettlementExtinguishmentId
  target : SettlementCommitmentId
  quantity : Quantity
  effectiveOn : Option String := none
deriving Repr, DecidableEq

/--
Append-only evidence correction/retraction for extinguishment rows.

- `replacement = some id` corrects one retained extinguishment claim;
- `replacement = none` retracts an erroneous extinguishment claim.

This revises extinguishment evidence only. It does not retract the target
commitment.
-/
structure SettlementExtinguishmentRevision where
  target : SettlementExtinguishmentId
  replacement : Option SettlementExtinguishmentId
deriving Repr, DecidableEq

/--
Version-capable identity for one retained direct settlement correspondence.

Retained correspondence correction permits old and replacement rows to share
the same semantic coordinate `target + event + effect` while differing in
attributed Quantity. The retained row therefore needs identity distinct from
that coordinate when append-only correction is promised.
-/
structure SettlementCorrespondenceId where
  token : String
deriving Repr, DecidableEq

/--
One raw direct attribution from a later physical Effect to a settlement
commitment.

`quantity` records the exact positive magnitude attributed along this edge.
Reference closure, sign agreement, Measure equality, target bounds, physical
Effect bounds, and cross-mode conservation are later admission laws.
-/
structure SettlementEffectCorrespondence where
  id : SettlementCorrespondenceId
  target : SettlementCommitmentId
  event : EventId
  effect : EffectKey
  quantity : Quantity
deriving Repr, DecidableEq

/--
One append-only claim that a direct settlement correspondence is superseded by
another retained correspondence.

This raw edge carries settlement-specific revision authority. Structural
one-to-one frontier mechanics remain owned by
`Loam.Application.ReplacementFrontier`.
-/
structure SettlementCorrespondenceRevision where
  target : SettlementCorrespondenceId
  replacement : SettlementCorrespondenceId
deriving Repr, DecidableEq

/--
Stable identity for one netting / settlement occasion.

The same commitment may participate in more than one occasion. Context identity
therefore cannot be recovered from commitment identity alone.
-/
structure SettlementNettingContextId where
  token : String
deriving Repr, DecidableEq

/--
Physical outcome of one netting context.

Exact cancellation is represented explicitly as `zero`; it does not require a
synthetic zero-quantity physical Effect.

A nonzero outcome names the exact physical Effect whose signed Quantity must
later equal the derived signed member total.
-/
inductive NetSettlementOutcome where
  | zero
  | physical (event : EventId) (effect : EffectKey)
deriving Repr, DecidableEq

/--
One raw netting context.

The aggregate net amount is deliberately not stored. It is derived from current
member rows during Application admission / projection.
-/
structure SettlementNettingContext where
  id : SettlementNettingContextId
  measure : MeasureId
  outcome : NetSettlementOutcome
deriving Repr, DecidableEq

/--
Version-capable identity for one retained netting-member row.

Retained netting-member correction permits old and replacement rows to keep the
same semantic coordinate `context + target` while differing in Quantity.
-/
structure SettlementNettingMemberId where
  token : String
deriving Repr, DecidableEq

/--
One raw exact contribution of a settlement commitment to one netting context.

Direction is not duplicated here. The target commitment's debtor / creditor
orientation later determines the signed contribution to the context's derived
net amount.
-/
structure SettlementNettingMember where
  id : SettlementNettingMemberId
  context : SettlementNettingContextId
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

/--
One append-only claim that a netting-member row is superseded by another
retained member row.

Structural frontier laws are intentionally not duplicated in Core.
-/
structure SettlementNettingMemberRevision where
  target : SettlementNettingMemberId
  replacement : SettlementNettingMemberId
deriving Repr, DecidableEq

/--
Persistence-neutral retained aggregate for the base settlement family.

This is a raw collection boundary only. It does not imply that references,
replacement frontiers, netting arithmetic, or composed conservation have been
admitted. Those laws remain owned by the Application settlement image.
-/
structure SettlementEvidence where
  commitments : List SettlementCommitment
  commitmentRevisions : List SettlementCommitmentRevision := []
  extinguishments : List SettlementCommitmentExtinguishment := []
  extinguishmentRevisions : List SettlementExtinguishmentRevision := []
  correspondences : List SettlementEffectCorrespondence
  correspondenceRevisions : List SettlementCorrespondenceRevision
  nettingContexts : List SettlementNettingContext
  nettingMembers : List SettlementNettingMember
  nettingMemberRevisions : List SettlementNettingMemberRevision
deriving Repr, DecidableEq

/-- Empty retained settlement evidence for Actual generations with no settlement facts. -/
def SettlementEvidence.empty : SettlementEvidence := {
  commitments := []
  commitmentRevisions := []
  extinguishments := []
  extinguishmentRevisions := []
  correspondences := []
  correspondenceRevisions := []
  nettingContexts := []
  nettingMembers := []
  nettingMemberRevisions := []
}

end Loam.Core
