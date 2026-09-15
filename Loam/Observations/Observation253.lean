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

and one compatibility obligation at the queried Measure:

```
accountView (resourceOf locus) measure = Observation250.accountOf locus measure
```

Under that obligation, the REA-mediated route and Observation 250's direct
Ledger-shaped route have exactly the same flow at every Ledger coordinate.
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
The accounting view is compatible with Observation 250's direct coordinate
selection at one queried Measure.

The hypothesis is intentionally silent about other Measures. Observation 253 is
a commuting theorem for the selected single-Measure movement slice, not a global
ontology alignment claim.
-/
def CompatibleAtMeasure {Resource : Type u}
    (resourceOf : LocusId → Resource)
    (accountView : Resource → MeasureId → LedgerAccountShadow)
    (measure : MeasureId) : Prop :=
  ∀ locus,
    mediatedAccountOf resourceOf accountView locus measure =
      accountOf locus measure

/--
Generic commuting theorem at the exact integer-quanta level.

Once the mediated accounting view agrees with the direct Observation-250
coordinate for the selected Measure, both routes return the same flow at every
Ledger-shaped account coordinate.
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
  induction changes with
  | nil => rfl
  | cons change rest ih =>
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
      rw [hCompatible change.coordinate]
      by_cases hAccount : accountOf change.coordinate measure = account
      · simp [hAccount, ih]
      · simp [hAccount, ih]

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
