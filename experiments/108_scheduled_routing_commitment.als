module experiments/observation_108_scheduled_routing_commitment

open util/ordering[Day] as ord

sig Day {}
sig Purpose {}
sig Unit {}

sig Scheduled {
  due: one Day
}

sig Claim {
  scheduled: one Scheduled,
  units: some Unit
}

sig TerminalEvidence {
  scheduled: one Scheduled,
  knownOn: one Day
}

sig RoutingEvidence {
  claim: one Claim,
  effectiveOn: one Day,
  purpose: lone Purpose
}

sig World {
  terminals: set TerminalEvidence,
  routes: set RoutingEvidence
}

one sig Left, Right extends World {}

fact ClaimUnitOwnership {
  all u: Unit | one c: Claim | u in c.units
  all s: Scheduled | some c: Claim | c.scheduled = s
}

fact OneTerminalPerScheduledDay {
  all w: World, s: Scheduled, d: Day |
    lone { t: w.terminals | t.scheduled = s and t.knownOn = d }
}

fact OneRoutePerClaimDay {
  all w: World, c: Claim, d: Day |
    lone { r: w.routes | r.claim = c and r.effectiveOn = d }
}

fun present: one Day {
  ord/next[ord/next[ord/first]]
}

pred inCommitmentHorizon[s: Scheduled] {
  ord/lt[s.due, ord/last]
}

fun visibleTerminals[w: World, s: Scheduled, d: Day]: set TerminalEvidence {
  { t: w.terminals |
    t.scheduled = s and
    t.knownOn in d.*(ord/prev)
  }
}

pred openAt[w: World, s: Scheduled, d: Day] {
  no visibleTerminals[w, s, d]
}

fun visibleRoutes[w: World, c: Claim, d: Day]: set RoutingEvidence {
  { r: w.routes |
    r.claim = c and
    r.effectiveOn in d.*(ord/prev)
  }
}

fun latestRoute[w: World, c: Claim, d: Day]: lone RoutingEvidence {
  { r: visibleRoutes[w, c, d] |
    no newer: visibleRoutes[w, c, d] - r |
      newer.effectiveOn in r.effectiveOn.^(ord/next)
  }
}

fun routedPurposeAt[w: World, c: Claim, d: Day]: lone Purpose {
  { p: Purpose |
    some r: latestRoute[w, c, d] |
      p in r.purpose
  }
}

fun candidateUnitsAt[w: World, d: Day]: set Unit {
  { u: Unit |
    some c: Claim |
      u in c.units and
      inCommitmentHorizon[c.scheduled] and
      openAt[w, c.scheduled, d]
  }
}

fun managedCommitmentAt[w: World, d: Day]: Unit -> Purpose {
  { u: Unit, p: Purpose |
    some c: Claim |
      u in c.units and
      inCommitmentHorizon[c.scheduled] and
      openAt[w, c.scheduled, d] and
      p in routedPurposeAt[w, c, d]
  }
}

fun managedUnitsAt[w: World, d: Day]: set Unit {
  { u: Unit | some u.(managedCommitmentAt[w, d]) }
}

fun unmanagedCommitmentAt[w: World, d: Day]: set Unit {
  { u: Unit |
    some c: Claim |
      u in c.units and
      inCommitmentHorizon[c.scheduled] and
      openAt[w, c.scheduled, d] and
      some r: latestRoute[w, c, d] |
        no r.purpose
  }
}

fun unroutedCommitmentAt[w: World, d: Day]: set Unit {
  { u: Unit |
    some c: Claim |
      u in c.units and
      inCommitmentHorizon[c.scheduled] and
      openAt[w, c.scheduled, d] and
      no latestRoute[w, c, d]
  }
}

pred representativeCommitmentView {
  some managedUnitsAt[Left, present]
  some unmanagedCommitmentAt[Left, present]
  some unroutedCommitmentAt[Left, present]

  some c: Claim |
    ord/lt[c.scheduled.due, present] and
    c.units in candidateUnitsAt[Left, present]
}

pred lifecycleDifferenceChangesCommitment {
  Left.routes = Right.routes

  some s: Scheduled, c: Claim, u: Unit, p: Purpose | {
    c.scheduled = s
    u in c.units
    u->p in managedCommitmentAt[Left, present]
    u->p not in managedCommitmentAt[Right, present]
  }
}

pred routingDifferenceChangesCommitment {
  Left.terminals = Right.terminals

  some u: Unit |
    u in managedUnitsAt[Left, present] and
    u not in managedUnitsAt[Right, present]
  or
  some u: Unit |
    u in unmanagedCommitmentAt[Left, present] and
    u not in unmanagedCommitmentAt[Right, present]
  or
  some u: Unit |
    u in unroutedCommitmentAt[Left, present] and
    u not in unroutedCommitmentAt[Right, present]
}

pred lateTerminalDoesNotRewriteEarlierCommitment {
  some s: Scheduled, c: Claim, u: Unit, p: Purpose, t: TerminalEvidence | {
    c.scheduled = s
    u in c.units
    t in Left.terminals
    t.scheduled = s
    ord/lt[present, t.knownOn]
    u->p in managedCommitmentAt[Left, present]
    u->p not in managedCommitmentAt[Left, ord/last]
  }
}

pred overdueOpenStillCommits {
  some s: Scheduled, c: Claim, u: Unit, p: Purpose | {
    c.scheduled = s
    u in c.units
    ord/lt[s.due, present]
    openAt[Left, s, present]
    u->p in managedCommitmentAt[Left, present]
  }
}

pred endExclusiveHorizonExcludesScheduledClaim {
  some s: Scheduled, c: Claim | {
    c.scheduled = s
    s.due = ord/last
    openAt[Left, s, present]
    no c.units & candidateUnitsAt[Left, present]
  }
}

assert ScheduledLifecycleWithoutRoutingDeterminesCommitment {
  Left.terminals = Right.terminals
  implies
  all d: Day | {
    managedCommitmentAt[Left, d] = managedCommitmentAt[Right, d]
    unmanagedCommitmentAt[Left, d] = unmanagedCommitmentAt[Right, d]
    unroutedCommitmentAt[Left, d] = unroutedCommitmentAt[Right, d]
  }
}

assert ScheduledRoutingWithoutLifecycleDeterminesCommitment {
  Left.routes = Right.routes
  implies
  all d: Day | {
    managedCommitmentAt[Left, d] = managedCommitmentAt[Right, d]
    unmanagedCommitmentAt[Left, d] = unmanagedCommitmentAt[Right, d]
    unroutedCommitmentAt[Left, d] = unroutedCommitmentAt[Right, d]
  }
}

assert ScheduledLifecycleAndRoutingDetermineCommitment {
  Left.terminals = Right.terminals and Left.routes = Right.routes
  implies
  all d: Day | {
    managedCommitmentAt[Left, d] = managedCommitmentAt[Right, d]
    unmanagedCommitmentAt[Left, d] = unmanagedCommitmentAt[Right, d]
    unroutedCommitmentAt[Left, d] = unroutedCommitmentAt[Right, d]
  }
}

assert CommitmentPartitionsOpenHorizonClaims {
  all w: World, d: Day | {
    candidateUnitsAt[w, d] =
      managedUnitsAt[w, d] +
      unmanagedCommitmentAt[w, d] +
      unroutedCommitmentAt[w, d]

    no managedUnitsAt[w, d] & unmanagedCommitmentAt[w, d]
    no managedUnitsAt[w, d] & unroutedCommitmentAt[w, d]
    no unmanagedCommitmentAt[w, d] & unroutedCommitmentAt[w, d]
  }
}

assert PeriodEndExclusiveNeverCommits {
  all w: World, d: Day, s: Scheduled |
    s.due = ord/last
    implies
    no c: Claim |
      c.scheduled = s and
      some c.units & candidateUnitsAt[w, d]
}

run representativeCommitmentView for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
run lifecycleDifferenceChangesCommitment for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
run routingDifferenceChangesCommitment for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
run lateTerminalDoesNotRewriteEarlierCommitment for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
run overdueOpenStillCommits for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
run endExclusiveHorizonExcludesScheduledClaim for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
check ScheduledLifecycleWithoutRoutingDeterminesCommitment for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
check ScheduledRoutingWithoutLifecycleDeterminesCommitment for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
check ScheduledLifecycleAndRoutingDetermineCommitment for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
check CommitmentPartitionsOpenHorizonClaims for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
check PeriodEndExclusiveNeverCommits for exactly 5 Day, exactly 3 Purpose, exactly 4 Scheduled, exactly 5 Claim, exactly 8 Unit, exactly 4 TerminalEvidence, exactly 8 RoutingEvidence, exactly 2 World
