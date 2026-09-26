import Loam.Observations.Observation325
import Loam.Observations.Observation327
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas

namespace Loam.Observation328

open Loam.Core

set_option autoImplicit false

/-!
# Observation 328 — One-pass Transactions-Flow RowIndex refinement

Observation 327 fixed the semantic target for a global
CoordinateKey -> RowActivity map.

This observation builds the same observation incrementally:

1. seed exactly Snapshot.rows with zero activity state;
2. scan selected Columns once from left to right;
3. inside each Column, aggregate raw Effects first with Observation 325's
   Event-local CellIndex;
4. update each coordinate represented by that Event exactly once.

The row builder never inserts a coordinate that was not seeded from
Snapshot.rows. Therefore represented zero rows remain represented and no new row
authority is invented.

The local coordinate-dedup list is deliberately simple research mechanics. This
observation qualifies the one-pass refinement law, not a final performance
implementation.
-/

private abbrev CoordinateKey := Loam.Observation325.CoordinateKey
private abbrev ActivityState := Int × Int × Nat
private abbrev FastRowIndex := Std.HashMap CoordinateKey ActivityState

private def zeroState : ActivityState := (0, 0, 0)

private def advanceState (state : ActivityState) (quantity : Int) : ActivityState :=
  if quantity > 0 then
    (state.1 + quantity, state.2.1, state.2.2 + 1)
  else if quantity < 0 then
    (state.1, state.2.1 + quantity, state.2.2 + 1)
  else
    state

private def activityFromState
    (state : ActivityState) : Loam.TransactionsFlowReview.RowActivity :=
  {
    positive := Quantity.ofQuanta state.1
    negative := Quantity.ofQuanta state.2.1
    activeEvents := state.2.2
  }

/-! ## Event-local represented coordinate set -/

/--
Tail-first dedup keeps one exact EffectCoordinate for every coordinate appearing
in raw Event evidence. Order is research representation only.
-/
private def eventCoordinates : List Effect → List EffectCoordinate
  | [] => []
  | effect :: rest =>
      let coordinates := eventCoordinates rest
      if effect.coordinate ∈ coordinates then
        coordinates
      else
        effect.coordinate :: coordinates

private theorem eventCoordinates_nodup
    (effects : List Effect) :
    (eventCoordinates effects).Nodup := by
  induction effects with
  | nil =>
      simp [eventCoordinates]
  | cons effect rest ih =>
      simp only [eventCoordinates]
      by_cases hMem : effect.coordinate ∈ eventCoordinates rest
      · simp [hMem, ih]
      · simp [hMem, ih]

private theorem mem_eventCoordinates_iff
    (effects : List Effect)
    (coordinate : EffectCoordinate) :
    coordinate ∈ eventCoordinates effects ↔
      ∃ effect ∈ effects, effect.coordinate = coordinate := by
  induction effects with
  | nil =>
      simp [eventCoordinates]
  | cons effect rest ih =>
      simp only [eventCoordinates]
      by_cases hMem : effect.coordinate ∈ eventCoordinates rest
      · have hWitness :
            ∃ later ∈ rest, later.coordinate = effect.coordinate :=
          (ih effect.coordinate).mp hMem
        constructor
        · intro hCoordinate
          have hRest :
              ∃ later ∈ rest, later.coordinate = coordinate :=
            (ih coordinate).mp hCoordinate
          exact ⟨hRest.1, by simp [hRest.2.1], hRest.2.2⟩
        · intro hExists
          rcases hExists with ⟨candidate, hCandidate, hEq⟩
          simp only [List.mem_cons] at hCandidate
          rcases hCandidate with rfl | hLater
          · exact (ih effect.coordinate).mpr hWitness
          · exact (ih coordinate).mpr ⟨candidate, hLater, hEq⟩
      · constructor
        · intro hCoordinate
          simp only [List.mem_cons] at hCoordinate
          rcases hCoordinate with hHead | hRest
          · exact ⟨effect, by simp, hHead⟩
          · have hExists := (ih coordinate).mp hRest
            exact ⟨hExists.1, by simp [hExists.2.1], hExists.2.2⟩
        · intro hExists
          rcases hExists with ⟨candidate, hCandidate, hEq⟩
          simp only [List.mem_cons] at hCandidate
          rcases hCandidate with rfl | hLater
          · simp [hEq]
          · have hRest :
                coordinate ∈ eventCoordinates rest :=
              (ih coordinate).mpr ⟨candidate, hLater, hEq⟩
            simp [hRest]

private def directQuanta
    (event : Event)
    (coordinate : EffectCoordinate) : Int :=
  (Event.quantityAt
    event coordinate.locus coordinate.measure).quanta

private theorem directQuanta_zero_of_not_mem
    (event : Event)
    (coordinate : EffectCoordinate)
    (hNotMem : coordinate ∉ eventCoordinates event.effects) :
    directQuanta event coordinate = 0 := by
  have hNoWitness :
      ¬ ∃ effect ∈ event.effects, effect.coordinate = coordinate := by
    intro h
    exact hNotMem ((mem_eventCoordinates_iff event.effects coordinate).mpr h)
  unfold directQuanta Event.quantityAt
  induction event.effects with
  | nil =>
      rfl
  | cons effect rest ih =>
      have hEffect : effect.coordinate ≠ coordinate := by
        intro hEq
        apply hNoWitness
        exact ⟨effect, by simp, hEq⟩
      have hRestNo :
          ¬ ∃ later ∈ rest, later.coordinate = coordinate := by
        intro h
        apply hNoWitness
        exact ⟨h.1, by simp [h.2.1], h.2.2⟩
      simp [hEffect]
      apply ih
      exact hRestNo

/-! ## Seed exactly the represented row set -/

private def seedRows : List EffectCoordinate → FastRowIndex
  | [] => {}
  | coordinate :: rest =>
      (seedRows rest).insert
        (Loam.Observation325.coordinateKey coordinate)
        zeroState

private theorem seedRows_get?_of_mem
    (rows : List EffectCoordinate)
    (coordinate : EffectCoordinate)
    (hMem : coordinate ∈ rows) :
    (seedRows rows).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some zeroState := by
  induction rows with
  | nil =>
      simp at hMem
  | cons row rest ih =>
      simp only [seedRows]
      rw [Std.HashMap.get?_insert]
      by_cases hEq : row = coordinate
      · subst row
        simp
      · have hRest : coordinate ∈ rest := by
          simp only [List.mem_cons] at hMem
          rcases hMem with hHead | hTail
          · exact False.elim (hEq hHead.symm)
          · exact hTail
        have hKey :
            Loam.Observation325.coordinateKey row ≠
              Loam.Observation325.coordinateKey coordinate := by
          intro h
          exact hEq (Loam.Observation325.coordinateKey_injective h)
        have hBeq :
            (Loam.Observation325.coordinateKey row ==
              Loam.Observation325.coordinateKey coordinate) = false := by
          cases h :
              (Loam.Observation325.coordinateKey row ==
                Loam.Observation325.coordinateKey coordinate) with
          | false => rfl
          | true =>
              have hSame :
                  Loam.Observation325.coordinateKey row =
                    Loam.Observation325.coordinateKey coordinate :=
                eq_of_beq h
              exact False.elim (hKey hSame)
        rw [hBeq]
        exact ih hRest

private theorem seedRows_get?_of_not_mem
    (rows : List EffectCoordinate)
    (coordinate : EffectCoordinate)
    (hNotMem : coordinate ∉ rows) :
    (seedRows rows).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  induction rows with
  | nil =>
      simp [seedRows]
  | cons row rest ih =>
      have hHead : row ≠ coordinate := by
        intro h
        apply hNotMem
        simp [h]
      have hRest : coordinate ∉ rest := by
        intro h
        apply hNotMem
        simp [h]
      simp only [seedRows]
      rw [Std.HashMap.get?_insert]
      have hKey :
          Loam.Observation325.coordinateKey row ≠
            Loam.Observation325.coordinateKey coordinate := by
        intro h
        exact hHead (Loam.Observation325.coordinateKey_injective h)
      have hBeq :
          (Loam.Observation325.coordinateKey row ==
            Loam.Observation325.coordinateKey coordinate) = false := by
        cases h :
            (Loam.Observation325.coordinateKey row ==
              Loam.Observation325.coordinateKey coordinate) with
        | false => rfl
        | true =>
            have hSame :
                Loam.Observation325.coordinateKey row =
                  Loam.Observation325.coordinateKey coordinate :=
              eq_of_beq h
            exact False.elim (hKey hSame)
      rw [hBeq]
      exact ih hRest

/-! ## One Event update -/

/--
Update one row only if Snapshot.rows seeded that key.

This prevents the transient builder from manufacturing a coordinate outside the
already-derived represented row set.
-/
private def updateCoordinate
    (cells : Loam.Observation325.CellIndex)
    (index : FastRowIndex)
    (coordinate : EffectCoordinate) : FastRowIndex :=
  let key := Loam.Observation325.coordinateKey coordinate
  match index.get? key with
  | none => index
  | some state =>
      let quantity := (cells.get? key).getD 0
      index.insert key (advanceState state quantity)

private theorem updateCoordinate_same
    (cells : Loam.Observation325.CellIndex)
    (index : FastRowIndex)
    (coordinate : EffectCoordinate)
    (state : ActivityState)
    (hGet :
      index.get? (Loam.Observation325.coordinateKey coordinate) =
        some state) :
    (updateCoordinate cells index coordinate).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some
        (advanceState state
          ((cells.get?
            (Loam.Observation325.coordinateKey coordinate)).getD 0)) := by
  simp [updateCoordinate, hGet]

private theorem updateCoordinate_other
    (cells : Loam.Observation325.CellIndex)
    (index : FastRowIndex)
    (row coordinate : EffectCoordinate)
    (hNe : row ≠ coordinate) :
    (updateCoordinate cells index row).get?
        (Loam.Observation325.coordinateKey coordinate) =
      index.get? (Loam.Observation325.coordinateKey coordinate) := by
  unfold updateCoordinate
  cases hRow :
      index.get? (Loam.Observation325.coordinateKey row) with
  | none =>
      simp [hRow]
  | some state =>
      simp only [hRow]
      rw [Std.HashMap.get?_insert]
      have hKey :
          Loam.Observation325.coordinateKey row ≠
            Loam.Observation325.coordinateKey coordinate := by
        intro h
        exact hNe (Loam.Observation325.coordinateKey_injective h)
      have hBeq :
          (Loam.Observation325.coordinateKey row ==
            Loam.Observation325.coordinateKey coordinate) = false := by
        cases h :
            (Loam.Observation325.coordinateKey row ==
              Loam.Observation325.coordinateKey coordinate) with
        | false => rfl
        | true =>
            have hSame :
                Loam.Observation325.coordinateKey row =
                  Loam.Observation325.coordinateKey coordinate :=
              eq_of_beq h
            exact False.elim (hKey hSame)
      rw [hBeq]

private theorem updateCoordinate_preserves_none
    (cells : Loam.Observation325.CellIndex)
    (index : FastRowIndex)
    (row coordinate : EffectCoordinate)
    (hNone :
      index.get? (Loam.Observation325.coordinateKey coordinate) = none) :
    (updateCoordinate cells index row).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  by_cases hEq : row = coordinate
  · subst row
    simp [updateCoordinate, hNone]
  · rw [updateCoordinate_other cells index row coordinate hEq]
    exact hNone

private def updateCoordinates
    (cells : Loam.Observation325.CellIndex)
    (coordinates : List EffectCoordinate)
    (index : FastRowIndex) : FastRowIndex :=
  coordinates.foldl (updateCoordinate cells) index

private theorem updateCoordinates_preserves_none
    (cells : Loam.Observation325.CellIndex)
    (coordinates : List EffectCoordinate)
    (index : FastRowIndex)
    (coordinate : EffectCoordinate)
    (hNone :
      index.get? (Loam.Observation325.coordinateKey coordinate) = none) :
    (updateCoordinates cells coordinates index).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  induction coordinates generalizing index with
  | nil =>
      exact hNone
  | cons row rest ih =>
      simp only [updateCoordinates, List.foldl_cons]
      apply ih
      exact updateCoordinate_preserves_none
        cells index row coordinate hNone

private theorem updateCoordinates_not_mem
    (cells : Loam.Observation325.CellIndex)
    (coordinates : List EffectCoordinate)
    (index : FastRowIndex)
    (coordinate : EffectCoordinate)
    (hNotMem : coordinate ∉ coordinates) :
    (updateCoordinates cells coordinates index).get?
        (Loam.Observation325.coordinateKey coordinate) =
      index.get? (Loam.Observation325.coordinateKey coordinate) := by
  induction coordinates generalizing index with
  | nil =>
      rfl
  | cons row rest ih =>
      have hHead : row ≠ coordinate := by
        intro h
        apply hNotMem
        simp [h]
      have hRest : coordinate ∉ rest := by
        intro h
        apply hNotMem
        simp [h]
      simp only [updateCoordinates, List.foldl_cons]
      rw [ih (updateCoordinate cells index row) hRest]
      exact updateCoordinate_other cells index row coordinate hHead

private theorem updateCoordinates_mem
    (cells : Loam.Observation325.CellIndex)
    (coordinates : List EffectCoordinate)
    (index : FastRowIndex)
    (coordinate : EffectCoordinate)
    (state : ActivityState)
    (hNodup : coordinates.Nodup)
    (hMem : coordinate ∈ coordinates)
    (hGet :
      index.get? (Loam.Observation325.coordinateKey coordinate) =
        some state) :
    (updateCoordinates cells coordinates index).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some
        (advanceState state
          ((cells.get?
            (Loam.Observation325.coordinateKey coordinate)).getD 0)) := by
  induction coordinates generalizing index state with
  | nil =>
      simp at hMem
  | cons row rest ih =>
      simp only [List.nodup_cons] at hNodup
      simp only [List.mem_cons] at hMem
      simp only [updateCoordinates, List.foldl_cons]
      rcases hMem with hHead | hTail
      · subst row
        have hAfter :=
          updateCoordinate_same cells index coordinate state hGet
        rw [updateCoordinates_not_mem
          cells rest (updateCoordinate cells index coordinate)
          coordinate hNodup.1]
        exact hAfter
      · have hNe : row ≠ coordinate := by
          intro h
          subst row
          exact hNodup.1 hTail
        have hOther :=
          updateCoordinate_other cells index row coordinate hNe
        apply ih (updateCoordinate cells index row) state hNodup.2 hTail
        rw [hOther]
        exact hGet

private def updateColumn
    (index : FastRowIndex)
    (column : Loam.TransactionsFlowReview.Column) : FastRowIndex :=
  let cells := Loam.Observation325.buildCellIndex column.event.effects
  updateCoordinates cells (eventCoordinates column.event.effects) index

/--
One Column transforms an already-present target row exactly like the production
rowActivity accumulator step.
-/
private theorem updateColumn_get?
    (index : FastRowIndex)
    (column : Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (state : ActivityState)
    (hGet :
      index.get? (Loam.Observation325.coordinateKey coordinate) =
        some state) :
    (updateColumn index column).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some (advanceState state (directQuanta column.event coordinate)) := by
  unfold updateColumn
  by_cases hMem : coordinate ∈ eventCoordinates column.event.effects
  · have hUpdate :=
      updateCoordinates_mem
        (Loam.Observation325.buildCellIndex column.event.effects)
        (eventCoordinates column.event.effects)
        index coordinate state
        (eventCoordinates_nodup column.event.effects)
        hMem hGet
    rw [Loam.Observation325.buildCellIndex_getD_eq_quantityAt] at hUpdate
    exact hUpdate
  · have hUpdate :=
      updateCoordinates_not_mem
        (Loam.Observation325.buildCellIndex column.event.effects)
        (eventCoordinates column.event.effects)
        index coordinate hMem
    rw [hUpdate, hGet]
    have hZero :=
      directQuanta_zero_of_not_mem column.event coordinate hMem
    simp [hZero, advanceState]

private theorem updateColumn_preserves_none
    (index : FastRowIndex)
    (column : Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (hNone :
      index.get? (Loam.Observation325.coordinateKey coordinate) = none) :
    (updateColumn index column).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  unfold updateColumn
  exact updateCoordinates_preserves_none
    (Loam.Observation325.buildCellIndex column.event.effects)
    (eventCoordinates column.event.effects)
    index coordinate hNone

/-! ## Whole selected-column scan -/

private def directStep
    (coordinate : EffectCoordinate)
    (state : ActivityState)
    (column : Loam.TransactionsFlowReview.Column) : ActivityState :=
  advanceState state (directQuanta column.event coordinate)

private def buildFastRowIndex
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : FastRowIndex :=
  snapshot.columns.foldl updateColumn (seedRows snapshot.rows)

private theorem foldColumns_get?
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (index : FastRowIndex)
    (state : ActivityState)
    (hGet :
      index.get? (Loam.Observation325.coordinateKey coordinate) =
        some state) :
    (columns.foldl updateColumn index).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some (columns.foldl (directStep coordinate) state) := by
  induction columns generalizing index state with
  | nil =>
      exact hGet
  | cons column rest ih =>
      simp only [List.foldl_cons]
      apply ih
      exact updateColumn_get? index column coordinate state hGet

private theorem foldColumns_preserves_none
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (index : FastRowIndex)
    (hNone :
      index.get? (Loam.Observation325.coordinateKey coordinate) = none) :
    (columns.foldl updateColumn index).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  induction columns generalizing index with
  | nil =>
      exact hNone
  | cons column rest ih =>
      simp only [List.foldl_cons]
      apply ih
      exact updateColumn_preserves_none index column coordinate hNone

private def fastRowActivity?
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    Option Loam.TransactionsFlowReview.RowActivity :=
  ((buildFastRowIndex snapshot).get?
      (Loam.Observation325.coordinateKey coordinate)).map activityFromState

private theorem activityFromDirectFold_eq_rowActivity
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    activityFromState
        (snapshot.columns.foldl (directStep coordinate) zeroState) =
      Loam.TransactionsFlowReview.rowActivity snapshot coordinate := by
  rfl

/--
Every represented row produced by the one-pass builder has exactly production
RowActivity meaning.
-/
theorem fastRowActivity?_of_represented
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hRepresented : coordinate ∈ snapshot.rows) :
    fastRowActivity? snapshot coordinate =
      some (Loam.TransactionsFlowReview.rowActivity snapshot coordinate) := by
  have hSeed :=
    seedRows_get?_of_mem snapshot.rows coordinate hRepresented
  have hFold :=
    foldColumns_get?
      snapshot.columns coordinate
      (seedRows snapshot.rows) zeroState hSeed
  unfold fastRowActivity? buildFastRowIndex
  rw [hFold]
  simp [activityFromDirectFold_eq_rowActivity snapshot coordinate]

/--
Unrepresented rows remain absent because the one-pass updater never inserts a
missing seed key.
-/
theorem fastRowActivity?_of_unrepresented
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hUnrepresented : coordinate ∉ snapshot.rows) :
    fastRowActivity? snapshot coordinate = none := by
  have hSeed :=
    seedRows_get?_of_not_mem snapshot.rows coordinate hUnrepresented
  have hFold :=
    foldColumns_preserves_none
      snapshot.columns coordinate (seedRows snapshot.rows) hSeed
  unfold fastRowActivity? buildFastRowIndex
  rw [hFold]
  rfl

/--
The incremental one-pass builder is pointwise extensionally equal to
Observation 327's semantic RowIndex specification for every Snapshot and
EffectCoordinate.
-/
theorem fastRowActivity?_eq_spec
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    fastRowActivity? snapshot coordinate =
      (Loam.Observation327.buildSnapshotRowIndex snapshot).get?
        (Loam.Observation325.coordinateKey coordinate) := by
  by_cases hRepresented : coordinate ∈ snapshot.rows
  · rw [fastRowActivity?_of_represented
      snapshot coordinate hRepresented]
    rw [Loam.Observation327.buildSnapshotRowIndex_get?_of_represented
      snapshot coordinate hRepresented]
  · rw [fastRowActivity?_of_unrepresented
      snapshot coordinate hRepresented]
    rw [Loam.Observation327.buildSnapshotRowIndex_get?_of_unrepresented
      snapshot coordinate hRepresented]

/-!
## Finding

A one-pass selected-Column builder can refine the already-qualified RowIndex
meaning.

Its shape is:

    Snapshot.rows
      -> seed exactly represented keys with zero state

    selected Columns (one left-to-right fold)
      -> Event-local CellIndex
      -> each Event coordinate exactly once
      -> update only pre-seeded global rows

    final FastRowIndex
      -> RowActivity view

For every Snapshot and EffectCoordinate, the resulting RowActivity lookup is
pointwise equal to Observation 327's semantic RowIndex specification.

This preserves:

- represented zero rows;
- no invented row keys;
- Event-local aggregation before sign classification;
- positive/negative partitions;
- active Event count;
- arbitrary Snapshot column multiplicity, including duplicate EventIds.

The proof does not claim the local research dedup list is the final fastest
implementation. It establishes the algorithm-refinement boundary:

    future optimized one-pass builder
        need only preserve this qualified lookup law

rather than re-proving Transactions-Flow semantics from raw evidence.

No production code or authority is changed.
-/

end Loam.Observation328
