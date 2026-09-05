import Loam.Application.ScheduledBalanceInspection

namespace Loam.Application

open Loam.Core
open Std (IsLinearOrder)

set_option autoImplicit false

variable {Time : Type}
  [DecidableEq Time]
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Read-only Scheduled suppression comparison

Observation 185 earned only a read-side boundary:

  canonical evidence
  + explicitly typed hypothetical intervention
  -> derived comparison projection

This module applies that boundary to one already-qualified Application projection:
Scheduled balance effects before an explicit end-exclusive horizon.

The intervention is deliberately only one thing: suppress one currently open
Scheduled identity for the hypothetical projection. It does not retire, complete,
delete, rewrite, or otherwise mutate canonical Scheduled evidence.
-/

/-- One explicit hypothetical request to omit a current-open Scheduled occurrence. -/
structure SuppressScheduledHypothesis where
  scheduled : ScheduledId
deriving Repr, DecidableEq

/-- Baseline and hypothetical Scheduled balance effects from the same qualified open set. -/
structure ScheduledSuppressionComparison where
  hypothesis : SuppressScheduledHypothesis
  baseline : List ScheduledBalanceEffect
  projected : List ScheduledBalanceEffect
deriving Repr, DecidableEq

/--
Typed refusal states preserve the same lifecycle failures as current-open Scheduled
inspection and separately reject a target that is not currently open.
-/
inductive ScheduledSuppressionComparisonResult where
  | comparison (value : ScheduledSuppressionComparison)
  | targetNotOpen
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | conflictingTerminalEvidence
deriving Repr, DecidableEq

private def containsScheduled
    (occurrences : List (ScheduledOccurrence Time))
    (scheduled : ScheduledId) : Bool :=
  occurrences.any fun occurrence => decide (occurrence.id = scheduled)

private def withoutScheduled
    (occurrences : List (ScheduledOccurrence Time))
    (scheduled : ScheduledId) : List (ScheduledOccurrence Time) :=
  occurrences.filter fun occurrence => decide (occurrence.id ≠ scheduled)

/--
Compare the ordinary Scheduled balance projection with the projection obtained by
omitting exactly one current-open Scheduled occurrence.

Lifecycle evidence is qualified once. Baseline and hypothetical answers are then
projected from that same current-open occurrence list. This prevents a hypothetical
suppression from fabricating a second canonical Scheduled memory or bypassing the
existing completion/retirement fail-closed boundary.

A target must be in the qualified current-open set. A currently open target may be
outside the requested horizon or outside the selected coordinates; in those cases
the hypothetical can legitimately equal the baseline for this particular view.
-/
def compareSuppressScheduledBalanceEffectsBefore
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (events : EventMemory)
    (coordinates : List EffectCoordinate)
    (endExclusive : Time)
    (hypothesis : SuppressScheduledHypothesis) : ScheduledSuppressionComparisonResult :=
  match currentOpenScheduled scheduled completions retirements events with
  | .unknownCompletionScheduled => .unknownCompletionScheduled
  | .unknownRetirementScheduled => .unknownRetirementScheduled
  | .conflictingTerminalEvidence => .conflictingTerminalEvidence
  | .open occurrences =>
      if containsScheduled occurrences hypothesis.scheduled then
        .comparison {
          hypothesis := hypothesis
          baseline := scheduledBalanceEffectsBefore occurrences coordinates endExclusive
          projected :=
            scheduledBalanceEffectsBefore
              (withoutScheduled occurrences hypothesis.scheduled)
              coordinates
              endExclusive
        }
      else
        .targetNotOpen

end Loam.Application
