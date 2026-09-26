import Loam.BalanceReview
import Loam.BalanceViewConfig
import Loam.BudgetWindowReview
import Loam.CapacityReview
import Loam.HouseholdPaths
import Loam.RoleBalanceReview

namespace Loam.HouseholdObservationCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage: loamHouseholdObservation DATA_ROOT START END\n" ++
  "\n" ++
  "Emits Household Observation v1 (HOBS1) records for Balance, Budget, and\n" ++
  "Capacity over the explicit half-open budget window [START, END). The output\n" ++
  "is a read-only derived projection, never canonical household state."

private def emitRecord (fields : List String) : IO Unit :=
  IO.println (String.intercalate "\t" ("HOBS1" :: fields))

private def emitMeta (name value : String) : IO Unit :=
  emitRecord ["meta", name, value]

private def emitScalar (scope name unit value : String) : IO Unit :=
  emitRecord ["scalar", scope, name, unit, value]

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

/--
Emit one complete HOBS1 document. All three shared production queries are loaded
before stdout is touched, so a semantic or persistence refusal cannot masquerade
as a complete observation document. Consumers should additionally require the
terminal `meta status complete` record to detect stream truncation.
-/
def report (rootPath start end_ : String) : IO UInt32 := do
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

  emitMeta "status" "complete"
  return 0

end Loam.HouseholdObservationCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, start, end_] =>
      Loam.HouseholdObservationCli.report rootPath start end_
  | _ => do
      IO.eprintln Loam.HouseholdObservationCli.usage
      return 2
