import Loam.Observations.Observation325
import Loam.Observations.Observation326
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas

namespace Loam.Observation327

open Loam.Core

set_option autoImplicit false

/-!
# Observation 327 — Global row-summary map specification

Observations 325–326 established that a concrete per-Event sparse cell HashMap
preserves cell lookup, row activity, row total, and contributor identity.

This observation defines the global coordinate -> RowActivity HashMap as a
research specification.

It deliberately does not claim an optimal construction algorithm. The map is
built from the already-derived represented row list and the proven
sparse-cell-based row activity. That makes it a clean semantic target for any
later one-pass builder.

The important representation law is that row-key presence follows represented
coordinate presence, not nonzero numeric activity. A represented zero row must
remain represented.
-/

private abbrev RowIndex :=
  Std.HashMap Loam.Observation325.CoordinateKey
    Loam.TransactionsFlowReview.RowActivity

private def buildRowIndex
    (snapshot : Loam.TransactionsFlowReview.Snapshot) :
    List EffectCoordinate → RowIndex
  | [] => {}
  | coordinate :: rest =>
      (buildRowIndex snapshot rest).insert
        (Loam.Observation325.coordinateKey coordinate)
        (Loam.Observation326.indexedRowActivity snapshot coordinate)

/--
For a coordinate represented in the supplied row-key list, global HashMap lookup
returns exactly the production RowActivity answer.
-/
theorem buildRowIndex_get?_of_mem
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (rows : List EffectCoordinate)
    (coordinate : EffectCoordinate)
    (hMem : coordinate ∈ rows) :
    (buildRowIndex snapshot rows).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some (Loam.TransactionsFlowReview.rowActivity snapshot coordinate) := by
  induction rows with
  | nil =>
      simp at hMem
  | cons row rest ih =>
      simp only [buildRowIndex]
      rw [Std.HashMap.get?_insert]
      by_cases hEq : row = coordinate
      · subst row
        simp [Loam.Observation326.indexedRowActivity_eq_rowActivity]
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

/--
Coordinates absent from the supplied represented-row list are absent from the
global RowActivity map, independent of numeric zero.
-/
theorem buildRowIndex_get?_of_not_mem
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (rows : List EffectCoordinate)
    (coordinate : EffectCoordinate)
    (hNotMem : coordinate ∉ rows) :
    (buildRowIndex snapshot rows).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  induction rows with
  | nil =>
      simp [buildRowIndex]
  | cons row rest ih =>
      have hHead : row ≠ coordinate := by
        intro h
        apply hNotMem
        simp [h]
      have hRest : coordinate ∉ rest := by
        intro h
        apply hNotMem
        simp [h]
      simp only [buildRowIndex]
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

/--
Research specification map for the complete represented Transactions-Flow row
set.
-/
def buildSnapshotRowIndex
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : RowIndex :=
  buildRowIndex snapshot snapshot.rows

/--
Every represented Transactions-Flow row has exactly the production RowActivity
value in the global summary map.
-/
theorem buildSnapshotRowIndex_get?_of_represented
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hRepresented : coordinate ∈ snapshot.rows) :
    (buildSnapshotRowIndex snapshot).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some (Loam.TransactionsFlowReview.rowActivity snapshot coordinate) := by
  exact buildRowIndex_get?_of_mem
    snapshot snapshot.rows coordinate hRepresented

/--
No unrepresented coordinate is invented by the global summary map.
-/
theorem buildSnapshotRowIndex_get?_of_unrepresented
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hUnrepresented : coordinate ∉ snapshot.rows) :
    (buildSnapshotRowIndex snapshot).get?
        (Loam.Observation325.coordinateKey coordinate) = none := by
  exact buildRowIndex_get?_of_not_mem
    snapshot snapshot.rows coordinate hUnrepresented

/--
A represented coordinate remains a row-map key even when its production
activity is exactly zero.
-/
theorem represented_zero_activity_key_is_retained
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate)
    (hRepresented : coordinate ∈ snapshot.rows)
    (hZero :
      Loam.TransactionsFlowReview.rowActivity snapshot coordinate =
        { positive := Quantity.ofQuanta 0
          negative := Quantity.ofQuanta 0
          activeEvents := 0 }) :
    (buildSnapshotRowIndex snapshot).get?
        (Loam.Observation325.coordinateKey coordinate) =
      some {
        positive := Quantity.ofQuanta 0
        negative := Quantity.ofQuanta 0
        activeEvents := 0
      } := by
  rw [buildSnapshotRowIndex_get?_of_represented
    snapshot coordinate hRepresented]
  rw [hZero]

/-!
## Finding

Transactions-Flow now has a complete research specification ladder:

    selected Columns / raw Effect evidence
        |
        v
    per-Event sparse CellIndex
        EventId -> (CoordinateKey -> Int)
        [general cell correspondence]
        |
        v
    sparse-cell-derived RowActivity
        [general rowActivity / rowTotal / contributor correspondence]
        |
        v
    global RowIndex
        CoordinateKey -> RowActivity
        [general represented-key/value correspondence]

The RowIndex deliberately retains represented zero-activity rows because key
presence is driven by Snapshot.rows, not by nonzero activity.

This is the semantic target a later faster one-pass row-summary builder would
need to match.

The remaining performance question is no longer "what should the map mean?"
It is narrower:

> Can a one-pass builder over selected Columns construct the same RowIndex
> without first recomputing each row activity separately?

That is an algorithm-refinement question. No production code or authority is
changed here.
-/

end Loam.Observation327
