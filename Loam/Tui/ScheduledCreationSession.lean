import Loam.HouseholdCommand
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Review.ScheduledReview
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCoverageSetupSession
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCreationSession

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/--
Run the existing Scheduled editor until the user either confirms one draft or
cancels, without publishing anything.

Higher-level construction helpers can therefore collect several explicit drafts,
show the complete set, and only then publish through the ordinary household
command boundary.
-/
partial def collectDraft
    (bounds : Bounds)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) :
    IO (Option Loam.ScheduledCreationPublisher.Draft) := do
  let step := Loam.Tui.ScheduledCreation.updateForBounds bounds known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return none
  match step.publish with
  | some draft => return some draft
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCreation.view bounds known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      collectDraft bounds known step.state nextFrame

/--
Run one presentation-only Scheduled creation editor session, returning the created Scheduled identity if published.
-/
def runWithScheduledId
    (bounds : Bounds) (root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) :
    IO (Option ScheduledId × String) :=
  Loam.Tui.EditorSession.runUntilPublished bounds
    (Loam.Tui.ScheduledCreation.updateForBounds bounds known)
    (Loam.Tui.ScheduledCreation.view bounds known)
    Loam.Tui.ScheduledCreation.withPublishError
    (none, "Scheduled creation cancelled.")
    (fun draft => do
      match ← Loam.HouseholdCommand.createScheduled root draft with
      | .ok scheduledId =>
          return .ok
            (some scheduledId,
              "Scheduled " ++ scheduledId.token ++ " for " ++ draft.scheduledOn ++ ".")
      | .error message =>
          return .error message)
    state frame

/--
Run one presentation-only Scheduled creation editor session.

The session owns no Scheduled authority. It emits at most one draft to the shared
household command boundary; publication refusal returns to editable local state.
-/
def run
    (bounds : Bounds) (dataDir root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) : IO String := do
  let (created?, notice) ← runWithScheduledId bounds root known state frame
  let some created := created? | return notice
  -- Re-read the exact published identity. A failed reread is reported, never
  -- silently treated as an absent or one-off recurrence expectation.
  let .ok evidence ← Loam.ScheduledReview.loadHouseholdEvidence dataDir root
    | return notice ++ " Expected-pace setup unavailable: Scheduled evidence could not be reloaded."
  let .ok records ← Loam.ScheduledReview.orderedCurrentOpenRecords evidence
    | return notice ++ " Expected-pace setup unavailable: open Scheduled evidence is unreadable."
  let some source := records.find? (fun record => record.id.token == created.token)
    | return notice ++ " Expected-pace setup unavailable: new Scheduled identity not found."
  let bounds ← Loam.Tui.Terminal.currentBounds
  let paceNotice ← Loam.Tui.ScheduledCoverageSetupSession.runAfterCreation
    bounds dataDir source
  return notice ++ " " ++ paceNotice

end Loam.Tui.ScheduledCreationSession
