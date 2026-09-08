import Loam.Core.Capacity
import Loam.Core.FiniteKeyed

namespace Loam.Core

set_option autoImplicit false

/-!
# Capacity effective-coordinate evidence

Observation 112 showed that a Capacity movement's effective coordinate can be
independently observable, while Observation 158 showed that the current
household budget pressure can be answered from coordinates and a half-open
query window without retaining BudgetPeriod identity.

Capacity authority therefore stays in `CapacityMovement`; this separate evidence
attaches an effective coordinate without adding time fields to the movement
algebra itself.
-/

/-- One effective coordinate attached to a retained Capacity movement. -/
structure CapacityEffective (Time : Type) where
  movement : CapacityMovementId
  effectiveOn : Time
deriving Repr, DecidableEq

/--
Practical effective-coordinate memory. Each Capacity movement identity has at
most one retained effective coordinate. Representation order has no temporal or
priority meaning.
-/
structure CapacityEffectiveMemory (Time : Type) where
  entries : List (CapacityEffective Time)
  movementNodup : (entries.map CapacityEffective.movement).Nodup

namespace CapacityEffectiveMemory

variable {Time : Type}

/-- Admit effective-coordinate evidence only when movement identity is unique. -/
def ofEntries?
    (entries : List (CapacityEffective Time)) : Option (CapacityEffectiveMemory Time) :=
  if h : (entries.map CapacityEffective.movement).Nodup then
    some { entries := entries, movementNodup := h }
  else
    none

/-- Find the retained effective coordinate for one Capacity movement identity. -/
def findByMovementId?
    (memory : CapacityEffectiveMemory Time)
    (id : CapacityMovementId) : Option Time :=
  (FiniteKeyed.findBy? CapacityEffective.movement memory.entries id).map
    CapacityEffective.effectiveOn

/-- Effective-coordinate lookup is invariant under representation permutation. -/
theorem findByMovementId?_perm
    (left right : CapacityEffectiveMemory Time)
    (hPerm : left.entries.Perm right.entries)
    (id : CapacityMovementId) :
    findByMovementId? left id = findByMovementId? right id := by
  simpa [findByMovementId?] using
    congrArg (fun result => result.map CapacityEffective.effectiveOn)
      (FiniteKeyed.findBy?_perm CapacityEffective.movement hPerm left.movementNodup id)

@[simp] theorem ofEntries?_nil :
    ofEntries? ([] : List (CapacityEffective Time)) =
      some { entries := [], movementNodup := by simp } := by
  simp [ofEntries?]

end CapacityEffectiveMemory

end Loam.Core