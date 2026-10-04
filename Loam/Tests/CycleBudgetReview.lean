import Loam.Tests.ActualWorldFixture
import Loam.Review.CycleBudgetReview
import Loam.Authority.HouseholdAuthority

open Loam.Core
private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)
private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

/-- Isolated synthetic evidence; never touches household data. Also serves the PTY test. -/
def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "supply isolated fixture directory")
  let root := System.FilePath.mk path
  IO.FS.createDirAll (root / "config")

  -- 1. Minimal synthetic evidence
  let fundingPath := root / "config" / "cycle-funding.tsv"
  let config := "cash\tjpy\n"
  expect ((Loam.CycleFundingConfig.decode? config).isSome) "valid config"
  expect (Loam.CycleFundingConfig.decode? "" == some []) "empty config not explicit empty selection"
  expect
    ((Loam.CycleFundingConfig.decodeForMeasure? ⟨"usd"⟩ "cash\tusd\n").isSome)
    "valid USD funding config"
  expect
    ((Loam.CycleFundingConfig.decodeForMeasure? ⟨"usd"⟩ "cash\tjpy\n").isNone)
    "USD funding config accepted JPY backing"
  for invalid in ["cash\tjpy\ncash\tjpy\n", "cash\tusd\n", "cash\t\n", "\tjpy\n",
      "cash\tjpy\textra\n", "cash\njpy\n", "cash\tjpy\r\n"] do
    expect ((Loam.CycleFundingConfig.decode? invalid).isNone) ("bad config admitted: " ++ invalid)
  expect (!(← Loam.CycleFundingConfig.load fundingPath).isOk) "missing config became empty"
  IO.FS.writeFile (root / "config" / "boundary-presets.tsv") "Pension\t2026-08-14\t2026-10-15\n"
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "cash\tjpy\nyucho\tjpy\n"
  let world : Loam.MovementAdmission.World := {
    events := { events := [], idNodup := by simp }
    validity := { facts := [], factRefNodup := by simp, corrections := [], correctionIdNodup := by simp }
    descriptions := .empty, relations := [], discharges := []
    locusAdmission := Loam.Core.LocusAdmissionVocabulary.empty }
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root world
    | throw (IO.userError "publish fixture world")
  -- yucho keeps historical zero-origin support, while cash is deliberately
  -- current-only. This fixture proves current Cycle Budget/Funding no longer
  -- require historical completeness for cash.
  let zero ← requireSome (ZeroOriginCoverage.ofCoordinates?
    [⟨⟨"yucho"⟩, ⟨"jpy"⟩⟩]) "coverage"
  expect (← Loam.Persistence.saveZeroOriginCoverage? (root / "zero-origin-coverage.loam") zero)
    "save zero-origin"
  IO.FS.writeFile (root / "current-quantity-anchor.loam")
    ("LOAM-CURRENT-QUANTITY-ANCHOR\t1\n" ++
     "ASSERT\tcash\tjpy\t0\n" ++
     "ASSERT\tcash\tusd\t250\n")
  let capacityFixture :=
    ("LOAM-NORMALIZED-CAPACITY\t1\n" ++
     "MOVEMENT\tcapacity-1\t2026-09-08\tjpy\n" ++
     "CHANGE\tUNALLOCATED\t-100\n" ++
     "CHANGE\tPURPOSE\tfood\t100\n" ++
     "ENDMOVEMENT\n" ++
     "MOVEMENT\tcapacity-2\t2026-09-08\tusd\n" ++
     "CHANGE\tUNALLOCATED\t-40\n" ++
     "CHANGE\tPURPOSE\tfood\t40\n" ++
     "ENDMOVEMENT\n")
  let .ok _ ←
      Loam.Tests.ActualWorldFixture.publishHouseholdSection?
        root "Capacity" capacityFixture
    | throw (IO.userError "install CycleBudget Household Capacity")
  let capacityGeneration ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => throw (IO.userError message)
  expect (!(← (root / "capacity.loam").pathExists))
    "CycleBudget fixture unexpectedly retained legacy Capacity"
  IO.FS.writeFile (root / "actual-routing.loam") "LOAM-ACTUAL-ROUTING\t1\n"
  IO.FS.writeFile (root / "scheduled-routing.loam") "LOAM-SCHEDULED-ROUTING\t1\n"
  IO.FS.writeFile (root / "accounting-role.loam") "LOAM-ACCOUNTING-ROLE-MAP\t1\n"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? []) "scheduled"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? []) "terminals"
  expect (← Loam.Persistence.saveScheduledLifecycleImage? (root / "scheduled.loam")
    { scheduled, terminals }) "save lifecycle"
  let load := Loam.CycleBudgetReview.loadSnapshotAt root root "2026-09-08"
  let missing ← load
  expect (missing.coverage.isOk && missing.physical.isOk && !missing.funding.isOk)
    "missing funding config damaged independent layers"
  IO.FS.writeFile fundingPath config
  let good ← load
  let .ok summary := good.funding | throw (IO.userError "valid funding unavailable")
  expect (summary.budgetableBacking.quanta == 0 && summary.remainingAssigned.quanta == 100 &&
    summary.residualBeforeUnresolved.quanta == -100) "shared projection changed"
  IO.FS.writeFile fundingPath "cash\tusd\n"
  let usdBudget ← Loam.CycleBudgetReview.loadSnapshotAtForMeasure ⟨"usd"⟩ root root "2026-09-08"
  expect (usdBudget.measure == ⟨"usd"⟩) "Cycle Budget lost the requested USD Measure"
  let .ok usdCoverage := usdBudget.coverage
    | throw (IO.userError "USD CurrentCoverage unavailable through Cycle Budget")
  expect (usdCoverage.measure == ⟨"usd"⟩) "Cycle Budget coverage Measure diverged"
  let .ok usdSummary := usdBudget.funding
    | throw (IO.userError "USD funding unavailable through Cycle Budget")
  expect
    (usdSummary.measure == ⟨"usd"⟩ &&
      usdSummary.budgetableBacking.quanta == 250 &&
      usdSummary.remainingAssigned.quanta == 40 &&
      usdSummary.residualBeforeUnresolved.quanta == 210)
    "USD Cycle Budget funding arithmetic diverged"
  IO.FS.writeFile fundingPath config
  for invalid in ["cash\tjpy\ncash\tjpy\n", "cash\tusd\n", "bad row\n"] do
    IO.FS.writeFile fundingPath invalid
    let bad ← load
    expect (bad.coverage.isOk && bad.physical.isOk && !bad.selection.isOk && !bad.funding.isOk)
      "malformed config did not isolate Funding refusal"
  IO.FS.writeFile fundingPath "unknown\tjpy\n"
  let unknown ← load
  expect (!unknown.funding.isOk && unknown.physical.isOk) "unknown backing inferred from display"
  IO.FS.writeFile fundingPath config
  -- Balance display is optional and not the funding authority.
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "bad row\n"
  let displayBad ← load
  expect (!displayBad.physical.isOk && displayBad.funding.isOk) "funding depended on display config"
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "cash\tjpy\nyucho\tjpy\n"
  let withoutCapacity : Loam.Persistence.HouseholdImage.Image := {
    sections := capacityGeneration.image.sections.filter
      (fun part => part.name != "Capacity")
  }
  let withoutCapacityWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? withoutCapacity)
    "encode missing-Capacity HouseholdImage fixture"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) withoutCapacityWire
  let unavailable ← load
  expect (!unavailable.coverage.isOk && !unavailable.funding.isOk && unavailable.physical.isOk)
    "missing Household Capacity did not refuse Funding independently"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) capacityGeneration.wire
  -- Filesystem exceptions also degrade, rather than escape the optional read layer.
  IO.FS.removeFile fundingPath
  IO.FS.createDirAll fundingPath
  let unreadable ← load
  expect (!unreadable.funding.isOk && unreadable.physical.isOk) "unreadable config crashed layer"
  IO.FS.removeDir fundingPath
  IO.FS.writeFile fundingPath config
  IO.println "CycleBudgetReview: current-anchor backing, explicit config and independent failures passed."
