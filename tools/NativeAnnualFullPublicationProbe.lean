import Loam.Authority.AnnualSourcePublication
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tools.NativeAnnualFullPublicationProbe

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

private def required {α : Type} (value : Except String α) (label : String) : IO α := do
  match value with
  | .ok result => return result
  | .error error => throw (IO.userError s!"{label}: {error}")

private def someOrError {α : Type} (value : Option α) (label : String) : IO α := do
  let some x := value | throw (IO.userError label)
  return x

def run (args : List String) : IO Unit := do
  let [beforePath, afterPath] := args
    | throw (IO.userError "usage: NativeAnnualFullPublicationProbe BEFORE AFTER")
  let before ← required
    (Loam.AnnualSourceMaterialization.qualifyWire? (← IO.FS.readFile (System.FilePath.mk beforePath)))
    "native before"
  let after ← required
    (Loam.AnnualSourceMaterialization.qualifyWire? (← IO.FS.readFile (System.FilePath.mk afterPath)))
    "native after"
  let groups := ["Actual", "Scheduled"]
  let pub ← required
    (Loam.AnnualSourcePublication.prepare? before 1
      "2027-01-03" "scheduled-completion:first" "native-genesis"
      groups after.image)
    "native Actual+Scheduled full source object"
  expect (pub.year == "2027" && pub.generation.wire == after.wire)
    "admission year was confused with effective or Scheduled day"
  let wire := Loam.AnnualSourcePublication.encodePublication pub
  let decoded ← required
    (Loam.AnnualSourcePublication.decodeAgainst? before wire)
    "full source replay"
  expect (decoded.generation.wire == after.wire &&
          decoded.changedNames == groups &&
          decoded.operation == "scheduled-completion:first")
    "real native paired completion bytes or metadata changed"

  -- The serialized annual source is an actual standalone native-readable
  -- object, stored only under an isolated temporary journal path.
  let disposable ← IO.FS.createTempDir
  let output := disposable / "journal" / pub.year / "000001.full.loam"
  IO.FS.createDirAll (disposable / "journal" / pub.year)
  IO.FS.writeFile output wire
  let reopened ← required
    (Loam.AnnualSourcePublication.decodeAgainst? before (← IO.FS.readFile output))
    "reopen native all-family source from year path"
  expect (reopened.generation.wire == after.wire)
    "on-disk source replay changed real native household evidence"

  -- Ordinary malformed candidates cannot bypass the existing known section
  -- codec, unknown-section preservation or exact changed-set admission.
  expect ((Loam.AnnualSourcePublication.prepare? before 2
      "2027-01-03" "idempotent-retry" "native-genesis"
      groups after.image).isOk)
    "valid generic second preparation failed unexpectedly"
  for invalid in [
      Loam.AnnualSourcePublication.prepare? before 0
        "2027-01-03" "op0" "native-genesis" groups after.image,
      Loam.AnnualSourcePublication.prepare? before 1
        "2027-02-29" "bad-day" "native-genesis" groups after.image,
      Loam.AnnualSourcePublication.prepare? before 1
        "2027-01-03" "bad-op\tmeta" "native-genesis" groups after.image,
      Loam.AnnualSourcePublication.prepare? before 1
        "2027-01-03" "missing-scheduled" "native-genesis" ["Actual"] after.image,
      Loam.AnnualSourcePublication.prepare? before 1
        "2027-01-03" "duplicate-changed" "native-genesis"
        ["Actual", "Actual", "Scheduled"] after.image,
      Loam.AnnualSourcePublication.prepare? before 1
        "2027-01-03" "unknown-authority" "native-genesis"
        ["Actual", "Scheduled", "CustomEvidence"] after.image,
      Loam.AnnualSourcePublication.prepare? before 1
        "2027-01-03" "no-op" "native-genesis" ["Actual"] before.image
    ] do
      expect (!invalid.isOk) "annual source accepted invalid operation"

  let changedUnknown ← someOrError
    (replaceBody? after.image "CustomEvidence" "forged\n")
    "fixture unknown section missing"
  expect (!(Loam.AnnualSourcePublication.prepare? before 1
    "2027-01-03" "tamper" "native-genesis" groups changedUnknown).isOk)
    "future unknown section was silently rewritten"
  expect (!(Loam.AnnualSourcePublication.decodeAgainst? before
    (wire.replace "DAY\t2027-01-03" "DAY\t2026-02-30")).isOk)
    "forged source admission day passed"
  expect (!(Loam.AnnualSourcePublication.decodeAgainst? before
    (wire.replace "CHANGED\tActual\tScheduled" "CHANGED\tActual")).isOk)
    "incomplete source family group passed"
  expect (!(Loam.AnnualSourcePublication.decodeAgainst? before
    (wire ++ "trailing bytes")).isOk)
    "garbage after native HouseholdImage was accepted"

  -- This variant changes a DIFFERENT known section. No new family-specific
  -- parser or list of admissible pairs is needed for source preparation.
  let some wider := LocusAdmissionVocabulary.ofLoci?
      [⟨"bank"⟩, ⟨"wifi"⟩, ⟨"other"⟩]
    | throw (IO.userError "wider vocabulary fixture")
  let widerBody ← someOrError
    (Loam.Persistence.encodeLocusAdmissionVocabulary? wider)
    "wider vocabulary encoding"
  let nextImage ← someOrError
    (replaceBody? after.image "LocusAdmission" widerBody)
    "LocusAdmission section missing"
  let pub2 ← required
    (Loam.AnnualSourcePublication.prepare? after 2
      "2028-01-01" "expand-vocabulary" "source-ordinal-1"
      ["LocusAdmission"] nextImage)
    "generic next-year source publication"
  let nextWire := Loam.AnnualSourcePublication.encodePublication pub2
  let replay ← required
    (Loam.AnnualSourcePublication.decodeAgainst? after nextWire)
    "generic multi-year source replay"
  expect (pub2.year == "2028" && replay.generation.wire != after.wire &&
          body? replay.generation.image "CustomEvidence" ==
            body? after.image "CustomEvidence" &&
          body? replay.generation.image "Scheduled" ==
            body? after.image "Scheduled")
    "second-year source replay mutated unrelated evidence"

  expect (!(Loam.AnnualSourcePublication.decodeAgainst? before nextWire).isOk)
    "replayed native source without its required exact predecessor"

  IO.println "NATIVE_ANNUAL_FULL_PUBLICATION_PASS paired Actual/Scheduled, unrelated native LocusAdmission in 2028, strict metadata and full-image preservation"

end Loam.Tools.NativeAnnualFullPublicationProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualFullPublicationProbe.run args
