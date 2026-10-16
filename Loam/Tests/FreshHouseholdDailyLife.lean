import Loam.Cli.NewHouseholdCli
import Loam.HouseholdCommand
import Loam.Authority.ActualAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.Review.CurrentBalanceReview
import Loam.Review.CycleSpendingPaceReview
import Loam.Review.ScheduledReview
import Loam.Tui.Cli
import Loam.OperationalContinuity
import Loam.Tests.Support

namespace Loam.Tests.FreshHouseholdDailyLife

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : EffectCoordinate := ⟨⟨"bank"⟩, yen⟩
private def cash : EffectCoordinate := ⟨⟨"cash"⟩, yen⟩

private def observe
    (root : System.FilePath) (coordinate : EffectCoordinate) (value : Int) :
    IO Unit := do
  let _ ← requireOk
    (← Loam.HouseholdCommand.observeCurrentQuantities root [
      { coordinate := coordinate, quantity := Quantity.ofQuanta value }
    ]) "observe explicitly known present-day amount"
  pure ()

private def buy (root : System.FilePath) (validOn : String) (amount : Int) :
    IO EventId := do
  let draft : Loam.MovementAdmission.Draft := {
    validOn := validOn
    description := some "new daily-life expense"
    effects := [
      Effect.ofAnonymousQuantity ⟨"bank"⟩ yen (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ yen (Quantity.ofQuanta amount)
    ]
    relations := []
    discharges := []
    total := amount
  }
  requireOk (← Loam.HouseholdCommand.record root draft)
    "record an actual purchase in newly created household"

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let root := parent / "new-independent-household"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "start an independent household"

  -- Before an observation, an unknown current bank amount is NOT zero.
  let emptyBalance ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot root root)
    "read first-run neutral current support"
  expect ((Loam.CurrentBalanceReview.selectExact emptyBalance [bank]).isError)
    "first-run bank balance was silently inferred to be zero"
  let emptyPace ← Loam.CycleSpendingPaceReview.loadSnapshotAt root root "2026-10-16"
  expect emptyPace.isError
    "first-run Daily Pace invented a numerical answer without a configured pool"

  -- The same high-level commands used by normal TUI editors.
  for locus in ["bank", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus root { token := locus })
      ("admit ordinary " ++ locus)
    pure ()
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root {
      locus := ⟨"bank"⟩, role := .asset
    }) "assign bank asset role"
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root {
      locus := ⟨"food"⟩, role := .expense
    }) "assign food expense role"
  observe root bank 10000

  let planned ← requireSome
    (BalancedMovement.ofChanges? yen [
      { coordinate := ⟨"bank"⟩, quantity := Quantity.ofQuanta (-1500) },
      { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 1500 }
    ]) "future payment movement"
  let scheduledId ← requireOk
    (← Loam.HouseholdCommand.createScheduled root {
      scheduledOn := "2026-10-20", movement := planned
    }) "create future unpaid household obligation"

  let eventId ← buy root "2026-10-16" 500
  let afterPurchase ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot root root)
    "reopen after new actual"
  let afterBank ← requireSome (afterPurchase.exactRowFor? bank)
    "exact current bank balance vanished after normal recording"
  expect (afterBank.quantity.quanta == 9500)
    "current anchored bank amount did not follow new actual"

  let scheduled ← requireOk
    (← Loam.ScheduledReview.loadHouseholdEvidence root root)
    "reopen future scheduled obligation"
  let stillOpen ← requireOk
    (Loam.ScheduledReview.currentOpenRecords scheduled)
    "read future unpaid schedule"
  expect (stillOpen.length == 1 &&
          stillOpen.head?.map (·.id) == some scheduledId)
    "new household silently paid or dropped a future obligation"

  -- The Daily Pace query needs explicit replaceable CONFIGURATION. Creating a
  -- household does not manufacture a pool or pension-cycle dates.
  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile (root / "config" / "daily-pace.tsv") "bank\tjpy\n"
  IO.FS.writeFile (root / "config" / "boundary-presets.tsv")
    "pension\t2026-10-15\t2026-12-15\n"
  let pace ← requireOk
    (← Loam.CycleSpendingPaceReview.loadSnapshotAt root root "2026-10-17")
    "current-forward Daily Pace with explicit selected pool and cycle"
  expect (pace.eligiblePool.quanta == 9500)
    "Daily Pace discarded currently observed bank fact"
  expect (pace.automaticDeductions.quanta == 1500)
    "Daily Pace did not protect future unpaid amount"
  expect (pace.availableThroughEnd.quanta == 8000)
    "Daily Pace invented spendable funds"

  -- The next day's ordinary Home reader and same canonical image reopen.
  let observed ← requireOk
    (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "reopen canonical image after initial setup"
  expect ((observed.image.evidence.events.findById? eventId).isSome)
    "next-day reopen lost the purchase"
  let home ← requireOk
    (← Loam.Tui.Cli.loadSnapshotFromActualImage
      root "2026-10-17" observed.image (some observed.generation) true)
    "compose ordinary Home from admitted first-run generation"
  expect (home.actual.allRecords.length == 1)
    "Home silently lost recorded purchase"
  match home.scheduled with
  | .ok evidence =>
      let rows ← requireOk
        (Loam.ScheduledReview.currentOpenRecords evidence)
        "Home current-open Scheduled"
      expect (rows.length == 1)
        "Home did not retain planned future spending"
  | .error error =>
      throw (IO.userError ("Home Scheduled unavailable: " ++ error))

  -- Additional setup is possible tomorrow without re-running initialization.
  let _ ← requireOk
    (← Loam.HouseholdCommand.admitLocus root { token := "cash" })
    "admit cash incrementally after first reopen"
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root {
      locus := ⟨"cash"⟩, role := .asset
    }) "assign later-added cash asset role"
  observe root cash 3000
  let incremental ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot root root)
    "reopen after later incremental setup"
  let bankRow ← requireSome (incremental.exactRowFor? bank)
    "adding a new account removed existing bank balance"
  let cashRow ← requireSome (incremental.exactRowFor? cash)
    "adding new cash account did not provide today's observed quantity"
  expect (bankRow.quantity.quanta == 9500 && cashRow.quantity.quanta == 3000)
    "incremental current observations changed previous exact balances"

  let currentSupport ← requireOk
    (← Loam.CurrentSupportAuthority.loadHousehold? root)
    "qualify current support after reopening"
  expect currentSupport.snapshot.bounded.supports.isEmpty
    "fresh restart fabricated complete historical coverage"
  match ← Loam.OperationalContinuity.diagnoseStartupRead root root with
  | .ok () => pure ()
  | .error diagnosis =>
      throw (IO.userError ("ordinary re-open refused: " ++ diagnosis.technical))

  IO.println "Daily-life fresh restart: unknown bank is not zero; loci/roles, current balance, future Scheduled, ordinary Actual, next-day Home and current-forward pace, later incremental account, and no fictional history passed."

end Loam.Tests.FreshHouseholdDailyLife

def main : IO Unit := Loam.Tests.FreshHouseholdDailyLife.main
