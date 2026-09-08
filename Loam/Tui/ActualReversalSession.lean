import Loam.ActualReversalPublisher
import Loam.Tui.ActualReversal
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.ActualReversalSession

open Loam.Tui.Kernel

set_option autoImplicit false

/--
Run one local reversal confirmation session. Durable admission and exact inverse
construction remain exclusively owned by `ActualReversalPublisher`.
-/
partial def run
    (bounds : Bounds)
    (scheduledFile root correctionFile reversalFile : System.FilePath)
    (state : Loam.Tui.ActualReversal.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ActualReversal.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    return "Actual reversal cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.ActualReversalPublisher.publishManifestReversal
          scheduledFile.toString root.toString correctionFile.toString reversalFile.toString draft with
      | .ok receipt =>
          return "Reversed " ++ receipt.target.token ++ " with " ++ receipt.reversal.token ++ "."
      | .error message =>
          let next := Loam.Tui.ActualReversal.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ActualReversal.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds scheduledFile root correctionFile reversalFile next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ActualReversal.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds scheduledFile root correctionFile reversalFile step.state nextFrame

end Loam.Tui.ActualReversalSession
