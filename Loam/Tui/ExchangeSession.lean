import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.Exchange

namespace Loam.Tui.ExchangeSession

set_option autoImplicit false

/-!
# Exchange terminal session

The pure Exchange editor owns local presentation state. This shell owns terminal
I/O and delegates one durable publication intent to HouseholdCommand.recordExchange.
-/

def run
    (bounds : Loam.Tui.Kernel.Bounds)
    (root : System.FilePath)
    (world : Loam.ExchangeAdmission.World)
    (state : Loam.Tui.Exchange.State)
    (frame : Loam.Tui.Runtime.CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilPublished bounds
    (fun current key =>
      let step := Loam.Tui.Exchange.update world current key
      { state := step.state, cancel := step.cancel, publish := step.publish })
    Loam.Tui.Exchange.view
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
