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

  IO.println "YearCli: calendar selection, independent archive, no write and corrupt source refusal passed."

end Loam.Tests.YearCli

def main : IO Unit := Loam.Tests.YearCli.main
