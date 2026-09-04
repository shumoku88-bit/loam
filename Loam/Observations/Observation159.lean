import Loam.Core.BalancedMovement

namespace Loam.Observation159

open Loam.Core

set_option autoImplicit false

/-!
# Observation 159 — free Abelian projection boundary

For one fixed Measure and coordinate type, a finite list of signed
`MovementChange`s can be read as a finite presentation of an integer-valued
coordinate vector. The observable aggregate is the candidate free-Abelian
semantics; the represented list itself remains evidence / representation.

This observation deliberately does not introduce a production quotient type or
Mathlib dependency. It asks the smaller question first: can two distinct finite
presentations be identified by every coordinate projection while
`BalancedMovement` remains exactly the zero-augmentation boundary?
-/

/-- Aggregate one finite signed presentation at one coordinate. -/
def aggregateAt {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) : Quantity :=
  Quantity.ofQuanta <|
    changes.foldr
      (fun change total =>
        if change.coordinate = coordinate then
          change.quantity.quanta + total
        else
          total)
      0

/--
Candidate quotient relation: two finite presentations are equivalent when every
coordinate observes the same exact integer quantity.
-/
def VectorEquivalent {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate)) : Prop :=
  ∀ coordinate, aggregateAt left coordinate = aggregateAt right coordinate

@[refl] theorem vectorEquivalent_refl
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate)) :
    VectorEquivalent changes changes := by
  intro coordinate
  rfl

@[symm] theorem vectorEquivalent_symm
    {Coordinate : Type} [DecidableEq Coordinate]
    {left right : List (MovementChange Coordinate)}
    (h : VectorEquivalent left right) :
    VectorEquivalent right left := by
  intro coordinate
  exact (h coordinate).symm

theorem vectorEquivalent_trans
    {Coordinate : Type} [DecidableEq Coordinate]
    {left middle right : List (MovementChange Coordinate)}
    (hLeft : VectorEquivalent left middle)
    (hRight : VectorEquivalent middle right) :
    VectorEquivalent left right := by
  intro coordinate
  exact (hLeft coordinate).trans (hRight coordinate)

/-- Existing `BalancedMovement.quantityAt` factors through the candidate relation. -/
theorem quantityAt_respects_vector_equivalence
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : BalancedMovement Coordinate)
    (h : VectorEquivalent left.changes right.changes)
    (coordinate : Coordinate) :
    left.quantityAt coordinate = right.quantityAt coordinate := by
  simpa [aggregateAt, BalancedMovement.quantityAt] using h coordinate

/-! ## Concrete finite witness -/

inductive Coordinate where
  | wallet
  | food
  deriving Repr, DecidableEq

private def jpy : MeasureId := ⟨"jpy"⟩

/-- One two-term presentation of a 100 JPY movement. -/
def compactPresentation : List (MovementChange Coordinate) :=
  [ { coordinate := .wallet, quantity := Quantity.ofQuanta (-100) },
    { coordinate := .food, quantity := Quantity.ofQuanta 100 } ]

/--
A different three-term presentation of the same coordinate vector. The wallet
coefficient is split into two retained list entries.
-/
def splitPresentation : List (MovementChange Coordinate) :=
  [ { coordinate := .food, quantity := Quantity.ofQuanta 100 },
    { coordinate := .wallet, quantity := Quantity.ofQuanta (-40) },
    { coordinate := .wallet, quantity := Quantity.ofQuanta (-60) } ]

/-- Different finite presentations can have the same observable coordinate vector. -/
theorem split_and_compact_are_vector_equivalent :
    VectorEquivalent compactPresentation splitPresentation := by
  intro coordinate
  cases coordinate <;> decide

/-- The candidate quotient really forgets representation: the witness lengths differ. -/
theorem equivalent_presentations_can_have_different_shape :
    compactPresentation.length ≠ splitPresentation.length := by
  decide

/-- Both representatives satisfy the existing exact zero-augmentation law. -/
theorem both_presentations_have_zero_augmentation :
    movementTotalQuanta compactPresentation = 0 ∧
    movementTotalQuanta splitPresentation = 0 := by
  decide

/-- The same witnesses are admitted by today's practical balanced-movement boundary. -/
def compactMovement : BalancedMovement Coordinate :=
  { measure := jpy
    changes := compactPresentation
    balanced := by decide }

/-- The split representation is admitted independently with the same balance proof. -/
def splitMovement : BalancedMovement Coordinate :=
  { measure := jpy
    changes := splitPresentation
    balanced := by decide }

/-- Existing practical coordinate observation cannot distinguish the two presentations. -/
theorem practical_quantity_projection_agrees (coordinate : Coordinate) :
    compactMovement.quantityAt coordinate = splitMovement.quantityAt coordinate := by
  exact quantityAt_respects_vector_equivalence
    compactMovement splitMovement split_and_compact_are_vector_equivalent coordinate

/--
The current `BalancedMovement` is therefore presentation-rich evidence carrying
proof of membership in the zero-augmentation boundary. The free-Abelian vector
is a projection of that evidence, not yet a reason to erase the represented
list from canonical data.
-/
theorem balanced_boundary_is_observed :
    movementTotalQuanta compactMovement.changes = 0 ∧
    movementTotalQuanta splitMovement.changes = 0 := by
  exact ⟨compactMovement.balanced, splitMovement.balanced⟩

end Loam.Observation159
