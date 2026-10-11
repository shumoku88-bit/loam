import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCancellation
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCancellationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled cancellation on a reusable adaptive modal surface

The local editor retains the selected Scheduled identity, protected action
selection, scroll state, and precise publisher intent. The shared surface owns
only physical placement and painting. The caller supplies the parent view at
fresh bounds and still reloads canonical evidence on return.
-/

/-- Show a bounded overlay on a terminal with enough review area. -/
def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 72 24 76 20

/-- The editor sees the actual size inside the optional surrounding frame. -/
def editorBounds (bounds : Bounds) : Bounds :=
  match floatingGeometry? bounds with
  | none => bounds
  | some region => { width := region.width - 1, height := region.height - 1 }

/-- The exact same domain review is rendered for floating and compact modes. -/
def viewForBounds (bounds : Bounds)
    (state : Loam.Tui.ScheduledCancellation.State) : Widget :=
  match floatingGeometry? bounds with
  | none => Loam.Tui.ScheduledCancellation.view bounds state
  | some region =>
      Loam.Tui.Layout.framedPanel region.width region.height
        "Scheduled / Cancel"
        (Loam.Tui.ScheduledCancellation.view (editorBounds bounds) state) true

/--
Resize/paint loop only. Do not genericize publication refusal: cancellation
must return to the owner for a fresh Scheduled authority read after refusal.
-/
private partial def runLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ScheduledCancellation.State)
    (frame : CompiledWidget)
    (parent : Bounds → CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let geometry := floatingGeometry? active
  let frame ←
    if active == bounds then
      pure frame
    else do
      let resized := compileWidget (viewForBounds active state)
      Loam.Tui.ModalSurface.repaintOverParent active geometry
        (parent active) resized
      pure resized
  if key == .other then
    return (← runLoop active root state frame parent)
  let step := Loam.Tui.ScheduledCancellation.updateForBounds
    (editorBounds active) state key
  if step.cancel then return "Scheduled cancellation kept the occurrence open."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.cancelScheduled root draft with
      | .ok () => return "Cancelled " ++ draft.scheduled.token ++ "."
      | .error message => return "Scheduled cancellation refused: " ++ message
  | none =>
      let nextFrame := compileWidget (viewForBounds active step.state)
      Loam.Tui.ModalSurface.paint active geometry .dirtyDiff frame nextFrame
      runLoop active root step.state nextFrame parent

/--
Open against the current parent surface. After exit, the caller remains the
owner of canonical reload, fresh selection and terminal restoration.
-/
def runAdaptive
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ScheduledCancellation.State)
    (parent : Bounds → CompiledWidget) : IO String := do
  let active ← Loam.Tui.Terminal.currentBounds
  let geometry := floatingGeometry? active
  let frame := compileWidget (viewForBounds active state)
  if active == bounds then
    Loam.Tui.ModalSurface.paint active geometry .fromBlank
      (compileWidget (.row [])) frame
  else
    Loam.Tui.ModalSurface.repaintOverParent active geometry
      (parent active) frame
  runLoop active root state frame parent

end Loam.Tui.ScheduledCancellationSession
