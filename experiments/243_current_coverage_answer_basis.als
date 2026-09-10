module experiments/observation_243_current_coverage_answer_basis

-- Observation 243: current coverage answer basis
--
-- Reduce the production CurrentCoverage composition to the information
-- dimensions that can affect one queried Purpose/Measure answer.  This model
-- deliberately does not mirror files or current Core type boundaries.
--
-- It asks two different questions:
--   1. what determines the full current production answer, including visible
--      unmanaged/unrouted/unresolved pressure;
--   2. what would determine only a narrower scalar such as Headroom.
--
-- The difference demonstrates why canonical minimality must be relative to the
-- answer vocabulary we choose to preserve.

abstract sig Flag {}
one sig Yes, No extends Flag {}

abstract sig ScheduledClass {}
one sig ManagedForPurpose,
        ManagedForOtherPurpose,
        Unmanaged,
        UnroutedPressure,
        ResolvedNonPressure,
        UnresolvedEligibility extends ScheduledClass {}

sig World {
  capacityAmount: one Int,
  capacityInElapsedWindow: one Flag,

  actualAmount: one Int,
  actualIsCurrent: one Flag,
  actualInElapsedWindow: one Flag,
  actualRoutedToPurpose: one Flag,

  scheduledAmount: one Int,
  scheduledIsOpen: one Flag,
  scheduledInFutureHorizon: one Flag,
  scheduledClass: one ScheduledClass
}

one sig Left, Right extends World {}

fact SmallNonnegativeAmounts {
  all w: World | {
    w.capacityAmount >= 0
    w.capacityAmount <= 6
    w.actualAmount >= 0
    w.actualAmount <= 6
    w.scheduledAmount >= 0
    w.scheduledAmount <= 6
  }
}

fun entitlement[w: World]: one Int {
  (w.capacityInElapsedWindow = Yes) => w.capacityAmount else 0
}

fun consumption[w: World]: one Int {
  (w.actualIsCurrent = Yes and
   w.actualInElapsedWindow = Yes and
   w.actualRoutedToPurpose = Yes) => w.actualAmount else 0
}

fun selectedScheduled[w: World]: one Int {
  (w.scheduledIsOpen = Yes and
   w.scheduledInFutureHorizon = Yes) => w.scheduledAmount else 0
}

fun managedCommitment[w: World]: one Int {
  (w.scheduledClass = ManagedForPurpose) => selectedScheduled[w] else 0
}

fun unmanagedCommitment[w: World]: one Int {
  (w.scheduledClass = Unmanaged) => selectedScheduled[w] else 0
}

fun unroutedCommitment[w: World]: one Int {
  (w.scheduledClass = UnroutedPressure) => selectedScheduled[w] else 0
}

fun unresolvedEligibility[w: World]: one Int {
  (w.scheduledClass = UnresolvedEligibility) => selectedScheduled[w] else 0
}

fun remaining[w: World]: one Int {
  sub[entitlement[w], consumption[w]]
}

fun headroom[w: World]: one Int {
  sub[remaining[w], managedCommitment[w]]
}

pred sameFullCoverageAnswer[a, b: World] {
  entitlement[a] = entitlement[b]
  consumption[a] = consumption[b]
  remaining[a] = remaining[b]
  managedCommitment[a] = managedCommitment[b]
  headroom[a] = headroom[b]
  unmanagedCommitment[a] = unmanagedCommitment[b]
  unroutedCommitment[a] = unroutedCommitment[b]
  unresolvedEligibility[a] = unresolvedEligibility[b]
}

pred samePrimitiveCoverageState[a, b: World] {
  a.capacityAmount = b.capacityAmount
  a.capacityInElapsedWindow = b.capacityInElapsedWindow
  a.actualAmount = b.actualAmount
  a.actualIsCurrent = b.actualIsCurrent
  a.actualInElapsedWindow = b.actualInElapsedWindow
  a.actualRoutedToPurpose = b.actualRoutedToPurpose
  a.scheduledAmount = b.scheduledAmount
  a.scheduledIsOpen = b.scheduledIsOpen
  a.scheduledInFutureHorizon = b.scheduledInFutureHorizon
  a.scheduledClass = b.scheduledClass
}

pred sameExceptCapacityWindow[a, b: World] {
  a.capacityAmount = b.capacityAmount
  a.actualAmount = b.actualAmount
  a.actualIsCurrent = b.actualIsCurrent
  a.actualInElapsedWindow = b.actualInElapsedWindow
  a.actualRoutedToPurpose = b.actualRoutedToPurpose
  a.scheduledAmount = b.scheduledAmount
  a.scheduledIsOpen = b.scheduledIsOpen
  a.scheduledInFutureHorizon = b.scheduledInFutureHorizon
  a.scheduledClass = b.scheduledClass
}

pred sameExceptActualRouting[a, b: World] {
  a.capacityAmount = b.capacityAmount
  a.capacityInElapsedWindow = b.capacityInElapsedWindow
  a.actualAmount = b.actualAmount
  a.actualIsCurrent = b.actualIsCurrent
  a.actualInElapsedWindow = b.actualInElapsedWindow
  a.scheduledAmount = b.scheduledAmount
  a.scheduledIsOpen = b.scheduledIsOpen
  a.scheduledInFutureHorizon = b.scheduledInFutureHorizon
  a.scheduledClass = b.scheduledClass
}

pred sameExceptScheduledOpen[a, b: World] {
  a.capacityAmount = b.capacityAmount
  a.capacityInElapsedWindow = b.capacityInElapsedWindow
  a.actualAmount = b.actualAmount
  a.actualIsCurrent = b.actualIsCurrent
  a.actualInElapsedWindow = b.actualInElapsedWindow
  a.actualRoutedToPurpose = b.actualRoutedToPurpose
  a.scheduledAmount = b.scheduledAmount
  a.scheduledInFutureHorizon = b.scheduledInFutureHorizon
  a.scheduledClass = b.scheduledClass
}

pred capacityEffectivePlacementIsObservable {
  sameExceptCapacityWindow[Left, Right]
  Left.capacityAmount > 0
  Left.capacityInElapsedWindow = Yes
  Right.capacityInElapsedWindow = No
  not sameFullCoverageAnswer[Left, Right]
}

pred actualPurposeRoutingIsObservable {
  sameExceptActualRouting[Left, Right]
  Left.actualAmount > 0
  Left.actualIsCurrent = Yes
  Left.actualInElapsedWindow = Yes
  Left.actualRoutedToPurpose = Yes
  Right.actualRoutedToPurpose = No
  not sameFullCoverageAnswer[Left, Right]
}

pred scheduledOpenStateIsObservable {
  sameExceptScheduledOpen[Left, Right]
  Left.scheduledAmount > 0
  Left.scheduledInFutureHorizon = Yes
  Left.scheduledClass = ManagedForPurpose
  Left.scheduledIsOpen = Yes
  Right.scheduledIsOpen = No
  not sameFullCoverageAnswer[Left, Right]
}

-- Both worlds have the same managed Commitment and therefore the same Headroom,
-- but the full current product answer distinguishes unmanaged from unrouted
-- pressure.  If LOAM wanted only one scalar Headroom answer, this distinction
-- would not be required by that narrower vocabulary.
pred sameHeadroomDifferentVisibleFrontier {
  Left.capacityAmount = Right.capacityAmount
  Left.capacityInElapsedWindow = Right.capacityInElapsedWindow
  Left.actualAmount = Right.actualAmount
  Left.actualIsCurrent = Right.actualIsCurrent
  Left.actualInElapsedWindow = Right.actualInElapsedWindow
  Left.actualRoutedToPurpose = Right.actualRoutedToPurpose
  Left.scheduledAmount = Right.scheduledAmount
  Left.scheduledAmount > 0
  Left.scheduledIsOpen = Yes
  Right.scheduledIsOpen = Yes
  Left.scheduledInFutureHorizon = Yes
  Right.scheduledInFutureHorizon = Yes
  Left.scheduledClass = Unmanaged
  Right.scheduledClass = UnroutedPressure
  headroom[Left] = headroom[Right]
  not sameFullCoverageAnswer[Left, Right]
}

-- A second query-relative witness: unresolved eligibility can be invisible to
-- Headroom while remaining explicitly visible in the current full answer.
pred sameHeadroomResolvedVsUnresolved {
  Left.capacityAmount = Right.capacityAmount
  Left.capacityInElapsedWindow = Right.capacityInElapsedWindow
  Left.actualAmount = Right.actualAmount
  Left.actualIsCurrent = Right.actualIsCurrent
  Left.actualInElapsedWindow = Right.actualInElapsedWindow
  Left.actualRoutedToPurpose = Right.actualRoutedToPurpose
  Left.scheduledAmount = Right.scheduledAmount
  Left.scheduledAmount > 0
  Left.scheduledIsOpen = Yes
  Right.scheduledIsOpen = Yes
  Left.scheduledInFutureHorizon = Yes
  Right.scheduledInFutureHorizon = Yes
  Left.scheduledClass = ResolvedNonPressure
  Right.scheduledClass = UnresolvedEligibility
  headroom[Left] = headroom[Right]
  not sameFullCoverageAnswer[Left, Right]
}

assert PrimitiveCoverageStateDeterminesFullAnswer {
  all a, b: World |
    samePrimitiveCoverageState[a, b] implies sameFullCoverageAnswer[a, b]
}

-- Deliberately too strong.  The current answer exposes more information than
-- Headroom, so equal Headroom must not be treated as sufficient reconstruction.
assert HeadroomDeterminesFullCoverageAnswer {
  all a, b: World |
    headroom[a] = headroom[b] implies sameFullCoverageAnswer[a, b]
}

run capacityEffectivePlacementIsObservable for exactly 2 World, 5 Int
run actualPurposeRoutingIsObservable for exactly 2 World, 5 Int
run scheduledOpenStateIsObservable for exactly 2 World, 5 Int
run sameHeadroomDifferentVisibleFrontier for exactly 2 World, 5 Int
run sameHeadroomResolvedVsUnresolved for exactly 2 World, 5 Int
check PrimitiveCoverageStateDeterminesFullAnswer for exactly 2 World, 5 Int
check HeadroomDeterminesFullCoverageAnswer for exactly 2 World, 5 Int
