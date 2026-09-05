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
delete, rewrite, replace, or otherwise mutate canonical Scheduled evidence.
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
Typed refusal states for the pre-replacement observation boundary.
-/
inductive ScheduledSuppressionComparisonResult where
  | comparison (value : ScheduledSuppressionComparison)
  | targetNotOpen
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | conflictingTerminalEvidence
deriving Repr, DecidableEq

/-- Replacement-aware refusal states for practical readers. -/
inductive ScheduledSuppressionWithReplacementComparisonResult where
  | comparison (value : ScheduledSuppressionComparison)
  | targetNotOpen
  | unknownCompletionScheduled
  | unknownRetirementScheduled
  | unknownReplacementScheduled
  | invalidReplacementGraph
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

private def comparisonFromOpenOccurrences
    (occurrences : List (ScheduledOccurrence Time))
    (coordinates : List EffectCoordinate)
    (endExclusive : Time)
    (hypothesis : SuppressScheduledHypothesis) : Option ScheduledSuppressionComparison :=
  if containsScheduled occurrences hypothesis.scheduled then
    some {
      hypothesis := hypothesis
      baseline := scheduledBalanceEffectsBefore occurrences coordinates endExclusive
      projected :=
        scheduledBalanceEffectsBefore
          (withoutScheduled occurrences hypothesis.scheduled)
          coordinates
          endExclusive
    }
  else
    none

/--
Compare the ordinary Scheduled balance projection with a read-only suppression in
the pre-replacement observation world retained by Observation 186.
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
      match comparisonFromOpenOccurrences occurrences coordinates endExclusive hypothesis with
      | some value => .comparison value
      | none => .targetNotOpen

/--
Compare suppression against the same replacement-aware current-open frontier used
by practical Scheduled readers. A superseded Scheduled identity is therefore not
a valid hypothetical target: it is already absent from the canonical baseline.
-/
def compareSuppressScheduledBalanceEffectsBeforeWithReplacement
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (replacements : ScheduledReplacementMemory)
    (events : EventMemory)
    (coordinates : List EffectCoordinate)
    (endExclusive : Time)
    (hypothesis : SuppressScheduledHypothesis) :
    ScheduledSuppressionWithReplacementComparisonResult :=
  match currentOpenScheduledWithReplacement
      scheduled completions retirements replacements events with
  | .unknownCompletionScheduled => .unknownCompletionScheduled
  | .unknownRetirementScheduled => .unknownRetirementScheduled
  | .unknownReplacementScheduled => .unknownReplacementScheduled
  | .invalidReplacementGraph => .invalidReplacementGraph
  | .conflictingTerminalEvidence => .conflictingTerminalEvidence
  | .open occurrences =>
      match comparisonFromOpenOccurrences occurrences coordinates endExclusive hypothesis with
      | some value => .comparison value
      | none => .targetNotOpen

end Loam.Application
