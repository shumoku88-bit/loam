import Loam.Application.CorrectionFrontier

namespace Loam.Observation293

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 293 — user annotation and cross-provider aliases still do not earn LotId

Observation 292 showed that an externally reported lot identifier is independent
evidence: a complete internal provenance graph does not reconstruct a provider's
own lot reference.

That left a stronger candidate pressure:

If a user wants one annotation to follow a lot-like subject while Events are
corrected and several providers assign different external identifiers, does
LOAM finally need its own first-class LotId?

A real accounting UI motivates the question. GnuCash lots have their own GUID
and also carry user-editable title / notes. So durable lot-local annotation is a
real feature, not an invented pressure.

This observation asks only whether that feature forces a new identity family
in LOAM.

The selected specimen retains:

- one historical Effect anchor;
- an explicit provenance edge to the current Effect;
- one EventCorrection from the historical Event to a replacement Event;
- two source-scoped external lot references from different custodians;
- one user annotation.

The production correction frontier already derives a stable Event root for the
replacement path. The complete provenance edge then keeps the historical
Effect anchor connected to the current Effect.

The user annotation and both provider aliases can therefore target the retained
historical provenance anchor. They are independent evidence, but they do not
need a new LOAM-owned LotId merely to share one subject.
-/

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def rootEventId : EventId := ⟨"o293-root-event"⟩
private def replacementEventId : EventId := ⟨"o293-replacement-event"⟩

private def rootEffectKey : EffectKey := ⟨"o293-root-lot-effect"⟩
private def replacementEffectKey : EffectKey := ⟨"o293-current-lot-effect"⟩

private def broker : LocusId := ⟨"o293-broker-account"⟩
private def shares : MeasureId := ⟨"o293-security-units"⟩

private def rootAnchor : EffectAnchor :=
  ⟨rootEventId, rootEffectKey⟩

private def replacementAnchor : EffectAnchor :=
  ⟨replacementEventId, replacementEffectKey⟩

private def rootEvent : Event :=
  { id := rootEventId
    effects := [
      Effect.ofQuantity
        rootEffectKey
        broker
        shares
        (Quantity.ofQuanta 3)
    ]
    keyNodup := by
      simp [retainedEffectKeys, rootEffectKey] }

private def replacementEvent : Event :=
  { id := replacementEventId
    effects := [
      Effect.ofQuantity
        replacementEffectKey
        broker
        shares
        (Quantity.ofQuanta 3)
    ]
    keyNodup := by
      simp [retainedEffectKeys, replacementEffectKey] }

private def eventMemory : EventMemory :=
  { events := [rootEvent, replacementEvent]
    idNodup := by
      simp [rootEvent, replacementEvent, rootEventId, replacementEventId] }

private def correctionMemory : EventCorrectionMemory :=
  { corrections := [{
      target := rootEventId
      replacement := replacementEventId
    }]
    idNodup := by simp }

/--
Project the production correction-root answer down to identifiers so the
selected observation is independent of Event proof fields.
-/
private def rootTerminalIds? : Option (List (EventId × EventId)) := do
  let rooted ← correctionRootTerminalEvents? eventMemory correctionMemory
  pure (rooted.map fun item => (item.1, item.2.id))

/--
The existing production correction frontier keeps the original EventId as the
stable root while the replacement Event is current.
-/
theorem correction_preserves_stable_event_root :
    rootTerminalIds? = some [(rootEventId, replacementEventId)] := by
  native_decide

structure LineageEdge where
  source : EffectAnchor
  target : EffectAnchor
  units : Quantity
deriving Repr, DecidableEq

private def lineage : List LineageEdge := [{
  source := rootAnchor
  target := replacementAnchor
  units := Quantity.ofQuanta 3
}]

/--
One provider-scoped external identifier. The provider/account namespace is part
of the evidence; the raw external id is not promoted to a universal identity.
-/
structure ExternalLotIdentityEvidence where
  provider : String
  account : String
  lotId : String
  subject : EffectAnchor
deriving Repr, DecidableEq

private def externalLots : List ExternalLotIdentityEvidence := [
  {
    provider := "custodian-a"
    account := "account-a"
    lotId := "A-LOT-17"
    subject := rootAnchor
  },
  {
    provider := "custodian-b"
    account := "account-b"
    lotId := "B-8841"
    subject := rootAnchor
  }
]

/--
User-authored annotation is another additive evidence family. It does not
change physical quantity, provenance, or either provider's identifier.
-/
structure UserLotAnnotation where
  subject : EffectAnchor
  text : String
deriving Repr, DecidableEq

private def annotation : UserLotAnnotation := {
  subject := rootAnchor
  text := "keep this acquisition history together"
}

structure World where
  lineage : List LineageEdge
  externalLots : List ExternalLotIdentityEvidence
  annotations : List UserLotAnnotation
deriving Repr, DecidableEq

private def annotatedWorld : World := {
  lineage := lineage
  externalLots := externalLots
  annotations := [annotation]
}

private def unannotatedWorld : World := {
  lineage := lineage
  externalLots := externalLots
  annotations := []
}

private def structuralProjection
    (world : World) :
    List LineageEdge × List ExternalLotIdentityEvidence :=
  (world.lineage, world.externalLots)

private def annotationText?
    (world : World)
    (subject : EffectAnchor) : Option String := do
  let item ← world.annotations.find? fun candidate =>
    candidate.subject = subject
  pure item.text

/--
The physical/provenance subject and both external aliases are unchanged whether
or not the user annotation exists.
-/
theorem same_graph_and_external_aliases_without_annotation :
    structuralProjection annotatedWorld =
      structuralProjection unannotatedWorld := by
  native_decide

/--
The annotation is independently observable evidence, so it must be retained
somewhere rather than reconstructed from provenance or provider ids.
-/
theorem annotation_is_independent_evidence :
    annotationText? annotatedWorld rootAnchor =
        some "keep this acquisition history together" ∧
      annotationText? unannotatedWorld rootAnchor = none := by
  native_decide

/--
Both providers can name the same retained internal provenance subject without
requiring their identifiers to be equal or universal.
-/
theorem multiple_external_ids_share_existing_internal_subject :
    (externalLots.map fun item => item.subject) =
      [rootAnchor, rootAnchor] := by
  native_decide

/--
The retained historical Effect anchor and the current replacement Effect are
connected explicitly by provenance. The annotation therefore does not need to
move onto the replacement Effect merely because physical currentness changed.
-/
theorem annotation_subject_is_provenance_root :
    lineage = [{
      source := annotation.subject
      target := replacementAnchor
      units := Quantity.ofQuanta 3
    }] := by
  native_decide

/-!
## Finding

This candidate pressure does not yet falsify the provenance-first design.

The selected facts separate cleanly:

physical/current Event:
  replacement Event + Effect

correction continuity:
  retained root EventId -> current terminal Event

lot-like continuity:
  retained Effect anchor -> current Effect provenance

external identities:
  (provider, account, external lot id) -> retained anchor

user annotation:
  retained anchor -> user text

The user annotation is real additional information: the same graph and the same
external identifiers can exist without it.

But the annotation does not itself create a need for a new identity. A retained
historical provenance anchor already supplies the internal referent, and the
production correction frontier already keeps the Event root stable across the
selected replacement path.

Likewise, two custodians assigning different lot identifiers to the continuing
subject does not by itself earn a LOAM-owned LotId. Both aliases can point to
the same retained internal anchor.

This observation therefore eliminates two candidate justifications for LotId:

- user annotation alone;
- several external lot ids alone.

A first-class LOAM-owned identity is still independently pressured only if a
selected subject must remain referable while no single retained provenance
anchor, canonical provenance component/key, or existing correction root can
serve as that referent.

If such a case appears, the next design question should also remain open:
whether the earned noun is really investment-specific LotId, or a more general
stable semantic subject / annotation-target identity reusable outside
investments.

Not earned here:

- production LotId;
- production annotation persistence;
- production external-lot identity persistence;
- cross-provider alias reconciliation policy;
- automatic Effect correspondence across arbitrary corrections;
- mutation or deletion of historical provenance anchors.
-/

end Loam.Observation293
