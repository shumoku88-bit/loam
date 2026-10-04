import Loam.Authority.HouseholdAuthority
import Loam.HouseholdPaths
import Loam.Authority.ActualRoutingAuthority
import Loam.Publisher.ActualRoutingPublisher
import Loam.HouseholdCommand
import Loam.Persistence.ActualRoutingPersistence
import Loam.Tests.Support

namespace Loam.Tests.HouseholdActualRoutingAdapter

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

open Loam.Tests.Support

set_option autoImplicit false

private def householdBody?
    (root : System.FilePath) : IO (Option String) := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "HouseholdImage did not load"
  pure (body? generation.image "ActualRouting")

private def sameStatus
    (left right : ActualRoutingHistory)
    (locus : LocusId)
    (effective : RoutingEffective String) : Bool :=
  decide (left.statusAt locus effective = right.statusAt locus effective)

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household Actual routing adapter directory")
  let base := System.FilePath.mk rootText
  let legacyRoot := base / "legacy"
  let imageRoot := base / "image"
  let missingRoot := base / "missing"
  let malformedRoot := base / "malformed"
  IO.FS.createDirAll legacyRoot
  IO.FS.createDirAll imageRoot
  IO.FS.createDirAll missingRoot
  IO.FS.createDirAll malformedRoot

  let legacyRouting := Loam.HouseholdPaths.actualRouting legacyRoot

  let initialImage : Image := {
    sections := [
      { name := "Securities", body := "FUTURE\t1\nopaque\tunknown\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot initialImage)
    "initial HouseholdImage installation failed"

  -- A valid stale legacy file beside HouseholdImage must remain isolated from
  -- HouseholdImage-specific publication.
  let imageLegacyRouting := Loam.HouseholdPaths.actualRouting imageRoot
  IO.FS.writeFile imageLegacyRouting <|
    actualRoutingHeader ++ "\n" ++
    "ROUTE\tlegacy-only\tINITIAL\tMANAGED\tlegacy-purpose\n"
  let frozenLegacyBefore ← IO.FS.readFile imageLegacyRouting

  let groceries : LocusId := ⟨"groceries"⟩
  let coffee : LocusId := ⟨"coffee"⟩

  let managed : Loam.ActualRoutingPublisher.Draft := {
    locus := groceries
    effectiveOn := .initial
    target := .managed ⟨"food"⟩
  }

  -- Both writer topologies begin from absent routing storage and create the
  -- first canonical routing history.
  let _ ← requireOk
    (← Loam.ActualRoutingPublisher.publish legacyRouting.toString managed)
    "legacy first Actual route failed"
  let _ ← requireOk
    (← Loam.ActualRoutingPublisher.publishHousehold imageRoot managed)
    "Household first Actual route failed"

  let firstLegacyBody ← IO.FS.readFile legacyRouting
  expect ((← householdBody? imageRoot) == some firstLegacyBody)
    "first Actual routing canonical bytes differ across storage topology"
  expect ((← IO.FS.readFile imageLegacyRouting) == frozenLegacyBefore)
    "Household Actual routing adapter mutated stale legacy actual-routing.loam"

  let previousAfterFirstWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let previousAfterFirst ← requireSome
    (Loam.Persistence.HouseholdImage.decode? previousAfterFirstWire)
    "first previous HouseholdImage did not decode"
  expect (body? previousAfterFirst "ActualRouting" == none)
    "first Actual routing publication did not preserve prior section absence"

  let unmanaged : Loam.ActualRoutingPublisher.Draft := {
    locus := coffee
    effectiveOn := .dated "2026-10-01"
    target := .unmanaged
  }
  let _ ← requireOk
    (← Loam.ActualRoutingPublisher.publish legacyRouting.toString unmanaged)
    "legacy second Actual route failed"
  let _ ← requireOk
    (← Loam.ActualRoutingPublisher.publishHousehold imageRoot unmanaged)
    "Household second Actual route failed"

  let secondLegacyBody ← IO.FS.readFile legacyRouting
  expect ((← householdBody? imageRoot) == some secondLegacyBody)
    "second Actual routing canonical bytes differ across storage topology"

  let legacyHistory ← requireOk
    (← Loam.ActualRoutingAuthority.loadLegacyRequired? legacyRouting)
    "legacy Actual routing did not load"
  let imageHistory ← requireOk
    (← Loam.ActualRoutingAuthority.loadHouseholdRequired? imageRoot)
    "Household Actual routing did not load"
  expect (sameStatus legacyHistory imageHistory groceries (.dated "2026-09-30"))
    "initial Actual routing status differs across storage topology"
  expect (sameStatus legacyHistory imageHistory coffee (.dated "2026-10-01"))
    "dated Actual routing status differs across storage topology"

  let current ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "updated HouseholdImage disappeared"
  expect
    (body? current.image "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "Actual routing update changed unknown future evidence"
  expect ((← IO.FS.readFile imageLegacyRouting) == frozenLegacyBefore)
    "second Household Actual route changed frozen legacy evidence"

  let previousWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let previous ← requireSome
    (Loam.Persistence.HouseholdImage.decode? previousWire)
    "previous HouseholdImage did not decode"
  expect (body? previous "ActualRouting" == some firstLegacyBody)
    "previous HouseholdImage did not retain prior Actual routing generation"

  let beforeRefusal := current.wire
  match ← Loam.ActualRoutingPublisher.publishHousehold imageRoot managed with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "duplicate Household Actual route unexpectedly succeeded")
  let afterRefusal ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "HouseholdImage disappeared after duplicate refusal"
  expect (afterRefusal.wire == beforeRefusal)
    "refused Household Actual route changed HouseholdImage"
  expect ((← IO.FS.readFile imageLegacyRouting) == frozenLegacyBefore)
    "refused Household Actual route changed frozen legacy evidence"

  -- Production cutover: the high-level household command must publish only to
  -- HouseholdImage and leave the stale legacy routing file frozen.
  let productionDraft : Loam.ActualRoutingPublisher.Draft := {
    locus := groceries
    effectiveOn := .dated "2026-10-02"
    target := .managed ⟨"household"⟩
  }
  let _ ← requireOk
    (← Loam.HouseholdCommand.routeActual imageRoot productionDraft)
    "HouseholdCommand Actual route failed"
  let productionHistory ← requireOk
    (← Loam.ActualRoutingAuthority.loadHouseholdRequired? imageRoot)
    "production Household Actual routing did not load"
  expect
    (productionHistory.statusAt groceries (.dated "2026-10-02") ==
      .managed ⟨"household"⟩)
    "HouseholdCommand Actual route did not reach HouseholdImage"
  expect ((← IO.FS.readFile imageLegacyRouting) == frozenLegacyBefore)
    "HouseholdCommand mutated frozen legacy actual-routing.loam"

  -- Required reads preserve absence as absence, while the writer retains the
  -- existing first-write-from-empty behavior.
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingRoot {
      sections := [{ name := "Securities", body := "opaque\n" }]
    })
    "missing-section HouseholdImage installation failed"
  expect
    (!(← Loam.ActualRoutingAuthority.loadHouseholdRequired? missingRoot).isOk)
    "missing Household ActualRouting section became an implicit required read"

  let firstMissingDraft : Loam.ActualRoutingPublisher.Draft := {
    locus := ⟨"book"⟩
    effectiveOn := .initial
    target := .managed ⟨"misc"⟩
  }
  let _ ← requireOk
    (← Loam.ActualRoutingPublisher.publishHousehold missingRoot firstMissingDraft)
    "missing Household ActualRouting section did not admit first publication"
  let missingHistory ← requireOk
    (← Loam.ActualRoutingAuthority.loadHouseholdRequired? missingRoot)
    "created Household ActualRouting section did not load"
  expect
    (missingHistory.statusAt ⟨"book"⟩ (.dated "2026-10-01") ==
      .managed ⟨"misc"⟩)
    "first Household Actual route did not become visible"
  let missingPreviousWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath missingRoot)
  let missingPrevious ← requireSome
    (Loam.Persistence.HouseholdImage.decode? missingPreviousWire)
    "missing-section previous HouseholdImage did not decode"
  expect (body? missingPrevious "ActualRouting" == none)
    "first-write Household Actual routing lost prior section absence"

  let malformedImage : Image := {
    sections := [{ name := "ActualRouting", body := "not-actual-routing\n" }]
  }
  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? malformedImage)
    "malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedRoot) malformedWire
  expect
    (!(← Loam.ActualRoutingAuthority.loadHouseholdRequired? malformedRoot).isOk)
    "malformed Household Actual routing did not fail closed"
  expect
    (!(← Loam.ActualRoutingPublisher.publishHousehold malformedRoot managed).isOk)
    "malformed Household Actual routing accepted publication"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedRoot)) ==
      malformedWire)
    "refused malformed Actual routing publication changed HouseholdImage"

  IO.println
    "Household Actual routing adapter: absent-first-write equivalence plus production command cutover, required-read absence, canonical byte/status equivalence, frozen-legacy isolation, previous-generation retention, refusal, malformed fail-closed, and unknown preservation passed."

end Loam.Tests.HouseholdActualRoutingAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdActualRoutingAdapter.main args
