import Loam.HouseholdCommand
import Loam.Tui.EditorSession
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

/--
Use the existing adaptive editor session for this ordinary editable replacement.
A refused write returns to the exact same draft; cancellation and canonical
reload stay caller-owned. Scheduled cancellation deliberately keeps its
different refusal policy.
-/
def runAdaptive
    (bounds : Bounds) (root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State)
    (parent : Bounds → CompiledWidget) : IO String := do
  let active ← Loam.Tui.Terminal.currentBounds
  let surface := floatingGeometry? active
  let frame := compileWidget (viewForBounds active known state)
  Loam.Tui.ModalSurface.paintEntrance bounds active surface parent frame
  Loam.Tui.EditorSession.runUntilPublishedAdaptive active
    floatingGeometry?
    parent
    (fun current editor key =>
      Loam.Tui.ScheduledReplacement.updateForBounds
        (editorBounds current) known editor key)
    (fun current editor => viewForBounds current known editor)
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
