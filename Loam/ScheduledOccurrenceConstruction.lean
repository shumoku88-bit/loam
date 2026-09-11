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

def movementFromEffects? (effects : List Effect) : Option (BalancedMovement LocusId) := do
  let changes : List (MovementChange LocusId) :=
    effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  BalancedMovement.ofChanges? ⟨"jpy"⟩ changes

def occurrenceFromEffects?
    (id : ScheduledId) (scheduledOn : String) (effects : List Effect) :
    Option (ScheduledOccurrence String) := do
  let movement ← movementFromEffects? effects
  pure { id := id, scheduledOn := scheduledOn, movement := movement }

end Loam.ScheduledOccurrenceConstruction
