import Loam.Tui.FirstRun
import Loam.Tui.Runtime
import Loam.Cli.NewHouseholdCli
import Loam.Authority.HouseholdAuthority
import Loam.Tests.Support

namespace Loam.Tests.TuiFirstRun

open Loam.Tests.Support
open Loam.Tui.Kernel
open Loam.Tui.Terminal

set_option autoImplicit false

private def frameText (view : Widget) : String :=
  String.ofList (view.lines.flatten.map (·.glyph))

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let missing := parent / "fresh"
  let initial := Loam.Tui.FirstRun.initial missing false "missing"
  expect (initial.destination == missing.toString)
    "truly absent root should be the suggested destination"
  let editing := Loam.Tui.FirstRun.update initial .enter
  expect (editing.publish.isNone && editing.state.phase == .confirm)
    "first Enter must ONLY review and must not publish"
  let refused := Loam.Tui.FirstRun.update editing.state .escape
  expect (refused.state.phase == .editing && refused.publish.isNone)
    "Escape from review must return to editing"
  let cancelled := Loam.Tui.FirstRun.update initial .escape
  expect cancelled.cancel "Escape must leave without creating anything"
  expect (!(← missing.pathExists)) "cancelling or reviewing published a root"

  let final := Loam.Tui.FirstRun.update editing.state .enter
  expect (final.publish == some missing.toString)
    "only second explicit Enter publishes the new destination"
  let some path := final.publish
    | throw (IO.userError "TUI did not expose an explicit new destination")
  let _ ← requireOk (← Loam.NewHouseholdCli.create (System.FilePath.mk path))
    "qualified fresh-root installer from TUI decision"
  let rootBytes ← IO.FS.readFile (Loam.HouseholdAuthority.path missing)
  expect (!rootBytes.isEmpty) "TUI-chosen new household is not persisted"
  expect ((← Loam.HouseholdAuthority.loadCurrent? missing).isOk)
    "TUI-chosen new household cannot reopen normally"

  -- Selected unreadable household is NEVER proposed as a fresh target.
  let broken := parent / "old-corrupt"
  IO.FS.createDirAll broken
  let source := broken / "household.loam"
  IO.FS.writeFile source "not-a-household\n"
  let blocked := Loam.Tui.FirstRun.initial broken true "malformed"
  expect blocked.destination.isEmpty "existing unreadable root was offered for reset"
  let emptyReview := Loam.Tui.FirstRun.update blocked .enter
  expect (emptyReview.state.phase == .editing && emptyReview.publish.isNone)
    "empty new-root destination was accepted"
  let typed := Loam.Tui.FirstRun.update blocked (.paste (parent / "alternative").toString)
  let confirmed := Loam.Tui.FirstRun.update typed.state .enter
  expect (confirmed.state.phase == .confirm) "new independent path did not reach review"
  let requested := Loam.Tui.FirstRun.update confirmed.state .enter
  let some alternative := requested.publish
    | throw (IO.userError "alternative destination never offered")
  let _ ← requireOk
    (← Loam.NewHouseholdCli.create (System.FilePath.mk alternative))
    "independent new root after old-data failure"
  expect ((← IO.FS.readFile source) == "not-a-household\n")
    "TUI-driven new-root selection changed damaged old bytes"
  let rejected := Loam.Tui.FirstRun.update
    (Loam.Tui.FirstRun.withError confirmed.state
      "Already exists") .enter
  expect (rejected.publish.isNone)
    "publication refusal must re-enter editing before any retry"

  for bounds in
    ([{ width := 32, height := 9 },
      { width := 48, height := 14 },
      { width := 120, height := 40 }] : List Bounds) do
    for state in [initial, editing.state, blocked, typed.state] do
      let widget := Loam.Tui.FirstRun.view bounds state
      expect (widget.lines.length ≤ bounds.height)
        "startup editor exceeds terminal row count"
      for line in widget.lines do
        expect
          (Loam.Tui.Layout.displayWidth
            (String.ofList (line.map (·.glyph))) ≤
             Loam.Tui.Layout.contentWidth bounds)
          "startup editor exceeds physical terminal width"
    expect ((frameText (Loam.Tui.FirstRun.view bounds initial)).splitOn "Enter").length > 1
      "first-run screen lost review action"
  IO.println "TUI first-run: review/cancel, independent path, refuse old root, no-write, bounded terminal and qualified reopen passed."

end Loam.Tests.TuiFirstRun

def main : IO Unit := Loam.Tests.TuiFirstRun.main
