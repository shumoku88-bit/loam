import Loam.Authority.AnnualSandboxDurabilityBarriers
import Loam.Review.AnnualSourceQueryPolicy
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tools.NativeAnnualInstalledMigrationProbe

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
Isolated copy-first migration rehearsal of the *real ordinary* Jan-1 household
fixture into a separate annual source root. No write to original authority,
no TUI annual selection, no migration of real households, no reliable clock.
-/

private def expect (ok : Bool) (reason : String) : IO Unit := do
  unless ok do throw (IO.userError reason)

private def requireOk {α : Type}
    (e : Except String α) (label : String) : IO α := do
  match e with
  | .ok value => return value
  | .error why => throw (IO.userError s!"{label}: {why}")

private def requireSome {α : Type}
    (value : Option α) (label : String) : IO α := do
  let some answer := value | throw (IO.userError label)
  return answer

private def policyFromInstalled
    (root : System.FilePath) : IO Loam.AnnualSourceQueryPolicy.Policy := do
  let pool ← IO.FS.readFile (root / "config" / "daily-pace.tsv")
  let cycle ← IO.FS.readFile (root / "config" / "boundary-presets.tsv")
  requireOk
    (Loam.AnnualSourceQueryPolicy.admit? ⟨"jpy"⟩ "2027-01-03" pool cycle)
    "exact original cross-Jan-1 pension policy"

/-- Compare actual results, not just the canonical full-image bytes. The exact
source equality is also required, preventing unknown-section loss. -/
private def assertParity
    (installed : Loam.AnnualSourceReadView.Snapshot)
    (replayed : Loam.AnnualSourceReadView.Snapshot)
    (policy : Loam.AnnualSourceQueryPolicy.Policy) : IO Unit := do
  expect (installed.generation.wire == replayed.generation.wire)
    "copied year-source native bytes differ from original household"
  let actualKeys (view : Loam.AnnualSourceReadView.Snapshot) :=
    view.actualRecords.map fun row => (row.event.id.token, row.isCurrent)
  expect (actualKeys installed == actualKeys replayed &&
          installed.actualRecords.length == 4)
    "December/January Actual identities or correction currentness changed"
  let openKeys (view : Loam.AnnualSourceReadView.Snapshot) :=
    view.openScheduled.map (fun row => row.id.token)
  expect (openKeys installed == openKeys replayed &&
          replayed.openScheduled.isEmpty)
    "completed January Scheduled was resurrected by annual replay"
  expect (installed.currentBalances == replayed.currentBalances)
    "current balance known/unknown/exact support changed"
  let bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let row ← requireSome (replayed.currentBalances.exactRowFor? bank)
    "replayed exact bank balance missing"
  expect (row.quantity.quanta == 7850 &&
          !(Loam.CurrentBalanceReview.selectExact
            replayed.currentBalances [cash]).isOk)
    "2027 exact bank or unsupported cash was altered on copy"

  let nativePace ← requireOk (policy.project? installed)
    "installed pension Daily Pace"
  let yearPace ← requireOk (policy.project? replayed)
    "selected source pension Daily Pace"
  expect (nativePace == yearPace &&
          yearPace.eligiblePool.quanta == 7850 &&
          yearPace.automaticDeductions.quanta == 0 &&
          yearPace.endExclusive == "2027-02-15" &&
          yearPace.remainingDays > 0)
    "Jan-1 date erroneously reset cycle or pace after migration"

private def run (household annual : System.FilePath) : IO Unit := do
  expect (household.toString != annual.toString)
    "refuse using the original household as a new annual source root"
  let sourcePath := Loam.HouseholdAuthority.path household
  let original ← IO.FS.readFile sourcePath
  let previousPath := Loam.HouseholdAuthority.previousPath household
  let previous ← IO.FS.readFile previousPath
  let generation ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? household)
    "qualified ordinary production household source"
  expect (original == generation.wire)
    "ordinary source changed between capture and load"
  let installed ← requireOk
    (Loam.AnnualSourceReadView.fromGeneration? generation)
    "ordinary same-generation Actual/Scheduled/Balance view"
  let policy ← policyFromInstalled household
  expect (!(← (annual / "HEAD").pathExists))
    "copy-first annual root already has a selected HEAD"
  Loam.AnnualSandboxDurabilityBarriers.markDisposableRoot annual
  let barrier := Loam.AnnualSandboxDurabilityBarriers.barriers annual
  let copied ← requireOk
    (← Loam.AnnualSourceHeadSandbox.bootstrapWithBarriers?
      annual "2027" generation.wire barrier)
    "copy current whole native HouseholdImage into 2027 baseline"
  expect (copied.head.baselineYear == "2027" &&
          copied.head.years.isEmpty &&
          !(← (annual / "journal" / "2028").pathExists))
    "copying old history manufactured an empty year or a close entry"
  let selected ← requireOk
    (← Loam.AnnualSourceHeadSandbox.readSelected? annual)
    "reopen copy-first annual generation"
  let current ← requireOk
    (Loam.AnnualSourceReadView.fromGeneration? selected.generation)
    "reopen migrated native view"
  assertParity installed current policy
  let currentInstalled ← requireOk
    (← Loam.AnnualSourceReadView.compareInstalled?
      household selected.generation.wire)
    "source-selected copy must still equal original installed authority"
  assertParity installed currentInstalled policy

  -- First admitted year after copied baseline is 2028. The physical year
  -- follows the injected admission day, not the older effective dates.
  let vocabulary ← requireSome
    (LocusAdmissionVocabulary.ofLoci?
      [⟨"bank"⟩, ⟨"cash"⟩, ⟨"food"⟩, ⟨"later"⟩])
    "2028 synthetic vocabulary"
  let body ← requireSome
    (Loam.Persistence.encodeLocusAdmissionVocabulary? vocabulary)
    "2028 synthetic locus encoding"
  let nextImage ← requireSome
    (replaceBody? selected.generation.image "LocusAdmission" body)
    "LocusAdmission section missing"
  let continued ← requireOk
    (← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
      annual selected.headWire "2028-01-03" "post-migration-locus"
      ["LocusAdmission"] nextImage barrier)
    "admit first native source change in 2028"
  expect (continued.head.years == ["2028"] &&
          continued.operations == ["post-migration-locus"] &&
          continued.generation.wire != selected.generation.wire &&
          Loam.HouseholdAuthority.preservesUntouched
            selected.generation.image continued.generation.image ["LocusAdmission"])
    "2028 change altered earlier Actual/Scheduled/support evidence"
  let later ← requireOk
    (← Loam.AnnualSourceHeadSandbox.readSelected? annual)
    "reopen copied household after new-year operation"
  let laterView ← requireOk
    (Loam.AnnualSourceReadView.fromGeneration? later.generation)
    "post-2028 annual current view"
  expect (laterView.actualRecords.length == current.actualRecords.length &&
          laterView.openScheduled.isEmpty &&
          laterView.currentBalances == current.currentBalances)
    "later year altered original current Actual/Scheduled/balances"
  let pace2028Source ← requireOk (policy.project? laterView)
    "same explicitly pinned Jan-2027 pace after future vocabulary"
  let paceInstalled ← requireOk (policy.project? installed)
    "original pinned pace"
  expect (pace2028Source == paceInstalled)
    "later source publication retroactively changed pinned pace"
  expect ((← IO.FS.readFile sourcePath) == original &&
          (← IO.FS.readFile previousPath) == previous &&
          (← IO.FS.readFile (household / "config" / "daily-pace.tsv")) ==
            policy.poolWire &&
          (← IO.FS.readFile (household / "config" / "boundary-presets.tsv")) ==
            policy.boundaryWire)
    "copy-first annual trial modified original household or query config"
  expect ((← (household / "journal" / "2028").pathExists) == false)
    "trial created a year source inside the production-style household"
  IO.println "NATIVE_ANNUAL_INSTALLED_COPY_MIGRATION_PASS old canonical bytes unchanged; full Actual/Scheduled/Balance/Pace parity; 2028 annual continuation"

def main (args : List String) : IO Unit := do
  match args with
  | [household, annual] =>
      run (System.FilePath.mk household) (System.FilePath.mk annual)
  | _ => throw (IO.userError
      "usage: NativeAnnualInstalledMigrationProbe SYNTHETIC_HOUSEHOLD ANNUAL_ROOT")

end Loam.Tools.NativeAnnualInstalledMigrationProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualInstalledMigrationProbe.main args
