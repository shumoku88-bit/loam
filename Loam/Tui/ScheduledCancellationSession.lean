import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCancellation
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCancellationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled cancellation session

Owns only the presentation confirmation loop. Canonical cancellation admission
and publication remain in `Loam.HouseholdCommand` and its existing publisher boundary.
-/

/-- Confirmation stays presentation-local; publisher refusal returns a notice to the caller. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ScheduledCancellation.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCancellation.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled cancellation kept the occurrence open."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.cancelScheduled root draft with
      | .ok () => return "Cancelled " ++ draft.scheduled.token ++ "."
      | .error message => return "Scheduled cancellation refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCancellation.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root step.state nextFrame

end Loam.Tui.ScheduledCancellationSession
