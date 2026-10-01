import Loam.Review.BudgetWindowReview
import Loam.Persistence.TokenSyntax

namespace Loam.BudgetWindowCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage: loamBudgetWindow DATA_ROOT START END PURPOSE|--all\n" ++
  "\n" ++
  "Projects single-Measure Entitlement, routed Actual Consumption, and Remaining over the\n" ++
  "half-open coordinate window [START, END). --all reuses the same projection\n" ++
  "for every Purpose already represented by Capacity evidence. LOAM_MEASURE selects\n" ++
  "the Measure and defaults to jpy. No Period or Remaining state is stored."

private def printOne
    (measure : MeasureId)
    (start end_ : String)
    (row : Loam.BudgetWindowReview.Row) : IO Unit := do
  IO.println ("Budget window [" ++ start ++ ", " ++ end_ ++ ")")
  IO.println ("Purpose: " ++ row.purpose.token)
  IO.println ("Entitlement: " ++ toString row.entitlement.quanta ++ " " ++ measure.token)
  IO.println ("Consumption: " ++ toString row.consumption.quanta ++ " " ++ measure.token)
  IO.println ("Remaining: " ++ toString row.remaining.quanta ++ " " ++ measure.token)

private def printAll
    (snapshot : Loam.BudgetWindowReview.Snapshot) : IO Unit := do
  IO.println
    ("Budget window [" ++ snapshot.start ++ ", " ++ snapshot.endExclusive ++ ")")
  if snapshot.rows.isEmpty then
    IO.println "No spending-purpose capacity."
  else
    IO.println "Purposes:"
    for row in snapshot.rows do
      IO.println
        ("  " ++ row.purpose.token ++
          ": entitlement " ++ toString row.entitlement.quanta ++
          " " ++ snapshot.measure.token ++ ", consumption " ++ toString row.consumption.quanta ++
          " " ++ snapshot.measure.token ++ ", remaining " ++ toString row.remaining.quanta ++
          " " ++ snapshot.measure.token)

private def configuredMeasure : IO (Except String MeasureId) := do
  let token := (← IO.getEnv "LOAM_MEASURE").getD "jpy"
  if !Loam.Persistence.validToken token then
    return .error "loam: Measure must be a nonempty single-line token"
  return .ok ⟨token⟩

/--
Render the shared production Budget Window review through the standalone line CLI.

The CLI owns only argument parsing and text presentation. Canonical evidence
loading, ActualValidity resolution, Purpose projection, and derived Remaining
all belong to `BudgetWindowReview`.
-/
def reportForMeasure
    (measure : MeasureId)
    (rootPath start end_ purposeToken : String) : IO UInt32 := do
  if purposeToken != "--all" && !Loam.Persistence.validToken purposeToken then
    IO.eprintln "loam: budget Purpose must be a nonempty single-line token or --all"
    return 2
  else
    let root := System.FilePath.mk rootPath
    if purposeToken = "--all" then
      match ← Loam.BudgetWindowReview.loadSnapshotForMeasure measure root root start end_ with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok snapshot =>
          printAll snapshot
          return 0
    else
      let purpose : PurposeId := ⟨purposeToken⟩
      match ← Loam.BudgetWindowReview.loadPurposeRowForMeasure measure root root start end_ purpose with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok row =>
          printOne measure start end_ row
          return 0

def report
    (rootPath start end_ purposeToken : String) : IO UInt32 := do
  match ← configuredMeasure with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok measure =>
      reportForMeasure measure rootPath start end_ purposeToken

/-- Command dispatcher for the shared production Budget Window projection. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, start, end_, purpose] =>
      report rootPath start end_ purpose
  | _ => do
      IO.eprintln usage
      return 2

end Loam.BudgetWindowCli
