import Loam.ScheduledCreationPublisher
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCreation
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCreationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/--
Run one presentation-only Scheduled creation editor session, returning the creation receipt if published.
-/
partial def runWithReceipt
    (bounds : Bounds) (scheduledFile root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) :
    IO (Option Loam.ScheduledCreationPublisher.Receipt × String) := do
  let step := Loam.Tui.ScheduledCreation.update known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return (none, "Scheduled creation cancelled.")
  match step.publish with
  | some draft =>
      match ← Loam.ScheduledCreationPublisher.publishManifestCreation
          scheduledFile.toString root.toString draft with
      | .ok receipt =>
          return (some receipt, "Scheduled " ++ receipt.scheduled.token ++ " for " ++ receipt.scheduledOn ++ ".")
      | .error message =>
          let next := Loam.Tui.ScheduledCreation.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ScheduledCreation.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          runWithReceipt bounds scheduledFile root known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCreation.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runWithReceipt bounds scheduledFile root known step.state nextFrame

/--
Run one presentation-only Scheduled creation editor session.

The session owns no Scheduled authority. It emits at most one draft to the shared
creation publisher; publication refusal returns to editable local state.
-/
def run
    (bounds : Bounds) (scheduledFile root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) : IO String := do
  let (_, notice) ← runWithReceipt bounds scheduledFile root known state frame
  return notice

end Loam.Tui.ScheduledCreationSession
