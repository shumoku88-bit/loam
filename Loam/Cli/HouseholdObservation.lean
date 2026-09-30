import Loam.ActualDate
import Loam.Review.BalanceReview
import Loam.BalanceViewConfig
import Loam.BoundaryPresetConfig
import Loam.Review.BudgetWindowReview
import Loam.Review.CapacityReview
import Loam.Review.CycleBudgetReview
import Loam.HouseholdPaths
import Loam.Review.RoleBalanceReview
import Loam.Review.ScheduledCoverageReview

namespace Loam.HouseholdObservationCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage: loamHouseholdObservation DATA_ROOT START END [OBSERVED_AT]\n" ++
  "\n" ++
  "Emits Household Observation v1 (HOBS1) records for Balance, Budget, and\n" ++
  "Capacity over the explicit half-open budget window [START, END). When\n" ++
  "OBSERVED_AT is supplied, existing CycleBudget and ScheduledCoverage reads\n" ++
  "also emit LOAM-specific current-coverage, funding, and Scheduled-series\n" ++
  "diagnostics. The output is a\n" ++
  "read-only derived projection, never canonical household state."

private def emitRecord (fields : List String) : IO Unit :=
  IO.println (String.intercalate "\t" ("HOBS1" :: fields))

private def emitMeta (name value : String) : IO Unit :=
  emitRecord ["meta", name, value]

private def emitScalar (scope name unit value : String) : IO Unit :=
  emitRecord ["scalar", scope, name, unit, value]

private def emitDiagnostic (fields : List String) : IO Unit :=
  emitRecord ("diagnostic" :: fields)

private structure BalanceObservationRow where
  coordinate : EffectCoordinate
  quantity : Quantity
  originStatus : String

private def supportedQuantity?
    (snapshot : Loam.RoleBalanceReview.Snapshot)
    (coordinate : EffectCoordinate) : Option Quantity :=
  match snapshot.rows.find? fun row => decide (row.coordinate = coordinate) with
  | some row => some row.quantity
  | none =>
      match snapshot.unresolvedRoles.find? fun row => decide (row.coordinate = coordinate) with
      | some row => some row.quantity
      | none => none

/--
Load the configured current-balance question through the support-complete
RoleBalance boundary, then project only the replaceable balance-view selection.

This deliberately separates two facts that HOBS1 already has vocabulary for:

- `known-zero-origin`: the selected coordinate has explicit ZeroOriginCoverage;
- `unknown-origin`: its current quantity is supported by another qualified
  current support family, such as OpeningSupport or CurrentQuantityAnchor.

A selected coordinate with no current quantity support still refuses the whole
observation document rather than becoming an invented zero.
-/
private def loadBalanceRows
    (root : System.FilePath) : IO (Except String (List BalanceObservationRow)) := do
  let snapshot ←
    match ← Loam.RoleBalanceReview.loadSnapshot root root with
    | .error message => return .error message
    | .ok snapshot => pure snapshot

  let coverage ←
    match ← Loam.BalanceReview.loadCoverage (Loam.HouseholdPaths.zeroOriginCoverage root) with
    | .error message => return .error message
    | .ok coverage => pure coverage

  let coordinates ←
    match ← Loam.BalanceViewConfig.load? (Loam.HouseholdPaths.balanceView root) with
    | none => return .error "loam: malformed or unsupported balance-view config"
    | some selected => pure selected.eraseDups

  let mut rows : List BalanceObservationRow := []
  for coordinate in coordinates do
    let some quantity := supportedQuantity? snapshot coordinate
      | return .error
          ("loam: household observation balance unavailable: current quantity support missing for " ++
            coordinate.locus.token ++ " / " ++ coordinate.measure.token)
    let originStatus :=
      if coverage.covers coordinate then "known-zero-origin" else "unknown-origin"
    rows := rows ++ [{
      coordinate := coordinate
      quantity := quantity
      originStatus := originStatus
    }]
  return .ok rows

private def printBalance (rows : List BalanceObservationRow) : IO Unit := do
  for row in rows do
    emitRecord [
      "balance",
      row.coordinate.locus.token,
      row.coordinate.measure.token,
      toString row.quantity.quanta,
      row.originStatus,
      "-"
    ]

private def printBudget (snapshot : Loam.BudgetWindowReview.Snapshot) : IO Unit := do
  for row in snapshot.rows do
    emitRecord [
      "budget",
      row.purpose.token,
      "jpy",
      toString row.entitlement.quanta,
      toString row.consumption.quanta,
      toString row.remaining.quanta
    ]

  let totalEntitlement :=
    snapshot.rows.foldl (fun total row => total + row.entitlement.quanta) (0 : Int)
  let totalConsumption :=
    snapshot.rows.foldl (fun total row => total + row.consumption.quanta) (0 : Int)
  let totalRemaining :=
    snapshot.rows.foldl (fun total row => total + row.remaining.quanta) (0 : Int)

  emitScalar "budget" "total_entitlement" "jpy" (toString totalEntitlement)
  emitScalar "budget" "total_consumption" "jpy" (toString totalConsumption)
  emitScalar "budget" "total_remaining" "jpy" (toString totalRemaining)

private def printCapacity (snapshot : Loam.CapacityReview.Snapshot) : IO Unit := do
  for row in snapshot.rows do
    emitRecord [
      "capacity",
      "purpose",
      row.purpose.token,
      "jpy",
      toString row.entitlement.quanta
    ]


private structure CurrentDiagnostics where
  observedAt : String
  funding : Loam.CycleFundingInspection.Summary
  coverage : Loam.CurrentCoverageReview.Snapshot
  scheduled : Loam.ScheduledCoverageReview.Snapshot

private def loadCurrentDiagnostics
    (root : System.FilePath)
    (start observedAt end_ : String) :
    IO (Except String CurrentDiagnostics) := do
  let cycle ← Loam.CycleBudgetReview.loadSnapshotAt root root observedAt
  let window ←
    match cycle.window with
    | .error message => return .error message
    | .ok window => pure window
  if window.start != start || window.endExclusive != end_ then
    return .error
      ("loam: household observation current window mismatch: requested [" ++
        start ++ ", " ++ end_ ++ "), resolved [" ++ window.start ++ ", " ++
        window.endExclusive ++ ")")
  let funding ←
    match cycle.funding with
    | .error message => return .error message
    | .ok summary => pure summary
  let coverage ←
    match cycle.coverage with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let scheduled ←
    match ← Loam.ScheduledCoverageReview.loadSnapshot root root observedAt 18 with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  return .ok {
    observedAt := cycle.observedAt
    funding := funding
    coverage := coverage
    scheduled := scheduled
  }

private def printFunding
    (observedAt : String)
    (summary : Loam.CycleFundingInspection.Summary) : IO Unit := do
  emitMeta "funding_observed_at" observedAt
  emitScalar "funding" "budgetable_backing" "jpy"
    (toString summary.budgetableBacking.quanta)
  emitScalar "funding" "remaining_assigned" "jpy"
    (toString summary.remainingAssigned.quanta)
  emitScalar "funding" "residual_before_unresolved" "jpy"
    (toString summary.residualBeforeUnresolved.quanta)

private def printCurrentCoverage
    (snapshot : Loam.CurrentCoverageReview.Snapshot) : IO Unit := do
  emitMeta "coverage_observed_at" snapshot.observedAt
  emitMeta "coverage_window_start" snapshot.currentWindowStart
  emitMeta "coverage_end_exclusive" snapshot.endExclusive
  for row in snapshot.rows do
    emitDiagnostic [
      "current-coverage",
      row.purpose.token,
      "jpy",
      toString row.entitlement.quanta,
      toString row.consumption.quanta,
      toString row.commitment.quanta,
      toString row.remaining.quanta,
      toString row.headroom.quanta
    ]
  match snapshot.scheduledFrontier with
  | none =>
      emitScalar "coverage" "scheduled_frontier_available" "bool" "0"
  | some frontier =>
      emitScalar "coverage" "scheduled_frontier_available" "bool" "1"
      emitScalar "coverage" "scheduled_unmanaged" "jpy"
        (toString frontier.unmanaged.quanta)
      emitScalar "coverage" "scheduled_unrouted" "jpy"
        (toString frontier.unrouted.quanta)
      emitScalar "coverage" "scheduled_unresolved_eligibility" "jpy"
        (toString frontier.unresolvedEligibility.quanta)
  emitScalar "coverage" "unresolved_scheduled_rows" "count"
    (toString snapshot.unresolvedScheduled.length)
  emitScalar "coverage" "unrouted_actual_expense_rows" "count"
    (toString snapshot.actualRoutingFrontier.unroutedExpense.length)
  emitScalar "coverage" "unresolved_actual_role_rows" "count"
    (toString snapshot.actualRoutingFrontier.unresolvedRole.length)

private def scheduledDaysText (days : List String) : String :=
  if days.isEmpty then "-" else String.intercalate "," days

private def printScheduledCoverage
    (snapshot : Loam.ScheduledCoverageReview.Snapshot) : IO Unit := do
  emitMeta "scheduled_observed_at" snapshot.observedAt
  emitScalar "scheduled" "loaded_months" "count" (toString snapshot.months.length)
  match snapshot.months.head?, snapshot.months.getLast? with
  | some first, some last =>
      emitMeta "scheduled_window_first_month" first
      emitMeta "scheduled_window_last_month" last
  | _, _ => pure ()
  for row in snapshot.rows do
    emitDiagnostic [
      "scheduled-plan",
      row.rule.name,
      row.rule.anchor,
      toString row.rule.everyMonths,
      row.firstMissing.getD "-"
    ]
    for cell in row.cells do
      if cell.expected || !(cell.explicitCount == 0) then
        emitDiagnostic [
          "scheduled-cell",
          row.rule.name,
          cell.month,
          if cell.expected then "expected" else "not-expected",
          toString cell.explicitCount,
          scheduledDaysText cell.explicitDays
        ]

/--
Emit one complete HOBS1 document. All requested shared production queries are
loaded before stdout is touched, so a semantic or persistence refusal cannot masquerade
as a complete observation document. Consumers should additionally require the
terminal `meta status complete` record to detect stream truncation.
-/
def report (rootPath start end_ : String) (observedAt? : Option String := none) : IO UInt32 := do
  let root := System.FilePath.mk rootPath

  let balances ←
    match ← loadBalanceRows root with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok rows => pure rows

  let budget ←
    match ← Loam.BudgetWindowReview.loadSnapshot root root start end_ with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot => pure snapshot

  let capacity ←
    match ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot root with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot => pure snapshot

  let diagnostics? ←
    match observedAt? with
    | none => pure none
    | some observedAt =>
        match ← loadCurrentDiagnostics root start observedAt end_ with
        | .error message =>
            IO.eprintln message
            return 2
        | .ok diagnostics => pure (some diagnostics)

  emitMeta "schema" "1"
  emitMeta "implementation" "loam"
  emitMeta "snapshot_kind" "composed-current-read"
  emitMeta "window_start" budget.start
  emitMeta "window_end_exclusive" budget.endExclusive
  emitMeta "balance_scope" "configured"
  emitMeta "capacity_scope" "purpose-only"

  printBalance balances
  printBudget budget
  printCapacity capacity
  match diagnostics? with
  | none => pure ()
  | some diagnostics =>
      printFunding diagnostics.observedAt diagnostics.funding
      printCurrentCoverage diagnostics.coverage
      printScheduledCoverage diagnostics.scheduled

  emitMeta "status" "complete"
  return 0

private def defaultDataRoot : IO (Except String String) := do
  match ← IO.getEnv "LOAM_DATA_DIR" with
  | some path =>
      if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
      return .ok path
  | none => return .ok "../loam-data"

def reportCurrentAt (rootPath observedAt : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate observedAt then
    IO.eprintln "loam: household explanation observation date must be a real YYYY-MM-DD calendar date"
    return 2
  let root := System.FilePath.mk rootPath
  let window ←
    match ← Loam.BoundaryPresetConfig.loadCurrentWindow root observedAt with
    | .error message =>
        IO.eprintln ("loam: household explanation current window unavailable: " ++ message)
        return 2
    | .ok window => pure window
  report rootPath window.start window.endExclusive (some observedAt)

def reportCurrent (rootPath : String) : IO UInt32 := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | IO.eprintln "loam: could not determine the local household observation date"
      return 2
  reportCurrentAt rootPath observedAt

def runCurrentMachine (args : List String) : IO UInt32 := do
  match args with
  | ["--machine"] =>
      match ← defaultDataRoot with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok rootPath => reportCurrent rootPath
  | ["--machine", rootPath] =>
      if rootPath.isEmpty then
        IO.eprintln "loam: data directory must not be empty"
        return 2
      reportCurrent rootPath
  | ["--machine", "--at", observedAt] =>
      match ← defaultDataRoot with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok rootPath => reportCurrentAt rootPath observedAt
  | ["--machine", "--at", observedAt, rootPath] =>
      if rootPath.isEmpty then
        IO.eprintln "loam: data directory must not be empty"
        return 2
      reportCurrentAt rootPath observedAt
  | _ =>
      IO.eprintln
        "Usage: loam explain household --machine [--at YYYY-MM-DD] [LOAM_DATA_DIR]"
      return 2


/-- Command dispatcher for the standalone Household Observation executable. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, start, end_] =>
      report rootPath start end_
  | [rootPath, start, end_, observedAt] =>
      report rootPath start end_ (some observedAt)
  | _ => do
      IO.eprintln usage
      return 2

end Loam.HouseholdObservationCli
