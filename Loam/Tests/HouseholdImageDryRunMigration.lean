import Loam.Migration.HouseholdImageDryRun
import Loam.Cli.HouseholdImageDryRunCli

namespace Loam.Tests.HouseholdImageDryRunMigration

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw (IO.userError message)

private def requireSome {α : Type}
    (value : Option α)
    (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def cleanupDir (root : System.FilePath) : IO Unit := do
  if ← root.pathExists then
    IO.FS.removeDirAll root

private def coherentActual : String :=
  String.intercalate "\n" [
    Loam.Persistence.normalizedActualHeaderV1,
    "TX\topening-event\t2026-09-01\tNODESC",
    "EFFECT\tcash\tjpy\t10000",
    "EFFECT\topening-offset\tjpy\t-10000",
    "ENDTX",
    "TX\tspend-event\t2026-10-02\tNODESC",
    "EFFECT\tcash\tjpy\t-2000",
    "EFFECT\tfood\tjpy\t2000",
    "ENDTX"
  ] ++ "\n"

private def coherentScheduled : String :=
  String.intercalate "\n" [
    Loam.Persistence.scheduledLifecycleHeader,
    "BEGIN\tScheduled",
    Loam.Persistence.scheduledMemoryHeader,
    "SCHEDULED\tscheduled-1\t2026-10-20\tjpy",
    "CHANGE\tcash\t-1000",
    "CHANGE\tfood\t1000",
    "END\tScheduled",
    "BEGIN\tCompletion",
    "LOAM-SCHEDULED-COMPLETION-MEMORY\t1",
    "END\tCompletion",
    "BEGIN\tRetirement",
    "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1",
    "END\tRetirement",
    "BEGIN\tReplacement",
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1",
    "END\tReplacement"
  ] ++ "\n"

private def coherentAttention : String :=
  String.intercalate "\n" [
    Loam.Persistence.attentionMemoryHeader,
    "ITEM\tattention-1\tDUE_ON\t2026-10-31\trenew-insurance"
  ] ++ "\n"

private def emptyAttention : IO String := do
  let items ← requireSome
    (AttentionMemory.ofItems? [])
    "empty Attention items were rejected"
  let closures ← requireSome
    (AttentionClosureMemory.ofClosures? [])
    "empty Attention closures were rejected"
  requireSome
    (Loam.Persistence.encodeAttentionMemory? items closures)
    "empty Attention did not encode"

private def writeFixture
    (root : System.FilePath)
    (attention : Option String) : IO Unit := do
  IO.FS.createDirAll root
  IO.FS.writeFile (Loam.HouseholdPaths.actual root) coherentActual
  IO.FS.writeFile (Loam.HouseholdPaths.scheduled root) coherentScheduled
  IO.FS.writeFile (Loam.HouseholdPaths.capacity root) <|
    String.intercalate "\n" [
      Loam.Persistence.normalizedCapacityHeader,
      "MOVEMENT\tcapacity-1\t2026-09-15\tjpy",
      "CHANGE\tUNALLOCATED\t-5000",
      "CHANGE\tPURPOSE\tfood-budget\t5000",
      "ENDMOVEMENT"
    ] ++ "\n"
  match attention with
  | some body =>
      IO.FS.writeFile (Loam.HouseholdPaths.attention root) body
  | none => pure ()
  IO.FS.writeFile (Loam.HouseholdPaths.actualRouting root) <|
    String.intercalate "\n" [
      Loam.Persistence.actualRoutingHeader,
      "ROUTE\tfood\tINITIAL\tMANAGED\tfood-budget"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.scheduledRouting root) <|
    String.intercalate "\n" [
      Loam.Persistence.scheduledRoutingHeader,
      "ROUTE\tscheduled-1\tfood\tFROM\t2026-10-01\tMANAGED\tfood-budget"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.accountingRole root) <|
    String.intercalate "\n" [
      "LOAM-ACCOUNTING-ROLE-MAP\t1",
      "ROLE\tcash\tASSET",
      "ROLE\topening-offset\tEQUITY",
      "ROLE\tfood\tEXPENSE",
      "ROLE\tsavings\tASSET",
      "ROLE\tdebt\tLIABILITY"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.locusAdmission root) <|
    String.intercalate "\n" [
      Loam.Persistence.locusAdmissionVocabularyHeader,
      "LOCUS\tcash",
      "LOCUS\topening-offset",
      "LOCUS\tfood",
      "LOCUS\tsavings",
      "LOCUS\tdebt"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.zeroOriginCoverage root) <|
    String.intercalate "\n" [
      Loam.Persistence.zeroOriginCoverageHeader,
      "COORDINATE\tfood\tjpy"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.openingSupport root) <|
    String.intercalate "\n" [
      "LOAM-OPENING-SUPPORT\t1",
      "OPENING\tcash\tjpy\topening-event"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.currentQuantityAnchor root) <|
    String.intercalate "\n" [
      "LOAM-CURRENT-QUANTITY-ANCHOR\t2",
      "GROUP",
      "ROOT\topening-event",
      "ROOT\tspend-event",
      "ASSERT\tsavings\tjpy\t3000",
      "END"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.currentQuantityPresence root) <|
    String.intercalate "\n" [
      "LOAM-CURRENT-QUANTITY-PRESENCE\t1",
      "ROOT\topening-event",
      "ROOT\tspend-event",
      "PRESENT\tdebt\tjpy"
    ] ++ "\n"
  IO.FS.writeFile (Loam.HouseholdPaths.boundedHistorySupport root) <|
    String.intercalate "\n" [
      Loam.Persistence.boundedHistorySupportHeader,
      "SUPPORT\tsavings\tjpy\t2026-09-01"
    ] ++ "\n"

  IO.FS.createDirAll (Loam.HouseholdPaths.configDir root)
  IO.FS.writeFile (Loam.HouseholdPaths.measurePresentation root)
    "# measure\tdecimal-scale\njpy\t0\nusd\t2\nils\t2\n"

private def probe : Loam.HouseholdImageDryRun.ReviewProbe := {
  currentWindowStart := "2026-09-01"
  observedAt := "2026-10-04"
  endExclusive := "2026-11-01"
}

private def decodedCandidate
    (report : Loam.HouseholdImageDryRun.Report) : IO Image := do
  let wire ← IO.FS.readFile report.candidatePath
  requireSome
    (Loam.Persistence.HouseholdImage.decode? wire)
    "dry-run candidate did not reopen"

private def runFullCase (base : System.FilePath) : IO Unit := do
  let source := base / "full"
  let scratch := base / "full-scratch"
  writeFixture source (some coherentAttention)

  let actualBefore ← IO.FS.readFile (Loam.HouseholdPaths.actual source)
  let configBefore ← IO.FS.readFile (Loam.HouseholdPaths.measurePresentation source)

  let report ← requireOk
    (← Loam.HouseholdImageDryRun.run source scratch probe)
    "full dry-run migration was refused"

  expect (report.presentSections.length == 13)
    "full dry-run did not retain all thirteen present sections"
  expect report.absentSections.isEmpty
    "full dry-run invented absent known sections"
  expect (← report.candidatePath.pathExists)
    "full dry-run did not leave an inspectable candidate"
  expect (!(← (Loam.HouseholdAuthority.path source).pathExists))
    "full dry-run installed household.loam into the source root"
  expect ((← IO.FS.readFile (Loam.HouseholdPaths.actual source)) == actualBefore)
    "full dry-run changed legacy Actual bytes"
  expect ((← IO.FS.readFile (Loam.HouseholdPaths.measurePresentation source)) == configBefore)
    "full dry-run changed source configuration"
  expect
    ((← IO.FS.readFile
      (Loam.HouseholdPaths.measurePresentation report.projectionRoot)) == configBefore)
    "dry-run projection did not mirror external config for Review comparison"

  let candidate ← decodedCandidate report
  expect (body? candidate "Attention" == some coherentAttention)
    "full dry-run changed Attention bytes in the candidate"

private def runPresentEmptyCase (base : System.FilePath) : IO Unit := do
  let source := base / "present-empty"
  let scratch := base / "present-empty-scratch"
  let empty ← emptyAttention
  writeFixture source (some empty)

  let report ← requireOk
    (← Loam.HouseholdImageDryRun.run source scratch probe)
    "present-empty dry-run migration was refused"
  let candidate ← decodedCandidate report
  expect (body? candidate "Attention" == some empty)
    "present-empty Attention was normalized to absence or changed"
  expect (!(report.absentSections.contains "Attention"))
    "present-empty Attention was reported absent"

private def runMissingCase (base : System.FilePath) : IO Unit := do
  let source := base / "missing"
  let scratch := base / "missing-scratch"
  writeFixture source none

  let report ← requireOk
    (← Loam.HouseholdImageDryRun.run source scratch probe)
    "missing-Attention dry-run migration was refused"
  let candidate ← decodedCandidate report
  expect (body? candidate "Attention" == none)
    "missing Attention was normalized into a HouseholdImage section"
  expect (report.absentSections.contains "Attention")
    "missing Attention was not reported absent"
  expect (!(← (Loam.HouseholdPaths.attention report.projectionRoot).pathExists))
    "legacy projection invented missing Attention"

private def runCliCase (base : System.FilePath) : IO Unit := do
  let source := base / "cli"
  let scratch := base / "cli-scratch"
  writeFixture source (some coherentAttention)

  let exitCode ← Loam.HouseholdImageDryRunCli.run [
    source.toString,
    scratch.toString,
    probe.currentWindowStart,
    probe.observedAt,
    probe.endExclusive
  ]
  expect (exitCode == 0)
    "dry-run CLI refused the qualified fixture"
  expect (← (scratch / "household.loam.candidate").pathExists)
    "dry-run CLI did not leave an inspectable candidate"
  expect (!(← (Loam.HouseholdAuthority.path source).pathExists))
    "dry-run CLI installed household.loam into the source root"

private def runMalformedCase (base : System.FilePath) : IO Unit := do
  let source := base / "malformed"
  let scratch := base / "malformed-scratch"
  writeFixture source (some "LOAM-ATTENTION-MEMORY\t1\nITEM\tbroken\n")

  match ← Loam.HouseholdImageDryRun.run source scratch probe with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "malformed legacy Attention unexpectedly migrated")
  expect (!(← scratch.pathExists))
    "malformed legacy input created a scratch candidate before refusal"
  expect (!(← (Loam.HouseholdAuthority.path source).pathExists))
    "malformed dry-run installed household.loam"

def main (args : List String) : IO Unit := do
  let [basePath] := args
    | throw (IO.userError "supply isolated HouseholdImage dry-run test directory")
  let base := System.FilePath.mk basePath
  cleanupDir base
  IO.FS.createDirAll base

  runFullCase base
  runPresentEmptyCase base
  runMissingCase base
  runCliCase base
  runMalformedCase base

  cleanupDir base
  IO.println
    "HouseholdImage dry-run migration: full, present-empty, missing, CLI entry, malformed refusal, Review equivalence, config separation, and source immutability passed."

end Loam.Tests.HouseholdImageDryRunMigration

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdImageDryRunMigration.main args
