import Loam.Core.HistoricalRouting
import Loam.Core.Effect
import Std.Data.HashMap

namespace Loam.Tests.RoutingStatusImageBenchmark

open Loam.Core

set_option autoImplicit false

private abbrev Entry := RoutingEntry LocusId Nat
private abbrev History := RoutingHistory LocusId Nat
private abbrev StatusImage := Std.HashMap String Entry

private def subject (i : Nat) : LocusId := ⟨s!"locus-{i}"⟩

private def purpose (i j : Nat) : Option PurposeId :=
  match j % 3 with
  | 0 => some ⟨s!"purpose-{i % 7}"⟩
  | 1 => none
  | _ => some ⟨s!"purpose-{(i + j) % 11}"⟩

private def entry (i j : Nat) : Entry :=
  {
    subject := subject i
    effectiveOn := j * 10
    purpose := purpose i j
  }

private def entries (subjectCount changesPerSubject : Nat) : List Entry :=
  ((List.range subjectCount).flatMap fun i =>
      (List.range changesPerSubject).map fun j => entry i j)
    |>.reverse

private def history? (subjectCount changesPerSubject : Nat) : Option History :=
  RoutingHistory.ofEntries? (entries subjectCount changesPerSubject)

private def latestStep
    (validOn : Nat)
    (image : StatusImage)
    (e : Entry) : StatusImage :=
  if e.effectiveOn ≤ validOn then
    match image.get? e.subject.token with
    | none => image.insert e.subject.token e
    | some current =>
        if current.effectiveOn ≤ e.effectiveOn then
          image.insert e.subject.token e
        else
          image
  else
    image

@[noinline] private def buildImage
    (history : History)
    (validOn : Nat) : StatusImage :=
  history.entries.foldl (latestStep validOn) {}

private def statusOfEntry? : Option Entry → RoutingStatus
  | none => .unrouted
  | some e =>
      match e.purpose with
      | some p => .managed p
      | none => .unmanaged

@[noinline] private def statusFromImage
    (image : StatusImage)
    (s : LocusId) : RoutingStatus :=
  statusOfEntry? (image.get? s.token)

@[noinline] private def baselineAll
    (history : History)
    (subjects : List LocusId)
    (validOn : Nat) : List RoutingStatus :=
  subjects.map fun s => history.statusAt s validOn

@[noinline] private def imageAll
    (history : History)
    (subjects : List LocusId)
    (validOn : Nat) : List RoutingStatus :=
  let image := buildImage history validOn
  subjects.map fun s => statusFromImage image s

@[noinline] private def forceStatuses (statuses : List RoutingStatus) : Nat :=
  statuses.foldl
    (fun total status =>
      total +
        match status with
        | .unrouted => 1
        | .unmanaged => 2
        | .managed p => 3 + p.token.length)
    0

@[noinline] private def timeOne
    (action : Unit → List RoutingStatus) :
    IO (Nat × List RoutingStatus × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let digest := forceStatuses result
  if digest == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, result, digest)

private def median (samples : List Nat) : Nat :=
  let sorted := samples.toArray.qsort (· < ·)
  sorted[sorted.size / 2]!

private structure Timed where
  baselineUs : Nat
  imageUs : Nat
  baselineResult : List RoutingStatus
  imageResult : List RoutingStatus

private def pairedMedian
    (iterations : Nat)
    (baselineAction imageAction : Unit → List RoutingStatus) : IO Timed := do
  let mut baselineTimes : List Nat := []
  let mut imageTimes : List Nat := []
  let mut baselineResult : List RoutingStatus := []
  let mut imageResult : List RoutingStatus := []

  for i in List.range iterations do
    if i % 2 = 0 then
      let (a, ar, _) ← timeOne baselineAction
      let (b, br, _) ← timeOne imageAction
      baselineTimes := a :: baselineTimes
      imageTimes := b :: imageTimes
      baselineResult := ar
      imageResult := br
    else
      let (b, br, _) ← timeOne imageAction
      let (a, ar, _) ← timeOne baselineAction
      baselineTimes := a :: baselineTimes
      imageTimes := b :: imageTimes
      baselineResult := ar
      imageResult := br

  pure {
    baselineUs := median baselineTimes
    imageUs := median imageTimes
    baselineResult := baselineResult
    imageResult := imageResult
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

private def runCase (subjectCount changesPerSubject : Nat) : IO Unit := do
  let some history := history? subjectCount changesPerSubject
    | throw <| IO.userError
        s!"routing fixture rejected subjects={subjectCount} changes={changesPerSubject}"
  let subjects := (List.range subjectCount).map subject
  let validOn := changesPerSubject * 10 + 1

  let timed ← pairedMedian 5
    (fun _ => baselineAll history subjects validOn)
    (fun _ => imageAll history subjects validOn)

  unless timed.baselineResult == timed.imageResult do
    throw <| IO.userError
      s!"status image mismatch subjects={subjectCount} changes={changesPerSubject}"

  IO.println
    s!"{subjectCount}\t{changesPerSubject}\t{history.entries.length}\t{fmtUs timed.baselineUs}\t{fmtUs timed.imageUs}\t{fmtRatio timed.baselineUs timed.imageUs}"

def runAll : IO Unit := do
  IO.println "=== Routing fixed-time status image paired benchmark ==="
  IO.println "baseline: statusAt for every subject; candidate: one history scan + HashMap lookups"
  IO.println "timed result lists retained; exact equality checked after timing"
  IO.println ""
  IO.println "subjects\tchanges/subject\thistory entries\tbaseline\tstatus-image\tspeedup"

  for case in [(1, 64), (4, 16), (16, 16), (64, 16), (64, 64), (256, 16), (256, 64)] do
    runCase case.1 case.2

  IO.println ""
  IO.println "Routing fixed-time status image paired benchmark complete."

end Loam.Tests.RoutingStatusImageBenchmark

def main : IO Unit :=
  Loam.Tests.RoutingStatusImageBenchmark.runAll
