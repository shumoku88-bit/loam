import Loam.TransactionsFlowReview

namespace Loam.Tests.TransactionsFlowSharedImageBenchmark

open Loam.Core

set_option autoImplicit false

private def jpy : MeasureId := ⟨"jpy"⟩

private def mkEvent (i : Nat) : Event :=
  let eventId : EventId := ⟨s!"math6-event-{i}"⟩
  let leftKey : EffectKey := ⟨s!"math6-left-{i}"⟩
  let rightKey : EffectKey := ⟨s!"math6-right-{i}"⟩
  let leftLocus : LocusId := ⟨s!"asset-{i % 64}"⟩
  let rightLocus : LocusId := ⟨s!"expense-{i % 64}"⟩
  match Event.ofEffects? eventId
      [ Effect.ofQuantity leftKey leftLocus jpy (Quantity.ofQuanta (-100))
      , Effect.ofQuantity rightKey rightLocus jpy (Quantity.ofQuanta 100)
      ] with
  | some event => event
  | none => { id := eventId, effects := [], keyNodup := by simp }

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

@[noinline] private def digestRows
    (rows : List (EffectCoordinate × Loam.TransactionsFlowReview.RowActivity)) : Nat :=
  rows.foldl
    (fun total row =>
      total +
        row.1.locus.token.length +
        row.1.measure.token.length +
        row.2.activeEvents)
    0

@[noinline] private def buildRowsLeft
    (snapshot : Loam.TransactionsFlowReview.Snapshot) :=
  snapshot.rowActivities

@[noinline] private def buildRowsRight
    (snapshot : Loam.TransactionsFlowReview.Snapshot) :=
  snapshot.rowActivities

/-- Production-shaped baseline: two independent consumers rebuild the same row image. -/
@[noinline] private def duplicateDigest
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Nat :=
  let left := buildRowsLeft snapshot
  let right := buildRowsRight snapshot
  digestRows left + digestRows right

/-- Candidate shape: build one transient row image and share it across two consumers. -/
@[noinline] private def sharedDigest
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Nat :=
  let rows := buildRowsLeft snapshot
  digestRows rows + digestRows rows

@[noinline] private def batchDigest
    (iterations : Nat) (action : Nat → Nat) : Nat :=
  (List.range iterations).foldl
    (fun total iteration => total + action iteration)
    0

private def timeNanosForced
    (batchSize : Nat)
    (action : Nat → Nat) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let value := batchDigest batchSize action
  if value == 0 then throw <| IO.userError "benchmark digest was unexpectedly zero"
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0).toNat, value)

private def timeMedianNanos
    (samples batchSize : Nat)
    (action : Nat → Nat) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut value : Nat := 0
  for _ in List.range samples do
    let (ns, observed) ← timeNanosForced batchSize action
    times := ns :: times
    value := observed
  let sorted := times.toArray.qsort (· < ·)
  pure (sorted[sorted.size / 2]! / batchSize, value)

private def fmtNanos (ns : Nat) : String :=
  if ns >= 1000000000 then
    s!"{ns / 1000000000}.{(ns % 1000000000) / 100000000} s"
  else if ns >= 1000000 then
    s!"{ns / 1000000}.{(ns % 1000000) / 100000} ms"
  else if ns >= 1000 then
    s!"{ns / 1000}.{(ns % 1000) / 100} µs"
  else
    s!"{ns} ns"

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator > 0 then
    let hundredths := numerator * 100 / denominator
    s!"{hundredths / 100}.{hundredths % 100}x"
  else
    "∞"

def main : IO Unit := do
  let sizes := [1000, 5000, 10000, 25000]
  let samples := 5
  let batchSize := 20

  IO.println "=== MATH-6 shared Transactions-Flow row image pressure ==="
  IO.println "events | duplicate row image | shared row image | speedup"

  for n in sizes do
    let snapshot := mkSnapshot n
    let expected := duplicateDigest snapshot
    let candidate := sharedDigest snapshot
    unless expected == candidate do
      throw <| IO.userError s!"semantic digest mismatch at N={n}: {expected} != {candidate}"

    let (duplicateNs, duplicateValue) ←
      timeMedianNanos samples batchSize fun iteration =>
        duplicateDigest snapshot + (iteration % 2)
    let (sharedNs, sharedValue) ←
      timeMedianNanos samples batchSize fun iteration =>
        sharedDigest snapshot + (iteration % 2)

    unless duplicateValue == sharedValue do
      throw <| IO.userError s!"timed semantic digest mismatch at N={n}"

    IO.println
      s!"{n} | {fmtNanos duplicateNs} | {fmtNanos sharedNs} | {fmtRatio duplicateNs sharedNs}"

  IO.println ""
  IO.println "This benchmark isolates only repeated stage-2 row-image construction."
  IO.println "It does not measure whole Web rendering or authorize retained caches."

end Loam.Tests.TransactionsFlowSharedImageBenchmark

def main : IO Unit :=
  Loam.Tests.TransactionsFlowSharedImageBenchmark.main
