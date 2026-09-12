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
-> optional surface observation of the admitted receipt
-> atomic publish to actual.loam
```

Historical Event evidence in `actual.loam` is strictly separated from
new-write policy in `locus-admission.loam`.
-/

/--
Small surface-independent receipt for one admitted Movement publication.

It exposes only identities/counts that a frontend may render after admission.
The canonical world and persistence representation remain private to the
publisher boundary.
-/
structure Receipt where
  eventId : Loam.Core.EventId
  relationCount : Nat
  dischargeCount : Nat
  deriving Repr

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Loam.MovementAdmission.Draft)
    (beforePublish : Receipt → IO Unit) : IO (Except String Receipt) := do
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
  match Loam.MovementAdmission.admit? world draft with
  | Except.error message => return Except.error message
  | Except.ok admitted =>
      let receipt : Receipt := {
        eventId := admitted.event.id
        relationCount := admitted.newRelations.length
        dischargeCount := admitted.newDischarges.length
      }
      beforePublish receipt
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
      | Except.ok () => return Except.ok receipt

/--
Publish one already-collected Movement draft to normalized Actual authority.
-/
def publishDraftWithPreview
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft)
    (beforePublish : Receipt → IO Unit) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return Except.error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft beforePublish)

/-- Publish without a frontend-specific pre-publication rendering callback. -/
def publishDraft
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Receipt) :=
  publishDraftWithPreview rootPath draft (fun _ => pure ())

/-- Backward-compatible alias for existing call sites. -/
def publishManifestDraftWithPreview := publishDraftWithPreview

/-- Backward-compatible alias for existing call sites. -/
def publishManifestDraft := publishDraft

end Loam.MovementPublisher
