import Loam.HouseholdCommand
import Loam.Tui.Correction
import Loam.Tui.ModalSurface
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

private def placeFocusCursor (bounds : Bounds) (state : Loam.Tui.Correction.State)
    (frame : CompiledWidget) : IO Unit :=
  Loam.Tui.ModalSurface.placeTextCaret bounds none
    (Loam.Tui.Record.isTextEditing state.editor) frame

private def redraw (bounds : Bounds) (state : Loam.Tui.Correction.State)
    (old next : CompiledWidget) : IO Unit := do
  Loam.Tui.ModalSurface.hideTextCaret
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 old next
  placeFocusCursor bounds state next

private partial def runLoop
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let (bounds, frame) ← if active == bounds then pure (bounds, frame) else do
    Loam.Tui.ModalSurface.hideTextCaret
    let next := compileWidget (Loam.Tui.Correction.view active known state)
    Loam.Tui.Terminal.redrawFromBlank active next
    placeFocusCursor active state next
    pure (active, next)
  let state := Loam.Tui.Correction.normalizedForBounds bounds state
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
        redraw bounds next frame nextFrame
        runLoop bounds root world known next nextFrame
    | .ok enabled =>
        let next := { step.state with editor := enabled.editor }
        let nextFrame := compileWidget (Loam.Tui.Correction.view bounds enabled.known next)
        redraw bounds next frame nextFrame
        runLoop bounds root enabled.world enabled.known next nextFrame
  else
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.correctActual root draft with
        | .ok () => return "Corrected " ++ draft.target.token ++ "."
        | .error message =>
            let next := Loam.Tui.Correction.withPublishError step.state message
            let nextFrame := compileWidget (Loam.Tui.Correction.view bounds known next)
            redraw bounds next frame nextFrame
            runLoop bounds root world known next nextFrame
    | none =>
        let nextFrame := compileWidget (Loam.Tui.Correction.view bounds known step.state)
        redraw bounds step.state frame nextFrame
        runLoop bounds root world known step.state nextFrame

/-- Run one Correction editor session and return its human-facing completion notice. -/
def run
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String :=
  Loam.Tui.ModalSurface.withTextCaret do
    placeFocusCursor bounds state frame
    runLoop bounds root world known state frame

end Loam.Tui.CorrectionSession
