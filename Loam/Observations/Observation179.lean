import Loam.Observations.Observation159

namespace Loam.Observation179

open Loam.Core
open Loam.Observation159

set_option autoImplicit false

/-!
# Observation 179 — preservation polarity beyond the free-Abelian image

Observation 159 showed that finite `MovementChange` presentations factor through
coordinate-wise additive projection, while retained presentation shape remains
observable evidence.

This observation asks the next question without assuming a group of symmetries:

* which concrete transformations preserve the additive observations?
* must such a transformation be invertible?
* what order-reversing relation exists between chosen observations and the
  transformations that preserve them?

The key witness is a deterministic normalization that replaces any presentation
with one wallet row and one food row carrying the exact aggregate quantities.
It preserves the complete additive vector for this finite coordinate type, but
collapses distinct Observation-159 presentations and therefore has no two-sided
inverse.
-/

abbrev Presentation := List (MovementChange Coordinate)

/--
Choose one compact representative of the additive image for the finite
Observation-159 coordinate type.
-/
def normalize (changes : Presentation) : Presentation :=
  [ { coordinate := .wallet, quantity := aggregateAt changes .wallet },
    { coordinate := .food, quantity := aggregateAt changes .food } ]

/-- Normalization preserves every coordinate quantity in the finite witness plane. -/
theorem normalize_vector_equivalent (changes : Presentation) :
    VectorEquivalent changes (normalize changes) := by
  intro coordinate
  cases coordinate <;> simp [normalize, aggregateAt]

/-- Observation 159's two different representatives normalize to the same list. -/
theorem normalization_collapses_observation159_witness :
    normalize compactPresentation = normalize splitPresentation := by
  unfold normalize
  rw [split_and_compact_are_vector_equivalent .wallet]
  rw [split_and_compact_are_vector_equivalent .food]

/-- The two representatives really are distinct retained presentations. -/
theorem observation159_witness_presentations_are_distinct :
    compactPresentation ≠ splitPresentation := by
  intro h
  apply equivalent_presentations_can_have_different_shape
  exact congrArg List.length h

/--
A natural additive-image-preserving transformation need not be invertible.
So the full practical preservation structure is not automatically a group.
-/
theorem normalize_not_injective :
    ¬ Function.Injective normalize := by
  intro h
  exact observation159_witness_presentations_are_distinct
    (h normalization_collapses_observation159_witness)

/-- Minimal notion needed to rule out group-style invertibility. -/
def HasTwoSidedInverse (f : Presentation → Presentation) : Prop :=
  ∃ g : Presentation → Presentation,
    (∀ x, g (f x) = x) ∧
    (∀ x, f (g x) = x)

/-- Normalization cannot be a group symmetry of retained presentations. -/
theorem normalize_has_no_two_sided_inverse :
    ¬ HasTwoSidedInverse normalize := by
  intro h
  rcases h with ⟨g, leftInverse, _⟩
  apply normalize_not_injective
  intro a b hab
  calc
    a = g (normalize a) := (leftInverse a).symm
    _ = g (normalize b) := congrArg g hab
    _ = b := leftInverse b

/-! ## Concrete observables and preservers -/

inductive Observable where
  | walletQuantity
  | foodQuantity
  | representationLength
  deriving Repr, DecidableEq

inductive Transform where
  | identity
  | normalize
  deriving Repr, DecidableEq

def applyTransform : Transform → Presentation → Presentation
  | .identity, changes => changes
  | .normalize, changes => normalize changes

/-- Equality as seen through one chosen observation. -/
def indistinguishable : Observable → Presentation → Presentation → Prop
  | .walletQuantity, left, right =>
      aggregateAt left .wallet = aggregateAt right .wallet
  | .foodQuantity, left, right =>
      aggregateAt left .food = aggregateAt right .food
  | .representationLength, left, right =>
      left.length = right.length

/-- A transformation preserves an observable on every retained presentation. -/
def Preserves (transform : Transform) (observable : Observable) : Prop :=
  ∀ changes,
    indistinguishable observable changes (applyTransform transform changes)

/-- Identity preserves every chosen observation. -/
theorem identity_preserves (observable : Observable) :
    Preserves .identity observable := by
  intro changes
  cases observable <;> rfl

/-- Normalization preserves wallet quantity. -/
theorem normalize_preserves_wallet :
    Preserves .normalize .walletQuantity := by
  intro changes
  exact normalize_vector_equivalent changes .wallet

/-- Normalization preserves food quantity. -/
theorem normalize_preserves_food :
    Preserves .normalize .foodQuantity := by
  intro changes
  exact normalize_vector_equivalent changes .food

/-- But normalization does not preserve retained presentation length. -/
theorem normalize_does_not_preserve_length :
    ¬ Preserves .normalize .representationLength := by
  intro h
  have hlen := h splitPresentation
  simp [indistinguishable, applyTransform, normalize, splitPresentation] at hlen

/--
For this two-coordinate witness, Observation 159's `VectorEquivalent` relation is
exactly agreement on the two additive observables.
-/
theorem vector_equivalent_iff_additive_observations_agree
    (left right : Presentation) :
    VectorEquivalent left right ↔
      indistinguishable .walletQuantity left right ∧
      indistinguishable .foodQuantity left right := by
  constructor
  · intro h
    exact ⟨h .wallet, h .food⟩
  · rintro ⟨walletAgreement, foodAgreement⟩ coordinate
    cases coordinate
    · exact walletAgreement
    · exact foodAgreement

/-! ## Preservation polarity -/

/-- A transformation preserves every observable selected by a predicate. -/
def PreserverOf
    (observables : Observable → Prop)
    (transform : Transform) : Prop :=
  ∀ observable, observables observable → Preserves transform observable

/-- An observable is invariant under every transformation selected by a predicate. -/
def InvariantUnder
    (transforms : Transform → Prop)
    (observable : Observable) : Prop :=
  ∀ transform, transforms transform → Preserves transform observable

/--
The exact order-reversing correspondence induced by the preservation relation.
This is the standard polarity/Galois-connection shape on powersets:

`T ⊆ Preservers(O)` iff `O ⊆ Invariants(T)`.
-/
theorem preservation_polarity
    (transforms : Transform → Prop)
    (observables : Observable → Prop) :
    (∀ transform,
        transforms transform → PreserverOf observables transform) ↔
      (∀ observable,
        observables observable → InvariantUnder transforms observable) := by
  constructor
  · intro h observable hObservable transform hTransform
    exact h transform hTransform observable hObservable
  · intro h transform hTransform observable hObservable
    exact h observable hObservable transform hTransform

/-- More observations can only reduce the set of preserving transformations. -/
theorem preservers_are_antitone
    {smaller larger : Observable → Prop}
    (h : ∀ observable, smaller observable → larger observable) :
    ∀ transform,
      PreserverOf larger transform → PreserverOf smaller transform := by
  intro transform hLarge observable hSmall
  exact hLarge observable (h observable hSmall)

/-- More transformations can only reduce the set of invariant observations. -/
theorem invariants_are_antitone
    {smaller larger : Transform → Prop}
    (h : ∀ transform, smaller transform → larger transform) :
    ∀ observable,
      InvariantUnder larger observable → InvariantUnder smaller observable := by
  intro observable hLarge transform hSmall
  exact hLarge transform (h transform hSmall)

/-- The two additive observations corresponding to the free-Abelian image. -/
def AdditiveObservable : Observable → Prop
  | .walletQuantity => True
  | .foodQuantity => True
  | .representationLength => False

/-- Add retained representation shape to the additive observation family. -/
def RepresentationObservable (observable : Observable) : Prop :=
  AdditiveObservable observable ∨ observable = .representationLength

/-- Normalization is a preserver when only the additive image is observable. -/
theorem normalize_is_additive_preserver :
    PreserverOf AdditiveObservable .normalize := by
  intro observable h
  cases observable with
  | walletQuantity =>
      exact normalize_preserves_wallet
  | foodQuantity =>
      exact normalize_preserves_food
  | representationLength =>
      simp [AdditiveObservable] at h

/--
Once retained representation shape is observable, the same normalization is
excluded. This is the concrete order reversal, not merely the generic theorem.
-/
theorem normalize_is_not_representation_preserver :
    ¬ PreserverOf RepresentationObservable .normalize := by
  intro h
  apply normalize_does_not_preserve_length
  exact h .representationLength (Or.inr rfl)

end Loam.Observation179
