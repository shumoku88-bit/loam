import Loam.Cli.YearCli
import Loam.Cli.NewHouseholdCli
import Loam.HouseholdCommand
import Loam.Authority.HouseholdAuthority
import Loam.Tests.Support

namespace Loam.Tests.YearCli

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

private def bookEvent (root : System.FilePath) (date : String) :
    IO EventId := do
  requireOk (← Loam.HouseholdCommand.record root {
    validOn := date
    description := some ("recorded " ++ date)
    effects := [
      Effect.ofAnonymousQuantity ⟨"cash"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
    relations := []
    discharges := []
    total := 100
  }) "record a disposable calendar-year event"

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let root := parent / "year-product"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "create disposable household"
  for token in ["cash", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus root { token })
      ("admit " ++ token)
    pure ()

  let december ← bookEvent root "2026-12-31"
  let currentBefore ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let legacyYear ← requireOk (← Loam.YearCli.readYear root "2026")
    "load installed December year"
  expect (legacyYear.entries.map (·.event.id) == [december] &&
          legacyYear.sourceRoot == root)
    "reading a year from today's installed source failed"

  let archived := Loam.HouseholdPaths.yearRoot root "2026"
  IO.FS.createDirAll archived
  IO.FS.writeFile (Loam.HouseholdAuthority.path archived) currentBefore
  let january ← bookEvent root "2027-01-01"
  let currentAfter ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let fromArchive ← requireOk (← Loam.YearCli.readYear root "2026")
    "open independently saved 2026 source"
  expect (fromArchive.sourceRoot == archived &&
          fromArchive.entries.map (·.event.id) == [december])
    "explicitly saved year source not selected"
  let nextYear ← requireOk (← Loam.YearCli.readYear root "2027")
    "open installed January year"
  expect (nextYear.sourceRoot == root &&
          nextYear.entries.map (·.event.id) == [january])
    "January selection included December records"

  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == currentAfter)
    "read-only year selection changed the installed source"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path archived)) == currentBefore)
    "read-only year selection changed archived source"

  -- Corrections to an archived December Event may be admitted in January.
  -- The immutable archived source must stay unchanged, but the ordinary
  -- year browser must report the latest admitted corrected amount.
  let _ ← requireOk
    (← Loam.HouseholdCommand.correctActual root {
      target := december
      effects := [
        Effect.ofAnonymousQuantity ⟨"cash"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-75)),
        Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 75)
      ]
      description := some "corrected after year boundary"
    }) "correct saved December after first January booking"
  let latestYear ← requireOk (← Loam.YearCli.readYear root "2026")
    "reconcile immutable 2026 archive against current admitted correction"
  expect (latestYear.sourceFile == Loam.HouseholdAuthority.path root &&
          latestYear.entries.length == 1 &&
          latestYear.entries.head?.bind (·.description) ==
            some "corrected after year boundary" &&
          latestYear.entries.head?.map
            (fun entry => entry.event.effects.map (·.quantity.quanta)) ==
              some [-75, 75] &&
          latestYear.notice.isSome)
    "saved year masked a subsequently admitted December correction"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path archived)) == currentBefore)
    "corrected December silently changed the immutable saved year"
  expect (((Loam.YearCli.render "2026" latestYear).splitOn "Notice: ").length > 1)
    "archive correction source switch was not visible in year report"

  -- A missing historical year is not a verified empty journal.
  match ← Loam.YearCli.readYear root "2025" with
  | .error message =>
      expect (message.startsWith "loam: year 2025 has no saved source")
        "missing year was not reported as unavailable"
  | .ok _ => throw (IO.userError "missing year was reported as an empty book")

  -- An incomplete selected year directory is not a fallback to today's root.
  let missingSource := Loam.HouseholdPaths.yearRoot root "2025"
  IO.FS.createDirAll missingSource
  match ← Loam.YearCli.readYear root "2025" with
  | .error message =>
      expect (message.startsWith "loam: saved year 2025 exists")
        "incomplete year directory was not reported as missing authority"
  | .ok _ => throw (IO.userError "incomplete year silently fell back to current")
  expect (!Loam.YearCli.validYear "202A" &&
          !Loam.YearCli.validYear "0000" &&
          !Loam.YearCli.validYear "../2" &&
          Loam.YearCli.validYear "2028")
    "invalid year accepted or four-digit year refused"

  -- A present and fully admitted empty year is different from a missing year.
  let emptyYear := Loam.HouseholdPaths.yearRoot root "2024"
  let _ ← requireOk (← Loam.NewHouseholdCli.create emptyYear)
    "create an independent, valid empty year source"
  let emptyReport ← requireOk (← Loam.YearCli.readYear root "2024")
    "read empty but present year source"
  expect (emptyReport.sourceRoot == emptyYear && emptyReport.entries.isEmpty)
    "verified empty archive was treated as absent"

  IO.FS.writeFile (Loam.HouseholdAuthority.path archived) "broken"
  match ← Loam.YearCli.readYear root "2026" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "corrupt archived year silently fell back to current")

  -- Checkpoint creation uses the existing household, not fresh-household
  -- initialization. It keeps one exact qualified generation and never writes
  -- to the original or overwrites an earlier year directory.
  let checkpointRoot := parent / "year-checkpoint"
  let _ ← requireOk (← Loam.NewHouseholdCli.create checkpointRoot)
    "create checkpoint source household"
  for token in ["cash", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus checkpointRoot { token })
      ("admit checkpoint " ++ token)
    pure ()
  let sourceOld ← bookEvent checkpointRoot "2020-12-31"
  let _ ← bookEvent checkpointRoot "2021-01-01"
  let _ ← requireOk
    (← Loam.HouseholdCommand.observeCurrentQuantities checkpointRoot [
      { coordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩,
        quantity := Quantity.ofQuanta 5000 }
    ]) "observe an exact carried cash amount"
  let plan ← requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩ [
      { coordinate := ⟨"cash"⟩, quantity := Quantity.ofQuanta (-250) },
      { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 250 }
    ]) "create a still-open obligation for carry"
  let _ ← requireOk
    (← Loam.HouseholdCommand.createScheduled checkpointRoot {
      scheduledOn := "2022-04-01", movement := plan
    }) "carry one still-open Scheduled obligation"
  let checkpointBefore ← IO.FS.readFile (Loam.HouseholdAuthority.path checkpointRoot)
  let checkpoint ← requireOk (← Loam.YearCli.checkpointYear checkpointRoot "2020")
    "create qualified historical checkpoint"
  let checkpointDir := Loam.HouseholdPaths.yearRoot checkpointRoot "2020"
  expect (checkpoint == Loam.HouseholdAuthority.path checkpointDir &&
          (← IO.FS.readFile checkpoint) == checkpointBefore &&
          (← IO.FS.readFile (Loam.HouseholdAuthority.path checkpointRoot)) == checkpointBefore)
    "checkpoint did not preserve exact source bytes or changed source"
  -- Checkpoint carries the same admitted current support classifications.
  -- It neither silently turns unknown cash into zero nor drops open Scheduled.
  let basis ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? checkpointRoot)
    "load checkpoint source as one observed generation"
  let sourceCarry ← requireOk
    (Loam.YearCli.carryState? basis.generation basis.image)
    "qualify source carry from normal production read boundaries"
  let copied ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? checkpointDir)
    "load checkpoint copy as one observed generation"
  let copiedCarry ← requireOk
    (Loam.YearCli.carryState? copied.generation copied.image)
    "qualify checkpoint carry"
  expect (Loam.YearCli.carryAgrees sourceCarry copiedCarry)
    "new year checkpoint changed supported and unsupported coordinates"
  expect (sourceCarry.openScheduled.length == 1 &&
          sourceCarry.balances.rows.any
            (fun row => row.coordinate.locus.token == "cash" &&
              row.quantity.quanta == 5000) &&
          sourceCarry.balances.unsupported.any
            (fun coordinate => coordinate.locus.token == "food"))
    "carry lost an open obligation, exact cash or unsupported food"

  let opened ← requireOk (← Loam.YearCli.readYear checkpointRoot "2020")
    "open installed checkpoint with ordinary year browser"
  expect (opened.sourceRoot == checkpointDir &&
          opened.entries.map (·.event.id) == [sourceOld])
    "year browser did not open the checkpoint as the selected source"
  -- An archived HouseholdImage is readable, but it is not a second writable
  -- household. This must be enforced at the shared publisher, not merely by
  -- the checkpoint CLI's refusal to overwrite an existing path.
  expect (Loam.HouseholdAuthority.isSavedYearRoot checkpointDir &&
          !Loam.HouseholdAuthority.isSavedYearRoot checkpointRoot &&
          !Loam.HouseholdAuthority.isSavedYearRoot
            (checkpointRoot / "journal" / "draft"))
    "saved year writer identification rejected the installed root"
  match ← Loam.HouseholdCommand.record checkpointDir {
    validOn := "2022-05-01"
    description := some "must not write to the saved year"
    effects := [
      Effect.ofAnonymousQuantity ⟨"cash"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
    relations := []
    discharges := []
    total := 100
  } with
  | .error message =>
      expect (message.startsWith "loam: saved journal/YYYY household is read-only")
        "saved year writer did not report read-only ownership"
  | .ok _ => throw (IO.userError "ordinary record wrote into an immutable saved year")
  let savedGeneration ← requireOk (← Loam.HouseholdAuthority.loadCurrent? checkpointDir)
    "load saved generation for direct publisher guard"
  match ← Loam.HouseholdAuthority.publishObserved?
      checkpointDir savedGeneration.wire [] savedGeneration.image with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "direct Household publisher wrote into saved year")
  IO.FS.writeFile (Loam.HouseholdAuthority.previousPath checkpointDir) checkpointBefore
  match ← Loam.HouseholdAuthority.restorePrevious? checkpointDir with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "previous-generation restore modified saved year")
  expect ((← IO.FS.readFile checkpoint) == checkpointBefore)
    "attempted archive modification changed saved year bytes"

  let _ ← bookEvent checkpointRoot "2022-03-01"
  expect ((← IO.FS.readFile checkpoint) == checkpointBefore)
    "checkpoint was modified by subsequent normal household publication"
  let changed ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? checkpointRoot)
    "load updated source for carry mismatch test"
  let changedCarry ← requireOk
    (Loam.YearCli.carryState? changed.generation changed.image)
    "admit changed source carry"
  expect (!Loam.YearCli.carryAgrees sourceCarry changedCarry)
    "carry verification ignored a newly admitted household movement"
  match ← Loam.YearCli.checkpointYear checkpointRoot "2020" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "checkpoint overwrote a previous year")
  match ← Loam.YearCli.checkpointYear checkpointRoot "2019" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "checkpoint fabricated an empty past year")
  match ← Loam.YearCli.checkpointYear checkpointRoot "9999" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "checkpoint accepted a future or open year")
  let brokenYear := Loam.HouseholdPaths.yearRoot checkpointRoot "2018"
  IO.FS.createDirAll brokenYear
  match ← Loam.YearCli.checkpointYear checkpointRoot "2018" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "checkpoint overwrote a partial existing directory")

  -- Product year extraction uses only the selected year's dated Actual,
  -- not a full copy of every year and family.
  let extractionRoot := parent / "year-extraction"
  let _ ← requireOk (← Loam.NewHouseholdCli.create extractionRoot)
    "create source for bounded Actual extraction"
  for token in ["cash", "food"] do
    let _ ← requireOk (← Loam.HouseholdCommand.admitLocus extractionRoot { token })
      ("admit extract " ++ token)
    pure ()
  let _ ← bookEvent extractionRoot "2020-12-31"
  let archivedId ← bookEvent extractionRoot "2021-02-03"
  let _ ← bookEvent extractionRoot "2022-01-01"
  let sourceWire ← IO.FS.readFile (Loam.HouseholdAuthority.path extractionRoot)
  let extractedFile ← requireOk (← Loam.YearCli.extractYear extractionRoot "2021")
    "extract one calendar year into native bounded Actual format"
  let excerptWire ← IO.FS.readFile extractedFile
  expect (excerptWire.length < sourceWire.length &&
          excerptWire.startsWith "LOAM-NORMALIZED-ACTUAL" &&
          (← IO.FS.readFile (Loam.HouseholdAuthority.path extractionRoot)) == sourceWire)
    "bounded year extraction copied whole household or changed its authority"
  let excerpt ← requireOk (← Loam.YearCli.readYear extractionRoot "2021")
    "browse native year-only excerpt"
  expect (excerpt.entries.map (·.event.id) == [archivedId] &&
          excerpt.sourceFile == extractedFile)
    "year excerpt lost selected record or included another year"
  let _ ← bookEvent extractionRoot "2023-01-01"
  expect ((← IO.FS.readFile extractedFile) == excerptWire)
    "immutable extracted source changed after new canonical publication"
  match ← Loam.YearCli.extractYear extractionRoot "2021" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "extraction overwrote a prior archive")
  match ← Loam.YearCli.extractYear extractionRoot "2019" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "extraction invented a missing prior year")
  match ← Loam.YearCli.extractYear extractionRoot "9999" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "extraction accepted future year")
  IO.FS.writeFile extractedFile "corrupt"
  match ← Loam.YearCli.readYear extractionRoot "2021" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "corrupt annual Actual was silently replaced")

  -- Historical support is essential: an exact current anchor is NOT an
  -- exact January-1 opening, and today's Scheduled status is not Jan-1 status.
  let unsupportedOpening ← requireOk
    (← Loam.YearCli.inspectOpening checkpointRoot "2021")
    "review Jan-1 without historical completeness"
  expect (unsupportedOpening.exact.isEmpty &&
          unsupportedOpening.unavailable.any
            (fun item => item.1.locus.token == "cash") &&
          unsupportedOpening.currentOpenScheduled.length == 1 &&
          ((Loam.YearCli.renderOpening unsupportedOpening).splitOn "UNAVAILABLE").length > 1)
    "year opening invented historical cash or silently dropped open Scheduled"

  let openingRoot := parent / "year-opening"
  let _ ← requireOk (← Loam.NewHouseholdCli.create openingRoot)
    "create bounded year-opening product fixture"
  for token in ["cash", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus openingRoot { token })
      ("admit year-opening " ++ token)
    pure ()
  let _ ← bookEvent openingRoot "2026-12-31"
  let _ ← bookEvent openingRoot "2027-01-01"
  let observedOpening ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? openingRoot)
    "load opening candidate source"
  let zero ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [
      ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩, ⟨⟨"food"⟩, ⟨"jpy"⟩⟩
    ]) "admit explicit known-zero synthetic origins"
  let zeroWire ← requireSome
    (Loam.Persistence.encodeZeroOriginCoverage? zero)
    "encode synthetic zero origin"
  let zeroImage ← requireSome
    (Loam.Persistence.HouseholdImage.replaceBody?
      observedOpening.image "ZeroOrigin" zeroWire)
    "install synthetic explicit origin section"
  let _ ← requireOk
    (← Loam.HouseholdAuthority.publishObserved? openingRoot
      observedOpening.wire ["ZeroOrigin"] zeroImage)
    "publish admitted zero-origin fixture"
  let januarySource ← requireOk
    (← Loam.ActualAuthority.loadHouseholdObserved? openingRoot)
    "load synthetic future-boundary fixture"
  let jan1 ← requireOk
    (Loam.YearCli.openingReview? januarySource.generation januarySource.image "2027")
    "project simulated Jan-1 2027 exact quantities"
  expect (jan1.exact.length == 2 && jan1.unavailable.isEmpty &&
          jan1.exact.any (fun row =>
            row.coordinate.locus.token == "cash" &&
            row.quantity.quanta == -100) &&
          jan1.exact.any (fun row =>
            row.coordinate.locus.token == "food" &&
            row.quantity.quanta == 100))
    "Jan-1 historical reconstruction counted Jan-1 Actual or lost Dec-31"
  expect (((Loam.YearCli.renderOpening jan1).splitOn "2027-01-01").length > 1)
    "Jan-1 CLI did not expose its historical boundary"
  match ← Loam.YearCli.inspectOpening openingRoot "9998" with
  | .error message =>
      expect (message.startsWith "loam: future Jan-1 opening")
        "future boundary refused without the correct explanation"
  | .ok _ => throw (IO.userError "future opening was fabricated as historical")
  match ← Loam.YearCli.inspectOpening openingRoot "20x7" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "invalid opening year was accepted")

  IO.println "YearCli: calendar selection, archives, immutable checkpoints, bounded Actual extraction and exact Jan-1 opening checks passed."

end Loam.Tests.YearCli

def main : IO Unit := Loam.Tests.YearCli.main
