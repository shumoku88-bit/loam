import Loam.Tui.CycleBudget
import Loam.CurrentCoverageReview
import Loam.Application.ScheduledCommitmentInspection

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
  for (purpose, expected) in [("食費", 20328), ("食費:ストック", 0), ("一般生活", 0),
      ("タバコ", 16500), ("固定費予定", 8730), ("通院", 1510)] do
    let some row := coverage.rows.find? (fun row => row.purpose.token == purpose)
      | throw (IO.userError ("missing Purpose: " ++ purpose))
    unless row.remaining.quanta == expected do throw (IO.userError ("Now changed: " ++ purpose))

  -- Stage D1 dogfood checkpoint: subject-level unresolved Scheduled pressure
  -- parity with aggregate unresolvedEligibility.
  let .ok window := snapshot.window | throw (IO.userError "window unavailable")
  let some frontier := coverage.scheduledFrontier | throw (IO.userError "missing Scheduled frontier")
  let some scheduled ← Loam.Persistence.loadScheduledLifecycleImage? (dataDir / "scheduled.loam")
    | throw (IO.userError "scheduled authority failed")
  let some scheduledRouting ← Loam.Persistence.loadScheduledRoutingHistory? (dataDir / "scheduled-routing.loam")
    | throw (IO.userError "scheduled routing failed")
  let some roles ← Loam.Persistence.loadAccountingRoleMap? (dataDir / "accounting-role.loam")
    | throw (IO.userError "accounting roles failed")
  let .ok movement ← Loam.MovementManifestAuthority.loadSelectedWorld? (dataDir / "movement-authority")
    | throw (IO.userError "movement authority failed")
  let some unresolvedRows :=
    Loam.Application.currentUnresolvedScheduledPressureWithReplacement?
      scheduled.scheduled scheduled.completions scheduled.retirements scheduled.replacements
      movement.events roles scheduledRouting ⟨"jpy"⟩ snapshot.observedAt window.endExclusive
    | throw (IO.userError "unresolved rows failed closed")
  unless unresolvedRows.length == 1 do
    throw (IO.userError s!"expected 1 unresolved row, got {unresolvedRows.length}")
  let some wifiRow := unresolvedRows.head? | throw (IO.userError "missing unresolved row")
  unless wifiRow.subject.scheduled.token == "scheduled-12" &&
      wifiRow.subject.locus.token == "wifi" &&
      wifiRow.scheduledOn == "2026-10-08" &&
      wifiRow.measure.token == "jpy" &&
      wifiRow.quantity.quanta == 4810 do
    throw (IO.userError s!"dogfood unresolved row mismatch: {repr wifiRow}")
  let unresolvedSum := (unresolvedRows.map (fun r => r.quantity.quanta)).sum
  unless unresolvedSum == 4810 do
    throw (IO.userError s!"expected unresolved rows sum 4810, got {unresolvedSum}")
  unless unresolvedSum == frontier.unresolvedEligibility.quanta do
    throw (IO.userError s!"parity failed: rows sum {unresolvedSum} ≠ frontier {frontier.unresolvedEligibility.quanta}")

  let view := Loam.Tui.CycleBudget.view { width := 120, height := 40 } { snapshot := snapshot }
  IO.println (String.intercalate "\n" (view.lines.map fun cells => String.ofList (cells.map Cell.glyph)))
  IO.println "Read-only cycle Budget dogfood checkpoint passed (not SafeToSpend)."
