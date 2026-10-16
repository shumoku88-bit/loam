import Loam.Authority.AnnualSandboxDurabilityBarriers

namespace Loam.Tools.NativeAnnualUnknownOutcomeProbe

set_option autoImplicit false

private def expect (holds : Bool) (message : String) : IO Unit := do
  unless holds do throw (IO.userError message)

private def required {α : Type} (value : Except String α)
    (label : String) : IO α := do
  match value with
  | .ok answer => return answer
  | .error message => throw (IO.userError s!"{label}: {message}")

private def qualified (filename : String) :
    IO Loam.HouseholdAuthority.Generation := do
  required (Loam.AnnualSourceMaterialization.qualifyWire?
    (← IO.FS.readFile (System.FilePath.mk filename))) "native fixture"

private def initial (root : System.FilePath)
    (before : Loam.HouseholdAuthority.Generation) :
    IO Loam.AnnualSourceHeadSandbox.Selected := do
  Loam.AnnualSandboxDurabilityBarriers.markDisposableRoot root
  required (← Loam.AnnualSourceHeadSandbox.bootstrapWithBarriers?
      root "2026" before.wire
      (Loam.AnnualSandboxDurabilityBarriers.barriers root)) "bootstrap"

def run (root : System.FilePath) (beforeFile afterFile : String) : IO Unit := do
  let before ← qualified beforeFile
  let after ← qualified afterFile
  let day := "2027-01-03"
  let operation := "scheduled-completion:first"

  -- Fault BEFORE HEAD rename: clearly refused, with selected old HEAD.
  let pre := root / "pre-head"
  let oldPre ← initial pre before
  let safePre := Loam.AnnualSandboxDurabilityBarriers.barriers pre
  let stage := pre / "journal" / "2027" / "1.full.loam.loam-stage"
  let failPre : Loam.AnnualSourceHeadSandbox.PublicationBarriers := {
    syncFile := fun p => do
      if p.toString == stage.toString then
        throw (IO.userError "test-injected source stage fsync failure")
      safePre.syncFile p
    syncParents := safePre.syncParents
  }
  let preResult ← Loam.AnnualSourceHeadSandbox.appendWithOutcome?
    pre oldPre.headWire day operation ["Actual", "Scheduled"] after.image failPre
  match preResult with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "pre-HEAD failure not classified as refusal")
  let preStill ← required (← Loam.AnnualSourceHeadSandbox.readSelected? pre)
    "reopen after pre-HEAD refusal"
  expect (preStill.headWire == oldPre.headWire && preStill.operations.isEmpty)
    "pre-HEAD failure advanced selected HEAD"

  -- Fault AFTER a successful HEAD rename, specifically in HEAD parent sync.
  -- The operation may already be selected, but no durable success is claimed.
  let post := root / "post-head"
  let oldPost ← initial post before
  let safePost := Loam.AnnualSandboxDurabilityBarriers.barriers post
  let reached ← IO.mkRef false
  let failPost : Loam.AnnualSourceHeadSandbox.PublicationBarriers := {
    syncFile := safePost.syncFile
    syncParents := fun p => do
      if p.toString == (Loam.AnnualSourceHeadSandbox.headPath post).toString then
        reached.set true
        throw (IO.userError "test-injected HEAD directory fsync failure")
      safePost.syncParents p
  }
  let uncertain ← Loam.AnnualSourceHeadSandbox.appendWithOutcome?
    post oldPost.headWire day operation ["Actual", "Scheduled"] after.image failPost
  expect (← reached.get) "post-HEAD fault was not reached"
  match uncertain with
  | .outcomeUnknown op _ =>
      expect (op == operation) "uncertain result lost operation identity"
  | _ => throw (IO.userError "post-rename fsync failure was not outcomeUnknown")
  let observation ← Loam.AnnualSourceHeadSandbox.reobserveUnknown?
    post oldPost.headWire day operation
  match observation with
  | .requestedHeadSelected => pure ()
  | _ => throw (IO.userError "new HEAD cannot be requalified after uncertain result")
  let visible ← required (← Loam.AnnualSourceHeadSandbox.readSelected? post)
    "post-HEAD process-visible reobservation"
  expect (visible.generation.wire == after.wire &&
          visible.operations == [operation])
    "uncertain HEAD lost native Actual+Scheduled operation"

  -- Never retry from either prior HEAD or the current HEAD with the same ID.
  for observed in [oldPost.headWire, visible.headWire] do
    let duplicate ← Loam.AnnualSourceHeadSandbox.appendWithOutcome?
      post observed day operation ["Actual", "Scheduled"] after.image safePost
    match duplicate with
    | .refusedBeforeHead _ => pure ()
    | _ => throw (IO.userError "uncertain operation re-sent or double-posted")
  let postAgain ← required (← Loam.AnnualSourceHeadSandbox.readSelected? post)
    "post-HEAD final qualification"
  expect (postAgain.headWire == visible.headWire &&
          postAgain.operations == [operation])
    "duplicate retry changed selected native HEAD"

  -- A normal barrier-backed path still yields an explicit committed result.
  let good := root / "success"
  let oldGood ← initial good before
  let success ← Loam.AnnualSourceHeadSandbox.appendWithOutcome?
    good oldGood.headWire day operation ["Actual", "Scheduled"] after.image
      (Loam.AnnualSandboxDurabilityBarriers.barriers good)
  match success with
  | .committed selected =>
      expect (selected.generation.wire == after.wire &&
              selected.operations == [operation])
        "successful fsync append does not return qualified result"
  | _ => throw (IO.userError "successful barrier-backed append did not commit")
  expect ((← IO.FS.readFile (System.FilePath.mk beforeFile)) == before.wire &&
          (← IO.FS.readFile (System.FilePath.mk afterFile)) == after.wire)
    "synthetic input fixture was modified"
  IO.println "NATIVE_ANNUAL_UNKNOWN_OUTCOME_PASS pre-HEAD refusal; post-HEAD uncertain; reobserve read-only; duplicate rejected; success typed"

end Loam.Tools.NativeAnnualUnknownOutcomeProbe

def main (args : List String) : IO Unit := do
  match args with
  | [root, before, after] =>
      Loam.Tools.NativeAnnualUnknownOutcomeProbe.run
        (System.FilePath.mk root) before after
  | _ => throw (IO.userError "usage: NativeAnnualUnknownOutcomeProbe ROOT BEFORE AFTER")
