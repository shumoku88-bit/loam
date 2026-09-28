namespace Loam.Observation191

set_option autoImplicit false

/-!
# Observation 191 — observational quotient factorization

Earlier finite field trials exposed three nearby structures:

* equality under a selected family of observations;
* a preservation polarity between observations and evidence transformations;
* double-polarity closure of an observation family.

This observation is the generalized live owner of their common structure. The
older wallet/food normalization and minimal-basis fixtures have graduated to Git
history; downstream research now depends on the generic quotient/factorization
boundary below.

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
why the theorem depends on all-endomap closure; it does not automatically apply
to a restricted production transformation set.
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

/-!
## Finding

The surviving structure is intentionally small:

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

The finite wallet/food transformations that originally established the shape
were representative discovery fixtures. They are no longer needed as live
dependencies once the generic theorem above owns preservation polarity and
closure/factorization directly.

This is a structural unification, not a claim of new mathematics. The
all-endomap assumption remains essential to the exact factorization theorem.
Production correction, routing, relation authority, time selection, publication,
or human decision policy are not thereby arbitrary evidence endomaps and are
not collapsed into this observation-local structure.

Retired finite witnesses remain available in Git history.
-/

end Loam.Observation191
