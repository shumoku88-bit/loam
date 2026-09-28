import Loam.ActualReview
import Loam.BoundaryPresetConfig
import Loam.LocusTrendReview

namespace Loam.LocusTrendCompareReview

open Loam.Core

set_option autoImplicit false

/-!
# Multi-Locus long-history comparison

A read-only comparison over several exact `(Locus, Measure)` coordinates.

Every series is projected through the same explicitly configured boundary
preset and observation date by reusing `LocusTrendReview.projectOverview`.
No description text, Purpose routing, aliases, or historical reclassification
is inferred here.

This means a `coffee` series is exactly the admitted `coffee / jpy`
coordinate. If older evidence used another Locus, that is a separate historical
classification question rather than something this comparison silently repairs.
-/

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

def project
    (records : List Loam.ActualReview.Record)
    (preset : Loam.BoundaryPresetConfig.Preset)
    (observedAt : String)
    (specs : List SeriesSpec) : Except String Snapshot := do
  if specs.isEmpty then
    throw "loam: Trend Compare requires at least one exact coordinate"
  let series ← specs.mapM fun spec => do
    let overview ←
      Loam.LocusTrendReview.projectOverview
        records preset observedAt spec.coordinate
    return {
      spec := spec
      points := overview.points
      undatedMatchingCurrentRecords := overview.undatedMatchingCurrentRecords
    }
  return {
    source := preset.name
    observedAt := observedAt
    series := series
  }

/--
Load admitted Actual once, resolve the unique configured preset containing
`observedAt`, and project every requested exact coordinate through that same
historical window set.
-/
def loadConfigured
    (dataDir root : System.FilePath)
    (observedAt : String)
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
                  return project records preset observedAt specs

end Loam.LocusTrendCompareReview
