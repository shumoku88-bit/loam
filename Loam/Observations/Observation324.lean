import Loam.StockFlowReview

namespace Loam.Observation324

open Loam.Core

set_option autoImplicit false

/-!
# Observation 324 — Stock-Flow public-shell factorization boundary

Observations 322–323 established that the selected-record core can be expressed
as one sequential fail-closed scan.

This observation asks what the *rest* of Stock-Flow needs.

Because StockFlowReview's construction helpers are file-private, this module
does not pretend to prove a general implementation theorem against those hidden
definitions. Instead it does two things:

1. proves the outer project shell factors through a deliberately small research
   image;
2. applies finite executable pressure against the public
   StockFlowReview.project entrance across success and refusal classes.

The result identifies the exact remaining bridge a production proof would need.
No production code is changed.
-/

private structure BalanceImage where
  coordinates : List EffectCoordinate
  currentTracked : Int
deriving Repr, DecidableEq

private def balanceImage
    (balances : Loam.BalanceReview.Snapshot) : BalanceImage :=
  {
    coordinates := balances.rows.map (fun row => row.coordinate)
    currentTracked :=
      balances.rows.foldl
        (fun total row => total + row.quantity.quanta)
        0
  }

private structure Scan where
  startBoundary : Int
  endBoundary : Int
  positiveWindow : Int
  negativeWindow : Int
deriving Repr, DecidableEq

private def zeroScan : Scan :=
  {
    startBoundary := 0
    endBoundary := 0
    positiveWindow := 0
    negativeWindow := 0
  }

private def trackedQuanta
    (coordinates : List EffectCoordinate)
    (event : Event) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate ∈ coordinates then
        total + effect.quantity.quanta
      else
        total)
    0

private def recordError?
    (coordinates : List EffectCoordinate)
    (record : Loam.ActualReview.Record) : Option String :=
  if !record.isCurrent then
    none
  else
    let quantity := trackedQuanta coordinates record.event
    if quantity = 0 then
      none
    else
      match record.date with
      | none =>
          some
            ("loam: stock-flow unavailable: current selected Event " ++
              record.event.id.token ++ " has no occurrence date")
      | some date =>
          if Loam.ActualDate.validIsoDate date then
            none
          else
            some
              ("loam: stock-flow unavailable: current selected Event " ++
                record.event.id.token ++ " has an invalid occurrence date")

private def numericStep
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (state : Scan)
    (record : Loam.ActualReview.Record) : Scan :=
  if !record.isCurrent then
    state
  else
    match record.date with
    | none => state
    | some date =>
        let quantity := trackedQuanta coordinates record.event
        let nextStart :=
          if decide (date < start) then
            state.startBoundary + quantity
          else
            state.startBoundary
        let nextEnd :=
          if decide (date < endExclusive) then
            state.endBoundary + quantity
          else
            state.endBoundary
        let changes :=
          if decide (start ≤ date ∧ date < endExclusive) then
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

private def scan
    (coordinates : List EffectCoordinate)
    (start endExclusive : String) :
    List Loam.ActualReview.Record →
    Scan →
    Except String Scan
  | [], state => .ok state
  | record :: rest, state =>
      match recordError? coordinates record with
      | some message => .error message
      | none =>
          scan coordinates start endExclusive rest
            (numericStep coordinates start endExclusive state record)

/--
The outer project shell consumes only:

- endpoint strings;
- one BalanceImage;
- one fail-closed Scan result.

It does not need Event or Effect evidence directly after the scan boundary.
-/
private def finish
    (image : BalanceImage)
    (start endExclusive : String)
    (result : Except String Scan) :
    Except String Loam.StockFlowReview.Snapshot :=
  if !Loam.ActualDate.validIsoDate start ||
      !Loam.ActualDate.validIsoDate endExclusive then
    .error "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates"
  else if !(decide (start < endExclusive)) then
    .error "loam: stock-flow start must be earlier than end"
  else
    match result with
    | .error message => .error message
    | .ok state =>
        let net := state.positiveWindow + state.negativeWindow
        if state.startBoundary + net != state.endBoundary then
          .error "loam: stock-flow internal parity failure"
        else
          .ok {
            start := start
            endExclusive := endExclusive
            reconstructedStart := Quantity.ofQuanta state.startBoundary
            increasesAcrossEvents := Quantity.ofQuanta state.positiveWindow
            decreasesAcrossEvents := Quantity.ofQuanta state.negativeWindow
            currentTracked := Quantity.ofQuanta image.currentTracked
          }

/-- Research-only whole-project factorization candidate. -/
private def factorProject
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) :
    Except String Loam.StockFlowReview.Snapshot :=
  let image := balanceImage balances
  finish image start endExclusive
    (scan image.coordinates start endExclusive records zeroScan)

/-! ## General outer-shell laws -/

theorem factorProject_factors_through_balanceImage_and_scan
    (balances : Loam.BalanceReview.Snapshot)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String) :
    factorProject balances records start endExclusive =
      let image := balanceImage balances
      finish image start endExclusive
        (scan image.coordinates start endExclusive records zeroScan) := by
  rfl

theorem invalid_endpoint_dominates
    (image : BalanceImage)
    (start endExclusive : String)
    (result : Except String Scan)
    (hInvalid :
      (!Loam.ActualDate.validIsoDate start ||
        !Loam.ActualDate.validIsoDate endExclusive) = true) :
    finish image start endExclusive result =
      .error "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates" := by
  simp [finish, hInvalid]

theorem reversed_window_dominates
    (image : BalanceImage)
    (start endExclusive : String)
    (result : Except String Scan)
    (hStart : Loam.ActualDate.validIsoDate start = true)
    (hEnd : Loam.ActualDate.validIsoDate endExclusive = true)
    (hOrder : decide (start < endExclusive) = false) :
    finish image start endExclusive result =
      .error "loam: stock-flow start must be earlier than end" := by
  simp [finish, hStart, hEnd, hOrder]

theorem scan_error_passes_through
    (image : BalanceImage)
    (start endExclusive message : String)
    (hStart : Loam.ActualDate.validIsoDate start = true)
    (hEnd : Loam.ActualDate.validIsoDate endExclusive = true)
    (hOrder : decide (start < endExclusive) = true) :
    finish image start endExclusive (.error message) =
      .error message := by
  simp [finish, hStart, hEnd, hOrder]

theorem successful_scan_builds_exact_snapshot
    (image : BalanceImage)
    (start endExclusive : String)
    (state : Scan)
    (hStart : Loam.ActualDate.validIsoDate start = true)
    (hEnd : Loam.ActualDate.validIsoDate endExclusive = true)
    (hOrder : decide (start < endExclusive) = true)
    (hParity :
      state.startBoundary + (state.positiveWindow + state.negativeWindow) =
        state.endBoundary) :
    finish image start endExclusive (.ok state) =
      .ok {
        start := start
        endExclusive := endExclusive
        reconstructedStart := Quantity.ofQuanta state.startBoundary
        increasesAcrossEvents := Quantity.ofQuanta state.positiveWindow
        decreasesAcrossEvents := Quantity.ofQuanta state.negativeWindow
        currentTracked := Quantity.ofQuanta image.currentTracked
      } := by
  simp [finish, hStart, hEnd, hOrder, hParity]

theorem parity_failure_is_preserved
    (image : BalanceImage)
    (start endExclusive : String)
    (state : Scan)
    (hStart : Loam.ActualDate.validIsoDate start = true)
    (hEnd : Loam.ActualDate.validIsoDate endExclusive = true)
    (hOrder : decide (start < endExclusive) = true)
    (hParity :
      state.startBoundary + (state.positiveWindow + state.negativeWindow) ≠
        state.endBoundary) :
    finish image start endExclusive (.ok state) =
      .error "loam: stock-flow internal parity failure" := by
  simp [finish, hStart, hEnd, hOrder, hParity]

/-! ## Closed pressure against the public production entrance -/

private def jpy : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩
private def bankJpy : EffectCoordinate := ⟨bank, jpy⟩

private def event (id : String) (q : Int) : Event :=
  let effect :=
    Effect.ofAnonymousQuantity bank jpy (Quantity.ofQuanta q)
  {
    id := ⟨id⟩
    effects := [effect]
    keyNodup := retainedEffectKeys_singleton_nodup effect
  }

private def record
    (id : String)
    (q : Int)
    (date : Option String)
    (current : Bool := true) : Loam.ActualReview.Record :=
  {
    event := event id q
    date := date
    description := ""
    replacement := if current then none else some ⟨id ++ "-replacement"⟩
  }

private def balances : Loam.BalanceReview.Snapshot :=
  {
    rows := [{
      coordinate := bankJpy
      quantity := Quantity.ofQuanta 13
    }]
  }

private def successRecords : List Loam.ActualReview.Record :=
  [ record "opening" 10 (some "2026-08-01")
  , record "spend" (-3) (some "2026-09-10")
  , record "later" 6 (some "2026-10-02")
  ]

private def missingRecords : List Loam.ActualReview.Record :=
  [ record "missing-first" 5 none
  , record "invalid-later" 7 (some "2026-02-30")
  ]

private def invalidRecords : List Loam.ActualReview.Record :=
  [ record "invalid-first" 5 (some "2026-02-30")
  , record "missing-later" 7 none
  ]

private def zeroUndatedRecords : List Loam.ActualReview.Record :=
  [ record "zero-undated" 0 none
  , record "dated-five" 5 (some "2026-09-10")
  ]

private def supersededRecords : List Loam.ActualReview.Record :=
  [ record "superseded-undated" 999 none false
  , record "dated-three" 3 (some "2026-09-10")
  ]

example :
    factorProject balances successRecords "2026-09-01" "2026-10-01" =
      Loam.StockFlowReview.project
        balances successRecords "2026-09-01" "2026-10-01" := by
  native_decide

example :
    factorProject balances missingRecords "2026-09-01" "2026-10-01" =
      Loam.StockFlowReview.project
        balances missingRecords "2026-09-01" "2026-10-01" := by
  native_decide

example :
    factorProject balances invalidRecords "2026-09-01" "2026-10-01" =
      Loam.StockFlowReview.project
        balances invalidRecords "2026-09-01" "2026-10-01" := by
  native_decide

example :
    factorProject balances zeroUndatedRecords "2026-09-01" "2026-10-01" =
      Loam.StockFlowReview.project
        balances zeroUndatedRecords "2026-09-01" "2026-10-01" := by
  native_decide

example :
    factorProject balances supersededRecords "2026-09-01" "2026-10-01" =
      Loam.StockFlowReview.project
        balances supersededRecords "2026-09-01" "2026-10-01" := by
  native_decide

/--
Endpoint refusal has priority even when the record stream itself would fail.
-/
example :
    factorProject balances missingRecords "not-a-date" "2026-10-01" =
      Loam.StockFlowReview.project
        balances missingRecords "not-a-date" "2026-10-01" := by
  native_decide

/--
Window-order refusal has priority over record-scan refusal after both endpoint
spellings are valid.
-/
example :
    factorProject balances missingRecords "2026-10-01" "2026-09-01" =
      Loam.StockFlowReview.project
        balances missingRecords "2026-10-01" "2026-09-01" := by
  native_decide

/-!
## Finding

The research whole-project candidate has a small outer dependency:

    BalanceReview.Snapshot
        -> BalanceImage {
             coordinates
             currentTracked
           }

    records + coordinates + window
        -> Except String Scan {
             startBoundary
             endBoundary
             positiveWindow
             negativeWindow
           }

    endpoints + BalanceImage + Scan result
        -> parity gate
        -> StockFlowReview.Snapshot

The outer shell laws are general.

Closed executable pressure also agrees with the public production project for
representative success, missing-date, invalid-date, zero-undated,
superseded-undated, malformed-endpoint, and reversed-window cases.

What remains deliberately unclaimed is one general theorem equating the
research factorProject with the public production project for arbitrary inputs.

That last bridge lives across file-private production helpers. If production
optimization is ever justified, the cleanest proof location would be inside
StockFlowReview itself, where those private definitions are visible.

Until then, this observation identifies the factorization boundary without
creating a second production authority.
-/

end Loam.Observation324
