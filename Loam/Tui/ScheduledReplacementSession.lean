import Loam.HouseholdCommand
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.ScheduledReplacement
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledReplacementSession

open Loam.Tui.Kernel Loam.Tui.Runtime
set_option autoImplicit false

/-!
# Scheduled replacement on the shared adaptive modal surface

The same bounds-aware editing/preview state from #1920 is now positioned by
ModalSurface. The chosen source, focus, signed postings, preview draft,
refusal-to-edit policy and authority stay inside ScheduledReplacement and
HouseholdCommand. The parent remains caller-owned and is rendered fresh on resize.
-/

/-- Float the complete replacement editor when review and fields can fit. -/
def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 78 35 88 33

/-- The existing replacement view receives its actual bounded inner viewport. -/
def editorBounds (bounds : Bounds) : Bounds :=
  Loam.Tui.ModalSurface.contentBounds bounds (floatingGeometry? bounds)

def viewForBounds (bounds : Bounds) (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds)
    "Scheduled / Supersede"
    (fun inner => Loam.Tui.ScheduledReplacement.viewForBounds inner known state)

private def render (bounds : Bounds) (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State) : CompiledWidget :=
  compileWidget (viewForBounds bounds known state)

/--
Unlike Scheduled cancellation, publication refusal returns to *this editable
draft*. Do not absorb that policy into ModalSurface or the cancellation session.
-/
private partial def runLoop
    (bounds : Bounds) (root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State) (frame : CompiledWidget)
    (parent : Bounds → CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let surface := floatingGeometry? active
  let frame ←
    if active == bounds then pure frame
    else do
      let next := render active known state
      Loam.Tui.ModalSurface.repaintOverParent active surface (parent active) next
      pure next
  if key == .other then
    return (← runLoop active root known state frame parent)
  let step := Loam.Tui.ScheduledReplacement.updateForBounds
    (editorBounds active) known state key
  if step.cancel then
    return "Scheduled supersede cancelled."
  let outcome ←
    match step.publish with
    | none => pure (.ok step.state : Except String Loam.Tui.ScheduledReplacement.State)
    | some draft =>
        match ← Loam.HouseholdCommand.replaceScheduled root draft with
        | .ok () => pure (.error ("Superseded " ++ draft.source.token ++ "."))
        | .error message =>
            pure (.ok (Loam.Tui.ScheduledReplacement.withPublishError step.state message))
  match outcome with
  | .error notice => return notice
  | .ok nextState =>
      let nextFrame := render active known nextState
      Loam.Tui.ModalSurface.paint active surface .dirtyDiff frame nextFrame
      runLoop active root known nextState nextFrame parent

/--
Open over the correct caller parent. After return, callers reload canonical
evidence and redraw the parent using fresh bounds as before.
-/
def runAdaptive
    (bounds : Bounds) (root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State)
    (parent : Bounds → CompiledWidget) : IO String := do
  let active ← Loam.Tui.Terminal.currentBounds
  let surface := floatingGeometry? active
  let frame := render active known state
  Loam.Tui.ModalSurface.paintEntrance bounds active surface parent frame
  runLoop active root known state frame parent

end Loam.Tui.ScheduledReplacementSession
