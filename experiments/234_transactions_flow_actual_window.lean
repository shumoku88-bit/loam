import Loam.ActualDate
import Loam.ActualReview

namespace Observation234

open Loam.Core

set_option autoImplicit false

/-!
Observation 234 asks whether the Observation 233 incidence-matrix semantics can
sit directly on the existing correction-aware ActualReview.Record boundary.

The experiment remains local. It introduces no production reader, matrix type,
persistence, or TUI surface.
-/

structure Snapshot where
  start : String
  endExclusive : String
  rows : List EffectCoordinate
  columns : List Loam.ActualReview.Record

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
              ("current quantity Event " ++ record.event.id.token ++
                " has no occurrence date")
        | some date =>
            if Loam.ActualDate.validIsoDate date then
              validateCurrentDates rest
            else
              .error
                ("current quantity Event " ++ record.event.id.token ++
                  " has an invalid occurrence date")

private def inWindow (start endExclusive : String)
    (record : Loam.ActualReview.Record) : Bool :=
  if !record.isCurrent then false
  else
    match record.date with
    | none => false
    | some date => decide (start ≤ date ∧ date < endExclusive)

private def columnLe
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

private def rowsFromColumns
    (columns : List Loam.ActualReview.Record) : List EffectCoordinate :=
  let represented := columns.foldl
    (fun rows record =>
      record.event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        rows)
    []
  represented.mergeSort coordinateLe

/--
Select one explicit half-open Actual window from the already correction-aware
review answer.

Any current quantity-bearing Event without a usable date refuses the matrix:
without that coordinate it cannot be justified as inside or outside the window.
Superseded records do not block the current projection.
-/
def project
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate start ||
      !Loam.ActualDate.validIsoDate endExclusive then
    throw "matrix endpoints must be real YYYY-MM-DD calendar dates"
  if !(decide (start < endExclusive)) then
    throw "matrix start must be earlier than end"
  validateCurrentDates records
  let columns :=
    (records.filter (inWindow start endExclusive)).mergeSort columnLe
  return {
    start := start
    endExclusive := endExclusive
    rows := rowsFromColumns columns
    columns := columns
  }

/-- Exact Observation-233 cell, now addressed through one selected Actual column. -/
def cellAt
    (snapshot : Snapshot)
    (coordinate : EffectCoordinate)
    (eventId : EventId) : Option Quantity := do
  let record ← snapshot.columns.find? fun candidate =>
    decide (candidate.event.id = eventId)
  some (Event.quantityAt record.event coordinate.locus coordinate.measure)

/-- Exact net change at one matrix row across the selected Actual columns. -/
def rowTotal (snapshot : Snapshot) (coordinate : EffectCoordinate) : Quantity :=
  Quantity.ofQuanta <|
    snapshot.columns.foldl
      (fun total record =>
        total + (Event.quantityAt record.event coordinate.locus coordinate.measure).quanta)
      0

private def jpy : MeasureId := ⟨"jpy"⟩
private def paypayJpy : EffectCoordinate := ⟨⟨"paypay"⟩, jpy⟩
private def foodJpy : EffectCoordinate := ⟨⟨"food"⟩, jpy⟩
private def bookJpy : EffectCoordinate := ⟨⟨"book"⟩, jpy⟩
private def smbcJpy : EffectCoordinate := ⟨⟨"smbc"⟩, jpy⟩

private def originalEvent : Event := {
  id := ⟨"original"⟩
  effects := [
    Effect.ofQuantity ⟨"original-paypay"⟩ ⟨"paypay"⟩ jpy (Quantity.ofQuanta (-9999)),
    Effect.ofQuantity ⟨"original-food"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 9999)]
  keyNodup := by decide
}

private def replacementEvent : Event := {
  id := ⟨"replacement"⟩
  effects := [
    Effect.ofQuantity ⟨"replacement-paypay"⟩ ⟨"paypay"⟩ jpy
      (Quantity.ofQuanta (-1000)),
    Effect.ofQuantity ⟨"replacement-food"⟩ ⟨"food"⟩ jpy
      (Quantity.ofQuanta 600),
    Effect.ofQuantity ⟨"replacement-book"⟩ ⟨"book"⟩ jpy
      (Quantity.ofQuanta 400)]
  keyNodup := by decide
}

private def laterEvent : Event := {
  id := ⟨"later"⟩
  effects := [
    Effect.ofQuantity ⟨"later-smbc"⟩ ⟨"smbc"⟩ jpy (Quantity.ofQuanta (-2470)),
    Effect.ofQuantity ⟨"later-book"⟩ ⟨"book"⟩ jpy (Quantity.ofQuanta 2470)]
  keyNodup := by decide
}

private def beforeEvent : Event := {
  id := ⟨"before"⟩
  effects := [
    Effect.ofQuantity ⟨"before-paypay"⟩ ⟨"paypay"⟩ jpy (Quantity.ofQuanta (-100)),
    Effect.ofQuantity ⟨"before-food"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 100)]
  keyNodup := by decide
}

private def afterEvent : Event := {
  id := ⟨"after"⟩
  effects := [
    Effect.ofQuantity ⟨"after-paypay"⟩ ⟨"paypay"⟩ jpy (Quantity.ofQuanta (-200)),
    Effect.ofQuantity ⟨"after-food"⟩ ⟨"food"⟩ jpy (Quantity.ofQuanta 200)]
  keyNodup := by decide
}

private def originalRecord : Loam.ActualReview.Record := {
  event := originalEvent
  date := some "2026-09-04"
  description := "superseded household entry"
  replacement := some ⟨"replacement"⟩
  isCurrent := false
}

private def replacementRecord : Loam.ActualReview.Record := {
  event := replacementEvent
  date := some "2026-09-05"
  description := "food and book"
  replacement := none
  isCurrent := true
}

private def laterRecord : Loam.ActualReview.Record := {
  event := laterEvent
  date := some "2026-09-15"
  description := "book purchase"
  replacement := none
  isCurrent := true
}

private def beforeRecord : Loam.ActualReview.Record := {
  event := beforeEvent
  date := some "2026-08-31"
  description := "before window"
  replacement := none
  isCurrent := true
}

private def afterRecord : Loam.ActualReview.Record := {
  event := afterEvent
  date := some "2026-10-01"
  description := "end boundary"
  replacement := none
  isCurrent := true
}

private def householdRecords : List Loam.ActualReview.Record :=
  -- Deliberately not chronological. Selection must use explicit dates, not list order.
  [laterRecord, originalRecord, afterRecord, replacementRecord, beforeRecord]

private def selectedIds (result : Except String Snapshot) : List String :=
  match result with
  | .error _ => []
  | .ok snapshot => snapshot.columns.map fun record => record.event.id.token

private def rowTokens (result : Except String Snapshot) : List (String × String) :=
  match result with
  | .error _ => []
  | .ok snapshot =>
      snapshot.rows.map fun coordinate =>
        (coordinate.locus.token, coordinate.measure.token)

private def cellQuanta
    (result : Except String Snapshot)
    (coordinate : EffectCoordinate)
    (eventId : EventId) : Option Int :=
  match result with
  | .error _ => none
  | .ok snapshot => (cellAt snapshot coordinate eventId).map (·.quanta)

private def rowTotalQuanta
    (result : Except String Snapshot)
    (coordinate : EffectCoordinate) : Option Int :=
  match result with
  | .error _ => none
  | .ok snapshot => some (rowTotal snapshot coordinate).quanta

private def september := project householdRecords "2026-09-01" "2026-10-01"

/-!
## Household-shaped selected matrix

Columns are selected from current Actual records and sorted by explicit date:

                        2026-09-05       2026-09-15
                        replacement      later
book/jpy                    400             2470
food/jpy                    600                0
paypay/jpy                -1000                0
smbc/jpy                      0            -2470

The superseded 9999-food Event is absent. The August record and the half-open
October end-boundary record are absent. Input list position is irrelevant.
-/

example : selectedIds september = ["replacement", "later"] := by native_decide

example :
    rowTokens september =
      [("book", "jpy"), ("food", "jpy"), ("paypay", "jpy"), ("smbc", "jpy")] := by
  native_decide

example : cellQuanta september foodJpy ⟨"replacement"⟩ = some 600 := by native_decide
example : cellQuanta september foodJpy ⟨"original"⟩ = none := by native_decide
example : cellQuanta september bookJpy ⟨"replacement"⟩ = some 400 := by native_decide
example : cellQuanta september bookJpy ⟨"later"⟩ = some 2470 := by native_decide
example : rowTotalQuanta september bookJpy = some 2870 := by native_decide
example : rowTotalQuanta september paypayJpy = some (-1000) := by native_decide
example : rowTotalQuanta september smbcJpy = some (-2470) := by native_decide

/-- A current quantity Event with no date cannot be placed relative to the window. -/
private def undatedCurrent : Loam.ActualReview.Record := {
  replacementRecord with date := none
}

example :
    (project (undatedCurrent :: householdRecords) "2026-09-01" "2026-10-01").isOk = false := by
  native_decide

/-- Superseded undated evidence does not block the correction-aware current matrix. -/
private def undatedSuperseded : Loam.ActualReview.Record := {
  originalRecord with date := none
}

example :
    selectedIds
      (project (undatedSuperseded :: householdRecords) "2026-09-01" "2026-10-01") =
      ["replacement", "later"] := by
  native_decide

/-- Invalid current occurrence evidence also refuses the matrix. -/
private def invalidDateCurrent : Loam.ActualReview.Record := {
  replacementRecord with date := some "2026-02-29"
}

example :
    (project (invalidDateCurrent :: householdRecords) "2026-09-01" "2026-10-01").isOk = false := by
  native_decide

/-- Empty current Events need no date to decide quantity-matrix membership. -/
private def emptyUndatedEvent : Event := {
  id := ⟨"empty-undated"⟩
  effects := []
  keyNodup := by simp
}

private def emptyUndatedRecord : Loam.ActualReview.Record := {
  event := emptyUndatedEvent
  date := none
  description := "no quantity effects"
  replacement := none
  isCurrent := true
}

example :
    selectedIds
      (project (emptyUndatedRecord :: householdRecords) "2026-09-01" "2026-10-01") =
      ["replacement", "later"] := by
  native_decide

end Observation234
