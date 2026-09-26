import Loam.ActualEvidence
import Loam.ActualReview
import Loam.Application.ActualValidityFrontier

namespace Loam.Observation353

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 353 — provisional adjustment date can be refined without rewriting quantity

Issue #1372 reached a practical question after the reconciled-interval work:

    an unexplained quantity discrepancy is recorded at the reconciliation day
        ->
    later evidence identifies an earlier occurrence day
        ->
    can the existing append-only validity correction machinery refine the
    historical position without inventing a second quantity history?

Production already has two separate authorities:

- Event / Effect carries the retained quantity movement;
- ActualValidityHistory carries append-only occurrence-date claims and
  corrections.

This observation composes those existing types directly.

The selected specimen is one balanced unexplained adjustment:

    cash         -16 JPY
    unexplained  +16 JPY

It is initially recorded with a provisional occurrence date of 2026-06-07.
Later evidence refines that date to 2026-06-03.

The expected semantics are:

1. the retained quantity Event is unchanged;
2. the raw validity history still contains the original 2026-06-07 claim;
3. the current validity frontier selects 2026-06-03;
4. current-truth historical review moves the same -16 JPY Event from 06-07 to
   06-03;
5. no new UnknownTime, Adjustment, or second quantity engine is required merely
   to perform this refinement.

This does not claim that the earlier pointwise balance was known before the
revision arrived. It proves only that, once the better date evidence exists, the
current historical projection can refine append-only while provenance remains.
-/

private def adjustmentId : EventId := ⟨"o353-adjustment"⟩
private def revisionId : ActualValidityRevisionId := ⟨"o353-date-r1"⟩

private def cash : LocusId := ⟨"cash"⟩
private def unexplained : LocusId := ⟨"unexplained"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def adjustmentEvent : Event :=
  {
    id := adjustmentId
    effects :=
      [ Effect.ofAnonymousQuantity cash yen (Quantity.ofQuanta (-16))
      , Effect.ofAnonymousQuantity unexplained yen (Quantity.ofQuanta 16)
      ]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
  }

private def events : EventMemory :=
  {
    events := [adjustmentEvent]
    idNodup := by simp
  }

private def beforeHistory : ActualValidityHistory String :=
  {
    facts := [.base adjustmentId "2026-06-07"]
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp
  }

private def afterHistory : ActualValidityHistory String :=
  {
    facts :=
      [ .base adjustmentId "2026-06-07"
      , .revision revisionId adjustmentId "2026-06-03"
      ]
    factRefNodup := by native_decide
    corrections :=
      [{ target := .root adjustmentId, replacement := revisionId }]
    correctionIdNodup := by native_decide
  }

private def evidenceWith
    (history : ActualValidityHistory String) : Loam.ActualEvidence :=
  {
    Loam.ActualEvidence.empty with
      events := events
      validity := history
  }

private def currentDate?
    (history : ActualValidityHistory String) : Option String := do
  let memory ← admittedActualValidityMemory? history
  memory.findByEventId? adjustmentId

private def selectedCashQuantity?
    (history : ActualValidityHistory String)
    (date : String) : Option Int :=
  match Loam.ActualReview.recordsFromActualEvidence? (evidenceWith history) with
  | .error _ => none
  | .ok records =>
      match Loam.ActualReview.select records (.day date) with
      | [record] => some (Event.quantityAt record.event cash yen).quanta
      | _ => none

/--
Before any date refinement, the current occurrence-date projection uses the
provisional reconciliation-day claim.
-/
theorem provisional_date_is_current_before_refinement :
    currentDate? beforeHistory = some "2026-06-07" := by
  native_decide

/--
Appending one validity revision and correction changes the current occurrence
date without mutating the Event.
-/
theorem refined_date_is_current_after_refinement :
    currentDate? afterHistory = some "2026-06-03" := by
  native_decide

/--
The old date claim remains retained provenance after the refinement. The
replacement date is additive evidence, not destructive mutation.
-/
theorem refinement_retains_both_date_claims :
    (.base adjustmentId "2026-06-07" : ActualValidityFact String) ∈
        afterHistory.facts ∧
      (.revision revisionId adjustmentId "2026-06-03" :
          ActualValidityFact String) ∈ afterHistory.facts := by
  native_decide

/--
Current-truth historical review moves the same exact cash delta to the refined
day. Quantity does not need to be republished or padded.
-/
theorem same_quantity_moves_to_refined_day :
    selectedCashQuantity? beforeHistory "2026-06-07" = some (-16) ∧
    selectedCashQuantity? beforeHistory "2026-06-03" = none ∧
    selectedCashQuantity? afterHistory "2026-06-07" = none ∧
    selectedCashQuantity? afterHistory "2026-06-03" = some (-16) := by
  native_decide

/--
The refined validity history remains semantically admissible: the result is one
current date for the Event, not two competing dates selected by representation
order.
-/
theorem refined_history_remains_admissible :
    actualValidityFrontierAdmissible afterHistory = true := by
  native_decide

/-!
## Finding

For the selected adjustment-refinement pressure, existing production semantics
already have the required separation:

    retained quantity Event
        +
    append-only date provenance
        +
    validity correction frontier
        ->
    refined current historical placement

Therefore an unexplained discrepancy can be recorded as an ordinary exact
Movement at the reconciliation boundary and later have its occurrence date
refined without replacing its quantity.

If later evidence also changes the Effects or interpretation, existing
EventCorrection remains the separate operation. Current production regression
coverage already checks that a replacement Event carries the target's current
date and that the replacement itself can subsequently receive an independent
date correction.

What is *not* earned here:

- a universal UnknownTime scalar;
- a new Adjustment Core primitive;
- automatic inference that a reconciliation-day adjustment physically occurred
  on that day;
- pointwise historical exactness before the improved date evidence exists;
- learned-time reporting for "what did LOAM believe on an earlier day?";
- a second historical quantity engine.

The practical rule is smaller:

    provisional placement may be refined append-only;
    current-truth history follows the qualified current date;
    old date evidence remains retained provenance.

That is enough to continue #1372 without enlarging the Core merely to support
later date discovery.
-/

end Loam.Observation353
