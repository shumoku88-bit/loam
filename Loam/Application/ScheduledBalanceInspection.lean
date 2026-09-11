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
visible until terminal evidence closes it, while an occurrence exactly at the
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
retained Scheduled evidence first obtain the single qualified current-open set.
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

All terminal meanings, including replacement, are part of the ordinary Scheduled
frontier. Structural refusal collapses to `none` at this older Option-shaped
projection boundary.
-/
def currentScheduledBalanceEffectsBefore?
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (coordinates : List EffectCoordinate)
    (endExclusive : Time) : Option (List ScheduledBalanceEffect) :=
  match currentOpenScheduled scheduled terminals events with
  | .open occurrences =>
      some <| scheduledBalanceEffectsBefore occurrences coordinates endExclusive
  | _ => none

end Loam.Application
