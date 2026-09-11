import Loam.BalanceReview
import Loam.BudgetWindowReview
import Loam.CapacityReview

namespace Loam.HouseholdObservationCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage: loamHouseholdObservation DATA_ROOT START END\n" ++
  "\n" ++
  "Emits Household Observation v1 (HOBS1) records for Balance, Budget, and\n" ++
  "Capacity over the explicit half-open budget window [START, END). The output\n" ++
  "is a read-only derived projection, never canonical household state."

private def movementManifestRoot?
    (root : System.FilePath) : IO (Except String System.FilePath) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      return .ok (System.FilePath.mk rootPath)
  | none =>
      return .ok (root / "movement-authority")

private def record (fields : List String) : IO Unit :=
  IO.println (String.intercalate "\t" ("HOBS1" :: fields))

private def meta (name value : String) : IO Unit :=
  record ["meta", name, value]

private def scalar (namespace name unit value : String) : IO Unit :=
  record ["scalar", namespace, name, unit, value]

private def printBalance (snapshot : Loam.BalanceReview.Snapshot) : IO Unit := do
  for row in snapshot.rows do
    record [
      "balance",
      row.coordinate.locus.token,
      row.coordinate.measure.token,
      toString row.quantity.quanta,
      "known-zero-origin",
      "-"
    ]

private def printBudget (snapshot : Loam.BudgetWindowReview.Snapshot) : IO Unit := do
  for row in snapshot.rows do
    record [
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

  scalar "budget" "total_entitlement" "jpy" (toString totalEntitlement)
  scalar "budget" "total_consumption" "jpy" (toString totalConsumption)
  scalar "budget" "total_remaining" "jpy" (toString totalRemaining)

private def printCapacity (snapshot : Loam.CapacityReview.Snapshot) : IO Unit := do
  for row in snapshot.rows do
    record [
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
  let movementRoot ←
    match ← movementManifestRoot? root with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok path => pure path

  let balances ←
    match ← Loam.BalanceReview.loadSnapshot root movementRoot with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot => pure snapshot

  let budget ←
    match ← Loam.BudgetWindowReview.loadSnapshot root movementRoot start end_ with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot => pure snapshot

  let capacity ←
    match ← Loam.CapacityReview.loadSnapshot (root / "capacity.loam") with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok snapshot => pure snapshot

  meta "schema" "1"
  meta "implementation" "loam"
  meta "snapshot_kind" "composed-current-read"
  meta "window_start" budget.start
  meta "window_end_exclusive" budget.endExclusive
  meta "balance_scope" "configured"
  meta "capacity_scope" "purpose-only"

  printBalance balances
  printBudget budget
  printCapacity capacity

  meta "status" "complete"
  return 0

end Loam.HouseholdObservationCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, start, end_] =>
      Loam.HouseholdObservationCli.report rootPath start end_
  | _ => do
      IO.eprintln Loam.HouseholdObservationCli.usage
      return 2
