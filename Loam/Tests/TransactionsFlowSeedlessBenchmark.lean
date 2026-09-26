import Loam.Observations.Observation331

namespace Loam.Tests.TransactionsFlowSeedlessBenchmark

open Loam.Core

set_option autoImplicit false

private abbrev Row :=
  EffectCoordinate × Loam.TransactionsFlowReview.RowActivity

private def jpy : MeasureId := ⟨"jpy"⟩
private def cash : LocusId := ⟨"cash"⟩

private def expenseLocus (i : Nat) : LocusId :=
  ⟨s!"expense-{i}"⟩

private def mkEvent (i : Nat) : Event :=
  {
    id := ⟨s!"bench-{i}"⟩
    effects :=
      [ Effect.ofAnonymousQuantity cash jpy (Quantity.ofQuanta (-1))
      , Effect.ofAnonymousQuantity (expenseLocus i) jpy (Quantity.ofQuanta 1)
      ]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
  }

private def mkColumn (i : Nat) : Loam.TransactionsFlowReview.Column :=
  {
    event := mkEvent i
    date := "2026-09-01"
    description := ""
  }

private def mkSnapshot (n : Nat) : Loam.TransactionsFlowReview.Snapshot :=
  {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    columns := (List.range n).map mkColumn
  }

private def coordinateLe (left right : EffectCoordinate) : Bool :=
  if left.locus.token == right.locus.token then
    left.measure.token <= right.measure.token
  else
    left.locus.token <= right.locus.token

private def baselineRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : List Row :=
  snapshot.rows.map fun coordinate =>
    (coordinate, Loam.TransactionsFlowReview.rowActivity snapshot coordinate)

private def candidateRows
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

private def timeOne (action : Unit → List Row) : IO (Nat × (Nat × Int)) := do
  let t0 ← IO.monoNanosNow
  let rows := action ()
  let forced := forceRows rows
  if forced.1 == 999999999 then
    IO.println "unreachable"
  else
    pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, forced)

private def median (samples : List Nat) : Nat :=
  let sorted := samples.toArray.qsort (· < ·)
  sorted[sorted.size / 2]!

private def pairedMedianUs
    (iterations : Nat)
    (baseline candidate : Unit → List Row) :
    IO (Nat × Nat × (Nat × Int) × (Nat × Int)) := do
  let mut baseTimes : List Nat := []
  let mut candTimes : List Nat := []
  let mut baseForced : Nat × Int := (0, 0)
  let mut candForced : Nat × Int := (0, 0)

  for i in List.range iterations do
    if i % 2 = 0 then
      let (baseUs, baseValue) ← timeOne baseline
      let (candUs, candValue) ← timeOne candidate
      baseTimes := baseUs :: baseTimes
      candTimes := candUs :: candTimes
      baseForced := baseValue
      candForced := candValue
    else
      let (candUs, candValue) ← timeOne candidate
      let (baseUs, baseValue) ← timeOne baseline
      baseTimes := baseUs :: baseTimes
      candTimes := candUs :: candTimes
      baseForced := baseValue
      candForced := candValue

  pure (median baseTimes, median candTimes, baseForced, candForced)

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

def runAll : IO Unit := do
  let sizes := [250, 500, 1000, 2000, 4000]
  let reps := 3

  IO.println "=== Transactions-Flow seedless paired benchmark ==="
  IO.println "shape: each Event has shared cash + one unique expense coordinate"
  IO.println "N events -> N+1 represented rows; two Effects per Event"
  IO.println "baseline: Snapshot.rows + rowActivity per row"
  IO.println "candidate: Observation331 seedless RowIndex + one final coordinate sort"
  IO.println ""
  IO.println "events\trows\tbaseline\tseedless\tspeedup\tbase_growth\tseedless_growth"

  let mut prevBase : Nat := 0
  let mut prevCand : Nat := 0

  for n in sizes do
    let snapshot := mkSnapshot n

    let baselineCheck := baselineRows snapshot
    let candidateCheck := candidateRows snapshot
    unless decide (baselineCheck = candidateCheck) do
      throw <| IO.userError s!"semantic mismatch at N={n}"

    let (baseUs, candUs, baseForced, candForced) ←
      pairedMedianUs reps
        (fun _ => baselineRows snapshot)
        (fun _ => candidateRows snapshot)

    unless baseForced == candForced do
      throw <| IO.userError s!"forced-result mismatch at N={n}"

    let speedup := fmtRatio baseUs candUs
    let baseGrowth :=
      if prevBase > 0 then fmtRatio baseUs prevBase else "-"
    let candGrowth :=
      if prevCand > 0 then fmtRatio candUs prevCand else "-"

    IO.println
      s!"{n}\t{n + 1}\t{fmtUs baseUs}\t{fmtUs candUs}\t{speedup}\t{baseGrowth}\t{candGrowth}"

    prevBase := baseUs
    prevCand := candUs

  IO.println ""
  IO.println "Paired benchmark complete; semantic row equality checked before timing."

end Loam.Tests.TransactionsFlowSeedlessBenchmark

def main : IO Unit :=
  Loam.Tests.TransactionsFlowSeedlessBenchmark.runAll
