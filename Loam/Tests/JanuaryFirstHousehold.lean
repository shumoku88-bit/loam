import Loam.Cli.NewHouseholdCli
import Loam.HouseholdCommand
import Loam.Authority.ActualAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.Review.CurrentBalanceReview
import Loam.Review.CycleSpendingPaceReview
import Loam.Review.ScheduledReview
import Loam.Review.ActualReview
import Loam.Tui.Cli
import Loam.Tests.Support

namespace Loam.Tests.JanuaryFirstHousehold

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

/-!
#2030 first product-facing annual preflight: same installed HouseholdImage over
the Dec-31/Jan-1 day boundary. This uses qualified production publishers and
normal composed Home readers, but does NOT claim an annual source-journal
writer or trustworthy publication-date metadata already exists.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : EffectCoordinate := ⟨⟨"bank"⟩, yen⟩
private def cash : EffectCoordinate := ⟨⟨"cash"⟩, yen⟩

private def effects (amount : Int) : List Effect :=
  [ Effect.ofAnonymousQuantity ⟨"bank"⟩ yen (Quantity.ofQuanta (-amount))
  , Effect.ofAnonymousQuantity ⟨"food"⟩ yen (Quantity.ofQuanta amount) ]

private def buy (root : System.FilePath) (on : String) (amount : Int) :
    IO EventId := do
  let draft : Loam.MovementAdmission.Draft := {
    validOn := on
    description := some "synthetic cross-year expense"
    effects := effects amount
    relations := []
    discharges := []
    total := amount
  }
  requireOk (← Loam.HouseholdCommand.record root draft) "ordinary Actual record"

private def exactBank (root : System.FilePath) (want : Int) : IO Unit := do
  let balance ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot root root)
    "current balance from one installed household"
  let row ← requireSome (balance.exactRowFor? bank)
    "exact bank disappeared across calendar boundary"
  expect (row.quantity.quanta == want)
    s!"exact bank diverged at year boundary: got {row.quantity.quanta}, want {want}"
  expect (!(Loam.CurrentBalanceReview.selectExact balance [cash]).isOk)
    "unknown cash was manufactured as an exact zero at the year boundary"

private def pace (root : System.FilePath) (today : String)
    (wantEligible wantDeductions : Int) : IO Unit := do
  let snapshot ← requireOk
    (← Loam.CycleSpendingPaceReview.loadSnapshotAt root root today)
    ("cross-year Daily Pace " ++ today)
  expect (snapshot.endExclusive == "2027-02-15")
    "Jan 1 erroneously reset the explicit pension cycle"
  expect (snapshot.eligiblePool.quanta == wantEligible)
    "cross-year Daily Pace failed to follow current observed balance"
  expect (snapshot.automaticDeductions.quanta == wantDeductions)
    "cross-year Scheduled commitment was lost or counted twice"
  expect
    (snapshot.availableThroughEnd.quanta == wantEligible - wantDeductions)
    "cross-year available funds disagree with explicitly known support"
  expect (snapshot.remainingDays > 0)
    "cross-year pace lost remaining days inside one unchanged cycle"

private def home (root : System.FilePath) (today : String)
    (expectRecords : Nat) : IO Unit := do
  let observed ← requireOk
    (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "load one admitted annual-crossing Household generation"
  let snapshot ← requireOk
    (← Loam.Tui.Cli.loadSnapshotFromActualImage root today observed.image
      (some observed.generation) false)
    "open ordinary Home without a new household or annual wizard"
  expect (snapshot.actual.today == today)
    "Home date did not advance on same household"
  expect (snapshot.actual.allRecords.length == expectRecords)
    "Home lost retained Actual identities at calendar rollover"
  match snapshot.scheduled with
  | .ok _ => pure ()
  | .error detail => throw (IO.userError ("Home Scheduled became unavailable: " ++ detail))

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let root := parent / "same-household"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "create isolated qualified ordinary household"

  for token in ["bank", "cash", "food"] do
    let _ ← requireOk (← Loam.HouseholdCommand.admitLocus root { token })
      ("admit synthetic Locus " ++ token)
    pure ()
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root
      { locus := ⟨"bank"⟩, role := .asset })
    "assign ordinary bank role"
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root
      { locus := ⟨"food"⟩, role := .expense })
    "assign ordinary expense role"
  let _ ← requireOk
    (← Loam.HouseholdCommand.observeCurrentQuantities root
      [{ coordinate := bank, quantity := Quantity.ofQuanta 10000 }])
    "observe known bank without claiming historical coverage"

  let plan ← requireSome
    (BalancedMovement.ofChanges? yen [
      { coordinate := ⟨"bank"⟩, quantity := Quantity.ofQuanta (-1500) },
      { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 1500 }
    ]) "create future balanced Scheduled movement"
  let scheduledId ← requireOk
    (← Loam.HouseholdCommand.createScheduled root {
      scheduledOn := "2027-01-03", movement := plan
    }) "create unpaid 2027 Scheduled before 2026 ends"

  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile (root / "config" / "daily-pace.tsv") "bank\tjpy\n"
  IO.FS.writeFile (root / "config" / "boundary-presets.tsv")
    "pension\t2026-12-15\t2027-02-15\n"

  let oldEvent ← buy root "2026-12-31" 500
  exactBank root 9500
  home root "2026-12-31" 1
  pace root "2026-12-31" 9500 1500

  -- Simulate next-day Home from an independent ordinary query, not from the
  -- host system clock. Pure midnight with NO accepted source publication
  -- must not modify canonical data or create empty annual journal files.
  let beforeMidnight ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "read pre-Jan-1 committed source generation"
  home root "2027-01-01" 1
  exactBank root 9500
  pace root "2027-01-01" 9500 1500
  let afterMidnight ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "reopen exact same qualified source after midnight"
  expect (beforeMidnight.wire == afterMidnight.wire)
    "merely opening LOAM on Jan 1 rewrote the household source"
  expect (!(← (root / "journal" / "2027").pathExists))
    "the current single-file engine manufactured a new source-year journal"

  let newEvent ← buy root "2027-01-01" 250
  let afterNewYearRecord ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "reopen after first admitted new-year expense"
  expect (afterNewYearRecord.wire != afterMidnight.wire)
    "first Jan-1 new Actual did not publish a new source generation"
  let actual ← requireOk (← Loam.ActualAuthority.loadHouseholdActual? root)
    "review actual records across two calendar years"
  expect ((actual.events.findById? oldEvent).isSome &&
          (actual.events.findById? newEvent).isSome)
    "the January record overwrote December instead of extending the same household"
  expect (actual.events.events.length == 2)
    "a new-year rollover fabricated annual close/opening Actual events"
  home root "2027-01-01" 2
  exactBank root 9250
  pace root "2027-01-01" 9250 1500

  let _ ← requireOk
    (← Loam.HouseholdCommand.correctActual root {
      target := oldEvent
      effects := effects 400
      description := some "correction admitted after Jan 1, effective Dec 31"
    }) "correct earlier-year expense without losing retained Event"
  let corrected ← requireOk
    (← Loam.ActualAuthority.loadHouseholdActual? root)
    "reopen after January correction of December expense"
  expect (corrected.corrections.targetsEvent oldEvent &&
          (corrected.events.findById? oldEvent).isSome &&
          (corrected.events.findById? newEvent).isSome)
    "January correction removed December provenance or Jan-1 identity"
  let correctedImage ← requireOk
    (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "load admitted correction for effective-year review"
  let records := Loam.ActualReview.recordsFromActualImage correctedImage.image
  let dec31 := Loam.ActualReview.select records (.day "2026-12-31")
  let jan01 := Loam.ActualReview.select records (.day "2027-01-01")
  expect (dec31.length == 1 && jan01.length == 1)
    "cross-year effective-date queries lost corrected December or January record"
  exactBank root 9350
  pace root "2027-01-02" 9350 1500

  -- A Scheduled completion is one Actual+Scheduled publisher generation,
  -- even though its occurrence was known in the previous calendar year.
  let beforeCompletion ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "capture generation before cross-year Scheduled completion"
  let _ ← requireOk
    (← Loam.HouseholdCommand.completeScheduled root {
      scheduled := scheduledId
      movement := {
        validOn := "2027-01-03"
        description := some "paid synthetic January bill"
        effects := effects 1500
        relations := []
        discharges := []
        total := 1500
      }
    }) "complete January bill atomically from Scheduled to Actual"
  let afterCompletion ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "reopen completed Actual and Scheduled generation"
  expect (afterCompletion.wire != beforeCompletion.wire)
    "Scheduled completion did not publish"
  expect (Loam.HouseholdAuthority.preservesUntouched
    beforeCompletion.image afterCompletion.image ["Actual", "Scheduled"])
    "Scheduled+Actual completion modified unrelated canonical sections"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.previousPath root)) ==
          beforeCompletion.wire)
    "previous-generation recovery bytes did not match the entire accepted pre-completion generation"
  let scheduled ← requireOk
    (← Loam.ScheduledReview.loadHouseholdEvidence root root)
    "reopen Scheduled after January payment"
  let openRecords ← requireOk
    (Loam.ScheduledReview.currentOpenRecords scheduled)
    "read still-open Scheduled"
  expect openRecords.isEmpty
    "completed cross-year bill was still deducted as unpaid"
  exactBank root 7850
  pace root "2027-01-03" 7850 0
  home root "2027-01-03" 4

  let support ← requireOk
    (← Loam.CurrentSupportAuthority.loadHousehold? root)
    "reopen cross-year evidence support"
  expect support.snapshot.bounded.supports.isEmpty
    "Jan 1 silently claimed historically complete recording"
  expect (!(← (root / "journal" / "2027").pathExists))
    "existing production source unexpectedly acquired an unqualified 2027 journal"

  IO.println "Jan-1 existing-engine preflight PASS: same root, read-only midnight, exact/unknown balances, pension Daily Pace, Scheduled, Dec/Jan Actual, Jan correction and one Actual+Scheduled completion. Native Git source-year publication remains UNIMPLEMENTED and is NOT qualified by this test."

end Loam.Tests.JanuaryFirstHousehold

def main : IO Unit := Loam.Tests.JanuaryFirstHousehold.main
