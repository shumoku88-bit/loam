import Loam.ActualAuthority
import Loam.ActualReview
import Loam.Application.CorrectionFrontierIndexed
import Loam.HouseholdPaths
import Loam.RoleFlowReview
import Loam.ScheduledActualOwnership
import Loam.ScheduledReview
import Loam.TransactionsFlowReview

namespace Loam.IncomeExpenseProvenanceReview

open Loam.Core

set_option autoImplicit false

/-!
# Income / Expense Scheduled-completion provenance

This boundary adds one read-only provenance lens to the existing RoleFlow answer.

It does not introduce a Fixed/Variable/Recurring classification. An Expense is
"Scheduled-linked" only when the current Actual Event belongs to a stable
correction root named by retained Scheduled completion evidence. Everything else
is "No Scheduled link" only when the Scheduled lifecycle image is available and
qualified. Missing or malformed Scheduled evidence makes the provenance overlay
Unknown without discarding the underlying Income / Expense answer.

Correction continuity is inherited from the existing production
`correctionRootTerminalEvents?` projection: a completion anchored at an original
Event root remains attached to that root's current corrected terminal.
-/

structure ExpensePartition where
  scheduledLinked : List Loam.RoleFlowReview.Row
  noScheduledLink : List Loam.RoleFlowReview.Row
  deriving Repr, DecidableEq

inductive ExpenseProvenance where
  | available (partition : ExpensePartition)
  | unknown (reason : String)
  deriving Repr, DecidableEq

structure Snapshot where
  roleFlow : Loam.RoleFlowReview.Snapshot
  expenseProvenance : ExpenseProvenance
  deriving Repr

/--
One immutable source image for one or more Income / Expense windows.

Scheduled lifecycle failure is retained as an overlay-level Unknown instead of
turning the already-qualified RoleFlow answer into a false negative or making
the entire report unavailable.
-/
structure Evidence where
  records : List Loam.ActualReview.Record
  roles : AccountingRoleMap
  rootedCurrent : List (EventId × Event)
  scheduledTerminals : Except String ScheduledTerminalMemory

private def currentEventRepresented
    (rooted : List (EventId × Event)) (id : EventId) : Bool :=
  rooted.any fun pair => decide (pair.2.id = id)

private def linkedCurrentEventIds
    (rooted : List (EventId × Event))
    (terminals : ScheduledTerminalMemory) : List EventId :=
  rooted.filterMap fun pair =>
    let root := pair.1
    let current := pair.2.id
    if (terminals.completionSourceForActual? root).isSome ||
        (terminals.completionSourceForActual? current).isSome then
      some current
    else
      none

private def eventLinked (linked : List EventId) (id : EventId) : Bool :=
  linked.any fun candidate => decide (candidate = id)

private def linkedQuantity
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (linked : List EventId)
    (coordinate : EffectCoordinate) : Quantity :=
  Quantity.ofQuanta <|
    flow.columns.foldl
      (fun total column =>
        if eventLinked linked column.event.id then
          total +
            (Event.quantityAt
              column.event coordinate.locus coordinate.measure).quanta
        else
          total)
      0

private def expensePartition
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roleFlow : Loam.RoleFlowReview.Snapshot)
    (rooted : List (EventId × Event))
    (terminals : ScheduledTerminalMemory) : Except String ExpensePartition := do
  if !(flow.columns.all fun column =>
      currentEventRepresented rooted column.event.id) then
    throw
      "loam: Expense Scheduled provenance is unavailable because a selected current Event has no admitted correction root"
  let linked := linkedCurrentEventIds rooted terminals
  let expenseRows :=
    roleFlow.rows.filter fun row => decide (row.role = AccountingRole.expense)
  let scheduledLinked := expenseRows.map fun row =>
    { row with quantity := linkedQuantity flow linked row.coordinate }
  let noScheduledLink := expenseRows.map fun row =>
    let linkedPart := linkedQuantity flow linked row.coordinate
    { row with
        quantity := Quantity.ofQuanta (row.quantity.quanta - linkedPart.quanta) }
  return { scheduledLinked, noScheduledLink }

/--
Project one window from one immutable source image.

The partition is exact by construction:
for each Expense coordinate,
  RoleFlow quantity = Scheduled-linked + No-Scheduled-link quantity.
-/
def project
    (evidence : Evidence)
    (start endExclusive : String) : Except String Snapshot := do
  let flow ←
    Loam.TransactionsFlowReview.project evidence.records start endExclusive
  let roleFlow := Loam.RoleFlowReview.project flow evidence.roles
  let expenseProvenance :=
    match evidence.scheduledTerminals with
    | .error message =>
        ExpenseProvenance.unknown message
    | .ok terminals =>
        match expensePartition flow roleFlow evidence.rootedCurrent terminals with
        | .ok partition => ExpenseProvenance.available partition
        | .error message => ExpenseProvenance.unknown message
  return { roleFlow, expenseProvenance }

private def loadEvidenceUnderOwnership
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .ok image => pure image
    | .error message => return .error message
  let roles ←
    match ← Loam.RoleFlowReview.loadRoleMap dataDir with
    | .ok roles => pure roles
    | .error message => return .error message
  let rootedCurrent ←
    match Loam.Application.correctionRootTerminalEvents?
        image.evidence.events image.evidence.corrections with
    | some rooted => pure rooted
    | none =>
        return .error
          "loam: admitted Actual image did not yield a correction-root/current-terminal projection"
  let scheduledTerminals ←
    match ← Loam.ScheduledReview.loadHouseholdEvidenceForEvents
        dataDir image.evidence.events with
    | .ok scheduled => pure (.ok scheduled.terminals)
    | .error message => pure (.error message)
  return .ok {
    records := Loam.ActualReview.recordsFromActualImage image
    roles := roles
    rootedCurrent := rootedCurrent
    scheduledTerminals := scheduledTerminals
  }

/--
Load one coherent Actual/Scheduled observation cut for Income / Expense.

The shared ownership order is reused so a Scheduled completion cannot be observed
half-published relative to its Actual endpoint. AccountingRole remains an
independent current authority exactly as in RoleFlowReview.
-/
def loadEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) :=
  Loam.ScheduledActualOwnership.withOwnership
    (Loam.HouseholdPaths.scheduled dataDir) actualRoot
    (loadEvidenceUnderOwnership dataDir actualRoot)

/-- Load and project one Income / Expense window with the provenance overlay. -/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let evidence ←
    match ← loadEvidence dataDir actualRoot with
    | .ok evidence => pure evidence
    | .error message => return .error message
  return project evidence start endExclusive

end Loam.IncomeExpenseProvenanceReview
