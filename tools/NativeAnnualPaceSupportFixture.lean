import Loam.Tests.ActualWorldFixture
import Loam.Persistence.ZeroOriginCoveragePersistence

namespace Loam.Tools.NativeAnnualPaceSupportFixture

open Loam.Core

set_option autoImplicit false

/-!
Install test-only, explicitly asserted zero-origin evidence BEFORE the real
native snapshots are produced. The family is carried unchanged through each
annual source publication. All roots are disposable synthetic fixtures.
The unasserted Wi-Fi coordinate must stay amount-unknown, never zero.
-/

def run (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "expected isolated synthetic household root")
  let root := System.FilePath.mk rootText
  let bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩
  let some support := ZeroOriginCoverage.ofCoordinates? [bank]
    | throw (IO.userError "test-only zero-origin assertion rejected")
  let some body := Loam.Persistence.encodeZeroOriginCoverage? support
    | throw (IO.userError "test-only zero-origin encoding rejected")
  match ← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root "ZeroOrigin" body with
  | .ok () => pure ()
  | .error message => throw (IO.userError message)
  IO.println "NATIVE_ANNUAL_PACE_SUPPORT_FIXTURE_PASS bank zero-origin; wifi unsupported"

end Loam.Tools.NativeAnnualPaceSupportFixture

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualPaceSupportFixture.run args
