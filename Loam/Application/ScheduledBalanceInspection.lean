import Init.Data.Order
import Loam.Application.ScheduledInspection

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
# Scheduled balance-view effect inspection

Observation 119 qualified the narrow decomposition

  current open Scheduled
  + replaceable BalanceView selection
  -> per-coordinate Scheduled balance effects

without AccountType, Asset, Income, Expense, holding classification, or a second
balance subsystem. Observation 108 already qualified the current-open
end-exclusive horizon rule used here: overdue open Scheduled evidence remains
visible until lifecycle evidence closes it, while an occurrence exactly at the
end boundary is excluded.

This module deliberately projects signed effects only. It does not combine them
with current balances, claim that Scheduled will equal later Actual, or infer
safe-to-spend / Backing authority.
-/

/-- One selected balance coordinate and its aggregate signed open-Scheduled effect. -/
structure ScheduledBalanceEffect where
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

private def inEndExclusiveHorizon
    (scheduledOn endExclusive : Time) : Bool :=
  decide (scheduledOn ≤ endExclusive ∧ scheduledOn ≠ endExclusive)

private def addCoordinateIfAbsent
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) : List EffectCoordinate :=
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def normalizeCoordinates
    (coordinates : List EffectCoordinate) : List EffectCoordinate :=
  coordinates.foldl addCoordinateIfAbsent []

private def occurrenceQuantaAt
    (occurrence : ScheduledOccurrence Time)
    (coordinate : EffectCoordinate) : Int :=
  if occurrence.measure = coordinate.measure then
    (occurrence.quantityAt coordinate.locus).quanta
  else
    0

private def aggregateCoordinate
    (occurrences : List (ScheduledOccurrence Time))
    (endExclusive : Time)
    (coordinate : EffectCoordinate) : ScheduledBalanceEffect :=
  let quanta := occurrences.foldl
    (fun total occurrence =>
      if inEndExclusiveHorizon occurrence.scheduledOn endExclusive then
        total + occurrenceQuantaAt occurrence coordinate
      else
        total)
    0
  {
    coordinate := coordinate
    quantity := Quantity.ofQuanta quanta
  }

/--
Project one already-qualified Scheduled occurrence list onto selected balance
coordinates before `endExclusive`.

This operation carries no lifecycle authority of its own. Callers that start from
retained Scheduled evidence must first obtain a qualified current-open set, as
`currentScheduledBalanceEffectsBefore?` does below. Exposing this pure projection
lets a read-only hypothetical query compare the same qualified open set with a
derived subset without fabricating a second Scheduled memory.
-/
def scheduledBalanceEffectsBefore
    (occurrences : List (ScheduledOccurrence Time))
    (coordinates : List EffectCoordinate)
    (endExclusive : Time) : List ScheduledBalanceEffect :=
  (normalizeCoordinates coordinates).map
    (aggregateCoordinate occurrences endExclusive)

/--
Project aggregate signed effects of the complete current-open Scheduled set onto
one replaceable balance-coordinate selection before `endExclusive`.

Duplicate selected coordinates are normalized as one current question. Every
selected coordinate is retained in the answer, including an explicit zero, so
an internal transfer cannot disappear merely because a wider selected net would
cancel.

The answer fails closed when Scheduled completion / retirement evidence is
structurally inconsistent, exactly like `currentOpenScheduled`.
-/
def currentScheduledBalanceEffectsBefore?
    (scheduled : ScheduledMemory Time)
    (completions : ScheduledCompletionMemory)
    (retirements : ScheduledRetirementMemory)
    (events : EventMemory)
    (coordinates : List EffectCoordinate)
    (endExclusive : Time) : Option (List ScheduledBalanceEffect) :=
  match currentOpenScheduled scheduled completions retirements events with
  | .unknownCompletionScheduled => none
  | .unknownRetirementScheduled => none
  | .conflictingTerminalEvidence => none
  | .open occurrences =>
      some <| scheduledBalanceEffectsBefore occurrences coordinates endExclusive

end Loam.Application
