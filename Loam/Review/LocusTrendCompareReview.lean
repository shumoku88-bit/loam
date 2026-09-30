import Loam.ActualReview
import Loam.BoundaryPresetConfig
import Loam.Review.LocusTrendReview

namespace Loam.LocusTrendCompareReview

open Loam.Core

set_option autoImplicit false

/-!
# Multi-Locus long-history comparison

A read-only comparison over several exact `(Locus, Measure)` coordinates.

Every series is projected through the same explicitly configured household
history and observation date. Scope first selects occurrence-time evidence;
Cycle, calendar-month, and calendar-day grains then aggregate that same scoped
daily evidence.

No description text, Purpose routing, aliases, or historical reclassification
is inferred here.
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

inductive Scope where
  | allHistory
  | currentCycle
  | currentMonth
  | last30Days
  deriving Repr, DecidableEq

namespace Scope

def label : Scope → String
  | .allHistory => "All history"
  | .currentCycle => "Current cycle"
  | .currentMonth => "This month"
  | .last30Days => "Last 30 days"

def next : Scope → Scope
  | .allHistory => .currentCycle
  | .currentCycle => .currentMonth
  | .currentMonth => .last30Days
  | .last30Days => .allHistory

def previous : Scope → Scope
  | .allHistory => .last30Days
  | .currentCycle => .allHistory
  | .currentMonth => .currentCycle
  | .last30Days => .currentMonth

end Scope

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
  scope : Scope := .allHistory
  scopeStart : String := ""
  scopeEndExclusive : String := ""
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

private def laterDate (first second : String) : String :=
  if first < second then second else first

private def earlierDate (first second : String) : String :=
  if first < second then first else second

private def calendarMonthWindow?
    (date : String) : Option (String × String) := do
  if !Loam.ActualDate.validIsoDate date then none else do
    let [year, month, _] := date.splitOn "-" | none
    let start := year ++ "-" ++ month ++ "-01"
    let endExclusive ← Loam.ActualDate.shiftMonthsSameDay? start 1
    some (start, endExclusive)

private def scopeWindow
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (scope : Scope) : Except String (String × String) := do
  let some historyStart := preset.boundaries.head?
    | throw "loam: Trend Compare scope requires a configured history boundary"
  let some observedEndExclusive := Loam.ActualDate.shiftDays? observedAt 1
    | throw "loam: Trend Compare scope could not construct the observation boundary"
  let (requestedStart, requestedEnd) ←
    match scope with
    | .allHistory =>
        pure (historyStart, observedEndExclusive)
    | .currentCycle =>
        match Loam.BoundaryPresetConfig.windowForDate? preset observedAt with
        | some (start, endExclusive) => pure (start, endExclusive)
        | none => throw "loam: Trend Compare current-cycle scope is unavailable"
    | .currentMonth =>
        match calendarMonthWindow? observedAt with
        | some window => pure window
        | none => throw "loam: Trend Compare current-month scope is unavailable"
    | .last30Days =>
        match Loam.ActualDate.shiftDays? observedAt (-29) with
        | some start => pure (start, observedEndExclusive)
        | none => throw "loam: Trend Compare 30-day scope is unavailable"
  let start := laterDate historyStart requestedStart
  let endExclusive := earlierDate observedEndExclusive requestedEnd
  if decide (start < endExclusive) then
    pure (start, endExclusive)
  else
    throw "loam: Trend Compare scope has no configured historical coverage"

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

private def adjacentWindowsFrom
    (previous : String) :
    List String → List (String × String)
  | [] => []
  | next :: rest =>
      (previous, next) :: adjacentWindowsFrom next rest

private def adjacentWindows :
    List String → List (String × String)
  | [] => []
  | first :: rest => adjacentWindowsFrom first rest

private def cyclePoint?
    (scopeStart scopeEndExclusive : String)
    (points : List Loam.LocusTrendReview.Point)
    (window : String × String) :
    Option Loam.LocusTrendReview.OverviewPoint :=
  let (naturalStart, naturalEnd) := window
  let start := laterDate naturalStart scopeStart
  let endExclusive := earlierDate naturalEnd scopeEndExclusive
  if !(decide (start < endExclusive)) then
    none
  else
    let matching :=
      points.filter fun point =>
        decide (start <= point.date && point.date < endExclusive)
    let observedDays := matching.length
    if observedDays = 0 then
      none
    else
      let totalQuanta :=
        matching.foldl (fun total point => total + point.daily.quanta) 0
      some {
        start := start
        endExclusive := endExclusive
        throughExclusive := endExclusive
        total := Quantity.ofQuanta totalQuanta
        observedDays := observedDays
        dailyAverageQuanta := totalQuanta / Int.ofNat observedDays
        complete := start == naturalStart && endExclusive == naturalEnd
      }

private def cyclePoints
    (preset : Loam.BoundaryPresetConfig.Preset)
    (scopeStart scopeEndExclusive : String)
    (points : List Loam.LocusTrendReview.Point) :
    List Loam.LocusTrendReview.OverviewPoint :=
  (adjacentWindows preset.boundaries).filterMap fun window =>
    cyclePoint? scopeStart scopeEndExclusive points window

private def scopedDailyPoints
    (start endExclusive : String)
    (points : List Loam.LocusTrendReview.Point) :
    List Loam.LocusTrendReview.Point :=
  points.filter fun point =>
    decide (start <= point.date && point.date < endExclusive)

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

private def projectScopedSeries
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt start endExclusive : String)
    (granularity : Granularity)
    (spec : SeriesSpec) : Except String Series := do
  let history ←
    Loam.LocusTrendReview.projectConfiguredHistory
      records preset observedAt spec.coordinate
  let scopedPoints := scopedDailyPoints start endExclusive history.points
  let points ←
    match granularity with
    | .cycle => pure (cyclePoints preset start endExclusive scopedPoints)
    | .month => monthlyPoints scopedPoints
    | .day => dailyPoints observedAt scopedPoints
  return {
    spec := spec
    points := points
    undatedMatchingCurrentRecords := history.undatedMatchingCurrentRecords
  }

def projectAtScope
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (granularity : Granularity)
    (scope : Scope)
    (specs : List SeriesSpec) : Except String Snapshot := do
  if specs.isEmpty then
    throw "loam: Trend Compare requires at least one exact coordinate"
  let (start, endExclusive) ← scopeWindow preset observedAt scope
  let series ← specs.mapM fun spec =>
    if scope == .allHistory then
      projectSeries records preset observedAt granularity spec
    else
      projectScopedSeries
        records preset observedAt start endExclusive granularity spec
  return {
    source := preset.name
    observedAt := observedAt
    granularity := granularity
    scope := scope
    scopeStart := start
    scopeEndExclusive := endExclusive
    series := series
  }

def projectAtGranularity
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (granularity : Granularity)
    (specs : List SeriesSpec) : Except String Snapshot :=
  projectAtScope records preset observedAt granularity .allHistory specs

/-- Backwards-compatible cycle projection used by existing callers and tests. -/
def project
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (specs : List SeriesSpec) : Except String Snapshot :=
  projectAtGranularity records preset observedAt .cycle specs

def loadConfiguredAtScope
    (dataDir root : System.FilePath)
    (observedAt : String)
    (granularity : Granularity)
    (scope : Scope)
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
                  return projectAtScope
                    records preset observedAt granularity scope specs

def loadConfiguredAtGranularity
    (dataDir root : System.FilePath)
    (observedAt : String)
    (granularity : Granularity)
    (specs : List SeriesSpec) : IO (Except String Snapshot) :=
  loadConfiguredAtScope
    dataDir root observedAt granularity .allHistory specs

/-- Backwards-compatible configured cycle projection. -/
def loadConfigured
    (dataDir root : System.FilePath)
    (observedAt : String)
    (specs : List SeriesSpec) : IO (Except String Snapshot) :=
  loadConfiguredAtGranularity dataDir root observedAt .cycle specs

end Loam.LocusTrendCompareReview
