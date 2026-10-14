import Loam.HouseholdCommand
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.EditorSession
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
authoritative write to the shared household command boundary. Every publish
attempt returns to Home. A later administration entrance loads a fresh review,
rather than retrying against the editor's old snapshot.
-/

private def effectiveText : RoutingEffective String → String
  | .initial => "initial"
  | .dated date => date

/--
Publish-once route administration: a refused write may mean a stale routing
snapshot and must leave this editor. The caller can reopen it from fresh
review evidence instead of continuing with a now-outdated proposal.
-/
def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.ActualRoutingAdministration.State)
    (frame : CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilAttemptResizing bounds
    Loam.Tui.ActualRoutingAdministration.update
    (fun current editor => Loam.Tui.ActualRoutingAdministration.view current editor)
    (fun _ => "Actual routing administration cancelled.")
    (fun draft => do
      match ← Loam.HouseholdCommand.routeActual root draft with
      | .ok () =>
          let target :=
            match draft.target with
            | .managed purpose => "managed " ++ purpose.token
            | .unmanaged => "unmanaged"
          return "Routed " ++ draft.locus.token ++ " -> " ++ target ++
            ". Effective: " ++ effectiveText draft.effectiveOn ++ "."
      | .error message => return "Actual routing refused: " ++ message)
    state frame

end Loam.Tui.ActualRoutingAdministrationSession
