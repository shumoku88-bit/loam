import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledReplacement
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledReplacementSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled replacement terminal session

`ScheduledReplacement` owns editor state, validation, transitions, preview, and view.
This module owns the terminal/effect shell for one replacement editor session:
read one key at a time, redraw the editor, delegate one replacement intent to
`HouseholdCommand.replaceScheduled`, and return publication refusal to editing.

It owns no household authority. The caller remains responsible for selected-record
lookup, editor construction, loading the current vocabulary before the session,
reloading canonical evidence after the session, and choosing the destination
workspace.
-/

/-- Run one Scheduled replacement editor session and return its human-facing completion notice. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledReplacement.update known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled supersede cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.replaceScheduled root draft with
      | .ok () =>
          return "Superseded " ++ draft.source.token ++ "."
      | .error message =>
          let next := Loam.Tui.ScheduledReplacement.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root known step.state nextFrame

end Loam.Tui.ScheduledReplacementSession
