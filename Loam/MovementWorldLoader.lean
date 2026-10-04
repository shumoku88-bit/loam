import Loam.Authority.ActualAuthority
import Loam.Authority.LocusAdmissionAuthority
import Loam.Application.MovementAdmission
import Loam.Application.MovementWorldAdapter

namespace Loam.MovementWorldLoader

set_option autoImplicit false

/-!
# Composite Movement World Loader

This module provides the production loader for `MovementAdmission.World` by
combining authoritative `ActualEvidence` from `actual.loam` and current new-write
policy from the `LocusAdmission` section of `household.loam`.

The two semantic authorities remain independent:
* `actual.loam` owns historical fact families (Events, Validity, Corrections, etc.)
* HouseholdImage `LocusAdmission` owns current new-write Locus policy
* `MovementWorldLoader` orchestrates loading both and composing them via `MovementWorldAdapter`

The caller-selected root is exact: missing or malformed authority fails closed
without searching parent directories for a different household authority.
-/

/--
Load the full typed MovementAdmission.World by combining authoritative ActualEvidence
from `actual.loam` and current new-write policy from HouseholdImage.
The caller-selected root is exact: missing or malformed authority fails closed
instead of searching parent directories for a different household authority.
-/
def loadSelectedWorld? (root : System.FilePath) : IO (Except String Loam.MovementAdmission.World) := do
  let path :=
    if root.fileName == some Loam.ActualAuthority.actualFileName then root
    else Loam.ActualAuthority.actualPath root
  let dataDir := if root.fileName == some Loam.ActualAuthority.actualFileName then root.parent.getD root else root
  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? path with
    | .ok ev => pure ev
    | .error msg => return .error msg
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? dataDir with
    | .ok la => pure la
    | .error msg => return .error msg
  return .ok (Loam.MovementWorldAdapter.ofActual evidence locusAdmission)

end Loam.MovementWorldLoader
