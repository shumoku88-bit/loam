import Loam.CapacityPublisher
import Loam.HouseholdCommand
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

partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.CapacityTransfer.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.CapacityTransfer.update state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    pure (if state.grantContext.isSome then "Cycle grant cancelled." else "Capacity transfer cancelled.")
  else
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.moveCapacity root draft with
        | .ok receipt =>
            pure
              ("Moved " ++ toString receipt.quanta ++ " jpy Capacity: " ++
                Loam.CapacityPublisher.coordinateToken receipt.source ++ " -> " ++
                Loam.CapacityPublisher.coordinateToken receipt.destination ++
                ". Effective: " ++ receipt.effectiveOn ++ ".")
        | .error message =>
            pure ("Capacity transfer refused: " ++ message)
    | none =>
        let nextFrame := compileWidget (Loam.Tui.CapacityTransfer.view step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root step.state nextFrame

end Loam.Tui.CapacityTransferSession
