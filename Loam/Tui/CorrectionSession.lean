import Loam.HouseholdCommand
import Loam.Tui.Correction
import Loam.Tui.RecordSession
import Loam.Tui.UnresolvedActivation
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

private def placeFocusCursor (bounds : Bounds) (frame : CompiledWidget) : IO Unit := do
  match Loam.Tui.RecordSession.focusedCursorPosition? 0 0 frame with
  | none => pure ()
  | some (row, col) =>
      Loam.Tui.Terminal.placeCursor
        (min row (bounds.height - 1)) (min col (Loam.Tui.Layout.contentWidth bounds - 1))

private def redraw (bounds : Bounds) (old next : CompiledWidget) : IO Unit := do
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 old next
  placeFocusCursor bounds next

private partial def runLoop
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let previousBounds := bounds
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.Correction.view active known state)
  let state := Loam.Tui.Correction.normalizedForBounds bounds state
  if bounds != previousBounds then placeFocusCursor bounds frame
  if key == .other then return (← runLoop bounds root world known state frame)
  let step := match Loam.Tui.Correction.scrollPreview bounds state key with
    | some next => { state := next : Loam.Tui.Correction.Step }
    | none => Loam.Tui.Correction.update world known state key
  if step.cancel then return "Correction cancelled."
  if step.enableUnresolved then
    match ← Loam.Tui.UnresolvedActivation.enableEditor? root step.state.editor with
    | .error message =>
        let editor := Loam.Tui.UnresolvedActivation.withEnableError step.state.editor message
        let next := { step.state with editor := editor }
        let nextFrame := compileWidget (Loam.Tui.Correction.view bounds known next)
        redraw bounds frame nextFrame
        runLoop bounds root world known next nextFrame
    | .ok enabled =>
        let next := { step.state with editor := enabled.editor }
        let nextFrame := compileWidget (Loam.Tui.Correction.view bounds enabled.known next)
        redraw bounds frame nextFrame
        runLoop bounds root enabled.world enabled.known next nextFrame
  else
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.correctActual root draft with
        | .ok () => return "Corrected " ++ draft.target.token ++ "."
        | .error message =>
            let next := Loam.Tui.Correction.withPublishError step.state message
            let nextFrame := compileWidget (Loam.Tui.Correction.view bounds known next)
            redraw bounds frame nextFrame
            runLoop bounds root world known next nextFrame
    | none =>
        let nextFrame := compileWidget (Loam.Tui.Correction.view bounds known step.state)
        redraw bounds frame nextFrame
        runLoop bounds root world known step.state nextFrame

/-- Run one Correction editor session and return its human-facing completion notice. -/
def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String := do
  placeFocusCursor bounds frame
  runLoop bounds root world known state frame

end Loam.Tui.CorrectionSession
