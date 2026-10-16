import Loam.Review.AnnualSelectedHomePreview
import Loam.Review.AnnualSourceQueryPolicy

namespace Loam.Tools.NativeAnnualSelectedHomePreviewProbe

open Loam.Core

set_option autoImplicit false

private def expect (yes : Bool) (why : String) : IO Unit := do
  unless yes do throw (IO.userError why)

private def requireOk {α : Type} (x : Except String α) (label : String) :
    IO α := do
  match x with
  | .ok value => return value
  | .error reason => throw (IO.userError s!"{label}: {reason}")

private def observedHome
    (configRoot : System.FilePath)
    (generation : Loam.HouseholdAuthority.Generation) :
    IO Loam.Tui.Main.Snapshot := do
  let view ← requireOk
    (Loam.AnnualSourceReadView.fromGeneration? generation)
    "native installed read evidence"
  requireOk (← Loam.Tui.Cli.loadSnapshotFromActualImage
    configRoot "2027-01-03" view.actual (some generation) false)
    "ordinary installed Home read"

private def identities (home : Loam.Tui.Main.Snapshot) : List String :=
  home.actual.allRecords.map (fun row => row.event.id.token)

private def run (original annual : System.FilePath) : IO Unit := do
  let originalFile := Loam.HouseholdAuthority.path original
  let originalPrev := Loam.HouseholdAuthority.previousPath original
  let before ← IO.FS.readFile originalFile
  let prev ← IO.FS.readFile originalPrev
  let pool ← IO.FS.readFile (original / "config" / "daily-pace.tsv")
  let boundary ← IO.FS.readFile (original / "config" / "boundary-presets.tsv")
  let admitted ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? original)
    "read existing synthetic household"
  let native ← observedHome original admitted
  let head := Loam.AnnualSourceHeadSandbox.headPath annual
  let pin ← IO.FS.readFile head
  let preview ← requireOk
    (← Loam.AnnualSelectedHomePreview.load? original annual pin "2027-01-03")
    "Home from one selected native annual source"
  expect (preview.selected.headWire == pin &&
          preview.selected.head.years == ["2028"] &&
          preview.home.actual.today == "2027-01-03" &&
          identities preview.home == identities native &&
          identities preview.home |>.length == 4)
    "Home failed exact cross-year event identity/parity"
  let bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let bankRow ←
    match preview.view.currentBalances.exactRowFor? bank with
    | some row => pure row
    | none => throw (IO.userError "annual Home bank support lost")
  expect (bankRow.quantity.quanta == 7850 &&
          !(Loam.CurrentBalanceReview.selectExact
            preview.view.currentBalances [cash]).isOk &&
          preview.view.openScheduled.isEmpty)
    "annual Home bank/current Scheduled/unknown cash changed"
  let policy ← requireOk
    (Loam.AnnualSourceQueryPolicy.admit? ⟨"jpy"⟩ "2027-01-03" pool boundary)
    "exact external current Daily Pace policy"
  let beforePace ← requireOk
    (policy.project? (← requireOk
      (Loam.AnnualSourceReadView.fromGeneration? admitted) "installed view"))
    "ordinary installed pace"
  let annualPace ← requireOk (policy.project? preview.view)
    "pinned annual Home pace"
  expect (beforePace == annualPace &&
          annualPace.endExclusive == "2027-02-15" &&
          annualPace.eligiblePool.quanta == 7850 &&
          annualPace.automaticDeductions.quanta == 0)
    "annual Home changed current-truth Daily Pace or Jan-1 cycle boundary"

  -- Failure must not fall back to valid ordinary household.loam.
  let journal2028 := annual / "journal" / "2028" / "1.full.loam"
  let yearSource ← IO.FS.readFile journal2028
  IO.FS.writeFile journal2028 "CORRUPT-SELECTED-ANNUAL-SOURCE\n"
  expect (!(← Loam.AnnualSelectedHomePreview.load?
    original annual pin "2027-01-03").isOk)
    "corrupt selected year fell back to ordinary HouseholdImage"
  IO.FS.writeFile journal2028 yearSource

  let originalHead ← IO.FS.readFile head
  IO.FS.writeFile head
    (Loam.AnnualSourceHeadSandbox.Head.encode { baselineYear := "2027" })
  expect (!(← Loam.AnnualSelectedHomePreview.load?
    original annual pin "2027-01-03").isOk)
    "valid old HEAD accepted despite explicit expected selected HEAD"
  IO.FS.writeFile head originalHead

  let unmarked ← IO.FS.createTempDir
  expect (!(← Loam.AnnualSelectedHomePreview.load?
    original unmarked pin "2027-01-03").isOk)
    "annual Home preview accepted an unmarked source root"
  expect (!(← Loam.AnnualSelectedHomePreview.load?
    original original pin "2027-01-03").isOk)
    "annual Home preview accepted the production-style root as annual owner"
  expect (!(← Loam.AnnualSelectedHomePreview.load?
    original annual pin "2027-02-30").isOk)
    "annual Home preview accepted an impossible calendar day"
  expect (!(← Loam.AnnualSelectedHomePreview.load?
    original annual "stale external pin" "2027-01-03").isOk)
    "annual Home preview ignored mismatching HEAD pin"

  let again ← requireOk
    (← Loam.AnnualSelectedHomePreview.load? original annual pin "2027-01-03")
    "selected annual Home after refusing invalid sources"
  expect (identities again.home == identities preview.home &&
          again.selected.generation.wire == preview.selected.generation.wire &&
          (← IO.FS.readFile originalFile) == before &&
          (← IO.FS.readFile originalPrev) == prev &&
          (← IO.FS.readFile (original / "config" / "daily-pace.tsv")) == pool &&
          (← IO.FS.readFile (original / "config" / "boundary-presets.tsv")) == boundary)
    "annual Home preview changed the original installed household or selected data"
  IO.println "NATIVE_ANNUAL_SELECTED_HOME_PREVIEW_PASS TUI Home from one pinned native HEAD; Actual/Scheduled/Balance/Pace parity; corrupt/missing/stale roots refused; ordinary source unchanged"

def main (args : List String) : IO Unit := do
  match args with
  | [household, annual] =>
      run (System.FilePath.mk household) (System.FilePath.mk annual)
  | _ => throw (IO.userError
      "usage: NativeAnnualSelectedHomePreviewProbe SYNTHETIC_HOUSEHOLD ANNUAL_ROOT")

end Loam.Tools.NativeAnnualSelectedHomePreviewProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualSelectedHomePreviewProbe.main args
