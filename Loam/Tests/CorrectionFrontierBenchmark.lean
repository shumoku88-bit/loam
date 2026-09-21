import Loam.Core.EventMemory
import Loam.Core.EventCorrectionMemory
import Loam.Application.CorrectionFrontier

namespace Loam.Tests.CorrectionFrontierBenchmark

open Loam.Core
open Loam.Application

private def mkEvent (i : Nat) : Event :=
  { id := ⟨s!"e-{i}"⟩, effects := [], keyNodup := by simp }

private def buildEventMemory (n : Nat) : EventMemory :=
  match EventMemory.ofEvents? ((List.range n).map mkEvent) with
  | some m => m
  | none => { events := [], idNodup := by simp }

-- Corrected shape: every odd event replaces the preceding even event
private def buildCorrectionMemory (n : Nat) : EventCorrectionMemory :=
  let cCount := n / 2
  let list := (List.range cCount).map fun i =>
    ({ target := ⟨s!"e-{i * 2}"⟩, replacement := ⟨s!"e-{i * 2 + 1}"⟩ } : EventCorrection)
  match EventCorrectionMemory.ofCorrections? list with
  | some m => m
  | none => { corrections := [], idNodup := by simp }

@[noinline] private def forceMemCount (m : Option EventMemory) : Nat :=
  match m with
  | some em => em.events.length
  | none => 0

private def timeUsForced
    (action : Unit → Option EventMemory) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let count := forceMemCount result
  if count == 99999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  let us := (t1 - t0) / 1000
  pure (us, count)

private def timeMedianUs (iterations : Nat)
    (action : Unit → Option EventMemory) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut count : Nat := 0
  for _ in List.range iterations do
    let (us, c) ← timeUsForced action
    times := us :: times
    count := c
  let sorted := times.toArray.qsort (· < ·)
  let mid := sorted.size / 2
  pure (sorted[mid]!, count)

private def fmtUs (us : Nat) : String :=
  if us >= 1000000 then s!"{us / 1000000}.{(us % 1000000) / 100000} s"
  else if us >= 1000 then s!"{us / 1000}.{(us % 1000) / 100} ms"
  else s!"{us} µs"

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator > 0 then
    let tenths := numerator * 10 / denominator
    s!"{tenths / 10}.{tenths % 10}x"
  else
    "∞"

def runAll : IO Unit := do
  let sizes := [1000, 2000, 5000, 10000]
  let reps := 3

  IO.println "=== Phase 3H-0: Paired Benchmark (Correction Frontier Admission) ==="
  IO.println "  N (events)\t| C (corrs)\t| Baseline (Ref)\t| Candidate (Indexed)\t| Speedup\t| Cand Growth"
  IO.println "----------------+---------------+-----------------------+-----------------------+---------------+-------------"

  let mut prevCand : Nat := 0
  for n in sizes do
    let c := n / 2
    let events := buildEventMemory n
    let corrections := buildCorrectionMemory n

    let (baselineUs, countBase) ← timeMedianUs reps fun _ =>
      correctionFrontierMemory? events corrections
    let (candidateUs, countCand) ← timeMedianUs reps fun _ =>
      let idx := buildCorrectionFrontierIndex events corrections
      correctionFrontierMemoryIndexed? events corrections idx

    unless countBase == countCand do
      throw <| IO.userError s!"Semantic mismatch at N={n}: baseline count {countBase} != candidate count {countCand}"

    let speedup := fmtRatio baselineUs candidateUs
    let candGrowth := if prevCand > 0 then fmtRatio candidateUs prevCand else "-"

    IO.println s!"  {n}\t\t| {c}\t\t| {fmtUs baselineUs}\t\t| {fmtUs candidateUs}\t\t| {speedup}\t\t| {candGrowth}"
    prevCand := candidateUs

  IO.println ""
  IO.println "Paired benchmark complete. All measurements taken on identical machine, build, and process."

end Loam.Tests.CorrectionFrontierBenchmark

def main : IO Unit :=
  Loam.Tests.CorrectionFrontierBenchmark.runAll
