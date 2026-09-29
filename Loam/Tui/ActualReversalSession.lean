import Loam.HouseholdCommand
import Loam.Tui.ActualReversal
import Loam.Tui.EditorSession

namespace Loam.Tui.ActualReversalSession

set_option autoImplicit false

/--
Run one local reversal confirmation session. Durable admission and exact inverse
construction remain exclusively owned by the shared publisher behind
`HouseholdCommand`.
-/
def run
    (bounds : Loam.Tui.Kernel.Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.ActualReversal.State)
    (frame : Loam.Tui.Runtime.CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilPublished bounds
    Loam.Tui.ActualReversal.update
    Loam.Tui.ActualReversal.view
    Loam.Tui.ActualReversal.withPublishError
    "Actual reversal cancelled."
    (fun draft => do
      match ← Loam.HouseholdCommand.reverseActual root draft with
      | .ok () =>
          return .ok ("Reversed " ++ draft.target.token ++ ".")
      | .error message =>
          return .error message)
    state frame

end Loam.Tui.ActualReversalSession
