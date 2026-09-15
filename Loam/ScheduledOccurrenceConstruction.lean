import Loam.Core.ScheduledMemory
import Loam.FreshNumberedToken

namespace Loam.ScheduledOccurrenceConstruction

open Loam.Core

set_option autoImplicit false

/-- Pure total fresh-occurrence mechanics shared by Scheduled publication operations. -/
def freshId (memory : ScheduledMemory String) : ScheduledId :=
  let used := memory.occurrences.map (fun occurrence => occurrence.id.token)
  ⟨Loam.firstUnusedNumberedToken "scheduled-" used 1⟩

/-- Derived positive-side total of one already-balanced Scheduled movement. -/
def positiveTotalQuanta (movement : BalancedMovement LocusId) : Int :=
  movement.changes.foldl
    (fun total change => total + max 0 change.quantity.quanta) 0

end Loam.ScheduledOccurrenceConstruction
