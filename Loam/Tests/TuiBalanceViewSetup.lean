import Loam.Cli.NewHouseholdCli
import Loam.HouseholdCommand
import Loam.HouseholdPaths
import Loam.Authority.HouseholdAuthority
import Loam.Config.BalanceViewConfig
import Loam.Review.CurrentBalanceReview
import Loam.Tui.Balances
import Loam.Tui.BalanceViewSetupSession
import Loam.Tui.DailyPacePoolSetup
import Loam.Tests.Support

namespace Loam.Tests.TuiBalanceViewSetup

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

private def jpy : MeasureId := ⟨"jpy"⟩
private def bank : EffectCoordinate := ⟨⟨"bank"⟩, jpy⟩
private def cash : EffectCoordinate := ⟨⟨"cash"⟩, jpy⟩
private def usd : EffectCoordinate := ⟨⟨"foreign"⟩, ⟨"usd"⟩⟩

def main : IO Unit := do
  let base ← IO.FS.createTempDir
  let root := base / "fresh"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "initialize independent ordinary household"
  let config := Loam.HouseholdPaths.balanceView root
  let before ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let empty ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.prepare root jpy)
    "read first-run neutral Balance view selection"
  expect (empty.candidates.isEmpty && empty.previous.isEmpty)
    "first-run Balance display invented an account or a balance"
  expect (!(← config.pathExists))
    "opening neutral Balance setup wrote a config file"

  let _ ← requireOk (← Loam.HouseholdCommand.admitLocus root { token := "bank" })
    "admit new bank Locus without quantity"
  let _ ← requireOk (← Loam.HouseholdCommand.admitLocus root { token := "cash" })
    "admit new cash Locus without quantity"
  let ready ← requireOk (← Loam.Tui.BalanceViewSetupSession.prepare root jpy)
    "read admitted Loci for Balance view"
  expect (ready.candidates.contains bank && ready.candidates.contains cash)
    "unobserved admitted assets were missing from neutral display candidates"
  let state := Loam.Tui.DailyPacePoolSetup.initialBalanceDisplay
    jpy ready.candidates []
  let checked := Loam.Tui.DailyPacePoolSetup.update state (.input ' ')
  expect (checked.state.chosen.length == 1)
    "Space did not toggle neutral Balance display selection"
  let preview := Loam.Tui.DailyPacePoolSetup.update checked.state .enter
  expect (preview.state.phase == .review && preview.publish.isNone)
    "first Enter published without review"
  let back := Loam.Tui.DailyPacePoolSetup.update preview.state .escape
  expect (back.state.phase == .choose && back.publish.isNone)
    "Esc did not restore display selection"
  let confirm := Loam.Tui.DailyPacePoolSetup.update preview.state .enter
  let some selected := confirm.publish
    | throw (IO.userError "second Enter did not publish accepted view selection")
  let canonicalBefore ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let _ ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.save root jpy ready selected)
    "publish neutral display selection"
  let loaded ← requireSome (← Loam.BalanceViewConfig.load? config)
    "reload exact Balance view configuration"
  expect (loaded == selected) "Balance view selection did not round-trip"
  let balance ← requireOk (← Loam.CurrentBalanceReview.loadSnapshot root root)
    "reopen neutral support with admitted but unobserved bank"
  match (Loam.Tui.Balances.initial balance [bank]).rows with
  | [.unsupported coordinate] =>
      expect (coordinate == bank)
        "unsupported balance changed coordinate"
  | _ => throw (IO.userError "Balance view invented a zero/exact quantity for unobserved bank")
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == canonicalBefore)
    "display-only change modified canonical household data"

  -- Neutral Balance display can intentionally be cleared to an empty view.
  let clearReady ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.prepare root jpy)
    "reload display configuration"
  let clearScreen := Loam.Tui.DailyPacePoolSetup.initialBalanceDisplay
    jpy clearReady.candidates selected
  let blank := Loam.Tui.DailyPacePoolSetup.update clearScreen (.input ' ')
  let blankReview := Loam.Tui.DailyPacePoolSetup.update blank.state .enter
  expect (blankReview.state.phase == .review && blankReview.publish.isNone)
    "empty Balance display refused despite no financial claim"
  let _ ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.save root jpy clearReady [])
    "clear only display rows"
  let noRows ← requireSome (← Loam.BalanceViewConfig.load? config)
    "reopen intentionally empty display"
  expect noRows.isEmpty "clearing display left stale selected balance"

  -- Keep other Measure selections, but do not infer any foreign balance.
  IO.FS.writeFile config "foreign\tusd\n"
  let withForeign ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.prepare root jpy)
    "prepare view with other currency row"
  let _ ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.save root jpy withForeign [bank])
    "choose bank while preserving foreign Measure"
  let both ← requireSome (← Loam.BalanceViewConfig.load? config)
    "reload mixed-Measure display"
  expect (both == [usd, bank])
    "updating the current Measure erased foreign display selection"

  let stale ← requireOk
    (← Loam.Tui.BalanceViewSetupSession.prepare root jpy)
    "capture old display state"
  IO.FS.writeFile config "cash\tjpy\n"
  let changed ← IO.FS.readFile config
  expect (!(← Loam.Tui.BalanceViewSetupSession.save root jpy stale [bank]).isOk)
    "stale editor replaced a newer view choice"
  expect ((← IO.FS.readFile config) == changed)
    "stale edit changed query bytes despite refusal"
  IO.FS.writeFile config "bad\tdata\textra\n"
  expect (!(← Loam.Tui.BalanceViewSetupSession.prepare root jpy).isOk)
    "malformed view silently became a clean default"
  expect ((← IO.FS.readFile config) == "bad\tdata\textra\n")
    "opening invalid display repaired config without approval"

  for bounds in
    ([{ width := 32, height := 9 }, { width := 80, height := 24 }] :
      List Loam.Tui.Kernel.Bounds) do
    for screen in [state, checked.state, preview.state] do
      let widget := Loam.Tui.DailyPacePoolSetup.view bounds screen
      expect (decide (widget.lines.length ≤ bounds.height))
        "visible-account picker exceeds terminal height"
      for line in widget.lines do
        expect (decide (Loam.Tui.Layout.displayWidth
            (String.ofList (line.map (·.glyph))) ≤
            Loam.Tui.Layout.contentWidth bounds))
          "visible-account picker exceeds terminal width"

  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == canonicalBefore &&
          before != canonicalBefore)
    "setup changed canonical evidence or admission did not occur"
  IO.println "Balance display: admitted unobserved bank remains '?'; review, empty selection, foreign Measure retention, stale/malformed refusal and no canonical mutation passed."

end Loam.Tests.TuiBalanceViewSetup

def main : IO Unit := Loam.Tests.TuiBalanceViewSetup.main
