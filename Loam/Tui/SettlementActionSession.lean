import Loam.HouseholdCommand
import Loam.Tui.EditorSession
import Loam.Tui.SettlementAction

namespace Loam.Tui.SettlementActionSession

set_option autoImplicit false

/--
Run one friendly settlement action editor.

The session owns terminal effects only. The editor emits a small human-intent
draft; HouseholdCommand delegates identity allocation, canonical re-read,
append-only translation, admission, and atomic publication to the shared
SettlementActionPublisher.
-/
def run
    (bounds : Loam.Tui.Kernel.Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.SettlementAction.State)
    (frame : Loam.Tui.Runtime.CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilPublished bounds
    (Loam.Tui.SettlementAction.update)
    Loam.Tui.SettlementAction.view
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
