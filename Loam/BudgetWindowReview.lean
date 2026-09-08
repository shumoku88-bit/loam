import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CapacityWindowInspection
import Loam.CapacityReview
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence

namespace Loam.BudgetWindowReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Budget Window review

This is the production read boundary for explicit half-open budget-window queries.
It deliberately follows the current authority topology instead of reviving frozen
Movement sidecars:

- Event / ActualValidity come from the selected Movement manifest generation;
- Capacity / CapacityEffective remain their independent canonical streams;
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

private def emptyCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def loadCorrections?
    (path : System.FilePath) : IO (Except String EventCorrectionMemory) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadEventCorrectionMemory? path with
    | some corrections => return .ok corrections
    | none => return .error "loam: malformed or unsupported Event correction authority"
  else
    return .ok emptyCorrections

private def requireFile (path : System.FilePath) (label : String) : IO (Except String Unit) := do
  if ← path.pathExists then return .ok ()
  return .error ("loam: required " ++ label ++ " not found: " ++ path.toString)

private def projectPurpose?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory String)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory String)
    (routing : Loam.Persistence.ActualRoutingHistory)
    (start end_ : String)
    (purpose : PurposeId) : Option Row := do
  let yen : MeasureId := ⟨"jpy"⟩
  let entitlement ← entitlementAtEffectiveWindow? capacity effective start end_ purpose yen
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      events corrections validities routing start end_ purpose yen
  some {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
    remaining := entitlement - consumption
  }

/--
Load one immutable production evidence snapshot and answer an explicit JPY
`[start, end)` query for every Purpose represented by retained Capacity evidence.
No fallback to frozen Movement sidecars exists on this path.
-/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (start end_ : String) : IO (Except String Snapshot) := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    return .error "loam: budget window endpoints must be real YYYY-MM-DD calendar dates"
  if !validCapacityWindow start end_ then
    return .error "loam: budget window start must be earlier than end"

  let capacityPath := dataDir / "capacity.loam"
  let effectivePath := Loam.Persistence.capacityEffectivePathForMemory capacityPath
  let routingPath := dataDir / "actual-routing.loam"
  let correctionPath := dataDir / "corrections.loam"

  match ← requireFile capacityPath "Capacity authority" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile effectivePath "Capacity effective evidence" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile routingPath "Actual routing evidence" with
  | .error message => return .error message
  | .ok _ => pure ()

  let capacity ←
    match ← Loam.Persistence.loadCapacityMemory? capacityPath with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity authority"
  let effective ←
    match ← Loam.Persistence.loadCapacityEffectiveMemory? effectivePath with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity effective evidence"
  let movement ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? manifestRoot with
    | .ok world => pure world
    | .error message => return .error message
  let validities ←
    match admittedActualValidityMemory? movement.validity with
    | some memory => pure memory
    | none =>
        return .error
          "loam: Actual validity corrections do not justify one current date per Event"
  let corrections ←
    match ← loadCorrections? correctionPath with
    | .ok memory => pure memory
    | .error message => return .error message
  let routing ←
    match ← Loam.Persistence.loadActualRoutingHistory? routingPath with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Actual routing evidence"

  let purposes := Loam.CapacityReview.rememberedPurposes capacity
  match purposes.mapM (projectPurpose?
      capacity effective movement.events corrections validities routing start end_) with
  | none =>
      return .error "loam: canonical evidence does not justify this budget-window projection"
  | some rows =>
      return .ok { start := start, endExclusive := end_, rows := rows }

end Loam.BudgetWindowReview
