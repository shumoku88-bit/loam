import Loam.Authority.ActualAuthority
import Loam.Authority.LocusAdmissionAuthority
import Loam.Application.MovementAdmission

namespace Loam.Tests.ActualWorldFixture

open Loam.Core

set_option autoImplicit false

/--
Initialize one isolated test household from the older MovementAdmission.World shape.

This helper is deliberately test-only. MovementAdmission.World does not carry
correction, reversal, or Merchant history, so converting it to ActualEvidence is
only sound for fresh fixtures that intentionally start with those histories empty.
Actual and the selected Locus-admission authority are published sequentially;
after LocusAdmission cutover the latter is the HouseholdImage section. This is
still test-only setup, not a production multi-authority transaction boundary.
-/
def publishWorld?
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO (Except String Unit) := do
  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
    events := world.events
    validity := world.validity
    descriptions := world.descriptions
    relations := world.relations
    discharges := world.discharges
  }
  let path :=
    if root.fileName == some Loam.ActualAuthority.actualFileName then root
    else Loam.ActualAuthority.actualPath root
  let dataDir :=
    if root.fileName == some Loam.ActualAuthority.actualFileName then
      root.parent.getD root
    else
      root
  match ← Loam.ActualAuthority.publishActualFile? path evidence with
  | .error message => return .error message
  | .ok () =>
      Loam.LocusAdmissionAuthority.publishCurrent? dataDir world.locusAdmission

end Loam.Tests.ActualWorldFixture
