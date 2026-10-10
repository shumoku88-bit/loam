import Loam.Tui.Cli
import Loam.Tests.ActualWorldFixture
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ZeroOriginCoveragePersistence

namespace Loam.Tests.TuiHomeActualGeneration

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def publishActualGeneration
    (root : System.FilePath)
    (eventToken : String)
    (walletQuanta : Int) : IO Unit := do
  let event ←
    requireSome
      (Event.ofEffects? ⟨eventToken⟩
        [ Effect.ofQuantity
            ⟨eventToken ++ "-wallet"⟩
            ⟨"wallet"⟩
            ⟨"jpy"⟩
            (Quantity.ofQuanta walletQuanta)
        , Effect.ofQuantity
            ⟨eventToken ++ "-income"⟩
            ⟨"income"⟩
            ⟨"jpy"⟩
            (Quantity.ofQuanta (-walletQuanta))
        ])
      "Home generation fixture Event"
  let events ←
    requireSome (EventMemory.ofEvents? [event])
      "Home generation fixture Event memory"
  let validity ←
    requireSome
      (ActualValidityHistory.ofParts?
        [.base event.id "2026-09-24"] [])
      "Home generation fixture Actual validity"
  let evidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
    events := events
    validity := validity
  }
  let _ ←
    requireOk (← Loam.Tests.ActualWorldFixture.publishActualEvidence? root evidence)
      "publish Home Actual generation"
  pure ()

private def initializeIndependentEvidence (root : System.FilePath) : IO Unit := do
  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile
    (root / "config" / "boundary-presets.tsv")
    "cycle\t2026-09-01\t2026-10-01\n"
  IO.FS.writeFile
    (root / "config" / "daily-pace.tsv")
    "wallet\tjpy\n"
  let _ ← requireOk
    (← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root "AccountingRole"
      "LOAM-ACCOUNTING-ROLE-MAP\t1\nROLE\twallet\tASSET\nROLE\tincome\tINCOME\n")
    "Home canonical accounting roles"

  let coverage ←
    requireSome
      (ZeroOriginCoverage.ofCoordinates?
        [⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩])
      "Home generation zero-origin coverage"
  let coverageBody ←
    requireSome
      (Loam.Persistence.encodeZeroOriginCoverage? coverage)
      "encode Home generation Household zero-origin coverage"
  let _ ←
    requireOk
      (← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
        root "ZeroOrigin" coverageBody)
      "install Home generation Household zero-origin coverage"
  expect
    (← Loam.Persistence.saveZeroOriginCoverage?
      (root / "zero-origin-coverage.loam") ZeroOriginCoverage.empty)
    "save Home generation stale legacy zero-origin coverage"

  let scheduled ←
    requireSome
      (ScheduledMemory.ofOccurrences? ([] : List (ScheduledOccurrence String)))
      "Home generation empty Scheduled memory"
  let terminals ←
    requireSome (ScheduledTerminalMemory.ofTerminals? [])
      "Home generation empty Scheduled terminal memory"
  let lifecycle : Loam.Persistence.ScheduledLifecycleImage := { scheduled, terminals }
  let lifecycleBody ←
    requireSome
      (Loam.Persistence.encodeScheduledLifecycleImage? lifecycle)
      "encode Home generation Household Scheduled lifecycle"
  let _ ←
    requireOk
      (← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
        root "Scheduled" lifecycleBody)
      "install Home generation Household Scheduled lifecycle"
  expect
    (← Loam.Persistence.saveScheduledLifecycleImage?
      (root / "scheduled.loam") lifecycle)
    "save Home generation frozen legacy Scheduled lifecycle"

def main : IO Unit := do
  let root ← IO.FS.createTempDir
  initializeIndependentEvidence root

  publishActualGeneration root "generation-a" 1000
  let observedA ←
    requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root)
      "load paired generation A"
  let generationA := observedA.image

  -- Simulate a writer publishing after Home selected its admitted Actual image.
  publishActualGeneration root "generation-b" 2000
  let currentGeneration ←
    requireOk (← Loam.ActualAuthority.loadImage? root)
      "load generation B"
  expect
    ((currentGeneration.currentEvents.findById? ⟨"generation-b"⟩).isSome)
    "fixture did not advance canonical Actual to generation B"

  let snapshot ←
    requireOk
      (← Loam.Tui.Cli.loadSnapshotFromActualImage
        root "2026-09-24" generationA)
      "compose Home from generation A"

  match snapshot.actual.allRecords with
  | [record] =>
      expect (record.event.id.token == "generation-a")
        "Home Actual rows reopened canonical Actual after selecting generation A"
  | _ =>
      throw (IO.userError "Home Actual rows did not preserve the selected generation")

  match snapshot.scheduled with
  | .error message =>
      throw (IO.userError ("Home Scheduled evidence unavailable: " ++ message))
  | .ok scheduled =>
      expect
        ((scheduled.events.findById? ⟨"generation-a"⟩).isSome &&
          (scheduled.events.findById? ⟨"generation-b"⟩).isNone)
        "Home Scheduled validation mixed a later Actual generation"

  match snapshot.paceHistory with
  | .notRequested =>
      throw (IO.userError "Home recent pace was not requested")
  | .unavailable =>
      throw (IO.userError "Home recent pace was unexpectedly unavailable")
  | .failed message =>
      throw (IO.userError ("Home recent pace unavailable: " ++ message))
  | .loaded points =>
      match points.reverse with
      | [] => throw (IO.userError "Home recent pace returned no current point")
      | latest :: _ =>
          expect (latest.eligiblePool.quanta == 1000)
            "Home recent pace reopened canonical Actual after selecting generation A"

  -- Paired production composition needs no second Household read. Removing only
  -- the synthetic authority makes hidden reopens fail deterministically, while
  -- independent query/presentation configuration remains available on disk.
  let household := Loam.HouseholdAuthority.path root
  let held := root / "held-household"
  IO.FS.rename household held
  let (paired, prepared) ←
    try
      let paired ← requireOk (← Loam.Tui.Cli.loadSnapshotFromActualImage
        root "2026-09-24" observedA.image (some observedA.generation))
        "compose paired Home without reopening household"
      let prepared ← requireOk (← Loam.Tui.Cli.loadSnapshotFromActualImage
        root "2026-09-24" observedA.image (some observedA.generation) true)
        "prepare all Daily Pace periods without reopening household"
      pure (paired, prepared)
    finally
      IO.FS.rename held household
  match paired.scheduled with
  | .ok scheduled =>
      expect (scheduled.events.findById? ⟨"generation-a"⟩).isSome
        "paired Scheduled lost the selected Actual generation"
  | .error _ => throw (IO.userError "paired Home reopened Scheduled storage")
  match paired.paceHistory with
  | .loaded points =>
      let latest ← requireSome points.getLast? "paired Home lost the current trend point"
      expect (latest.eligiblePool.quanta == 1000)
        "paired Home mixed current support generations"
  | _ => throw (IO.userError "paired Home reopened pace support storage")
  match paired.moneyCalendar with
  | .loaded _ => pure ()
  | _ => throw (IO.userError "paired Home reopened AccountingRole storage")

  let .loaded periods := prepared.pacePeriods | throw (IO.userError "prepared periods reopened support storage")
  let ten ← requireSome (periods.find? fun period => period.preset == .tenDays) "10d not prepared"
  let .loaded points := ten.history | throw (IO.userError "prepared current range refused")
  let latest ← requireSome points.getLast? "prepared series empty"
  expect (latest.eligiblePool.quanta == 1000) "prepared periods mixed Actual/support generations"
  let observedB ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root) "fresh B"
  let refreshed ← requireOk (← Loam.Tui.Cli.loadSnapshotFromActualImage
    root "2026-09-24" observedB.image (some observedB.generation) true) "refresh prepared Daily Pace"
  let .loaded newPeriods := refreshed.pacePeriods | throw (IO.userError "fresh periods unavailable")
  let newTen ← requireSome (newPeriods.find? fun period => period.preset == .tenDays) "fresh 10d missing"
  let .loaded newPoints := newTen.history | throw (IO.userError "fresh 10d refused")
  let newLatest ← requireSome newPoints.getLast? "fresh current missing"
  expect (newLatest.eligiblePool.quanta == 2000) "fresh reload retained stale pace cache"

  IO.println
    "Home generation: selected Actual, Scheduled, Daily Pace trend and paired family composition survived advancement and no-reopen pressure."

end Loam.Tests.TuiHomeActualGeneration

def main : IO Unit :=
  Loam.Tests.TuiHomeActualGeneration.main
