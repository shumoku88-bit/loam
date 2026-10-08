import Loam.HouseholdCommand
import Loam.Tui.ScheduledBulkEdit

namespace Loam.Tui.ScheduledBulkEditSession

open Loam.Tui.Kernel Loam.Tui.Runtime

set_option autoImplicit false

/-!
The complete candidate sheet and preview use one HouseholdImage generation.
A publication refusal exits to the workspace for canonical reload; stale sheets
are never rebound to newer household bytes behind the user's back.
-/

partial def runEditor
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ScheduledBulkEdit.State) (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.ScheduledBulkEdit.view active state)
  let step := Loam.Tui.ScheduledBulkEdit.update state key
  if step.cancel then return "Batch edit cancelled. No Scheduled occurrences changed."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.replaceScheduledBatch root draft with
      | .ok () => return "Revised " ++ toString draft.drafts.length ++ " Scheduled occurrences."
      | .error message => return "No batch changes published. " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledBulkEdit.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runEditor bounds root step.state nextFrame

/-- Build a fresh read-only sheet; no mutation occurs before explicit Publish all. -/
def run
    (bounds : Bounds) (root : System.FilePath)
    (sourceId : Loam.Core.ScheduledId) (fromDate : String)
    (presentation : List Loam.MeasurePresentation.Metadata) : IO String := do
  let observed ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return message
  let actual ←
    match Loam.ActualAuthority.decodeHouseholdGeneration? observed.generation with
    | .ok image => pure image
    | .error message => return message
  let some source := observed.lifecycle.scheduled.findById? sourceId
    | return "Selected Scheduled reference is no longer retained. Reopen batch edit."
  let snapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := observed.lifecycle.scheduled
    terminals := observed.lifecycle.terminals
    events := actual.evidence.events
  }
  let candidates ←
    match Loam.ScheduledBulkEdit.candidates snapshot source with
    | .ok candidates => pure candidates
    | .error message => return message
  let state := Loam.Tui.ScheduledBulkEdit.initial
    observed.generation.wire source candidates fromDate presentation
  let frame := compileWidget (Loam.Tui.ScheduledBulkEdit.view bounds state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  runEditor bounds root state frame

end Loam.Tui.ScheduledBulkEditSession
