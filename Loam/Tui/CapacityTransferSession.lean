import Loam.Publisher.CapacityPublisher
import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.CapacityTransfer
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.CapacityTransferSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Capacity transfer terminal session

The session owns no Capacity authority. It drives one presentation-only editor
and emits at most one draft to the shared household command boundary.

Unlike a purely local validation refusal, a shared publisher refusal may mean the
source Entitlement or retained evidence changed after this editor was opened. The
session therefore returns to the caller instead of continuing with a stale
Capacity snapshot; the caller reloads shared Capacity review before rendering the
workspace again.
-/

def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.CapacityTransfer.State)
    (frame : CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilAttemptResizing bounds
    Loam.Tui.CapacityTransfer.update
    (fun _ editor => Loam.Tui.CapacityTransfer.view editor)
    (fun editor =>
      if editor.grantContext.isSome then "Cycle grant cancelled."
      else "Capacity transfer cancelled.")
    (fun draft => do
      match ← Loam.HouseholdCommand.moveCapacity root draft with
      | .ok _ =>
          return
            ("Moved " ++ toString draft.quanta ++ " " ++ draft.measure.token ++ " Capacity: " ++
              Loam.CapacityPublisher.coordinateToken draft.source ++ " -> " ++
              Loam.CapacityPublisher.coordinateToken draft.destination ++
              ". Effective: " ++ draft.effectiveOn ++ ".")
      | .error message =>
          -- Publication refusal is terminal: the caller reloads fresh Capacity.
          return "Capacity transfer refused: " ++ message)
    state frame

end Loam.Tui.CapacityTransferSession
