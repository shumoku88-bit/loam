import Loam.BudgetWindowReview
import Loam.Persistence.TokenSyntax

namespace Loam.BudgetWindowCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage: loamBudgetWindow DATA_ROOT START END PURPOSE|--all\n" ++
  "\n" ++
  "Projects JPY Entitlement, routed Actual Consumption, and Remaining over the\n" ++
  "half-open coordinate window [START, END). --all reuses the same projection\n" ++
  "for every Purpose already represented by Capacity evidence. No Period or\n" ++
  "Remaining state is stored."

private def printOne
    (start end_ : String)
    (row : Loam.BudgetWindowReview.Row) : IO Unit := do
  IO.println ("Budget window [" ++ start ++ ", " ++ end_ ++ ")")
  IO.println ("Purpose: " ++ row.purpose.token)
  IO.println ("Entitlement: " ++ toString row.entitlement.quanta ++ " jpy")
  IO.println ("Consumption: " ++ toString row.consumption.quanta ++ " jpy")
  IO.println ("Remaining: " ++ toString row.remaining.quanta ++ " jpy")

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
          " jpy, consumption " ++ toString row.consumption.quanta ++
          " jpy, remaining " ++ toString row.remaining.quanta ++ " jpy")

/--
Render the shared production Budget Window review through the standalone line CLI.

The CLI owns only argument parsing and text presentation. Canonical evidence
loading, ActualValidity resolution, Purpose projection, and derived Remaining
all belong to `BudgetWindowReview`.
-/
def report
    (rootPath start end_ purposeToken : String) : IO UInt32 := do
  if purposeToken != "--all" && !Loam.Persistence.validToken purposeToken then
    IO.eprintln "loam: budget Purpose must be a nonempty single-line token or --all"
    return 2
  else
    let root := System.FilePath.mk rootPath
    if purposeToken = "--all" then
      match ← Loam.BudgetWindowReview.loadSnapshot root start end_ with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok snapshot =>
          printAll snapshot
          return 0
    else
      let purpose : PurposeId := ⟨purposeToken⟩
      match ← Loam.BudgetWindowReview.loadPurposeRow root start end_ purpose with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok row =>
          printOne start end_ row
          return 0

end Loam.BudgetWindowCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, start, end_, purpose] =>
      Loam.BudgetWindowCli.report rootPath start end_ purpose
  | _ => do
      IO.eprintln Loam.BudgetWindowCli.usage
      return 2
