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

This read boundary keeps the existing default administration question:

> For every currently admitted Locus explicitly classified as an Expense, what
> Purpose routing is visible now, and which Expense Loci are still unrouted?

It also exposes a separate optional list of currently admitted Loci with a known
non-Expense AccountingRole. Those rows are not routing obligations and do not
contribute to the default Expense unrouted count; they exist only so a human can
deliberately route an Asset/Income/Liability/Equity Locus when a generic Purpose
such as savings or investment contribution requires it.

The review does not infer routing relevance from spelling or sign. Unknown-role
Loci remain separately visible, historical-only routes remain separate, and
Purpose candidates come only from retained Capacity evidence.
-/

structure Row where
  locus : LocusId
  role : AccountingRole
  status : RoutingStatus
  deriving Repr, DecidableEq

structure Snapshot where
  observedAt : String
  rows : List Row
  otherRows : List Row
  purposes : List PurposeId
  unresolvedRoleLoci : List LocusId
  historicalOnlyRouteLoci : List LocusId
  deriving Repr, DecidableEq

private def isApproved (approved : List LocusId) (locus : LocusId) : Bool :=
  approved.any fun current => decide (current = locus)

private def distinctSubjects (history : ActualRoutingHistory) : List LocusId :=
  history.entries.map (fun entry => entry.subject) |>.eraseDups

private structure RolePartitions where
  rows : List Row
  otherRows : List Row
  unresolvedRoleLoci : List LocusId

/--
Classify each currently admitted Locus exactly once by retained AccountingRole.
The partition preserves admission order while keeping Expense obligations,
known optional non-Expense rows, and unresolved-role diagnostics distinct.
-/
private def partitionApproved
    (approved : List LocusId)
    (roles : AccountingRoleMap)
    (history : ActualRoutingHistory)
    (effective : RoutingEffective String) : RolePartitions :=
  approved.foldr
    (fun locus partitions =>
      match roles.roleOf? locus with
      | some .expense =>
          { partitions with
            rows :=
              { locus := locus
                role := .expense
                status := history.statusAt locus effective } :: partitions.rows }
      | some role =>
          { partitions with
            otherRows :=
              { locus := locus
                role := role
                status := history.statusAt locus effective } :: partitions.otherRows }
      | none =>
          { partitions with
            unresolvedRoleLoci := locus :: partitions.unresolvedRoleLoci })
    { rows := [], otherRows := [], unresolvedRoleLoci := [] }

/-- Count only default explicitly-Expense Loci with no routing evidence visible now. -/
def unroutedCount (snapshot : Snapshot) : Nat :=
  (snapshot.rows.filter fun row => row.status == .unrouted).length

/--
Load the current administration snapshot from production authority boundaries.

`rows` preserves the existing default Expense-only administration surface.
`otherRows` contains only currently admitted Loci with an explicit known
non-Expense AccountingRole. Merely appearing there does not mean the Locus must
be routed; optional rows are a deliberate human-selection surface only.

Current admitted Loci with no AccountingRole evidence remain visible separately
rather than being guessed into either candidate list.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
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
    match ← Loam.LocusAdmissionAuthority.loadCurrent? actualRoot with
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
  let partitions := partitionApproved approved roles history effective
  let historicalOnlyRouteLoci :=
    (distinctSubjects history).filter fun locus => !isApproved approved locus
  let purposes := capacity.rows.map (fun row => row.purpose) |>.eraseDups

  return .ok {
    observedAt := observedAt
    rows := partitions.rows
    otherRows := partitions.otherRows
    purposes := purposes
    unresolvedRoleLoci := partitions.unresolvedRoleLoci
    historicalOnlyRouteLoci := historicalOnlyRouteLoci
  }

end Loam.ActualRoutingReview
