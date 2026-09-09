import Loam.ActualRoutingPublisher
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.ActualRoutingAdministrationSession

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Actual routing administration terminal session

The session drives presentation-only administration state and delegates the one
authoritative write to `ActualRoutingPublisher.publish`. The caller reloads the
shared review after publication.
-/

private def effectiveText : RoutingEffective String → String
  | .initial => "initial"
  | .dated date => date

partial def run
    (bounds : Bounds)
    (routingFile : System.FilePath)
    (state : Loam.Tui.ActualRoutingAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.ActualRoutingAdministration.update state key
  if step.cancel then
    return "Actual routing administration cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.ActualRoutingPublisher.publish routingFile.toString draft with
      | .ok receipt =>
          let target :=
            match receipt.target with
            | .managed purpose => "managed " ++ purpose.token
            | .unmanaged => "unmanaged"
          return "Routed " ++ receipt.locus.token ++ " -> " ++ target ++
            ". Effective: " ++ effectiveText receipt.effectiveOn ++ "."
      | .error message => return "Actual routing refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ActualRoutingAdministration.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds routingFile step.state nextFrame

end Loam.Tui.ActualRoutingAdministrationSession
