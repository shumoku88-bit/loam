import Loam.Observations.Observation163
import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.CSLibSemanticCorrespondence006

open Loam.Core

set_option autoImplicit false

/-!
CSA-006 asks whether the exact total carried by a finite movement presentation
factors through Observation 159's finite-vector meaning.

CSA-005 established that `VectorEquivalent` is exactly extensional equality of
a FinFun-style finite-support integer denotation. The missing direction is:

    same finite vector -> same movementTotalQuanta

The proof below stays on the integer carrier until the final bridge back to
Observation 159's `Quantity` wrapper. No quotient, CSLib dependency, Mathlib
dependency, or production carrier is introduced.
-/

/-- Exact integer coefficient observed at one coordinate. -/
def aggregateQuanta {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) : Int :=
  changes.foldr
    (fun change total =>
      if change.coordinate = coordinate then
        change.quantity.quanta + total
      else
        total)
    0

/-- Observation 159's quantity projection wraps exactly `aggregateQuanta`. -/
@[simp] theorem aggregateAt_quanta
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    (Loam.Observation159.aggregateAt changes coordinate).quanta =
      aggregateQuanta changes coordinate := by
  rfl

/-- Pointwise integer-vector equality used internally by the augmentation proof. -/
def QuantaEquivalent {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate)) : Prop :=
  ∀ coordinate, aggregateQuanta left coordinate = aggregateQuanta right coordinate

/-- Observation 159 vector equality implies integer-vector equality. -/
theorem vectorEquivalent_to_quantaEquivalent
    {Coordinate : Type} [DecidableEq Coordinate]
    {left right : List (MovementChange Coordinate)}
    (hEquivalent : Loam.Observation159.VectorEquivalent left right) :
    QuantaEquivalent left right := by
  intro coordinate
  have hQuanta := congrArg Quantity.quanta (hEquivalent coordinate)
  simpa only [aggregateAt_quanta] using hQuanta

/-- Integer-vector equality is also sufficient for Observation 159 vector equality. -/
theorem quantaEquivalent_to_vectorEquivalent
    {Coordinate : Type} [DecidableEq Coordinate]
    {left right : List (MovementChange Coordinate)}
    (hEquivalent : QuantaEquivalent left right) :
    Loam.Observation159.VectorEquivalent left right := by
  intro coordinate
  calc
    Loam.Observation159.aggregateAt left coordinate =
        Quantity.ofQuanta (aggregateQuanta left coordinate) := by rfl
    _ = Quantity.ofQuanta (aggregateQuanta right coordinate) :=
      congrArg Quantity.ofQuanta (hEquivalent coordinate)
    _ = Loam.Observation159.aggregateAt right coordinate := by rfl

/-- Remove every represented change at one coordinate while preserving the others. -/
def eraseCoordinate {Coordinate : Type} [DecidableEq Coordinate]
    (coordinate : Coordinate) :
    List (MovementChange Coordinate) → List (MovementChange Coordinate)
  | [] => []
  | change :: rest =>
      if change.coordinate = coordinate then
        eraseCoordinate coordinate rest
      else
        change :: eraseCoordinate coordinate rest

/-- Exact total of a cons presentation. -/
private theorem movementTotal_cons
    {Coordinate : Type}
    (change : MovementChange Coordinate)
    (rest : List (MovementChange Coordinate)) :
    movementTotalQuanta (change :: rest) =
      change.quantity.quanta + movementTotalQuanta rest := by
  rfl

/-- Erasing one coordinate never increases presentation length. -/
theorem eraseCoordinate_length_le
    {Coordinate : Type} [DecidableEq Coordinate]
    (coordinate : Coordinate)
    (changes : List (MovementChange Coordinate)) :
    (eraseCoordinate coordinate changes).length ≤ changes.length := by
  induction changes with
  | nil =>
      simp [eraseCoordinate]
  | cons change rest ih =>
      by_cases h : change.coordinate = coordinate
      · simp [eraseCoordinate, h]
        omega
      · simp [eraseCoordinate, h]
        omega

/-- Erasing the head coordinate strictly shrinks any nonempty presentation. -/
theorem eraseCoordinate_head_length_lt
    {Coordinate : Type} [DecidableEq Coordinate]
    (head : MovementChange Coordinate)
    (rest : List (MovementChange Coordinate)) :
    (eraseCoordinate head.coordinate (head :: rest)).length <
      (head :: rest).length := by
  simp [eraseCoordinate]
  have hLe := eraseCoordinate_length_le head.coordinate rest
  omega

/-- After erasing one coordinate, its integer coefficient is exact zero. -/
theorem aggregateQuanta_eraseCoordinate_same
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    aggregateQuanta (eraseCoordinate coordinate changes) coordinate = 0 := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases h : change.coordinate = coordinate
      · simpa [eraseCoordinate, h] using ih
      · simpa [eraseCoordinate, h, aggregateQuanta] using ih

/-- Erasing one coordinate leaves every other integer coefficient unchanged. -/
theorem aggregateQuanta_eraseCoordinate_other
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (erased observed : Coordinate)
    (hDifferent : observed ≠ erased) :
    aggregateQuanta (eraseCoordinate erased changes) observed =
      aggregateQuanta changes observed := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases hErase : change.coordinate = erased
      · have hReverse : erased ≠ observed := Ne.symm hDifferent
        simpa [eraseCoordinate, hErase, hReverse, aggregateQuanta] using ih
      · by_cases hObserved : change.coordinate = observed
        · have hLifted :=
            congrArg (fun total => change.quantity.quanta + total) ih
          simpa [eraseCoordinate, hErase, hObserved, hDifferent, aggregateQuanta] using hLifted
        · simpa [eraseCoordinate, hErase, hObserved, aggregateQuanta] using ih

/-- Integer-vector equivalence survives erasing the same coordinate on both sides. -/
theorem quantaEquivalent_eraseCoordinate
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (coordinate : Coordinate)
    (hEquivalent : QuantaEquivalent left right) :
    QuantaEquivalent
      (eraseCoordinate coordinate left)
      (eraseCoordinate coordinate right) := by
  intro observed
  by_cases hSame : observed = coordinate
  · subst observed
    rw [aggregateQuanta_eraseCoordinate_same, aggregateQuanta_eraseCoordinate_same]
  · rw [aggregateQuanta_eraseCoordinate_other left coordinate observed hSame]
    rw [aggregateQuanta_eraseCoordinate_other right coordinate observed hSame]
    exact hEquivalent observed

/--
One presentation splits exactly into one coordinate coefficient plus the total
of all remaining coordinates.
-/
theorem movementTotal_eq_coordinate_add_remainder
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    movementTotalQuanta changes =
      aggregateQuanta changes coordinate +
        movementTotalQuanta (eraseCoordinate coordinate changes) := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases h : change.coordinate = coordinate
      · have hAggregate :
            aggregateQuanta (change :: rest) coordinate =
              change.quantity.quanta + aggregateQuanta rest coordinate := by
          simp [aggregateQuanta, h]
        have hErase :
            eraseCoordinate coordinate (change :: rest) =
              eraseCoordinate coordinate rest := by
          simp [eraseCoordinate, h]
        rw [movementTotal_cons, hAggregate, hErase, ih]
        exact (Int.add_assoc
          change.quantity.quanta
          (aggregateQuanta rest coordinate)
          (movementTotalQuanta (eraseCoordinate coordinate rest))).symm
      · have hAggregate :
            aggregateQuanta (change :: rest) coordinate =
              aggregateQuanta rest coordinate := by
          simp [aggregateQuanta, h]
        have hErase :
            eraseCoordinate coordinate (change :: rest) =
              change :: eraseCoordinate coordinate rest := by
          simp [eraseCoordinate, h]
        rw [movementTotal_cons, hAggregate, hErase, movementTotal_cons, ih]
        omega

private theorem movementTotal_zero_of_all_quanta_zero_of_length
    {Coordinate : Type} [DecidableEq Coordinate]
    (n : Nat) :
    ∀ changes : List (MovementChange Coordinate),
      changes.length = n →
      (∀ coordinate, aggregateQuanta changes coordinate = 0) →
      movementTotalQuanta changes = 0 := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro changes hLength hZero
      cases changes with
      | nil =>
          rfl
      | cons head rest =>
          have hSmaller :
              (eraseCoordinate head.coordinate (head :: rest)).length < n := by
            rw [← hLength]
            exact eraseCoordinate_head_length_lt head rest
          have hReducedZero :
              ∀ coordinate,
                aggregateQuanta
                    (eraseCoordinate head.coordinate (head :: rest)) coordinate = 0 := by
            intro coordinate
            by_cases hSame : coordinate = head.coordinate
            · subst coordinate
              exact aggregateQuanta_eraseCoordinate_same
                (head :: rest) head.coordinate
            · rw [aggregateQuanta_eraseCoordinate_other
                (head :: rest) head.coordinate coordinate hSame]
              exact hZero coordinate
          have hReducedTotal :=
            ih
              (eraseCoordinate head.coordinate (head :: rest)).length
              hSmaller
              (eraseCoordinate head.coordinate (head :: rest))
              rfl
              hReducedZero
          rw [movementTotal_eq_coordinate_add_remainder
              (head :: rest) head.coordinate]
          rw [hZero head.coordinate, hReducedTotal]
          rfl

/-- If every coordinate coefficient is zero, the represented total is zero. -/
theorem movementTotal_zero_of_all_quanta_zero
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (hZero : ∀ coordinate, aggregateQuanta changes coordinate = 0) :
    movementTotalQuanta changes = 0 :=
  movementTotal_zero_of_all_quanta_zero_of_length
    changes.length changes rfl hZero

private theorem quantaEquivalent_preserves_movementTotal_of_left_length
    {Coordinate : Type} [DecidableEq Coordinate]
    (n : Nat) :
    ∀ left : List (MovementChange Coordinate),
      left.length = n →
      ∀ right : List (MovementChange Coordinate),
        QuantaEquivalent left right →
        movementTotalQuanta left = movementTotalQuanta right := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro left hLength right hEquivalent
      cases left with
      | nil =>
          have hRightZero : ∀ coordinate, aggregateQuanta right coordinate = 0 := by
            intro coordinate
            have hAt := hEquivalent coordinate
            simpa [aggregateQuanta] using hAt.symm
          have hTotalRight :=
            movementTotal_zero_of_all_quanta_zero right hRightZero
          change 0 = movementTotalQuanta right
          exact hTotalRight.symm
      | cons head rest =>
          have hSmaller :
              (eraseCoordinate head.coordinate (head :: rest)).length < n := by
            rw [← hLength]
            exact eraseCoordinate_head_length_lt head rest
          have hReducedEquivalent :=
            quantaEquivalent_eraseCoordinate
              (head :: rest) right head.coordinate hEquivalent
          have hReducedTotal :=
            ih
              (eraseCoordinate head.coordinate (head :: rest)).length
              hSmaller
              (eraseCoordinate head.coordinate (head :: rest))
              rfl
              (eraseCoordinate head.coordinate right)
              hReducedEquivalent
          rw [movementTotal_eq_coordinate_add_remainder
              (head :: rest) head.coordinate]
          rw [movementTotal_eq_coordinate_add_remainder right head.coordinate]
          rw [hEquivalent head.coordinate]
          exact congrArg
            (fun total => aggregateQuanta right head.coordinate + total)
            hReducedTotal

/-- Integer-vector equality determines exact augmentation. -/
theorem quantaEquivalent_preserves_movementTotal
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (hEquivalent : QuantaEquivalent left right) :
    movementTotalQuanta left = movementTotalQuanta right :=
  quantaEquivalent_preserves_movementTotal_of_left_length
    left.length left rfl right hEquivalent

/--
The augmentation factors through Observation 159's finite-vector meaning:
extensionally equal vectors have the same exact total.
-/
theorem vectorEquivalent_preserves_movementTotal
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (hEquivalent : Loam.Observation159.VectorEquivalent left right) :
    movementTotalQuanta left = movementTotalQuanta right :=
  quantaEquivalent_preserves_movementTotal
    left right (vectorEquivalent_to_quantaEquivalent hEquivalent)

/-- Consequently, zero augmentation is a property of vector meaning, not list shape. -/
theorem vectorEquivalent_preserves_zero_augmentation
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (hEquivalent : Loam.Observation159.VectorEquivalent left right) :
    movementTotalQuanta left = 0 ↔ movementTotalQuanta right = 0 := by
  have hTotal := vectorEquivalent_preserves_movementTotal left right hEquivalent
  constructor
  · intro hZero
    rw [← hTotal]
    exact hZero
  · intro hZero
    rw [hTotal]
    exact hZero

/-- The represented augmentation is additive under concatenation. -/
theorem movementTotal_append
    {Coordinate : Type}
    (left right : List (MovementChange Coordinate)) :
    movementTotalQuanta (left ++ right) =
      movementTotalQuanta left + movementTotalQuanta right := by
  induction left with
  | nil =>
      simp [movementTotalQuanta]
  | cons head rest ih =>
      change
        head.quantity.quanta + movementTotalQuanta (rest ++ right) =
          head.quantity.quanta + movementTotalQuanta rest + movementTotalQuanta right
      rw [ih]
      exact (Int.add_assoc
        head.quantity.quanta (movementTotalQuanta rest) (movementTotalQuanta right)).symm

/--
The factorization is strict: equal augmentation is weaker than equal vector
meaning. Observation 163 already carries a concrete zero-total counterexample.
-/
theorem equal_augmentation_does_not_imply_vector_equivalence :
    ∃ left right : List (MovementChange Loam.Observation159.Coordinate),
      movementTotalQuanta left = movementTotalQuanta right ∧
        ¬ Loam.Observation159.VectorEquivalent left right := by
  refine ⟨Loam.Observation163.driftLeft, Loam.Observation163.driftRight, ?_, ?_⟩
  · simpa [Loam.Observation163.DriftedMeaning] using
      Loam.Observation163.drifted_meaning_accepts_witness
  · simpa [Loam.Observation163.StrictMeaning] using
      Loam.Observation163.strict_meaning_rejects_witness

/-!
CSA-006 therefore identifies the standard algebraic shape without changing
production representation:

* finite vector meaning is finer than total augmentation;
* `movementTotalQuanta` is well-defined on the vector-equivalence quotient;
* concatenation maps to integer addition;
* the balanced boundary is the zero fibre / augmentation kernel;
* equal totals alone do not recover vector meaning.

This is a correspondence theorem, not a reason to replace retained movement
lists with a quotient or to add CSLib / Mathlib dependencies.
-/

end Loam.Experiments.CSLibSemanticCorrespondence006
