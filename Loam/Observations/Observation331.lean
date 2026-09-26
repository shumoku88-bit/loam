import Loam.Observations.Observation327
import Loam.Observations.Observation329
import Loam.Observations.Observation330
import Std.Data.HashMap.Lemmas

namespace Loam.Observation331

open Loam.Core

set_option autoImplicit false

/-!
# Observation 331 — Seedless one-pass Transactions-Flow RowIndex

Observation 329 removed the separate Event-coordinate dedup representation:
an Event-local CellIndex already carries exact coordinate support and exact
post-aggregation cell values.

Observation 330 then separated global row support from presentation order:
represented-row membership is raw selected Effect occurrence, while eraseDups
and mergeSort only choose a duplicate-free ordered presentation.

This observation asks the remaining refinement question:

> Can the global RowIndex start empty, discover represented keys while scanning
> Columns, and accumulate RowActivity in that same scan?

The candidate intentionally inserts a key even when the Event-local aggregated
cell is zero. Thus raw representation survives exact same-Event cancellation.

This is research-only. Production remains unchanged.
-/

private abbrev CoordinateKey := Loam.Observation325.CoordinateKey
private abbrev CellIndex := Loam.Observation325.CellIndex
private abbrev ActivityState := Int × Int × Nat
private abbrev SeedlessRowIndex := Std.HashMap CoordinateKey ActivityState

private def zeroState : ActivityState := (0, 0, 0)

private def advanceState
    (state : ActivityState) (quantity : Int) : ActivityState :=
  if quantity > 0 then
    (state.1 + quantity, state.2.1, state.2.2 + 1)
  else if quantity < 0 then
    (state.1, state.2.1 + quantity, state.2.2 + 1)
  else
    state

private theorem advanceState_zero (state : ActivityState) :
    advanceState state 0 = state := by
  simp [advanceState]

private def activityFromState
    (state : ActivityState) : Loam.TransactionsFlowReview.RowActivity :=
  {
    positive := Quantity.ofQuanta state.1
    negative := Quantity.ofQuanta state.2.1
    activeEvents := state.2.2
  }

private def directQuanta
    (event : Event)
    (coordinate : EffectCoordinate) : Int :=
  (Event.quantityAt
    event coordinate.locus coordinate.measure).quanta

private def directStep
    (coordinate : EffectCoordinate)
    (state : ActivityState)
    (column : Loam.TransactionsFlowReview.Column) : ActivityState :=
  advanceState state (directQuanta column.event coordinate)

/--
Raw Event support as a Bool.

This intentionally observes coordinate occurrence rather than nonzero quantity.
-/
private def representedInColumn
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) : Bool :=
  column.event.effects.any fun effect =>
    decide (effect.coordinate = coordinate)

/-! ## 1. Event-local key support -/

private theorem representedInColumn_iff_key_mem
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) :
    representedInColumn coordinate column = true ↔
      Loam.Observation325.coordinateKey coordinate ∈
        (Loam.Observation325.buildCellIndex column.event.effects).keys := by
  have h :=
    Loam.Observation329.coordinate_mem_eventCellKeys_iff_raw_occurs
      column.event coordinate
  change
    Loam.Observation325.coordinateKey coordinate ∈
        (Loam.Observation325.buildCellIndex column.event.effects).keys ↔
      representedInColumn coordinate column = true at h
  exact h.symm

private theorem directQuanta_zero_of_not_represented
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column)
    (hNotRepresented : representedInColumn coordinate column = false) :
    directQuanta column.event coordinate = 0 := by
  let cells := Loam.Observation325.buildCellIndex column.event.effects
  have hContains :
      cells.contains (Loam.Observation325.coordinateKey coordinate) = false := by
    change
      (Loam.Observation325.buildCellIndex column.event.effects).contains
          (Loam.Observation325.coordinateKey coordinate) = false
    rw [Loam.Observation325.buildCellIndex_contains_eq_any]
    exact hNotRepresented
  have hNone :
      cells.get? (Loam.Observation325.coordinateKey coordinate) = none := by
    exact Std.HashMap.getElem?_eq_none_of_contains_eq_false hContains
  have hCell :=
    Loam.Observation325.buildCellIndex_getD_eq_quantityAt
      column.event coordinate
  change
    ((cells.get? (Loam.Observation325.coordinateKey coordinate)).getD 0) =
      directQuanta column.event coordinate at hCell
  rw [hNone] at hCell
  exact hCell.symm

/-! ## 2. Update one Event-local sparse map -/

/--
Update one global row from one Event-local cell.

The global key is inserted even when the cell value is zero. This is the
seedless replacement for pre-seeding every Snapshot.rows key with zeroState.
-/
private def updateKey
    (cells : CellIndex)
    (index : SeedlessRowIndex)
    (key : CoordinateKey) : SeedlessRowIndex :=
  index.insert key
    (advanceState
      ((index.get? key).getD zeroState)
      ((cells.get? key).getD 0))

private theorem updateKey_same
    (cells : CellIndex)
    (index : SeedlessRowIndex)
    (key : CoordinateKey) :
    (updateKey cells index key).get? key =
      some
        (advanceState
          ((index.get? key).getD zeroState)
          ((cells.get? key).getD 0)) := by
  unfold updateKey
  rw [Std.HashMap.get?_insert]
  simp

private theorem updateKey_other
    (cells : CellIndex)
    (index : SeedlessRowIndex)
    (row key : CoordinateKey)
    (hNe : row ≠ key) :
    (updateKey cells index row).get? key =
      index.get? key := by
  unfold updateKey
  rw [Std.HashMap.get?_insert]
  have hBeq : (row == key) = false := by
    cases h : (row == key) with
    | false => rfl
    | true =>
        have hEq : row = key := eq_of_beq h
        exact False.elim (hNe hEq)
  rw [hBeq]
  simp

private def updateKeys
    (cells : CellIndex) :
    List CoordinateKey → SeedlessRowIndex → SeedlessRowIndex
  | [], index => index
  | key :: rest, index =>
      updateKeys cells rest (updateKey cells index key)

private theorem updateKeys_not_mem
    (cells : CellIndex)
    (keys : List CoordinateKey)
    (index : SeedlessRowIndex)
    (target : CoordinateKey)
    (hNotMem : target ∉ keys) :
    (updateKeys cells keys index).get? target =
      index.get? target := by
  induction keys generalizing index with
  | nil =>
      rfl
  | cons key rest ih =>
      have hHead : key ≠ target := by
        intro hEq
        apply hNotMem
        simp [hEq]
      have hRest : target ∉ rest := by
        intro hMem
        apply hNotMem
        exact List.mem_cons_of_mem key hMem
      simp only [updateKeys]
      calc
        (updateKeys cells rest (updateKey cells index key)).get? target =
            (updateKey cells index key).get? target :=
          ih (updateKey cells index key) hRest
        _ = index.get? target :=
          updateKey_other cells index key target hHead

private theorem updateKeys_mem
    (cells : CellIndex)
    (keys : List CoordinateKey)
    (index : SeedlessRowIndex)
    (target : CoordinateKey)
    (hNodup : keys.Nodup)
    (hMem : target ∈ keys) :
    (updateKeys cells keys index).get? target =
      some
        (advanceState
          ((index.get? target).getD zeroState)
          ((cells.get? target).getD 0)) := by
  induction keys generalizing index with
  | nil =>
      simp at hMem
  | cons key rest ih =>
      simp only [List.nodup_cons] at hNodup
      simp only [List.mem_cons] at hMem
      simp only [updateKeys]
      rcases hMem with hHead | hTail
      · subst key
        have hAfter := updateKey_same cells index target
        calc
          (updateKeys cells rest (updateKey cells index target)).get? target =
              (updateKey cells index target).get? target :=
            updateKeys_not_mem
              cells rest (updateKey cells index target)
              target hNodup.1
          _ =
              some
                (advanceState
                  ((index.get? target).getD zeroState)
                  ((cells.get? target).getD 0)) :=
            hAfter
      · have hNe : key ≠ target := by
          intro hEq
          subst key
          exact hNodup.1 hTail
        have hOther :=
          updateKey_other cells index key target hNe
        have hResult :=
          ih (updateKey cells index key) hNodup.2 hTail
        rw [hOther] at hResult
        exact hResult

private def updateColumn
    (index : SeedlessRowIndex)
    (column : Loam.TransactionsFlowReview.Column) : SeedlessRowIndex :=
  let cells := Loam.Observation325.buildCellIndex column.event.effects
  updateKeys cells cells.keys index

/-! ## 3. Lookup law for one Column -/

/--
Option-state view of one target coordinate.

- absent raw support leaves the Option unchanged;
- present raw support inserts or updates exactly once using the already-aggregated
  Event-local cell quantity.
-/
private def optionStep
    (coordinate : EffectCoordinate)
    (state : Option ActivityState)
    (column : Loam.TransactionsFlowReview.Column) : Option ActivityState :=
  if representedInColumn coordinate column then
    some (directStep coordinate (state.getD zeroState) column)
  else
    state

private theorem updateColumn_get?
    (index : SeedlessRowIndex)
    (column : Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate) :
    (updateColumn index column).get?
        (Loam.Observation325.coordinateKey coordinate) =
      optionStep coordinate
        (index.get? (Loam.Observation325.coordinateKey coordinate))
        column := by
  unfold updateColumn optionStep
  let cells := Loam.Observation325.buildCellIndex column.event.effects
  by_cases hRepresented : representedInColumn coordinate column = true
  · have hMem :
        Loam.Observation325.coordinateKey coordinate ∈ cells.keys := by
      exact
        (representedInColumn_iff_key_mem coordinate column).mp hRepresented
    have hUpdate :=
      updateKeys_mem
        cells cells.keys index
        (Loam.Observation325.coordinateKey coordinate)
        Std.HashMap.nodup_keys hMem
    rw [hRepresented]
    rw [hUpdate]
    have hCell :=
      Loam.Observation325.buildCellIndex_getD_eq_quantityAt
        column.event coordinate
    change
      ((cells.get? (Loam.Observation325.coordinateKey coordinate)).getD 0) =
        directQuanta column.event coordinate at hCell
    rw [hCell]
    rfl
  · have hNotRepresented :
        representedInColumn coordinate column = false := by
      cases hValue : representedInColumn coordinate column with
      | false => rfl
      | true => exact False.elim (hRepresented hValue)
    have hNotMem :
        Loam.Observation325.coordinateKey coordinate ∉ cells.keys := by
      intro hMem
      have hTrue :=
        (representedInColumn_iff_key_mem coordinate column).mpr hMem
      exact hRepresented hTrue
    rw [hNotRepresented]
    exact
      updateKeys_not_mem
        cells cells.keys index
        (Loam.Observation325.coordinateKey coordinate)
        hNotMem

/-! ## 4. Option-state fold corresponds to direct RowActivity fold -/

private theorem optionStep_some_eq_direct
    (coordinate : EffectCoordinate)
    (state : ActivityState)
    (column : Loam.TransactionsFlowReview.Column) :
    optionStep coordinate (some state) column =
      some (directStep coordinate state column) := by
  unfold optionStep
  cases hRepresented : representedInColumn coordinate column with
  | true =>
      simp [hRepresented]
  | false =>
      have hZero :=
        directQuanta_zero_of_not_represented
          coordinate column hRepresented
      simp [hRepresented, directStep, hZero, advanceState_zero]

private theorem optionFold_some_eq_direct
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (state : ActivityState) :
    columns.foldl (optionStep coordinate) (some state) =
      some (columns.foldl (directStep coordinate) state) := by
  induction columns generalizing state with
  | nil =>
      rfl
  | cons column rest ih =>
      simp only [List.foldl_cons]
      rw [optionStep_some_eq_direct]
      exact ih (directStep coordinate state column)

private theorem optionFold_none_eq_direct_if_represented
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate) :
    columns.foldl (optionStep coordinate) none =
      if columns.any (representedInColumn coordinate) then
        some (columns.foldl (directStep coordinate) zeroState)
      else
        none := by
  induction columns with
  | nil =>
      rfl
  | cons column rest ih =>
      simp only [List.foldl_cons, List.any_cons]
      by_cases hRepresented :
          representedInColumn coordinate column = true
      · have hOption :
            optionStep coordinate none column =
              some (directStep coordinate zeroState column) := by
          simp [optionStep, hRepresented]
        rw [hOption]
        simpa [hRepresented] using
          optionFold_some_eq_direct
            rest coordinate (directStep coordinate zeroState column)
      · have hFalse :
            representedInColumn coordinate column = false := by
          cases hValue : representedInColumn coordinate column with
          | false => rfl
          | true => exact False.elim (hRepresented hValue)
        have hOption :
            optionStep coordinate none column = none := by
          simp [optionStep, hFalse]
        have hZero :=
          directQuanta_zero_of_not_represented
            coordinate column hFalse
        have hDirect :
            directStep coordinate zeroState column = zeroState := by
          simp [directStep, hZero, advanceState]
        rw [hOption, hDirect]
        simpa [hFalse] using ih

/-! ## 5. Whole seedless scan -/

private theorem foldColumns_get?
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (index : SeedlessRowIndex) :
    (columns.foldl updateColumn index).get?
        (Loam.Observation325.coordinateKey coordinate) =
      columns.foldl
        (optionStep coordinate)
        (index.get? (Loam.Observation325.coordinateKey coordinate)) := by
  induction columns generalizing index with
  | nil =>
      rfl
  | cons column rest ih =>
      simp only [List.foldl_cons]
      calc
        (rest.foldl updateColumn (updateColumn index column)).get?
            (Loam.Observation325.coordinateKey coordinate) =
          rest.foldl
            (optionStep coordinate)
            ((updateColumn index column).get?
              (Loam.Observation325.coordinateKey coordinate)) :=
            ih (updateColumn index column)
        _ =
          rest.foldl
            (optionStep coordinate)
            (optionStep coordinate
              (index.get? (Loam.Observation325.coordinateKey coordinate))
              column) := by
                rw [updateColumn_get?]
        _ =
          (column :: rest).foldl
            (optionStep coordinate)
            (index.get? (Loam.Observation325.coordinateKey coordinate)) := by
              rfl

private def buildSeedlessRowIndex
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : SeedlessRowIndex :=
  snapshot.columns.foldl updateColumn {}

private def seedlessRowActivity?
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    Option Loam.TransactionsFlowReview.RowActivity :=
  ((buildSeedlessRowIndex snapshot).get?
      (Loam.Observation325.coordinateKey coordinate)).map activityFromState

private theorem activityFromDirectFold_eq_rowActivity
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    activityFromState
        (snapshot.columns.foldl (directStep coordinate) zeroState) =
      Loam.TransactionsFlowReview.rowActivity snapshot coordinate := by
  rfl

/-! ## 6. Selected-column support equals Snapshot.rows membership -/

private theorem selected_support_eq_row_membership
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    snapshot.columns.any (representedInColumn coordinate) =
      decide (coordinate ∈ snapshot.rows) := by
  rw [Bool.eq_iff_iff]
  simp only [List.any_eq_true, representedInColumn, decide_eq_true_eq]
  change
    (∃ column,
      column ∈ snapshot.columns ∧
      ∃ effect, effect ∈ column.event.effects ∧
        effect.coordinate = coordinate) ↔
    coordinate ∈
      List.mergeSort
        (List.eraseDups
          (snapshot.columns.flatMap fun column =>
            column.event.effects.map fun effect => effect.coordinate))
        _
  simp

/-! ## 7. General pointwise refinement -/

/--
For every represented row, the empty-start one-pass builder returns exactly the
current production RowActivity answer.
-/
theorem seedlessRowActivity?_of_represented
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hRepresented : coordinate ∈ snapshot.rows) :
    seedlessRowActivity? snapshot coordinate =
      some (Loam.TransactionsFlowReview.rowActivity snapshot coordinate) := by
  have hSupport :
      snapshot.columns.any (representedInColumn coordinate) = true := by
    rw [selected_support_eq_row_membership]
    simp [hRepresented]
  unfold seedlessRowActivity? buildSeedlessRowIndex
  rw [foldColumns_get?]
  simp only [Std.HashMap.get?_eq_getElem?, Std.HashMap.getElem?_empty]
  rw [optionFold_none_eq_direct_if_represented]
  rw [hSupport]
  simp [activityFromDirectFold_eq_rowActivity snapshot coordinate]

/--
Coordinates outside Snapshot.rows remain absent from the seedless global map.
-/
theorem seedlessRowActivity?_of_unrepresented
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hUnrepresented : coordinate ∉ snapshot.rows) :
    seedlessRowActivity? snapshot coordinate = none := by
  have hSupport :
      snapshot.columns.any (representedInColumn coordinate) = false := by
    rw [selected_support_eq_row_membership]
    simp [hUnrepresented]
  unfold seedlessRowActivity? buildSeedlessRowIndex
  rw [foldColumns_get?]
  simp only [Std.HashMap.get?_eq_getElem?, Std.HashMap.getElem?_empty]
  rw [optionFold_none_eq_direct_if_represented]
  rw [hSupport]
  rfl

/--
The seedless one-pass builder is pointwise extensionally equal to Observation
327's semantic RowIndex specification for every Snapshot and EffectCoordinate.

Unlike Observation 328, no precomputed Snapshot.rows seed map is needed.
-/
theorem seedlessRowActivity?_eq_spec
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    seedlessRowActivity? snapshot coordinate =
      (Loam.Observation327.buildSnapshotRowIndex snapshot).get?
        (Loam.Observation325.coordinateKey coordinate) := by
  by_cases hRepresented : coordinate ∈ snapshot.rows
  · rw [seedlessRowActivity?_of_represented
      snapshot coordinate hRepresented]
    rw [Loam.Observation327.buildSnapshotRowIndex_get?_of_represented
      snapshot coordinate hRepresented]
  · rw [seedlessRowActivity?_of_unrepresented
      snapshot coordinate hRepresented]
    rw [Loam.Observation327.buildSnapshotRowIndex_get?_of_unrepresented
      snapshot coordinate hRepresented]

/-!
## Finding

The pre-seeded Snapshot.rows pass is not required to construct the qualified
global RowActivity summary.

For every Snapshot and EffectCoordinate, an empty-start builder can:

    selected Columns
      -> Event-local CellIndex
      -> iterate each CellIndex key exactly once
      -> first key occurrence inserts zeroState and applies the cell
      -> later occurrences update the existing state
      -> final CoordinateKey -> RowActivity

and the resulting lookup is pointwise extensionally equal to Observation 327's
semantic RowIndex specification.

The important zero-cancellation boundary survives:

- CellIndex key presence follows raw coordinate occurrence;
- updateKey always inserts a visited CellIndex key;
- therefore a represented coordinate whose Event-local summed quantity is zero
  remains present globally with zero activity until later Events change it.

This removes two research-only repeated-work structures from Observation 328:

1. the separate list-membership Event-coordinate dedup;
2. the precomputed Snapshot.rows zero-seeding pass.

The remaining ordered row presentation can be derived separately:

    seedless RowIndex support
      -> keys
      -> coordinate reconstruction / ordering
      -> presentation

or current Snapshot.rows can remain as the ordered compatibility view while the
summary is built independently.

This theorem qualifies semantic shape only. It does not yet establish that a
production implementation is faster on realistic workloads.

The next step is therefore empirical:

1. construct a production-shaped candidate behind a benchmark-only boundary;
2. compare current repeated row scans with one seedless sparse-summary build on
   high-row/high-column synthetic Transactions-Flow workloads;
3. promote nothing unless same-runner paired measurements show a material gain.

No production optimization is authorized by this observation.
-/

end Loam.Observation331
