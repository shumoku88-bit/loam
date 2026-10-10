import Loam.Review.DailyPacePeriods
import Loam.Tests.ActualWorldFixture
import Loam.Config.DailyPaceConfig
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ZeroOriginCoveragePersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def yen : MeasureId := ⟨"jpy"⟩
private def usd : MeasureId := ⟨"usd"⟩
private def wallet : LocusId := ⟨"wallet"⟩
private def cash : LocusId := ⟨"cash"⟩
private def expense : LocusId := ⟨"expense"⟩
private def income : LocusId := ⟨"income"⟩

private def coordinateForMeasure (measure : MeasureId) (locus : LocusId) : EffectCoordinate :=
  ⟨locus, measure⟩

private def coordinate (locus : LocusId) : EffectCoordinate :=
  coordinateForMeasure yen locus

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduledForMeasure?
    (measure : MeasureId)
    (id date : String) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? measure changes
  pure { id := ⟨id⟩, scheduledOn := date, movement := movement }

private def scheduled?
    (id date : String) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence String) :=
  scheduledForMeasure? yen id date changes

private def admittedScheduled : IO Loam.ScheduledReview.EvidenceSnapshot := do
  let overdue ← requireSome
    (scheduled? "overdue" "2026-09-07" [change wallet (-300), change expense 300])
    "overdue Scheduled fixture"
  let internalTransfer ← requireSome
    (scheduled? "transfer" "2026-09-10" [change wallet (-200), change cash 200])
    "internal transfer Scheduled fixture"
  let plannedInflow ← requireSome
    (scheduled? "inflow" "2026-09-11" [change income (-1000), change wallet 1000])
    "planned inflow Scheduled fixture"
  let futureOutflow ← requireSome
    (scheduled? "future" "2026-09-12" [change cash (-500), change expense 500])
    "future outflow Scheduled fixture"
  let boundary ← requireSome
    (scheduled? "boundary" "2026-09-18" [change wallet (-900), change expense 900])
    "boundary Scheduled fixture"
  let memory ← requireSome
    (ScheduledMemory.ofOccurrences?
      [futureOutflow, boundary, plannedInflow, internalTransfer, overdue])
    "Scheduled memory fixture"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal fixture"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event fixture"
  pure { scheduled := memory, terminals := terminals, events := events }

private def expectError {α : Type} (value : Except String α) (message : String) : IO Unit :=
  match value with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError message)

def main : IO Unit := do
  let selection := [coordinate wallet, coordinate cash]
  let balances : Loam.BalanceReview.Snapshot := {
    rows := [
      { coordinate := coordinate wallet, quantity := Quantity.ofQuanta 2000 },
      { coordinate := coordinate cash, quantity := Quantity.ofQuanta 500 }
    ]
  }
  let scheduled ← admittedScheduled

  expect ((Loam.DailyPaceConfig.decode? "wallet\tjpy\ncash\tjpy\n").isSome)
    "Daily Pace config rejected a valid explicit JPY pool"
  expect ((Loam.DailyPaceConfig.decode? "wallet\tjpy\nwallet\tjpy\n").isNone)
    "Daily Pace config accepted duplicate coordinates"
  expect ((Loam.DailyPaceConfig.decode? "wallet\tusd\n").isNone)
    "JPY compatibility Daily Pace config accepted a non-JPY coordinate"
  expect
    ((Loam.DailyPaceConfig.decodeForMeasure? usd "wallet\tusd\ncash\tusd\n").isSome)
    "Daily Pace config rejected a valid explicit USD pool"
  expect
    ((Loam.DailyPaceConfig.decodeForMeasure? usd "wallet\tjpy\n").isNone)
    "USD Daily Pace config accepted a JPY coordinate"

  let pace ←
    match Loam.CycleSpendingPaceReview.project
        "2026-09-08" "2026-09-18" selection balances scheduled with
    | .error message => throw (IO.userError message)
    | .ok pace => pure pace

  expect (pace.remainingDays == 10) "Daily Pace remaining-day count drifted"
  expect (pace.eligiblePool.quanta == 2500) "Daily Pace eligible pool drifted"
  expect (pace.automaticDeductions.quanta == 800)
    "Daily Pace did not protect overdue + future pool outflows exactly once"
  expect (pace.availableThroughEnd.quanta == 1700)
    "Daily Pace available-through-end arithmetic drifted"
  expect (pace.dailyPaceQuanta? == some 170)
    "Daily Pace exact integer-quanta presentation drifted"

  let usdSelection := [coordinateForMeasure usd wallet, coordinateForMeasure usd cash]
  let usdBalances : Loam.BalanceReview.Snapshot := {
    rows := [
      { coordinate := coordinateForMeasure usd wallet, quantity := Quantity.ofQuanta 3000 },
      { coordinate := coordinateForMeasure usd cash, quantity := Quantity.ofQuanta 500 }
    ]
  }
  let usdOutflow ← requireSome
    (scheduledForMeasure? usd "usd-outflow" "2026-09-12"
      [change cash (-700), change expense 700])
    "USD Daily Pace Scheduled fixture"
  let jpyOutflow ← requireSome
    (scheduled? "jpy-outflow" "2026-09-12"
      [change cash (-900), change expense 900])
    "JPY isolation Scheduled fixture"
  let usdScheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [usdOutflow, jpyOutflow])
    "mixed-Measure Daily Pace Scheduled memory"
  let usdTerminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "mixed-Measure Daily Pace empty terminal memory"
  let usdEvents ← requireSome (EventMemory.ofEvents? [])
    "mixed-Measure Daily Pace empty Event memory"
  let usdScheduled : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := usdScheduledMemory
    terminals := usdTerminals
    events := usdEvents
  }
  let usdPace ←
    match Loam.CycleSpendingPaceReview.projectForMeasure
        usd "2026-09-08" "2026-09-18" usdSelection usdBalances usdScheduled with
    | .error message => throw (IO.userError message)
    | .ok value => pure value
  expect (usdPace.measure == usd) "Daily Pace lost the requested Measure"
  expect (usdPace.eligiblePool.quanta == 3500) "USD Daily Pace eligible pool"
  expect (usdPace.automaticDeductions.quanta == 700)
    "JPY Scheduled pressure leaked into USD Daily Pace"
  expect (usdPace.availableThroughEnd.quanta == 2800)
    "USD Daily Pace available-through-end arithmetic"
  expect (usdPace.dailyPaceQuanta? == some 280)
    "USD Daily Pace integer-quanta presentation"
  expectError
    (Loam.CycleSpendingPaceReview.projectForMeasure
      usd "2026-09-08" "2026-09-18" selection balances scheduled)
    "USD Daily Pace accepted a JPY pool"

  let earliest ←
    match Loam.ScheduledReview.earliestCurrentOpenRecord scheduled with
    | .error message => throw (IO.userError message)
    | .ok value => pure value
  match earliest with
  | some record =>
      expect (record.id.token == "overdue")
        "earliest current-open Scheduled did not preserve overdue action pressure"
  | none => throw (IO.userError "expected an earliest current-open Scheduled record")

  expectError
    (Loam.CycleSpendingPaceReview.project
      "2026-09-18" "2026-09-18" selection balances scheduled)
    "Daily Pace accepted an empty current-cycle horizon"

  let opening ← requireSome
    (Event.ofEffects? ⟨"opening"⟩
      [ Effect.ofQuantity ⟨"opening-wallet"⟩ wallet yen (Quantity.ofQuanta 2000)
      , Effect.ofQuantity ⟨"opening-income"⟩ income yen (Quantity.ofQuanta (-2000))
      ])
    "Daily Pace history opening Event fixture"
  let spend ← requireSome
    (Event.ofEffects? ⟨"spend"⟩
      [ Effect.ofQuantity ⟨"spend-wallet"⟩ wallet yen (Quantity.ofQuanta (-500))
      , Effect.ofQuantity ⟨"spend-expense"⟩ expense yen (Quantity.ofQuanta 500)
      ])
    "Daily Pace history spending Event fixture"
  let completion ← requireSome
    (Event.ofEffects? ⟨"completion"⟩
      [ Effect.ofQuantity ⟨"completion-cash"⟩ cash yen (Quantity.ofQuanta (-300))
      , Effect.ofQuantity ⟨"completion-expense"⟩ expense yen (Quantity.ofQuanta 300)
      ])
    "Daily Pace history completion Event fixture"
  let historyEvents ← requireSome
    (EventMemory.ofEvents? [opening, spend, completion])
    "Daily Pace history Event memory fixture"
  let historyValidity ← requireSome
    (ActualValidityHistory.ofParts?
      [ .base opening.id "2026-09-08"
      , .base spend.id "2026-09-09"
      , .base completion.id "2026-09-10"
      ]
      [])
    "Daily Pace history Actual validity fixture"
  let actualEvidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := historyEvents
      validity := historyValidity
  }
  let image ← requireSome
    (Loam.Persistence.admitActualImage? actualEvidence)
    "Daily Pace history admitted Actual image"

  let bill ← requireSome
    (scheduled? "bill" "2026-09-12" [change cash (-300), change expense 300])
    "Daily Pace history bill fixture"
  let laterBill ← requireSome
    (scheduled? "later-bill" "2026-09-13" [change cash (-500), change expense 500])
    "Daily Pace history later bill fixture"
  let historyScheduledMemory ← requireSome
    (ScheduledMemory.ofOccurrences? [bill, laterBill])
    "Daily Pace history Scheduled memory fixture"
  let historyTerminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := bill.id, target := some (.actual completion.id) }])
    "Daily Pace history terminal fixture"
  let historyScheduled : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := historyScheduledMemory
    terminals := historyTerminals
    events := historyEvents
  }
  let historyBalances : Loam.BalanceReview.Snapshot := {
    rows := [
      { coordinate := coordinate wallet, quantity := Quantity.ofQuanta 1500 },
      { coordinate := coordinate cash, quantity := Quantity.ofQuanta (-300) }
    ]
  }

  let roots ← requireSome
    (Loam.Application.correctionRootIds?
      actualEvidence.events actualEvidence.corrections)
    "Daily Pace history correction roots"
  let anchor ← requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists?
      roots
      [{ coordinate := coordinate wallet, quantity := Quantity.ofQuanta 1500 }])
    "Daily Pace history wallet anchor"
  let bounded ← requireSome
    (Loam.BoundedHistorySupport.Evidence.ofSupports?
      [{ coordinate := coordinate wallet, startDay := "2026-09-08" }])
    "Daily Pace history bounded support"
  let zeroOrigin ← requireSome
    (ZeroOriginCoverage.ofCoordinates? [coordinate cash])
    "Daily Pace history cash zero-origin coverage"
  let historicalEvidence : Loam.HistoricalBalanceReview.Evidence := {
    zeroOrigin := zeroOrigin
    opening := OpeningSupportMap.empty
    bounded := bounded
    anchor := anchor
  }

  let history ←
    match Loam.CycleSpendingPaceReview.projectHistory
        image historicalEvidence
        "2026-09-08" "2026-09-10" "2026-09-18"
        selection historyBalances historyScheduled 7 with
    | .error message => throw (IO.userError message)
    | .ok points => pure points

  expect
    (history.map (fun point => point.observedAt) ==
      ["2026-09-08", "2026-09-09", "2026-09-10"])
    "Daily Pace history did not stay inside the current cycle"
  expect
    (history.map (fun point => point.dailyPaceQuanta?) ==
      [some 120, some 77, some 87])
    "Daily Pace history did not reconstruct completion-aware pace"

  let configured : List Loam.BoundaryPresetConfig.Preset := [{name := "explicit", boundaries :=
    ["2026-08-08", "2026-09-08", "2026-09-18", "2026-10-08"]}]
  let periods := Loam.DailyPacePeriods.project yen image historicalEvidence selection historyBalances historyScheduled configured "2026-09-10"
  let currentPeriod ← requireSome (periods.find? fun period => period.preset == .cycle) "current cycle missing"
  expect (match currentPeriod.history with | .loaded points => points == history | _ => false)
    "extended current-cycle history changed the existing calculation"
  let previous ← requireSome (periods.find? fun period => period.preset == .previousCycle) "previous cycle missing"
  expect (match previous.history with | .failed message => (message.splitOn "precedes bounded history start").length > 1 | _ => false)
    "unsupported previous cycle fabricated points"
  let coverage ← requireSome (ZeroOriginCoverage.ofCoordinates? selection) "period zero origin"
  let allDays : Loam.HistoricalBalanceReview.Evidence := {
    zeroOrigin := coverage, opening := OpeningSupportMap.empty,
    bounded := Loam.BoundedHistorySupport.Evidence.empty,
    anchor := Loam.CurrentQuantityAnchor.Evidence.empty}
  let complete := Loam.DailyPacePeriods.project yen image allDays selection historyBalances historyScheduled configured "2026-09-10"
  let source ← requireSome configured.head? "test boundary source missing"
  for period in complete do
    let .loaded points := period.history | throw (IO.userError ("daily period failed: " ++ period.preset.label))
    let dates ← match period.range.bind Loam.DailyPacePeriods.Range.dates with
      | .ok dates => pure dates | .error message => throw (IO.userError message)
    expect (points.map (·.observedAt) == dates) "display range lost daily grain"
    for point in points do
      let some (start, endExclusive) := Loam.BoundaryPresetConfig.windowForDate? source point.observedAt
        | throw (IO.userError "explicit test boundary missing")
      let some next := Loam.ActualDate.shiftDays? point.observedAt 1 | throw (IO.userError "next day missing")
      let pool ← match Loam.HistoricalBalanceReview.projectStartOfDay image allDays next selection with
        | .ok pool => pure pool | .error message => throw (IO.userError message)
      expect (point.eligiblePool.quanta == pool.rows.foldl (fun total row => total + row.quantity.quanta) 0)
        "batch changed historical balance/correction meaning"
      let expectedDeductions := if endExclusive == "2026-09-08" then 0
        else if point.observedAt < "2026-09-10" then 800 else 500
      expect (point.automaticDeductions.quanta == expectedDeductions &&
        point.availableThroughEnd.quanta == point.eligiblePool.quanta - expectedDeductions)
        "daily reconstruction changed completion/deduction arithmetic"
      expect (start ≤ point.observedAt) "point outside explicit cycle"
      expect (point.endExclusive == endExclusive && point.measure == yen && point.remainingDays > 0)
        "period used calendar-month end or mixed Measures"
  let ten ← requireSome complete.head? "10d period missing"
  let .loaded crossed := ten.history | throw (IO.userError "10d missing")
  let firstCrossed ← requireSome crossed.head? "10d first missing"
  let lastCrossed ← requireSome crossed.getLast? "10d last missing"
  expect (crossed.length == 10 && firstCrossed.endExclusive == "2026-09-08" && lastCrossed.endExclusive == "2026-09-18")
    "10d did not cross explicit cycle boundary day by day"
  let previousPeriod ← requireSome complete.getLast? "previous period missing"
  let .loaded prior := previousPeriod.history | throw (IO.userError "previous cycle missing")
  let lastPrior ← requireSome prior.getLast? "previous last missing"
  expect (prior.length == 31 && lastPrior.observedAt == "2026-09-07" && lastPrior.remainingDays == 1)
    "previous completed cycle end was included or compressed to a single point"
  let mismatch := Loam.DailyPacePeriods.project yen image allDays selection
    {historyBalances with rows := []} historyScheduled configured "2026-09-10"
  expect (mismatch.all fun period => match period.history with | .failed _ => true | _ => false)
    "current-pace disagreement allowed historical values"

  expectError
    (Loam.CycleSpendingPaceReview.projectHistory
      image
      { historicalEvidence with bounded := Loam.BoundedHistorySupport.Evidence.empty }
      "2026-09-08" "2026-09-10" "2026-09-18"
      selection historyBalances historyScheduled 7)
    "Daily Pace history silently treated current anchor as historical completeness"

  -- Exercise the canonical household loader used by Home. The pool deliberately
  -- mixes bounded wallet history with zero-origin cash history.
  let root ← IO.FS.createTempDir
  IO.FS.createDirAll (root / "config")
  IO.FS.writeFile
    (root / "config" / "boundary-presets.tsv")
    "cycle\t2026-09-08\t2026-09-18\n"
  IO.FS.writeFile
    (root / "config" / "daily-pace.tsv")
    "wallet\tjpy\ncash\tjpy\n"
  let zeroOriginBody ← requireSome
    (Loam.Persistence.encodeZeroOriginCoverage? zeroOrigin)
    "encode Daily Pace Household zero-origin coverage"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "ZeroOrigin" zeroOriginBody
    | throw (IO.userError "install Daily Pace Household zero-origin coverage")
  let anchorBody ← requireSome
    (Loam.Persistence.encodeCurrentQuantityAnchor? anchor)
    "encode Daily Pace Household current quantity anchor"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "CurrentQuantityAnchor" anchorBody
    | throw (IO.userError "install Daily Pace Household current quantity anchor")
  let boundedBody ← requireSome
    (Loam.Persistence.encodeBoundedHistorySupport? bounded)
    "encode Daily Pace Household bounded history support"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "BoundedHistorySupport" boundedBody
    | throw (IO.userError "install Daily Pace Household bounded history support")
  expect
    (← Loam.Persistence.saveZeroOriginCoverage?
      (Loam.HouseholdPaths.zeroOriginCoverage root) ZeroOriginCoverage.empty)
    "save Daily Pace stale legacy zero-origin coverage"
  let frozenLegacyZero ←
    IO.FS.readFile (Loam.HouseholdPaths.zeroOriginCoverage root)
  expect
    (← Loam.Persistence.saveCurrentQuantityAnchor?
      (Loam.HouseholdPaths.currentQuantityAnchor root) anchor)
    "save Daily Pace history current anchor"
  expect
    (← Loam.Persistence.saveBoundedHistorySupport?
      (Loam.HouseholdPaths.boundedHistorySupport root) bounded)
    "save Daily Pace history bounded support"
  let historyLifecycle : Loam.Persistence.ScheduledLifecycleImage := {
    scheduled := historyScheduledMemory
    terminals := historyTerminals
  }
  let historyScheduledBody ← requireSome
    (Loam.Persistence.encodeScheduledLifecycleImage? historyLifecycle)
    "encode Daily Pace Household Scheduled lifecycle"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" historyScheduledBody
    | throw (IO.userError "install Daily Pace Household Scheduled lifecycle")
  expect
    (← Loam.Persistence.saveScheduledLifecycleImage?
      (Loam.HouseholdPaths.scheduled root) historyLifecycle)
    "save Daily Pace frozen legacy Scheduled lifecycle"

  let loadedHistory ←
    match ← Loam.CycleSpendingPaceReview.loadHistoryFromActualImageAt
        root image "2026-09-10" 7 with
    | .error message =>
        throw (IO.userError ("load canonical bounded Daily Pace history: " ++ message))
    | .ok points => pure points
  expect (loadedHistory == history)
    "canonical Daily Pace history loader diverged from the shared historical projection"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.zeroOriginCoverage root)) ==
      frozenLegacyZero)
    "Daily Pace history read changed frozen legacy zero-origin evidence"

  -- A retained Scheduled completion remains active when its Actual endpoint is
  -- later corrected. Correction changes current Event interpretation but does
  -- not erase the retained occurrence identity named by the terminal relation.
  let correctedCompletion ← requireSome
    (Event.ofEffects? ⟨"completion-corrected"⟩
      [ Effect.ofQuantity ⟨"completion-corrected-cash"⟩ cash yen (Quantity.ofQuanta (-300))
      , Effect.ofQuantity ⟨"completion-corrected-expense"⟩ expense yen (Quantity.ofQuanta 300)
      ])
    "Daily Pace corrected completion Event fixture"
  let correctedEvents ← requireSome
    (EventMemory.ofEvents? [opening, spend, completion, correctedCompletion])
    "Daily Pace corrected completion Event memory"
  let correctedCorrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := completion.id, replacement := correctedCompletion.id }])
    "Daily Pace corrected completion relation"
  let correctedValidity ← requireSome
    (ActualValidityHistory.ofParts?
      [ .base opening.id "2026-09-08"
      , .base spend.id "2026-09-09"
      , .base completion.id "2026-09-10"
      , .base correctedCompletion.id "2026-09-10"
      ]
      [])
    "Daily Pace corrected completion validity"
  let correctedEvidence : Loam.ActualEvidence := {
    Loam.ActualEvidence.empty with
      events := correctedEvents
      corrections := correctedCorrections
      validity := correctedValidity
  }
  let correctedImage ← requireSome
    (Loam.Persistence.admitActualImage? correctedEvidence)
    "Daily Pace corrected completion admitted image"
  expect
    ((correctedImage.currentEvents.findById? completion.id).isNone &&
      (correctedImage.evidence.events.findById? completion.id).isSome)
    "fixture did not distinguish current interpretation from retained completion identity"

  let correctedHistory ←
    match ← Loam.CycleSpendingPaceReview.loadHistoryFromActualImageAt
        root correctedImage "2026-09-10" 7 with
    | .error message =>
        throw (IO.userError
          ("corrected completion reopened Scheduled or broke Daily Pace parity: " ++ message))
    | .ok points => pure points
  expect (correctedHistory == history)
    "Actual Correction changed retained Scheduled completion meaning"

  let retirementTerminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := laterBill.id, target := none }])
    "Daily Pace history retirement fixture"
  let retiredScheduled : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := historyScheduledMemory
    terminals := retirementTerminals
    events := historyEvents
  }
  expectError
    (Loam.CycleSpendingPaceReview.projectHistory
      image historicalEvidence
      "2026-09-08" "2026-09-10" "2026-09-18"
      selection historyBalances retiredScheduled 7)
    "Daily Pace history invented a retirement date"

  let retiredPeriods := Loam.DailyPacePeriods.project yen image allDays selection historyBalances
    retiredScheduled configured "2026-09-10"
  let retiredCycle ← requireSome (retiredPeriods.find? fun period => period.preset == .cycle) "retired cycle missing"
  expect (match retiredCycle.history with | .failed _ => true | _ => false)
    "extended history invented Scheduled retirement time"

  IO.println
    "Cycle Spending Pace: explicit pool, per-Scheduled deduction, boundary and earliest-open checks passed."
