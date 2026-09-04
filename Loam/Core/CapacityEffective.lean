import Loam.Core.Capacity
import Init.Data.List.Perm

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

private def findEntryByMovementId? :
    List (CapacityEffective Time) → CapacityMovementId → Option Time
  | [], _ => none
  | entry :: rest, id =>
      if entry.movement = id then
        some entry.effectiveOn
      else
        findEntryByMovementId? rest id

/-- Find the retained effective coordinate for one Capacity movement identity. -/
def findByMovementId?
    (memory : CapacityEffectiveMemory Time)
    (id : CapacityMovementId) : Option Time :=
  findEntryByMovementId? memory.entries id

private theorem findEntryByMovementId?_perm
    {left right : List (CapacityEffective Time)}
    (hPerm : left.Perm right)
    (hNodup : (left.map CapacityEffective.movement).Nodup)
    (id : CapacityMovementId) :
    findEntryByMovementId? left id = findEntryByMovementId? right id := by
  induction hPerm with
  | nil => rfl
  | cons entry hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : entry.movement = id
      · simp [findEntryByMovementId?, h]
      · simp [findEntryByMovementId?, h, ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : y.movement ≠ x.movement := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      by_cases hy : y.movement = id
      · have hx : x.movement ≠ id := by
          intro hx
          exact hyx (hy.trans hx.symm)
        simp [findEntryByMovementId?, hy, hx]
      · by_cases hx : x.movement = id
        · simp [findEntryByMovementId?, hy, hx]
        · simp [findEntryByMovementId?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup :=
        (hLeft.map CapacityEffective.movement).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/-- Effective-coordinate lookup is invariant under representation permutation. -/
theorem findByMovementId?_perm
    (left right : CapacityEffectiveMemory Time)
    (hPerm : left.entries.Perm right.entries)
    (id : CapacityMovementId) :
    findByMovementId? left id = findByMovementId? right id := by
  simpa [findByMovementId?] using
    findEntryByMovementId?_perm hPerm left.movementNodup id

@[simp] theorem ofEntries?_nil :
    ofEntries? ([] : List (CapacityEffective Time)) =
      some { entries := [], movementNodup := by simp } := by
  simp [ofEntries?]

end CapacityEffectiveMemory

end Loam.Core
