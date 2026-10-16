import Loam.Authority.AnnualSourceHeadSandbox
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tools.NativeAnnualSingleHeadSandboxProbe

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

private def required {α : Type} (value : Except String α) (label : String) : IO α := do
  match value with
  | .ok answer => return answer
  | .error message => throw (IO.userError s!"{label}: {message}")

private def get {α : Type} (value : Option α) (label : String) : IO α := do
  let some answer := value | throw (IO.userError label)
  return answer

def run (args : List String) : IO Unit := do
  let [beforePath, afterPath] := args
    | throw (IO.userError "expected native Scheduled-completion before/after image paths")
  let before ← IO.FS.readFile (System.FilePath.mk beforePath)
  let after ← IO.FS.readFile (System.FilePath.mk afterPath)
  let initial ← required
    (Loam.AnnualSourceMaterialization.qualifyWire? before) "native baseline"
  let completed ← required
    (Loam.AnnualSourceMaterialization.qualifyWire? after) "native completion"

  -- Only an independent disposable source root is owned by this experiment.
  let root ← IO.FS.createTempDir
  expect (!(← (root / "journal" / "2027").pathExists))
    "idle 2027 unexpectedly exists"
  expect (!(← Loam.AnnualSourceHeadSandbox.readSelected? root).isOk)
    "missing HEAD silently chose another source"

  let base ← required (← Loam.AnnualSourceHeadSandbox.bootstrap? root "2026" before)
    "isolated baseline setup"
  expect (base.head.years.isEmpty && base.generation.wire == initial.wire)
    "bootstrap mismatch"
  expect (!(← Loam.AnnualSourceHeadSandbox.bootstrap? root "2026" before).isOk)
    "bootstrap overwrote an installed genesis"
  expect (!(← (root / "journal" / "2027").pathExists))
    "opening the original HEAD created an empty 2027 year"

  let first ← required (← Loam.AnnualSourceHeadSandbox.append? root base.headWire
    "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] completed.image) "first selected annual HEAD switch"
  expect (first.head.years == ["2027"] && first.generation.wire == after &&
          first.lastDay == "2027-01-03")
    "cross-family 2027 source replay mismatched native"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root base.headWire
    "2027-01-03" "stale-append" ["Actual", "Scheduled"] completed.image).isOk)
    "stale observed HEAD published another source"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root first.headWire
    "2027-01-03" "scheduled-completion:first" ["Actual"] completed.image).isOk)
    "committed operation identity was duplicated"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root first.headWire
    "2027-01-04" "no-op" ["Actual"] completed.image).isOk)
    "no-op publication created a second source"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root first.headWire
    "2026-12-31" "regression" ["Actual"] completed.image).isOk)
    "annual source accepted earlier publication day"
  let stillFirst ← required (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "reopen after refused publications"
  expect (stillFirst.headWire == first.headWire &&
          stillFirst.generation.wire == completed.wire)
    "refused operation changed selected source"

  -- A different known native section uses the SAME source-publisher path.
  let wider ← get (LocusAdmissionVocabulary.ofLoci?
    [⟨"bank"⟩, ⟨"wifi"⟩, ⟨"other"⟩]) "test vocabulary"
  let widerBody ← get (Loam.Persistence.encodeLocusAdmissionVocabulary? wider)
    "native vocabulary encoding"
  let nextImage ← get (replaceBody? completed.image "LocusAdmission" widerBody)
    "native LocusAdmission section missing"
  let second ← required (← Loam.AnnualSourceHeadSandbox.append? root first.headWire
    "2028-01-01" "expand-vocabulary"
    ["LocusAdmission"] nextImage) "second-year selected HEAD switch"
  expect (second.head.years == ["2027", "2028"] &&
          second.operations == ["scheduled-completion:first", "expand-vocabulary"] &&
          second.generation.wire != completed.wire &&
          body? second.generation.image "CustomEvidence" ==
            body? initial.image "CustomEvidence")
    "2028 publication lost earlier years or unknown evidence"
  let reopened ← required (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "selected HEAD restart and full native replay"
  expect (reopened.headWire == second.headWire &&
          reopened.generation.wire == second.generation.wire)
    "restarted read did not select one immutable HEAD"

  -- An unreferenced completed/staged future source is never selected.
  IO.FS.createDirAll (root / "journal" / "2030")
  IO.FS.writeFile (root / "journal" / "2030" / "3.full.loam")
    "unselected future publication"
  let unchanged ← required (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "ignore orphan year-source file"
  expect (unchanged.headWire == second.headWire &&
          unchanged.generation.wire == reopened.generation.wire)
    "annual reader guessed latest year from directory listing"

  let secondObject := root / "journal" / "2028" / "2.full.loam"
  let retained ← IO.FS.readFile secondObject
  IO.FS.writeFile secondObject "corrupt selected object"
  expect (!(← Loam.AnnualSourceHeadSandbox.readSelected? root).isOk)
    "corrupt selected head referent was bypassed"
  IO.FS.writeFile secondObject retained
  let headPath := Loam.AnnualSourceHeadSandbox.headPath root
  IO.FS.writeFile headPath
    (second.headWire.replace "PUB\t2028\t2" "PUB\t2028\t4")
  expect (!(← Loam.AnnualSourceHeadSandbox.readSelected? root).isOk)
    "malformed HEAD ordinal was accepted"
  IO.FS.writeFile headPath second.headWire

  -- Replacing the entire HEAD with a *valid older head* succeeds as a read
  -- of older truth. This is the KNOWN missing trusted freshness check.
  IO.FS.writeFile headPath first.headWire
  let old ← required (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "demonstrate valid-old-HEAD rollback limitation"
  expect (old.generation.wire == completed.wire &&
          old.head.years == ["2027"])
    "valid-old-HEAD rollback behavior unexpectedly changed"
  IO.FS.writeFile headPath second.headWire
  expect ((← IO.FS.readFile (System.FilePath.mk beforePath)) == before &&
          (← IO.FS.readFile (System.FilePath.mk afterPath)) == after)
    "sandbox test changed production-published fixture bytes"
  IO.println "NATIVE_ANNUAL_SINGLE_HEAD_SANDBOX_PASS 2027 paired, 2028 generic, stale/duplicate/no-op/missing/corrupt/orphan refused; valid-old-HEAD rollback STILL UNDETECTABLE"

end Loam.Tools.NativeAnnualSingleHeadSandboxProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualSingleHeadSandboxProbe.run args
