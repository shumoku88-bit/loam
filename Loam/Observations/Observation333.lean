import Loam.Observations.Observation332
import Loam.StockFlowReview

namespace Loam.Observation333

open Loam.Core

set_option autoImplicit false

/-!
# Observation 333 — Stock-Flow computes selected Event quantity once

Observation 323 fused validation and numeric accumulation into one left-to-right
Record traversal, but its research shape still computes tracked Event quantity
once for validation and again for numeric accumulation on a successful current
record.

This observation asks whether one exact Event-local quantity can drive both
decisions without changing the complete fail-closed result.
-/

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

private def numericFromQuantity
    (start endExclusive : String)
    (state : Scan)
    (date : String)
    (quantity : Int) : Scan :=
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
        numericFromQuantity start endExclusive state date
          (Loam.Observation332.trackedQuantaList coordinates record.event)

private def recordError?
    (coordinates : List EffectCoordinate)
    (record : Loam.ActualReview.Record) : Option String :=
  if !record.isCurrent then
    none
  else
    let quantity :=
      Loam.Observation332.trackedQuantaList coordinates record.event
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

private def validate :
    List EffectCoordinate →
    List Loam.ActualReview.Record →
    Except String Unit
  | _, [] => .ok ()
  | coordinates, record :: rest =>
      match recordError? coordinates record with
      | some message => .error message
      | none => validate coordinates rest

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
One-record candidate. The selected quantity let-binding is the only call to
trackedQuantaList on the current record.
-/
private def singleRecord
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (state : Scan)
    (record : Loam.ActualReview.Record) : Except String Scan :=
  if !record.isCurrent then
    .ok state
  else
    let quantity :=
      Loam.Observation332.trackedQuantaList coordinates record.event
    if quantity = 0 then
      .ok state
    else
      match record.date with
      | none =>
          .error
            ("loam: stock-flow unavailable: current selected Event " ++
              record.event.id.token ++ " has no occurrence date")
      | some date =>
          if Loam.ActualDate.validIsoDate date then
            .ok (numericFromQuantity start endExclusive state date quantity)
          else
            .error
              ("loam: stock-flow unavailable: current selected Event " ++
                record.event.id.token ++ " has an invalid occurrence date")

/--
Computing selected Event quantity once is extensionally equal to the
validation-then-numeric one-record composition.
-/
private theorem singleRecord_eq_reference
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (state : Scan)
    (record : Loam.ActualReview.Record) :
    singleRecord coordinates start endExclusive state record =
      match recordError? coordinates record with
      | some message => .error message
      | none => .ok (numericStep coordinates start endExclusive state record) := by
  cases hCurrent : record.isCurrent with
  | false =>
      simp [singleRecord, recordError?, numericStep, hCurrent]
  | true =>
      by_cases hZero :
          Loam.Observation332.trackedQuantaList coordinates record.event = 0
      · cases hDate : record.date <;>
          simp [singleRecord, recordError?, numericStep, numericFromQuantity,
            hCurrent, hZero, hDate]
      · cases hDate : record.date with
        | none =>
            simp [singleRecord, recordError?, numericStep, hCurrent, hZero, hDate]
        | some date =>
            cases hValid : Loam.ActualDate.validIsoDate date with
            | false =>
                simp [singleRecord, recordError?, numericStep,
                  hCurrent, hZero, hDate, hValid]
            | true =>
                simp [singleRecord, recordError?, numericStep,
                  hCurrent, hZero, hDate, hValid]

private def referenceFused
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
          referenceFused coordinates start endExclusive rest
            (numericStep coordinates start endExclusive state record)

private def singleQuantityFused
    (coordinates : List EffectCoordinate)
    (start endExclusive : String) :
    List Loam.ActualReview.Record →
    Scan →
    Except String Scan
  | [], state => .ok state
  | record :: rest, state =>
      match singleRecord coordinates start endExclusive state record with
      | .error message => .error message
      | .ok next =>
          singleQuantityFused coordinates start endExclusive rest next

private theorem referenceFused_eq_twoPass
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (initial : Scan) :
    referenceFused coordinates start endExclusive records initial =
      twoPass coordinates records start endExclusive initial := by
  induction records generalizing initial with
  | nil =>
      rfl
  | cons record rest ih =>
      unfold referenceFused twoPass validate
      cases hError : recordError? coordinates record with
      | some message =>
          simp [hError]
      | none =>
          simp only [hError]
          change
            referenceFused coordinates start endExclusive rest
                (numericStep coordinates start endExclusive initial record) =
              match validate coordinates rest with
              | .error message => .error message
              | .ok () =>
                  .ok <|
                    rest.foldl
                      (numericStep coordinates start endExclusive)
                      (numericStep coordinates start endExclusive initial record)
          exact ih (numericStep coordinates start endExclusive initial record)

private theorem singleQuantityFused_eq_referenceFused
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (initial : Scan) :
    singleQuantityFused coordinates start endExclusive records initial =
      referenceFused coordinates start endExclusive records initial := by
  induction records generalizing initial with
  | nil =>
      rfl
  | cons record rest ih =>
      unfold singleQuantityFused referenceFused
      rw [singleRecord_eq_reference]
      cases hError : recordError? coordinates record with
      | some message =>
          simp [hError]
      | none =>
          simp only [hError]
          exact ih (numericStep coordinates start endExclusive initial record)

/--
For arbitrary coordinate selections, Record streams, window strings and initial
state, one selected Event quantity computation per current Record preserves the
complete fail-closed two-pass reference result.
-/
theorem single_quantity_fused_eq_twoPass
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (initial : Scan) :
    singleQuantityFused coordinates start endExclusive records initial =
      twoPass coordinates records start endExclusive initial := by
  calc
    singleQuantityFused coordinates start endExclusive records initial =
        referenceFused coordinates start endExclusive records initial :=
      singleQuantityFused_eq_referenceFused
        coordinates records start endExclusive initial
    _ = twoPass coordinates records start endExclusive initial :=
      referenceFused_eq_twoPass
        coordinates records start endExclusive initial

/-!
## Finding

Stock-Flow can compress one level further than Observation 323's record-fusion
shape.

A successful current Record does not need:

    trackedQuanta for validation
        +
    trackedQuanta again for numeric accumulation

The exact same selected Event quantity can decide:

1. whether a date is required;
2. whether that date is valid;
3. opening-boundary contribution;
4. closing-boundary contribution;
5. positive/negative window contribution.

The general theorem preserves the complete Except result, including first
failure message and successful numeric state.

Combined with Observation 332, the strongest research candidate is now:

    selected Balance coordinates
        -> transient finite support image

    each current Record
        -> selected Event quantity exactly once
        -> validation + all Stock-Flow numeric coordinates

    all Records
        -> one left-to-right fail-closed scan

No production optimization is authorized yet. The next step is paired
measurement against current StockFlowReview.project, with List and support-index
single-quantity candidates measured separately.
-/

end Loam.Observation333
