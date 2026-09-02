import Loam.Core.Measure

namespace Loam.Core

set_option autoImplicit false

/-!
# Balanced movement algebra

`BalancedMovement` is a small reusable mathematical boundary for operations that
are admitted only when their signed quantities close to zero within one explicit
Measure.

The coordinate type is a parameter. This lets different semantic families share
the same exact arithmetic without sharing their coordinate meaning. In
particular, a physical `LocusId` and a capacity `CapacityCoordinate` can use the
same balance law while remaining different Lean types.

This does not make every `Event` balanced and does not add debit / credit,
Account, transaction-kind, or semantic-plane tags to the neutral Event core.
-/

/-- One signed quantity change at a caller-chosen semantic coordinate. -/
structure MovementChange (Coordinate : Type) where
  coordinate : Coordinate
  quantity : Quantity

/-- Exact signed total of one represented movement change list. -/
def movementTotalQuanta {Coordinate : Type}
    (changes : List (MovementChange Coordinate)) : Int :=
  changes.foldr (fun change total => change.quantity.quanta + total) 0

/--
One single-Measure movement whose represented signed changes close exactly.

The proof is retained with the value, so downstream functions that accept a
`BalancedMovement` do not need to re-check the zero-total law.
-/
structure BalancedMovement (Coordinate : Type) where
  measure : MeasureId
  changes : List (MovementChange Coordinate)
  balanced : movementTotalQuanta changes = 0

namespace BalancedMovement

/-- Admit an arbitrary runtime change list only when its exact signed total is zero. -/
def ofChanges? {Coordinate : Type}
    (measure : MeasureId)
    (changes : List (MovementChange Coordinate)) : Option (BalancedMovement Coordinate) :=
  if h : movementTotalQuanta changes = 0 then
    some { measure := measure, changes := changes, balanced := h }
  else
    none

/-- Project the signed quantity at one semantic coordinate. -/
def quantityAt {Coordinate : Type} [DecidableEq Coordinate]
    (movement : BalancedMovement Coordinate)
    (coordinate : Coordinate) : Quantity :=
  Quantity.ofQuanta <|
    movement.changes.foldr
      (fun change total =>
        if change.coordinate = coordinate then
          change.quantity.quanta + total
        else
          total)
      0

/-- Every admitted balanced movement exposes exact zero as its complete signed total. -/
@[simp] theorem totalQuanta_zero {Coordinate : Type}
    (movement : BalancedMovement Coordinate) :
    movementTotalQuanta movement.changes = 0 :=
  movement.balanced

/-- An empty change list is mathematically balanced for any explicit Measure. -/
@[simp] theorem ofChanges?_nil {Coordinate : Type} (measure : MeasureId) :
    ofChanges? (Coordinate := Coordinate) measure [] =
      some { measure := measure, changes := [], balanced := by rfl } := by
  rfl

end BalancedMovement

end Loam.Core
