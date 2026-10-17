import Loam.Core.ScheduledMemory
import Loam.FreshNumberedToken
import Lean.Elab.Tactic.Omega

namespace Loam.ScheduledOccurrenceConstruction

open Loam.Core

set_option autoImplicit false

/-- Year-specific namespace for a new occurrence; legacy defaults remain. -/
def freshIdWithPrefix (memory : ScheduledMemory String) (namePrefix : String) : ScheduledId :=
  let used := memory.occurrences.map (fun occurrence => occurrence.id.token)
  ⟨Loam.firstUnusedNumberedToken namePrefix used 1⟩

theorem freshIdWithPrefix_fresh (memory : ScheduledMemory String) (namePrefix : String) :
    freshIdWithPrefix memory namePrefix ∉ memory.occurrences.map ScheduledOccurrence.id := by
  intro hId
  have hToken :=
    Loam.firstUnusedNumberedToken_fresh
      namePrefix (memory.occurrences.map (fun occurrence => occurrence.id.token)) 1
  apply hToken
  simp only [List.mem_map] at hId ⊢
  rcases hId with ⟨existing, hExisting, hEq⟩
  refine ⟨existing, hExisting, ?_⟩
  simpa [freshIdWithPrefix] using congrArg ScheduledId.token hEq

/-- Legacy callers retain the original Scheduled identifier spelling. -/
def freshId (memory : ScheduledMemory String) : ScheduledId :=
  freshIdWithPrefix memory "scheduled-"

/-- The generated Scheduled identity is outside the retained Scheduled namespace. -/
theorem freshId_fresh (memory : ScheduledMemory String) :
    freshId memory ∉ memory.occurrences.map ScheduledOccurrence.id := by
  exact freshIdWithPrefix_fresh memory "scheduled-"

private def positiveQuanta (quanta : Int) : Int :=
  if 0 < quanta then quanta else 0

private def positiveSum : List (MovementChange LocusId) → Int
  | [] => 0
  | change :: rest => positiveQuanta change.quantity.quanta + positiveSum rest

/-- Derived positive-side total of one already-balanced Scheduled movement. -/
def positiveTotalQuanta (movement : BalancedMovement LocusId) : Int :=
  positiveSum movement.changes

private theorem positiveSum_nonneg
    (changes : List (MovementChange LocusId)) :
    0 ≤ positiveSum changes := by
  induction changes with
  | nil =>
      simp [positiveSum]
  | cons head tail ih =>
      by_cases h : 0 < head.quantity.quanta
      · simp [positiveSum, positiveQuanta, h]
        omega
      · simp [positiveSum, positiveQuanta, h]
        exact ih

private theorem total_le_positiveSum
    (changes : List (MovementChange LocusId)) :
    movementTotalQuanta changes ≤ positiveSum changes := by
  induction changes with
  | nil =>
      simp [movementTotalQuanta, positiveSum]
  | cons head tail ih =>
      change head.quantity.quanta + movementTotalQuanta tail ≤
        positiveQuanta head.quantity.quanta + positiveSum tail
      by_cases h : 0 < head.quantity.quanta
      · rw [show positiveQuanta head.quantity.quanta = head.quantity.quanta by
          simp [positiveQuanta, h]]
        omega
      · rw [show positiveQuanta head.quantity.quanta = 0 by
          simp [positiveQuanta, h]]
        omega

/--
A non-empty balanced Scheduled movement whose retained quantities are all nonzero
necessarily has a positive side. Publishers that already establish those two
practical guards do not need a second runtime `positiveTotalQuanta > 0` check.
-/
theorem positiveTotalQuanta_pos_of_nonempty_nonzero
    (movement : BalancedMovement LocusId)
    (hNonempty : movement.changes ≠ [])
    (hNonzero : ∀ change ∈ movement.changes, change.quantity.quanta ≠ 0) :
    0 < positiveTotalQuanta movement := by
  cases hChanges : movement.changes with
  | nil =>
      exact (hNonempty hChanges).elim
  | cons head tail =>
      have hHeadNonzero : head.quantity.quanta ≠ 0 := by
        apply hNonzero head
        rw [hChanges]
        simp
      have hBalance : head.quantity.quanta + movementTotalQuanta tail = 0 := by
        have h := movement.balanced
        rw [hChanges] at h
        change head.quantity.quanta + movementTotalQuanta tail = 0 at h
        exact h
      unfold positiveTotalQuanta
      rw [hChanges]
      change 0 < positiveQuanta head.quantity.quanta + positiveSum tail
      by_cases hPos : 0 < head.quantity.quanta
      · rw [show positiveQuanta head.quantity.quanta = head.quantity.quanta by
          simp [positiveQuanta, hPos]]
        have hTailNonneg := positiveSum_nonneg tail
        omega
      · have hNeg : head.quantity.quanta < 0 := by omega
        rw [show positiveQuanta head.quantity.quanta = 0 by
          simp [positiveQuanta, hPos]]
        have hTailPositive : 0 < movementTotalQuanta tail := by omega
        have hBound := total_le_positiveSum tail
        omega

end Loam.ScheduledOccurrenceConstruction
