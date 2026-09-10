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

The intervention suppresses one currently open Scheduled identity only for the
hypothetical projection. It does not retire, complete, delete, rewrite, replace,
or otherwise mutate retained evidence.
-/

structure SuppressScheduledHypothesis where
  scheduled : ScheduledId
deriving Repr, DecidableEq

structure ScheduledSuppressionComparison where
  hypothesis : SuppressScheduledHypothesis
  baseline : List ScheduledBalanceEffect
  projected : List ScheduledBalanceEffect
deriving Repr, DecidableEq

inductive ScheduledSuppressionComparisonResult where
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
Compare the ordinary current Scheduled balance projection with a read-only
suppression. Replacement is part of the ordinary lifecycle frontier, so a
superseded Scheduled identity is already absent from the baseline and cannot be a
hypothetical target.
-/
def compareSuppressScheduledBalanceEffectsBefore
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (coordinates : List EffectCoordinate)
    (endExclusive : Time)
    (hypothesis : SuppressScheduledHypothesis) : ScheduledSuppressionComparisonResult :=
  match currentOpenScheduled scheduled terminals events with
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
