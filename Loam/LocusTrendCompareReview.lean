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

private def takeSameMonth
    (key : String) :
    List Loam.LocusTrendReview.Point →
      List Loam.LocusTrendReview.Point × List Loam.LocusTrendReview.Point
  | [] => ([], [])
  | point :: rest =>
      if monthKey point.date == key then
        let (same, remaining) := takeSameMonth key rest
        (point :: same, remaining)
      else
        ([], point :: rest)

private def monthlyPoints :
    List Loam.LocusTrendReview.Point →
      Except String (List Loam.LocusTrendReview.OverviewPoint)
  | [] => pure []
  | first :: rest => do
      let key := monthKey first.date
      let (same, remaining) := takeSameMonth key rest
      let group := first :: same
      let some last := group.getLast?
        | throw "loam: Trend Compare lost a nonempty calendar-month group"
      let some throughExclusive := Loam.ActualDate.shiftDays? last.date 1
        | throw "loam: Trend Compare could not construct a calendar-month boundary"
      let days := group.length
      let totalQuanta :=
        group.foldl (fun total point => total + point.daily.quanta) 0
      let complete :=
        startsCalendarMonth first.date &&
          monthKey throughExclusive != key
      let later ← monthlyPoints remaining
      return {
        start := first.date
        endExclusive := throughExclusive
        throughExclusive := throughExclusive
        total := Quantity.ofQuanta totalQuanta
        observedDays := days
        dailyAverageQuanta := totalQuanta / Int.ofNat days
        complete := complete
      } :: later

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
