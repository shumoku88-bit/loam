import Loam.Core.ScheduledMemory
import Loam.FreshNumberedToken

namespace Loam.ScheduledOccurrenceConstruction

open Loam.Core

set_option autoImplicit false

/-- Pure fresh-occurrence mechanics shared by Scheduled publication operations. -/
def freshId? (memory : ScheduledMemory String) : Option ScheduledId := do
  let token ← Loam.firstUnusedNumberedToken?
    "scheduled-"
    (fun token => (ScheduledMemory.findById? memory (⟨token⟩ : ScheduledId)).isSome)
    1
    (memory.occurrences.length + 1)
  pure ⟨token⟩

/-- Derived positive-side total of one already-balanced Scheduled movement. -/
def positiveTotalQuanta (movement : BalancedMovement LocusId) : Int :=
  movement.changes.foldl
    (fun total change => total + max 0 change.quantity.quanta) 0

end Loam.ScheduledOccurrenceConstruction
