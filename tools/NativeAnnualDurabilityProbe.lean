import Loam.Authority.AnnualSandboxDurabilityBarriers
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tools.NativeAnnualDurabilityProbe

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (holds : Bool) (message : String) : IO Unit := do
  unless holds do throw (IO.userError message)

private def required {α : Type} (value : Except String α)
    (label : String) : IO α := do
  match value with
  | .ok answer => return answer
  | .error error => throw (IO.userError s!"{label}: {error}")

private def get {α : Type} (x : Option α) (label : String) : IO α := do
  let some answer := x | throw (IO.userError label)
  return answer

private def qualified (path : String) : IO Loam.HouseholdAuthority.Generation := do
  required (Loam.AnnualSourceMaterialization.qualifyWire?
    (← IO.FS.readFile (System.FilePath.mk path))) ("qualified " ++ path)

private def selectedRoot (root : System.FilePath) :
    IO Loam.AnnualSourceHeadSandbox.Selected := do
  required (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "selected native annual HEAD"

/-- Use actual native pairs; pause after the year source has been renamed AND
file/parent fsynced, but before staging its authoritative HEAD. CI kills the
entire Lean process group at this explicitly-observed point. -/
private def seed (root : System.FilePath) (before after ready : String) :
    IO Unit := do
  let initial ← qualified before
  let complete ← qualified after
  Loam.AnnualSandboxDurabilityBarriers.markDisposableRoot root
  let barriers := Loam.AnnualSandboxDurabilityBarriers.barriers root
  let base ← required
    (← Loam.AnnualSourceHeadSandbox.bootstrapWithBarriers?
      root "2026" initial.wire barriers) "durable baseline bootstrap"
  expect (base.head.years.isEmpty) "durable bootstrap published a year prematurely"
  let _ ← required (← Loam.AnnualSourceHeadSandbox.appendWithBarriersAndTestHook?
      root base.headWire "2027-01-03" "scheduled-completion:first"
      ["Actual", "Scheduled"] complete.image barriers (do
        IO.FS.writeFile (System.FilePath.mk ready) "SOURCE_FSYNCED_BEFORE_HEAD\n"
        IO.sleep 60000)) "durable append should be killed at hook"
  throw (IO.userError "durable SIGKILL interruption never arrived")

private def retry (root : System.FilePath) (before after : String) :
    IO Unit := do
  let initial ← qualified before
  let complete ← qualified after
  let barriers := Loam.AnnualSandboxDurabilityBarriers.barriers root
  let older ← selectedRoot root
  expect (older.generation.wire == initial.wire && older.head.years.isEmpty)
    "SIGKILL changed selected generation before HEAD was installed"
  let orphanPath := root / "journal" / "2027" / "1.full.loam"
  let orphan ← IO.FS.readFile orphanPath
  let decoded ← required (Loam.AnnualSourcePublication.decodeAgainst?
    initial orphan) "installed source after crash"
  expect (decoded.generation.wire == complete.wire &&
          decoded.changedNames == ["Actual", "Scheduled"])
    "SIGKILL damaged qualified Actual + Scheduled source"
  for (day, op) in [("2027-01-03", "other-op"),
                     ("2027-01-04", "scheduled-completion:first")] do
    expect (!(← Loam.AnnualSourceHeadSandbox.appendWithBarriers? root
      older.headWire day op ["Actual", "Scheduled"] complete.image barriers).isOk)
      "mismatched orphan was accepted by durable retry"
    expect ((← IO.FS.readFile orphanPath) == orphan)
      "durable retry rewrote a mismatched orphan"
  let recovered ← required (← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
    root older.headWire "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] complete.image barriers) "exact durable resume"
  expect (recovered.head.years == ["2027"] &&
          recovered.generation.wire == complete.wire &&
          (← IO.FS.readFile orphanPath) == orphan)
    "durable exact retry lost evidence or created an extra generation"
  expect (!(← Loam.AnnualSourceHeadSandbox.appendWithBarriers? root
    older.headWire "2027-01-03" "scheduled-completion:first"
    ["Actual", "Scheduled"] complete.image barriers).isOk)
    "stale observed HEAD doubly committed during durable retry"
  let wider ← get (LocusAdmissionVocabulary.ofLoci?
    [⟨"bank"⟩, ⟨"wifi"⟩, ⟨"other"⟩]) "wider locus"
  let body ← get (Loam.Persistence.encodeLocusAdmissionVocabulary? wider)
    "wider encoding"
  let nextImage ← get (replaceBody? complete.image "LocusAdmission" body)
    "LocusAdmission missing"
  let newer ← required (← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
    root recovered.headWire "2028-01-01" "expand-vocabulary"
    ["LocusAdmission"] nextImage barriers) "durable 2028 continuation"
  expect (newer.head.years == ["2027", "2028"] &&
          body? newer.generation.image "CustomEvidence" ==
            body? initial.image "CustomEvidence")
    "durable year continuation lost unknown-family evidence"
  let current ← selectedRoot root
  expect (current.generation.wire == newer.generation.wire &&
          (← IO.FS.readFile (System.FilePath.mk before)) == initial.wire &&
          (← IO.FS.readFile (System.FilePath.mk after)) == complete.wire)
    "durable source HEAD did not reopen or mutated original fixtures"
  IO.println "NATIVE_ANNUAL_DURABLE_RETRY_PASS exact fsynced orphan resumed, 2028 selected, no double commit"

private def failStage (root : System.FilePath) (before after : String) :
    IO Unit := do
  let initial ← qualified before
  let complete ← qualified after
  Loam.AnnualSandboxDurabilityBarriers.markDisposableRoot root
  let barriers := Loam.AnnualSandboxDurabilityBarriers.barriers root
  let base ← required (← Loam.AnnualSourceHeadSandbox.bootstrapWithBarriers?
    root "2026" initial.wire barriers) "failed-fsync test baseline"
  let mut failed := false
  try
    let result ← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
      root base.headWire "2027-01-03" "scheduled-completion:first"
      ["Actual", "Scheduled"] complete.image barriers
    failed := !result.isOk
  catch _ =>
    failed := true
  expect failed "injected source fsync failure was swallowed"
  let current ← selectedRoot root
  expect (current.headWire == base.headWire &&
          current.generation.wire == initial.wire &&
          !(← (root / "journal" / "2027" / "1.full.loam").pathExists))
    "fsync failure returned an accepted HEAD or installed unqualified source"
  IO.println "NATIVE_ANNUAL_DURABLE_FSYNC_REFUSAL_PASS injected sync error never committed HEAD"

def run (args : List String) : IO Unit := do
  match args with
  | [mode, root, before, after, ready] =>
      if mode != "seed" then
        throw (IO.userError "five args reserved for seed SIGKILL fixture")
      seed (System.FilePath.mk root) before after ready
  | [mode, root, before, after] =>
      if mode == "retry" then
        retry (System.FilePath.mk root) before after
      else if mode == "fail-stage" then
        failStage (System.FilePath.mk root) before after
      else
        throw (IO.userError "unsupported native annual durability probe mode")
  | _ =>
      throw (IO.userError "usage: seed ROOT BEFORE AFTER READY | retry ROOT BEFORE AFTER | fail-stage ROOT BEFORE AFTER")

end Loam.Tools.NativeAnnualDurabilityProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualDurabilityProbe.run args
