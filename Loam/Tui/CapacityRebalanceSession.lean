import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.CapacityRebalance
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.CapacityRebalanceSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Capacity Rebalance terminal session

The session drives one presentation-only rebalance editor and emits at most one
balanced draft to the shared household command boundary.

Publication re-reads authority and effective evidence under writer ownership.
On publication or cancellation, the session returns to the caller, which reloads
the shared Capacity review snapshot.
-/

def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.CapacityRebalance.State)
    (frame : CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilAttemptResizing bounds
    Loam.Tui.CapacityRebalance.update
    (fun current editor => Loam.Tui.CapacityRebalance.view current editor)
    (fun _ => "Capacity rebalance cancelled.")
    (fun draft => do
      match ← Loam.HouseholdCommand.rebalanceCapacity root draft with
      | .ok movementId =>
          return ("Rebalanced Capacity across " ++ toString draft.changes.length ++
             " purposes (" ++ movementId.token ++ "). Effective: " ++ draft.effectiveOn ++ ".")
      | .error message =>
          -- Refusal ends the session: the caller obtains a fresh Capacity snapshot.
          return "Capacity rebalance refused: " ++ message)
    state frame

end Loam.Tui.CapacityRebalanceSession
