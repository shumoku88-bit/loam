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

/-- Production-shaped baseline: two independent consumers rebuild the same row image. -/
@[noinline] private def duplicateDigest
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Nat :=
  let left := snapshot.rowActivities
  let right := snapshot.rowActivities
  digestRows left + digestRows right

/-- Candidate shape: build one transient row image and share it across two consumers. -/
@[noinline] private def sharedDigest
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Nat :=
  let rows := snapshot.rowActivities
  digestRows rows + digestRows rows

private def timeUsForced
    (action : Unit → Nat) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let value := action ()
  if value == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, value)

private def timeMedianUs
    (iterations : Nat)
    (action : Unit → Nat) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut value : Nat := 0
  for _ in List.range iterations do
    let (us, observed) ← timeUsForced action
    times := us :: times
    value := observed
  let sorted := times.toArray.qsort (· < ·)
  pure (sorted[sorted.size / 2]!, value)

private def fmtUs (us : Nat) : String :=
  if us >= 1000000 then s!"{us / 1000000}.{(us % 1000000) / 100000} s"
  else if us >= 1000 then s!"{us / 1000}.{(us % 1000) / 100} ms"
  else s!"{us} µs"

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator > 0 then
    let hundredths := numerator * 100 / denominator
    s!"{hundredths / 100}.{hundredths % 100}x"
  else
    "∞"

def main : IO Unit := do
  let sizes := [1000, 5000, 10000, 25000]
  let reps := 5

  IO.println "=== MATH-6 shared Transactions-Flow row image pressure ==="
  IO.println "events | duplicate row image | shared row image | speedup"

  for n in sizes do
    let snapshot := mkSnapshot n
    let expected := duplicateDigest snapshot
    let candidate := sharedDigest snapshot
    unless expected == candidate do
      throw <| IO.userError s!"semantic digest mismatch at N={n}: {expected} != {candidate}"

    let (duplicateUs, duplicateValue) ←
      timeMedianUs reps fun _ => duplicateDigest snapshot
    let (sharedUs, sharedValue) ←
      timeMedianUs reps fun _ => sharedDigest snapshot

    unless duplicateValue == sharedValue do
      throw <| IO.userError s!"timed semantic digest mismatch at N={n}"

    IO.println
      s!"{n} | {fmtUs duplicateUs} | {fmtUs sharedUs} | {fmtRatio duplicateUs sharedUs}"

  IO.println ""
  IO.println "This benchmark isolates only repeated stage-2 row-image construction."
  IO.println "It does not measure whole Web rendering or authorize retained caches."

end Loam.Tests.TransactionsFlowSharedImageBenchmark

def main : IO Unit :=
  Loam.Tests.TransactionsFlowSharedImageBenchmark.main
