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

/-!
## Finding

The fail-closed sequencing itself can be fused.

For the research reference, one left-to-right traversal preserves the complete
Except observation, including exact first-failure text, while accumulating the
same numeric product summary.

The error constructor used by the research reference mirrors the current
StockFlowReview source spelling and left-to-right validation rule. This
observation does not claim a general theorem directly against the public
production project, because the production validation helpers are private and
the public project also owns endpoint validation, current-balance projection,
and the final parity gate.

It does establish the difficult local result:

    selected-record validation
        +
    Stock-Flow numeric accumulation

share one sequential fail-closed scan semantics.

No production change is authorized.
-/

end Loam.Observation323
