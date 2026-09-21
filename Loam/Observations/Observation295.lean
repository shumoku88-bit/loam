import Loam.Core.Event

namespace Loam.Observation295

open Loam.Core

set_option autoImplicit false

/-!
# Observation 295 — stable subject compression needs semantic domain indexing

Observation 204 and Observation 294 reached stable-subject pressure from
different directions.

Observation 204:
- one future subject may be known before exact amount or due evidence exists;
- amount and due remain independently attachable;
- loose identity-free pools do not preserve subject-specific pairing.

Observation 294:
- one user-created lot-like subject may exist before provenance membership;
- title, note, provenance members, and provider aliases may all change;
- two independently created subjects may have identical complete current
  payloads and still need to remain distinguishable.

This observation asks whether one tiny stable-subject abstraction can express
both pressures without turning LOAM into one untyped global identity space.

The selected candidate shares only the *shape* of stable identity:

    StableSubjectId Domain

The phantom semantic domain is part of the type. Evidence remains
domain-specific and independently attached.

This tests a narrower claim than "LOAM should add StableSubjectId to Core".
-/

/-- Semantic domains remain deliberately empty marker types. -/
inductive PreScheduledDomain
deriving Repr, DecidableEq

inductive LotDomain
deriving Repr, DecidableEq

/--
One stable identity shape indexed by the semantic domain that owns it.

The raw token representation may be the same, but values from different domains
have different Lean types and therefore cannot be silently joined.
-/
structure StableSubjectId (Domain : Type) where
  value : String
deriving Repr, DecidableEq

/-- A tiny reusable subject-attached carrier. The value type stays domain-local. -/
structure Attached (Domain : Type) (Value : Type) where
  subject : StableSubjectId Domain
  value : Value
deriving Repr, DecidableEq

private def scheduledA : StableSubjectId PreScheduledDomain :=
  ⟨"subject-1"⟩

private def scheduledB : StableSubjectId PreScheduledDomain :=
  ⟨"subject-2"⟩

private def lotA : StableSubjectId LotDomain :=
  ⟨"subject-1"⟩

private def lotB : StableSubjectId LotDomain :=
  ⟨"subject-2"⟩

/--
The textual token can be identical across domains without creating semantic
identity across those domains.
-/
theorem same_token_spelling_can_be_domain_local :
    scheduledA.value = lotA.value ∧
      scheduledB.value = lotB.value := by
  native_decide

/-! ## Pre-Scheduled pressure -/

structure Due where
  day : Nat
deriving Repr, DecidableEq

structure PreScheduledWorld where
  known : List (StableSubjectId PreScheduledDomain)
  amounts : List (Attached PreScheduledDomain Int)
  dues : List (Attached PreScheduledDomain Due)
deriving Repr, DecidableEq

private def futureLeft : PreScheduledWorld := {
  known := [scheduledA, scheduledB]
  amounts := [
    ⟨scheduledA, 1000⟩,
    ⟨scheduledB, 2000⟩
  ]
  dues := [
    ⟨scheduledA, ⟨10⟩⟩,
    ⟨scheduledB, ⟨20⟩⟩
  ]
}

private def futureRight : PreScheduledWorld := {
  known := [scheduledA, scheduledB]
  amounts := [
    ⟨scheduledA, 1000⟩,
    ⟨scheduledB, 2000⟩
  ]
  dues := [
    ⟨scheduledA, ⟨20⟩⟩,
    ⟨scheduledB, ⟨10⟩⟩
  ]
}

private def amountPool (world : PreScheduledWorld) : List Int :=
  world.amounts.map Attached.value

private def duePool (world : PreScheduledWorld) : List Due :=
  world.dues.map Attached.value

private def dueFor?
    (world : PreScheduledWorld)
    (subject : StableSubjectId PreScheduledDomain) : Option Due := do
  let row ← world.dues.find? fun item => decide (item.subject = subject)
  pure row.value

/--
The selected Observation-204 pressure survives: the loose amount values are
equal, and both worlds contain the same two due values, but subject-specific
pairing still differs.

The list order is deliberately not treated as semantic authority here. The
selected witness compares membership in the loose due pool instead.
-/
theorem loose_future_pools_do_not_determine_pairing :
    amountPool futureLeft = amountPool futureRight ∧
      (duePool futureLeft).contains ⟨10⟩ = true ∧
      (duePool futureLeft).contains ⟨20⟩ = true ∧
      (duePool futureRight).contains ⟨10⟩ = true ∧
      (duePool futureRight).contains ⟨20⟩ = true ∧
      dueFor? futureLeft scheduledA = some ⟨10⟩ ∧
      dueFor? futureRight scheduledA = some ⟨20⟩ := by
  native_decide

/-! ## User-created lot-like subject pressure -/

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

structure ExternalAlias where
  provider : String
  account : String
  externalId : String
deriving Repr, DecidableEq

structure LotPayload where
  title : String
  note : String
  members : List EffectAnchor
  aliases : List ExternalAlias
deriving Repr, DecidableEq

structure LotSnapshot where
  subject : StableSubjectId LotDomain
  payload : LotPayload
deriving Repr, DecidableEq

private def anchor : EffectAnchor :=
  ⟨⟨"o295-event"⟩, ⟨"o295-effect"⟩⟩

private def sameLotPayload : LotPayload := {
  title := "retirement reserve"
  note := "user-created durable subject"
  members := [anchor]
  aliases := [{
    provider := "custodian-x"
    account := "account-1"
    externalId := "LOT-7"
  }]
}

private def lotTwinA : LotSnapshot := {
  subject := lotA
  payload := sameLotPayload
}

private def lotTwinB : LotSnapshot := {
  subject := lotB
  payload := sameLotPayload
}

/--
The selected Observation-294 pressure also survives under the same generic
identity shape: complete current payload does not determine independently
created subject identity.
-/
theorem same_lot_payload_does_not_determine_subject :
    lotTwinA.payload = lotTwinB.payload ∧
      lotTwinA.subject ≠ lotTwinB.subject := by
  native_decide

private def emptyLotPayload : LotPayload := {
  title := "new lot"
  note := "created before membership"
  members := []
  aliases := []
}

private def emptyLot : LotSnapshot := {
  subject := lotA
  payload := emptyLotPayload
}

private def populatedLot : LotSnapshot := {
  subject := lotA
  payload := sameLotPayload
}

/-- Stable identity survives the selected transition from no members to members. -/
theorem lot_subject_survives_payload_change :
    emptyLot.subject = populatedLot.subject ∧
      emptyLot.payload ≠ populatedLot.payload := by
  native_decide

/-! ## Why one untyped token space is too broad -/

/--
Erasing the semantic domain collapses two intentionally unrelated subjects that
happen to use the same token spelling.
-/
def eraseDomain {Domain : Type} (subject : StableSubjectId Domain) : String :=
  subject.value

theorem domain_erasure_collapses_unrelated_subjects :
    eraseDomain scheduledA = eraseDomain lotA := by
  native_decide

/--
Within one domain, the stable identity remains usable as the common attachment
coordinate.
-/
private def amountFor?
    (world : PreScheduledWorld)
    (subject : StableSubjectId PreScheduledDomain) : Option Int := do
  let row ← world.amounts.find? fun item => decide (item.subject = subject)
  pure row.value

theorem typed_subject_coordinates_independent_future_evidence :
    amountFor? futureLeft scheduledA = some 1000 ∧
      dueFor? futureLeft scheduledA = some ⟨10⟩ := by
  native_decide

/--
Lot-domain evidence uses the same identity *shape* without sharing the
PreScheduled subject type.
-/
private def lotTitle?
    (snapshots : List LotSnapshot)
    (subject : StableSubjectId LotDomain) : Option String := do
  let row ← snapshots.find? fun item => decide (item.subject = subject)
  pure row.payload.title

theorem typed_subject_coordinates_lot_evidence :
    lotTitle? [lotTwinA, lotTwinB] lotA =
      some "retirement reserve" := by
  native_decide

/-!
## Finding

The bounded cross-domain compression survives, but only in a narrower form than
"one global StableSubjectId".

The reusable part is:

    StableSubjectId Domain
    Attached Domain Value

The semantic payload remains outside the identity abstraction.

This is enough to reproduce the two selected pressures:

1. Pre-Scheduled:
   stable identity preserves amount/due attachment correspondence that loose
   value pools lose.

2. User-created lot-like object:
   stable identity distinguishes independently created subjects even when their
   complete current payload is identical, and survives payload replacement.

The domain index matters.

The raw token "subject-1" can appear in both domains. If LOAM erased the domain
and used one untyped token space, those unrelated subjects would become
accidentally joinable. Keeping the domain in the type preserves the compression
of implementation *shape* without asserting cross-domain semantic identity.

So Observation 295 rejects two extremes:

- one investment-specific LotId is not yet the only possible answer;
- one universal untyped SubjectId is too broad for the selected evidence.

The smallest successful research abstraction is closer to a typed identity
schema than to a new universal household noun.

This also matches the current SA-010 discipline:

- allocate identity when independent reference/multiplicity requires it;
- use subjects/endpoints when they suffice;
- do not create a generic token ontology merely because several domains need
  similarly shaped identifiers.

Production still does not need to change. A shared implementation type would
become worth considering only if at least two production domains actually need
this stable-subject lifecycle and the typed abstraction removes real duplicated
mechanics without merging their semantics.

Not earned here:

- production StableSubjectId;
- production LotId;
- production pre-Scheduled Subject;
- one global subject registry;
- cross-domain subject equality;
- generic mutable entity/component storage;
- persistence or UI.
-/

end Loam.Observation295
