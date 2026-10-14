import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.SettlementAction
import Loam.Tui.Kernel
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.SettlementActionSession

open Loam.Tui.Kernel Loam.Tui.Runtime

set_option autoImplicit false

/--
The earlier-reduction list is unbounded. It must never be squeezed into a
fixed-height floating panel if the list could exceed the panel. The count is
retained row evidence captured at session entrance; no publication changes it
while the editor is open.
-/
def floatingGeometry? (bounds : Bounds) (reductionCount : Nat) :
    Option Loam.Tui.ModalSurface.Rectangle :=
  if reductionCount > 12 then none
  else Loam.Tui.ModalSurface.centered? bounds 72 28 90 23

def viewForBounds (bounds : Bounds) (reductionCount : Nat)
    (state : Loam.Tui.SettlementAction.State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds reductionCount)
    "Settlement / Action"
    (fun _ => Loam.Tui.SettlementAction.view state)

/--
Use the same domain-owned editor and publish/refusal logic for a floating or
compact presentation, restoring the parent on terminal resize.
-/
def runAdaptive
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.SettlementAction.State)
    (parent : Bounds → CompiledWidget) : IO String := do
  let active ← Loam.Tui.Terminal.currentBounds
  let reductionCount := state.row.extinguishments.length
  let geometry := fun current => floatingGeometry? current reductionCount
  let view := fun current editor => viewForBounds current reductionCount editor
  let frame := compileWidget (view active state)
  Loam.Tui.ModalSurface.paintEntrance bounds active (geometry active) parent frame
  Loam.Tui.EditorSession.runUntilPublishedAdaptive active
    geometry parent
    (fun _ editor key => Loam.Tui.SettlementAction.update editor key)
    view
    Loam.Tui.SettlementAction.withPublishError
    "Settlement action cancelled."
    (fun intent => do
      match intent with
      | .correctAmount draft =>
          match ← Loam.HouseholdCommand.correctSettlementAmount root draft with
          | .ok _ => return .ok "Settlement amount updated."
          | .error message => return .error message
      | .retract draft =>
          match ← Loam.HouseholdCommand.retractSettlement root draft with
          | .ok () => return .ok "Settlement record marked as erroneous."
          | .error message => return .error message
      | .reduceWithoutPayment draft =>
          match ← Loam.HouseholdCommand.reduceSettlementWithoutPayment root draft with
          | .ok _ =>
              return .ok
                ("Remaining amount reduced by " ++ toString draft.quantity.quanta ++
                  " without payment.")
          | .error message => return .error message
      | .correctReduction draft =>
          match ← Loam.HouseholdCommand.correctSettlementReduction root draft with
          | .ok _ => return .ok "Earlier non-payment decrease updated."
          | .error message => return .error message
      | .retractReduction draft =>
          match ← Loam.HouseholdCommand.retractSettlementReduction root draft with
          | .ok () => return .ok "Earlier non-payment decrease marked as erroneous."
          | .error message => return .error message)
    state frame

end Loam.Tui.SettlementActionSession
