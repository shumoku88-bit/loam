import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.ScheduledReplacement

namespace Loam.Tui.ScheduledReplacementSession

set_option autoImplicit false

/-!
# Scheduled replacement terminal session

`ScheduledReplacement` owns editor state, validation, transitions, preview, and view.
This module owns the terminal/effect shell for one replacement editor session:
delegate one replacement intent to `HouseholdCommand.replaceScheduled`, and return
publication refusal to editing.

It owns no household authority. The caller remains responsible for selected-record
lookup, editor construction, loading the current vocabulary before the session,
reloading canonical evidence after the session, and choosing the destination
workspace.
-/

/-- Run one Scheduled replacement editor session and return its human-facing completion notice. -/
def run
    (bounds : Loam.Tui.Kernel.Bounds) (root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State)
    (frame : Loam.Tui.Runtime.CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilPublished bounds
    (fun current key =>
      let step := Loam.Tui.ScheduledReplacement.update known current key
      { state := step.state, cancel := step.cancel, publish := step.publish })
    (Loam.Tui.ScheduledReplacement.view known)
    Loam.Tui.ScheduledReplacement.withPublishError
    "Scheduled supersede cancelled."
    (fun draft => do
      match ← Loam.HouseholdCommand.replaceScheduled root draft with
      | .ok () =>
          return .ok ("Superseded " ++ draft.source.token ++ ".")
      | .error message =>
          return .error message)
    state frame

end Loam.Tui.ScheduledReplacementSession
