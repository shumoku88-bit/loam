import Loam.Core.ScheduledMemory
import Loam.FreshNumberedToken

namespace Loam.ScheduledOccurrenceConstruction

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled occurrence construction mechanics

This module owns only presentation-neutral mechanics shared by independent
Scheduled publication operations. It does not own lifecycle authority,
source selection, terminal provenance, transition admission, writer ownership,
publication order, receipts, or user-facing refusal wording.
-/

/-- Choose the first unused practical Scheduled identity. -/
def freshId?
    (memory : ScheduledMemory String) : Option ScheduledId := do
  let token ← Loam.firstUnusedNumberedToken?
    "scheduled-"
    (fun token => (ScheduledMemory.findById? memory (⟨token⟩ : ScheduledId)).isSome)
    1
    (memory.occurrences.length + 1)
  pure ⟨token⟩

/-- Reconstruct one balanced JPY movement from admitted draft Effects. -/
def movementFromEffects?
    (effects : List Effect) : Option (BalancedMovement LocusId) := do
  let changes : List (MovementChange LocusId) :=
    effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  BalancedMovement.ofChanges? ⟨"jpy"⟩ changes

/-- Construct one Scheduled occurrence after operation-specific draft admission. -/
def occurrenceFromEffects?
    (id : ScheduledId)
    (scheduledOn : String)
    (effects : List Effect) : Option (ScheduledOccurrence String) := do
  let movement ← movementFromEffects? effects
  pure { id := id, scheduledOn := scheduledOn, movement := movement }

end Loam.ScheduledOccurrenceConstruction
