import Loam.CycleSpendingPaceReview

open Loam.Core

namespace Loam.Tests.DailyPaceHistoryBenchmark

set_option autoImplicit false

private def yen : MeasureId := ⟨"jpy"⟩
private def wallet : LocusId := ⟨"wallet"⟩
private def expense : LocusId := ⟨"expense"⟩
private def selection : List EffectCoordinate := [⟨wallet, yen⟩]

private def pointDate? (offset : Nat) : Option String :=
  Loam.ActualDate.shiftDays? "2026-01-01" (Int.ofNat offset)

private def mkEvent? (i : Nat) : Option Event :=
  Event.ofEffects? ⟨s!"pace-{i}"⟩
    [ Effect.ofQuantity ⟨s!"pace-{i}-wallet"⟩ wallet yen (Quantity.ofQuanta 1)
    , Effect.ofQuantity ⟨s!"pace-{i}-expense"⟩ expense yen (Quantity.ofQuanta (-1))
    ]

private def mkRecord? (horizon i : Nat) : Option Loam.ActualReview.Record := do
  let event ← mkEvent? i
  let date ← pointDate? (i % horizon)
  pure {
    event := event
    date := some date
    description := ""
    replacement := none
  }

private def buildRecords? (n horizon : Nat) : Option (List Loam.ActualReview.Record) :=
  (List.range n).mapM (mkRecord? horizon)

private def pointDates? (days : Nat) : Option (List String) :=
  (List.range days).mapM pointDate?

private def selectedEventQuanta
    (coordinates : List EffectCoordinate)
    (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate ∈ coordinates then total + effect.quantity.quanta else total)
    0

private def referenceValidate
    (coordinates : List EffectCoordinate) :
    List Loam.ActualReview.Record → Except String Unit
  | [] => .ok ()
  | record :: rest =>
      if !record.isCurrent then
        referenceValidate coordinates rest
      else
        let quantity := selectedEventQuanta coordinates record.event
        if quantity = 0 then
          referenceValidate coordinates rest
        else
          match record.date with
          | none =>
              .error
                ("loam: Daily Pace history unavailable: current selected Actual " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if Loam.ActualDate.validIsoDate date then
                referenceValidate coordinates rest
              else
                .error
                  ("loam: Daily Pace history unavailable: current selected Actual " ++
                    record.event.id.token ++ " has an invalid occurrence date")

private def referenceEligiblePoolAtEndOfDay
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (date : String) : Int :=
  records.foldl
    (fun total record =>
      if !record.isCurrent then total
      else
        match record.date with
        | some validOn =>
            if decide (validOn ≤ date) then
              total + selectedEventQuanta coordinates record.event
            else
              total
        | none => total)
    0

private def referenceSeries?
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (dates : List String) : Except String (List Int) := do
  referenceValidate coordinates records
  return dates.map (referenceEligiblePoolAtEndOfDay coordinates records)

private def addContribution
    (validOn : String)
    (quantity : Int) :
    List String → List Int → List Int
  | date :: laterDates, total :: laterTotals =>
      let next := if decide (validOn ≤ date) then total + quantity else total
      next :: addContribution validOn quantity laterDates laterTotals
  | _, totals => totals

private def fusedSeries?
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (dates : List String) : Except String (List Int) :=
  records.foldlM
    (fun totals record => do
      if !record.isCurrent then
        return totals
      let quantity := selectedEventQuanta coordinates record.event
      if quantity = 0 then
        return totals
      let some validOn := record.date
        | throw
            ("loam: Daily Pace history unavailable: current selected Actual " ++
              record.event.id.token ++ " has no occurrence date")
      if !Loam.ActualDate.validIsoDate validOn then
        throw
          ("loam: Daily Pace history unavailable: current selected Actual " ++
            record.event.id.token ++ " has an invalid occurrence date")
      return addContribution validOn quantity dates totals)
    (List.replicate dates.length 0)

private def sameSeriesResult
    (left right : Except String (List Int)) : Bool :=
  match left, right with
  | .ok leftValues, .ok rightValues => leftValues == rightValues
  | .error leftMessage, .error rightMessage => leftMessage == rightMessage
  | _, _ => false

@[noinline] private def forceSeries : Except String (List Int) → Nat
  | .error message => message.length
  | .ok values =>
      values.length + (values.foldl (fun total value => total + value) 0).natAbs

private def timeUsForced
    (action : Unit → Except String (List Int)) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let forced := forceSeries result
  if forced == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, forced)

private def timeMedianUs
    (iterations : Nat)
    (action : Unit → Except String (List Int)) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut forced : Nat := 0
  for _ in List.range iterations do
    let (us, value) ← timeUsForced action
    times := us :: times
    forced := value
  let sorted := times.toArray.qsort (· < ·)
  pure (sorted[sorted.size / 2]!, forced)

private def fmtUs (us : Nat) : String :=
  if us >= 1000000 then s!"{us / 1000000}.{(us % 1000000) / 100000} s"
  else if us >= 1000 then s!"{us / 1000}.{(us % 1000) / 100} ms"
  else s!"{us} µs"

private def fmtRatio (numerator denominator : Nat) : String :=
  if denominator = 0 then "∞"
  else
    let hundredths := numerator * 100 / denominator
    s!"{hundredths / 100}.{hundredths % 100}x"

def runAll : IO Unit := do
  let recordSizes := [1000, 5000, 10000]
  let daySizes := [7, 30, 90]
  let reps := 3

  IO.println "=== Daily Pace Actual history: repeated scans vs fused finite-vector fold ==="
  IO.println "days | records | reference | fused | speedup"

  for days in daySizes do
    let dates ←
      match pointDates? days with
      | some dates => pure dates
      | none => throw <| IO.userError s!"could not build {days}-day date fixture"

    for n in recordSizes do
      let records ←
        match buildRecords? n days with
        | some records => pure records
        | none => throw <| IO.userError s!"could not build {n}-record fixture"

      let expected := referenceSeries? selection records dates
      let actual := fusedSeries? selection records dates
      unless sameSeriesResult expected actual do
        throw <| IO.userError s!"semantic mismatch: days={days}, records={n}"

      let (referenceUs, forcedRef) ←
        timeMedianUs reps fun _ => referenceSeries? selection records dates
      let (fusedUs, forcedFused) ←
        timeMedianUs reps fun _ => fusedSeries? selection records dates

      unless forcedRef == forcedFused do
        throw <| IO.userError s!"forced mismatch: days={days}, records={n}"

      IO.println s!"{days} | {n} | {fmtUs referenceUs} | {fmtUs fusedUs} | {fmtRatio referenceUs fusedUs}"

  IO.println "Daily Pace Actual history benchmark complete."

end Loam.Tests.DailyPaceHistoryBenchmark

def main : IO Unit :=
  Loam.Tests.DailyPaceHistoryBenchmark.runAll
