import Loam.Authority.HouseholdAuthority
import Loam.Migration.HouseholdImageDryRun

namespace Loam.HouseholdImageInstall

set_option autoImplicit false

/-!
# Qualified initial HouseholdImage installation

This boundary performs exactly one transition beyond the dry-run gate:

1. rerun the full legacy-to-HouseholdImage dry-run against the source root;
2. reuse the exact qualified candidate bytes produced by that run;
3. install them as the first `household.loam` generation.

The legacy thirteen-file layout is not deleted, rewritten, or dual-written.
Production readers and publishers are not switched here. For the initial
generation there is intentionally no `household.loam.prev`, because no prior
HouseholdImage generation exists yet. The untouched legacy layout remains the
rollback source until a later explicit production cutover.
-/

structure Report where
  dryRun : Loam.HouseholdImageDryRun.Report
  installed : Loam.HouseholdAuthority.Generation
deriving Repr

def run
    (legacyRoot scratchRoot : System.FilePath)
    (probe : Loam.HouseholdImageDryRun.ReviewProbe) :
    IO (Except String Report) := do
  let dryRun ←
    match ← Loam.HouseholdImageDryRun.run legacyRoot scratchRoot probe with
    | .ok report => pure report
    | .error message => return .error message

  let some candidate :=
      Loam.Persistence.HouseholdImage.decode? dryRun.wire
    | return .error
        "loam: qualified HouseholdImage candidate failed to decode before installation"

  let installed ←
    match ← Loam.HouseholdAuthority.installInitial? legacyRoot candidate with
    | .ok generation => pure generation
    | .error message => return .error message

  return .ok {
    dryRun := dryRun
    installed := installed
  }

end Loam.HouseholdImageInstall
