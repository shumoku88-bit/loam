import Loam.Cli.NewHouseholdCli
import Loam.HouseholdCommand
import Loam.HouseholdPaths
import Loam.Authority.HouseholdAuthority
import Loam.Config.DailyPaceConfig
import Loam.Tui.DailyPacePoolSetup
import Loam.Tui.DailyPacePoolSetupSession
import Loam.Tui.Runtime
import Loam.Tests.Support

namespace Loam.Tests.TuiDailyPacePoolSetup

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : EffectCoordinate := ⟨⟨"bank"⟩, yen⟩
private def cash : EffectCoordinate := ⟨⟨"cash"⟩, yen⟩

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let root := parent / "fresh"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root) "initialize synthetic root"
  let config := Loam.HouseholdPaths.dailyPace root
  let empty ← requireOk
    (← Loam.Tui.DailyPacePoolSetupSession.prepare root yen)
    "prepare empty household pool"
  expect empty.candidates.isEmpty "unknown current balances were offered as spendable funds"
  let first := Loam.Tui.DailyPacePoolSetup.initial yen empty.candidates []
  let refused := Loam.Tui.DailyPacePoolSetup.update first .enter
  expect (refused.publish.isNone && refused.state.phase == .choose)
    "empty choice reached confirmation or publication"
  expect (!(← config.pathExists)) "opening a pool editor created query config"

  for locus in ["bank", "cash", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus root { token := locus })
      "admit synthetic Locus"
    pure ()
  for coordinate in [bank, cash] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.observeCurrentQuantities root [
        { coordinate := coordinate, quantity := Quantity.ofQuanta 10000 }
      ]) "observe exact current quantity"
    pure ()

  let ready ← requireOk
    (← Loam.Tui.DailyPacePoolSetupSession.prepare root yen)
    "prepare current balance picker"
  expect (ready.candidates.contains bank && ready.candidates.contains cash)
    "exact current observed coordinates missing from spendable pool choices"
  let state := Loam.Tui.DailyPacePoolSetup.initial yen ready.candidates []
  let checked := Loam.Tui.DailyPacePoolSetup.update state (.input ' ')
  expect (checked.state.chosen.length == 1)
    "Space did not mark selected balance"
  let preview := Loam.Tui.DailyPacePoolSetup.update checked.state .enter
  expect (preview.state.phase == .review && preview.publish.isNone)
    "first Enter saved without review"
  let edit := Loam.Tui.DailyPacePoolSetup.update preview.state .escape
  expect (edit.state.phase == .choose && edit.publish.isNone)
    "escape from review did not return to choosing"
  let confirm := Loam.Tui.DailyPacePoolSetup.update preview.state .enter
  let some selection := confirm.publish
    | throw (IO.userError "confirmed pool choice did not produce selection")
  let canonicalBefore ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let _ ← requireOk
    (← Loam.Tui.DailyPacePoolSetupSession.save root yen ready selection)
    "publish explicit spendable pool"
  let decoded ← requireOk
    (← Loam.DailyPaceConfig.loadForMeasure yen config)
    "read back persisted Daily Pace pool"
  expect (decoded == selection)
    "Daily Pace pool did not round-trip existing typed decoder"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == canonicalBefore)
    "query-only pool setting modified canonical household evidence"

  let preparedAgain ← requireOk
    (← Loam.Tui.DailyPacePoolSetupSession.prepare root yen)
    "reload saved configuration as selected choices"
  expect (preparedAgain.previous == selection)
    "second pool editor did not restore current selection"
  let _ ← requireOk
    (← Loam.Tui.DailyPacePoolSetupSession.save root yen preparedAgain selection)
    "repeating same configuration should be a no-op"

  -- A concurrent manual config edit must never be replaced by the stale form.
  let stale := preparedAgain
  IO.FS.writeFile config "cash\tjpy\n"
  let staleContent ← IO.FS.readFile config
  expect (!(← Loam.Tui.DailyPacePoolSetupSession.save root yen stale selection).isOk)
    "stale screen silently clobbered later configuration"
  expect ((← IO.FS.readFile config) == staleContent)
    "refused stale update modified config"

  -- Malformed existing query config never triggers implicit repair/reset.
  IO.FS.writeFile config "bank\tjpy\nbank\tjpy\n"
  expect (!(← Loam.Tui.DailyPacePoolSetupSession.prepare root yen).isOk)
    "malformed old pool was accepted as an empty/default pool"
  expect ((← IO.FS.readFile config) == "bank\tjpy\nbank\tjpy\n")
    "malformed pool was silently rewritten"

  for bounds in
    ([{ width := 32, height := 9 }, { width := 80, height := 24 }] :
      List Loam.Tui.Kernel.Bounds) do
    for shown in [state, checked.state, preview.state] do
      let view := Loam.Tui.DailyPacePoolSetup.view bounds shown
      expect (decide (view.lines.length ≤ bounds.height))
        "pool picker exceeded terminal height"
      for line in view.lines do
        expect
          (decide (Loam.Tui.Layout.displayWidth
            (String.ofList (line.map (·.glyph))) ≤
             Loam.Tui.Layout.contentWidth bounds))
          "pool picker exceeded terminal width"
  IO.println "Daily Pace pool: exact-only candidates, two-stage review, ESC, config-only publication, typed re-read, stale/malformed refusal and compact bounds passed."

end Loam.Tests.TuiDailyPacePoolSetup

def main : IO Unit := Loam.Tests.TuiDailyPacePoolSetup.main
