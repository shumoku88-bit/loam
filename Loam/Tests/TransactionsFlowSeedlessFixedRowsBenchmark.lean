import Loam.Observations.Observation331

namespace Loam.Tests.TransactionsFlowSeedlessFixedRowsBenchmark

open Loam.Core

set_option autoImplicit false

private abbrev Row :=
  EffectCoordinate × Loam.TransactionsFlowReview.RowActivity

private def jpy : MeasureId := ⟨"jpy"⟩
private def cash : LocusId := ⟨"cash"⟩

private def expenseLocus (i : Nat) : LocusId :=
  ⟨s!"expense-{i}"⟩

private def mkEvent (categories i : Nat) : Event :=
  {
    id := ⟨s!"bench-fixed-{categories}-{i}"⟩
    effects :=
      [ Effect.ofAnonymousQuantity cash jpy (Quantity.ofQuanta (-1))
      , Effect.ofAnonymousQuantity
          (expenseLocus (i % categories)) jpy (Quantity.ofQuanta 1)
      ]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
  }

private def mkColumn
    (categories i : Nat) : Loam.TransactionsFlowReview.Column :=
  {
    event := mkEvent categories i
    date := "2026-09-01"
    description := ""
  }

private def mkSnapshot
    (categories events : Nat) : Loam.TransactionsFlowReview.Snapshot :=
  {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    columns := (List.range events).map (mkColumn categories)
  }

private def coordinateLe (left right : EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

@[noinline] private def baselineRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : List Row :=
  snapshot.rows.map fun coordinate =>
    (coordinate, Loam.TransactionsFlowReview.rowActivity snapshot coordinate)

@[noinline] private def candidateRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : List Row :=
  ((Loam.Observation331.buildSeedlessRowIndex snapshot).toList.map fun entry =>
      let key := entry.1
      let coordinate : EffectCoordinate :=
        { locus := ⟨key.1⟩, measure := ⟨key.2⟩ }
      (coordinate, Loam.Observation331.activityFromState entry.2))
    |>.mergeSort fun left right => coordinateLe left.1 right.1

@[noinline] private def forceRows (rows : List Row) : Nat × Int :=
  rows.foldl
    (fun state row =>
      ( state.1 + row.1.locus.token.length + row.1.measure.token.length +
          row.2.activeEvents
      , state.2 + row.2.positive.quanta + row.2.negative.quanta ))
    (0, 0)

@[noinline] private def timeOne
    (action : Unit → List Row) : IO (Nat × List Row × (Nat × Int)) := do
  let t0 ← IO.monoNanosNow
  let rows := action ()
  let forced := forceRows rows
  if forced.1 == 999999999 then
    IO.println "unreachable"
  else
    pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, rows, forced)

private def median (samples : List Nat) : Nat :=
  let sorted := samples.toArray.qsort (· < ·)
  sorted[sorted.size / 2]!

private def pairedMedianUs
    (iterations : Nat)
    (baseline candidate : Unit → List Row) :
    IO (Nat × Nat × List Row × List Row × (Nat × Int) × (Nat × Int)) := do
  let mut baseTimes : List Nat := []
  let mut candTimes : List Nat := []
  let mut baseRows : List Row := []
  let mut candRows : List Row := []
  let mut baseForced : Nat × Int := (0, 0)
  let mut candForced : Nat × Int := (0, 0)

  for i in List.range iterations do
    if i % 2 = 0 then
      let (baseUs, baseResult, baseValue) ← timeOne baseline
      let (candUs, candResult, candValue) ← timeOne candidate
      baseTimes := baseUs :: baseTimes
      candTimes := candUs :: candTimes
      baseRows := baseResult
      candRows := candResult
      baseForced := baseValue
      candForced := candValue
    else
      let (candUs, candResult, candValue) ← timeOne candidate
      let (baseUs, baseResult, baseValue) ← timeOne baseline
      baseTimes := baseUs :: baseTimes
      candTimes := candUs :: candTimes
      baseRows := baseResult
      candRows := candResult
      baseForced := baseValue
      candForced := candValue

  pure
    ( median baseTimes
    , median candTimes
    , baseRows
    , candRows
    , baseForced
    , candForced )

private def fmtUs (us : Nat) : String :=
  if us >= 1000000 then
    s!"{us / 1000000}.{(us % 1000000) / 100000} s"
  else if us >= 1000 then
    s!"{us / 1000}.{(us % 1000) / 100} ms"
  else
    s!"{us} µs"

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator > 0 then
    let hundredths := numerator * 100 / denominator
    s!"{hundredths / 100}.{hundredths % 100 / 10}{hundredths % 10}x"
  else
    "∞"

private def runCase
    (reps categories events : Nat) : IO Unit := do
  let snapshot := mkSnapshot categories events
  let (baseUs, candUs, baseResult, candResult, baseForced, candForced) ←
    pairedMedianUs reps
      (fun _ => baselineRows snapshot)
      (fun _ => candidateRows snapshot)

  unless decide (baseResult = candResult) do
    throw <| IO.userError
      s!"semantic mismatch categories={categories} events={events}"

  unless baseForced == candForced do
    throw <| IO.userError
      s!"forced-result mismatch categories={categories} events={events}"

  IO.println
    s!"{categories}\t{events}\t{baseResult.length}\t{fmtUs baseUs}\t{fmtUs candUs}\t{fmtRatio baseUs candUs}"

def runAll : IO Unit := do
  let reps := 5

  IO.println "=== Transactions-Flow seedless fixed-row benchmark ==="
  IO.println "shape: shared cash + repeating expense category"
  IO.println "timed results are retained and compared exactly after measurement"
  IO.println ""
  IO.println "expense_categories\tevents\tactual_rows\tbaseline\tseedless\tspeedup"

  for categories in [16, 32, 64] do
    for events in [1000, 5000, 10000, 25000] do
      runCase reps categories events

  IO.println ""
  IO.println "Fixed-row paired benchmark complete."

end Loam.Tests.TransactionsFlowSeedlessFixedRowsBenchmark

def main : IO Unit :=
  Loam.Tests.TransactionsFlowSeedlessFixedRowsBenchmark.runAll
