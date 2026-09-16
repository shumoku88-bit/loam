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

If this holds, the balance law `movementTotalQuanta changes = 0` is a property
of the vector meaning rather than of list shape. No quotient, CSLib dependency,
Mathlib dependency, or production carrier is introduced here.
-/

/-- Remove every represented change at one coordinate while preserving the others. -/
def eraseCoordinate {Coordinate : Type} [DecidableEq Coordinate]
    (coordinate : Coordinate) :
    List (MovementChange Coordinate) -> List (MovementChange Coordinate)
  | [] => []
  | change :: rest =>
      if change.coordinate = coordinate then
        eraseCoordinate coordinate rest
      else
        change :: eraseCoordinate coordinate rest

/-- Erasing one coordinate never increases presentation length. -/
theorem eraseCoordinate_length_le
    {Coordinate : Type} [DecidableEq Coordinate]
    (coordinate : Coordinate)
    (changes : List (MovementChange Coordinate)) :
    (eraseCoordinate coordinate changes).length <= changes.length := by
  induction changes with
  | nil =>
      rfl
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

/-- After erasing one coordinate, that coordinate observes exact zero. -/
theorem aggregateAt_eraseCoordinate_same
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    Loam.Observation159.aggregateAt
        (eraseCoordinate coordinate changes) coordinate = 0 := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases h : change.coordinate = coordinate
      · simp [eraseCoordinate, h, Loam.Observation159.aggregateAt, ih]
      · simp [eraseCoordinate, h, Loam.Observation159.aggregateAt, ih]

/-- Erasing one coordinate leaves every other coordinate aggregate unchanged. -/
theorem aggregateAt_eraseCoordinate_other
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (erased observed : Coordinate)
    (hDifferent : observed != erased) :
    Loam.Observation159.aggregateAt
        (eraseCoordinate erased changes) observed =
      Loam.Observation159.aggregateAt changes observed := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases hErase : change.coordinate = erased
      · have hObserved : change.coordinate != observed := by
          intro hEqual
          apply hDifferent
          calc
            observed = change.coordinate := hEqual.symm
            _ = erased := hErase
        simp [eraseCoordinate, hErase, hObserved,
          Loam.Observation159.aggregateAt, ih]
      · simp [eraseCoordinate, hErase, Loam.Observation159.aggregateAt, ih]

/-- Vector equivalence survives erasing the same coordinate on both sides. -/
theorem vectorEquivalent_eraseCoordinate
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (coordinate : Coordinate)
    (hEquivalent : Loam.Observation159.VectorEquivalent left right) :
    Loam.Observation159.VectorEquivalent
      (eraseCoordinate coordinate left)
      (eraseCoordinate coordinate right) := by
  intro observed
  by_cases hSame : observed = coordinate
  · subst observed
    rw [aggregateAt_eraseCoordinate_same, aggregateAt_eraseCoordinate_same]
  · rw [aggregateAt_eraseCoordinate_other left coordinate observed hSame]
    rw [aggregateAt_eraseCoordinate_other right coordinate observed hSame]
    exact hEquivalent observed

/--
One presentation splits exactly into the aggregate at one coordinate plus the
total of all remaining coordinates.
-/
theorem movementTotal_eq_coordinate_add_remainder
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    movementTotalQuanta changes =
      (Loam.Observation159.aggregateAt changes coordinate).quanta +
        movementTotalQuanta (eraseCoordinate coordinate changes) := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      by_cases h : change.coordinate = coordinate
      · simp [movementTotalQuanta, Loam.Observation159.aggregateAt,
          eraseCoordinate, h, ih, Int.add_assoc]
      · simp [movementTotalQuanta, Loam.Observation159.aggregateAt,
          eraseCoordinate, h, ih, Int.add_assoc, Int.add_comm, Int.add_left_comm]

private theorem movementTotal_zero_of_all_aggregates_zero_of_length
    {Coordinate : Type} [DecidableEq Coordinate]
    (n : Nat) :
    forall changes : List (MovementChange Coordinate),
      changes.length = n ->
      (forall coordinate, Loam.Observation159.aggregateAt changes coordinate = 0) ->
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
            rw [<- hLength]
            exact eraseCoordinate_head_length_lt head rest
          have hReducedZero :
              forall coordinate,
                Loam.Observation159.aggregateAt
                    (eraseCoordinate head.coordinate (head :: rest)) coordinate = 0 := by
            intro coordinate
            by_cases hSame : coordinate = head.coordinate
            · subst coordinate
              exact aggregateAt_eraseCoordinate_same (head :: rest) head.coordinate
            · rw [aggregateAt_eraseCoordinate_other
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

/-- If every coordinate aggregate is zero, the represented total is zero. -/
theorem movementTotal_zero_of_all_aggregates_zero
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (hZero : forall coordinate,
      Loam.Observation159.aggregateAt changes coordinate = 0) :
    movementTotalQuanta changes = 0 :=
  movementTotal_zero_of_all_aggregates_zero_of_length
    changes.length changes rfl hZero

private theorem vectorEquivalent_preserves_movementTotal_of_left_length
    {Coordinate : Type} [DecidableEq Coordinate]
    (n : Nat) :
    forall left : List (MovementChange Coordinate),
      left.length = n ->
      forall right : List (MovementChange Coordinate),
        Loam.Observation159.VectorEquivalent left right ->
        movementTotalQuanta left = movementTotalQuanta right := by
  induction n using Nat.strongRecOn with
  | ind n ih =>
      intro left hLength right hEquivalent
      cases left with
      | nil =>
          have hRightZero :
              forall coordinate,
                Loam.Observation159.aggregateAt right coordinate = 0 := by
            intro coordinate
            simpa [Loam.Observation159.aggregateAt] using
              (hEquivalent coordinate).symm
          have hTotalRight :=
            movementTotal_zero_of_all_aggregates_zero right hRightZero
          simp [movementTotalQuanta, hTotalRight]
      | cons head rest =>
          have hSmaller :
              (eraseCoordinate head.coordinate (head :: rest)).length < n := by
            rw [<- hLength]
            exact eraseCoordinate_head_length_lt head rest
          have hReducedEquivalent :=
            vectorEquivalent_eraseCoordinate
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
            (fun total =>
              (Loam.Observation159.aggregateAt right head.coordinate).quanta + total)
            hReducedTotal

/--
The augmentation factors through Observation 159's finite-vector meaning:
extensionally equal vectors have the same exact total.
-/
theorem vectorEquivalent_preserves_movementTotal
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (hEquivalent : Loam.Observation159.VectorEquivalent left right) :
    movementTotalQuanta left = movementTotalQuanta right :=
  vectorEquivalent_preserves_movementTotal_of_left_length
    left.length left rfl right hEquivalent

/-- Consequently, zero augmentation is a property of vector meaning, not list shape. -/
theorem vectorEquivalent_preserves_zero_augmentation
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate))
    (hEquivalent : Loam.Observation159.VectorEquivalent left right) :
    movementTotalQuanta left = 0 <-> movementTotalQuanta right = 0 := by
  rw [vectorEquivalent_preserves_movementTotal left right hEquivalent]

/-- The represented augmentation is additive under concatenation. -/
theorem movementTotal_append
    {Coordinate : Type}
    (left right : List (MovementChange Coordinate)) :
    movementTotalQuanta (left ++ right) =
      movementTotalQuanta left + movementTotalQuanta right := by
  induction left with
  | nil =>
      rfl
  | cons head rest ih =>
      simp [movementTotalQuanta, ih, Int.add_assoc]

/--
The factorization is strict: equal augmentation is weaker than equal vector
meaning. Observation 163 already carries a concrete zero-total counterexample.
-/
theorem equal_augmentation_does_not_imply_vector_equivalence :
    exists left right : List (MovementChange Loam.Observation159.Coordinate),
      movementTotalQuanta left = movementTotalQuanta right /\
        not (Loam.Observation159.VectorEquivalent left right) := by
  refine <| exists.intro Loam.Observation163.driftLeft <|
    exists.intro Loam.Observation163.driftRight ?_
  constructor
  · exact Loam.Observation163.drifted_meaning_accepts_witness
  · exact Loam.Observation163.strict_meaning_rejects_witness

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
