import Loam.CycleSpendingPaceReview
import Loam.DailyPaceConfig

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def yen : MeasureId := ⟨"jpy"⟩
private def wallet : LocusId := ⟨"wallet"⟩
private def cash : LocusId := ⟨"cash"⟩
private def expense : LocusId := ⟨"expense"⟩
private def income : LocusId := ⟨"income"⟩

private def coordinate (locus : LocusId) : EffectCoordinate := ⟨locus, yen⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id date : String) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, scheduledOn := date, movement := movement }

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
    "Daily Pace config accepted a non-JPY coordinate"

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
  let records : List Loam.ActualReview.Record := [
    { event := opening, date := some "2026-09-08", description := "", replacement := none },
    { event := spend, date := some "2026-09-09", description := "", replacement := none },
    { event := completion, date := some "2026-09-10", description := "", replacement := none }
  ]

  let history ←
    match Loam.CycleSpendingPaceReview.projectHistory
        "2026-09-08" "2026-09-10" "2026-09-18"
        selection historyBalances records historyScheduled 7 with
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
      "2026-09-08" "2026-09-10" "2026-09-18"
      selection historyBalances records retiredScheduled 7)
    "Daily Pace history invented a retirement date"

  IO.println
    "Cycle Spending Pace: explicit pool, per-Scheduled deduction, boundary and earliest-open checks passed."
