import Loam.Core.LocusAdmission
import Loam.MovementManifestAuthority

namespace Loam.LocusAdmissionAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Locus admission authority boundary

LocusAdmission is current new-write policy, not household Event evidence. This
module hides only the policy's current physical placement.

The representation remains Movement-manifest-backed for now. Callers that need
only the current admission vocabulary therefore no longer depend directly on the
Movement world layout, and a later independently persisted policy can be tested
without changing those callers.

This is deliberately local rather than a generic authority abstraction.
-/

/-- Load exactly the currently selected new-write Locus policy. -/
def loadCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) := do
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
  | .ok world => return .ok world.locusAdmission
  | .error message => return .error message

/--
Replace only the policy meaning while preserving the currently selected household
Movement world.

Physical publication is intentionally unchanged: the current implementation still
publishes one complete Movement generation. The caller owns the existing
`root / "CURRENT"` writer lock, so read-modify-publish remains serialized exactly
as before.
-/
def replaceCurrent?
    (root : System.FilePath)
    (vocabulary : LocusAdmissionVocabulary) : IO (Except String Nat) := do
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  Loam.MovementManifestAuthority.publishWorld? root
    { world with locusAdmission := vocabulary }

end Loam.LocusAdmissionAuthority
