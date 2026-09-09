import Loam.TransactionsFlowReview

namespace Observation236

open Loam.Core

set_option autoImplicit false

/-!
Observation 236 asks a presentation question only. The production
TransactionsFlowReview already owns the read semantics. This probe tests whether
one coordinate-first sparse summary plus a focused contribution list preserves
the useful incidence evidence without rendering the mostly-zero dense matrix.
-/

structure Contribution where
  date : String
  eventId : EventId
  description : String
  quantity : Quantity
  deriving Repr, DecidableEq

structure RowView where
  coordinate : EffectCoordinate
  activity : Loam.TransactionsFlowReview.RowActivity
  contributions : List Contribution

private def coordinateLe (left right : EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

/-- Keep only Event columns that actually changed the selected coordinate. -/
def contributions
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) : List Contribution :=
  snapshot.columns.filterMap fun column =>
    let quantity := Event.quantityAt column.event coordinate.locus coordinate.measure
    if quantity.quanta = 0 then
      none
    else
      some {
        date := column.date
        eventId := column.event.id
        description := column.description
        quantity := quantity
      }

/-- One sparse row keeps summary activity and only its nonzero Event witnesses. -/
def rowView
    (snapshot : Loam.TransactionsFlowReview.Snapshot)
    (coordinate : EffectCoordinate) : RowView :=
  {
    coordinate := coordinate
    activity := Loam.TransactionsFlowReview.rowActivity snapshot coordinate
    contributions := contributions snapshot coordinate
  }

/--
Presentation salience only: larger gross activity first, then stable coordinate
spelling as a deterministic tie-break. Gross ordering is not accounting,
priority, importance, or authority semantics.
-/
private def rowViewLe (left right : RowView) : Bool :=
  if left.activity.gross.quanta == right.activity.gross.quanta then
    coordinateLe left.coordinate right.coordinate
  else
    left.activity.gross.quanta >= right.activity.gross.quanta

/-- Sparse coordinate summary for presentation. -/
def sparseRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : List RowView :=
  (snapshot.rows.map (rowView snapshot)).filter
      (fun row => row.activity.activeEvents > 0)
    |>.mergeSort rowViewLe

/-- Number of rendered contribution lines after zero cells are removed. -/
def sparseCellCount
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Nat :=
  (sparseRows snapshot).foldl (fun total row => total + row.contributions.length) 0

/-- Number of cells a literal dense coordinate × Event presentation would expose. -/
def denseCellCount
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Nat :=
  snapshot.rows.length * snapshot.columns.length

private def jpy : MeasureId := ⟨"jpy"⟩
private def cashJpy : EffectCoordinate := ⟨⟨"cash"⟩, jpy⟩
private def smbcJpy : EffectCoordinate := ⟨⟨"smbc"⟩, jpy⟩
private def bookJpy : EffectCoordinate := ⟨⟨"book"⟩, jpy⟩
private def lessonJpy : EffectCoordinate := ⟨⟨"lesson-income"⟩, jpy⟩

private def effect (key locus : String) (quantity : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ jpy (Quantity.ofQuanta quantity)

private def event? (id : String) (effects : List Effect) : Option Event :=
  Event.ofEffects? ⟨id⟩ effects

private def record
    (event : Event) (date description : String) : Loam.ActualReview.Record :=
  {
    event := event
    date := some date
    description := description
    replacement := none
    isCurrent := true
  }

private def specimen? : Option Loam.TransactionsFlowReview.Snapshot := do
  let cashIn ← event? "lesson"
    [effect "l-cash" "cash" 30000, effect "l-source" "lesson-income" (-30000)]
  let cashOut ← event? "deposit"
    [effect "d-cash" "cash" (-30000), effect "d-smbc" "smbc" 30000]
  let book ← event? "book"
    [effect "b-smbc" "smbc" (-1915), effect "b-book" "book" 1915]
  match Loam.TransactionsFlowReview.project
      [ record book "2026-09-05" "book purchase"
      , record cashOut "2026-09-06" "cash -> smbc"
      , record cashIn "2026-09-01" "lesson income"
      ]
      "2026-09-01" "2026-09-10" with
  | .error _ => none
  | .ok snapshot => some snapshot

private def cashView? : Option RowView := do
  let snapshot ← specimen?
  (sparseRows snapshot).find? fun row => row.coordinate = cashJpy

private def contributionQuanta (row : RowView) : List Int :=
  row.contributions.map fun contribution => contribution.quantity.quanta

private def contributionIds (row : RowView) : List String :=
  row.contributions.map fun contribution => contribution.eventId.token

/-- Zero-net circulation remains highly visible because gross activity is retained. -/
example : (cashView?.map fun row => row.activity.net.quanta) = some 0 := by
  native_decide

example : (cashView?.map fun row => row.activity.gross.quanta) = some 60000 := by
  native_decide

example : (cashView?.map fun row => row.activity.activeEvents) = some 2 := by
  native_decide

/-- Focus detail contains only the two nonzero Event witnesses, in occurrence order. -/
example : (cashView?.map contributionIds) = some ["lesson", "deposit"] := by
  native_decide

example : (cashView?.map contributionQuanta) = some [30000, -30000] := by
  native_decide

/-- Dense zeros are not rendered: 4 rows × 3 Events = 12 possible cells, 6 nonzero witnesses. -/
example : specimen?.map denseCellCount = some 12 := by
  native_decide

example : specimen?.map sparseCellCount = some 6 := by
  native_decide

/-- Gross salience ranks the zero-net cash circulation ahead of the smaller book activity. -/
example :
    specimen?.map (fun snapshot =>
      (sparseRows snapshot).map fun row => row.coordinate.locus.token) =
      some ["cash", "lesson-income", "smbc", "book"] := by
  native_decide

/-- The focused view is an incidence projection only; unrelated zero cells never appear. -/
example :
    specimen?.map (fun snapshot => contributions snapshot bookJpy |>.length) = some 1 := by
  native_decide

example :
    specimen?.map (fun snapshot => contributions snapshot lessonJpy |>.length) = some 1 := by
  native_decide

example :
    specimen?.map (fun snapshot =>
      Loam.TransactionsFlowReview.rowActivity snapshot smbcJpy |>.gross.quanta) =
      some 31915 := by
  native_decide

end Observation236
