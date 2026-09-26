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

private abbrev Row :=
  EffectCoordinate × Loam.TransactionsFlowReview.RowActivity

private abbrev Rows := List Row
private abbrev RowPair := Rows × Rows

@[noinline] private def digestRows (rows : Rows) : Nat :=
  rows.foldl
    (fun total row =>
      total +
        row.1.locus.token.length +
        row.1.measure.token.length +
        row.2.activeEvents)
    0

@[noinline] private def buildRowsLeft
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Rows :=
  snapshot.rowActivities

@[noinline] private def buildRowsRight
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : Rows :=
  snapshot.rowActivities

/-- Production-shaped baseline: two independent consumers rebuild the same row image. -/
@[noinline] private def duplicateRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : RowPair :=
  (buildRowsLeft snapshot, buildRowsRight snapshot)

/-- Candidate shape: build one transient row image and share it across two consumers. -/
@[noinline] private def sharedRows
    (snapshot : Loam.TransactionsFlowReview.Snapshot) : RowPair :=
  let rows := buildRowsLeft snapshot
  (rows, rows)

@[noinline] private def forcePair (rows : RowPair) : Nat :=
  digestRows rows.1 + digestRows rows.2

private def timeUsForced
    (action : Unit → RowPair) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let digest := forcePair result
  if digest == 0 then
    throw <| IO.userError "benchmark row digest was unexpectedly zero"
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, digest)

private def timeMedianUs
    (iterations : Nat)
    (action : Unit → RowPair) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut digest : Nat := 0
  for _ in List.range iterations do
    let (us, observed) ← timeUsForced action
    times := us :: times
    digest := observed
  let sorted := times.toArray.qsort (· < ·)
  pure (sorted[sorted.size / 2]!, digest)

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
    s!"{hundredths / 100}.{hundredths % 100}x"
  else
    "∞"

def runSize (n : Nat) : IO Unit := do
  unless (mkEvent n).effects.length == 2 do
    throw <| IO.userError "MATH-6 fixture did not retain two Effects per Event"

  let snapshot := mkSnapshot n
  unless snapshot.columns.length == n do
    throw <| IO.userError s!"MATH-6 fixture lost columns at N={n}"

  let expected := forcePair (duplicateRows snapshot)
  let candidate := forcePair (sharedRows snapshot)
  unless expected == candidate do
    throw <| IO.userError s!"semantic digest mismatch at N={n}: {expected} != {candidate}"

  let reps := 5
  let (duplicateUs, duplicateDigest) ←
    timeMedianUs reps fun _ => duplicateRows snapshot
  let (sharedUs, sharedDigest) ←
    timeMedianUs reps fun _ => sharedRows snapshot

  unless duplicateDigest == sharedDigest do
    throw <| IO.userError s!"timed semantic digest mismatch at N={n}"

  IO.println
    s!"{n} | {fmtUs duplicateUs} | {fmtUs sharedUs} | {fmtRatio duplicateUs sharedUs}"

end Loam.Tests.TransactionsFlowSharedImageBenchmark

def main : IO Unit := do
  let args ← IO.getArgs
  let some token := args[0]?
    | throw <| IO.userError "usage: benchmark <event-count>"
  let some n := token.toNat?
    | throw <| IO.userError s!"invalid event count: {token}"
  Loam.Tests.TransactionsFlowSharedImageBenchmark.runSize n
