import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCompletion
import Loam.Tui.UnresolvedActivation
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCompletionSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled completion terminal session

`ScheduledCompletion` owns editor state, validation, transitions, preview, and view.
This module owns only the terminal/effect shell for one completion editor session:
read one key at a time, redraw the editor, delegate one completion intent to
`HouseholdCommand.completeScheduled`, and return publication refusal to editing.

The session intentionally returns only whether completion was published. Optional
next-Scheduled creation, routing inheritance, canonical reload, and destination
workspace refresh remain caller-owned continuation semantics. The Boolean result
is the explicit stop line before that continuation begins.
-/

/-- Run one Scheduled completion editor session. `true` means completion publication succeeded. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.ScheduledCompletion.State) (frame : CompiledWidget) :
    IO Bool := do
  let step := Loam.Tui.ScheduledCompletion.update world known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return false
  if step.enableUnresolved then
    match ← Loam.Tui.UnresolvedActivation.enable? root with
    | .error message =>
        let editor := {
          step.state.editor with
          mode := Loam.Tui.Record.Mode.editing
          notice := "Unresolved recording was not enabled: " ++ message }
        let next := { step.state with editor := editor }
        let nextFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known next)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root world known next nextFrame
    | .ok enabled =>
        let editorBase := Loam.Tui.Record.withCatalog
          { step.state.editor with mode := Loam.Tui.Record.Mode.editing } enabled.catalog
        let editor :=
          match Loam.Tui.Record.fillUnresolvedRemainder? enabled.world editorBase with
          | .ok filled =>
              { filled with notice := "Unresolved recording enabled; remainder filled." }
          | .error message =>
              { editorBase with notice := "Unresolved recording enabled. " ++ message }
        let next := { step.state with editor := editor }
        let nextFrame := compileWidget (Loam.Tui.ScheduledCompletion.view enabled.known next)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root enabled.world enabled.known next nextFrame
  else
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.completeScheduled root draft with
        | .ok () => return true
        | .error message =>
            let next := Loam.Tui.ScheduledCompletion.withPublishError step.state message
            let nextFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known next)
            Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
            run bounds root world known next nextFrame
    | none =>
        let nextFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root world known step.state nextFrame

end Loam.Tui.ScheduledCompletionSession
