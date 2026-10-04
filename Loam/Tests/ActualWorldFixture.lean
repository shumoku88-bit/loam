import Loam.Authority.ActualAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Application.MovementAdmission
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tests.ActualWorldFixture

open Loam.Core

set_option autoImplicit false

/--
Test-only partial-HouseholdImage fixture publication.

If no HouseholdImage exists this installs the initial generation. Otherwise it
replaces or appends exactly one section through the real generation publisher.
This helper exists only so partially cut-over test households can be assembled
without reimplementing HouseholdImage framing.
-/
def publishHouseholdSection?
    (root : System.FilePath)
    (name body : String) : IO (Except String Unit) := do
  let householdPath := Loam.HouseholdAuthority.path root
  if !(← householdPath.pathExists) then
    match ← Loam.HouseholdAuthority.installInitial? root {
      sections := [{ name := name, body := body }]
    } with
    | .ok _ => return .ok ()
    | .error message => return .error message

  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let candidate? :=
    if Loam.Persistence.HouseholdImage.contains generation.image name then
      Loam.Persistence.HouseholdImage.replaceBody? generation.image name body
    else
      Loam.Persistence.HouseholdImage.appendSection?
        generation.image { name := name, body := body }
  let some candidate := candidate?
    | return .error
        ("loam: test fixture could not install HouseholdImage section: " ++ name)
  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire [name] candidate with
  | .ok _ => return .ok ()
  | .error message => return .error message

/--
Initialize one isolated test household from the older MovementAdmission.World shape.

This helper is deliberately test-only. MovementAdmission.World does not carry
correction, reversal, or Merchant history, so converting it to ActualEvidence is
only sound for fresh fixtures that intentionally start with those histories empty.
Actual and HouseholdImage LocusAdmission are published sequentially; this is
test setup, not a production multi-authority transaction boundary.
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
      let some locusBody :=
          Loam.Persistence.encodeLocusAdmissionVocabulary? world.locusAdmission
        | return .error "loam: test Locus admission vocabulary did not encode"
      publishHouseholdSection? dataDir "LocusAdmission" locusBody

end Loam.Tests.ActualWorldFixture
