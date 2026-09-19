import Loam.ActualAuthority
import Loam.ActualDate
import Loam.Application.CurrentCoverageInspection
import Loam.CapacityAuthority
import Loam.CapacityReview
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
replayed into the past. Capacity movement and effective-coordinate meanings are loaded through one
proof-carrying `CapacityAuthority` image. Actual Consumption reuses the current
Event frontier and current validity memory carried by `ActualAuthority.Image`;
the report performs no second Correction or ActualValidity admission.

Scheduled selection and routing/role classification are performed once for the
whole query. Purpose rows project only their managed Commitment from that shared
partition; query-global pressure frontiers are projected once beside the rows.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  commitment : Quantity
  deriving Repr, DecidableEq

/-- Current Remaining is uniquely derived from Entitlement and Consumption. -/
def Row.remaining (row : Row) : Quantity :=
  row.entitlement - row.consumption

/-- Current Headroom is uniquely derived from Remaining and managed Commitment. -/
def Row.headroom (row : Row) : Quantity :=
  row.remaining - row.commitment

@[simp] theorem Row.remaining_eq_components (row : Row) :
    row.remaining = row.entitlement - row.consumption :=
  rfl

@[simp] theorem Row.headroom_eq_components (row : Row) :
    row.headroom = (row.entitlement - row.consumption) - row.commitment :=
  rfl

structure ScheduledFrontier where
  unmanaged : Quantity
  unrouted : Quantity
  unresolvedEligibility : Quantity
  deriving Repr, DecidableEq

/--
Current-window Actual routing uncertainty relevant to the default routing
administration policy.

Known non-Expense unrouted rows stay outside this frontier: existing Actual
routing administration treats them as optional human choices rather than default
Purpose obligations.
-/
structure ActualRoutingFrontier where
  unroutedExpense : List (UnroutedActualRow String)
  unresolvedRole : List (UnroutedActualRow String)
  deriving Repr, DecidableEq

def ActualRoutingFrontier.empty : ActualRoutingFrontier :=
  { unroutedExpense := [], unresolvedRole := [] }

private def actualRoutingFrontier
    (rows : List (UnroutedActualRow String)) : ActualRoutingFrontier :=
  {
    unroutedExpense := rows.filter fun row => row.role == some .expense
    unresolvedRole := rows.filter fun row => row.role.isNone
  }

structure Snapshot where
  currentWindowStart : String
  observedAt : String
  endExclusive : String
  rows : List Row
  scheduledFrontier : Option ScheduledFrontier
  unresolvedScheduled : List (UnresolvedScheduledPressureRow String) := []
  actualRoutingFrontier : ActualRoutingFrontier := .empty
  deriving Repr, DecidableEq

private def requireFile (path : System.FilePath) (label : String) : IO (Except String Unit) := do
  if ← path.pathExists then return .ok ()
  return .error ("loam: required " ++ label ++ " not found: " ++ path.toString)

private def projectPurposeFromImage?
    (capacity : Loam.CapacityAuthority.Image)
    (actual : Loam.ActualAuthority.Image)
    (actualRouting : Loam.Persistence.ActualRoutingHistory)
    (pressure : ScheduledPressurePartition String)
    (currentWindowStart observedAt : String)
    (purpose : PurposeId) : Option Row := do
  let yen : MeasureId := ⟨"jpy"⟩
  let commitment := ScheduledPressurePartition.managedFor pressure purpose
  let consumption ←
    consumptionAtRecordedEffectiveRoutingThrough?
      actual.currentEvents actual.currentValidities actualRouting
      currentWindowStart observedAt purpose yen
  let entitlement ←
    entitlementAtAdmittedEffectiveThrough?
      capacity currentWindowStart observedAt purpose yen
  return {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
    commitment := commitment
  }

/--
Load one immutable production evidence snapshot for an explicit current
observation date and future horizon.

Every canonical source needed by the answer is explicit and fail-closed. The
optional Event-correction stream preserves the established absent-as-empty policy.
No fallback to frozen Movement sidecars exists.
-/
def loadSnapshotAt
    (dataDir actualRoot : System.FilePath)
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
  let path :=
    if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then actualRoot
    else Loam.ActualAuthority.actualPath actualRoot
  let actualImage ←
    match ← Loam.ActualAuthority.loadImageFile? path with
    | .ok image => pure image
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

  let actualUnrouted ←
    match unroutedActualRows?
        actualImage.currentEvents actualImage.currentValidities actualRouting roles
        currentWindowStart observedAt ⟨"jpy"⟩ with
    | some rows => pure rows
    | none =>
        return .error
          "loam: canonical evidence does not justify the current Actual routing frontier"
  let actualRoutingFrontier := actualRoutingFrontier actualUnrouted

  let pressure ←
    match currentScheduledPressurePartition?
        scheduled.scheduled scheduled.terminals actualImage.evidence.events roles scheduledRouting
        ⟨"jpy"⟩ observedAt endExclusive with
    | some partition => pure partition
    | none => return .error "loam: canonical evidence does not justify actionable Scheduled pressure"

  let unresolvedScheduled := ScheduledPressurePartition.actionableRows pressure
  let frontier : ScheduledFrontier := {
    unmanaged := ScheduledPressurePartition.unmanaged pressure
    unrouted := ScheduledPressurePartition.unrouted pressure
    unresolvedEligibility := ScheduledPressurePartition.unresolvedEligibility pressure
  }
  let purposes := Loam.CapacityReview.rememberedPurposes capacity
  match purposes with
  | [] =>
      return .ok {
        currentWindowStart := currentWindowStart
        observedAt := observedAt
        endExclusive := endExclusive
        rows := []
        scheduledFrontier := none
        unresolvedScheduled := unresolvedScheduled
        actualRoutingFrontier := actualRoutingFrontier
      }
  | _ =>
      match purposes.mapM (projectPurposeFromImage?
          capacityImage actualImage actualRouting
          pressure currentWindowStart observedAt) with
      | none =>
          return .error "loam: canonical evidence does not justify this current coverage projection"
      | some rows =>
          return .ok {
            currentWindowStart := currentWindowStart
            observedAt := observedAt
            endExclusive := endExclusive
            rows := rows
            scheduledFrontier := some frontier
            unresolvedScheduled := unresolvedScheduled
            actualRoutingFrontier := actualRoutingFrontier
          }

/-- Production wrapper resolving only the current local observation date. -/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (currentWindowStart endExclusive : String) : IO (Except String Snapshot) := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local observation date"
  loadSnapshotAt dataDir actualRoot currentWindowStart observedAt endExclusive

end Loam.CurrentCoverageReview
