import Loam.HouseholdCommand
import Loam.Tui.ActualReversal
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ActualReversalSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/--
Run one local reversal confirmation session. Durable admission and exact inverse
construction remain exclusively owned by the shared publisher behind
`HouseholdCommand`.
-/
partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.ActualReversal.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ActualReversal.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    return "Actual reversal cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.reverseActual root draft with
      | .ok receipt =>
          return "Reversed " ++ receipt.target.token ++ " with " ++ receipt.reversal.token ++ "."
      | .error message =>
          let next := Loam.Tui.ActualReversal.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ActualReversal.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ActualReversal.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root step.state nextFrame

end Loam.Tui.ActualReversalSession
