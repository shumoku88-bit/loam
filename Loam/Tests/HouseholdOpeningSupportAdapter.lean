import Loam.Authority.HouseholdAuthority
import Loam.Authority.OpeningSupportAuthority
import Loam.HouseholdPaths
import Loam.Persistence.OpeningSupportPersistence
import Loam.Tests.Support

namespace Loam.Tests.HouseholdOpeningSupportAdapter

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

open Loam.Tests.Support

set_option autoImplicit false

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household opening-support adapter directory")
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

  expect (Loam.HouseholdAuthority.knownSectionNames.contains "OpeningSupport")
    "HouseholdAuthority lost canonical OpeningSupport section name"

  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let opening ← requireSome
    (OpeningSupportMap.ofSupports? [{
      coordinate := cash
      openingEvent := ⟨"opening-cash"⟩
    }])
    "opening-support fixture"
  let body ← requireSome
    (encodeOpeningSupportMap? opening)
    "opening-support fixture did not encode"

  let legacyPath := Loam.HouseholdPaths.openingSupport legacyRoot
  expect (← saveOpeningSupportMap? legacyPath opening)
    "legacy opening-support fixture did not save"

  let image : Image := {
    sections := [
      { name := "OpeningSupport", body := body },
      { name := "FutureEvidence", body := "FUTURE\t1\nopaque\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot image)
    "HouseholdImage opening-support fixture installation failed"

  -- A stale valid standalone authority may disagree beside HouseholdImage.
  -- Production Household reads must ignore it.
  let staleLegacyPath := Loam.HouseholdPaths.openingSupport imageRoot
  let staleOpening ← requireSome
    (OpeningSupportMap.ofSupports? [{
      coordinate := ⟨⟨"legacy-only"⟩, ⟨"jpy"⟩⟩
      openingEvent := ⟨"legacy-opening"⟩
    }])
    "stale legacy opening-support fixture"
  expect (← saveOpeningSupportMap? staleLegacyPath staleOpening)
    "stale legacy opening-support fixture did not save"
  let staleLegacyBefore ← IO.FS.readFile staleLegacyPath

  let legacyOptional ← requireOk
    (← Loam.OpeningSupportAuthority.loadLegacyOrEmpty? legacyPath)
    "legacy optional opening support did not load"
  let legacyRequired ← requireOk
    (← Loam.OpeningSupportAuthority.loadLegacyRequired? legacyPath)
    "legacy required opening support did not load"
  let householdOptional ← requireOk
    (← Loam.OpeningSupportAuthority.loadHouseholdOrEmpty? imageRoot)
    "Household optional opening support did not load"
  let householdRequired ← requireOk
    (← Loam.OpeningSupportAuthority.loadHouseholdRequired? imageRoot)
    "Household required opening support did not load"

  expect (legacyOptional.supports == opening.supports)
    "legacy optional opening-support meaning changed"
  expect (legacyRequired.supports == opening.supports)
    "legacy required opening-support meaning changed"
  expect (householdOptional.supports == opening.supports)
    "Household optional opening-support meaning changed"
  expect (householdRequired.supports == opening.supports)
    "Household required opening-support meaning changed"

  let householdBody ← requireSome
    (encodeOpeningSupportMap? householdOptional)
    "Household opening support did not re-encode"
  expect (householdBody == body)
    "opening-support canonical bytes differ after HouseholdImage decode/re-encode"
  expect ((← IO.FS.readFile staleLegacyPath) == staleLegacyBefore)
    "Household opening-support reads mutated stale legacy evidence"

  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "HouseholdImage disappeared after opening-support reads"
  expect
    (body? generation.image "FutureEvidence" == some "FUTURE\t1\nopaque\n")
    "opening-support reads changed unknown HouseholdImage evidence"

  -- Optional and required absence contracts remain intentionally different.
  let missingLegacyPath := Loam.HouseholdPaths.openingSupport missingLegacyRoot
  let missingLegacyOptional ← requireOk
    (← Loam.OpeningSupportAuthority.loadLegacyOrEmpty? missingLegacyPath)
    "missing legacy optional opening support did not become empty"
  expect missingLegacyOptional.supports.isEmpty
    "missing legacy optional opening support did not preserve semantic empty"
  expect
    (!(← Loam.OpeningSupportAuthority.loadLegacyRequired? missingLegacyPath).isOk)
    "missing legacy required opening support silently became empty"

  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingImageRoot {
      sections := [{ name := "FutureEvidence", body := "opaque\n" }]
    })
    "missing-section HouseholdImage installation failed"
  let missingImageOptional ← requireOk
    (← Loam.OpeningSupportAuthority.loadHouseholdOrEmpty? missingImageRoot)
    "missing Household optional opening support did not become empty"
  expect missingImageOptional.supports.isEmpty
    "missing Household optional opening support did not preserve semantic empty"
  expect
    (!(← Loam.OpeningSupportAuthority.loadHouseholdRequired? missingImageRoot).isOk)
    "missing Household required opening support silently became empty"

  -- Present malformed evidence fails closed for both absence contracts.
  IO.FS.writeFile legacyPath "not-opening-support\n"
  IO.FS.writeFile
    (Loam.HouseholdPaths.openingSupport malformedLegacyRoot)
    "not-opening-support\n"
  expect
    (!(← Loam.OpeningSupportAuthority.loadLegacyOrEmpty?
      (Loam.HouseholdPaths.openingSupport malformedLegacyRoot)).isOk)
    "malformed legacy optional opening support did not fail closed"
  expect
    (!(← Loam.OpeningSupportAuthority.loadLegacyRequired?
      (Loam.HouseholdPaths.openingSupport malformedLegacyRoot)).isOk)
    "malformed legacy required opening support did not fail closed"

  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? {
      sections := [{ name := "OpeningSupport", body := "not-opening-support\n" }]
    })
    "malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedImageRoot) malformedWire
  expect
    (!(← Loam.OpeningSupportAuthority.loadHouseholdOrEmpty? malformedImageRoot).isOk)
    "malformed Household optional opening support did not fail closed"
  expect
    (!(← Loam.OpeningSupportAuthority.loadHouseholdRequired? malformedImageRoot).isOk)
    "malformed Household required opening support did not fail closed"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedImageRoot)) == malformedWire)
    "failed opening-support reads changed malformed HouseholdImage"

  IO.println
    "Household OpeningSupport adapter: optional/required absence semantics, canonical equivalence, stale-legacy isolation, malformed fail-closed, and unknown preservation passed."

end Loam.Tests.HouseholdOpeningSupportAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdOpeningSupportAdapter.main args
