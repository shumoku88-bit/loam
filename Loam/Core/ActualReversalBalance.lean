import Loam.Core.ActualReversal
import Loam.Core.BalancedMovement

namespace Loam.Core

set_option autoImplicit false

/-!
# Actual reversal to balanced movement bridge

An exact reversal does not imply that either endpoint Event is balanced by
itself. It implies that the combined physical pair cancels exactly.

This bridge projects that combined pair into one single-Measure
`BalancedMovement LocusId` for any requested Measure, carrying the zero-total
proof directly from exact inverse evidence instead of re-running
`BalancedMovement.ofChanges?`.
-/

namespace ActualReversalBalance

open ActualReversal

/--
Project only Effects in one requested Measure to physical movement changes.

Effect identity is deliberately forgotten here; each retained Effect contributes
its locus and exact signed quantity. Effects in other Measures are excluded.
-/
def movementChangesForMeasure
    (measure : MeasureId)
    (effects : List Effect) : List (MovementChange LocusId) :=
  match effects with
  | [] => []
  | effect :: rest =>
      if effect.measure = measure then
        ({ coordinate := effect.locus, quantity := effect.quantity } :
          MovementChange LocusId) ::
          movementChangesForMeasure measure rest
      else
        movementChangesForMeasure measure rest

/-- Exact signed total in one Measure over physical Effect evidence. -/
private def physicalMeasureQuanta
    (effects : List PhysicalEffect)
    (measure : MeasureId) : Int :=
  effects.foldr
    (fun effect total =>
      if effect.measure = measure then
        effect.quantity.quanta + total
      else
        total)
    0

private theorem physicalMeasureQuanta_perm
    {left right : List PhysicalEffect}
    (hPerm : left.Perm right)
    (measure : MeasureId) :
    physicalMeasureQuanta left measure =
      physicalMeasureQuanta right measure := by
  induction hPerm with
  | nil =>
      rfl
  | cons effect h ih =>
      unfold physicalMeasureQuanta at ih ⊢
      simp only [List.foldr_cons]
      rw [ih]
  | swap x y rest =>
      unfold physicalMeasureQuanta
      simp only [List.foldr_cons]
      by_cases hx : x.measure = measure
      <;> by_cases hy : y.measure = measure
      <;> simp [hx, hy, Int.add_comm, Int.add_left_comm]
  | trans hLeft hRight ihLeft ihRight =>
      exact ihLeft.trans ihRight

@[simp] private theorem physicalMeasureQuanta_inversePhysical
    (effects : List PhysicalEffect)
    (measure : MeasureId) :
    physicalMeasureQuanta (effects.map inversePhysical) measure =
      -physicalMeasureQuanta effects measure := by
  induction effects with
  | nil =>
      rfl
  | cons effect rest ih =>
      unfold physicalMeasureQuanta at ih ⊢
      simp only [List.map_cons, List.foldr_cons]
      by_cases hMeasure : effect.measure = measure
      · simp [inversePhysical, hMeasure, ih, Int.neg_add]
      · simp [inversePhysical, hMeasure, ih]

/--
The MovementChange projection preserves the exact total of the selected Measure.
-/
theorem movementTotalQuanta_changesForMeasure
    (measure : MeasureId)
    (effects : List Effect) :
    movementTotalQuanta (movementChangesForMeasure measure effects) =
      physicalMeasureQuanta (physicalEffects effects) measure := by
  induction effects with
  | nil =>
      rfl
  | cons effect rest ih =>
      by_cases hMeasure : effect.measure = measure
      · simp [movementChangesForMeasure, physicalEffects, physicalEffect,
          physicalMeasureQuanta, movementTotalQuanta, hMeasure, ih]
      · simp [movementChangesForMeasure, physicalEffects, physicalEffect,
          physicalMeasureQuanta, movementTotalQuanta, hMeasure, ih]

private theorem movementTotalQuanta_append
    {Coordinate : Type}
    (left right : List (MovementChange Coordinate)) :
    movementTotalQuanta (left ++ right) =
      movementTotalQuanta left + movementTotalQuanta right := by
  induction left with
  | nil =>
      simp [movementTotalQuanta]
  | cons change rest ih =>
      simp [movementTotalQuanta, ih, Int.add_assoc]

/--
Exact physical inverse evidence implies zero total independently in every Measure.
-/
theorem measureNetZero_of_exactPhysicalInverse
    (target reversal : List Effect)
    (hExact : exactPhysicalInverse? target reversal = true)
    (measure : MeasureId) :
    movementTotalQuanta (movementChangesForMeasure measure target) +
        movementTotalQuanta (movementChangesForMeasure measure reversal) =
      0 := by
  have hPerm :=
    (exactPhysicalInverse?_eq_true_iff target reversal).mp hExact
  have hProjected :=
    physicalMeasureQuanta_perm hPerm measure
  rw [physicalMeasureQuanta_inversePhysical] at hProjected
  rw [movementTotalQuanta_changesForMeasure,
      movementTotalQuanta_changesForMeasure]
  rw [hProjected]
  exact Int.add_left_neg _

/--
Construct the balanced single-Measure view of one exact reversal pair directly
from proof evidence.

No runtime balance admission is repeated: the `balanced` field is discharged by
`measureNetZero_of_exactPhysicalInverse`.
-/
def balancedMovementForMeasure_of_exactPhysicalInverse
    (target reversal : List Effect)
    (hExact : exactPhysicalInverse? target reversal = true)
    (measure : MeasureId) : BalancedMovement LocusId :=
  {
    measure := measure
    changes :=
      movementChangesForMeasure measure target ++
        movementChangesForMeasure measure reversal
    balanced := by
      rw [movementTotalQuanta_append]
      exact measureNetZero_of_exactPhysicalInverse
        target reversal hExact measure
  }

end ActualReversalBalance

end Loam.Core
