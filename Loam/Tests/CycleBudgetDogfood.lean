import Loam.Tui.CycleBudget

open Loam.Tui.Kernel

/-- Explicit read-only 2026-09-08 checkpoint, not a rolling household truth or spending permission. -/
def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "usage: CycleBudgetDogfood DATA_DIR")
  let dataDir := System.FilePath.mk path
  let snapshot ← Loam.CycleBudgetReview.loadSnapshotAt dataDir (dataDir / "movement-authority") "2026-09-08"
  let .ok funding := snapshot.funding | throw (IO.userError s!"Funding unavailable: {repr snapshot.funding}")
  unless funding.budgetableBacking.quanta == 76389 && funding.remainingAssigned.quanta == 47068 &&
      funding.residualBeforeUnresolved.quanta == 29321 && funding.unresolvedFuturePressure.quanta == 4810 do
    throw (IO.userError s!"Dogfood funding changed; investigate rather than update blindly: {repr funding}")
  let .ok physical := snapshot.physical | throw (IO.userError "physical unavailable")
  for (locus, expected) in [("cash", 909), ("paypay", 523), ("smbc", 74957)] do
    let some row := physical.rows.find? (fun row => row.coordinate.locus.token == locus)
      | throw (IO.userError ("missing physical row: " ++ locus))
    unless row.quantity.quanta == expected do throw (IO.userError ("physical changed: " ++ locus))
  let .ok coverage := snapshot.coverage | throw (IO.userError "coverage unavailable")
  for (purpose, expected) in [("食費", 20328), ("食費:ストック", -1180), ("一般生活", -5546),
      ("タバコ", 16500), ("固定費予定", 8730), ("通院", 1510)] do
    let some row := coverage.rows.find? (fun row => row.purpose.token == purpose)
      | throw (IO.userError ("missing Purpose: " ++ purpose))
    unless row.remaining.quanta == expected do throw (IO.userError ("Now changed: " ++ purpose))
  let view := Loam.Tui.CycleBudget.view { width := 120, height := 40 } { snapshot := snapshot }
  IO.println (String.intercalate "\n" (view.lines.map fun cells => String.ofList (cells.map Cell.glyph)))
  IO.println "Read-only cycle Budget dogfood checkpoint passed (not SafeToSpend)."
