import Loam.ActualAuthority
import Loam.LocusAdmissionAuthority
import Loam.MovementAdmission

namespace Loam.MovementDraftReview

set_option autoImplicit false

/-!
# Read-only Movement draft review

This boundary answers only whether one already-collected `MovementAdmission.Draft`
would be admissible against the currently selected household Actual evidence and
new-write Locus policy.

It deliberately performs no publication, acquires no writer ownership, reserves
no Event identity, and retains no source-to-LOAM mapping. The hypothetical
`Admitted` value produced by `MovementAdmission.admit?` is discarded completely.
A later real publication must re-read authority under the ordinary writer-owned
`MovementPublisher` path and may therefore still refuse if the world changed.

This makes the boundary suitable for human, AI, CSV, bank-statement, receipt, or
other external proposal adapters without turning any external source into LOAM
authority merely by inspecting it.
-/

/--
Check one Movement draft against the current household world without writing.

Success means only "admissible against the world observed by this call". It is
not a reservation, publication receipt, stable EventId, or promise that a later
write will still succeed.
-/
def check
    (root : System.FilePath)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Unit) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .error message => return .error message
    | .ok value => pure value
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .error message => return .error message
    | .ok value => pure value
  let world := Loam.ActualAuthority.movementWorld evidence locusAdmission
  match Loam.MovementAdmission.admit? world draft with
  | .error message => return .error message
  | .ok _ => return .ok ()

end Loam.MovementDraftReview
