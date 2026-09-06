import Loam.MovementAdmission
import Loam.MovementManifestAuthority
import Loam.WriterOwnership

namespace Loam.MovementPublisher

set_option autoImplicit false

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
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft)
    (beforePublish : Receipt → IO Unit) : IO (Except String Receipt) := do
  let root := System.FilePath.mk rootPath
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
  | Except.error message =>
      return Except.error message
  | Except.ok world =>
      match Loam.MovementAdmission.admit? world draft with
      | Except.error message =>
          return Except.error message
      | Except.ok admitted =>
          let receipt : Receipt := {
            eventId := admitted.event.id
            relationCount := admitted.newRelations.length
            dischargeCount := admitted.newDischarges.length
          }
          beforePublish receipt
          match ← Loam.MovementManifestAuthority.publishWorld? root admitted.world with
          | Except.error message =>
              return Except.error message
          | Except.ok _ =>
              return Except.ok receipt

/--
Publish one already-collected Movement draft to selected manifest authority.

This is the single production write seam shared by frontends. It owns the full
world-dependent publication window:

```text
writer ownership
-> current selected-world re-read
-> MovementAdmission.admit?
-> optional surface observation of the admitted receipt
-> manifest publication
```

The callback is presentation-only. It runs after semantic admission and before
publication while ownership is still held; it receives no mutable world or
persistence object. A callback failure aborts publication and ownership is
released by `WriterOwnership`.

No historical completion hint, TUI candidate list, or frontend-local state can
authorize a Locus here. The selected manifest's current `LocusAdmission` family
is re-read immediately before `MovementAdmission.admit?`.
-/
def publishManifestDraftWithPreview
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft)
    (beforePublish : Receipt → IO Unit) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return Except.error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.WriterOwnership.withOwnership
    (root / "CURRENT")
    (publishUnderOwnership rootPath draft beforePublish)

/-- Publish without a frontend-specific pre-publication rendering callback. -/
def publishManifestDraft
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Receipt) :=
  publishManifestDraftWithPreview rootPath draft (fun _ => pure ())

end Loam.MovementPublisher
