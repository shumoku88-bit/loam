import Init.Data.Order
import Loam.Application.ConsumptionInspection
import Loam.Application.ScheduledInspection
import Loam.Core.AccountingRole
import Loam.Core.ScheduledRouting

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
# Scheduled Commitment and Headroom inspection

Observation 108 selected Commitment as a projection over open Scheduled evidence
plus historical routing. Observation 113 selected:

  Remaining = Entitlement - Consumption
  Headroom  = Remaining - Commitment

without retained reservation, Commitment, Remaining, or Headroom state.

Observation 153 then pruned the practical Scheduled routing subject. Whole
`ScheduledId` is too coarse for split-purpose movement; bare `LocusId` is too
coarse across distinct Scheduled intent; a fresh Claim identity is not yet earned
when it is only a bijective wrapper. The reusable coordinate is owned by
`Loam.Core.ScheduledRouting`.

Observation 227 strengthened the production household projection without adding
a fixed-cost or eligibility authority. Scheduled is a future-cashflow surface,
so a positive quantity is not by itself Capacity pressure. Explicit
ScheduledRouting selects positive pressure directly. Without a route, positive
Expense and Liability coordinates exert pressure by default, positive
Asset/Income/Equity coordinates are resolved non-pressure, and a missing
AccountingRole remains an unresolved eligibility frontier.

The current Scheduled lifecycle has no learned-time coordinate, so this module
answers only the current-open view. `observedAt` selects historical routing; it
does not pretend to reconstruct when completion, retirement, or replacement
became known.

The query-local `ScheduledPressurePartition` is the one semantic carrier after
current-open selection. Selection and routing/role classification happen once;
Commitment totals, visible frontiers, and actionable routing rows are projections
of that classified partition rather than independent reimplementations.
-/

/-- Compatibility aggregate view for one queried Purpose. -/
structure ScheduledCommitmentView where
  managed : Quantity
  unmanaged : Quantity
  unrouted : Quantity
  unresolvedEligibility : Quantity
deriving Repr, DecidableEq

/-- Arithmetic evidence for one current Headroom answer. -/
structure HeadroomView where
  remaining : Quantity
  commitment : Quantity
  headroom : Quantity
  unmanagedCommitment : Quantity
  unroutedCommitment : Quantity
  unresolvedEligibility : Quantity
deriving Repr, DecidableEq

/--
Observation 227 classification of one current-open positive Scheduled subject
coordinate into the shared Capacity-pressure partition.
-/
inductive ScheduledPressureClass where
  | managed (purpose : PurposeId)
  | unmanaged
  | unroutedPressure
  | resolvedNonPressure
  | unresolvedEligibility
deriving Repr, DecidableEq

/--
Classify one aggregated `ScheduledId × LocusId` subject at `observedAt`.

Explicit routing owns explicit pressure intent. Only an unrouted subject falls
back to partial AccountingRole classification: positive Expense and Liability
coordinates exert unrouted pressure, positive Asset/Income/Equity coordinates
are resolved non-pressure, and a missing AccountingRole remains an unresolved
eligibility frontier rather than becoming a default role or zero pressure.
-/
def classifyScheduledPressure
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (observedAt : Time)
    (subject : ScheduledRoutingSubject) : ScheduledPressureClass :=
  match routing.statusAt subject observedAt with
  | .managed routedPurpose => .managed routedPurpose
  | .unmanaged => .unmanaged
  | .unrouted =>
      match roles.roleOf? subject.locus with
      | some .expense => .unroutedPressure
      | some .liability => .unroutedPressure
      | some .asset => .resolvedNonPressure
      | some .income => .resolvedNonPressure
      | some .equity => .resolvedNonPressure
      | none => .unresolvedEligibility

/-- One actionable unrouted or unresolved Scheduled pressure coordinate. -/
structure UnresolvedScheduledPressureRow (Time : Type) where
  subject : ScheduledRoutingSubject
  scheduledOn : Time
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

/--
One selected current-open subject coordinate: the aggregated positive quantity
at one Locus of one occurrence inside the explicit current horizon and Measure.
-/
private structure SelectedCoordinate (Time : Type) where
  subject : ScheduledRoutingSubject
  scheduledOn : Time
  measure : MeasureId
  quantity : Quantity

private def inCurrentEndExclusiveHorizon
    (observedAt scheduledOn endExclusive : Time) : Bool :=
  decide (observedAt ≤ scheduledOn) &&
    decide (scheduledOn ≤ endExclusive ∧ scheduledOn ≠ endExclusive)

private def addLocusIfAbsent
    (loci : List LocusId)
    (locus : LocusId) : List LocusId :=
  if locus ∈ loci then loci else loci ++ [locus]

/-- Recover each represented Locus once. -/
private def scheduledLoci
    (occurrence : ScheduledOccurrence Time) : List LocusId :=
  occurrence.movement.changes.foldl
    (fun loci change => addLocusIfAbsent loci change.coordinate)
    []

/--
Enumerate each selected positive aggregated `ScheduledId × LocusId` coordinate
of one open occurrence exactly once.
-/
private def selectedCoordinates
    (measure : MeasureId)
    (observedAt endExclusive : Time)
    (occurrence : ScheduledOccurrence Time) : List (SelectedCoordinate Time) :=
  if occurrence.measure ≠ measure then
    []
  else if !inCurrentEndExclusiveHorizon observedAt occurrence.scheduledOn endExclusive then
    []
  else
    (scheduledLoci occurrence).filterMap fun locus =>
      let quantity := occurrence.quantityAt locus
      if quantity.quanta ≤ 0 then
        none
      else
        some {
          subject := { scheduled := occurrence.id, locus := locus }
          scheduledOn := occurrence.scheduledOn
          measure := occurrence.measure
          quantity := quantity }

/-- One selected coordinate with its pressure classification fixed for this query. -/
structure ScheduledPressureRow (Time : Type) where
  subject : ScheduledRoutingSubject
  scheduledOn : Time
  measure : MeasureId
  quantity : Quantity
  pressure : ScheduledPressureClass
deriving Repr, DecidableEq

/-- A transient query result: selection and routing/role classification happen once. -/
abbrev ScheduledPressurePartition (Time : Type) := List (ScheduledPressureRow Time)

private def pressureRow
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (observedAt : Time)
    (coordinate : SelectedCoordinate Time) : ScheduledPressureRow Time :=
  {
    subject := coordinate.subject
    scheduledOn := coordinate.scheduledOn
    measure := coordinate.measure
    quantity := coordinate.quantity
    pressure := classifyScheduledPressure roles routing observedAt coordinate.subject
  }

/-- Select and classify one current-open Scheduled set exactly once. -/
def scheduledPressurePartitionFromOpen
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : ScheduledPressurePartition Time :=
  (occurrences.flatMap (selectedCoordinates measure observedAt endExclusive)).map
    (pressureRow roles routing observedAt)

namespace ScheduledPressurePartition

/-- Managed Commitment belonging to one Purpose. -/
def managedFor
    (partition : ScheduledPressurePartition Time)
    (purpose : PurposeId) : Quantity :=
  Quantity.ofQuanta <|
    (partition.filterMap fun row =>
      match row.pressure with
      | .managed routedPurpose =>
          if routedPurpose = purpose then some row.quantity.quanta else none
      | _ => none).sum

/-- Query-global pressure explicitly marked unmanaged. -/
def unmanaged (partition : ScheduledPressurePartition Time) : Quantity :=
  Quantity.ofQuanta <|
    (partition.filterMap fun row =>
      match row.pressure with
      | .unmanaged => some row.quantity.quanta
      | _ => none).sum

/-- Query-global unrouted pressure justified by AccountingRole. -/
def unrouted (partition : ScheduledPressurePartition Time) : Quantity :=
  Quantity.ofQuanta <|
    (partition.filterMap fun row =>
      match row.pressure with
      | .unroutedPressure => some row.quantity.quanta
      | _ => none).sum

/-- Keep exactly the unresolved-eligibility coordinates, preserving query order. -/
def unresolvedRows
    (partition : ScheduledPressurePartition Time) :
    List (UnresolvedScheduledPressureRow Time) :=
  partition.filterMap fun row =>
    match row.pressure with
    | .unresolvedEligibility =>
        some {
          subject := row.subject
          scheduledOn := row.scheduledOn
          measure := row.measure
          quantity := row.quantity }
    | _ => none

/-- Query-global pressure whose AccountingRole is still unknown. -/
def unresolvedEligibility (partition : ScheduledPressurePartition Time) : Quantity :=
  Quantity.ofQuanta <|
    (partition.unresolvedRows.map (fun row => row.quantity.quanta)).sum

/-- Actionable unrouted or unresolved subjects, preserving query order. -/
def actionableRows
    (partition : ScheduledPressurePartition Time) :
    List (UnresolvedScheduledPressureRow Time) :=
  partition.filterMap fun row =>
    match row.pressure with
    | .unroutedPressure
    | .unresolvedEligibility =>
        some {
          subject := row.subject
          scheduledOn := row.scheduledOn
          measure := row.measure
          quantity := row.quantity }
    | _ => none

/-- Compatibility aggregate view projected from the one classified partition. -/
def commitmentFor
    (partition : ScheduledPressurePartition Time)
    (purpose : PurposeId) : ScheduledCommitmentView :=
  {
    managed := partition.managedFor purpose
    unmanaged := partition.unmanaged
    unrouted := partition.unrouted
    unresolvedEligibility := partition.unresolvedEligibility
  }

/-- The unresolved aggregate is definitionally the quantity sum of its rows. -/
theorem unresolvedEligibility_eq_rows_sum
    (partition : ScheduledPressurePartition Time) :
    partition.unresolvedEligibility.quanta =
      (partition.unresolvedRows.map (fun row => row.quantity.quanta)).sum := by
  simp [unresolvedEligibility]

/-- Actionable rows are exactly the unrouted plus unresolved pressure quantity. -/
theorem actionablePressure_eq_rows_sum
    (partition : ScheduledPressurePartition Time) :
    partition.unrouted.quanta + partition.unresolvedEligibility.quanta =
      (partition.actionableRows.map (fun row => row.quantity.quanta)).sum := by
  induction partition with
  | nil =>
      simp [unrouted, unresolvedEligibility, unresolvedRows, actionableRows]
  | cons row rest ih =>
      simp [unrouted, unresolvedEligibility, unresolvedRows, actionableRows] at ih
      cases hpressure : row.pressure <;>
        simp [unrouted, unresolvedEligibility, unresolvedRows, actionableRows, hpressure] <;>
        omega

end ScheduledPressurePartition

/-- Resolve current-open lifecycle once, then select and classify its pressure once. -/
def currentScheduledPressurePartition?
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option (ScheduledPressurePartition Time) :=
  match currentOpenScheduled scheduled terminals events with
  | .open occurrences =>
      some <| scheduledPressurePartitionFromOpen
        occurrences roles routing measure observedAt endExclusive
  | _ => none

/-- Project unresolved-eligibility rows behind one current-open Scheduled set. -/
def unresolvedScheduledPressureRowsFromOpen
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : List (UnresolvedScheduledPressureRow Time) :=
  (scheduledPressurePartitionFromOpen
    occurrences roles routing measure observedAt endExclusive).unresolvedRows

/-- Project all actionable unrouted and unresolved rows behind one open set. -/
def actionableScheduledPressureRowsFromOpen
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : List (UnresolvedScheduledPressureRow Time) :=
  (scheduledPressurePartitionFromOpen
    occurrences roles routing measure observedAt endExclusive).actionableRows

/-- Compatibility aggregate Current Scheduled pressure for one Purpose and Measure. -/
def currentScheduledCommitment?
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option ScheduledCommitmentView :=
  (currentScheduledPressurePartition?
    scheduled terminals events roles routing measure observedAt endExclusive).map
      (fun partition => partition.commitmentFor purpose)

/--
The query-global unmanaged frontier of the compatibility Commitment view is
independent of the queried Purpose. The distinction is structural because both
views project the same partition-level `unmanaged` quantity.
-/
theorem currentScheduledCommitment?_unmanaged_independent
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (leftPurpose rightPurpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) :
    (currentScheduledCommitment?
        scheduled terminals events roles routing leftPurpose
        measure observedAt endExclusive).map (fun view => view.unmanaged)
      =
    (currentScheduledCommitment?
        scheduled terminals events roles routing rightPurpose
        measure observedAt endExclusive).map (fun view => view.unmanaged) := by
  unfold currentScheduledCommitment?
  cases currentScheduledPressurePartition?
      scheduled terminals events roles routing measure observedAt endExclusive <;> rfl

/-- Project unresolved eligibility rows from the current classified partition. -/
def currentUnresolvedScheduledPressure?
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) :
    Option (List (UnresolvedScheduledPressureRow Time)) :=
  (currentScheduledPressurePartition?
    scheduled terminals events roles routing measure observedAt endExclusive).map
      ScheduledPressurePartition.unresolvedRows

/--
The unresolved subject rows and aggregate unresolved eligibility frontier are two
projections of the same classified partition.
-/
theorem currentScheduledCommitment?_unresolvedEligibility_eq_rows_sum
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) :
    (currentScheduledCommitment?
        scheduled terminals events roles routing purpose
        measure observedAt endExclusive).map (fun view => view.unresolvedEligibility.quanta)
      =
    (currentUnresolvedScheduledPressure?
        scheduled terminals events roles routing measure observedAt endExclusive).map
      (fun rows => (rows.map (fun row => row.quantity.quanta)).sum) := by
  unfold currentScheduledCommitment? currentUnresolvedScheduledPressure?
  cases hpartition : currentScheduledPressurePartition?
      scheduled terminals events roles routing measure observedAt endExclusive with
  | none => rfl
  | some partition =>
      simp only [Option.map_some]
      simpa [ScheduledPressurePartition.commitmentFor] using
        ScheduledPressurePartition.unresolvedEligibility_eq_rows_sum partition

/-- Project actionable unrouted and unresolved rows from the current partition. -/
def currentActionableScheduledPressure?
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) :
    Option (List (UnresolvedScheduledPressureRow Time)) :=
  (currentScheduledPressurePartition?
    scheduled terminals events roles routing measure observedAt endExclusive).map
      ScheduledPressurePartition.actionableRows

/--
Actionable routing subjects are exactly the unrouted plus unresolved pressure of
the same classified partition.
-/
theorem currentScheduledCommitment?_actionablePressure_eq_rows_sum
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) :
    (currentScheduledCommitment?
        scheduled terminals events roles routing purpose
        measure observedAt endExclusive).map
      (fun view => view.unrouted.quanta + view.unresolvedEligibility.quanta)
      =
    (currentActionableScheduledPressure?
        scheduled terminals events roles routing measure observedAt endExclusive).map
      (fun rows => (rows.map (fun row => row.quantity.quanta)).sum) := by
  unfold currentScheduledCommitment? currentActionableScheduledPressure?
  cases hpartition : currentScheduledPressurePartition?
      scheduled terminals events roles routing measure observedAt endExclusive with
  | none => rfl
  | some partition =>
      simp only [Option.map_some]
      simpa [ScheduledPressurePartition.commitmentFor] using
        ScheduledPressurePartition.actionablePressure_eq_rows_sum partition

/--
Compose correction-aware Actual Remaining with current-open Scheduled pressure.
Only managed pressure for the queried Purpose is subtracted from Remaining;
other pressure and unresolved eligibility stay visible in the answer.
-/
def headroomAtCorrectionFrontier?
    (capacityMovements : List CapacityMovement)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory Time)
    (actualRouting : RoutingHistory LocusId Time)
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (roles : AccountingRoleMap)
    (scheduledRouting : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option HeadroomView := do
  let remaining ←
    remainingAtCorrectionFrontier?
      capacityMovements events corrections validities actualRouting purpose measure
  let commitment ←
    currentScheduledCommitment?
      scheduled terminals events roles scheduledRouting purpose measure
      observedAt endExclusive
  return {
    remaining := remaining
    commitment := commitment.managed
    headroom := Quantity.ofQuanta (remaining.quanta - commitment.managed.quanta)
    unmanagedCommitment := commitment.unmanaged
    unroutedCommitment := commitment.unrouted
    unresolvedEligibility := commitment.unresolvedEligibility
  }

end Loam.Application
