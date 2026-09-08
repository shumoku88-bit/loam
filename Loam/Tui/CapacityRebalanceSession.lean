import Loam.CapacityPublisher
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
balanced draft to the shared `CapacityPublisher.publishBalanced`.

Publication re-reads authority and effective evidence under writer ownership.
On publication or cancellation, the session returns to the caller, which reloads
the shared Capacity review snapshot.
-/

partial def run
    (bounds : Bounds)
    (capacityFile : System.FilePath)
    (state : Loam.Tui.CapacityRebalance.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.CapacityRebalance.update state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    pure "Capacity rebalance cancelled."
  else
    match step.publish with
    | some draft =>
        match ← Loam.CapacityPublisher.publishBalanced capacityFile.toString draft with
        | .ok receipt =>
            pure
              ("Rebalanced Capacity across " ++ toString receipt.changes.length ++
               " purposes (" ++ receipt.movement.token ++ "). Effective: " ++ receipt.effectiveOn ++ ".")
        | .error message =>
            pure ("Capacity rebalance refused: " ++ message)
    | none =>
        let nextFrame := compileWidget (Loam.Tui.CapacityRebalance.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds capacityFile step.state nextFrame

end Loam.Tui.CapacityRebalanceSession
