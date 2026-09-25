import Loam.StockFlowReview

namespace Loam.Observation323

open Loam.Core

set_option autoImplicit false

/-!
# Observation 323 — Stock-Flow fail-closed scan fusion

Observation 322 proved that the three numeric Stock-Flow passes can be fused
into one product accumulator after validation.

This observation adds the sequencing question:

> Can validation and numeric accumulation share one left-to-right traversal
> while preserving the exact first refusal witness and successful numeric result?

The reference below deliberately mirrors the current Stock-Flow validation
rules and then runs a separate numeric fold. The candidate fused scan interleaves
those two operations.

This remains research-only. Production StockFlowReview is unchanged.
-/

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

private structure Scan where
  startBoundary : Int
  endBoundary : Int
  positiveWindow : Int
  negativeWindow : Int
deriving Repr, DecidableEq

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

/--
The exact per-record refusal used by the research reference.

This mirrors the current StockFlowReview validation contract:

- superseded records are inert;
- zero selected quantity does not require a date;
- nonzero selected quantity requires a date;
- the date must be a real ISO calendar date;
- the error names the offending Event.
-/
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

/-- Two-pass reference validation, intentionally left-to-right. -/
private def validate :
    List EffectCoordinate →
    List Loam.ActualReview.Record →
    Except String Unit
  | _, [] => .ok ()
  | coordinates, record :: rest =>
      match recordError? coordinates record with
      | some message => .error message
      | none => validate coordinates rest

/--
Research reference corresponding to:

    validate all records
    then
    run the numeric scan

The numeric scan here is already the Observation 322 product accumulator.
-/
private def twoPass
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (initial : Scan) : Except String Scan :=
  match validate coordinates records with
  | .error message => .error message
  | .ok () =>
      .ok <| records.foldl
        (numericStep coordinates start endExclusive)
        initial

/--
Candidate complete one-pass scan.

The accumulator may be updated for earlier valid records, but if a later record
fails the returned observation is only that first error, exactly as in the
two-pass reference.
-/
private def fused
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
          fused coordinates start endExclusive rest
            (numericStep coordinates start endExclusive state record)

/--
The complete fail-closed fused traversal is exactly the two-pass reference for
arbitrary coordinates, records, window strings, and initial scan state.

Because the error text is part of the Except value, this equality includes:

- whether the computation succeeds or fails;
- which first record causes failure;
- missing-date versus invalid-date wording;
- the offending EventId embedded in the message;
- the complete successful numeric Scan.
-/
theorem fused_eq_twoPass
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (initial : Scan) :
    fused coordinates start endExclusive records initial =
      twoPass coordinates records start endExclusive initial := by
  induction records generalizing initial with
  | nil =>
      rfl
  | cons record rest ih =>
      unfold fused twoPass validate
      cases hError : recordError? coordinates record with
      | some message =>
          simp [hError]
      | none =>
          simp only [hError]
          change
            fused coordinates start endExclusive rest
                (numericStep coordinates start endExclusive initial record) =
              match validate coordinates rest with
              | .error message => .error message
              | .ok () =>
                  .ok <|
                    rest.foldl
                      (numericStep coordinates start endExclusive)
                      (numericStep coordinates start endExclusive initial record)
          exact ih (numericStep coordinates start endExclusive initial record)

/-! ## Finite pressure against the actual public project boundary -/

private def jpy : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩
private def bankJpy : EffectCoordinate := ⟨bank, jpy⟩

private def effect (key : String) (q : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ bank jpy (Quantity.ofQuanta q)

private def event (id : String) (q : Int) : Event :=
  {
    id := ⟨id⟩
    effects := [effect (id ++ "-effect") q]
    keyNodup := retainedEffectKeys_singleton_nodup (effect (id ++ "-effect") q)
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

private def zeroScan : Scan :=
  {
    startBoundary := 0
    endBoundary := 0
    positiveWindow := 0
    negativeWindow := 0
  }

private def balances : Loam.BalanceReview.Snapshot :=
  {
    rows :=
      [{
        coordinate := bankJpy
        quantity := Quantity.ofQuanta 13
      }]
  }

private def missingMessage (id : String) : String :=
  "loam: stock-flow unavailable: current selected Event " ++
    id ++ " has no occurrence date"

private def invalidMessage (id : String) : String :=
  "loam: stock-flow unavailable: current selected Event " ++
    id ++ " has an invalid occurrence date"

theorem first_missing_failure_is_preserved :
    let records :=
      [ record "missing-first" 5 none
      , record "invalid-later" 7 (some "2026-02-30")
      ]
    fused [bankJpy] "2026-09-01" "2026-10-01" records zeroScan =
      .error (missingMessage "missing-first") ∧
    Loam.StockFlowReview.project balances records "2026-09-01" "2026-10-01" =
      .error (missingMessage "missing-first") := by
  native_decide

theorem first_invalid_failure_is_preserved :
    let records :=
      [ record "invalid-first" 5 (some "2026-02-30")
      , record "missing-later" 7 none
      ]
    fused [bankJpy] "2026-09-01" "2026-10-01" records zeroScan =
      .error (invalidMessage "invalid-first") ∧
    Loam.StockFlowReview.project balances records "2026-09-01" "2026-10-01" =
      .error (invalidMessage "invalid-first") := by
  native_decide

/--
A current zero-selected-quantity record is permitted to remain undated. The
later dated +5 record is the only numeric contribution.
-/
theorem zero_selected_quantity_does_not_require_date :
    let records :=
      [ record "zero-undated" 0 none
      , record "dated-five" 5 (some "2026-09-10")
      ]
    fused [bankJpy] "2026-09-01" "2026-10-01" records zeroScan =
      .ok {
        startBoundary := 0
        endBoundary := 5
        positiveWindow := 5
        negativeWindow := 0
      } := by
  native_decide

/--
A superseded nonzero undated record is inert for both refusal and quantity.
-/
theorem superseded_undated_record_is_inert :
    let records :=
      [ record "superseded-undated" 999 none false
      , record "dated-three" 3 (some "2026-09-10")
      ]
    fused [bankJpy] "2026-09-01" "2026-10-01" records zeroScan =
      .ok {
        startBoundary := 0
        endBoundary := 3
        positiveWindow := 3
        negativeWindow := 0
      } := by
  native_decide

/-!
## Finding

The fail-closed sequencing itself can be fused.

For the research reference, one left-to-right traversal preserves the complete
Except observation, including exact first-failure text, while accumulating the
same numeric product summary.

Finite witnesses against the actual public StockFlowReview.project boundary also
confirm current first-failure wording/order for missing and invalid dates.

This does not yet prove a general equality between this research fused function
and the public production project, because the production helper functions are
private and the public project also owns endpoint validation, current-balance
projection, and the final parity gate.

It does establish the difficult local result:

    selected-record validation
        +
    Stock-Flow numeric accumulation

share one sequential fail-closed scan semantics.

No production change is authorized.
-/

end Loam.Observation323
