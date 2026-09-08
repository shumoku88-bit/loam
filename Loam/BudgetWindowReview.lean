import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CapacityWindowInspection
import Loam.Application.ScheduledCommitmentInspection
import Loam.CapacityReview
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence

namespace Loam.BudgetWindowReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Budget Window review

This is the production read boundary for explicit half-open budget-window queries.
It follows the current authority topology instead of reviving frozen Movement
sidecars:

- Event / ActualValidity come from the selected Movement manifest generation;
- Capacity / CapacityEffective remain independent canonical streams;
- ActualRouting remains its independent canonical stream;
- Scheduled lifecycle and ScheduledRouting remain distinct required authorities;
- AccountingRole is read as the existing explicit partial classification;
- EventCorrection preserves the existing absent-as-empty read policy.

The caller supplies `[start, end)` and `observedAt` separately. `start` and `end`
bound Capacity/Actual window evidence. Scheduled pressure remains the qualified
current-open projection due before `end`; `observedAt` only selects the historical
ScheduledRouting evidence visible to that current answer. The module does not
pretend to rewind Scheduled lifecycle knowledge to `start`.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  deriving Repr, DecidableEq

/-- JPY-wide Scheduled pressure whose Purpose ownership is not managed. -/
structure ScheduledFrontier where
  unmanaged : Quantity
  unrouted : Quantity
  unresolvedEligibility : Quantity
  deriving Repr, DecidableEq

structure Snapshot where
  start : String
  endExclusive : String
  observedAt : String
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
    (effective : CapacityEffectiveMemory String)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory String)
    (actualRouting : Loam.Persistence.ActualRoutingHistory)
    (scheduled : Loam.Persistence.ScheduledLifecycleImage)
    (roles : AccountingRoleMap)
    (scheduledRouting : ScheduledRoutingHistory String)
    (start end_ observedAt : String)
    (purpose : PurposeId) : Option ProjectedRow := do
  let yen : MeasureId := ⟨"jpy"⟩
  let entitlement ← entitlementAtEffectiveWindow? capacity effective start end_ purpose yen
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      events corrections validities actualRouting start end_ purpose yen
  let commitment ←
    currentScheduledCommitmentWithReplacement?
      scheduled.scheduled scheduled.completions scheduled.retirements scheduled.replacements
      events roles scheduledRouting purpose yen observedAt end_
  let remaining := entitlement - consumption
  some {
    row := {
      purpose := purpose
      entitlement := entitlement
      consumption := consumption
      remaining := remaining
      commitment := commitment.managed
      headroom := remaining - commitment.managed
    }
    frontier := {
      unmanaged := commitment.unmanaged
      unrouted := commitment.unrouted
      unresolvedEligibility := commitment.unresolvedEligibility
    }
  }

private def consistentFrontier (rows : List ProjectedRow) : Bool :=
  match rows with
  | [] => true
  | first :: rest => rest.all (fun row => row.frontier == first.frontier)

/--
Load one immutable production evidence snapshot and answer an explicit JPY
`[start, end)` query for every Purpose represented by retained Capacity evidence.

`observedAt` is a separate current observation coordinate for ScheduledRouting.
Managed current-open Scheduled pressure due before `end` is subtracted from each
Purpose's window Remaining to derive Headroom. Measure-wide unmanaged, unrouted,
and unresolved eligibility pressure is published once at snapshot level instead
of being repeated as though each Purpose owned it.
-/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (start end_ observedAt : String) : IO (Except String Snapshot) := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ ||
      !Loam.ActualDate.validIsoDate observedAt then
    return .error "loam: budget window and observation coordinates must be real YYYY-MM-DD calendar dates"
  if !validCapacityWindow start end_ then
    return .error "loam: budget window start must be earlier than end"

  let capacityPath := dataDir / "capacity.loam"
  let effectivePath := Loam.Persistence.capacityEffectivePathForMemory capacityPath
  let actualRoutingPath := dataDir / "actual-routing.loam"
  let correctionPath := dataDir / "corrections.loam"
  let scheduledPath := dataDir / "scheduled.loam"
  let scheduledRoutingPath := dataDir / "scheduled-routing.loam"
  let accountingRolePath := dataDir / "accounting-role.loam"

  match ← requireFile capacityPath "Capacity authority" with
  | .error message => return .error message
  | .ok _ => pure ()
  match ← requireFile effectivePath "Capacity effective evidence" with
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
      capacity effective movement.events corrections validities actualRouting
      scheduled roles scheduledRouting start end_ observedAt) with
  | none =>
      return .error "loam: canonical evidence does not justify this budget-window Headroom projection"
  | some projected =>
      if !consistentFrontier projected then
        return .error "loam: Scheduled pressure frontier changed across Purpose projections"
      let frontier := projected.head?.map (fun row => row.frontier)
      return .ok {
        start := start
        endExclusive := end_
        observedAt := observedAt
        rows := projected.map (fun row => row.row)
        scheduledFrontier := frontier
      }

end Loam.BudgetWindowReview
