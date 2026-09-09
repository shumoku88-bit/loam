import Loam.ActualDate
import Loam.ActualReview

namespace Loam.TransactionsFlowReview

open Loam.Core

set_option autoImplicit false

/-!
# Shared Transactions-Flow incidence review

This read boundary promotes only the semantics qualified by Observations 233–235.
It is a projection over the existing correction-aware `ActualReview.Record`
answer, not a second Event reader, correction frontier, date engine, canonical
authority, or persistence format.

The represented incidence relation is:

```text
row    = EffectCoordinate = (LocusId, MeasureId)
column = current dated Event in one explicit half-open window
cell   = Event.quantityAt row.locus row.measure
```

There is deliberately no Locus-to-Locus edge, source/destination pairing,
posting order, transfer classification, accounting role, or Purpose meaning in
this primitive. Distinct Measures remain distinct row coordinates.
-/

/-- One selected current Actual Event column with its already-admitted review context. -/
structure Column where
  event : Event
  date : String
  description : String

/--
One explicit Transactions-Flow window.

Cells are not retained. They are derived from the selected Events with
`Event.quantityAt`, keeping the review surface small and preventing a second
stored posting representation.
-/
structure Snapshot where
  start : String
  endExclusive : String
  rows : List EffectCoordinate
  columns : List Column

/-- Two-sided activity at one exact coordinate across the selected Event columns. -/
structure RowActivity where
  net : Quantity
  positive : Quantity
  negative : Quantity
  gross : Quantity
  activeEvents : Nat
  deriving Repr, DecidableEq

private def validateCurrentDates :
    List Loam.ActualReview.Record → Except String Unit
  | [] => .ok ()
  | record :: rest =>
      if !record.isCurrent || record.event.effects.isEmpty then
        validateCurrentDates rest
      else
        match record.date with
        | none =>
            .error
              ("loam: transactions-flow unavailable: current quantity Event " ++
                record.event.id.token ++ " has no occurrence date")
        | some date =>
            if Loam.ActualDate.validIsoDate date then
              validateCurrentDates rest
            else
              .error
                ("loam: transactions-flow unavailable: current quantity Event " ++
                  record.event.id.token ++ " has an invalid occurrence date")

private def inWindow
    (start endExclusive : String) (record : Loam.ActualReview.Record) : Bool :=
  if !record.isCurrent then false
  else
    match record.date with
    | none => false
    | some date => decide (start ≤ date ∧ date < endExclusive)

private def recordLe
    (left right : Loam.ActualReview.Record) : Bool :=
  match left.date, right.date with
  | some leftDate, some rightDate =>
      if leftDate == rightDate then
        left.event.id.token <= right.event.id.token
      else
        leftDate <= rightDate
  | _, _ => false

private def addCoordinateIfAbsent
    (rows : List EffectCoordinate) (coordinate : EffectCoordinate) :
    List EffectCoordinate :=
  if coordinate ∈ rows then rows else rows ++ [coordinate]

private def coordinateLe (left right : EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def rowsFromColumns (columns : List Column) : List EffectCoordinate :=
  let represented := columns.foldl
    (fun rows column =>
      column.event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        rows)
    []
  represented.mergeSort coordinateLe

private def columnOfRecord? (record : Loam.ActualReview.Record) : Option Column := do
  let date ← record.date
  some {
    event := record.event
    date := date
    description := record.description
  }

/--
Project one explicit half-open Transactions-Flow window from shared Actual review
evidence.

A current quantity-bearing Event without a usable date refuses the whole answer:
without that coordinate it cannot safely be justified as inside or outside the
window. Superseded records never become columns. Empty current Events need no
date because they contribute no quantity coordinate or matrix cell.
-/
def project
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate start ||
      !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: transactions-flow endpoints must be real YYYY-MM-DD calendar dates"
  if !(decide (start < endExclusive)) then
    throw "loam: transactions-flow start must be earlier than end"

  validateCurrentDates records

  let selected :=
    (records.filter (inWindow start endExclusive)).mergeSort recordLe
  let columns := selected.filterMap columnOfRecord?

  return {
    start := start
    endExclusive := endExclusive
    rows := rowsFromColumns columns
    columns := columns
  }

/-- Exact signed quantity in one coordinate/Event incidence cell. -/
def cellAt
    (snapshot : Snapshot)
    (coordinate : EffectCoordinate)
    (eventId : EventId) : Option Quantity := do
  let column ← snapshot.columns.find? fun candidate =>
    decide (candidate.event.id = eventId)
  some (Event.quantityAt column.event coordinate.locus coordinate.measure)

/-- Exact selected-period net change at one coordinate. -/
def rowTotal (snapshot : Snapshot) (coordinate : EffectCoordinate) : Quantity :=
  Quantity.ofQuanta <|
    snapshot.columns.foldl
      (fun total column =>
        total +
          (Event.quantityAt column.event coordinate.locus coordinate.measure).quanta)
      0

/--
Expose two-sided coordinate activity that a small net value can otherwise hide.

`positive` is nonnegative, `negative` is nonpositive, and `gross` is the exact
sum of absolute Event contributions. These are quantity arithmetic only; they do
not classify inflow/outflow, debit/credit, transfer, income, or expense meaning.
-/
def rowActivity
    (snapshot : Snapshot) (coordinate : EffectCoordinate) : RowActivity :=
  let accumulated := snapshot.columns.foldl
    (fun state column =>
      let quantity :=
        (Event.quantityAt column.event coordinate.locus coordinate.measure).quanta
      if quantity > 0 then
        (state.1 + quantity, state.2.1,
          state.2.2.1 + quantity, state.2.2.2 + 1)
      else if quantity < 0 then
        (state.1, state.2.1 + quantity,
          state.2.2.1 - quantity, state.2.2.2 + 1)
      else
        state)
    (0, 0, 0, 0)
  return {
    net := Quantity.ofQuanta (accumulated.1 + accumulated.2.1)
    positive := Quantity.ofQuanta accumulated.1
    negative := Quantity.ofQuanta accumulated.2.1
    gross := Quantity.ofQuanta accumulated.2.2.1
    activeEvents := accumulated.2.2.2
  }

/--
Observed residual of one selected Event inside one Measure.

Zero witnesses conservation for that Event/Measure column. A nonzero residual is
retained as evidence rather than rejected, because practical Movement balance is
not a universal Core Event law.
-/
def measureResidual (column : Column) (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    column.event.effects.foldl
      (fun total effect =>
        if effect.measure = measure then
          total + effect.quantity.quanta
        else
          total)
      0

/--
Compose the existing manifest-backed Actual reader with this pure projection.
No canonical interpretation is duplicated here.
-/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let records ←
    match ← Loam.ActualReview.loadRecordsFromManifest
        manifestRoot (some (dataDir / "corrections.loam").toString) with
    | .error message => return .error message
    | .ok records => pure records
  return project records start endExclusive

end Loam.TransactionsFlowReview
