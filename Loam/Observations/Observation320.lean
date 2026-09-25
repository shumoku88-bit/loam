import Loam.TransactionsFlowReview

namespace Loam.Observation320

open Loam.Core

set_option autoImplicit false

/-!
# Observation 320 — Transactions-Flow sparse-summary correspondence probe

RF-1 asks whether the native quantity observations of
`TransactionsFlowReview` can factor through a transient sparse image while the
selected Columns remain the evidence-bearing review image.

This observation deliberately does not modify production.

The candidate has two stages:

1. aggregate raw Effects inside each Event by exact EffectCoordinate;
2. aggregate those Event-coordinate cells into per-coordinate row activity.

The first stage is essential. Classifying raw Effects by sign before
same-Event/same-coordinate aggregation would change `activeEvents` and the
positive/negative partitions when raw Effects cancel inside one Event.

The finite witness below includes:

- exact same-coordinate cancellation inside one Event;
- repeated same-coordinate positive Effects inside one Event;
- zero-net/high-gross activity across distinct Events;
- multiple Measures;
- a represented coordinate whose Event cell is zero.

The experiment compares the candidate to current production observations. It is
a falsification probe, not a generic sparse-matrix production API.
-/

private def jpy : MeasureId := ⟨"jpy"⟩
private def point : MeasureId := ⟨"point"⟩

private def food : LocusId := ⟨"food"⟩
private def cash : LocusId := ⟨"cash"⟩
private def smbc : LocusId := ⟨"smbc"⟩
private def rewards : LocusId := ⟨"rewards"⟩

private def foodJpy : EffectCoordinate := ⟨food, jpy⟩
private def cashJpy : EffectCoordinate := ⟨cash, jpy⟩
private def smbcJpy : EffectCoordinate := ⟨smbc, jpy⟩
private def rewardsPoint : EffectCoordinate := ⟨rewards, point⟩

private def effect
    (key : String) (locus : LocusId) (measure : MeasureId) (q : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ locus measure (Quantity.ofQuanta q)

private def cancelEvent : Event :=
  {
    id := ⟨"o320-cancel"⟩
    effects :=
      [ effect "o320-cancel-a" food jpy 100
      , effect "o320-cancel-b" food jpy (-100)
      ]
    keyNodup := by native_decide
  }

private def splitPositiveEvent : Event :=
  {
    id := ⟨"o320-split-positive"⟩
    effects :=
      [ effect "o320-split-food-a" food jpy 20
      , effect "o320-split-food-b" food jpy 30
      , effect "o320-split-cash" cash jpy (-50)
      ]
    keyNodup := by native_decide
  }

private def negativeEvent : Event :=
  {
    id := ⟨"o320-negative"⟩
    effects :=
      [ effect "o320-neg-food" food jpy (-50)
      , effect "o320-neg-smbc" smbc jpy 50
      ]
    keyNodup := by native_decide
  }

private def mixedEvent : Event :=
  {
    id := ⟨"o320-mixed"⟩
    effects :=
      [ effect "o320-mixed-cash" cash jpy (-10)
      , effect "o320-mixed-food" food jpy 10
      , effect "o320-mixed-point" rewards point 3
      ]
    keyNodup := by native_decide
  }

private def column
    (event : Event) (date : String) : Loam.TransactionsFlowReview.Column :=
  { event := event, date := date, description := event.id.token }

private def snapshot : Loam.TransactionsFlowReview.Snapshot :=
  {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    columns :=
      [ column cancelEvent "2026-09-01"
      , column splitPositiveEvent "2026-09-02"
      , column negativeEvent "2026-09-03"
      , column mixedEvent "2026-09-04"
      ]
  }

/-! ## Experiment-only sparse image -/

private structure Cell where
  coordinate : EffectCoordinate
  quanta : Int


private structure SparseColumn where
  source : Loam.TransactionsFlowReview.Column
  cells : List Cell

private structure RowSummary where
  coordinate : EffectCoordinate
  positive : Int
  negative : Int
  activeEvents : Nat

private structure SparseImage where
  columns : List SparseColumn
  rows : List RowSummary

private def addQuantityToCells
    (coordinate : EffectCoordinate) (q : Int) : List Cell → List Cell
  | [] => [{ coordinate := coordinate, quanta := q }]
  | cell :: rest =>
      if cell.coordinate = coordinate then
        { cell with quanta := cell.quanta + q } :: rest
      else
        cell :: addQuantityToCells coordinate q rest

/--
First aggregate raw Effects inside one Event. This preserves represented zero
cells instead of dropping them.
-/
private def cellsForEvent (event : Event) : List Cell :=
  event.effects.foldl
    (fun cells effect =>
      addQuantityToCells effect.coordinate effect.quantity.quanta cells)
    []

private def cellQuanta
    (cells : List Cell) (coordinate : EffectCoordinate) : Int :=
  match cells.find? fun cell => decide (cell.coordinate = coordinate) with
  | some cell => cell.quanta
  | none => 0

private def rowOfCell (cell : Cell) : RowSummary :=
  if cell.quanta > 0 then
    { coordinate := cell.coordinate
      positive := cell.quanta
      negative := 0
      activeEvents := 1 }
  else if cell.quanta < 0 then
    { coordinate := cell.coordinate
      positive := 0
      negative := cell.quanta
      activeEvents := 1 }
  else
    { coordinate := cell.coordinate
      positive := 0
      negative := 0
      activeEvents := 0 }

private def addCellToRows (cell : Cell) : List RowSummary → List RowSummary
  | [] => [rowOfCell cell]
  | row :: rest =>
      if row.coordinate = cell.coordinate then
        let next :=
          if cell.quanta > 0 then
            { row with
              positive := row.positive + cell.quanta
              activeEvents := row.activeEvents + 1 }
          else if cell.quanta < 0 then
            { row with
              negative := row.negative + cell.quanta
              activeEvents := row.activeEvents + 1 }
          else
            row
        next :: rest
      else
        row :: addCellToRows cell rest

private def addColumnRows
    (rows : List RowSummary) (column : Loam.TransactionsFlowReview.Column) :
    List RowSummary :=
  (cellsForEvent column.event).foldl
    (fun rows cell => addCellToRows cell rows)
    rows

private def buildSparse
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : SparseImage :=
  {
    columns := snapshot.columns.map fun column =>
      { source := column, cells := cellsForEvent column.event }
    rows := snapshot.columns.foldl addColumnRows []
  }

private def sparse : SparseImage := buildSparse snapshot

private def findRow?
    (image : SparseImage) (coordinate : EffectCoordinate) : Option RowSummary :=
  image.rows.find? fun row => decide (row.coordinate = coordinate)

private def sparseActivity
    (image : SparseImage) (coordinate : EffectCoordinate) :
    Loam.TransactionsFlowReview.RowActivity :=
  match findRow? image coordinate with
  | none =>
      { positive := Quantity.ofQuanta 0
        negative := Quantity.ofQuanta 0
        activeEvents := 0 }
  | some row =>
      { positive := Quantity.ofQuanta row.positive
        negative := Quantity.ofQuanta row.negative
        activeEvents := row.activeEvents }

private def sparseCellAt
    (image : SparseImage)
    (coordinate : EffectCoordinate)
    (eventId : EventId) : Option Quantity := do
  let column ← image.columns.find? fun candidate =>
    decide (candidate.source.event.id = eventId)
  some (Quantity.ofQuanta (cellQuanta column.cells coordinate))

private def sparseMeasureResidual
    (column : SparseColumn) (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    column.cells.foldl
      (fun total cell =>
        if cell.coordinate.measure = measure then
          total + cell.quanta
        else
          total)
      0

private def coordinateLe
    (left right : EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def sparseRows (image : SparseImage) : List EffectCoordinate :=
  (image.rows.map (·.coordinate)).mergeSort coordinateLe

private def directContributorIds
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) : List EventId :=
  snapshot.columns.filterMap fun column =>
    let q := Event.quantityAt
      column.event coordinate.locus coordinate.measure
    if q.quanta = 0 then none else some column.event.id

private def sparseContributorIds
    (image : SparseImage)
    (coordinate : EffectCoordinate) : List EventId :=
  image.columns.filterMap fun column =>
    if cellQuanta column.cells coordinate = 0 then
      none
    else
      some column.source.event.id

/-! ## Correspondence witnesses -/

theorem represented_coordinates_correspond :
    sparseRows sparse = snapshot.rows := by
  native_decide

theorem all_selected_cells_correspond :
    snapshot.columns.all (fun column =>
      snapshot.rows.all (fun coordinate =>
        decide (
          sparseCellAt sparse coordinate column.event.id =
            Loam.TransactionsFlowReview.cellAt
              snapshot coordinate column.event.id))) = true := by
  native_decide

theorem row_activity_corresponds_on_all_represented_rows :
    snapshot.rows.all (fun coordinate =>
      decide (
        sparseActivity sparse coordinate =
          Loam.TransactionsFlowReview.rowActivity snapshot coordinate)) = true := by
  native_decide

theorem row_total_is_sparse_activity_net_on_all_represented_rows :
    snapshot.rows.all (fun coordinate =>
      decide (
        Loam.TransactionsFlowReview.rowTotal snapshot coordinate =
          (sparseActivity sparse coordinate).net)) = true := by
  native_decide

theorem focused_contributors_correspond_on_all_represented_rows :
    snapshot.rows.all (fun coordinate =>
      decide (
        sparseContributorIds sparse coordinate =
          directContributorIds snapshot coordinate)) = true := by
  native_decide

theorem measure_residuals_correspond_for_mixed_event :
    match sparse.columns.find? fun candidate =>
        decide (candidate.source.event.id = mixedEvent.id) with
    | none => False
    | some sparseMixed =>
        sparseMeasureResidual sparseMixed jpy =
            Loam.TransactionsFlowReview.measureResidual sparseMixed.source jpy ∧
        sparseMeasureResidual sparseMixed point =
            Loam.TransactionsFlowReview.measureResidual sparseMixed.source point := by
  native_decide

/-! ## Counterexample pressure -/

private def cancellationSnapshot : Loam.TransactionsFlowReview.Snapshot :=
  {
    start := "2026-09-01"
    endExclusive := "2026-09-02"
    columns := [column cancelEvent "2026-09-01"]
  }

private def cancellationSparse : SparseImage :=
  buildSparse cancellationSnapshot

/--
The coordinate remains represented even though its one Event cell cancels to
zero. A nonzero-only row-key set would lose current `Snapshot.rows` semantics.
-/
theorem exact_same_event_cancellation_remains_represented :
    cancellationSnapshot.rows = [foodJpy] ∧
    sparseRows cancellationSparse = [foodJpy] ∧
    (sparseActivity cancellationSparse foodJpy).activeEvents = 0 := by
  native_decide

/--
Raw-effect sign classification would be wrong here: the two raw Effects have
opposite signs, but the Event/coordinate cell is exactly zero.
-/
theorem same_event_cancellation_has_zero_activity :
    Loam.TransactionsFlowReview.rowActivity
        cancellationSnapshot foodJpy =
      { positive := Quantity.ofQuanta 0
        negative := Quantity.ofQuanta 0
        activeEvents := 0 } := by
  native_decide

/--
Across distinct Events, cancellation must remain visible as two-sided activity.
The split-positive Event contributes +50 after its two food Effects are first
combined; the negative Event contributes -50.
-/
theorem cross_event_zero_net_keeps_gross_activity :
    let activity := Loam.TransactionsFlowReview.rowActivity snapshot foodJpy
    activity.net.quanta = 10 ∧
    activity.positive.quanta = 60 ∧
    activity.negative.quanta = -50 ∧
    activity.gross.quanta = 110 ∧
    activity.activeEvents = 3 := by
  native_decide

/-!
## Finding

The selected witnesses did not falsify the RF-1 factorization.

For the tested boundary:

    full selected Columns
        remain required evidence

    per-Event coordinate aggregation
        preserves current cell semantics

    transient row summaries
        preserve rowTotal / rowActivity / summary contributors

The exact same-Event cancellation witness also falsifies a tempting but wrong
implementation:

    raw Effect sign buckets -> global RowActivity

because sign classification must happen only after Event-local coordinate
aggregation.

This observation does not establish a general theorem for arbitrary snapshots
and does not authorize production indexing. It qualifies the candidate shape
strongly enough to justify a later general correspondence proof attempt.
-/

end Loam.Observation320
