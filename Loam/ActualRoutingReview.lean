import Loam.ActualDate
import Loam.CapacityReview
import Loam.Core.AccountingRole
import Loam.Core.RoutingEffective
import Loam.LocusAdmissionAuthority
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence

namespace Loam.ActualRoutingReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Current Actual routing administration review

This read boundary answers the practical administration question:

> For every currently admitted Locus explicitly classified as an Expense, what
> Purpose routing is visible now, and which expense Loci are still unrouted?

The review does not infer Expense from spelling or sign. It requires explicit
AccountingRole evidence, the current LocusAdmission policy, and the existing
historical Actual-routing authority. Purpose candidates come only from retained
Capacity evidence.
-/

structure Row where
  locus : LocusId
  status : RoutingStatus
  deriving Repr, DecidableEq

structure Snapshot where
  observedAt : String
  rows : List Row
  purposes : List PurposeId
  unresolvedRoleLoci : List LocusId
  historicalOnlyRouteLoci : List LocusId
  deriving Repr, DecidableEq

private def isApproved (approved : List LocusId) (locus : LocusId) : Bool :=
  approved.any fun current => decide (current = locus)

private def distinctSubjects (history : ActualRoutingHistory) : List LocusId :=
  history.entries.map (fun entry => entry.subject) |>.eraseDups

/-- Count current explicitly-Expense Loci with no routing evidence visible now. -/
def unroutedCount (snapshot : Snapshot) : Nat :=
  (snapshot.rows.filter fun row => row.status == .unrouted).length

/--
Load the current administration snapshot from production authority boundaries.

Only currently admitted Loci with explicit `AccountingRole.expense` become
routing rows. Current admitted Loci with no AccountingRole evidence remain
visible separately rather than being guessed into or out of the budget surface.
-/
def loadSnapshot
    (dataDir manifestRoot : System.FilePath)
    (observedAt : String) : IO (Except String Snapshot) := do
  if !Loam.ActualDate.validIsoDate observedAt then
    return .error "loam: Actual routing review date must be a real YYYY-MM-DD calendar date"

  let routingPath := dataDir / "actual-routing.loam"
  let rolesPath := dataDir / "accounting-role.loam"
  if !(← routingPath.pathExists) then
    return .error "loam: required Actual routing evidence is missing"
  if !(← rolesPath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"

  let admission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? manifestRoot with
    | .ok vocabulary => pure vocabulary
    | .error message => return .error message
  let history ←
    match ← loadActualRoutingHistory? routingPath with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Actual routing evidence"
  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"
  let capacity ←
    match ← Loam.CapacityReview.loadSnapshot (dataDir / "capacity.loam") with
    | .ok snapshot => pure snapshot
    | .error message => return .error message

  let effective := RoutingEffective.dated observedAt
  let approved := admission.approved
  let rows := approved.filterMap fun locus =>
    match roles.roleOf? locus with
    | some .expense => some { locus := locus, status := history.statusAt locus effective }
    | _ => none
  let unresolvedRoleLoci := approved.filter fun locus => (roles.roleOf? locus).isNone
  let historicalOnlyRouteLoci :=
    (distinctSubjects history).filter fun locus => !isApproved approved locus
  let purposes := capacity.rows.map (fun row => row.purpose) |>.eraseDups

  return .ok {
    observedAt := observedAt
    rows := rows
    purposes := purposes
    unresolvedRoleLoci := unresolvedRoleLoci
    historicalOnlyRouteLoci := historicalOnlyRouteLoci
  }

end Loam.ActualRoutingReview
