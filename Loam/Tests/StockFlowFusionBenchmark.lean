import Loam.StockFlowReview
import Loam.Observations.Observation332

namespace Loam.Tests.StockFlowFusionBenchmark

open Loam.Core

set_option autoImplicit false

private structure Scan where
  startBoundary : Int
  endBoundary : Int
  positiveWindow : Int
  negativeWindow : Int

private def zeroScan : Scan :=
  { startBoundary := 0, endBoundary := 0, positiveWindow := 0, negativeWindow := 0 }

private def startDate := "2026-09-01"
private def endDate := "2026-10-01"
private def jpy : MeasureId := ⟨"jpy"⟩

private def selectedCoordinate (i : Nat) : EffectCoordinate :=
  ⟨⟨s!"selected-{i}"⟩, jpy⟩

private def noiseCoordinate (i : Nat) : EffectCoordinate :=
  ⟨⟨s!"noise-{i % 17}"⟩, jpy⟩

private def selectedCoordinates (count : Nat) : List EffectCoordinate :=
  (List.range count).map selectedCoordinate

private def balances (count : Nat) : Loam.BalanceReview.Snapshot :=
  {
    rows := (selectedCoordinates count).map fun coordinate =>
      { coordinate := coordinate, quantity := Quantity.ofQuanta 0 }
  }

private def eventFor (coordinateCount i : Nat) : Event :=
  let selected := selectedCoordinate (i % coordinateCount)
  let q : Int := if i % 2 = 0 then 3 else -2
  let effect :=
    Effect.ofAnonymousQuantity selected.locus selected.measure (Quantity.ofQuanta q)
  {
    id := ⟨s!"stock-bench-{coordinateCount}-{i}"⟩
    effects := [effect]
    keyNodup := retainedEffectKeys_singleton_nodup effect
  }

private def dateFor (i : Nat) : String :=
  match i % 3 with
  | 0 => "2026-08-15"
  | 1 => "2026-09-15"
  | _ => "2026-10-15"

private def recordFor (coordinateCount i : Nat) : Loam.ActualReview.Record :=
  {
    event := eventFor coordinateCount i
    date := some (dateFor i)
    description := ""
    replacement := none
  }

private def records (coordinateCount count : Nat) : List Loam.ActualReview.Record :=
  (List.range count).map (recordFor coordinateCount)

private def currentTrackedQuanta (balances : Loam.BalanceReview.Snapshot) : Int :=
  balances.rows.foldl (fun total row => total + row.quantity.quanta) 0

private def numericFromQuantity
    (state : Scan) (date : String) (quantity : Int) : Scan :=
  let nextStart :=
    if decide (date < startDate) then state.startBoundary + quantity
    else state.startBoundary
  let nextEnd :=
    if decide (date < endDate) then state.endBoundary + quantity
    else state.endBoundary
  let changes :=
    if decide (startDate ≤ date ∧ date < endDate) then
      if quantity > 0 then
        (state.positiveWindow + quantity, state.negativeWindow)
      else if quantity < 0 then
        (state.positiveWindow, state.negativeWindow + quantity)
      else
        (state.positiveWindow, state.negativeWindow)
    else
      (state.positiveWindow, state.negativeWindow)
  {
    startBoundary := nextStart
    endBoundary := nextEnd
    positiveWindow := changes.1
    negativeWindow := changes.2
  }

private def scanList
    (coordinates : List EffectCoordinate) :
    List Loam.ActualReview.Record → Scan → Except String Scan
  | [], state => .ok state
  | record :: rest, state =>
      if !record.isCurrent then
        scanList coordinates rest state
      else
        let quantity :=
          Loam.Observation332.trackedQuantaList coordinates record.event
        if quantity = 0 then
          scanList coordinates rest state
        else
          match record.date with
          | none =>
              .error
                ("loam: stock-flow unavailable: current selected Event " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if Loam.ActualDate.validIsoDate date then
                scanList coordinates rest (numericFromQuantity state date quantity)
              else
                .error
                  ("loam: stock-flow unavailable: current selected Event " ++
                    record.event.id.token ++ " has an invalid occurrence date")

private def scanSet
    (support : Loam.Observation332.SupportIndex) :
    List Loam.ActualReview.Record → Scan → Except String Scan
  | [], state => .ok state
  | record :: rest, state =>
      if !record.isCurrent then
        scanSet support rest state
      else
        let quantity :=
          Loam.Observation332.trackedQuantaSupport support record.event
        if quantity = 0 then
          scanSet support rest state
        else
          match record.date with
          | none =>
              .error
                ("loam: stock-flow unavailable: current selected Event " ++
                  record.event.id.token ++ " has no occurrence date")
          | some date =>
              if Loam.ActualDate.validIsoDate date then
                scanSet support rest (numericFromQuantity state date quantity)
              else
                .error
                  ("loam: stock-flow unavailable: current selected Event " ++
                    record.event.id.token ++ " has an invalid occurrence date")

private def finish
    (balances : Loam.BalanceReview.Snapshot)
    (result : Except String Scan) :
    Except String Loam.StockFlowReview.Snapshot :=
  match result with
  | .error message => .error message
  | .ok state =>
      let net := state.positiveWindow + state.negativeWindow
      if state.startBoundary + net != state.endBoundary then
        .error "loam: stock-flow internal parity failure"
      else
        .ok {
          start := startDate
          endExclusive := endDate
          reconstructedStart := Quantity.ofQuanta state.startBoundary
          increasesAcrossEvents := Quantity.ofQuanta state.positiveWindow
          decreasesAcrossEvents := Quantity.ofQuanta state.negativeWindow
          currentTracked := Quantity.ofQuanta (currentTrackedQuanta balances)
        }

@[noinline] private def baseline
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record) :
    Except String Loam.StockFlowReview.Snapshot :=
  Loam.StockFlowReview.project balances records startDate endDate

@[noinline] private def fusedList
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record) :
    Except String Loam.StockFlowReview.Snapshot :=
  let coordinates := balances.rows.map fun row => row.coordinate
  finish balances (scanList coordinates records zeroScan)

@[noinline] private def fusedSet
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record) :
    Except String Loam.StockFlowReview.Snapshot :=
  let coordinates := balances.rows.map fun row => row.coordinate
  let support := Loam.Observation332.buildSupport coordinates
  finish balances (scanSet support records zeroScan)

private abbrev Result := Except String Loam.StockFlowReview.Snapshot

private def sameResult (left right : Result) : Bool :=
  match left, right with
  | .error leftMessage, .error rightMessage => leftMessage == rightMessage
  | .ok leftSnapshot, .ok rightSnapshot => decide (leftSnapshot = rightSnapshot)
  | _, _ => false

@[noinline] private def forceResult (result : Result) : Nat × Int :=
  match result with
  | .error message => (message.length, 0)
  | .ok snapshot =>
      ( snapshot.start.length + snapshot.endExclusive.length
      , snapshot.reconstructedStart.quanta +
          snapshot.increasesAcrossEvents.quanta +
          snapshot.decreasesAcrossEvents.quanta +
          snapshot.currentTracked.quanta )

@[noinline] private def timeOne
    (action : Unit → Result) : IO (Nat × Result × (Nat × Int)) := do
  let t0 ← IO.monoNanosNow
  let result := action ()
  let forced := forceResult result
  if forced.1 == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, result, forced)

private def median (samples : List Nat) : Nat :=
  let sorted := samples.toArray.qsort (· < ·)
  sorted[sorted.size / 2]!

private structure Timed where
  baselineUs : Nat
  listUs : Nat
  setUs : Nat
  baselineResult : Result
  listResult : Result
  setResult : Result

private def pairedMedian
    (iterations : Nat)
    (baselineAction listAction setAction : Unit → Result) : IO Timed := do
  let mut baseTimes : List Nat := []
  let mut listTimes : List Nat := []
  let mut setTimes : List Nat := []
  let mut baseResult : Result := .error "unset"
  let mut listResult : Result := .error "unset"
  let mut setResult : Result := .error "unset"

  for i in List.range iterations do
    match i % 3 with
    | 0 =>
        let (a, ar, _) ← timeOne baselineAction
        let (b, br, _) ← timeOne listAction
        let (c, cr, _) ← timeOne setAction
        baseTimes := a :: baseTimes
        listTimes := b :: listTimes
        setTimes := c :: setTimes
        baseResult := ar
        listResult := br
        setResult := cr
    | 1 =>
        let (b, br, _) ← timeOne listAction
        let (c, cr, _) ← timeOne setAction
        let (a, ar, _) ← timeOne baselineAction
        baseTimes := a :: baseTimes
        listTimes := b :: listTimes
        setTimes := c :: setTimes
        baseResult := ar
        listResult := br
        setResult := cr
    | _ =>
        let (c, cr, _) ← timeOne setAction
        let (a, ar, _) ← timeOne baselineAction
        let (b, br, _) ← timeOne listAction
        baseTimes := a :: baseTimes
        listTimes := b :: listTimes
        setTimes := c :: setTimes
        baseResult := ar
        listResult := br
        setResult := cr

  pure {
    baselineUs := median baseTimes
    listUs := median listTimes
    setUs := median setTimes
    baselineResult := baseResult
    listResult := listResult
    setResult := setResult
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
  else "∞"

private def runCase (coordinateCount eventCount : Nat) : IO Unit := do
  let bs := balances coordinateCount
  let rs := records coordinateCount eventCount
  let timed ← pairedMedian 3
    (fun _ => baseline bs rs)
    (fun _ => fusedList bs rs)
    (fun _ => fusedSet bs rs)

  unless sameResult timed.baselineResult timed.listResult do
    throw <| IO.userError
      s!"fused-list semantic mismatch coordinates={coordinateCount} events={eventCount}"
  unless sameResult timed.baselineResult timed.setResult do
    throw <| IO.userError
      s!"fused-set semantic mismatch coordinates={coordinateCount} events={eventCount}"

  IO.println
    s!"{coordinateCount}\t{eventCount}\t{fmtUs timed.baselineUs}\t{fmtUs timed.listUs}\t{fmtUs timed.setUs}\t{fmtRatio timed.baselineUs timed.listUs}\t{fmtRatio timed.baselineUs timed.setUs}\t{fmtRatio timed.listUs timed.setUs}"

def runAll : IO Unit := do
  IO.println "=== Stock-Flow fusion paired benchmark ==="
  IO.println "one selected Effect/Event; coordinate rotates through the selected universe"
  IO.println "all timed results retained; exact result equality checked after timing"
  IO.println ""
  IO.println "coords\tevents\tproduction\tfused-list\tfused-set\tprod/list\tprod/set\tlist/set"

  for coordinateCount in [4, 16, 64, 256] do
    for eventCount in [2000, 10000] do
      runCase coordinateCount eventCount

  IO.println ""
  IO.println "Stock-Flow fusion paired benchmark complete."

end Loam.Tests.StockFlowFusionBenchmark

def main : IO Unit :=
  Loam.Tests.StockFlowFusionBenchmark.runAll
