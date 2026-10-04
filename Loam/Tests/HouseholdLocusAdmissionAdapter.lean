import Loam.Authority.HouseholdAuthority
import Loam.Authority.LocusAdmissionAuthority
import Loam.Publisher.LocusAdmissionPublisher
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tests.HouseholdLocusAdmissionAdapter

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

private def requireSome {α : Type}
    (value : Option α)
    (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def tokens (vocabulary : LocusAdmissionVocabulary) : List String :=
  vocabulary.approved.map LocusId.token

private def initialVocabulary : IO LocusAdmissionVocabulary :=
  requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"book"⟩, ⟨"misc"⟩])
    "initial Locus admission vocabulary"

private def proposed
    (vocabulary : LocusAdmissionVocabulary)
    (token : String) :
    Except String (LocusAdmissionVocabulary × Unit) := do
  let updated ←
    Loam.LocusAdmissionPublisher.propose? vocabulary { token := token }
  return (updated, ())

private def householdBody
    (root : System.FilePath) : IO String := do
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "HouseholdImage did not load"
  requireSome
    (body? generation.image "LocusAdmission")
    "HouseholdImage Locus admission section missing"

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household Locus admission adapter directory")
  let root := System.FilePath.mk rootText
  let legacyRoot := root / "legacy"
  let legacyPath := Loam.HouseholdPaths.locusAdmission legacyRoot
  let imageRoot := root / "image"
  let missingRoot := root / "missing"
  let malformedRoot := root / "malformed"
  IO.FS.createDirAll legacyRoot
  IO.FS.createDirAll imageRoot
  IO.FS.createDirAll missingRoot
  IO.FS.createDirAll malformedRoot

  let initial ← initialVocabulary
  let initialBody ← requireSome
    (Loam.Persistence.encodeLocusAdmissionVocabulary? initial)
    "initial Locus admission policy did not encode"

  expect
    (← Loam.Persistence.saveLocusAdmissionVocabulary? legacyPath initial)
    "legacy initial Locus admission publication failed"

  let initialImage : Image := {
    sections := [
      { name := "LocusAdmission", body := initialBody },
      { name := "Securities", body := "FUTURE\t1\nopaque\tunknown\n" }
    ]
  }
  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot initialImage)
    "initial HouseholdImage installation failed"

  -- Explicit legacy filepath remains a diagnostic/migration entrance.
  let legacyLoaded ← requireOk
    (← Loam.LocusAdmissionAuthority.loadCurrent? legacyPath)
    "explicit legacy Locus admission did not load"

  -- Root selection is now production HouseholdImage selection.
  let staleLegacy ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"legacy-only"⟩])
    "stale legacy Locus admission vocabulary"
  expect
    (← Loam.Persistence.saveLocusAdmissionVocabulary?
      (Loam.HouseholdPaths.locusAdmission imageRoot) staleLegacy)
    "stale legacy Locus admission fixture did not publish"
  let staleLegacyBefore ←
    IO.FS.readFile (Loam.HouseholdPaths.locusAdmission imageRoot)

  let imageLoaded ← requireOk
    (← Loam.LocusAdmissionAuthority.loadCurrent? imageRoot)
    "production HouseholdImage Locus admission did not load"
  expect (tokens legacyLoaded == tokens imageLoaded)
    "Locus admission load answer differs across storage topology"

  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.updateCurrent?
      legacyPath (fun vocabulary => proposed vocabulary "stationery"))
    "explicit legacy Locus admission update failed"
  let _ ← requireOk
    (← Loam.LocusAdmissionAuthority.updateCurrent?
      imageRoot (fun vocabulary => proposed vocabulary "stationery"))
    "production HouseholdImage Locus admission update failed"

  let legacyAfter ← requireOk
    (← Loam.LocusAdmissionAuthority.loadCurrent? legacyPath)
    "updated explicit legacy Locus admission did not load"
  let imageAfter ← requireOk
    (← Loam.LocusAdmissionAuthority.loadCurrent? imageRoot)
    "updated production HouseholdImage Locus admission did not load"
  expect (tokens legacyAfter == ["book", "misc", "stationery"])
    "legacy Locus admission answer changed unexpectedly"
  expect (tokens imageAfter == tokens legacyAfter)
    "updated Locus admission answer differs across storage topology"

  let legacyBody ← IO.FS.readFile legacyPath
  let imageBody ← householdBody imageRoot
  expect (legacyBody == imageBody)
    "canonical Locus admission bytes differ across storage topology"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.locusAdmission imageRoot)) ==
      staleLegacyBefore)
    "production Locus admission update mutated frozen legacy locus-admission.loam"

  let current ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "updated HouseholdImage disappeared"
  expect
    (body? current.image "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "Locus admission update changed unknown future evidence"

  let previousWire ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let previous ← requireSome
    (Loam.Persistence.HouseholdImage.decode? previousWire)
    "previous HouseholdImage did not decode"
  expect (body? previous "LocusAdmission" == some initialBody)
    "previous HouseholdImage did not retain prior Locus admission policy"
  expect
    (body? previous "Securities" ==
      some "FUTURE\t1\nopaque\tunknown\n")
    "previous HouseholdImage changed unknown future evidence"

  let beforeRefusal := current.wire
  match ← Loam.LocusAdmissionAuthority.updateCurrent?
      imageRoot (fun vocabulary => proposed vocabulary "stationery") with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "duplicate HouseholdImage Locus admission unexpectedly succeeded")
  let afterRefusal ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? imageRoot)
    "HouseholdImage disappeared after duplicate refusal"
  expect (afterRefusal.wire == beforeRefusal)
    "refused Locus admission update changed HouseholdImage"

  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingRoot {
      sections := [{ name := "Securities", body := "opaque\n" }]
    })
    "missing-section HouseholdImage installation failed"
  expect
    (!(← Loam.LocusAdmissionAuthority.loadCurrent? missingRoot).isOk)
    "missing HouseholdImage Locus admission section became implicit empty policy"
  expect
    (!(← Loam.LocusAdmissionAuthority.updateCurrent?
      missingRoot (fun vocabulary => proposed vocabulary "stationery")).isOk)
    "missing HouseholdImage Locus admission section accepted an update"
  expect (!(← (Loam.HouseholdAuthority.previousPath missingRoot).pathExists))
    "refused missing-section update invented a previous generation"

  let malformedImage : Image := {
    sections := [{ name := "LocusAdmission", body := "not-locus-admission\n" }]
  }
  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? malformedImage)
    "malformed-inner HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedRoot) malformedWire
  expect
    (!(← Loam.LocusAdmissionAuthority.loadCurrent? malformedRoot).isOk)
    "malformed HouseholdImage Locus admission policy did not fail closed"
  expect
    (!(← Loam.LocusAdmissionAuthority.updateCurrent?
      malformedRoot (fun vocabulary => proposed vocabulary "stationery")).isOk)
    "malformed HouseholdImage Locus admission policy accepted an update"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedRoot)) ==
      malformedWire)
    "refused malformed Locus admission update changed HouseholdImage"

  IO.println
    "Household Locus admission cutover: explicit legacy diagnostics, production HouseholdImage selection, frozen-legacy isolation, byte equivalence, required-section semantics, previous-generation retention, refusal, and unknown preservation passed."

end Loam.Tests.HouseholdLocusAdmissionAdapter

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdLocusAdmissionAdapter.main args
