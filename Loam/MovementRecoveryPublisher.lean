import Loam.MovementManifestAuthority
import Loam.WriterOwnership

namespace Loam.MovementRecoveryPublisher

set_option autoImplicit false

/-!
# Explicit Movement recovery publication

Recovery is an authority-selection operation, not a reconstruction of household
facts. The caller must name one retained recovery manifest digest. The manifest,
its referenced immutable objects, and typed production world are validated by
`MovementManifestAuthority` before `CURRENT` can change.

This publisher owns the same `CURRENT` writer anchor as ordinary Movement
publication so recovery cannot race a normal writer.
-/

/-- Select one exact retained recovery generation under production writer ownership. -/
def restore
    (rootPath digest : String) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  if digest.isEmpty then
    return .error "loam: recovery digest must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.WriterOwnership.withOwnership
    (root / "CURRENT")
    (Loam.MovementManifestAuthority.restoreRecoveryCandidate? root digest)

end Loam.MovementRecoveryPublisher
