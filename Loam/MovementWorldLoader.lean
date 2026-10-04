import Loam.Authority.ActualAuthority
import Loam.Authority.LocusAdmissionAuthority
import Loam.Application.MovementAdmission
import Loam.Application.MovementWorldAdapter

namespace Loam.MovementWorldLoader

set_option autoImplicit false

/-!
# Composite Movement World Loader

This module provides the production loader for `MovementAdmission.World` by
combining authoritative `ActualEvidence` and current new-write Locus policy from
the selected household generation. An explicit `actual.loam` path remains
available as a legacy diagnostic entrance while the Locus policy still comes
from that file's household directory.

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
  let selected := Loam.ActualAuthority.actualPathFromRootOrFile root
  let dataDir :=
    if root.fileName == some Loam.ActualAuthority.actualFileName ||
        root.fileName == some Loam.HouseholdAuthority.fileName then
      root.parent.getD root
    else
      root
  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? selected with
    | .ok ev => pure ev
    | .error msg => return .error msg
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? dataDir with
    | .ok la => pure la
    | .error msg => return .error msg
  return .ok (Loam.MovementWorldAdapter.ofActual evidence locusAdmission)

end Loam.MovementWorldLoader
