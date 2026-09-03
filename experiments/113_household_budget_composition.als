module experiments/observation_113_household_budget_composition

sig Purpose {}

abstract sig QuantityFact {
  purpose: one Purpose,
  amount: one Int
}

sig CapacityFact extends QuantityFact {}
sig ActualFact extends QuantityFact {}
sig ScheduledFact extends QuantityFact {}

sig Completion {
  scheduledFact: one ScheduledFact,
  actualFact: one ActualFact
}

sig Retirement {
  retired: one ScheduledFact
}

sig World {
  capacities: set CapacityFact,
  actuals: set ActualFact,
  scheduled: set ScheduledFact,
  completions: set Completion,
  retirements: set Retirement,

  // Deliberately competing candidate: separately retained reservation state.
  // Projection-only LOAM does not need this field.
  reservations: set ScheduledFact
}

one sig Before, After, Left, Right extends World {}

fact PositiveSmallAmounts {
  all q: QuantityFact |
    q.amount > 0 and q.amount <= 3
}

fact WorldReferencesAreVisible {
  all w: World | {
    w.completions.scheduledFact in w.scheduled
    w.completions.actualFact in w.actuals
    w.retirements.retired in w.scheduled
    w.reservations in w.scheduled
  }
}

fact TerminalEvidenceIsUnambiguousPerWorld {
  all w: World, s: ScheduledFact | {
    lone { c: w.completions | c.scheduledFact = s }
    lone { r: w.retirements | r.retired = s }
  }

  all w: World, a: ActualFact |
    lone { c: w.completions | c.actualFact = a }

  all w: World |
    no (w.completions.scheduledFact & w.retirements.retired)
}

fun openScheduled[w: World]: set ScheduledFact {
  w.scheduled - w.completions.scheduledFact - w.retirements.retired
}

fun amountAt[qs: set QuantityFact, p: Purpose]: one Int {
  sum q: { q: qs | q.purpose = p } | q.amount
}

fun entitlement[w: World, p: Purpose]: one Int {
  amountAt[w.capacities, p]
}

fun consumption[w: World, p: Purpose]: one Int {
  amountAt[w.actuals, p]
}

fun commitment[w: World, p: Purpose]: one Int {
  amountAt[openScheduled[w], p]
}

fun remaining[w: World, p: Purpose]: one Int {
  sub[entitlement[w, p], consumption[w, p]]
}

fun headroom[w: World, p: Purpose]: one Int {
  sub[remaining[w, p], commitment[w, p]]
}

fun reservationCommitment[w: World, p: Purpose]: one Int {
  amountAt[w.reservations, p]
}

fun reservationHeadroom[w: World, p: Purpose]: one Int {
  sub[remaining[w, p], reservationCommitment[w, p]]
}

pred sameHouseholdEvidence[a, b: World] {
  a.capacities = b.capacities
  a.actuals = b.actuals
  a.scheduled = b.scheduled
  a.completions = b.completions
  a.retirements = b.retirements
}

pred completionTransition[
    p: Purpose,
    s: ScheduledFact,
    a: ActualFact,
    c: Completion] {
  Before.capacities = After.capacities
  some Before.capacities
  all cap: Before.capacities | cap.purpose = p

  no Before.actuals
  After.actuals = a

  Before.scheduled = s
  After.scheduled = s

  no Before.completions
  After.completions = c

  no Before.retirements
  no After.retirements
  no Before.reservations
  no After.reservations

  s.purpose = p
  a.purpose = p
  c.scheduledFact = s
  c.actualFact = a
}

pred equalCompletionWitness {
  some p: Purpose, s: ScheduledFact, a: ActualFact, c: Completion |
    completionTransition[p, s, a, c] and
    s.amount = a.amount
}

pred underActualCompletionWitness {
  some p: Purpose, s: ScheduledFact, a: ActualFact, c: Completion |
    completionTransition[p, s, a, c] and
    a.amount < s.amount
}

pred overActualCompletionWitness {
  some p: Purpose, s: ScheduledFact, a: ActualFact, c: Completion |
    completionTransition[p, s, a, c] and
    a.amount > s.amount
}

pred cancellationTransition[
    p: Purpose,
    s: ScheduledFact,
    r: Retirement] {
  Before.capacities = After.capacities
  some Before.capacities
  all cap: Before.capacities | cap.purpose = p

  Before.actuals = After.actuals
  no Before.actuals

  Before.scheduled = s
  After.scheduled = s

  no Before.completions
  no After.completions

  no Before.retirements
  After.retirements = r
  r.retired = s

  no Before.reservations
  no After.reservations
  s.purpose = p
}

pred cancellationWitness {
  some p: Purpose, s: ScheduledFact, r: Retirement |
    cancellationTransition[p, s, r]
}

pred scheduledChangesHeadroomWithoutChangingRemaining {
  some p: Purpose, s: ScheduledFact | {
    Left.capacities = Right.capacities
    some Left.capacities
    all cap: Left.capacities | cap.purpose = p

    Left.actuals = Right.actuals
    no Left.actuals

    no Left.scheduled
    Right.scheduled = s
    s.purpose = p

    no Left.completions
    no Right.completions
    no Left.retirements
    no Right.retirements
    no Left.reservations
    no Right.reservations

    remaining[Left, p] = remaining[Right, p]
    headroom[Left, p] != headroom[Right, p]
  }
}

pred actualChangesRemainingWithoutChangingEntitlement {
  some p: Purpose, a: ActualFact | {
    Left.capacities = Right.capacities
    some Left.capacities
    all cap: Left.capacities | cap.purpose = p

    no Left.actuals
    Right.actuals = a
    a.purpose = p

    no Left.scheduled
    no Right.scheduled
    no Left.completions
    no Right.completions
    no Left.retirements
    no Right.retirements
    no Left.reservations
    no Right.reservations

    entitlement[Left, p] = entitlement[Right, p]
    remaining[Left, p] != remaining[Right, p]
  }
}

pred reservationDriftWitness {
  some p: Purpose, s: ScheduledFact | {
    sameHouseholdEvidence[Left, Right]

    Left.scheduled = s
    s.purpose = p
    no Left.actuals
    no Left.completions
    no Left.retirements

    no Left.reservations
    Right.reservations = s

    headroom[Left, p] = headroom[Right, p]
    reservationHeadroom[Left, p] != reservationHeadroom[Right, p]
  }
}

assert CapacityAloneDeterminesEntitlement {
  all a, b: World, p: Purpose |
    a.capacities = b.capacities
    implies entitlement[a, p] = entitlement[b, p]
}

assert CapacityAndActualDetermineRemaining {
  all a, b: World, p: Purpose |
    (a.capacities = b.capacities and a.actuals = b.actuals)
    implies remaining[a, p] = remaining[b, p]
}

assert CompletionHeadroomDeltaMatchesExpectedMinusActual {
  all p: Purpose, s: ScheduledFact, a: ActualFact, c: Completion |
    completionTransition[p, s, a, c]
    implies
      sub[headroom[After, p], headroom[Before, p]] =
        sub[s.amount, a.amount]
}

assert CancellationPreservesRemaining {
  all p: Purpose, s: ScheduledFact, r: Retirement |
    cancellationTransition[p, s, r]
    implies remaining[After, p] = remaining[Before, p]
}

assert CancellationReleasesCommitmentIntoHeadroom {
  all p: Purpose, s: ScheduledFact, r: Retirement |
    cancellationTransition[p, s, r]
    implies
      sub[headroom[After, p], headroom[Before, p]] = s.amount
}

assert HouseholdEvidenceDeterminesDerivedHeadroom {
  all a, b: World, p: Purpose |
    sameHouseholdEvidence[a, b]
    implies headroom[a, p] = headroom[b, p]
}

assert HouseholdEvidenceDeterminesReservationHeadroom {
  all a, b: World, p: Purpose |
    sameHouseholdEvidence[a, b]
    implies reservationHeadroom[a, p] = reservationHeadroom[b, p]
}

assert MirroredReservationAddsNoInformation {
  all w: World, p: Purpose |
    w.reservations = openScheduled[w]
    implies reservationHeadroom[w, p] = headroom[w, p]
}

run equalCompletionWitness for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
run underActualCompletionWitness for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
run overActualCompletionWitness for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
run cancellationWitness for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
run scheduledChangesHeadroomWithoutChangingRemaining for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
run actualChangesRemainingWithoutChangingEntitlement for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
run reservationDriftWitness for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World

check CapacityAloneDeterminesEntitlement for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check CapacityAndActualDetermineRemaining for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check CompletionHeadroomDeltaMatchesExpectedMinusActual for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check CancellationPreservesRemaining for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check CancellationReleasesCommitmentIntoHeadroom for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check HouseholdEvidenceDeterminesDerivedHeadroom for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check HouseholdEvidenceDeterminesReservationHeadroom for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
check MirroredReservationAddsNoInformation for 4 but exactly 1 Purpose, exactly 1 CapacityFact, exactly 1 ActualFact, exactly 1 ScheduledFact, exactly 1 Completion, exactly 1 Retirement, exactly 4 World
