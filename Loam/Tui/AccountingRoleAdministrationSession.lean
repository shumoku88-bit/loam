import Loam.AccountingRolePublisher
import Loam.Tui.AccountingRoleAdministration
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.AccountingRoleAdministrationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Initial AccountingRole administration terminal session

The session owns only local selection/preview state. Publication is delegated to
`AccountingRolePublisher.publishInitialRole`, which re-reads all relevant
Authorities under WriterOwnership before allowing the first role assertion.
-/

partial def run
    (bounds : Bounds)
    (scheduledFile root roleFile : System.FilePath)
    (state : Loam.Tui.AccountingRoleAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.AccountingRoleAdministration.update state key
  if step.cancel then
    return "AccountingRole assignment cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.AccountingRolePublisher.publishInitialRole
          scheduledFile.toString root.toString roleFile.toString draft with
      | .ok receipt =>
          return "Assigned initial AccountingRole to " ++ receipt.locus.token ++ ". Roles: " ++
            toString receipt.previousCount ++ " -> " ++ toString receipt.currentCount ++ "."
      | .error message => return "AccountingRole assignment refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds scheduledFile root roleFile step.state nextFrame

end Loam.Tui.AccountingRoleAdministrationSession
