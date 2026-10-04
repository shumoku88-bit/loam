import Loam.Authority.ActualAuthority
import Loam.ActualDate
import Loam.Application.CapacityWindowInspection
import Loam.Authority.CapacityAuthority
import Loam.Authority.ActualRoutingAuthority
import Loam.Review.CapacityReview
import Loam.HouseholdPaths
import Loam.Persistence.ActualRoutingPersistence

namespace Loam.BudgetWindowReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Budget Window review

This is the production read boundary for explicit half-open budget-window queries.
It consumes selected semantic authorities without exposing physical placement:

- Event / ActualValidity / EventCorrection come through `ActualAuthority`;
- Capacity / CapacityEffective come from HouseholdImage through `CapacityAuthority`;
- ActualRouting comes from the required HouseholdImage section.

The caller supplies `[start, end)` explicitly. This module does not choose a
cycle, month, selected-day window, or retained Period identity. Remaining is
derived from the two resolved component projections and is not retained state.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  deriving Repr, DecidableEq

/-- Exact Remaining derived from the two retained Budget Window components. -/
def Row.remaining (row : Row) : Quantity :=
  row.entitlement - row.consumption

structure Snapshot where
  measure : MeasureId := ⟨"jpy"⟩
  start : String
  endExclusive : String
  rows : List Row
  deriving Repr, DecidableEq

private structure Evidence where
  capacity : Loam.CapacityAuthority.Image
  actual : Loam.ActualAuthority.Image
  routing : Loam.Persistence.ActualRoutingHistory

private def validateWindow (start end_ : String) : Except String Unit :=
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    .error "loam: budget window endpoints must be real YYYY-MM-DD calendar dates"
  else if !validCapacityWindow start end_ then
    .error "loam: budget window start must be earlier than end"
  else
    .ok ()

/--
Project one Purpose from already-admitted Capacity and Actual read images.
Capacity cross-family completeness, the current Event frontier, and current
ActualValidity memory are all carried by their authority images rather than
reconstructed inside the report.
-/
private def projectPurpose?
    (measure : MeasureId)
    (evidence : Evidence)
    (start end_ : String)
    (purpose : PurposeId) : Option Row := do
  let entitlement ←
    entitlementAtAdmittedEffectiveWindow?
      evidence.capacity start end_ purpose measure
  let consumption ←
    consumptionAtRecordedEffectiveRoutingWindow?
      evidence.actual.currentEvents evidence.actual.currentValidities
      evidence.routing start end_ purpose measure
  some {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
  }

private def loadEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) := do
  let capacityImage ←
    match ← Loam.CapacityAuthority.loadHouseholdRequired dataDir with
    | .ok image => pure image
    | .error message => return .error message

  let actualImage ←
    match ← Loam.ActualAuthority.loadImageFile?
        (Loam.ActualAuthority.actualPathFromRootOrFile actualRoot) with
    | .ok image => pure image
    | .error message => return .error message
  let routing ←
    match ← Loam.ActualRoutingAuthority.loadHouseholdRequired? dataDir with
    | .ok history => pure history
    | .error message => return .error message

  return .ok {
    capacity := capacityImage
    actual := actualImage
    routing := routing
  }

private def loadWindowEvidence
    (dataDir actualRoot : System.FilePath)
    (start end_ : String) : IO (Except String Evidence) := do
  match validateWindow start end_ with
  | .error message => return .error message
  | .ok _ => loadEvidence dataDir actualRoot

/--
Load one immutable production evidence snapshot and answer one explicit
single-Measure Purpose over `[start, end)`. The Purpose need not already appear
in Capacity history: complete evidence can therefore justify an exact zero row.
-/
def loadPurposeRowForMeasure
    (measure : MeasureId)
    (dataDir actualRoot : System.FilePath)
    (start end_ : String)
    (purpose : PurposeId) : IO (Except String Row) := do
  let evidence ←
    match ← loadWindowEvidence dataDir actualRoot start end_ with
    | .ok evidence => pure evidence
    | .error message => return .error message
  match projectPurpose? measure evidence start end_ purpose with
  | some row => return .ok row
  | none =>
      return .error "loam: canonical evidence does not justify this budget-window projection"

/-- Backward-compatible JPY entrance for the current household. -/
def loadPurposeRow
    (dataDir actualRoot : System.FilePath)
    (start end_ : String)
    (purpose : PurposeId) : IO (Except String Row) :=
  loadPurposeRowForMeasure ⟨"jpy"⟩ dataDir actualRoot start end_ purpose

/--
Load one immutable production evidence snapshot and answer an explicit
single-Measure `[start, end)` query for every Purpose represented by retained Capacity evidence.

An empty Purpose set remains an empty successful answer. For a non-empty set,
every Purpose reuses the current Event frontier and current ActualValidity memory
already carried by the admitted Actual authority image. No report-local
Correction or ActualValidity admission is repeated.
-/
def loadSnapshotForMeasure
    (measure : MeasureId)
    (dataDir actualRoot : System.FilePath)
    (start end_ : String) : IO (Except String Snapshot) := do
  let evidence ←
    match ← loadWindowEvidence dataDir actualRoot start end_ with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let purposes := Loam.CapacityReview.rememberedPurposes evidence.capacity.movements
  match purposes with
  | [] =>
      return .ok { measure := measure, start := start, endExclusive := end_, rows := [] }
  | first :: rest =>
      match projectPurpose? measure evidence start end_ first with
      | none =>
          return .error "loam: canonical evidence does not justify this budget-window projection"
      | some firstRow =>
          match rest.mapM (projectPurpose? measure evidence start end_) with
          | none =>
              return .error "loam: canonical evidence does not justify this budget-window projection"
          | some later =>
              return .ok {
                measure := measure
                start := start
                endExclusive := end_
                rows := firstRow :: later
              }

/-- Backward-compatible JPY entrance for the current household. -/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start end_ : String) : IO (Except String Snapshot) :=
  loadSnapshotForMeasure ⟨"jpy"⟩ dataDir actualRoot start end_

end Loam.BudgetWindowReview
