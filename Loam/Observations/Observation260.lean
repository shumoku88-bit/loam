import Std.Tactic.Omega
import Loam.Observations.Observation259

namespace Loam.Observation260

open Loam.Core

set_option autoImplicit false

/-!
# Observation 260 — compositional correction quantity diffs

Observations 257–259 established exact point deltas, complete finite changed
support, and safe human-facing labels for one original/replacement pair.
This observation asks whether two successive correction quantity diffs compose
without retaining a new chain-diff authority.

The quantity layer should telescope. The support layer needs one extra filter,
because intermediate changes can cancel. Human labels remain endpoint-derived
and are deliberately not given an algebra.
-/

/-- Sum the two step deltas at one coordinate. Research-only projection. -/
def composedDeltaQuantaAt
    (first middle last : Event) (coordinate : EffectCoordinate) : Int :=
  Loam.Observation258.quantityDeltaQuantaAt first middle coordinate +
    Loam.Observation258.quantityDeltaQuantaAt middle last coordinate

/--
Pointwise telescoping law: direct endpoint delta equals the sum of step deltas.
No Effect lineage, identity matching, or chronology beyond the selected
first/middle/last comparison is required.
-/
theorem quantityDeltaQuantaAt_compose
    (first middle last : Event) (coordinate : EffectCoordinate) :
    Loam.Observation258.quantityDeltaQuantaAt first last coordinate =
      composedDeltaQuantaAt first middle last coordinate := by
  unfold composedDeltaQuantaAt Loam.Observation258.quantityDeltaQuantaAt
    Loam.Observation257.quantityDeltaQuanta
  omega

/-- Finite coordinate support exposed by either step diff. -/
def stepChangedCoordinates
    (first middle last : Event) : List EffectCoordinate :=
  (Loam.Observation258.changedCoordinates first middle ++
    Loam.Observation258.changedCoordinates middle last).eraseDups

/-- Membership in the deduplicated step support means membership in either step. -/
theorem mem_stepChangedCoordinates_iff
    (first middle last : Event) (coordinate : EffectCoordinate) :
    coordinate ∈ stepChangedCoordinates first middle last ↔
      coordinate ∈ Loam.Observation258.changedCoordinates first middle ∨
      coordinate ∈ Loam.Observation258.changedCoordinates middle last := by
  simp [stepChangedCoordinates]

/--
Every direct endpoint change must have appeared in at least one step. If neither
step changed the coordinate, their sum is zero and the direct delta cannot be
nonzero.
-/
theorem direct_nonzero_mem_stepChangedCoordinates
    (first middle last : Event) (coordinate : EffectCoordinate)
    (hDirect : Loam.Observation258.quantityDeltaQuantaAt first last coordinate ≠ 0) :
    coordinate ∈ stepChangedCoordinates first middle last := by
  by_cases hFirst :
      Loam.Observation258.quantityDeltaQuantaAt first middle coordinate = 0
  · have hLast :
        Loam.Observation258.quantityDeltaQuantaAt middle last coordinate ≠ 0 := by
      intro hLastZero
      apply hDirect
      rw [quantityDeltaQuantaAt_compose]
      simp [composedDeltaQuantaAt, hFirst, hLastZero]
    apply (mem_stepChangedCoordinates_iff first middle last coordinate).2
    exact Or.inr <|
      (Loam.Observation258.mem_changedCoordinates_iff_nonzero
        middle last coordinate).2 hLast
  · apply (mem_stepChangedCoordinates_iff first middle last coordinate).2
    exact Or.inl <|
      (Loam.Observation258.mem_changedCoordinates_iff_nonzero
        first middle coordinate).2 hFirst

/--
Compose two complete step supports by retaining only coordinates whose summed
step delta is nonzero. Intermediate motion that cancels is intentionally removed.
-/
def composedChangedCoordinates
    (first middle last : Event) : List EffectCoordinate :=
  (stepChangedCoordinates first middle last).filter
    (fun coordinate => decide (composedDeltaQuantaAt first middle last coordinate ≠ 0))

/-- The composed support is exact for the direct endpoint nonzero delta. -/
theorem mem_composedChangedCoordinates_iff_nonzero_direct
    (first middle last : Event) (coordinate : EffectCoordinate) :
    coordinate ∈ composedChangedCoordinates first middle last ↔
      Loam.Observation258.quantityDeltaQuantaAt first last coordinate ≠ 0 := by
  constructor
  · intro hMem
    simp only [composedChangedCoordinates, List.mem_filter] at hMem
    have hComposed : composedDeltaQuantaAt first middle last coordinate ≠ 0 :=
      of_decide_eq_true hMem.2
    intro hDirectZero
    apply hComposed
    have hEq := quantityDeltaQuantaAt_compose first middle last coordinate
    exact hEq.symm.trans hDirectZero
  · intro hDirect
    have hStep := direct_nonzero_mem_stepChangedCoordinates
      first middle last coordinate hDirect
    have hComposed : composedDeltaQuantaAt first middle last coordinate ≠ 0 := by
      intro hZero
      apply hDirect
      exact (quantityDeltaQuantaAt_compose first middle last coordinate).trans hZero
    simp [composedChangedCoordinates, hStep, hComposed]

/--
Exact support composition law. The composed step support and the direct O258
support may have different list order, but have exactly the same members.
-/
theorem mem_composedChangedCoordinates_iff_direct
    (first middle last : Event) (coordinate : EffectCoordinate) :
    coordinate ∈ composedChangedCoordinates first middle last ↔
      coordinate ∈ Loam.Observation258.changedCoordinates first last := by
  rw [mem_composedChangedCoordinates_iff_nonzero_direct]
  exact (Loam.Observation258.mem_changedCoordinates_iff_nonzero
    first last coordinate).symm

/-! ## Cancellation witness: `added` then `removed` disappears end-to-end -/

private def locus : LocusId := ⟨"o260-locus"⟩
private def yen : MeasureId := ⟨"o260-yen"⟩
private def coordinate : EffectCoordinate := ⟨locus, yen⟩

private def firstEvent : Event :=
  { id := ⟨"o260-first"⟩
    effects := []
    keyNodup := by simp [retainedEffectKeys] }

private def middleEvent : Event :=
  { id := ⟨"o260-middle"⟩
    effects := [Effect.ofAnonymousQuantity locus yen (Quantity.ofQuanta 100)]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def lastEvent : Event :=
  { id := ⟨"o260-last"⟩
    effects := []
    keyNodup := by simp [retainedEffectKeys] }

/-- First step adds +100 quanta. -/
theorem first_step_delta :
    Loam.Observation258.quantityDeltaQuantaAt firstEvent middleEvent coordinate = 100 := by
  simp [Loam.Observation258.quantityDeltaQuantaAt,
    Loam.Observation257.quantityDeltaQuanta,
    firstEvent, middleEvent, coordinate, locus, yen,
    Event.quantityAt, Effect.coordinate]

/-- Second step removes exactly those 100 quanta. -/
theorem second_step_delta :
    Loam.Observation258.quantityDeltaQuantaAt middleEvent lastEvent coordinate = -100 := by
  simp [Loam.Observation258.quantityDeltaQuantaAt,
    Loam.Observation257.quantityDeltaQuanta,
    middleEvent, lastEvent, coordinate, locus, yen,
    Event.quantityAt, Effect.coordinate]

/-- Endpoint quantity delta is zero because the two step deltas cancel. -/
theorem direct_delta_cancels :
    Loam.Observation258.quantityDeltaQuantaAt firstEvent lastEvent coordinate = 0 := by
  rw [quantityDeltaQuantaAt_compose]
  simp [composedDeltaQuantaAt, first_step_delta, second_step_delta]

/-- The coordinate occurs in both step changed supports. -/
theorem coordinate_changes_in_both_steps :
    coordinate ∈ Loam.Observation258.changedCoordinates firstEvent middleEvent ∧
      coordinate ∈ Loam.Observation258.changedCoordinates middleEvent lastEvent := by
  constructor
  · apply (Loam.Observation258.mem_changedCoordinates_iff_nonzero
      firstEvent middleEvent coordinate).2
    simp [first_step_delta]
  · apply (Loam.Observation258.mem_changedCoordinates_iff_nonzero
      middleEvent lastEvent coordinate).2
    simp [second_step_delta]

/-- The first step is safely described as `added`. -/
theorem first_step_label_added :
    Loam.Observation259.changeKindAt firstEvent middleEvent coordinate = .added := by
  simp [Loam.Observation259.changeKindAt,
    Loam.Observation258.eventCoordinates,
    firstEvent, middleEvent, coordinate, locus, yen, Effect.coordinate]

/-- The second step is safely described as `removed`. -/
theorem second_step_label_removed :
    Loam.Observation259.changeKindAt middleEvent lastEvent coordinate = .removed := by
  simp [Loam.Observation259.changeKindAt,
    Loam.Observation258.eventCoordinates,
    middleEvent, lastEvent, coordinate, locus, yen, Effect.coordinate]

/--
Despite appearing in both step diffs, the coordinate correctly disappears from
the composed endpoint support because +100 + (-100) = 0.
-/
theorem cancelling_coordinate_not_in_composed_support :
    coordinate ∉ composedChangedCoordinates firstEvent middleEvent lastEvent := by
  intro hMem
  have hDirect := (mem_composedChangedCoordinates_iff_nonzero_direct
    firstEvent middleEvent lastEvent coordinate).1 hMem
  exact hDirect direct_delta_cancels

/-- The direct endpoint O258 diff also contains no row for the cancelled coordinate. -/
theorem cancelling_coordinate_not_in_direct_support :
    coordinate ∉ Loam.Observation258.changedCoordinates firstEvent lastEvent := by
  intro hMem
  have hDirect := (Loam.Observation258.mem_changedCoordinates_iff_nonzero
    firstEvent lastEvent coordinate).1 hMem
  exact hDirect direct_delta_cancels

/-!
Observation boundary:

* coordinate quantity deltas telescope exactly across one intermediate Event;
* every direct endpoint change occurs in at least one step changed support;
* unioning step supports and filtering by nonzero summed delta yields exactly the
  direct endpoint changed support, up to list order;
* intermediate changes may cancel and correctly disappear end-to-end;
* human `added / removed / changed` labels are endpoint-presence descriptions,
  not additive tokens: `added` followed by `removed` can compose to no final row;
* none of these laws reconstruct Effect lineage, cause, capture chronology, or
  accounting interpretation.

Therefore complete quantity diffs are compositional read projections, while the
human explanation vocabulary remains deliberately non-algebraic.
-/

end Loam.Observation260
