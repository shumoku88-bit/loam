import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCompletion
import Loam.Tui.UnresolvedActivation
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCompletionSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled completion on the shared floating/compact presentation surface

The selected Scheduled source and independently editable Actual draft remain
ScheduledCompletion-owned. The terminal session owns only input/painting and
delegates the sole completion intent to HouseholdCommand. It still returns Bool:
a successful Actual + Scheduled completion is a durable boundary. Optional later
Scheduled and Attention choices are handled by caller-owned continuation, not
by this modal.
-/

/-- The complete edit/preview may float only when enough room remains. -/
def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 78 35 88 33

/-- A special Record admission prompt is kept in its original full-screen mode,
    rather than assuming it shares the completion review dimensions. -/
def activeGeometry? (bounds : Bounds)
    (state : Loam.Tui.ScheduledCompletion.State) :
    Option Loam.Tui.ModalSurface.Rectangle :=
  match state.editor.mode with
  | .editing | .preview _ _ => floatingGeometry? bounds
  | .enableUnresolved | .originalAmount _ => none

def editorBounds (bounds : Bounds)
    (state : Loam.Tui.ScheduledCompletion.State) : Bounds :=
  match activeGeometry? bounds state with
  | none => bounds
  | some rect => { width := rect.width - 1, height := rect.height - 1 }

def viewForBounds (bounds : Bounds) (known : List String)
    (state : Loam.Tui.ScheduledCompletion.State) : Widget :=
  match activeGeometry? bounds state with
  | none =>
      Loam.Tui.ScheduledCompletion.view bounds known state
  | some rect =>
      Loam.Tui.Layout.framedPanel rect.width rect.height
        "Scheduled / Complete"
        (Loam.Tui.ScheduledCompletion.view (editorBounds bounds state) known state)
        true

private def frameFor (bounds : Bounds) (known : List String)
    (state : Loam.Tui.ScheduledCompletion.State) : CompiledWidget :=
  compileWidget (viewForBounds bounds known state)

/--
The completion loop changes presentation location only. Policy activation still
updates its local World / known vocabulary and completion refusal still returns
to the same editable Actual draft, exactly as in the prior full-screen session.
-/
private partial def runLoop
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.ScheduledCompletion.State) (frame : CompiledWidget)
    (parent : Bounds → CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let geometry := activeGeometry? active state
  let frame ←
    if active == bounds then pure frame
    else do
      let next := frameFor active known state
      Loam.Tui.ModalSurface.repaintOverParent active geometry (parent active) next
      pure next
  if key == .other then
    return (← runLoop active root world known state frame parent)
  let step := Loam.Tui.ScheduledCompletion.updateForBounds
    (editorBounds active state) world known state key
  if step.cancel then return false
  if step.enableUnresolved then
    match ← Loam.Tui.UnresolvedActivation.enableEditor? root step.state.editor with
    | .error message =>
        let editor := Loam.Tui.UnresolvedActivation.withEnableError step.state.editor message
        let next := { step.state with editor := editor }
        let nextFrame := frameFor active known next
        Loam.Tui.ModalSurface.paint active (activeGeometry? active next)
          .dirtyDiff frame nextFrame
        runLoop active root world known next nextFrame parent
    | .ok enabled =>
        let next := { step.state with editor := enabled.editor }
        let nextFrame := frameFor active enabled.known next
        Loam.Tui.ModalSurface.paint active (activeGeometry? active next)
          .dirtyDiff frame nextFrame
        runLoop active root enabled.world enabled.known next nextFrame parent
  else
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.completeScheduled root draft with
        | .ok () => return true
        | .error message =>
            let next := Loam.Tui.ScheduledCompletion.withPublishError step.state message
            let nextFrame := frameFor active known next
            Loam.Tui.ModalSurface.paint active (activeGeometry? active next)
              .dirtyDiff frame nextFrame
            runLoop active root world known next nextFrame parent
    | none =>
        let nextFrame := frameFor active known step.state
        Loam.Tui.ModalSurface.paint active (activeGeometry? active step.state)
          .dirtyDiff frame nextFrame
        runLoop active root world known step.state nextFrame parent

/-- The parent owns its current-bounds frame and the later continuation. -/
def runAdaptive
    (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.ScheduledCompletion.State)
    (parent : Bounds → CompiledWidget) : IO Bool := do
  let active ← Loam.Tui.Terminal.currentBounds
  let geometry := activeGeometry? active state
  let frame := frameFor active known state
  if active == bounds then
    Loam.Tui.ModalSurface.paint active geometry .fromBlank
      (compileWidget (.row [])) frame
  else
    Loam.Tui.ModalSurface.repaintOverParent active geometry (parent active) frame
  runLoop active root world known state frame parent

end Loam.Tui.ScheduledCompletionSession
