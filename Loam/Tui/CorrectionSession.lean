import Loam.HouseholdCommand
import Loam.Tui.Correction
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.CorrectionSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Correction terminal session

`Correction` owns replacement-editor state, validation, transitions, and view.
This module owns the terminal/effect shell for one correction editor session:
read one key at a time, redraw the editor, delegate one replacement intent to
`HouseholdCommand.correctActual`, and return publication refusal to editing.

It owns no household authority. The caller remains responsible for loading
the selected world before the session, reloading canonical evidence after the
session, and choosing the destination surface.
-/

/-- Run one Correction editor session and return its human-facing completion notice. -/
partial def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Correction.update world known state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Correction cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.correctActual root draft with
      | .ok () =>
          return "Corrected " ++ draft.target.token ++ "."
      | .error message =>
          let next := Loam.Tui.Correction.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.Correction.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root world known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.Correction.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root world known step.state nextFrame

end Loam.Tui.CorrectionSession
