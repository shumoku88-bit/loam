import Loam.Observations.Observation321
import Loam.Observations.Observation325

namespace Loam.Observation326

open Loam.Core

set_option autoImplicit false

/-!
# Observation 326 — Sparse cell index lifts to row activity

Observation 325 established a concrete Event-local HashMap whose lookup is
extensionally equal to Event.quantityAt.

This observation asks whether Transactions-Flow's higher native quantity views
can be computed through that sparse cell index without changing meaning.

The global coordinate -> RowActivity preaggregation is still deliberately
separate. This observation proves only that replacing each direct Event
coordinate projection by the concrete sparse-cell lookup is semantics-preserving
for arbitrary Snapshots.
-/

private def indexedSelectedQuanta
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) : Int :=
  ((Loam.Observation325.buildCellIndex column.event.effects).get?
    (Loam.Observation325.coordinateKey coordinate)).getD 0

private def directSelectedQuanta
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) : Int :=
  (Event.quantityAt
    column.event coordinate.locus coordinate.measure).quanta

theorem indexedSelectedQuanta_eq_direct
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) :
    indexedSelectedQuanta coordinate column =
      directSelectedQuanta coordinate column := by
  exact
    Loam.Observation325.buildCellIndex_getD_eq_quantityAt
      column.event coordinate

private def indexedActivityStep
    (coordinate : EffectCoordinate)
    (state : Int × Int × Nat)
    (column : Loam.TransactionsFlowReview.Column) : Int × Int × Nat :=
  let quantity := indexedSelectedQuanta coordinate column
  if quantity > 0 then
    (state.1 + quantity, state.2.1, state.2.2 + 1)
  else if quantity < 0 then
    (state.1, state.2.1 + quantity, state.2.2 + 1)
  else
    state

private def directActivityStep
    (coordinate : EffectCoordinate)
    (state : Int × Int × Nat)
    (column : Loam.TransactionsFlowReview.Column) : Int × Int × Nat :=
  let quantity := directSelectedQuanta coordinate column
  if quantity > 0 then
    (state.1 + quantity, state.2.1, state.2.2 + 1)
  else if quantity < 0 then
    (state.1, state.2.1 + quantity, state.2.2 + 1)
  else
    state

private theorem indexedActivityStep_eq_direct
    (coordinate : EffectCoordinate)
    (state : Int × Int × Nat)
    (column : Loam.TransactionsFlowReview.Column) :
    indexedActivityStep coordinate state column =
      directActivityStep coordinate state column := by
  unfold indexedActivityStep directActivityStep
  rw [indexedSelectedQuanta_eq_direct]

private theorem indexedActivityFold_eq_direct
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate)
    (state : Int × Int × Nat) :
    columns.foldl (indexedActivityStep coordinate) state =
      columns.foldl (directActivityStep coordinate) state := by
  induction columns generalizing state with
  | nil =>
      rfl
  | cons column rest ih =>
      simp only [List.foldl_cons]
      rw [indexedActivityStep_eq_direct]
      exact ih _

private def activityFromState
    (state : Int × Int × Nat) :
    Loam.TransactionsFlowReview.RowActivity :=
  {
    positive := Quantity.ofQuanta state.1
    negative := Quantity.ofQuanta state.2.1
    activeEvents := state.2.2
  }

/--
Transactions-Flow row activity computed through the concrete sparse cell index.
-/
def indexedRowActivity
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    Loam.TransactionsFlowReview.RowActivity :=
  activityFromState <|
    snapshot.columns.foldl
      (indexedActivityStep coordinate)
      (0, 0, 0)

/--
For arbitrary Snapshots and coordinates, sparse-cell-based row activity is
exactly the production direct-projection answer.
-/
theorem indexedRowActivity_eq_rowActivity
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    indexedRowActivity snapshot coordinate =
      Loam.TransactionsFlowReview.rowActivity snapshot coordinate := by
  change
    activityFromState
        (snapshot.columns.foldl
          (indexedActivityStep coordinate) (0, 0, 0)) =
      activityFromState
        (snapshot.columns.foldl
          (directActivityStep coordinate) (0, 0, 0))
  rw [indexedActivityFold_eq_direct]

/--
The sparse-cell route therefore also reconstructs the existing rowTotal via the
already-proved rowActivity.net law.
-/
theorem indexedRowActivity_net_eq_rowTotal
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    (indexedRowActivity snapshot coordinate).net =
      Loam.TransactionsFlowReview.rowTotal snapshot coordinate := by
  rw [indexedRowActivity_eq_rowActivity]
  symm
  exact
    Loam.Observation321.rowTotal_eq_rowActivity_net
      snapshot coordinate

/-! ## Contributor identity -/

private def indexedContribution?
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) : Option EventId :=
  if indexedSelectedQuanta coordinate column = 0 then
    none
  else
    some column.event.id

private def directContribution?
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) : Option EventId :=
  if directSelectedQuanta coordinate column = 0 then
    none
  else
    some column.event.id

private theorem indexedContribution?_eq_direct
    (coordinate : EffectCoordinate)
    (column : Loam.TransactionsFlowReview.Column) :
    indexedContribution? coordinate column =
      directContribution? coordinate column := by
  unfold indexedContribution? directContribution?
  rw [indexedSelectedQuanta_eq_direct]

def indexedContributorIds
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) : List EventId :=
  snapshot.columns.filterMap (indexedContribution? coordinate)

def directContributorIds
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) : List EventId :=
  snapshot.columns.filterMap (directContribution? coordinate)

/--
Focused contributor identity is also preserved by the sparse-cell
representation for arbitrary Snapshots.
-/
private theorem filterMap_indexed_eq_direct
    (columns : List Loam.TransactionsFlowReview.Column)
    (coordinate : EffectCoordinate) :
    columns.filterMap (indexedContribution? coordinate) =
      columns.filterMap (directContribution? coordinate) := by
  induction columns with
  | nil =>
      rfl
  | cons column rest ih =>
      simp only [List.filterMap_cons]
      rw [indexedContribution?_eq_direct]
      exact congrArg
        (fun tail =>
          match directContribution? coordinate column with
          | some eventId => eventId :: tail
          | none => tail)
        ih

theorem indexedContributorIds_eq_direct
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) :
    indexedContributorIds snapshot coordinate =
      directContributorIds snapshot coordinate := by
  unfold indexedContributorIds directContributorIds
  exact filterMap_indexed_eq_direct snapshot.columns coordinate

/-!
## Finding

The concrete Event-local sparse HashMap now preserves, generally:

    cellAt
    rowActivity
    rowTotal
    focused contributing Event identity

The represented-row coordinate set remains intentionally separate because
Snapshot.rows observes raw coordinate occurrence, including coordinates whose
Event-local cell sum is zero. Observation 325 already proves that the cell map
retains those keys, but a global row-summary index still needs its own
construction/lookup theorem.

This narrows the remaining Transactions-Flow representation question to one
specific optimization layer:

    selected Columns
      -> per-Event sparse CellIndex       [general correspondence proved]
      -> global coordinate RowSummary map [not yet proved]

No production code or authority is changed.
-/

end Loam.Observation326
