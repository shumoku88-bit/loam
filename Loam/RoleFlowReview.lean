import Loam.ActualAuthority
import Loam.ActualReview
import Loam.HouseholdPaths
import Loam.TransactionsFlowReview
import Loam.Persistence.AccountingRolePersistence

namespace Loam.RoleFlowReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Role-aware flow projection basis

This boundary is intentionally thinner than a named accounting report.
It overlays the explicit partial `AccountingRole` relation on the existing
correction-aware `TransactionsFlowReview` answer.

It does not read Actual independently, reimplement date-window selection,
recompute the correction frontier, introduce debit/credit semantics, or retain
P&L state. Missing AccountingRole evidence remains visible as individual Effect
witnesses so numerical cancellation cannot masquerade as classification
completeness.
-/

/-- One classified coordinate and its exact selected-window net quantity. -/
structure Row where
  coordinate : EffectCoordinate
  role : AccountingRole
  quantity : Quantity
  deriving Repr, DecidableEq

/-- One selected current Effect whose Locus has no AccountingRole evidence. -/
structure UnresolvedEffect where
  event : EventId
  date : String
  effect : Effect

/--
Shared role-aware flow answer. Role totals remain derived presentation values;
coordinate identity is preserved because Trial-Balance and detailed views must
not collapse distinct Loci prematurely.
-/
structure Snapshot where
  start : String
  endExclusive : String
  rows : List Row
  unresolvedEffects : List UnresolvedEffect

private def classifiedRows
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap) : List Row :=
  flow.rows.filterMap fun coordinate =>
    match roles.roleOf? coordinate.locus with
    | none => none
    | some role =>
        some {
          coordinate := coordinate
          role := role
          quantity := Loam.TransactionsFlowReview.rowTotal flow coordinate
        }

private def unresolvedEffects
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap) : List UnresolvedEffect :=
  flow.columns.flatMap fun column =>
    column.event.effects.filterMap fun effect =>
      match roles.roleOf? effect.locus with
      | some _ => none
      | none => some { event := column.event.id, date := column.date, effect := effect }

/-- Overlay explicit accounting roles on one already-admitted Transactions-Flow snapshot. -/
def project
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap) : Snapshot :=
  {
    start := flow.start
    endExclusive := flow.endExclusive
    rows := classifiedRows flow roles
    unresolvedEffects := unresolvedEffects flow roles
  }

/--
Load one role-aware flow answer from a caller-supplied admitted Actual image.

The explicit AccountingRole authority remains independently loaded. The selected
window is projected from the same Actual generation already owned by the caller.
-/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let rolesPath := Loam.HouseholdPaths.accountingRole dataDir
  if !(← rolesPath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"

  let flow ←
    match Loam.TransactionsFlowReview.project
        (Loam.ActualReview.recordsFromActualImage image) start endExclusive with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let roles ←
    match ← loadAccountingRoleMap? rolesPath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  return .ok (project flow roles)

/--
Load existing production flow evidence and the explicit AccountingRole authority,
then compose them. Missing or malformed role evidence fails closed.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadSnapshotFromActualImage dataDir image start endExclusive

end Loam.RoleFlowReview
