import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.Exchange
import Loam.Tui.Kernel
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ExchangeSession

open Loam.Tui.Kernel Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Exchange terminal session

Keep all local edits, review, refusal, and exact-quantity semantics in Exchange.
Use the established modal geometry and adaptive terminal loop for both a bounded
floating panel and a small-terminal full-screen fallback. Only
HouseholdCommand.recordExchange publishes household authority.
-/

/-- Float only when the entire exchange editor and review fit. -/
def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 72 28 84 25

/-- The very same editor content is used in both presentation modes. -/
def viewForBounds (bounds : Bounds) (state : Loam.Tui.Exchange.State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds)
    "Exchange / Record"
    (fun inner => Loam.Tui.Exchange.viewForContentBounds inner state)

/--
The parent is caller-owned and repainted at fresh geometry on resize.
Cancellation, explicit preview, and publication-refusal retry remain unchanged.
-/
def runAdaptive
    (bounds : Bounds)
    (root : System.FilePath)
    (world : Loam.ExchangeAdmission.World)
    (state : Loam.Tui.Exchange.State)
    (parent : Bounds → CompiledWidget) : IO String := do
  let active ← Loam.Tui.Terminal.currentBounds
  let surface := floatingGeometry? active
  let frame := compileWidget (viewForBounds active state)
  Loam.Tui.ModalSurface.paintEntrance bounds active surface parent frame
  Loam.Tui.EditorSession.runUntilPublishedAdaptive active
    floatingGeometry?
    parent
    (fun _ editor key => Loam.Tui.Exchange.update world editor key)
    (fun current editor => viewForBounds current editor)
    Loam.Tui.Exchange.withPublishError
    "Exchange cancelled."
    (fun draft => do
      match ← Loam.HouseholdCommand.recordExchange root draft with
      | .ok eventId =>
          return .ok ("Recorded exchange " ++ eventId.token ++ ".")
      | .error message =>
          return .error message)
    state frame

end Loam.Tui.ExchangeSession
