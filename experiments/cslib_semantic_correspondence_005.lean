import Loam.Observations.Observation159

namespace Loam.Experiments.CSLibSemanticCorrespondence005

open Loam.Core

set_option autoImplicit false

/-!
CSA-005 asks whether Observation 159's free-Abelian projection can be read as the
semantic carrier exposed by CSLib `FinFun`: a function with finite nonzero
support.

No CSLib or Mathlib dependency is added. `ProbeFinFun` below shadows only the
semantic contract needed by the experiment. Its support uses a `List` rather
than CSLib's `Finset`; membership, not support representation, is the point of
correspondence.

The production `BalancedMovement.changes` list remains presentation-rich
evidence. This experiment tests only whether that evidence has a canonical
finite-function denotation.
-/

/-- Integer-valued coordinate denotation of one finite change presentation. -/
def denoteQuanta {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) : Int :=
  changes.foldr
    (fun change total =>
      if change.coordinate = coordinate then
        change.quantity.quanta + total
      else
        total)
    0

/-- Coordinates explicitly mentioned by one retained presentation. -/
def representedCoordinates {Coordinate : Type}
    (changes : List (MovementChange Coordinate)) : List Coordinate :=
  changes.map MovementChange.coordinate

/-- A coordinate absent from the finite presentation has denotation zero. -/
theorem denoteQuanta_zero_of_not_mem
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate)
    (hNotMem : coordinate ∉ representedCoordinates changes) :
    denoteQuanta changes coordinate = 0 := by
  induction changes with
  | nil =>
      rfl
  | cons change rest ih =>
      have hHead : change.coordinate ≠ coordinate := by
        intro hEq
        apply hNotMem
        simp [representedCoordinates, hEq]
      have hTail : coordinate ∉ representedCoordinates rest := by
        intro hMem
        apply hNotMem
        unfold representedCoordinates at hMem ⊢
        simp only [List.map_cons, List.mem_cons]
        exact Or.inr hMem
      simpa [denoteQuanta, hHead] using ih hTail

/-- Nonzero denotation can only occur at a coordinate represented by the list. -/
theorem nonzero_mem_representedCoordinates
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate)
    (hNonzero : denoteQuanta changes coordinate ≠ 0) :
    coordinate ∈ representedCoordinates changes := by
  apply Classical.byContradiction
  intro hNotMem
  exact hNonzero (denoteQuanta_zero_of_not_mem changes coordinate hNotMem)

/-- Exact nonzero support, represented as a finite list for the dependency-free probe. -/
def exactSupport {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate)) : List Coordinate :=
  (representedCoordinates changes).filter
    (fun coordinate => decide (denoteQuanta changes coordinate ≠ 0))

/-- The exact support list contains precisely the nonzero coordinates. -/
theorem mem_exactSupport_iff
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    coordinate ∈ exactSupport changes ↔ denoteQuanta changes coordinate ≠ 0 := by
  constructor
  · intro hMem
    simp only [exactSupport, List.mem_filter] at hMem
    exact of_decide_eq_true hMem.2
  · intro hNonzero
    have hCandidate :=
      nonzero_mem_representedCoordinates changes coordinate hNonzero
    simp [exactSupport, hCandidate, hNonzero]

/--
Dependency-free shadow of the part of CSLib `FinFun` relevant here: a function
plus one finite representation of exactly its nonzero support.
-/
structure ProbeFinFun (Coordinate : Type) [DecidableEq Coordinate] where
  fn : Coordinate → Int
  support : List Coordinate
  mem_support_fn : ∀ coordinate, coordinate ∈ support ↔ fn coordinate ≠ 0

namespace ProbeFinFun

/-- Semantic equality, matching CSLib `FinFun.ext`: equality at every coordinate. -/
def ExtEq {Coordinate : Type} [DecidableEq Coordinate]
    (left right : ProbeFinFun Coordinate) : Prop :=
  ∀ coordinate, left.fn coordinate = right.fn coordinate

@[refl] theorem extEq_refl
    {Coordinate : Type} [DecidableEq Coordinate]
    (f : ProbeFinFun Coordinate) : ExtEq f f := by
  intro coordinate
  rfl

end ProbeFinFun

/-- Every finite LOAM change presentation denotes one finite-support integer function. -/
def denote {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate)) : ProbeFinFun Coordinate where
  fn := denoteQuanta changes
  support := exactSupport changes
  mem_support_fn := mem_exactSupport_iff changes

/-- Observation 159's quantity projection is exactly the integer denotation rewrapped. -/
theorem aggregateAt_eq_denote
    {Coordinate : Type} [DecidableEq Coordinate]
    (changes : List (MovementChange Coordinate))
    (coordinate : Coordinate) :
    Loam.Observation159.aggregateAt changes coordinate =
      Quantity.ofQuanta ((denote changes).fn coordinate) := by
  rfl

/--
Observation 159's presentation equivalence is exactly extensional equality of
the finite-function denotation.
-/
theorem vectorEquivalent_iff_denotation_extEq
    {Coordinate : Type} [DecidableEq Coordinate]
    (left right : List (MovementChange Coordinate)) :
    Loam.Observation159.VectorEquivalent left right ↔
      ProbeFinFun.ExtEq (denote left) (denote right) := by
  constructor
  · intro h coordinate
    have hQuanta := congrArg Quantity.quanta (h coordinate)
    simpa [Loam.Observation159.aggregateAt, denoteQuanta] using hQuanta
  · intro h coordinate
    have hQuanta : denoteQuanta left coordinate = denoteQuanta right coordinate := by
      exact h coordinate
    simpa [Loam.Observation159.aggregateAt, denoteQuanta] using
      congrArg Quantity.ofQuanta hQuanta

/-- Existing `BalancedMovement.quantityAt` factors through the same denotation. -/
theorem quantityAt_eq_denote
    {Coordinate : Type} [DecidableEq Coordinate]
    (movement : BalancedMovement Coordinate)
    (coordinate : Coordinate) :
    movement.quantityAt coordinate =
      Quantity.ofQuanta ((denote movement.changes).fn coordinate) := by
  rfl

/-- Observation 159's two distinct presentations collapse to one denotation. -/
theorem compact_split_same_denotation :
    ProbeFinFun.ExtEq
      (denote Loam.Observation159.compactPresentation)
      (denote Loam.Observation159.splitPresentation) :=
  (vectorEquivalent_iff_denotation_extEq
    Loam.Observation159.compactPresentation
    Loam.Observation159.splitPresentation).mp
      Loam.Observation159.split_and_compact_are_vector_equivalent

/-- The collapse above is semantic, not representational: the evidence lists stay different. -/
theorem compact_split_still_different_presentations :
    Loam.Observation159.compactPresentation.length ≠
      Loam.Observation159.splitPresentation.length :=
  Loam.Observation159.equivalent_presentations_can_have_different_shape

/-!
CSA-005 deliberately keeps the direction one-way at the architecture boundary:

* `BalancedMovement.changes` remains retained evidence / presentation;
* `denote changes` is the finite-support integer-vector meaning of that evidence;
* `VectorEquivalent` is exactly equality of that meaning;
* CSLib's actual `FinFun` uses `Finset` support and imports Mathlib, so LOAM does
  not gain enough from a dependency merely to replace this small shadow.

A separate question is whether `movementTotalQuanta` factors through this
finite-function denotation in full generality, i.e. whether the zero-augmentation
law depends only on `ProbeFinFun.ExtEq`. That theorem is not assumed here; it can
be probed independently if this correspondence qualifies.
-/

end Loam.Experiments.CSLibSemanticCorrespondence005
