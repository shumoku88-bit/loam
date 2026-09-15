import Loam.Observations.Observation250

namespace Loam.Observation253

open Loam.Core
open Loam.Observation250

set_option autoImplicit false

universe u

/-!
# Observation 253 — generic LOAM–REA–Ledger commuting theorem

Observations 250–252 established three boundaries:

* LOAM `BalancedMovement` admits a direct Ledger/Pacioli-shaped additive view;
* selected REA interpretation is not forced by neutral LOAM evidence;
* an REA interpretation does not by itself determine one Ledger account view,
  but a compatible accounting-view policy makes the bounded triangle commute.

This observation promotes the positive part of Observation 252 from bounded
Alloy exploration to a generic Lean theorem. `Resource` is completely abstract:
it need not be a production LOAM type and no REA vocabulary is added to Core.

The only selected bridge data are:

```
resourceOf : LocusId -> Resource
accountView : Resource -> MeasureId -> LedgerAccountShadow
```

and a compatibility obligation saying that the mediated route selects the same
Ledger coordinate as Observation 250's direct route. The strongest theorem only
requires this agreement for changes actually present in the queried movement.
-/

/--
Compose an arbitrary Locus-to-Resource interpretation with an arbitrary
Resource-to-Ledger accounting view.
-/
def mediatedAccountOf {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (locus : LocusId)
    (measure : MeasureId) : LedgerAccountShadow :=
  accountView (resourceOf locus) measure

/--
Flow observation through the interpreted Resource and selected accounting view.
The arithmetic intentionally matches Observation 250 exactly; only coordinate
selection takes the mediated route.
-/
def mediatedFlowQuantaAtChanges {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (account : LedgerAccountShadow) : Int :=
  changes.foldr
    (fun change total =>
      if mediatedAccountOf resourceOf accountView change.coordinate measure = account then
        change.quantity.quanta + total
      else
        total)
    0

/-- Quantity-valued mediated balance observation for one admitted movement. -/
def mediatedFlowAt {Resource : Type u}
    (movement : BalancedMovement LocusId)
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (account : LedgerAccountShadow) : Quantity :=
  Quantity.ofQuanta
    (mediatedFlowQuantaAtChanges
      resourceOf accountView movement.measure movement.changes account)

/--
A convenient stronger compatibility form: every Locus agrees at one selected
Measure. This remains silent about other Measures.
-/
def CompatibleAtMeasure {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId) : Prop :=
  ∀ locus,
    mediatedAccountOf resourceOf accountView locus measure =
      accountOf locus measure

/--
The minimal compatibility condition for one concrete projection: only changes
actually present in the movement must select the same Ledger coordinate through
both routes.
-/
def CompatibleOnChanges {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId)
    (changes : List (MovementChange LocusId)) : Prop :=
  ∀ change ∈ changes,
    mediatedAccountOf resourceOf accountView change.coordinate measure =
      accountOf change.coordinate measure

/--
Strongest commuting theorem at the exact integer-quanta level.

Agreement only on the retained changes being projected is enough to force equal
flow at every Ledger-shaped account coordinate. Unobserved Loci and all other
Measures are irrelevant to this selected query.
-/
theorem mediatedFlowQuanta_eq_direct_of_observed_compatible {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (hCompatible : CompatibleOnChanges resourceOf accountView measure changes)
    (account : LedgerAccountShadow) :
    mediatedFlowQuantaAtChanges resourceOf accountView measure changes account =
      ledgerFlowQuantaAtChanges measure changes account := by
  revert hCompatible account
  induction changes with
  | nil =>
      intro _ _
      rfl
  | cons change rest ih =>
      intro hCompatible account
      have hHead :
          mediatedAccountOf resourceOf accountView change.coordinate measure =
            accountOf change.coordinate measure :=
        hCompatible change (by simp)
      have hRest : CompatibleOnChanges resourceOf accountView measure rest := by
        intro restChange hMem
        exact hCompatible restChange (by simp [hMem])
      change
        (if mediatedAccountOf resourceOf accountView change.coordinate measure = account then
            change.quantity.quanta +
              mediatedFlowQuantaAtChanges resourceOf accountView measure rest account
          else
            mediatedFlowQuantaAtChanges resourceOf accountView measure rest account) =
          (if accountOf change.coordinate measure = account then
              change.quantity.quanta +
                ledgerFlowQuantaAtChanges measure rest account
            else
              ledgerFlowQuantaAtChanges measure rest account)
      rw [hHead]
      by_cases hAccount : accountOf change.coordinate measure = account
      · simp [hAccount, ih hRest account]
      · simp [hAccount, ih hRest account]

/--
Global-at-one-Measure compatibility is a simple corollary of the observed-only
commuting theorem.
-/
theorem mediatedFlowQuanta_eq_direct_of_compatible {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (hCompatible : CompatibleAtMeasure resourceOf accountView measure)
    (account : LedgerAccountShadow) :
    mediatedFlowQuantaAtChanges resourceOf accountView measure changes account =
      ledgerFlowQuantaAtChanges measure changes account := by
  apply mediatedFlowQuanta_eq_direct_of_observed_compatible
    resourceOf accountView measure changes
  · intro change _
    exact hCompatible change.coordinate
  · exact account

/-- Quantity-valued commuting theorem for one admitted `BalancedMovement`. -/
theorem mediatedFlow_eq_direct_of_compatible {Resource : Type u}
    (movement : BalancedMovement LocusId)
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (hCompatible : CompatibleAtMeasure resourceOf accountView movement.measure)
    (account : LedgerAccountShadow) :
    mediatedFlowAt movement resourceOf accountView account =
      ledgerFlowAt movement account := by
  unfold mediatedFlowAt ledgerFlowAt ledgerFlowAtChanges
  rw [mediatedFlowQuanta_eq_direct_of_compatible
    resourceOf accountView movement.measure movement.changes hCompatible account]

/--
Consequently, every mapped Locus has exactly the same quantity through the
REA-mediated route as through LOAM's own `BalancedMovement.quantityAt` query.
-/
theorem mediatedFlow_mapped_locus_eq_quantityAt {Resource : Type u}
    (movement : BalancedMovement LocusId)
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (hCompatible : CompatibleAtMeasure resourceOf accountView movement.measure)
    (locus : LocusId) :
    mediatedFlowAt movement resourceOf accountView
        (accountOf locus movement.measure) =
      movement.quantityAt locus := by
  rw [mediatedFlow_eq_direct_of_compatible
    movement resourceOf accountView hCompatible
    (accountOf locus movement.measure)]
  exact ledgerFlowAt_mapped_locus movement locus

/--
Observation 252's Resource-collapse boundary follows generically from function
composition: if two direct Ledger coordinates are distinct, a compatible
Resource-only accounting view cannot map both Loci through one Resource value.
-/
theorem compatible_view_separates_distinct_direct_coordinates {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId)
    (hCompatible : CompatibleAtMeasure resourceOf accountView measure)
    (left right : LocusId)
    (hDistinct : accountOf left measure ≠ accountOf right measure) :
    resourceOf left ≠ resourceOf right := by
  intro hResource
  apply hDistinct
  calc
    accountOf left measure =
        mediatedAccountOf resourceOf accountView left measure :=
      (hCompatible left).symm
    _ = mediatedAccountOf resourceOf accountView right measure := by
      simp [mediatedAccountOf, hResource]
    _ = accountOf right measure := hCompatible right

end Loam.Observation253
