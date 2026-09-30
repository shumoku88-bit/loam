import Loam.ActualDate
import Loam.Review.ActualReview
import Loam.BoundaryPresetConfig

namespace Loam.LocusTrendReview

open Loam.Core

set_option autoImplicit false

/-!
# Locus quantity trend

Read-only historical projections over one exact `(Locus, Measure)` coordinate.

Two related answers are kept distinct:

* `Snapshot` preserves one point per calendar day inside one explicit window.
* `OverviewSnapshot` summarizes the explicitly configured adjacent windows of
  one boundary preset through an observation date.

Both use current admitted Actual truth. Corrected originals are excluded through
`ActualReview.Record.isCurrent`. Description text, AccountingRole, Purpose,
merchant, and sign conventions are not used to infer meaning.
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

/--
One configured adjacent boundary window in the long-history overview.

`endExclusive` is the configured boundary. `throughExclusive` is the portion
actually observed. They differ only for the current partial window.
-/
structure OverviewPoint where
  start : String
  endExclusive : String
  throughExclusive : String
  total : Quantity
  observedDays : Nat
  dailyAverageQuanta : Int
  complete : Bool
  deriving Repr, DecidableEq

structure OverviewSnapshot where
  source : String
  observedAt : String
  coordinate : EffectCoordinate
  points : List OverviewPoint
  undatedMatchingCurrentRecords : Nat
  deriving Repr, DecidableEq

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

private def quantityBetween
    (records : List Loam.ActualReview.Record)
    (coordinate : EffectCoordinate)
    (start endExclusive : String) : Int :=
  records.foldl
    (fun total record =>
      if record.isCurrent then
        match record.date with
        | some date =>
            if decide (start <= date && date < endExclusive) then
              total +
                (record.event.quantityAt coordinate.locus coordinate.measure).quanta
            else
              total
        | none => total
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
movement and daily averages retain actual time geometry.
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

private def configuredWindowsThrough
    (observedAt : String) : List String → List (String × String)
  | start :: endExclusive :: rest =>
      if start <= observedAt then
        (start, endExclusive) ::
          configuredWindowsThrough observedAt (endExclusive :: rest)
      else
        []
  | _ => []

private def overviewPoint
    (records : List Loam.ActualReview.Record)
    (coordinate : EffectCoordinate)
    (observedEndExclusive start endExclusive : String) :
    Except String OverviewPoint := do
  let throughExclusive :=
    if observedEndExclusive < endExclusive then observedEndExclusive else endExclusive
  let some distance := Loam.ActualDate.daysBetween? start throughExclusive
    | throw "loam: Locus Trend could not measure a configured historical window"
  if distance <= 0 then
    throw "loam: Locus Trend encountered an empty configured historical window"
  let days := distance.natAbs
  let total := quantityBetween records coordinate start throughExclusive
  return {
    start := start
    endExclusive := endExclusive
    throughExclusive := throughExclusive
    total := Quantity.ofQuanta total
    observedDays := days
    dailyAverageQuanta := total / Int.ofNat days
    complete := endExclusive <= observedEndExclusive
  }

/--
Summarize every explicitly configured adjacent window from the first boundary
through `observedAt`.

No recurrence is invented. The preset is consumed exactly as replaceable query
configuration. The current window is truncated at the day after `observedAt`,
so its average describes elapsed observed days rather than future zero days.
-/
def projectOverview
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (coordinate : EffectCoordinate) : Except String OverviewSnapshot := do
  if !Loam.ActualDate.validIsoDate observedAt then
    throw "loam: Locus Trend overview requires a real YYYY-MM-DD observation date"
  let some observedEndExclusive := Loam.ActualDate.shiftDays? observedAt 1
    | throw "loam: Locus Trend overview could not construct the observation boundary"
  let windows := configuredWindowsThrough observedAt preset.boundaries
  if windows.isEmpty then
    throw "loam: Locus Trend overview has no configured window through the observation date"
  let points ← windows.mapM fun (start, endExclusive) =>
    overviewPoint records coordinate observedEndExclusive start endExclusive
  return {
    source := preset.name
    observedAt := observedAt
    coordinate := coordinate
    points := points
    undatedMatchingCurrentRecords := undatedMatchingCount records coordinate
  }

/--
Project one calendar point per day from the first explicitly configured boundary
through `observedAt`.

This is the long daily-history companion to the cycle overview. It does not
invent boundaries before the first configured coordinate, and it retains zero
quantity days so pointer position remains calendar position.
-/
def projectConfiguredHistory
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (coordinate : EffectCoordinate) : Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate observedAt then
    throw "loam: Locus Trend daily history requires a real YYYY-MM-DD observation date"
  let some start := preset.boundaries.head?
    | throw "loam: Locus Trend daily history requires at least one configured boundary"
  if observedAt < start then
    throw "loam: Locus Trend daily history observation precedes its first configured boundary"
  let some endExclusive := Loam.ActualDate.shiftDays? observedAt 1
    | throw "loam: Locus Trend daily history could not construct the observation boundary"
  project records start endExclusive coordinate

/--
Load the unique configured boundary preset containing `observedAt` and project
its complete explicit history through that date.

This uses the same fail-closed preset selection as current cycle consumers. It
does not guess a preferred preset or extrapolate another boundary.
-/
def loadConfiguredOverview
    (dataDir root : System.FilePath)
    (observedAt : String)
    (coordinate : EffectCoordinate) : IO (Except String OverviewSnapshot) := do
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
                  return projectOverview records preset observedAt coordinate

/--
Load the configured preset containing `observedAt` and project daily history
from its first explicit boundary through that date.
-/
def loadConfiguredHistory
    (dataDir root : System.FilePath)
    (observedAt : String)
    (coordinate : EffectCoordinate) : IO (Except String Snapshot) := do
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
                  return projectConfiguredHistory
                    records preset observedAt coordinate

/-- Load admitted normalized Actual evidence and project one exact daily window. -/
def loadSnapshot
    (root : System.FilePath)
    (start endExclusive : String)
    (coordinate : EffectCoordinate) : IO (Except String Snapshot) := do
  match ← Loam.ActualReview.loadRecordsFromActual root with
  | .error message => return .error message
  | .ok records => return project records start endExclusive coordinate

/-- Load admitted Actual evidence and project one configured long-history overview. -/
def loadOverview
    (root : System.FilePath)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (coordinate : EffectCoordinate) : IO (Except String OverviewSnapshot) := do
  match ← Loam.ActualReview.loadRecordsFromActual root with
  | .error message => return .error message
  | .ok records => return projectOverview records preset observedAt coordinate

end Loam.LocusTrendReview
