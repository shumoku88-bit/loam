import Loam.Observations.Observation180

namespace Loam.Observation191

open Loam.Core
open Loam.Observation159

set_option autoImplicit false

/-!
# Observation 191 — observational quotient factorization

Observations 159, 179, and 180 exposed three nearby structures:

* equality under a selected family of observations;
* a preservation polarity between observations and evidence transformations;
* double-polarity closure of an observation family.

This observation asks whether those are merely adjacent uses of familiar
mathematics or whether one smaller structure explains their connection.

The generic witness deliberately assumes only:

* a retained evidence type `Evidence`;
* an observation type `Observable`;
* a possibly different result type for each observation;
* one observation map from evidence into that result type.

No additive law is required for the generic result. The free-Abelian reading
from Observation 159 reappears only when the generic result is specialized back
to LOAM's additive observation family.
-/

universe u v w

section Generic

variable {Evidence : Type u}
variable {Observable : Type v}
variable {Value : Observable → Type w}

/--
Two retained evidence values are indistinguishable by a selected observation
family when every selected observation returns the same value on both.
-/
def IndistinguishableBy
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    (left right : Evidence) : Prop :=
  ∀ observable, observables observable →
    observe observable left = observe observable right

@[refl] theorem indistinguishableBy_refl
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    (evidence : Evidence) :
    IndistinguishableBy observe observables evidence evidence := by
  intro observable _
  rfl

@[symm] theorem indistinguishableBy_symm
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    {left right : Evidence}
    (h : IndistinguishableBy observe observables left right) :
    IndistinguishableBy observe observables right left := by
  intro observable hObservable
  exact (h observable hObservable).symm

theorem indistinguishableBy_trans
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    {left middle right : Evidence}
    (hLeft : IndistinguishableBy observe observables left middle)
    (hRight : IndistinguishableBy observe observables middle right) :
    IndistinguishableBy observe observables left right := by
  intro observable hObservable
  exact (hLeft observable hObservable).trans (hRight observable hObservable)

/-- One retained-evidence endomap preserves one observation everywhere. -/
def Preserves
    (observe : (observable : Observable) → Evidence → Value observable)
    (transform : Evidence → Evidence)
    (observable : Observable) : Prop :=
  ∀ evidence,
    observe observable evidence = observe observable (transform evidence)

/-- One endomap preserves every observation selected by a family predicate. -/
def PreserverOf
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    (transform : Evidence → Evidence) : Prop :=
  ∀ observable, observables observable → Preserves observe transform observable

/-- One observation is invariant under every endomap selected by a predicate. -/
def InvariantUnder
    (observe : (observable : Observable) → Evidence → Value observable)
    (transforms : (Evidence → Evidence) → Prop)
    (observable : Observable) : Prop :=
  ∀ transform, transforms transform → Preserves observe transform observable

/-- Double polarity over all retained-evidence endomaps. -/
def Closure
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    (observable : Observable) : Prop :=
  InvariantUnder observe (PreserverOf observe observables) observable

/--
The generic Observation-179 polarity needs only the binary preservation
relation. No additive structure or invertibility assumption is involved.
-/
theorem preservation_polarity
    (observe : (observable : Observable) → Evidence → Value observable)
    (transforms : (Evidence → Evidence) → Prop)
    (observables : Observable → Prop) :
    (∀ transform,
        transforms transform → PreserverOf observe observables transform) ↔
      (∀ observable,
        observables observable → InvariantUnder observe transforms observable) := by
  constructor
  · intro h observable hObservable transform hTransform
    exact h transform hTransform observable hObservable
  · intro h transform hTransform observable hObservable
    exact h observable hObservable transform hTransform

/--
A target observation factors through the indistinguishability quotient induced
by `observables` exactly when it is constant on each induced equivalence class.
No quotient type has to be constructed to state this property.
-/
def FactorsThroughIndistinguishability
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    (target : Observable) : Prop :=
  ∀ left right,
    IndistinguishableBy observe observables left right →
      observe target left = observe target right

/--
The central bridge: when closure ranges over all endomaps of retained evidence,
a target observation is in double-polarity closure iff it factors through the
indistinguishability quotient induced by the starting observation family.

The reverse direction uses the endomap that redirects one evidence value to an
indistinguishable representative and fixes every other evidence value. This is
why the theorem depends on the all-endomap closure used by Observation 180; it
does not automatically apply to a restricted production transformation set.
-/
theorem closure_iff_factors_through_indistinguishability
    (observe : (observable : Observable) → Evidence → Value observable)
    (observables : Observable → Prop)
    (target : Observable) :
    Closure observe observables target ↔
      FactorsThroughIndistinguishability observe observables target := by
  constructor
  · intro hClosure left right hIndistinguishable
    classical
    let redirect : Evidence → Evidence := fun evidence =>
      if evidence = left then right else evidence
    have hRedirect : PreserverOf observe observables redirect := by
      intro observable hObservable evidence
      by_cases hEvidence : evidence = left
      · subst evidence
        simpa [redirect] using hIndistinguishable observable hObservable
      · simp [redirect, hEvidence]
    have hTarget := hClosure redirect hRedirect left
    simpa [redirect] using hTarget
  · intro hFactors transform hTransform evidence
    apply hFactors evidence (transform evidence)
    intro observable hObservable
    exact hTransform observable hObservable evidence

end Generic

/-! ## Specialization back to Observations 159–180 -/

namespace Existing

abbrev Evidence := Loam.Observation180.Evidence
abbrev Observable := Loam.Observation180.Observable

/-- Observation 180 is exactly the generic all-endomap closure specialized to its observer. -/
theorem observation180_closure_is_generic
    (observables : Observable → Prop)
    (observable : Observable) :
    Loam.Observation180.Closure observables observable ↔
      Closure Loam.Observation180.observe observables observable := by
  rfl

/--
Observation 159's candidate free-Abelian quotient relation is exactly
indistinguishability under Observation 180's two-coordinate additive basis.
-/
theorem additive_indistinguishability_iff_vector_equivalent
    (left right : Evidence) :
    IndistinguishableBy
        Loam.Observation180.observe
        Loam.Observation180.AdditiveBasis
        left right ↔
      VectorEquivalent left right := by
  constructor
  · intro h coordinate
    cases coordinate with
    | wallet =>
        have hw := h .walletQuantity (by simp [Loam.Observation180.AdditiveBasis])
        change
          (aggregateAt left .wallet).quanta =
            (aggregateAt right .wallet).quanta at hw
        calc
          aggregateAt left .wallet =
              Quantity.ofQuanta (aggregateAt left .wallet).quanta := by
                symm
                exact Quantity.ofQuanta_quanta _
          _ = Quantity.ofQuanta (aggregateAt right .wallet).quanta := by
                exact congrArg Quantity.ofQuanta hw
          _ = aggregateAt right .wallet := Quantity.ofQuanta_quanta _
    | food =>
        have hf := h .foodQuantity (by simp [Loam.Observation180.AdditiveBasis])
        change
          (aggregateAt left .food).quanta =
            (aggregateAt right .food).quanta at hf
        calc
          aggregateAt left .food =
              Quantity.ofQuanta (aggregateAt left .food).quanta := by
                symm
                exact Quantity.ofQuanta_quanta _
          _ = Quantity.ofQuanta (aggregateAt right .food).quanta := by
                exact congrArg Quantity.ofQuanta hf
          _ = aggregateAt right .food := Quantity.ofQuanta_quanta _
  · intro h observable hObservable
    cases observable with
    | walletQuantity =>
        change
          (aggregateAt left .wallet).quanta =
            (aggregateAt right .wallet).quanta
        exact congrArg (fun quantity : Quantity => quantity.quanta) (h .wallet)
    | foodQuantity =>
        change
          (aggregateAt left .food).quanta =
            (aggregateAt right .food).quanta
        exact congrArg (fun quantity : Quantity => quantity.quanta) (h .food)
    | totalQuantity =>
        simp [Loam.Observation180.AdditiveBasis] at hObservable
    | representationLength =>
        simp [Loam.Observation180.AdditiveBasis] at hObservable

/--
The promised bridge across the earlier observations. An Observation-180 target
belongs to the additive closure exactly when it cannot distinguish any two
Observation-159 vector-equivalent presentations.
-/
theorem additive_closure_iff_respects_vector_equivalence
    (target : Observable) :
    Loam.Observation180.Closure Loam.Observation180.AdditiveBasis target ↔
      ∀ left right : Evidence,
        VectorEquivalent left right →
          Loam.Observation180.observe target left =
            Loam.Observation180.observe target right := by
  constructor
  · intro hClosed left right hVector
    have hGeneric :
        Closure
          Loam.Observation180.observe
          Loam.Observation180.AdditiveBasis
          target :=
      (observation180_closure_is_generic
        Loam.Observation180.AdditiveBasis target).mp hClosed
    have hFactors :=
      (closure_iff_factors_through_indistinguishability
        Loam.Observation180.observe
        Loam.Observation180.AdditiveBasis
        target).mp hGeneric
    exact hFactors left right
      ((additive_indistinguishability_iff_vector_equivalent left right).mpr hVector)
  · intro hFactors
    have hGeneric :
        Closure
          Loam.Observation180.observe
          Loam.Observation180.AdditiveBasis
          target := by
      apply
        (closure_iff_factors_through_indistinguishability
          Loam.Observation180.observe
          Loam.Observation180.AdditiveBasis
          target).mpr
      intro left right hIndistinguishable
      exact hFactors left right
        ((additive_indistinguishability_iff_vector_equivalent left right).mp
          hIndistinguishable)
    exact
      (observation180_closure_is_generic
        Loam.Observation180.AdditiveBasis target).mpr hGeneric

/-- The derived total is constant on every Observation-159 additive equivalence class. -/
theorem total_respects_vector_equivalence
    (left right : Evidence)
    (h : VectorEquivalent left right) :
    Loam.Observation180.observe .totalQuantity left =
      Loam.Observation180.observe .totalQuantity right := by
  have hw := congrArg (fun quantity : Quantity => quantity.quanta) (h .wallet)
  have hf := congrArg (fun quantity : Quantity => quantity.quanta) (h .food)
  change
    (aggregateAt left .wallet).quanta + (aggregateAt left .food).quanta =
      (aggregateAt right .wallet).quanta + (aggregateAt right .food).quanta
  rw [hw, hf]

/-- Observation 180's derived-total result is recovered directly as quotient factorization. -/
theorem total_is_closed_because_it_factors :
    Loam.Observation180.Closure
      Loam.Observation180.AdditiveBasis
      .totalQuantity :=
  (additive_closure_iff_respects_vector_equivalence .totalQuantity).mpr
    total_respects_vector_equivalence

/-- Retained presentation length distinguishes Observation 159's equivalent representatives. -/
theorem representation_length_does_not_respect_vector_equivalence :
    ¬ (∀ left right : Evidence,
        VectorEquivalent left right →
          Loam.Observation180.observe .representationLength left =
            Loam.Observation180.observe .representationLength right) := by
  intro h
  have hLength := h
    compactPresentation
    splitPresentation
    split_and_compact_are_vector_equivalent
  simp [Loam.Observation180.observe, compactPresentation, splitPresentation] at hLength

/--
Observation 180's negative representation result is likewise recovered directly
from Observation 159's quotient witness, without needing normalization as a
separate counterexample transformation.
-/
theorem representation_length_is_not_closed_because_it_does_not_factor :
    ¬ Loam.Observation180.Closure
      Loam.Observation180.AdditiveBasis
      .representationLength := by
  intro hClosed
  exact representation_length_does_not_respect_vector_equivalence
    ((additive_closure_iff_respects_vector_equivalence .representationLength).mp
      hClosed)

end Existing

/-!
## Finding

The three earlier observations now have one common minimal reading:

```text
retained evidence E
    -> selected observation family O
    -> observational equivalence E / ~O

O
    <---- preservation polarity ---->
all endomaps that stay inside ~O classes

Closure(O)
    = observations constant on ~O classes
    = observations that factor through E / ~O
```

Observation 159 supplies a concrete nontrivial quotient: for the two-coordinate
field trial, `~O` is exactly the free-Abelian-style coordinate-vector
equivalence. Observation 179 supplies the preservation polarity. Observation
180's all-endomap double polarity then becomes quotient factorization rather
than a separate closure phenomenon.

This is a structural unification, not a claim of new mathematics. The generic
theorem is a familiar quotient/invariant/Galois-closure shape. LOAM's specific
content is that the same shape arose independently from practical evidence
retention and additive projection pressure.

The all-endomap assumption is essential to the exact factorization theorem.
Production correction, routing, relation authority, time selection, publication,
or human decision policy are not thereby arbitrary evidence endomaps and are
not collapsed into this observation-local structure.
-/

end Loam.Observation191
