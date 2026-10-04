import Loam.Authority.HouseholdAuthority
import Loam.Authority.ZeroOriginCoverageAuthority
import Loam.HouseholdPaths
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.Tests.Support

namespace Loam.Tests.HouseholdZeroOriginCoverageAdapter

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

open Loam.Tests.Support

set_option autoImplicit false

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household zero-origin adapter directory")
  let base := System.FilePath.mk rootText
  let legacyRoot := base / "legacy"
  let imageRoot := base / "image"
  let missingLegacyRoot := base / "missing-legacy"
  let missingImageRoot := base / "missing-image"
  let malformedLegacyRoot := base / "malformed-legacy"
  let malformedImageRoot := base / "malformed-image"
  for root in [
      legacyRoot, imageRoot, missingLegacyRoot, missingImageRoot,
      malformedLegacyRoot, malformedImageRoot] do
    IO.FS.createDirAll root

  expect (Loam.HouseholdAuthority.knownSectionNames.contains "ZeroOrigin")
    "HouseholdAuthority lost canonical ZeroOrigin section name"
  expect (!(Loam.HouseholdAuthority.knownSectionNames.contains "ZeroOriginCoverage"))
    "noncanonical ZeroOriginCoverage section name became known"

  let wallet : EffectCoordinate := ⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let coverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [wallet, cash])
    "zero-origin coverage fixture"
  let body ← requireSome
    (encodeZeroOriginCoverage? coverage)
    "zero-origin coverage fixture did not encode"

  let legacyPath := Loam.HouseholdPaths.zeroOriginCoverage legacyRoot
  expect (← saveZeroOriginCoverage? legacyPath coverage)
    "legacy zero-origin fixture did not save"

  let image : Image := {
    sections := [
      { name := "ZeroOrigin", body := body },
      { name := "FutureEvidence", body := "FUTURE\t1\nopaque\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot image)
    "HouseholdImage zero-origin fixture installation failed"

  -- A stale valid legacy file may disagree beside HouseholdImage. Household
  -- adapter reads must ignore it.
  let staleLegacyPath := Loam.HouseholdPaths.zeroOriginCoverage imageRoot
  let staleCoverage ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [⟨⟨"legacy-only"⟩, ⟨"jpy"⟩⟩])
    "stale zero-origin coverage fixture"
  expect (← saveZeroOriginCoverage? staleLegacyPath staleCoverage)
    "stale legacy zero-origin fixture did not save"
  let staleLegacyBefore ← IO.FS.readFile staleLegacyPath

  let legacyOptional ← requireOk
    (← Loam.ZeroOriginCoverageAuthority.loadLegacyOrEmpty? legacyPath)
    "legacy optional zero-origin coverage did not load"
  let legacyRequired ← requireOk
    (← Loam.ZeroOriginCoverageAuthority.loadLegacyRequired? legacyPath)
    "legacy required zero-origin coverage did not load"
  let householdOptional ← requireOk
    (← Loam.ZeroOriginCoverageAuthority.loadHouseholdOrEmpty? imageRoot)
    "Household optional zero-origin coverage did not load"
  let householdRequired ← requireOk
    (← Loam.ZeroOriginCoverageAuthority.loadHouseholdRequired? imageRoot)
    "Household required zero-origin coverage did not load"

  expect
    (legacyOptional.coordinates == coverage.coordinates &&
      legacyRequired.coordinates == coverage.coordinates)
    "legacy optional/required zero-origin answers diverged"
  expect
    (householdOptional.coordinates == coverage.coordinates &&
      householdRequired.coordinates == coverage.coordinates)
    "Household optional/required zero-origin answers diverged"
  expect (legacyOptional.coordinates == householdOptional.coordinates)
    "zero-origin meaning differs across storage topology"
  let householdBody ← requireSome
    (encodeZeroOriginCoverage? householdOptional)
    "Household zero-origin coverage did not re-encode"
  expect (householdBody == body)
    "zero-origin canonical bytes differ after HouseholdImage decode/re-encode"
  expect ((← IO.FS.readFile staleLegacyPath) == staleLegacyBefore)
    "Household zero-origin adapter mutated stale legacy evidence"

  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "HouseholdImage disappeared after zero-origin reads"
  expect
    (body? generation.image "FutureEvidence" == some "FUTURE\t1\nopaque\n")
    "zero-origin reads changed unknown HouseholdImage evidence"

  -- Optional and required absence contracts stay deliberately different.
  let missingLegacyPath := Loam.HouseholdPaths.zeroOriginCoverage missingLegacyRoot
  let missingLegacyOptional ← requireOk
    (← Loam.ZeroOriginCoverageAuthority.loadLegacyOrEmpty? missingLegacyPath)
    "missing legacy optional zero-origin did not become empty"
  expect missingLegacyOptional.coordinates.isEmpty
    "missing legacy optional zero-origin did not preserve semantic empty"
  expect
    (!(← Loam.ZeroOriginCoverageAuthority.loadLegacyRequired? missingLegacyPath).isOk)
    "missing legacy required zero-origin silently became empty"

  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingImageRoot {
      sections := [{ name := "FutureEvidence", body := "opaque\n" }]
    })
    "missing-section HouseholdImage installation failed"
  let missingImageOptional ← requireOk
    (← Loam.ZeroOriginCoverageAuthority.loadHouseholdOrEmpty? missingImageRoot)
    "missing Household optional zero-origin did not become empty"
  expect missingImageOptional.coordinates.isEmpty
    "missing Household optional zero-origin did not preserve semantic empty"
  expect
    (!(← Loam.ZeroOriginCoverageAuthority.loadHouseholdRequired? missingImageRoot).isOk)
    "missing Household required zero-origin silently became empty"

  -- Present malformed evidence fails closed for both absence contracts.
  IO.FS.writeFile
    (Loam.HouseholdPaths.zeroOriginCoverage malformedLegacyRoot)
    "not-zero-origin\n"
  expect
    (!(← Loam.ZeroOriginCoverageAuthority.loadLegacyOrEmpty?
      (Loam.HouseholdPaths.zeroOriginCoverage malformedLegacyRoot)).isOk)
    "malformed legacy optional zero-origin did not fail closed"
  expect
    (!(← Loam.ZeroOriginCoverageAuthority.loadLegacyRequired?
      (Loam.HouseholdPaths.zeroOriginCoverage malformedLegacyRoot)).isOk)
    "malformed legacy required zero-origin did not fail closed"

  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? {
      sections := [{ name := "ZeroOrigin", body := "not-zero-origin\n" }]
    })
    "malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedImageRoot) malformedWire
  expect
    (!(← Loam.ZeroOriginCoverageAuthority.loadHouseholdOrEmpty? malformedImageRoot).isOk)
    "malformed Household optional zero-origin did not fail closed"
  expect
    (!(← Loam.ZeroOriginCoverageAuthority.loadHouseholdRequired? malformedImageRoot).isOk)
    "malformed Household required zero-origin did not fail closed"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedImageRoot)) ==
      malformedWire)
    "failed zero-origin reads changed malformed HouseholdImage"

  IO.println
    "Household zero-origin adapter: optional/required absence semantics, canonical equivalence, stale-legacy isolation, malformed fail-closed, and unknown preservation passed."

end Loam.Tests.HouseholdZeroOriginCoverageAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdZeroOriginCoverageAdapter.main args
