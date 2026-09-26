import Loam.Observations.Observation325
import Std.Data.HashMap.Lemmas

namespace Loam.Observation330

open Loam.Core

set_option autoImplicit false

/-!
# Observation 330 — Transactions-Flow represented-row support is derivable

Observation 329 showed that one Event-local CellIndex already carries both:

- exact coordinate support;
- exact aggregated cell value.

Observation 328 still seeds the global RowIndex from `Snapshot.rows` before
scanning Columns. This observation isolates the support half of that pre-pass.

The question is deliberately smaller than a full seedless RowIndex theorem:

> Is the represented row set exactly the support discovered from selected raw
> Effect evidence, with sorting and duplicate removal contributing only
> representation/order rather than new membership meaning?

This is research-only. Production is unchanged.
-/

private abbrev CoordinateKey := Loam.Observation325.CoordinateKey
private abbrev SupportIndex := Loam.Observation325.CellIndex

/-- All selected raw Effect evidence, forgetting Column boundaries only for support discovery. -/
private def flattenedEffects
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : List Effect :=
  snapshot.columns.flatMap fun column => column.event.effects

/--
Research support index.

Its numeric values are not used as RowActivity and carry no global activity
meaning. Only key presence is observed here.
-/
private def discoveredSupport
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : SupportIndex :=
  Loam.Observation325.buildCellIndex (flattenedEffects snapshot)

/--
Membership in the public represented row list is exactly raw selected Effect
occurrence.

`eraseDups` and `mergeSort` therefore change representation/order, not the
underlying represented coordinate set.
-/
private theorem exists_selected_effect_iff_row_mem
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    (∃ effect ∈ flattenedEffects snapshot,
      effect.coordinate = coordinate) ↔
      coordinate ∈ snapshot.rows := by
  change
    (∃ effect ∈ flattenedEffects snapshot,
      effect.coordinate = coordinate) ↔
    coordinate ∈
      List.mergeSort
        (List.eraseDups
          (snapshot.columns.flatMap fun column =>
            column.event.effects.map fun effect => effect.coordinate))
        _
  simp [flattenedEffects]
  constructor
  · rintro ⟨effect, ⟨column, hColumn, hEffect⟩, hCoordinate⟩
    exact ⟨column, hColumn, effect, hEffect, hCoordinate⟩
  · rintro ⟨column, hColumn, effect, hEffect, hCoordinate⟩
    exact ⟨effect, ⟨column, hColumn, hEffect⟩, hCoordinate⟩

/--
The transient support index contains exactly the same represented coordinate
set as `Snapshot.rows`.

The theorem is about support only. It does not identify global summed CellIndex
values with RowActivity.
-/
theorem discoveredSupport_contains_eq_row_mem
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    (discoveredSupport snapshot).contains
        (Loam.Observation325.coordinateKey coordinate) =
      decide (coordinate ∈ snapshot.rows) := by
  unfold discoveredSupport
  rw [Loam.Observation325.buildCellIndex_contains_eq_any]
  rw [Bool.eq_iff_iff]
  simp only [List.any_eq_true, decide_eq_true_eq]
  exact exists_selected_effect_iff_row_mem snapshot coordinate

/--
Represented zero rows are included automatically because support follows raw
occurrence, not a nonzero test.

This is a direct consequence of the support theorem and does not require the
global activity value to have been computed first.
-/
theorem represented_row_is_discovered
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hRepresented : coordinate ∈ snapshot.rows) :
    (discoveredSupport snapshot).contains
        (Loam.Observation325.coordinateKey coordinate) = true := by
  rw [discoveredSupport_contains_eq_row_mem]
  simp [hRepresented]

/--
No unrepresented row is manufactured by support discovery.
-/
theorem unrepresented_row_is_absent
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hUnrepresented : coordinate ∉ snapshot.rows) :
    (discoveredSupport snapshot).contains
        (Loam.Observation325.coordinateKey coordinate) = false := by
  rw [discoveredSupport_contains_eq_row_mem]
  simp [hUnrepresented]

/-!
## Finding

The global represented-row support does not need `Snapshot.rows` as an
independent semantic input.

As a set:

    Snapshot.rows
      =
    coordinates occurring in selected raw Effect evidence

while:

    eraseDups
      preserves membership

    mergeSort
      preserves membership and chooses presentation order

So the current pre-seeding shape:

    build sorted Snapshot.rows
      -> seed zero global row states
      -> scan Columns

contains a separable concern. The row *support* can instead be discovered while
evidence is scanned.

This observation intentionally stops before claiming that RowActivity values can
be fused into the same first-insertion scan. That is the next refinement
question.

A future seedless builder must still prove both:

1. first occurrence inserts the represented key even when the Event-local cell
   sums to zero;
2. repeated occurrences update the same key with exactly current RowActivity
   semantics.

If that succeeds, sorting can remain a requested presentation operation rather
than a prerequisite for constructing the summary.

No production optimization is authorized by this observation.
-/

end Loam.Observation330
