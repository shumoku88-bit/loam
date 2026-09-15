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

## Design Rationale

- **Current semantics**: A query-local projection that partitions positive future Scheduled
  obligations into `managed` (routed to queried Purpose), `unmanaged`, `unrouted`, and
  `unresolvedEligibility`. It derives `Headroom = Remaining - Commitment` without storing
  any persistent budget, reservation, or headroom records.

- **Why this design**: Preserves minimal canonical evidence. Familiar household planning nouns
  (`Commitment`, `Headroom`, `Remaining`) are transient views computed on-the-fly from
  underlying facts (Capacity movements, actual events, open scheduled occurrences, routing,
  and role classification).

- **Prohibited simplifications**:
  1. *Why not all positive quantities as pressure?*: Scheduled models expected future cashflow,
     not only expenses. A scheduled pension/support receipt into a bank account is a positive
     Asset inflow. Treating all positive quantities as Capacity pressure would falsely consume
     budget headroom for incoming money.
  2. *Why not Expense only as pressure?*: A scheduled debt or loan repayment is a positive
     Liability coordinate (reducing liability). It obligates cash outflow and consumes Capacity
     just as real expenses do. Ignoring Liability drops genuine debt obligations.
  3. *Why is unresolved accounting role not equivalent to non-pressure?*: If an unrouted
     scheduled coordinate lacks an `AccountingRole`, assuming non-pressure silently hides
     unbudgeted cashflow; assuming a default role fabricates accounting evidence. It must
     remain an explicit, actionable `unresolvedEligibility` frontier.
  4. *Why not a stored CommitmentEligibility bit?*: Storing an eligibility flag on Scheduled
     records duplicates intent and creates synchronization hazards. Routing owns explicit
     pressure intent; partial `AccountingRole` serves as the qualified fallback.

- **Permanent evidence references**:
  - `theorem currentScheduledCommitment?_unresolvedEligibility_eq_rows_sum`:
    Proves that the aggregate `unresolvedEligibility` quantity matches the exact sum of
    actionable subject-level rows (`currentUnresolvedScheduledPressure?`).
  - Observations 108, 113, 153, 216-217, 227: Formalized the non-retained projection, the
    `ScheduledId × LocusId` routing subject, partial role classification, and the fail-visible
    unresolved eligibility frontier.

The production read path has one semantic engine: current-open selection and
pressure classification produce one transient `ScheduledPressurePartition`.
Commitment totals and actionable rows are projections of that partition rather
than parallel reclassifications.
-/

/--
Query-local Scheduled Capacity-pressure projection for one Purpose and Measure.

`managed` is only the amount routed to the queried Purpose. `unmanaged` and
`unrouted` retain selected pressure whose Purpose status is not managed.
`unresolvedEligibility` retains positive, unrouted quantity whose AccountingRole
is absent; it is neither silently counted as Commitment nor silently discarded.
-/
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

This is the single classification shared by the aggregate Commitment view and
the subject-level unresolved-pressure projection; neither answer reimplements
routing or AccountingRole conditions.
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

/--
One actionable unresolved-pressure coordinate behind the aggregate frontier: a
current-open, positive, unrouted `ScheduledId × LocusId` subject whose
AccountingRole evidence is missing.

This is a pure derived observation, never retained state.
-/
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

/--
Recover each represented Locus once. `BalancedMovement` may retain repeated
changes at one Locus; the routing subject qualified by Observation 153 is the
aggregated `ScheduledId × LocusId` coordinate, not an individual raw change row.
-/
private def scheduledLoci
    (occurrence : ScheduledOccurrence Time) : List LocusId :=
  occurrence.movement.changes.foldl
    (fun loci change => addLocusIfAbsent loci change.coordinate)
    []

/--
Enumerate each selected positive aggregated `ScheduledId × LocusId` coordinate
of one open occurrence exactly once.

Measure selection, the current end-exclusive horizon, positive aggregation, and
raw-change dedup at one Locus are selected only here. The classified partition
then serves aggregate Commitment and subject-level row projections alike.
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
  Quantity.ofQuanta <| partition.foldl
    (fun total row =>
      match row.pressure with
      | .managed routedPurpose =>
          if routedPurpose = purpose then total + row.quantity.quanta else total
      | _ => total)
    0

/-- Query-global pressure explicitly marked unmanaged. -/
def unmanaged (partition : ScheduledPressurePartition Time) : Quantity :=
  Quantity.ofQuanta <| partition.foldl
    (fun total row =>
      match row.pressure with
      | .unmanaged => total + row.quantity.quanta
      | _ => total)
    0

/-- Query-global unrouted pressure justified by AccountingRole. -/
def unrouted (partition : ScheduledPressurePartition Time) : Quantity :=
  Quantity.ofQuanta <|
    (partition.filterMap fun row =>
      match row.pressure with
      | .unroutedPressure => some row.quantity.quanta
      | _ => none).sum

/-- Keep exactly the unresolved-eligibility subjects, preserving partition order. -/
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

/-- Query-global unrouted pressure whose AccountingRole is still unknown. -/
def unresolvedEligibility (partition : ScheduledPressurePartition Time) : Quantity :=
  Quantity.ofQuanta <|
    (partition.unresolvedRows.map (fun row => row.quantity.quanta)).sum

/-- Actionable unrouted or unresolved subjects derived from the same partition. -/
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

end ScheduledPressurePartition

private theorem actionableRows_sum_eq
    (partition : ScheduledPressurePartition Time) :
    ((ScheduledPressurePartition.actionableRows partition).map
      (fun row => row.quantity.quanta)).sum
      =
    (ScheduledPressurePartition.unrouted partition).quanta +
      (ScheduledPressurePartition.unresolvedEligibility partition).quanta := by
  induction partition with
  | nil =>
      simp [ScheduledPressurePartition.unrouted,
        ScheduledPressurePartition.unresolvedEligibility,
        ScheduledPressurePartition.unresolvedRows,
        ScheduledPressurePartition.actionableRows]
  | cons row rest ih =>
      simp [ScheduledPressurePartition.unrouted,
        ScheduledPressurePartition.unresolvedEligibility,
        ScheduledPressurePartition.unresolvedRows,
        ScheduledPressurePartition.actionableRows] at ih
      cases hpressure : row.pressure <;>
        simp [ScheduledPressurePartition.unrouted,
          ScheduledPressurePartition.unresolvedEligibility,
          ScheduledPressurePartition.unresolvedRows,
          ScheduledPressurePartition.actionableRows, hpressure, ih] <;>
        omega

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

/--
Project current Scheduled Capacity pressure for one Purpose and Measure from the
single classified partition.
-/
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
    fun partition =>
      {
        managed := ScheduledPressurePartition.managedFor partition purpose
        unmanaged := ScheduledPressurePartition.unmanaged partition
        unrouted := ScheduledPressurePartition.unrouted partition
        unresolvedEligibility := ScheduledPressurePartition.unresolvedEligibility partition
      }

/--
The query-global unmanaged frontier of the compatibility Commitment view is
independent of the queried Purpose. The partition itself has no Purpose input.
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

/--
Project the actionable unresolved-pressure subjects behind one current-open
Scheduled set.

Each retained row is one aggregated `ScheduledId × LocusId` coordinate selected
by the shared partition. Occurrence and Locus enumeration order is preserved;
list position carries no priority meaning.
-/
def unresolvedScheduledPressureRowsFromOpen
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : List (UnresolvedScheduledPressureRow Time) :=
  ScheduledPressurePartition.unresolvedRows <|
    scheduledPressurePartitionFromOpen
      occurrences roles routing measure observedAt endExclusive

/--
Project the actionable unresolved-pressure subjects behind the current-open
Scheduled frontier. It shares lifecycle, horizon, Measure, positive aggregation,
routing status, and AccountingRole evidence with `currentScheduledCommitment?`;
only answer granularity differs.
-/
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
The retained invariant tying both granularities to the same semantics: the
unresolved subject rows and aggregate unresolved eligibility frontier fail
identically, and when justified the row quantities sum exactly to the aggregate.
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
      simp [ScheduledPressurePartition.unresolvedEligibility]

/--
Project all actionable unrouted and unresolved Scheduled pressure subjects behind
one current-open Scheduled set. Both unrouted Expense/Liability obligations and
unresolved eligibility lack an explicit route and can be assigned to a Purpose
or marked unmanaged.
-/
def actionableScheduledPressureRowsFromOpen
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : List (UnresolvedScheduledPressureRow Time) :=
  ScheduledPressurePartition.actionableRows <|
    scheduledPressurePartitionFromOpen
      occurrences roles routing measure observedAt endExclusive

/--
Project the actionable unrouted and unresolved pressure subjects behind the
current-open Scheduled frontier.
-/
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
The retained invariant tying actionable routing subjects to the unrouted and
unresolved frontier. Both sides are projections of one classified partition.
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
      exact congrArg some (actionableRows_sum_eq partition).symm

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
