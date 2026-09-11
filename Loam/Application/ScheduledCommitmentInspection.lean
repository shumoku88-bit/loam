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
-/

/--
Query-local Scheduled Capacity-pressure partition for one Purpose and Measure.

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

private structure CommitmentQuanta where
  managed : Int := 0
  unmanaged : Int := 0
  unrouted : Int := 0
  unresolvedEligibility : Int := 0

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
raw-change dedup at one Locus are selected only here; the aggregate Commitment
view and the subject-level unresolved rows share this enumeration so neither
reimplements the selection conditions.
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

/--
Add one selected coordinate to the aggregate partition. Only managed pressure
routed to the queried Purpose counts as that Purpose's Commitment; every other
partition stays visible without being guessed into managed pressure.
-/
private def addSelectedCoordinate
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (observedAt : Time)
    (total : CommitmentQuanta)
    (coordinate : SelectedCoordinate Time) : CommitmentQuanta :=
  match classifyScheduledPressure roles routing observedAt coordinate.subject with
  | .managed routedPurpose =>
      if routedPurpose = purpose then
        { total with managed := total.managed + coordinate.quantity.quanta }
      else
        total
  | .unmanaged =>
      { total with unmanaged := total.unmanaged + coordinate.quantity.quanta }
  | .unroutedPressure =>
      { total with unrouted := total.unrouted + coordinate.quantity.quanta }
  | .resolvedNonPressure =>
      total
  | .unresolvedEligibility =>
      { total with
          unresolvedEligibility := total.unresolvedEligibility + coordinate.quantity.quanta }

/-- Keep exactly the unresolved-eligibility coordinates as actionable rows. -/
private def unresolvedRow?
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (observedAt : Time)
    (coordinate : SelectedCoordinate Time) :
    Option (UnresolvedScheduledPressureRow Time) :=
  match classifyScheduledPressure roles routing observedAt coordinate.subject with
  | .unresolvedEligibility =>
      some {
        subject := coordinate.subject
        scheduledOn := coordinate.scheduledOn
        measure := coordinate.measure
        quantity := coordinate.quantity }
  | _ => none

private def commitmentFromOpenOccurrences
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : ScheduledCommitmentView :=
  let coordinates :=
    occurrences.flatMap (selectedCoordinates measure observedAt endExclusive)
  let total := coordinates.foldl
    (addSelectedCoordinate roles routing purpose observedAt)
    {}
  {
    managed := Quantity.ofQuanta total.managed
    unmanaged := Quantity.ofQuanta total.unmanaged
    unrouted := Quantity.ofQuanta total.unrouted
    unresolvedEligibility := Quantity.ofQuanta total.unresolvedEligibility
  }

/--
Project the actionable unresolved-pressure subjects behind one current-open
Scheduled set.

Each retained row is one aggregated `ScheduledId × LocusId` coordinate selected
by the shared classification. Occurrence and Locus enumeration order is
preserved; list position carries no priority meaning.
-/
def unresolvedScheduledPressureRowsFromOpen
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : List (UnresolvedScheduledPressureRow Time) :=
  (occurrences.flatMap (selectedCoordinates measure observedAt endExclusive)).filterMap
    (unresolvedRow? roles routing observedAt)

/--
The subject rows and the aggregate frontier are one semantics: over any shared
coordinate selection, unresolved row quantities sum exactly onto the aggregate
unresolved eligibility, for any queried Purpose and any starting accumulator.
-/
private theorem fold_unresolvedEligibility_eq
    (coordinates : List (SelectedCoordinate Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (observedAt : Time)
    (init : CommitmentQuanta) :
    (coordinates.foldl
        (addSelectedCoordinate roles routing purpose observedAt) init).unresolvedEligibility
      = init.unresolvedEligibility +
        ((coordinates.filterMap (unresolvedRow? roles routing observedAt)).map
          (fun row => row.quantity.quanta)).sum := by
  induction coordinates generalizing init with
  | nil => simp
  | cons coordinate rest ih =>
      simp only [List.foldl_cons, List.filterMap_cons]
      rw [ih]
      cases hclass : classifyScheduledPressure roles routing observedAt coordinate.subject with
      | managed routedPurpose =>
          by_cases h : routedPurpose = purpose
          · subst h
            simp [addSelectedCoordinate, unresolvedRow?, hclass]
          · simp [addSelectedCoordinate, unresolvedRow?, hclass, h]
      | unmanaged =>
          simp [addSelectedCoordinate, unresolvedRow?, hclass]
      | unroutedPressure =>
          simp [addSelectedCoordinate, unresolvedRow?, hclass]
      | resolvedNonPressure =>
          simp [addSelectedCoordinate, unresolvedRow?, hclass]
      | unresolvedEligibility =>
          simp [addSelectedCoordinate, unresolvedRow?, hclass, List.map_cons, List.sum_cons]
          omega

private theorem rowsFromOpen_sum_eq
    (occurrences : List (ScheduledOccurrence Time))
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) :
    ((unresolvedScheduledPressureRowsFromOpen
        occurrences roles routing measure observedAt endExclusive).map
          (fun row => row.quantity.quanta)).sum
      =
    (commitmentFromOpenOccurrences
        occurrences roles routing purpose measure observedAt endExclusive).unresolvedEligibility.quanta := by
  simp only [commitmentFromOpenOccurrences, unresolvedScheduledPressureRowsFromOpen]
  rw [fold_unresolvedEligibility_eq]
  simp

/-- Project current Scheduled Capacity pressure for one Purpose and Measure. -/
def currentScheduledCommitment?
    (scheduled : ScheduledMemory Time)
    (terminals : ScheduledTerminalMemory)
    (events : EventMemory)
    (roles : AccountingRoleMap)
    (routing : RoutingHistory ScheduledRoutingSubject Time)
    (purpose : PurposeId)
    (measure : MeasureId)
    (observedAt endExclusive : Time) : Option ScheduledCommitmentView :=
  match currentOpenScheduled scheduled terminals events with
  | .open occurrences =>
      some <| commitmentFromOpenOccurrences
        occurrences roles routing purpose measure observedAt endExclusive
  | _ => none

/--
Project the actionable unresolved-pressure subjects behind the current-open
Scheduled frontier. It shares the same lifecycle, horizon, Measure, positive
aggregation, routing status, and AccountingRole evidence as
`currentScheduledCommitment?`; only answer granularity differs.
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
  match currentOpenScheduled scheduled terminals events with
  | .open occurrences =>
      some <| unresolvedScheduledPressureRowsFromOpen
        occurrences roles routing measure observedAt endExclusive
  | _ => none

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
  cases currentOpenScheduled scheduled terminals events
  · rename_i occurrences
    simp only [Option.map_some]
    apply congrArg
    exact (rowsFromOpen_sum_eq
      occurrences roles routing purpose measure observedAt endExclusive).symm
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl

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
