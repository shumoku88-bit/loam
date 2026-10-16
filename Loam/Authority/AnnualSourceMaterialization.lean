import Loam.Authority.HouseholdAuthority

namespace Loam.AnnualSourceMaterialization

open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Read-only annual-source materialization parity gate

An annual-source reader could eventually reconstruct a *candidate* full
HouseholdImage. Before any production cutover, compare its exact bytes against
the currently installed, already-authoritative HouseholdImage under the same
writer lock. This probe never promotes the candidate and never writes a source.

It deliberately does NOT read or select an annual manifest/head, choose a
"newest" file, trust a publication clock, or fall back to a previous image.
The caller is still responsible for proving the external source-head closure.
-/

/-- Decode all present known families with the current production codecs.
Section absence remains absence; unknown section bodies remain opaque.
Require canonical byte-exact outer framing, not just a permissive decode. -/
def qualifyWire? (wire : String) :
    Except String Loam.HouseholdAuthority.Generation := do
  let some image := Loam.Persistence.HouseholdImage.decode? wire
    | throw "loam: annual materialization is not a valid HouseholdImage"
  Loam.HouseholdAuthority.qualifyKnownSections image
  let some encoded := Loam.Persistence.HouseholdImage.encode? image
    | throw "loam: annual materialization could not be re-encoded"
  if encoded != wire then
    throw "loam: annual materialization is not canonical byte-exact HouseholdImage"
  return { wire, image }

/-- Validate the proposed bytes and require exact equality to the installed
current source at one writer-owned observation. A valid old image, lost unknown
section, omitted support section or changed ordering is a *mismatch*, never an
automatic restoration or migration. This makes no filesystem mutations. -/
def compareInstalled? (root : System.FilePath) (candidateWire : String) :
    IO (Except String Loam.HouseholdAuthority.Generation) := do
  let candidate ←
    match qualifyWire? candidateWire with
    | .ok image => pure image
    | .error message => return .error message
  Loam.HouseholdAuthority.withOwnership root do
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .error message => return .error message
    | .ok installed =>
        if installed.wire != candidate.wire then
          return .error
            "loam: annual materialization differs from installed current HouseholdImage"
        return .ok installed

end Loam.AnnualSourceMaterialization
