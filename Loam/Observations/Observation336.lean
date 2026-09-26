import Loam.MerchantExpenseReview
import Loam.Observations.Observation191

namespace Loam.Observation336

open Loam.Core

set_option autoImplicit false

/-!
# Observation 336 — Merchant Expense observational sufficiency

R5 asks a production-shaped version of Observation 191's factorization question:

> Which distinctions in a rich review Snapshot can one selected observation
> actually see?

`MerchantExpenseReview.Snapshot` deliberately retains both numeric
contributions and diagnostic witnesses for two independent completeness
boundaries. This observation studies only the exact Merchant total answer.

The candidate image is intentionally tiny and research-only:

```text
knownTotal
complete?
```

It does not replace the production Snapshot. The point is to prove both sides
of the boundary:

1. `exactTotal?` factors through that compact image;
2. diagnostic completeness detail does not.
-/

abbrev Snapshot := Loam.MerchantExpenseReview.Snapshot
abbrev UnresolvedMerchantEvent := Loam.MerchantExpenseReview.UnresolvedMerchantEvent
abbrev UnresolvedRoleEffect := Loam.MerchantExpenseReview.UnresolvedRoleEffect

/--
One compact image sufficient for the exact Merchant total observation.

This is a sufficiency witness, not a claim that the representation is uniquely
minimal. In particular, the full production Snapshot intentionally retains
diagnostic evidence that this image forgets.
-/
structure ExactImage where
  knownTotal : Quantity
  complete : Bool

def exactImage (snapshot : Snapshot) : ExactImage :=
  {
    knownTotal := snapshot.knownTotal
    complete :=
      snapshot.unresolvedMerchantEvents.isEmpty &&
        snapshot.unresolvedRoleEffects.isEmpty
  }

def exactTotalFromImage (image : ExactImage) : Option Quantity :=
  if image.complete then some image.knownTotal else none

/-- The production exact answer is reconstructed exactly from the compact image. -/
theorem exactTotal_factors (snapshot : Snapshot) :
    snapshot.exactTotal? = exactTotalFromImage (exactImage snapshot) := by
  simp [
    Loam.MerchantExpenseReview.Snapshot.exactTotal?,
    exactTotalFromImage,
    exactImage
  ]

def SameExactImage (left right : Snapshot) : Prop :=
  exactImage left = exactImage right

/--
Any two rich Snapshots identified by the compact image are indistinguishable by
`exactTotal?`.
-/
theorem exactTotal_respects_sameExactImage
    {left right : Snapshot}
    (h : SameExactImage left right) :
    left.exactTotal? = right.exactTotal? := by
  rw [exactTotal_factors left, exactTotal_factors right]
  exact congrArg exactTotalFromImage h

/-!
## Observation-191 specialization

The selected basis below observes only the compact ExactImage. The target
observation is the production exact total. A third observation records whether
the Merchant-classification boundary itself is complete; it will supply the
negative witness.
-/

inductive Observable where
  | summary
  | exactTotal
  | merchantBoundaryComplete

def Value : Observable → Type
  | .summary => ExactImage
  | .exactTotal => Option Quantity
  | .merchantBoundaryComplete => Bool

def observe : (observable : Observable) → Snapshot → Value observable
  | .summary, snapshot => exactImage snapshot
  | .exactTotal, snapshot => snapshot.exactTotal?
  | .merchantBoundaryComplete, snapshot =>
      snapshot.unresolvedMerchantEvents.isEmpty

def ImageBasis (observable : Observable) : Prop :=
  observable = .summary

/--
Observation 191's factorization criterion holds for the production exact-total
answer when indistinguishability is induced only by the compact image.
-/
theorem exactTotal_factors_through_imageBasis :
    Loam.Observation191.FactorsThroughIndistinguishability
      observe ImageBasis .exactTotal := by
  intro left right hIndistinguishable
  apply exactTotal_respects_sameExactImage
  exact hIndistinguishable .summary rfl

/-!
## Negative witness: exact answer and diagnostic detail need different images

Keep every field of an arbitrary Snapshot fixed, then make it incomplete for
one of two different reasons:

* unresolved Merchant classification;
* unresolved AccountingRole classification.

Both cases have the same compact ExactImage: same known total, incomplete.
But the Merchant-boundary completeness observation distinguishes them.
-/

private def merchantFailure
    (snapshot : Snapshot)
    (gap : UnresolvedMerchantEvent) : Snapshot :=
  {
    snapshot with
      unresolvedMerchantEvents := [gap]
      unresolvedRoleEffects := []
  }

private def roleFailure
    (snapshot : Snapshot)
    (gap : UnresolvedRoleEffect) : Snapshot :=
  {
    snapshot with
      unresolvedMerchantEvents := []
      unresolvedRoleEffects := [gap]
  }

/--
The compact exact-answer image forgets which completeness boundary failed.
-/
theorem exactImage_forgets_failure_kind
    (snapshot : Snapshot)
    (merchantGap : UnresolvedMerchantEvent)
    (roleGap : UnresolvedRoleEffect) :
    exactImage (merchantFailure snapshot merchantGap) =
      exactImage (roleFailure snapshot roleGap) := by
  simp [
    exactImage,
    merchantFailure,
    roleFailure,
    Loam.MerchantExpenseReview.Snapshot.knownTotal
  ]

/--
The rich diagnostic surface still observes that forgotten distinction.
-/
theorem failure_kind_remains_observable
    (snapshot : Snapshot)
    (merchantGap : UnresolvedMerchantEvent)
    (roleGap : UnresolvedRoleEffect) :
    observe .merchantBoundaryComplete (merchantFailure snapshot merchantGap) ≠
      observe .merchantBoundaryComplete (roleFailure snapshot roleGap) := by
  simp [observe, merchantFailure, roleFailure]

/--
Therefore Merchant-boundary diagnostic completeness does not factor through the
same compact image, given ordinary witnesses for both incomplete cases.

This is the R5 stop line: the image is sufficient for `exactTotal?`, but is too
small to replace the inspectable production Snapshot.
-/
theorem merchantBoundaryComplete_does_not_factor_through_imageBasis
    (snapshot : Snapshot)
    (merchantGap : UnresolvedMerchantEvent)
    (roleGap : UnresolvedRoleEffect) :
    ¬ Loam.Observation191.FactorsThroughIndistinguishability
      observe ImageBasis .merchantBoundaryComplete := by
  intro hFactors
  let left := merchantFailure snapshot merchantGap
  let right := roleFailure snapshot roleGap
  have hIndistinguishable :
      Loam.Observation191.IndistinguishableBy
        observe ImageBasis left right := by
    intro observable hObservable
    subst observable
    exact exactImage_forgets_failure_kind snapshot merchantGap roleGap
  exact
    failure_kind_remains_observable snapshot merchantGap roleGap
      (hFactors left right hIndistinguishable)

/-!
## Finding

For the selected production observation:

```text
rich MerchantExpense Snapshot
        |
        v
ExactImage { knownTotal, complete }
        |
        v
exactTotal?
```

is a valid factorization.

But the same image cannot support the diagnostic question "which completeness
boundary failed?". The full Snapshot's unresolved Merchant Event and unresolved
AccountingRole Effect witnesses therefore remain semantically justified even
though the scalar exact answer does not observe them.

R5 consequently supports selective compression of derived answers, not
replacement of evidence-rich review surfaces.
-/

end Loam.Observation336
