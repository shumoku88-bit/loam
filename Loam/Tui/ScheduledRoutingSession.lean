import Loam.ScheduledRoutingPublisher
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledRouting
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledRoutingSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Scheduled routing terminal session

The session owns no routing authority; it drives one presentation-only routing
editor and emits at most one draft to the shared `ScheduledRoutingPublisher.publish`.

Publication re-reads authority under writer ownership. On publication or
cancellation, the session returns to the caller, which reloads the shared
CycleBudget snapshot from canonical disk evidence.
-/

partial def run
    (bounds : Bounds)
    (routingFile scheduledFile : System.FilePath)
    (state : Loam.Tui.ScheduledRouting.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.ScheduledRouting.update bounds state key
  if step.cancel then
    return "Scheduled routing cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.ScheduledRoutingPublisher.publish routingFile.toString scheduledFile.toString draft with
      | .ok receipt =>
          let targetDesc :=
            match receipt.target with
            | .managed p => "managed " ++ p.token
            | .unmanaged => "unmanaged"
          return "Routed " ++ receipt.subject.scheduled.token ++ " / " ++
            receipt.subject.locus.token ++ " -> " ++ targetDesc ++
            ". Effective: " ++ receipt.effectiveOn ++ "."
      | .error message =>
          return "Scheduled routing refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledRouting.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds routingFile scheduledFile step.state nextFrame

end Loam.Tui.ScheduledRoutingSession
