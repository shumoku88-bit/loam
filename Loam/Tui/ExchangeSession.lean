import Loam.HouseholdCommand
import Loam.Tui.Exchange
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ExchangeSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Exchange terminal session

The pure Exchange editor owns local presentation state. This shell owns terminal
I/O and delegates one durable publication intent to HouseholdCommand.recordExchange.
-/

partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (world : Loam.ExchangeAdmission.World)
    (state : Loam.Tui.Exchange.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Exchange.update world state (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    return "Exchange cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.recordExchange root draft with
      | .ok eventId =>
          return "Recorded exchange " ++ eventId.token ++ "."
      | .error message =>
          let next := Loam.Tui.Exchange.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.Exchange.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root world next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.Exchange.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root world step.state nextFrame

end Loam.Tui.ExchangeSession
