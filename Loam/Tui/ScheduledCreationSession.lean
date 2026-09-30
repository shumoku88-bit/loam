import Loam.HouseholdCommand
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCreation
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
  let step := Loam.Tui.ScheduledCreation.update known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return none
  match step.publish with
  | some draft => return some draft
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCreation.view known step.state)
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
    (Loam.Tui.ScheduledCreation.update known)
    (Loam.Tui.ScheduledCreation.view known)
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
    (bounds : Bounds) (root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) : IO String := do
  let (_, notice) ← runWithScheduledId bounds root known state frame
  return notice

end Loam.Tui.ScheduledCreationSession
