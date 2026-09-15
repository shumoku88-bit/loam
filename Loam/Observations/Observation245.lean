import Loam.Observations.Observation242
import Loam.Core.CapacityMemory
import Loam.Core.CapacityEffective
import Lean.Elab.Tactic.Omega

namespace Loam.Observations.Observation245

open Loam.Core

set_option autoImplicit false

/-!
# Observation 245 — Capacity identity allocation is total across two families

Observations 243 and 244 connected the shared numbered-search law to one retained
identity family at a time. Capacity is the next stronger case: one candidate is
reserved when it appears either in Capacity movement authority or in retained
effective-coordinate evidence.

The production allocator budgets exactly one more candidate than the sum of
those two represented family lengths. This observation asks whether that
OR-shaped collision predicate is still covered by one finite witness.
-/

/-- Capacity movement tokens retained by movement authority. -/
def movementTokens (movements : List CapacityMovement) : List String :=
  movements.map (fun movement => movement.id.token)

/-- Capacity movement tokens mentioned by effective-coordinate evidence. -/
def effectiveTokens (entries : List (CapacityEffective String)) : List String :=
  entries.map (fun entry => entry.movement.token)

/-- The complete finite namespace consulted by the current Capacity allocator. -/
def capacityTokens
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : List String :=
  movementTokens memory.movements ++ effectiveTokens effective.entries

@[simp] theorem capacityTokens_length
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) :
    (capacityTokens memory effective).length =
      memory.movements.length + effective.entries.length := by
  simp [capacityTokens, movementTokens, effectiveTokens]

private theorem findMovement_isSome_eq_usedByList
    (movements : List CapacityMovement)
    (token : String) :
    (FiniteKeyed.findBy?
        CapacityMovement.id
        movements
        (⟨token⟩ : CapacityMovementId)).isSome =
      Observation242.usedByList (movementTokens movements) token := by
  induction movements with
  | nil =>
      simp [FiniteKeyed.findBy?, movementTokens, Observation242.usedByList]
  | cons movement rest ih =>
      cases movement with
      | mk id balanced =>
          by_cases hEq : id.token = token
          · have hId : id = (⟨token⟩ : CapacityMovementId) := by
              cases id with
              | mk idToken =>
                  cases hEq
                  rfl
            simp [FiniteKeyed.findBy?, movementTokens, Observation242.usedByList, hId]
          · have hEqSymm : token ≠ id.token := by
              intro h
              exact hEq h.symm
            have hId : id ≠ (⟨token⟩ : CapacityMovementId) := by
              intro h
              apply hEq
              exact congrArg CapacityMovementId.token h
            simp [FiniteKeyed.findBy?, movementTokens, Observation242.usedByList,
              hEqSymm, hId, ih]

private theorem effectiveMentions_eq_usedByList
    (entries : List (CapacityEffective String))
    (token : String) :
    entries.any
        (fun entry =>
          decide (entry.movement = (⟨token⟩ : CapacityMovementId))) =
      Observation242.usedByList (effectiveTokens entries) token := by
  induction entries with
  | nil =>
      simp [effectiveTokens, Observation242.usedByList]
  | cons entry rest ih =>
      cases entry with
      | mk movement effectiveOn =>
          by_cases hEq : movement.token = token
          · have hId : movement = (⟨token⟩ : CapacityMovementId) := by
              cases movement with
              | mk movementToken =>
                  cases hEq
                  rfl
            simp [effectiveTokens, Observation242.usedByList, hId]
          · have hEqSymm : token ≠ movement.token := by
              intro h
              exact hEq h.symm
            have hId : movement ≠ (⟨token⟩ : CapacityMovementId) := by
              intro h
              apply hEq
              exact congrArg CapacityMovementId.token h
            simp [effectiveTokens, Observation242.usedByList, hEqSymm, hId, ih]

/--
The exact two-family collision predicate used by Capacity is finite membership
in the concatenated witness above.
-/
theorem capacityUsed_eq_usedByList
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) :
    (fun token =>
      let candidate : CapacityMovementId := ⟨token⟩
      (memory.findById? candidate).isSome ||
        effective.entries.any
          (fun entry => decide (entry.movement = candidate))) =
      Observation242.usedByList (capacityTokens memory effective) := by
  funext token
  have hMovement := findMovement_isSome_eq_usedByList memory.movements token
  have hEffective := effectiveMentions_eq_usedByList effective.entries token
  rw [CapacityMemory.findById?, hMovement, hEffective]
  simp [Observation242.usedByList, capacityTokens, movementTokens, effectiveTokens]

/--
The exact Capacity search shape cannot exhaust its current sum-of-families fuel
budget.
-/
theorem capacitySearch_is_total
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        "capacity-"
        (fun token =>
          let candidate : CapacityMovementId := ⟨token⟩
          (memory.findById? candidate).isSome ||
            effective.entries.any
              (fun entry => decide (entry.movement = candidate)))
        1
        (memory.movements.length + effective.entries.length + 1) = some token := by
  rw [capacityUsed_eq_usedByList memory effective]
  apply Observation242.search_succeeds_when_window_outnumbers_used
  simp [capacityTokens]

/-!
Observation 245 earns the structurally different third result:

```text
used Capacity IDs = movement-authority IDs ∪ effective-evidence references
finite witness length = movements.length + effective.entries.length
fuel = that sum + 1
-> fresh Capacity identity search cannot return none
```

The totality pattern therefore survives an OR-shaped collision namespace spanning
two retained semantic families. Production remains unchanged here.
-/

end Loam.Observations.Observation245
