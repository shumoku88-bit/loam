import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.LocusAdmissionAuthority
import Loam.MovementAdmission

namespace Loam.MovementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Single-File Actual Movement Publisher

This is the production write seam for practical Movement publication into
single-file normalized Actual authority (`actual.loam`).

The publication protocol is crash-resilient:
```text
writer ownership on actual.loam
-> load authoritative ActualEvidence from actual.loam
-> load current new-write policy from locus-admission.loam
-> construct typed MovementAdmission.World
-> MovementAdmission.admit?
-> optional surface observation of the admitted Event identity
-> atomic publish to actual.loam
```

Historical Event evidence in `actual.loam` is strictly separated from
new-write policy in `locus-admission.loam`.
-/

/--
Keep a durable EffectKey only when this Movement actually publishes a Relation
that names it. Frontends may use temporary keys while collecting one draft, but
ordinary quantity Effects must not acquire canonical identity merely because a
collector needed a local handle during human input.
-/
private def retainReferencedEffectKeys
    (draft : Loam.MovementAdmission.Draft) : Loam.MovementAdmission.Draft :=
  let referenced := draft.relations.map (fun relation => relation.sourceEffect)
  let effects := draft.effects.map fun effect =>
    match effect.key with
    | none => effect
    | some key =>
        if key ∈ referenced then effect else { effect with key := none }
  { draft with effects := effects }

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Loam.MovementAdmission.Draft)
    (beforePublish : Loam.Core.EventId → IO Unit) : IO (Except String Loam.Core.EventId) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | Except.error message => return Except.error message
    | Except.ok ev => pure ev
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | Except.error message => return Except.error message
    | Except.ok la => pure la
  let world : Loam.MovementAdmission.World := {
    events := evidence.events
    validity := evidence.validity
    descriptions := evidence.descriptions
    relations := evidence.relations
    discharges := evidence.discharges
    locusAdmission := locusAdmission
  }
  let canonicalDraft := retainReferencedEffectKeys draft
  match Loam.MovementAdmission.admit? world canonicalDraft with
  | Except.error message => return Except.error message
  | Except.ok admitted =>
      let eventId := admitted.event.id
      beforePublish eventId
      let updatedEvidence : ActualEvidence := {
        events := admitted.world.events
        validity := admitted.world.validity
        descriptions := admitted.world.descriptions
        corrections := evidence.corrections
        reversals := evidence.reversals
        relations := admitted.world.relations
        discharges := admitted.world.discharges
      }
      match ← Loam.ActualAuthority.publishActual? root updatedEvidence with
      | Except.error message => return Except.error message
      | Except.ok () => return Except.ok eventId

/--
Publish one already-collected Movement draft to normalized Actual authority.
-/
def publishDraftWithPreview
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft)
    (beforePublish : Loam.Core.EventId → IO Unit) : IO (Except String Loam.Core.EventId) := do
  if rootPath.isEmpty then
    return Except.error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft beforePublish)

/-- Publish without a frontend-specific pre-publication rendering callback. -/
def publishDraft
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Loam.Core.EventId) :=
  publishDraftWithPreview rootPath draft (fun _ => pure ())

end Loam.MovementPublisher
