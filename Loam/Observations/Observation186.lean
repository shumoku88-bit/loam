import Loam.Application.ScheduledBalanceHypothetical

namespace Loam.Observation186

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 186 — one concrete read-only Scheduled suppression overlay

Observation 185 showed that hypothetical household interventions should remain typed
and derived rather than becoming canonical Scenario or Recommendation state.

This observation applies exactly one such intervention to an already-qualified
Application projection: omit one current-open Scheduled identity from the derived
Scheduled balance effects before an explicit end-exclusive horizon.

The target is resolved only after the ordinary current-open lifecycle boundary has
qualified the canonical Scheduled evidence. Baseline and overlay then use the same
qualified occurrence list. The hypothetical therefore cannot repair or bypass
broken completion/retirement evidence by inventing a second Scheduled memory.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩
private def rent : LocusId := ⟨"rent"⟩
private def wallet : LocusId := ⟨"wallet"⟩

private def coordinate (locus : LocusId) : EffectCoordinate := ⟨locus, yen⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def paymentMovement : BalancedMovement LocusId :=
  {
    measure := yen
    changes := [change bank (-30), change rent 30]
    balanced := by decide
  }

private def transferMovement : BalancedMovement LocusId :=
  {
    measure := yen
    changes := [change bank (-20), change wallet 20]
    balanced := by decide
  }

private def overdueMovement : BalancedMovement LocusId :=
  {
    measure := yen
    changes := [change bank (-5), change wallet 5]
    balanced := by decide
  }

private def futureMovement : BalancedMovement LocusId :=
  {
    measure := yen
    changes := [change bank (-40), change rent 40]
    balanced := by decide
  }

private def payment : ScheduledOccurrence Nat :=
  { id := ⟨"scheduled-payment"⟩, scheduledOn := 2, movement := paymentMovement }

private def transfer : ScheduledOccurrence Nat :=
  { id := ⟨"scheduled-transfer"⟩, scheduledOn := 3, movement := transferMovement }

private def overdue : ScheduledOccurrence Nat :=
  { id := ⟨"scheduled-overdue"⟩, scheduledOn := 0, movement := overdueMovement }

private def future : ScheduledOccurrence Nat :=
  { id := ⟨"scheduled-future"⟩, scheduledOn := 5, movement := futureMovement }

private def scheduledMemory : ScheduledMemory Nat :=
  {
    occurrences := [payment, transfer, overdue, future]
    idNodup := by decide
  }

private def emptyCompletions : ScheduledCompletionMemory :=
  {
    completions := []
    scheduledNodup := by simp
    actualNodup := by simp
  }

private def emptyRetirements : ScheduledRetirementMemory :=
  {
    retirements := []
    scheduledNodup := by simp
  }

private def emptyEvents : EventMemory :=
  {
    events := []
    idNodup := by simp
  }

private def paymentHypothesis : SuppressScheduledHypothesis :=
  { scheduled := ⟨"scheduled-payment"⟩ }

private def futureHypothesis : SuppressScheduledHypothesis :=
  { scheduled := ⟨"scheduled-future"⟩ }

private def missingHypothesis : SuppressScheduledHypothesis :=
  { scheduled := ⟨"scheduled-missing"⟩ }

private def expectedBaseline : List ScheduledBalanceEffect :=
  [ { coordinate := coordinate bank, quantity := Quantity.ofQuanta (-55) }
  , { coordinate := coordinate wallet, quantity := Quantity.ofQuanta 25 }
  ]

private def expectedWithoutPayment : List ScheduledBalanceEffect :=
  [ { coordinate := coordinate bank, quantity := Quantity.ofQuanta (-25) }
  , { coordinate := coordinate wallet, quantity := Quantity.ofQuanta 25 }
  ]

/--
The concrete overlay keeps the ordinary baseline and shows only the consequence of
omitting the selected current-open payment from the same qualified occurrence set.
-/
theorem suppress_payment_changes_only_derived_projection :
    compareSuppressScheduledBalanceEffectsBefore
      scheduledMemory emptyCompletions emptyRetirements emptyEvents
      [coordinate bank, coordinate wallet]
      (4 : Nat)
      paymentHypothesis =
    .comparison {
      hypothesis := paymentHypothesis
      baseline := expectedBaseline
      projected := expectedWithoutPayment
    } := by
  decide

/-- The comparison baseline is exactly the already-qualified production projection. -/
theorem baseline_matches_existing_application_projection :
    (match compareSuppressScheduledBalanceEffectsBefore
        scheduledMemory emptyCompletions emptyRetirements emptyEvents
        [coordinate bank, coordinate wallet]
        (4 : Nat)
        paymentHypothesis with
      | .comparison value => some value.baseline
      | _ => none) =
    currentScheduledBalanceEffectsBefore?
      scheduledMemory emptyCompletions emptyRetirements emptyEvents
      [coordinate bank, coordinate wallet]
      (4 : Nat) := by
  decide

/-- A current-open target outside this horizon remains a valid hypothesis but has no visible effect here. -/
theorem open_target_outside_horizon_can_equal_baseline :
    compareSuppressScheduledBalanceEffectsBefore
      scheduledMemory emptyCompletions emptyRetirements emptyEvents
      [coordinate bank, coordinate wallet]
      (4 : Nat)
      futureHypothesis =
    .comparison {
      hypothesis := futureHypothesis
      baseline := expectedBaseline
      projected := expectedBaseline
    } := by
  decide

/-- An identity that is not in the qualified current-open set is rejected rather than silently becoming a no-op. -/
theorem non_open_target_is_rejected :
    compareSuppressScheduledBalanceEffectsBefore
      scheduledMemory emptyCompletions emptyRetirements emptyEvents
      [coordinate bank]
      (4 : Nat)
      missingHypothesis =
    .targetNotOpen := by
  decide

private def unknownCompletion : ScheduledCompletionMemory :=
  {
    completions :=
      [{ scheduled := ⟨"unknown-scheduled"⟩, actual := ⟨"unknown-actual"⟩ }]
    scheduledNodup := by simp
    actualNodup := by simp
  }

/-- Hypothetical comparison preserves the existing fail-closed lifecycle boundary. -/
theorem lifecycle_failure_is_not_repaired_by_hypothesis :
    compareSuppressScheduledBalanceEffectsBefore
      scheduledMemory unknownCompletion emptyRetirements emptyEvents
      [coordinate bank]
      (4 : Nat)
      paymentHypothesis =
    .unknownCompletionScheduled := by
  decide

/-!
Observation 186 earns only this practical slice:

```text
qualified current-open Scheduled evidence
+ one typed SuppressScheduledHypothesis
+ one ordinary Scheduled balance projection question
-> baseline and hypothetical derived effects side by side
```

It does not earn a generic Scenario engine, optimizer, Recommendation, automatic
retirement, safe-to-spend claim, or mutation path. A later adapter may expose this
single read-only comparison to a human or external query client without turning the
hypothesis into household evidence.
-/

end Loam.Observation186
