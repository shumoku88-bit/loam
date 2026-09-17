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
-> atomic publish to actual.loam
```

Historical Event evidence in `actual.loam` is strictly separated from
new-write policy in `locus-admission.loam`.

Presentation belongs outside this boundary. The publisher returns the admitted
Event identity only after authoritative publication succeeds; TUI, CLI, GUI, or
AI surfaces may render that result without injecting callbacks into the write
protocol.
-/

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Loam.Core.EventId) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | Except.error message => return Except.error message
    | Except.ok ev => pure ev
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | Except.error message => return Except.error message
    | Except.ok la => pure la
  let world := Loam.ActualAuthority.movementWorld evidence locusAdmission
  match Loam.MovementAdmission.admit? world draft with
  | Except.error message => return Except.error message
  | Except.ok admitted =>
      let updatedEvidence : ActualEvidence := {
        evidence with
        events := admitted.world.events
        validity := admitted.world.validity
        descriptions := admitted.world.descriptions
        relations := admitted.world.relations
        discharges := admitted.world.discharges
      }
      match ← Loam.ActualAuthority.publishActual? root updatedEvidence with
      | Except.error message => return Except.error message
      | Except.ok () => return Except.ok admitted.eventId

/--
Publish one already-collected Movement draft to normalized Actual authority.
-/
def publishDraft
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Loam.Core.EventId) := do
  if rootPath.isEmpty then
    return Except.error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.MovementPublisher
