import Loam.ActualJournalProjection

namespace Loam.Tests.ActualJournalSortBenchmark

open Loam.Core
open Loam.ActualJournalProjection

set_option autoImplicit false

private def dayString (i : Nat) : String :=
  let day := i % 28 + 1
  if day < 10 then
    s!"2026-09-0{day}"
  else
    s!"2026-09-{day}"

private def event (i : Nat) : Event :=
  {
    id := ⟨s!"journal-event-{i}"⟩
    effects := []
    keyNodup := by simp
  }

private def entry (i : Nat) : Entry :=
  {
    event := event i
    validOn := dayString i
    description := none
  }

private def entries (count : Nat) : List Entry :=
  (List.range count).map fun i =>
    let j := (i * 9973 + 7919) % count
    entry j

private def ordering (left right : Entry) : Ordering :=
  match compare left.validOn right.validOn with
  | .eq => compare left.event.id.token right.event.id.token
  | other => other

private def insertEntry (entry : Entry) : List Entry → List Entry
  | [] => [entry]
  | current :: rest =>
      match ordering entry current with
      | .gt => current :: insertEntry entry rest
      | _ => entry :: current :: rest

@[noinline] private def insertionSort (xs : List Entry) : List Entry :=
  xs.foldl (fun acc current => insertEntry current acc) []

private def entryLe (left right : Entry) : Bool :=
  match ordering left right with
  | .gt => false
  | _ => true

@[noinline] private def mergeSort (xs : List Entry) : List Entry :=
  xs.mergeSort entryLe

private def signature (xs : List Entry) : List (String × String) :=
  xs.map fun current => (current.validOn, current.event.id.token)

@[noinline] private def forceEntries (xs : List Entry) : Nat :=
  xs.foldl
    (fun total current =>
      total + current.validOn.length + current.event.id.token.length)
    0

@[noinline] private def timeOne
    (action : Unit → List Entry) :
    IO (Nat × List Entry × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let digest := forceEntries result
  if digest == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, result, digest)

private def median (samples : List Nat) : Nat :=
  let sorted := samples.toArray.qsort (· < ·)
  sorted[sorted.size / 2]!

private structure Timed where
  insertionUs : Nat
  mergeUs : Nat
  insertionResult : List Entry
  mergeResult : List Entry

private def pairedMedian
    (iterations : Nat)
    (insertionAction mergeAction : Unit → List Entry) : IO Timed := do
  let mut insertionTimes : List Nat := []
  let mut mergeTimes : List Nat := []
  let mut insertionResult : List Entry := []
  let mut mergeResult : List Entry := []

  for i in List.range iterations do
    if i % 2 = 0 then
      let (a, ar, _) ← timeOne insertionAction
      let (b, br, _) ← timeOne mergeAction
      insertionTimes := a :: insertionTimes
      mergeTimes := b :: mergeTimes
      insertionResult := ar
      mergeResult := br
    else
      let (b, br, _) ← timeOne mergeAction
      let (a, ar, _) ← timeOne insertionAction
      insertionTimes := a :: insertionTimes
      mergeTimes := b :: mergeTimes
      insertionResult := ar
      mergeResult := br

  pure {
    insertionUs := median insertionTimes
    mergeUs := median mergeTimes
    insertionResult := insertionResult
    mergeResult := mergeResult
  }

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

private def runCase (count : Nat) : IO Unit := do
  let input := entries count
  let timed ← pairedMedian 5
    (fun _ => insertionSort input)
    (fun _ => mergeSort input)

  unless signature timed.insertionResult == signature timed.mergeResult do
    throw <| IO.userError s!"journal sort mismatch entries={count}"

  IO.println
    s!"{count}\t{fmtUs timed.insertionUs}\t{fmtUs timed.mergeUs}\t{fmtRatio timed.insertionUs timed.mergeUs}"

def runAll : IO Unit := do
  IO.println "=== Actual journal sort paired benchmark ==="
  IO.println "baseline: current insertion-sort mechanics; candidate: List.mergeSort"
  IO.println "same Entry ordering: validOn, then EventId token"
  IO.println "timed result lists retained; exact ordered signatures checked after timing"
  IO.println ""
  IO.println "entries\tinsertion\tmergeSort\tspeedup"

  for count in [250, 500, 1000, 2000, 4000, 8000] do
    runCase count

  IO.println ""
  IO.println "Actual journal sort paired benchmark complete."

end Loam.Tests.ActualJournalSortBenchmark

def main : IO Unit :=
  Loam.Tests.ActualJournalSortBenchmark.runAll
