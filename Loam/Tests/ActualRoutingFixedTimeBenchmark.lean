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
    (subjects : List LocusId)
    (observedAt : Nat) : List RoutingStatus :=
  subjects.map fun subject =>
    history.statusAt subject observedAt

@[noinline] private def imageStatuses
    (history : RoutingHistory LocusId Nat)
    (subjects : List LocusId)
    (observedAt : Nat) : List RoutingStatus :=
  let index := Loam.Observation334.buildLatestIndex history observedAt
  subjects.map fun subject =>
    Loam.Observation334.statusFromIndex index subject

@[noinline] private def statusDigest (statuses : List RoutingStatus) : Nat :=
  statuses.foldl
    (fun total status =>
      total +
        match status with
        | .managed purpose => purpose.token.length + 11
        | .unmanaged => 17
        | .unrouted => 23)
    0

@[noinline] private def timeOne
    (action : Unit → List RoutingStatus) :
    IO (Nat × List RoutingStatus × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let digest := statusDigest result
  if digest == 99999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, result, digest)

private def median (samples : List Nat) : Nat :=
  let sorted := samples.toArray.qsort (· < ·)
  sorted[sorted.size / 2]!

private structure Timed where
  directUs : Nat
  imageUs : Nat
  directResult : List RoutingStatus
  imageResult : List RoutingStatus
  directDigest : Nat
  imageDigest : Nat

private def pairedMedian
    (iterations : Nat)
    (directAction imageAction : Unit → List RoutingStatus) : IO Timed := do
  let mut directTimes : List Nat := []
  let mut imageTimes : List Nat := []
  let mut directResult : List RoutingStatus := []
  let mut imageResult : List RoutingStatus := []
  let mut directDigest : Nat := 0
  let mut imageDigest : Nat := 0

  for i in List.range iterations do
    if i % 2 = 0 then
      let (a, ar, ad) ← timeOne directAction
      let (b, br, bd) ← timeOne imageAction
      directTimes := a :: directTimes
      imageTimes := b :: imageTimes
      directResult := ar
      imageResult := br
      directDigest := ad
      imageDigest := bd
    else
      let (b, br, bd) ← timeOne imageAction
      let (a, ar, ad) ← timeOne directAction
      directTimes := a :: directTimes
      imageTimes := b :: imageTimes
      directResult := ar
      imageResult := br
      directDigest := ad
      imageDigest := bd

  pure {
    directUs := median directTimes
    imageUs := median imageTimes
    directResult := directResult
    imageResult := imageResult
    directDigest := directDigest
    imageDigest := imageDigest
  }

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
  let subjectList := (List.range subjects).map locus

  let timed ← pairedMedian 7
    (fun _ => directStatuses history subjectList observedAt)
    (fun _ => imageStatuses history subjectList observedAt)

  unless timed.directResult == timed.imageResult do
    throw <| IO.userError s!"semantic status mismatch at {subjects}/{entries}"
  unless timed.directDigest == timed.imageDigest do
    throw <| IO.userError s!"timed digest mismatch at {subjects}/{entries}"

  IO.println
    s!"{subjects} | {entries} | {timed.directUs} µs | {timed.imageUs} µs | {fmtRatio timed.directUs timed.imageUs}"

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
