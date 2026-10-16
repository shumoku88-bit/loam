import Loam.Cli.NewHouseholdCli
import Loam.MovementWorldLoader
import Loam.OperationalContinuity
import Loam.Authority.HouseholdAuthority
import Loam.Tests.Support

namespace Loam.Tests.NewHousehold

open Loam.Tests.Support

set_option autoImplicit false

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let fresh := parent / "fresh"
  expect (!(← fresh.pathExists)) "fresh fixture unexpectedly exists"

  let _ ← requireOk
    (← Loam.NewHouseholdCli.create fresh)
    "fresh household creation failed"
  let body ← IO.FS.readFile (Loam.HouseholdAuthority.path fresh)
  expect (!body.isEmpty) "fresh household was not persisted"

  let observed ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? fresh)
    "fresh household failed qualified readback"
  expect
    (observed.image.sections.length == Loam.HouseholdAuthority.knownSectionNames.length)
    "fresh household does not have all the explicitly empty known sections"
  expect
    (!(← (Loam.HouseholdAuthority.previousPath fresh).pathExists))
    "fresh household invented a previous household generation"

  let _ ← requireOk
    (← Loam.MovementWorldLoader.loadSelectedWorld? fresh)
    "new household cannot admit ordinary Movement world"
  match ← Loam.OperationalContinuity.diagnoseStartupRead fresh fresh with
  | .ok () => pure ()
  | .error diagnosis =>
      throw (IO.userError ("new household startup refused: " ++ diagnosis.technical))

  -- A repeat, even on a valid fresh household, MUST NOT reset it.
  match ← Loam.NewHouseholdCli.create fresh with
  | .error _ => pure ()
  | .ok () => throw (IO.userError "initialization overwrote an existing household")
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path fresh)) == body)
    "repeat initialization changed existing financial evidence"

  -- A malformed old household remains byte-for-byte untouched.
  let broken := parent / "damaged"
  IO.FS.createDirAll broken
  let damagedPath := Loam.HouseholdAuthority.path broken
  IO.FS.writeFile damagedPath "damaged-household-do-not-touch\n"
  match ← Loam.NewHouseholdCli.create broken with
  | .error _ => pure ()
  | .ok () => throw (IO.userError "initialization overwrote a damaged household")
  expect
    ((← IO.FS.readFile damagedPath) == "damaged-household-do-not-touch\n")
    "failed init mutated old damaged data"

  -- A *separate* clean root may be created alongside the damaged root.
  let newStart := parent / "new-start"
  let _ ← requireOk
    (← Loam.NewHouseholdCli.create newStart)
    "failed to start an independent household alongside damaged data"
  expect ((← IO.FS.readFile damagedPath) == "damaged-household-do-not-touch\n")
    "new household creation touched the old household"

  IO.println "Fresh household bootstrap: explicit new root, qualified load, Movement and doctor, no fake previous state, no overwrite and independent restart passed."

end Loam.Tests.NewHousehold

def main : IO Unit := Loam.Tests.NewHousehold.main
