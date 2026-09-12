import Loam.ActualAuthority
import Loam.CycleBudgetReview

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
  let .ok _ ← Loam.ActualAuthority.publishWorld? root world
    | throw (IO.userError "publish fixture world")
  let zero ← requireSome (ZeroOriginCoverage.ofCoordinates?
    [⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, ⟨⟨"yucho"⟩, ⟨"jpy"⟩⟩]) "coverage"
  expect (← Loam.Persistence.saveZeroOriginCoverage? (root / "zero-origin-coverage.loam") zero)
    "save zero-origin"
  IO.FS.writeFile (root / "capacity.loam")
    "LOAM-CAPACITY-MEMORY\t1\nMOVEMENT\tcapacity-1\tjpy\nCHANGE\tUNALLOCATED\t-100\nCHANGE\tPURPOSE\tfood\t100\n"
  IO.FS.writeFile (root / "capacity.loam.effective")
    "LOAM-CAPACITY-EFFECTIVE\t1\nEFFECTIVE\tcapacity-1\t2026-09-08\n"
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
  IO.FS.removeFile (root / "capacity.loam.effective")
  let unavailable ← load
  expect (!unavailable.coverage.isOk && !unavailable.funding.isOk && unavailable.physical.isOk)
    "missing CurrentCoverage did not refuse Funding independently"
  IO.FS.writeFile (root / "capacity.loam.effective")
    "LOAM-CAPACITY-EFFECTIVE\t1\nEFFECTIVE\tcapacity-1\t2026-09-08\n"
  -- Filesystem exceptions also degrade, rather than escape the optional read layer.
  IO.FS.removeFile fundingPath
  IO.FS.createDirAll fundingPath
  let unreadable ← load
  expect (!unreadable.funding.isOk && unreadable.physical.isOk) "unreadable config crashed layer"
  IO.FS.removeDir fundingPath
  IO.FS.writeFile fundingPath config
  IO.println "CycleBudgetReview: explicit config and independent production read failures passed."
