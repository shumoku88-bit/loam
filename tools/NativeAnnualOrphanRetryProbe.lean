import Loam.Authority.AnnualSourceHeadSandbox
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tools.NativeAnnualOrphanRetryProbe

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (ok : Bool) (message : String) : IO Unit := do
  unless ok do throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α) (label : String) : IO α := do
  match value with
  | .ok answer => return answer
  | .error error => throw (IO.userError s!"{label}: {error}")

private def get {α : Type} (value : Option α) (label : String) : IO α := do
  let some answer := value | throw (IO.userError label)
  return answer

private def qualified (filename : String) :
    IO Loam.HouseholdAuthority.Generation :=
  requireOk (Loam.AnnualSourceMaterialization.qualifyWire?
    (← IO.FS.readFile (System.FilePath.mk filename))) ("fixture " ++ filename)

private def orphanPath (root : System.FilePath) : System.FilePath :=
  root / "journal" / "2027" / "1.full.loam"

private def seed (root : System.FilePath) (before after : String) : IO Unit := do
  let initial ← qualified before
  let completed ← qualified after
  let selected ← requireOk
    (← Loam.AnnualSourceHeadSandbox.bootstrap? root "2026" initial.wire)
    "isolated native HEAD genesis"
  let reachedInstalled ← IO.mkRef false
  try
    let _ ← Loam.AnnualSourceHeadSandbox.appendWithInstalledTestHook?
      root selected.headWire "2027-01-03" "scheduled-completion:first"
      ["Actual", "Scheduled"] completed.image
      (do
        reachedInstalled.set true
        throw (IO.userError "test-injected halt after source object install"))
    pure ()
  catch _ => pure ()
  expect (← reachedInstalled.get)
    "the injected stop happened before reaching source installation"
  expect (← (orphanPath root).pathExists)
    "interrupted append left no installed orphan"
  let same ← requireOk (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "selected HEAD after injected failure"
  expect (same.headWire == selected.headWire &&
          same.generation.wire == initial.wire &&
          same.operations.isEmpty)
    "interrupted write changed canonical selected HEAD"
  let orphan := ← IO.FS.readFile (orphanPath root)
  let recovered ← requireOk
    (Loam.AnnualSourcePublication.decodeAgainst? initial orphan)
    "decode committed-looking orphan without promoting it"
  expect (recovered.generation.wire == completed.wire &&
          recovered.changedNames == ["Actual", "Scheduled"])
    "orphan data was not a fully qualified native pair"
  IO.println "NATIVE_ANNUAL_ORPHAN_SEEDED old HEAD remains selected, valid new object unselected"

private def retry (root : System.FilePath) (before after : String) : IO Unit := do
  let initial ← qualified before
  let completed ← qualified after
  let selected ← requireOk
    (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "read 2026 HEAD on independent retry process"
  expect (selected.head.years.isEmpty &&
          selected.generation.wire == initial.wire)
    "seed phase silently promoted orphan"
  let orphanWire ← IO.FS.readFile (orphanPath root)
  -- Same path, but a different identity or admission day, must not adopt the
  -- old object, delete it, edit it, or change HEAD.
  for (day, token) in [
      ("2027-01-03", "another-operation"),
      ("2027-01-04", "scheduled-completion:first")
    ] do
      expect (!(← Loam.AnnualSourceHeadSandbox.append? root selected.headWire
        day token ["Actual", "Scheduled"] completed.image).isOk)
        "wrong operation/day adopted a different orphan"
      expect ((← IO.FS.readFile (orphanPath root)) == orphanWire &&
              (← IO.FS.readFile (Loam.AnnualSourceHeadSandbox.headPath root))
                == selected.headWire)
        "failed mismatched retry altered orphan or HEAD"

  IO.FS.writeFile (orphanPath root) "damaged orphan"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root selected.headWire
    "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] completed.image).isOk)
    "corrupt orphan passed retry"
  expect ((← IO.FS.readFile (orphanPath root)) == "damaged orphan")
    "corrupt orphan was silently overwritten"
  IO.FS.writeFile (orphanPath root) orphanWire

  let restored ← requireOk (← Loam.AnnualSourceHeadSandbox.append?
    root selected.headWire "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] completed.image)
    "resume same exact native operation after restart"
  expect (restored.head.years == ["2027"] &&
          restored.operations == ["scheduled-completion:first"] &&
          restored.generation.wire == completed.wire &&
          (← IO.FS.readFile (orphanPath root)) == orphanWire)
    "retry failed to install exactly one HEAD, or rewrote source bytes"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root selected.headWire
    "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] completed.image).isOk)
    "lost-success reply retried against stale HEAD and doubled operation"
  expect (!(← Loam.AnnualSourceHeadSandbox.append? root restored.headWire
    "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] completed.image).isOk)
    "committed identity was accepted as a second operation"

  let wider ← get (LocusAdmissionVocabulary.ofLoci?
      [⟨"bank"⟩, ⟨"wifi"⟩, ⟨"other"⟩]) "extra locus"
  let body ← get (Loam.Persistence.encodeLocusAdmissionVocabulary? wider)
    "native LocusAdmission encoding"
  let nextImage ← get (replaceBody? completed.image "LocusAdmission" body)
    "native LocusAdmission section"
  let second ← requireOk (← Loam.AnnualSourceHeadSandbox.append?
    root restored.headWire "2028-01-01" "expand-vocabulary"
    ["LocusAdmission"] nextImage)
    "subsequent ordinary 2028 publication after recovered 2027"
  expect (second.head.years == ["2027", "2028"] &&
          second.operations == ["scheduled-completion:first", "expand-vocabulary"] &&
          body? second.generation.image "CustomEvidence" ==
            body? completed.image "CustomEvidence")
    "orphan recovery damaged future publication or unknown source evidence"
  let again ← requireOk (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "reopen selected HEAD after a cross-year continuation"
  expect (again.generation.wire == second.generation.wire &&
          again.operations.length == 2 &&
          (← IO.FS.readFile (System.FilePath.mk before)) == initial.wire &&
          (← IO.FS.readFile (System.FilePath.mk after)) == completed.wire)
    "restored source differs, or fixture was modified"
  IO.println "NATIVE_ANNUAL_ORPHAN_RETRY_PASS exact orphan reused; mismatched/corrupt refused unchanged; lost-reply duplicate refused; 2028 continuation qualified"

def main (args : List String) : IO Unit := do
  match args with
  | [mode, root, before, after] =>
      if mode == "seed" then seed (System.FilePath.mk root) before after
      else if mode == "retry" then retry (System.FilePath.mk root) before after
      else throw (IO.userError "mode must be seed or retry")
  | _ => throw (IO.userError "usage: NativeAnnualOrphanRetryProbe seed|retry ROOT BEFORE AFTER")

end Loam.Tools.NativeAnnualOrphanRetryProbe
