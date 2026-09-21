import Loam.Observations.Observation295
import Loam.Core.Scheduled
import Loam.Core.Attention
import Loam.Core.OpenRelation
import Loam.Core.Capacity
import Loam.Core.ActualValidityHistory

namespace Loam.Observation296

open Loam.Core

set_option autoImplicit false

/-!
# Observation 296 — existing production identities are representationally generic,
# but semantically already separated

Observation 295 found a useful research shape:

    StableSubjectId Domain

The next temptation is to replace established production identities such as
EventId, ScheduledId, AttentionId, RelationUnitId, CapacityMovementId, and
ActualValidityRevisionId with one generic domain-indexed wrapper.

This observation separates two questions:

1. Representation:
   can one typed String wrapper represent the existing identities without losing
   equality information?

2. Architecture:
   would doing so collapse enough real production mechanics to justify replacing
   the existing semantic type names?

The first answer is yes. The second does not follow.
-/

inductive EventDomain
deriving Repr, DecidableEq

inductive ScheduledDomain
deriving Repr, DecidableEq

inductive AttentionDomain
deriving Repr, DecidableEq

inductive RelationUnitDomain
deriving Repr, DecidableEq

inductive CapacityMovementDomain
deriving Repr, DecidableEq

inductive ActualValidityRevisionDomain
deriving Repr, DecidableEq

abbrev TypedId := Loam.Observation295.StableSubjectId

/--
The generic representation has one reusable injectivity proof for its token
projection.
-/
theorem typedId_value_injective {Domain : Type} :
    Function.Injective (fun id : TypedId Domain => id.value) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

/-! ## Event identity -/

def eventToTyped (id : EventId) : TypedId EventDomain :=
  ⟨id.token⟩

def typedToEvent (id : TypedId EventDomain) : EventId :=
  ⟨id.value⟩

@[simp] theorem event_roundTrip_fromProduction (id : EventId) :
    typedToEvent (eventToTyped id) = id := by
  cases id
  rfl

@[simp] theorem event_roundTrip_fromTyped (id : TypedId EventDomain) :
    eventToTyped (typedToEvent id) = id := by
  cases id
  rfl

/-! ## Scheduled identity -/

def scheduledToTyped (id : ScheduledId) : TypedId ScheduledDomain :=
  ⟨id.token⟩

def typedToScheduled (id : TypedId ScheduledDomain) : ScheduledId :=
  ⟨id.value⟩

@[simp] theorem scheduled_roundTrip_fromProduction (id : ScheduledId) :
    typedToScheduled (scheduledToTyped id) = id := by
  cases id
  rfl

@[simp] theorem scheduled_roundTrip_fromTyped (id : TypedId ScheduledDomain) :
    scheduledToTyped (typedToScheduled id) = id := by
  cases id
  rfl

/-! ## Attention identity -/

def attentionToTyped (id : AttentionId) : TypedId AttentionDomain :=
  ⟨id.token⟩

def typedToAttention (id : TypedId AttentionDomain) : AttentionId :=
  ⟨id.value⟩

@[simp] theorem attention_roundTrip_fromProduction (id : AttentionId) :
    typedToAttention (attentionToTyped id) = id := by
  cases id
  rfl

@[simp] theorem attention_roundTrip_fromTyped (id : TypedId AttentionDomain) :
    attentionToTyped (typedToAttention id) = id := by
  cases id
  rfl

/-! ## Relation-unit identity -/

def relationToTyped (id : RelationUnitId) : TypedId RelationUnitDomain :=
  ⟨id.token⟩

def typedToRelation (id : TypedId RelationUnitDomain) : RelationUnitId :=
  ⟨id.value⟩

@[simp] theorem relation_roundTrip_fromProduction (id : RelationUnitId) :
    typedToRelation (relationToTyped id) = id := by
  cases id
  rfl

@[simp] theorem relation_roundTrip_fromTyped (id : TypedId RelationUnitDomain) :
    relationToTyped (typedToRelation id) = id := by
  cases id
  rfl

/-! ## Capacity-movement identity -/

def capacityToTyped (id : CapacityMovementId) : TypedId CapacityMovementDomain :=
  ⟨id.token⟩

def typedToCapacity (id : TypedId CapacityMovementDomain) : CapacityMovementId :=
  ⟨id.value⟩

@[simp] theorem capacity_roundTrip_fromProduction (id : CapacityMovementId) :
    typedToCapacity (capacityToTyped id) = id := by
  cases id
  rfl

@[simp] theorem capacity_roundTrip_fromTyped (id : TypedId CapacityMovementDomain) :
    capacityToTyped (typedToCapacity id) = id := by
  cases id
  rfl

/-! ## Actual-validity revision identity -/

def revisionToTyped
    (id : ActualValidityRevisionId) : TypedId ActualValidityRevisionDomain :=
  ⟨id.token⟩

def typedToRevision
    (id : TypedId ActualValidityRevisionDomain) : ActualValidityRevisionId :=
  ⟨id.value⟩

@[simp] theorem revision_roundTrip_fromProduction
    (id : ActualValidityRevisionId) :
    typedToRevision (revisionToTyped id) = id := by
  cases id
  rfl

@[simp] theorem revision_roundTrip_fromTyped
    (id : TypedId ActualValidityRevisionDomain) :
    revisionToTyped (typedToRevision id) = id := by
  cases id
  rfl

/-! ## Same token spelling does not imply same semantic identity family -/

private def eventSameSpelling : EventId := ⟨"shared-1"⟩
private def scheduledSameSpelling : ScheduledId := ⟨"shared-1"⟩
private def attentionSameSpelling : AttentionId := ⟨"shared-1"⟩

/--
Erasing the domain makes unrelated identities look equal at the String level.
The current named wrappers already prevent that accidental join, just as the
domain-indexed representation would.
-/
theorem erasing_family_recreates_cross_domain_collision :
    (eventToTyped eventSameSpelling).value =
        (scheduledToTyped scheduledSameSpelling).value ∧
      (scheduledToTyped scheduledSameSpelling).value =
        (attentionToTyped attentionSameSpelling).value := by
  native_decide

/-!
## Semantic ownership does not become generic

The generic wrapper can represent the identity token, but the evidence that
refers to each identity still has a different meaning.

These tiny projections intentionally keep the production semantic owners in the
types below.
-/

structure EventReference where
  event : EventId
deriving Repr, DecidableEq

structure ScheduledReference where
  scheduled : ScheduledId
deriving Repr, DecidableEq

structure AttentionReference where
  attention : AttentionId
deriving Repr, DecidableEq

structure RelationReference where
  relation : RelationUnitId
deriving Repr, DecidableEq

structure CapacityReference where
  movement : CapacityMovementId
deriving Repr, DecidableEq

structure RevisionReference where
  revision : ActualValidityRevisionId
deriving Repr, DecidableEq

private def eventRef : EventReference := ⟨⟨"shared-1"⟩⟩
private def scheduledRef : ScheduledReference := ⟨⟨"shared-1"⟩⟩
private def attentionRef : AttentionReference := ⟨⟨"shared-1"⟩⟩
private def relationRef : RelationReference := ⟨⟨"shared-1"⟩⟩
private def capacityRef : CapacityReference := ⟨⟨"shared-1"⟩⟩
private def revisionRef : RevisionReference := ⟨⟨"shared-1"⟩⟩

/--
All six semantic families may use the same String spelling without becoming one
identity namespace.
-/
theorem same_spelling_survives_semantic_family_separation :
    eventRef.event.token = "shared-1" ∧
      scheduledRef.scheduled.token = "shared-1" ∧
      attentionRef.attention.token = "shared-1" ∧
      relationRef.relation.token = "shared-1" ∧
      capacityRef.movement.token = "shared-1" ∧
      revisionRef.revision.token = "shared-1" := by
  native_decide

/-!
## Finding

The representation experiment succeeds completely.

Every selected production identity is isomorphic, for the retained token/equality
question, to:

    StableSubjectId Domain

and one generic projection-injectivity theorem can replace repeated tiny
proofs that a one-field String wrapper is injective.

But this does not mean production should be rewritten around one generic
identity type.

The semantic distinctions remain:

- EventId identifies an observed occurrence and is referenced by Actual evidence,
  descriptions, corrections, reversals, relations, and Scheduled completion.
- ScheduledId identifies an expected occurrence with its own replacement,
  completion, cancellation, and routing lifecycle.
- AttentionId identifies an independently closable household matter.
- RelationUnitId distinguishes relation units even when source/endpoints/quantity
  are otherwise equal, because discharge evidence can target one unit.
- CapacityMovementId identifies one capacity-authority occurrence and is the
  subject of independent effective-coordinate evidence.
- ActualValidityRevisionId exists only for later temporal revisions; the base
  occurrence-date fact deliberately has no separate identity.

Those are different reasons for identity, not instances of one household
"Subject" ontology.

More importantly, LOAM already shares the substantial mechanics beneath them:

- FiniteKeyed shares keyed-list lookup and freshness-preserving Nodup proofs;
- hash-backed admission shares finite uniqueness mechanics;
- firstUnusedNumberedToken shares total fresh-token allocation.

So a production conversion to one domain-indexed wrapper would currently remove
mostly:

- repeated one-field wrapper declarations;
- several tiny token-injectivity lemmas;
- some constructor spelling.

It would not remove the domain-specific lifecycle, authority, persistence,
admission, or query logic that gives each identity its meaning.

Therefore the generic form is a useful *representation theorem* and a useful
pattern for future identities, but a full production identity refactor is not
yet earned.

A stronger production case would require repeated mechanics that still remain
because the current distinct wrappers prevent a safe generic implementation.
The selected audit did not find such a blocker: the meaningful shared mechanics
are already generic below the identity layer.

Current recommendation from this observation:

    keep named production identity types
    +
    reuse generic mechanics underneath
    +
    use domain-indexed identity as a design pattern for genuinely new
      cross-domain stable-subject work if it becomes production-required

Not earned here:

- replacing EventId / ScheduledId / AttentionId / RelationUnitId /
  CapacityMovementId / ActualValidityRevisionId;
- a global identity registry;
- a universal Subject type;
- cross-family equality;
- shared lifecycle semantics;
- production StableSubjectId.
-/

end Loam.Observation296
