import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CurrentCoverageInspection
import Loam.CapacityReview
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence

namespace Loam.CurrentCoverageReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared current Capacity coverage review

This is the surface-independent production read boundary for the explicitly
current coverage question introduced by `CurrentCoverageInspection`.

It deliberately does not reuse Budget Window arithmetic. Capacity is all-retained,
Actual Consumption is correction-frontier and historical-routing aware, and
Scheduled pressure is replacement-aware current-open evidence due before the
explicit future `endExclusive` horizon.

`observedAt` selects the dated Scheduled-routing evidence visible to this current
answer. There is no historical `start` coordinate and no claim that Scheduled
lifecycle state can be replayed into the past.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  deriving Repr, DecidableEq

/-- JPY-wide Scheduled pressure that is not owned by one managed Purpose. -/
structure ScheduledFrontier where
  unmanaged : Quantity
  unrouted : Quantity
  unresolvedEligibility : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  observedAt : String
  endExclusive : String
  rows : List Row
  scheduledFrontier : Option ScheduledFrontier
  deriving Repr, DecidableEq

private structure ProjectedRow where
  row : Row
  frontier : ScheduledFrontier

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
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory String)
    (actualRouting : Loam.Persistence.ActualRoutingHistory)
    (scheduled : Loam.Persistence.ScheduledLifecycleImage)
    (roles : AccountingRoleMap)
    (scheduledRouting : ScheduledRoutingHistory String)
    (observedAt endExclusive : String)
    (purpose : PurposeId) : Option ProjectedRow := do
  let yen : MeasureId := ⟨"jpy"⟩
  let view ←
    currentCoverageAtCorrectionFrontierEffectiveRoutingWithReplacement?
      capacity.movements events corrections validities actualRouting
      scheduled.scheduled scheduled.completions scheduled.retirements scheduled.replacements
      roles scheduledRouting purpose yen observedAt endExclusive
  return {
    row := {
      purpose := purpose
      entitlement := view.entitlement
      consumption := view.consumption
      remaining := view.remaining
      commitment := view.commitment
      headroom := view.headroom
    }
    frontier := {
      unmanaged := view.unmanagedCommitment
      unrouted := view.unroutedCommitment
      unresolvedEligibility := view.unresolvedEligibility
    }
  }

private def consistentFrontier (rows : List ProjectedRow) : Bool :=
  match rows with
  | [] => true
  | first :: rest => rest.all (fun row => row.frontier == first.frontier)

/--
Load one immutable production evidence snapshot for an explicit current
observation date and future horizon.

Every canonical source needed by the answer is explicit and fail-closed. The
optional Event-correction stream preserves the established absent-as-empty policy.
No fallback to frozen Movement sidecars exists.
-/
def loadSnapshotAt
    (dataDir manifestRoot : System.FilePath)
    (observedAt endExclusive : String) : IO (Except String Snapshot) := do
  if !Loam.ActualDate.validIsoDate observedAt || !Loam.ActualDate.validIsoDate endExclusive then
    return .error "loam: current coverage coordinates must be real YYYY-MM-DD calendar dates"
  if !(observedAt < endExclusive) then
    return .error "loam: current coverage horizon must be later than the observation date"

  let capacityPath := dataDir / "capacity.loam"
  let actualRoutingPath := dataDir / "actual-routing.loam"
  let correctionPath := dataDir / "corrections.loam"
  let scheduledPath := dataDir / "scheduled.loam"
  let scheduledRoutingPath := dataDir / "scheduled-routing.loam"
  let accountingRolePath := dataDir / "accounting-role.loam"

  match ← requireFile capacityPath "Capacity authority" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile actualRoutingPath "Actual routing evidence" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile scheduledPath "Scheduled lifecycle authority" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile scheduledRoutingPath "Scheduled routing evidence" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile accountingRolePath "AccountingRole evidence" with
  | .error message => return .error message
  | .ok _ => pure ()

  let capacity ←
    match ← Loam.Persistence.loadCapacityMemory? capacityPath with
    | some memory => pure memory
    | none => return .error "loam: malformed or unsupported Capacity authority"
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
  let actualRouting ←
    match ← Loam.Persistence.loadActualRoutingHistory? actualRoutingPath with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Actual routing evidence"
  let scheduled ←
    match ← Loam.Persistence.loadScheduledLifecycleImage? scheduledPath with
    | some image => pure image
    | none => return .error "loam: malformed or unsupported Scheduled lifecycle authority"
  let scheduledRouting ←
    match ← Loam.Persistence.loadScheduledRoutingHistory? scheduledRoutingPath with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Scheduled routing evidence"
  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? accountingRolePath with
    | some roleMap => pure roleMap
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  let purposes := Loam.CapacityReview.rememberedPurposes capacity
  match purposes.mapM (projectPurpose?
      capacity movement.events corrections validities actualRouting
      scheduled roles scheduledRouting observedAt endExclusive) with
  | none =>
      return .error "loam: canonical evidence does not justify this current coverage projection"
  | some projected =>
      if !consistentFrontier projected then
        return .error "loam: Scheduled pressure frontier changed across Purpose projections"
      return .ok {
        observedAt := observedAt
        endExclusive := endExclusive
        rows := projected.map (fun projectedRow => projectedRow.row)
        scheduledFrontier := projected.head?.map (fun projectedRow => projectedRow.frontier)
      }

/-- Production wrapper resolving only the current local observation date. -/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (endExclusive : String) : IO (Except String Snapshot) := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local observation date"
  loadSnapshotAt dataDir manifestRoot observedAt endExclusive

end Loam.CurrentCoverageReview
