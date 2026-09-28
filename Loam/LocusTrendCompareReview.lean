import Loam.ActualReview
import Loam.BoundaryPresetConfig
import Loam.LocusTrendReview

namespace Loam.LocusTrendCompareReview

open Loam.Core

set_option autoImplicit false

/-!
# Multi-Locus long-history comparison

A read-only comparison over several exact `(Locus, Measure)` coordinates.

Every series is projected through the same explicitly configured household
history and observation date. Cycle, calendar-month, and calendar-day views are
different read-only aggregations of that same exact admitted Actual evidence.

No description text, Purpose routing, aliases, or historical reclassification
is inferred here.

This means a `coffee` series is exactly the admitted `coffee / jpy`
coordinate. If older evidence used another Locus, that is a separate historical
classification question rather than something this comparison silently repairs.
-/

inductive Granularity where
  | cycle
  | month
  | day
  deriving Repr, DecidableEq

namespace Granularity

def label : Granularity → String
  | .cycle => "Cycle"
  | .month => "Month"
  | .day => "Day"

def coarser : Granularity → Granularity
  | .cycle => .cycle
  | .month => .cycle
  | .day => .month

def finer : Granularity → Granularity
  | .cycle => .month
  | .month => .day
  | .day => .day

end Granularity

structure SeriesSpec where
  label : String
  coordinate : EffectCoordinate
  deriving Repr, DecidableEq

structure Series where
  spec : SeriesSpec
  points : List Loam.LocusTrendReview.OverviewPoint
  undatedMatchingCurrentRecords : Nat
  deriving Repr, DecidableEq

structure Snapshot where
  source : String
  observedAt : String
  granularity : Granularity := .cycle
  series : List Series
  deriving Repr, DecidableEq

def Snapshot.pointCount (snapshot : Snapshot) : Nat :=
  snapshot.series.head?.map (·.points.length) |>.getD 0

def Snapshot.selectedWindow?
    (snapshot : Snapshot) (index : Nat) :
    Option Loam.LocusTrendReview.OverviewPoint := do
  let first ← snapshot.series.head?
  first.points[index]?

def Series.valueAt? (series : Series) (index : Nat) : Option Int :=
  series.points[index]?.map (·.dailyAverageQuanta)

private def monthKey (date : String) : String :=
  String.ofList (date.toList.take 7)

private def startsCalendarMonth (date : String) : Bool :=
  match date.splitOn "-" with
  | [_, _, day] => day == "01"
  | _ => false

structure MonthBucket where
  start : String
  lastDate : String
  totalQuanta : Int
  observedDays : Nat

private def MonthBucket.ofPoint
    (point : Loam.LocusTrendReview.Point) : MonthBucket := {
  start := point.date
  lastDate := point.date
  totalQuanta := point.daily.quanta
  observedDays := 1
}

private def MonthBucket.push
    (bucket : MonthBucket)
    (point : Loam.LocusTrendReview.Point) : MonthBucket := {
  bucket with
    lastDate := point.date
    totalQuanta := bucket.totalQuanta + point.daily.quanta
    observedDays := bucket.observedDays + 1
}

private def MonthBucket.toPoint
    (bucket : MonthBucket) :
    Except String Loam.LocusTrendReview.OverviewPoint := do
  let some throughExclusive := Loam.ActualDate.shiftDays? bucket.lastDate 1
    | throw "loam: Trend Compare could not construct a calendar-month boundary"
  let complete :=
    startsCalendarMonth bucket.start &&
      monthKey throughExclusive != monthKey bucket.start
  return {
    start := bucket.start
    endExclusive := throughExclusive
    throughExclusive := throughExclusive
    total := Quantity.ofQuanta bucket.totalQuanta
    observedDays := bucket.observedDays
    dailyAverageQuanta :=
      bucket.totalQuanta / Int.ofNat bucket.observedDays
    complete := complete
  }

private def monthlyPointsAux
    (current : Option MonthBucket)
    (completed : List Loam.LocusTrendReview.OverviewPoint) :
    List Loam.LocusTrendReview.Point →
      Except String (List Loam.LocusTrendReview.OverviewPoint)
  | [] => do
      match current with
      | none => pure completed.reverse
      | some bucket =>
          let point ← bucket.toPoint
          pure (point :: completed).reverse
  | point :: rest => do
      match current with
      | none =>
          monthlyPointsAux (some (.ofPoint point)) completed rest
      | some bucket =>
          if monthKey point.date == monthKey bucket.start then
            monthlyPointsAux (some (bucket.push point)) completed rest
          else
            let period ← bucket.toPoint
            monthlyPointsAux (some (.ofPoint point)) (period :: completed) rest

private def monthlyPoints
    (points : List Loam.LocusTrendReview.Point) :
    Except String (List Loam.LocusTrendReview.OverviewPoint) :=
  monthlyPointsAux none [] points

private def dailyPoints
    (observedAt : String)
    (points : List Loam.LocusTrendReview.Point) :
    Except String (List Loam.LocusTrendReview.OverviewPoint) :=
  points.mapM fun point => do
    let some endExclusive := Loam.ActualDate.shiftDays? point.date 1
      | throw "loam: Trend Compare could not construct a calendar-day boundary"
    return {
      start := point.date
      endExclusive := endExclusive
      throughExclusive := endExclusive
      total := point.daily
      observedDays := 1
      dailyAverageQuanta := point.daily.quanta
      complete := point.date < observedAt
    }

private def projectSeries
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (granularity : Granularity)
    (spec : SeriesSpec) : Except String Series := do
  match granularity with
  | .cycle =>
      let overview ←
        Loam.LocusTrendReview.projectOverview
          records preset observedAt spec.coordinate
      return {
        spec := spec
        points := overview.points
        undatedMatchingCurrentRecords := overview.undatedMatchingCurrentRecords
      }
  | .month =>
      let history ←
        Loam.LocusTrendReview.projectConfiguredHistory
          records preset observedAt spec.coordinate
      let points ← monthlyPoints history.points
      return {
        spec := spec
        points := points
        undatedMatchingCurrentRecords := history.undatedMatchingCurrentRecords
      }
  | .day =>
      let history ←
        Loam.LocusTrendReview.projectConfiguredHistory
          records preset observedAt spec.coordinate
      let points ← dailyPoints observedAt history.points
      return {
        spec := spec
        points := points
        undatedMatchingCurrentRecords := history.undatedMatchingCurrentRecords
      }

def projectAtGranularity
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (granularity : Granularity)
    (specs : List SeriesSpec) : Except String Snapshot := do
  if specs.isEmpty then
    throw "loam: Trend Compare requires at least one exact coordinate"
  let series ← specs.mapM fun spec =>
    projectSeries records preset observedAt granularity spec
  return {
    source := preset.name
    observedAt := observedAt
    granularity := granularity
    series := series
  }

/-- Backwards-compatible cycle projection used by existing callers and tests. -/
def project
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (specs : List SeriesSpec) : Except String Snapshot :=
  projectAtGranularity records preset observedAt .cycle specs

/--
Load admitted Actual once, resolve the unique configured preset containing
`observedAt`, and project every requested exact coordinate through that same
historical evidence at the requested granularity.
-/
def loadConfiguredAtGranularity
    (dataDir root : System.FilePath)
    (observedAt : String)
    (granularity : Granularity)
    (specs : List SeriesSpec) : IO (Except String Snapshot) := do
  match ← Loam.BoundaryPresetConfig.load?
      (Loam.HouseholdPaths.boundaryPresets dataDir) with
  | none => return .error "loam: boundary preset config is malformed"
  | some presets =>
      match Loam.BoundaryPresetConfig.currentWindowFor? presets observedAt with
      | .error message => return .error ("loam: " ++ message)
      | .ok current =>
          match presets.find? (fun preset => preset.name == current.source) with
          | none => return .error "loam: selected boundary preset disappeared"
          | some preset =>
              match ← Loam.ActualReview.loadRecordsFromActual root with
              | .error message => return .error message
              | .ok records =>
                  return projectAtGranularity
                    records preset observedAt granularity specs

/-- Backwards-compatible configured cycle projection. -/
def loadConfigured
    (dataDir root : System.FilePath)
    (observedAt : String)
    (specs : List SeriesSpec) : IO (Except String Snapshot) :=
  loadConfiguredAtGranularity dataDir root observedAt .cycle specs

end Loam.LocusTrendCompareReview
