import Loam.StockFlowReview

namespace Loam.Observation322

open Loam.Core

set_option autoImplicit false

/-!
# Observation 322 — Stock-Flow numeric-pass fusion

The current Stock-Flow construction first validates selected Event dates and
then computes three numeric observations over the same ActualReview.Record list:

1. opening boundary quantity;
2. closing boundary quantity;
3. positive / negative window changes.

This observation leaves the validation pass completely unchanged and asks a
smaller universal question:

> After validation has succeeded, can those three numeric passes be replaced by
> one arithmetic scan without changing any numeric answer?

The fused scan is research-only. No production path is modified.
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

private def boundaryStep
    (coordinates : List EffectCoordinate)
    (boundary : String)
    (total : Int)
    (record : Loam.ActualReview.Record) : Int :=
  if !record.isCurrent then
    total
  else
    match record.date with
    | none => total
    | some date =>
        if decide (date < boundary) then
          total + trackedQuanta coordinates record.event
        else
          total

private def windowStep
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (totals : Int × Int)
    (record : Loam.ActualReview.Record) : Int × Int :=
  if !record.isCurrent then
    totals
  else
    match record.date with
    | none => totals
    | some date =>
        if decide (start ≤ date ∧ date < endExclusive) then
          let quantity := trackedQuanta coordinates record.event
          if quantity > 0 then
            (totals.1 + quantity, totals.2)
          else if quantity < 0 then
            (totals.1, totals.2 + quantity)
          else
            totals
        else
          totals

private structure Scan where
  startBoundary : Int
  endBoundary : Int
  positiveWindow : Int
  negativeWindow : Int
deriving Repr, DecidableEq

/--
One arithmetic record pass. The selected Event quantity is computed at most once
for a dated current record, then routed to all relevant output components.
-/
private def fusedStep
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

/-! ## One-record correspondence -/

private theorem fusedStep_start
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (state : Scan)
    (record : Loam.ActualReview.Record) :
    (fusedStep coordinates start endExclusive state record).startBoundary =
      boundaryStep coordinates start state.startBoundary record := by
  cases hCurrent : record.isCurrent <;>
    cases hDate : record.date <;>
    simp [fusedStep, boundaryStep, hCurrent, hDate]

private theorem fusedStep_end
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (state : Scan)
    (record : Loam.ActualReview.Record) :
    (fusedStep coordinates start endExclusive state record).endBoundary =
      boundaryStep coordinates endExclusive state.endBoundary record := by
  cases hCurrent : record.isCurrent <;>
    cases hDate : record.date <;>
    simp [fusedStep, boundaryStep, hCurrent, hDate]

private theorem fusedStep_window
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (state : Scan)
    (record : Loam.ActualReview.Record) :
    ( (fusedStep coordinates start endExclusive state record).positiveWindow
    , (fusedStep coordinates start endExclusive state record).negativeWindow ) =
      windowStep coordinates start endExclusive
        (state.positiveWindow, state.negativeWindow) record := by
  cases hCurrent : record.isCurrent <;>
    cases hDate : record.date <;>
    simp [fusedStep, windowStep, hCurrent, hDate]

/-! ## Whole-list correspondence -/

private theorem fusedFold_start
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (records : List Loam.ActualReview.Record)
    (state : Scan) :
    (records.foldl (fusedStep coordinates start endExclusive) state).startBoundary =
      records.foldl (boundaryStep coordinates start) state.startBoundary := by
  induction records generalizing state with
  | nil => rfl
  | cons record rest ih =>
      simp only [List.foldl_cons]
      simpa [fusedStep_start] using
        ih (fusedStep coordinates start endExclusive state record)

private theorem fusedFold_end
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (records : List Loam.ActualReview.Record)
    (state : Scan) :
    (records.foldl (fusedStep coordinates start endExclusive) state).endBoundary =
      records.foldl (boundaryStep coordinates endExclusive) state.endBoundary := by
  induction records generalizing state with
  | nil => rfl
  | cons record rest ih =>
      simp only [List.foldl_cons]
      simpa [fusedStep_end] using
        ih (fusedStep coordinates start endExclusive state record)

private theorem fusedFold_window
    (coordinates : List EffectCoordinate)
    (start endExclusive : String)
    (records : List Loam.ActualReview.Record)
    (state : Scan) :
    let result :=
      records.foldl (fusedStep coordinates start endExclusive) state
    (result.positiveWindow, result.negativeWindow) =
      records.foldl (windowStep coordinates start endExclusive)
        (state.positiveWindow, state.negativeWindow) := by
  induction records generalizing state with
  | nil => rfl
  | cons record rest ih =>
      simp only [List.foldl_cons]
      simpa [fusedStep_window] using
        ih (fusedStep coordinates start endExclusive state record)

/--
For arbitrary selected coordinates, Actual review records, window strings, and
initial accumulators, one fused arithmetic scan is extensionally equal to the
three independent current-style numeric folds.

No date-validity hypothesis is needed for this theorem because it compares only
the arithmetic layer. Production validation remains an upstream gate.
-/
theorem fused_numeric_passes_correspond
    (coordinates : List EffectCoordinate)
    (records : List Loam.ActualReview.Record)
    (start endExclusive : String)
    (initial : Scan) :
    let fused :=
      records.foldl (fusedStep coordinates start endExclusive) initial
    fused.startBoundary =
        records.foldl (boundaryStep coordinates start)
          initial.startBoundary ∧
    fused.endBoundary =
        records.foldl (boundaryStep coordinates endExclusive)
          initial.endBoundary ∧
    (fused.positiveWindow, fused.negativeWindow) =
        records.foldl (windowStep coordinates start endExclusive)
          (initial.positiveWindow, initial.negativeWindow) := by
  constructor
  · exact fusedFold_start coordinates start endExclusive records initial
  constructor
  · exact fusedFold_end coordinates start endExclusive records initial
  · exact fusedFold_window coordinates start endExclusive records initial

/-!
## Finding

The three Stock-Flow numeric passes share one compositional product summary.

The result is universal over the arithmetic layer:

    boundary(start)
    boundary(endExclusive)
    window positive / negative

can be accumulated in one record traversal without changing those answers.

This observation intentionally leaves the existing fail-closed date validation
separate. It therefore justifies at most the mathematical possibility:

    validate once
        +
    one fused numeric scan

instead of:

    validate once
        +
    start-boundary scan
        +
    end-boundary scan
        +
    window-change scan

The next research question is whether validation can also be fused while
preserving the exact first failing Event and error message. That is a
fail-closed sequencing question, not an additive-algebra question.

No production optimization is authorized here.
-/

end Loam.Observation322
