import Loam.Core.Event

namespace Loam.Observation294

open Loam.Core

set_option autoImplicit false

/-!
# Observation 294 — a user-created lot-like object crosses the stable-subject boundary

Observation 293 showed that user annotation, correction continuity, and several
provider aliases still do not force a new identity when all evidence can attach
to one retained provenance anchor.

This observation changes one premise.

The subject is now created by the user independently of provenance membership.
It may exist before any acquisition Effect is attached, keep notes while its
membership changes, and remain the same user-visible object after provider
aliases or graph members change.

That pressure is grounded in an existing accounting design: GnuCash can create
a new Lot before it is linked to any split; the Lot has editable title/notes and
its split membership can later be linked or unlinked. GnuCash also gives the Lot
its own GUID.

The code remains representation-neutral. It asks whether a user-created durable
subject can be reconstructed from its current payload.
-/

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

structure StableSubjectId where
  value : String
deriving Repr, DecidableEq

structure LineageEdge where
  source : EffectAnchor
  target : EffectAnchor
  units : Quantity
deriving Repr, DecidableEq

structure ExternalAlias where
  provider : String
  account : String
  lotId : String
deriving Repr, DecidableEq

structure SubjectPayload where
  title : String
  note : String
  members : List EffectAnchor
  lineage : List LineageEdge
  externalAliases : List ExternalAlias
deriving Repr, DecidableEq

structure SubjectSnapshot where
  subject : StableSubjectId
  payload : SubjectPayload
deriving Repr, DecidableEq

private def subjectA : StableSubjectId := ⟨"subject-A"⟩
private def subjectB : StableSubjectId := ⟨"subject-B"⟩

private def acquisitionA : EffectAnchor :=
  ⟨⟨"o294-acquisition-a"⟩, ⟨"o294-effect-a"⟩⟩

private def acquisitionB : EffectAnchor :=
  ⟨⟨"o294-acquisition-b"⟩, ⟨"o294-effect-b"⟩⟩

private def currentPosition : EffectAnchor :=
  ⟨⟨"o294-current"⟩, ⟨"o294-current-effect"⟩⟩

private def populatedPayload : SubjectPayload := {
  title := "retirement shares"
  note := "keep as one user-defined lot subject"
  members := [acquisitionA, acquisitionB]
  lineage := [
    {
      source := acquisitionA
      target := currentPosition
      units := Quantity.ofQuanta 2
    },
    {
      source := acquisitionB
      target := currentPosition
      units := Quantity.ofQuanta 1
    }
  ]
  externalAliases := [
    {
      provider := "custodian-a"
      account := "account-1"
      lotId := "A-17"
    },
    {
      provider := "custodian-b"
      account := "account-9"
      lotId := "B-8841"
    }
  ]
}

private def twinA : SubjectSnapshot := {
  subject := subjectA
  payload := populatedPayload
}

private def twinB : SubjectSnapshot := {
  subject := subjectB
  payload := populatedPayload
}

/--
Two independently created user subjects may have exactly the same current
provenance members, lineage, provider aliases, title, and note.

Therefore the current payload does not determine which user-created subject is
being referenced.
-/
theorem same_complete_payload_different_internal_subject :
    twinA.payload = twinB.payload ∧ twinA.subject ≠ twinB.subject := by
  native_decide

private def emptyPayload : SubjectPayload := {
  title := "Lot 0"
  note := "created before membership is known"
  members := []
  lineage := []
  externalAliases := []
}

private def retargetedPayload : SubjectPayload := {
  title := "retirement reserve"
  note := "same user subject after membership review"
  members := [acquisitionB]
  lineage := [{
    source := acquisitionB
    target := currentPosition
    units := Quantity.ofQuanta 1
  }]
  externalAliases := [{
    provider := "custodian-b"
    account := "account-9"
    lotId := "B-8841"
  }]
}

private def createdSnapshot : SubjectSnapshot := {
  subject := subjectA
  payload := emptyPayload
}

private def populatedSnapshot : SubjectSnapshot := {
  subject := subjectA
  payload := populatedPayload
}

private def retargetedSnapshot : SubjectSnapshot := {
  subject := subjectA
  payload := retargetedPayload
}

/--
The user-created subject can exist before it has any provenance member or
external alias.
-/
theorem subject_can_precede_provenance :
    createdSnapshot.subject = subjectA ∧
      createdSnapshot.payload.members = [] ∧
      createdSnapshot.payload.lineage = [] ∧
      createdSnapshot.payload.externalAliases = [] := by
  native_decide

/--
The subject remains the same while every obvious payload family is allowed to
change.

This is the crucial distinction from Observation 293: no retained provenance
anchor is being used as the identity of the user-created object.
-/
theorem stable_subject_survives_payload_change :
    createdSnapshot.subject = populatedSnapshot.subject ∧
      populatedSnapshot.subject = retargetedSnapshot.subject ∧
      createdSnapshot.payload ≠ populatedSnapshot.payload ∧
      populatedSnapshot.payload ≠ retargetedSnapshot.payload := by
  native_decide

/--
Even a complete populated graph plus several external ids is insufficient to
reconstruct user-object identity: another user-created subject may have the same
entire payload.
-/
theorem complete_graph_and_external_ids_do_not_determine_user_subject :
    populatedSnapshot.payload = twinB.payload ∧
      populatedSnapshot.subject ≠ twinB.subject := by
  native_decide

/-!
## Finding

This is the first selected pressure in the practical lot sequence that genuinely
earns some LOAM-owned stable subject identity in the observation model.

The reason is not tax arithmetic, basis, corporate-action topology, external lot
ids, or annotation by itself.

The reason is a stronger user-level semantic promise:

- the subject may exist before any provenance node belongs to it;
- its title and note may change;
- its provenance membership may change;
- its external aliases may change;
- two independently created subjects may have identical complete current
  payloads;
- references must still be able to distinguish which subject the user meant.

No function of the *current payload alone* can serve as that object identity
once the product promises independently created subjects with identical state.

That crosses the stable-subject boundary.

However this still does not decide the production representation.

The earned noun might be:

- an investment-local LotSubjectId;
- a generic StableSubjectId used by other user-created semantic groupings;
- or a content-derived lot key in a design that deliberately forbids two
  distinct subjects with identical keys.

External systems demonstrate more than one viable choice. GnuCash uses an
explicit Lot object / GUID. hledger's current lot specification instead defines
LotId from acquisition date plus optional label and preserves that identity
through transfers.

So Observation 294 earns the *need for identity only under the user-created
durable-object requirement*. It does not yet justify putting Core.LotId into
LOAM unconditionally.

If LOAM never offers independently created lot objects and continues to derive
lot-like answers from retained provenance, Observation 287-293 remain sufficient.

Not earned here:

- production LotId;
- placement in neutral Core;
- mutable object storage;
- lot editor UI;
- automatic mapping between a stable subject and provenance;
- tax policy;
- provider reconciliation authority.
-/

end Loam.Observation294
