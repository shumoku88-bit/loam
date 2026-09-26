import Loam.Observations.Observation334

namespace Loam.Tests.ActualRoutingFixedTimeBenchmark

open Loam.Core

set_option autoImplicit false

private def locus (i : Nat) : LocusId := ⟨s!"l-{i}"⟩
private def purposeA : PurposeId := ⟨"a"⟩
private def purposeB : PurposeId := ⟨"b"⟩

private def mkEntry (subjects i : Nat) : RoutingEntry LocusId Nat :=
  {
    subject := locus (i % subjects)
    effectiveOn := i / subjects
    purpose :=
      if i % 3 == 0 then some purposeA
      else if i % 3 == 1 then none
      else some purposeB
  }

private def buildHistory
    (subjects entries : Nat) : Option (RoutingHistory LocusId Nat) :=
  RoutingHistory.ofEntries? <|
    (List.range entries).map (mkEntry subjects)

@[noinline] private def directStatuses
    (history : RoutingHistory LocusId Nat)
    (subjects observedAt : Nat) : List RoutingStatus :=
  (List.range subjects).map fun i =>
    history.statusAt (locus i) observedAt

@[noinline] private def imageStatuses
    (history : RoutingHistory LocusId Nat)
    (subjects observedAt : Nat) : List RoutingStatus :=
  let index := Loam.Observation334.buildLatestIndex history observedAt
  (List.range subjects).map fun i =>
    Loam.Observation334.statusFromIndex index (locus i)

@[noinline] private def statusDigest (statuses : List RoutingStatus) : Nat :=
  statuses.foldl
    (fun total status =>
      total +
        match status with
        | .managed purpose => purpose.token.length + 11
        | .unmanaged => 17
        | .unrouted => 23)
    0

private def timeUsForced
    (action : Unit → List RoutingStatus) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let digest := statusDigest result
  if digest == 99999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, digest)

private def timeMedianUs
    (iterations : Nat)
    (action : Unit → List RoutingStatus) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut digest : Nat := 0
  for _ in List.range iterations do
    let (us, current) ← timeUsForced action
    times := us :: times
    digest := current
  let sorted := times.toArray.qsort (· < ·)
  pure (sorted[sorted.size / 2]!, digest)

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator > 0 then
    let hundredths := numerator * 100 / denominator
    s!"{hundredths / 100}.{(hundredths % 100) / 10}{hundredths % 10}x"
  else
    "∞"

def runShape (subjects entries : Nat) : IO Unit := do
  if subjects == 0 then
    throw <| IO.userError "subject count must be positive"
  let some history := buildHistory subjects entries
    | throw <| IO.userError s!"could not admit fixture {subjects}/{entries}"
  let observedAt := entries / subjects + 1

  let direct := directStatuses history subjects observedAt
  let indexed := imageStatuses history subjects observedAt
  unless direct == indexed do
    throw <| IO.userError s!"semantic status mismatch at {subjects}/{entries}"

  let reps := 31
  let (directUs, directDigest) ←
    timeMedianUs reps fun _ => directStatuses history subjects observedAt
  let (imageUs, imageDigest) ←
    timeMedianUs reps fun _ => imageStatuses history subjects observedAt

  unless directDigest == imageDigest do
    throw <| IO.userError s!"timed digest mismatch at {subjects}/{entries}"

  IO.println
    s!"{subjects} | {entries} | {directUs} µs | {imageUs} µs | {fmtRatio directUs imageUs}"

end Loam.Tests.ActualRoutingFixedTimeBenchmark

def main (args : List String) : IO UInt32 := do
  let (subjectToken, entryToken) ←
    match args with
    | [subjects, entries] => pure (subjects, entries)
    | _ => throw <| IO.userError "usage: benchmark <subjects> <entries>"
  let some subjects := String.toNat? subjectToken
    | throw <| IO.userError s!"invalid subject count: {subjectToken}"
  let some entries := String.toNat? entryToken
    | throw <| IO.userError s!"invalid entry count: {entryToken}"
  Loam.Tests.ActualRoutingFixedTimeBenchmark.runShape subjects entries
  return 0
