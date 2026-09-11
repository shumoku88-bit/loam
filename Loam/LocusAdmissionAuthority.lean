import Loam.Core.LocusAdmission
import Loam.MovementManifestAuthority
import Loam.WriterOwnership

namespace Loam.LocusAdmissionAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Locus admission authority boundary

LocusAdmission is current new-write policy, not household Event evidence. This
module hides only the policy's current physical placement and publication anchor.

The representation remains Movement-manifest-backed for now. Callers that need
only the current admission vocabulary therefore no longer depend directly on the
Movement world layout or the `CURRENT` child path, and a later independently
persisted policy can be tested without changing those callers.

This is deliberately local rather than a generic authority abstraction.
-/

/-- Load exactly the currently selected new-write Locus policy. -/
def loadCurrent?
    (root : System.FilePath) : IO (Except String LocusAdmissionVocabulary) := do
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
  | .ok world => return .ok world.locusAdmission
  | .error message => return .error message

/--
Apply one policy-local read/modify/write while preserving the currently selected
household Movement world.

The callback sees only the policy meaning and returns its replacement plus an
operation-specific result. Physical publication is intentionally unchanged: this
implementation still locks Movement `CURRENT` and publishes one complete Movement
generation. Neither the callback nor its caller knows that placement.

No add-only assumption is encoded here. If future policy semantics earn removal
or retirement, synchronization can be re-qualified inside this boundary without
changing policy-only callers.
-/
def updateCurrent? {α : Type}
    (root : System.FilePath)
    (propose : LocusAdmissionVocabulary →
      Except String (LocusAdmissionVocabulary × α)) : IO (Except String α) :=
  Loam.WriterOwnership.withOwnership (root / "CURRENT") do
    let world ←
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
      | .ok world => pure world
      | .error message => return .error message
    let (updated, result) ←
      match propose world.locusAdmission with
      | .ok value => pure value
      | .error message => return .error message
    match ← Loam.MovementManifestAuthority.publishWorld? root
        { world with locusAdmission := updated } with
    | .error message => return .error message
    | .ok _ => return .ok result

end Loam.LocusAdmissionAuthority
