import Loam.Cli.NewHouseholdCli
import Loam.HouseholdPaths
import Loam.Authority.HouseholdAuthority
import Loam.Config.BoundaryPresetConfig
import Loam.Tui.CycleBoundarySetup
import Loam.Tui.CycleBoundarySetupSession
import Loam.Tui.Runtime
import Loam.Tests.Support

namespace Loam.Tests.TuiCycleBoundarySetup

open Loam.Tests.Support

set_option autoImplicit false

private def today : String := "2026-10-16"

def main : IO Unit := do
  let base ← IO.FS.createTempDir
  let root := base / "fresh"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "start disposable household"
  let target := Loam.HouseholdPaths.boundaryPresets root
  let first ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.prepare root today)
    "fresh household config editor"
  expect first.presets.isEmpty "first-run unexpectedly contained configured pension dates"
  let empty := Loam.Tui.CycleBoundarySetup.initial first.current
  expect (empty.name == "pension" && empty.dates.isEmpty)
    "first-run default should be an unconfigured named preset"
  expect (!(← target.pathExists)) "opening cycle setup created a file"

  let typed := { empty with dates := "2026-10-15, 2026-12-15", focus := 1 }
  let preview := Loam.Tui.CycleBoundarySetup.update typed .enter
  expect (preview.state.phase == .review && preview.publish.isNone)
    "first Enter must review without publishing"
  let back := Loam.Tui.CycleBoundarySetup.update preview.state .escape
  expect (back.state.phase == .editing && back.publish.isNone)
    "Esc from review must restore editing"
  let cancelled := Loam.Tui.CycleBoundarySetup.update typed .escape
  expect cancelled.cancel "Esc must cancel editor"
  expect (!(← target.pathExists)) "review or cancel modified the configuration"
  let confirmed := Loam.Tui.CycleBoundarySetup.update preview.state .enter
  let some chosen := confirmed.publish
    | throw (IO.userError "second Enter did not confirm admitted boundaries")
  let canonicalBefore ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let _ ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.save root today first chosen)
    "save explicit pension boundaries"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == canonicalBefore)
    "editing a query boundary rewrote canonical household data"
  let saved ← requireSome (← Loam.BoundaryPresetConfig.load? target)
    "read typed boundary presets"
  let window ← requireOk
    (Loam.BoundaryPresetConfig.currentWindowFor? saved today)
    "read explicitly configured current window"
  expect (window.source == "pension" &&
          window.start == "2026-10-15" &&
          window.endExclusive == "2026-12-15")
    "current Daily Pace cycle boundaries were not retained"
  let reopened ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.prepare root today)
    "reopen current named preset"
  expect (reopened.current.map (·.name) == some "pension")
    "reopen did not focus the current preset"
  let _ ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.save root today repeat chosen)
    "repeat identical save must be a no-op"

  -- Other typed named presets must be retained if current preset changes.
  IO.FS.writeFile target
    "archive\t2025-01-01\t2025-12-31\npension\t2026-10-15\t2026-12-15\n"
  let withArchive ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.prepare root today)
    "read coexistence with unrelated named report preset"
  let extended : Loam.BoundaryPresetConfig.Preset := {
    name := "pension"
    boundaries := ["2026-10-15", "2026-12-15", "2027-02-15"]
  }
  let _ ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.save root today withArchive extended)
    "extend explicit current pension horizon"
  let after ← requireSome (← Loam.BoundaryPresetConfig.load? target)
    "qualified re-read after explicit boundary extension"
  expect (after.length == 2 &&
    (after.find? (fun p => p.name == "archive")).map (·.boundaries) ==
      some ["2025-01-01", "2025-12-31"] &&
    (after.find? (fun p => p.name == "pension")).map (·.boundaries) ==
      some extended.boundaries)
    "editing current cycle erased or changed another named preset"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == canonicalBefore)
    "boundary extension changed canonical records"

  let badDate := { typed with dates := "2026-10-15, 2026-02-30" }
  expect ((Loam.Tui.CycleBoundarySetup.parse badDate).isOk == false)
    "fabricated invalid calendar day accepted"
  let duplicate := { typed with dates := "2026-10-15, 2026-10-15" }
  expect (!(Loam.Tui.CycleBoundarySetup.parse duplicate).isOk)
    "same-day duplicate boundaries accepted"
  let backwards := { typed with dates := "2026-12-15, 2026-10-15" }
  expect (!(Loam.Tui.CycleBoundarySetup.parse backwards).isOk)
    "reverse pension boundaries accepted"

  -- A stale editor must not overwrite later external settings.
  let stale := withArchive
  let beforeStale := "archive\t2025-01-01\t2025-12-31\npension\t2026-10-15\t2027-02-15\n"
  IO.FS.writeFile target beforeStale
  expect (!(← Loam.Tui.CycleBoundarySetupSession.save root today stale extended).isOk)
    "stale editor overwrote independently modified config"
  expect ((← IO.FS.readFile target) == beforeStale)
    "stale refusal changed config bytes"

  -- Existing malformed config must not be treated as an empty file.
  IO.FS.writeFile target "pension\t2026-10-15\t2026-10-15\n"
  expect (!(← Loam.Tui.CycleBoundarySetupSession.prepare root today).isOk)
    "malformed existing pension schedule was silently reset"
  expect ((← IO.FS.readFile target) == "pension\t2026-10-15\t2026-10-15\n")
    "malformed input was unexpectedly rewritten"

  let otherRoot := base / "ambiguous"
  let _ ← requireOk (← Loam.NewHouseholdCli.create otherRoot)
    "build overlap refusal fixture"
  IO.FS.createDirAll (Loam.HouseholdPaths.configDir otherRoot)
  let otherTarget := Loam.HouseholdPaths.boundaryPresets otherRoot
  IO.FS.writeFile otherTarget "other\t2026-09-15\t2026-11-15\n"
  let conflicting ← requireOk
    (← Loam.Tui.CycleBoundarySetupSession.prepare otherRoot today)
    "open existing current other preset"
  expect (!(← Loam.Tui.CycleBoundarySetupSession.save otherRoot today conflicting chosen).isOk)
    "two overlapping active cycle presets were accepted"
  expect ((← IO.FS.readFile otherTarget) == "other\t2026-09-15\t2026-11-15\n")
    "ambiguous current-cycle refusal rewrote existing settings"

  for bounds in
    ([{ width := 32, height := 9 }, { width := 80, height := 24 }] :
      List Loam.Tui.Kernel.Bounds) do
    for state in [empty, typed, preview.state] do
      let widget := Loam.Tui.CycleBoundarySetup.view bounds state
      expect (decide (widget.lines.length ≤ bounds.height))
        "cycle date screen exceeded terminal height"
      for one in widget.lines do
        expect (decide (Loam.Tui.Layout.displayWidth
          (String.ofList (one.map (·.glyph))) ≤
          Loam.Tui.Layout.contentWidth bounds))
          "cycle date screen exceeded terminal width"
  IO.println "Cycle setup: real explicit dates, two-stage confirmation, current window, preserve named reports, stale/malformed/overlap refusal, no canonical write and narrow TUI passed."

end Loam.Tests.TuiCycleBoundarySetup

def main : IO Unit := Loam.Tests.TuiCycleBoundarySetup.main
