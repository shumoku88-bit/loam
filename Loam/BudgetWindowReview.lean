import Loam.ActualAuthority
import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CapacityWindowInspection
import Loam.CapacityAuthority
import Loam.CapacityReview
import Loam.Persistence.ActualRoutingPersistence

namespace Loam.BudgetWindowReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Budget Window review

This is the production read boundary for explicit half-open budget-window queries.
It consumes selected semantic authorities without exposing Capacity companion
placement:

- Event / ActualValidity come from the selected Movement evidence generation;
- Capacity / CapacityEffective come through `CapacityAuthority`;
- ActualRouting remains its independent canonical stream;
- EventCorrection preserves the existing absent-as-empty read policy.

The caller supplies `[start, end)` explicitly. This module does not choose a
cycle, month, selected-day window, or retained Period identity. Remaining is
derived from the two resolved component projections and is not retained state.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  remaining : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  start : String
  endExclusive : String
  rows : List Row
  deriving Repr, DecidableEq

private structure Evidence where
  capacity : CapacityMemory
  effective : CapacityEffectiveMemory String
  events : EventMemory
  corrections : EventCorrectionMemory
  validities : ActualValidityMemory String
  routing : Loam.Persistence.ActualRoutingHistory

private def requireFile (path : System.FilePath) (label : String) : IO (Except String Unit) := do
  if ← path.pathExists then return .ok ()
  return .error ("loam: required " ++ label ++ " not found: " ++ path.toString)

private def validateWindow (start end_ : String) : Except String Unit :=
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    .error "loam: budget window endpoints must be real YYYY-MM-DD calendar dates"
  else if !validCapacityWindow start end_ then
    .error "loam: budget window start must be earlier than end"
  else
    .ok ()

private def projectPurpose?
    (evidence : Evidence)
    (start end_ : String)
    (purpose : PurposeId) : Option Row := do
  let yen : MeasureId := ⟨"jpy"⟩
  let entitlement ←
    entitlementAtEffectiveWindow?
      evidence.capacity evidence.effective start end_ purpose yen
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      evidence.events evidence.corrections evidence.validities evidence.routing
      start end_ purpose yen
  some {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
    remaining := entitlement - consumption
  }

private def loadEvidence
    (dataDir manifestRoot : System.FilePath) : IO (Except String Evidence) := do
  let capacityPath := dataDir / "capacity.loam"
  let routingPath := dataDir / "actual-routing.loam"

  let capacityImage ←
    match ← Loam.CapacityAuthority.loadRequired capacityPath with
    | .ok image => pure image
    | .error message => return .error message
  match ← requireFile routingPath "Actual routing evidence" with
  | .error message => return .error message
  | .ok _ => pure ()

  let path :=
    if manifestRoot.fileName == some Loam.ActualAuthority.actualFileName then manifestRoot
    else Loam.ActualAuthority.actualPath manifestRoot
  let actualEvidence ←
    match ← Loam.ActualAuthority.loadActualFile? path with
    | .ok ev => pure ev
    | .error message =>
        match ← Loam.ActualAuthority.loadActual? dataDir with
        | .ok ev => pure ev
        | .error _ => return .error message

  let validities ←
    match admittedActualValidityMemory? actualEvidence.validity with
    | some memory => pure memory
    | none =>
        return .error
          "loam: Actual validity corrections do not justify one current date per Event"
  let routing ←
    match ← Loam.Persistence.loadActualRoutingHistory? routingPath with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Actual routing evidence"

  return .ok {
    capacity := capacityImage.movements
    effective := capacityImage.effective
    events := actualEvidence.events
    corrections := actualEvidence.corrections
    validities := validities
    routing := routing
  }

private def loadWindowEvidence
    (dataDir manifestRoot : System.FilePath)
    (start end_ : String) : IO (Except String Evidence) := do
  match validateWindow start end_ with
  | .error message => return .error message
  | .ok _ => loadEvidence dataDir manifestRoot

/--
Load one immutable production evidence snapshot and answer one explicit JPY
Purpose over `[start, end)`. The Purpose need not already appear in Capacity
history: complete evidence can therefore justify an exact zero row.
-/
def loadPurposeRow
    (dataDir manifestRoot : System.FilePath)
    (start end_ : String)
    (purpose : PurposeId) : IO (Except String Row) := do
  let evidence ←
    match ← loadWindowEvidence dataDir manifestRoot start end_ with
    | .ok evidence => pure evidence
    | .error message => return .error message
  match projectPurpose? evidence start end_ purpose with
  | some row => return .ok row
  | none =>
      return .error "loam: canonical evidence does not justify this budget-window projection"

/--
Load one immutable production evidence snapshot and answer an explicit JPY
`[start, end)` query for every Purpose represented by retained Capacity evidence.
No fallback to frozen Movement sidecars exists on this path.
-/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (start end_ : String) : IO (Except String Snapshot) := do
  let evidence ←
    match ← loadWindowEvidence dataDir manifestRoot start end_ with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let purposes := Loam.CapacityReview.rememberedPurposes evidence.capacity
  match purposes.mapM (projectPurpose? evidence start end_) with
  | none =>
      return .error "loam: canonical evidence does not justify this budget-window projection"
  | some rows =>
      return .ok { start := start, endExclusive := end_, rows := rows }

end Loam.BudgetWindowReview
