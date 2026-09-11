import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CurrentCoverageInspection
import Loam.CapacityAuthority
import Loam.CapacityReview
import Loam.MovementManifestAuthority
import Loam.Persistence.EventCorrectionPersistence
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence
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

It deliberately does not turn this into the historical Budget Window report.
Capacity is effective within the closed current elapsed window; Actual Consumption is correction-frontier and
historical-routing aware inside the explicit current elapsed window, and
Scheduled pressure is current-open evidence from `observedAt` through the
explicit future `endExclusive` horizon.

`currentWindowStart` is retained from the selected boundary preset rather than
being discarded. Scheduled lifecycle state is current-open only; it is not
replayed into the past. Capacity movement and effective-coordinate meanings are
loaded through one local `CapacityAuthority` handle so this review does not know
their physical companion topology.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  deriving Repr, DecidableEq

structure ScheduledFrontier where
  unmanaged : Quantity
  unrouted : Quantity
  unresolvedEligibility : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  currentWindowStart : String
  observedAt : String
  endExclusive : String
  rows : List Row
  scheduledFrontier : Option ScheduledFrontier
  unresolvedScheduled : List (UnresolvedScheduledPressureRow String) := []
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
    (effective : CapacityEffectiveMemory String)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory String)
    (actualRouting : Loam.Persistence.ActualRoutingHistory)
    (scheduled : Loam.Persistence.ScheduledLifecycleImage)
    (roles : AccountingRoleMap)
    (scheduledRouting : ScheduledRoutingHistory String)
    (currentWindowStart observedAt endExclusive : String)
    (purpose : PurposeId) : Option ProjectedRow := do
  let yen : MeasureId := ⟨"jpy"⟩
  let view ←
    currentCoverageAtCorrectionFrontierEffectiveRouting?
      capacity effective events corrections validities actualRouting
      scheduled.scheduled scheduled.terminals roles scheduledRouting
      purpose yen currentWindowStart observedAt endExclusive
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
    (currentWindowStart observedAt endExclusive : String) : IO (Except String Snapshot) := do
  if !Loam.ActualDate.validIsoDate currentWindowStart ||
      !Loam.ActualDate.validIsoDate observedAt ||
      !Loam.ActualDate.validIsoDate endExclusive then
    return .error "loam: current coverage coordinates must be real YYYY-MM-DD calendar dates"
  if !(currentWindowStart <= observedAt) then
    return .error "loam: current coverage start must not be later than the observation date"
  if !(observedAt < endExclusive) then
    return .error "loam: current coverage horizon must be later than the observation date"

  let capacityPath := dataDir / "capacity.loam"
  let actualRoutingPath := dataDir / "actual-routing.loam"
  let correctionPath := dataDir / "corrections.loam"
  let scheduledPath := dataDir / "scheduled.loam"
  let scheduledRoutingPath := dataDir / "scheduled-routing.loam"
  let accountingRolePath := dataDir / "accounting-role.loam"

  let capacityImage ←
    match ← Loam.CapacityAuthority.loadRequired capacityPath with
    | .ok image => pure image
    | .error message => return .error message
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

  let capacity := capacityImage.movements
  let effective := capacityImage.effective
  if !capacityEffectiveEvidenceComplete capacity effective then
    return .error "loam: incomplete Capacity effective evidence"
  let movement ←
    match ← Loam.MovementManifestAuthority.loadSelectedEvidence? manifestRoot with
    | .ok evidence => pure evidence
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

  let unresolvedScheduled ←
    match currentActionableScheduledPressure?
        scheduled.scheduled scheduled.terminals movement.events roles scheduledRouting
        ⟨"jpy"⟩ observedAt endExclusive with
    | some rows => pure rows
    | none => return .error "loam: canonical evidence does not justify actionable Scheduled pressure"

  let purposes := Loam.CapacityReview.rememberedPurposes capacity
  match purposes.mapM (projectPurpose?
      capacity effective movement.events corrections validities actualRouting
      scheduled roles scheduledRouting currentWindowStart observedAt endExclusive) with
  | none =>
      return .error "loam: canonical evidence does not justify this current coverage projection"
  | some projected =>
      if !consistentFrontier projected then
        return .error "loam: Scheduled pressure frontier changed across Purpose projections"
      return .ok {
        currentWindowStart := currentWindowStart
        observedAt := observedAt
        endExclusive := endExclusive
        rows := projected.map (fun projectedRow => projectedRow.row)
        scheduledFrontier := projected.head?.map (fun projectedRow => projectedRow.frontier)
        unresolvedScheduled := unresolvedScheduled
      }

/-- Production wrapper resolving only the current local observation date. -/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (currentWindowStart endExclusive : String) : IO (Except String Snapshot) := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local observation date"
  loadSnapshotAt dataDir manifestRoot currentWindowStart observedAt endExclusive

end Loam.CurrentCoverageReview
