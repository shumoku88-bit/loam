import Loam.ActualDate
import Loam.ActualReview

namespace Loam.LocusTrendReview

open Loam.Core

set_option autoImplicit false

/-!
# Locus quantity trend

A read-only explicit-window projection over one exact `(Locus, Measure)`
coordinate.

The projection answers a deliberately small question:

```text
for each calendar day in [start, end):
  what exact signed quantity is present at this coordinate
  in the current admitted Actual truth?
```

Corrected originals are excluded through `ActualReview.Record.isCurrent`.
No description text, AccountingRole, Purpose, merchant, or sign convention is
used to infer meaning. A positive quantity is not automatically called spending
and a negative quantity is not automatically called a refund.

Running totals and averages are presentation conveniences derived from the same
daily sequence. Nothing is retained as household authority.
-/

structure Point where
  date : String
  daily : Quantity
  cumulative : Quantity
  runningDailyAverageQuanta : Int
  deriving Repr, DecidableEq

structure Snapshot where
  start : String
  endExclusive : String
  coordinate : EffectCoordinate
  points : List Point
  undatedMatchingCurrentRecords : Nat
  deriving Repr, DecidableEq

def Snapshot.total (snapshot : Snapshot) : Quantity :=
  match snapshot.points.getLast? with
  | some point => point.cumulative
  | none => Quantity.ofQuanta 0

private def datesFrom
    (start : String) (days : Nat) : Except String (List String) :=
  (List.range days).mapM fun index =>
    match Loam.ActualDate.shiftDays? start (Int.ofNat index) with
    | some date => .ok date
    | none =>
        .error "loam: Locus Trend could not construct the explicit calendar window"

private def quantityForDate
    (records : List Loam.ActualReview.Record)
    (coordinate : EffectCoordinate)
    (date : String) : Int :=
  records.foldl
    (fun total record =>
      if record.isCurrent && record.date == some date then
        total +
          (record.event.quantityAt coordinate.locus coordinate.measure).quanta
      else
        total)
    0

private def undatedMatchingCount
    (records : List Loam.ActualReview.Record)
    (coordinate : EffectCoordinate) : Nat :=
  (records.filter fun record =>
    record.isCurrent &&
    record.date.isNone &&
    (record.event.quantityAt coordinate.locus coordinate.measure).quanta != 0).length

private def buildPoints
    (records : List Loam.ActualReview.Record)
    (coordinate : EffectCoordinate) :
    List String → Int → Nat → List Point
  | [], _, _ => []
  | date :: rest, cumulative, elapsed =>
      let daily := quantityForDate records coordinate date
      let nextCumulative := cumulative + daily
      let nextElapsed := elapsed + 1
      {
        date := date
        daily := Quantity.ofQuanta daily
        cumulative := Quantity.ofQuanta nextCumulative
        runningDailyAverageQuanta :=
          nextCumulative / Int.ofNat nextElapsed
      } :: buildPoints records coordinate rest nextCumulative nextElapsed

/--
Project one exact coordinate over one explicit half-open occurrence-time window.

Every calendar date is represented, including zero-quantity days, so cursor
movement and daily averages retain the actual time geometry instead of
compressing away quiet days.
-/
def project
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (coordinate : EffectCoordinate) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate start ||
      !Loam.ActualDate.validIsoDate endExclusive then
    throw "loam: Locus Trend requires real YYYY-MM-DD window coordinates"
  let some distance := Loam.ActualDate.daysBetween? start endExclusive
    | throw "loam: Locus Trend could not determine the explicit calendar window"
  if distance <= 0 then
    throw "loam: Locus Trend requires start to precede endExclusive"
  let days := distance.natAbs
  let dates ← datesFrom start days
  return {
    start := start
    endExclusive := endExclusive
    coordinate := coordinate
    points := buildPoints records coordinate dates 0 0
    undatedMatchingCurrentRecords := undatedMatchingCount records coordinate
  }

/-- Load admitted normalized Actual evidence and project one exact coordinate. -/
def loadSnapshot
    (root : System.FilePath)
    (start endExclusive : String)
    (coordinate : EffectCoordinate) : IO (Except String Snapshot) := do
  match ← Loam.ActualReview.loadRecordsFromActual root with
  | .error message => return .error message
  | .ok records => return project records start endExclusive coordinate

end Loam.LocusTrendReview
