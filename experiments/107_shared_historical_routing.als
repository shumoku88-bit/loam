module experiments/observation_107_shared_historical_routing

open util/ordering[Day] as ord

sig Day {}
sig Subject {}
sig Purpose {}

abstract sig SubjectKind {}
one sig ActualKind, ScheduledKind extends SubjectKind {}

sig RoutingEvidence {
  subject: one Subject,
  effectiveOn: one Day,
  purpose: lone Purpose
}

sig World {
  routes: set RoutingEvidence,
  kindOf: Subject -> one SubjectKind
}

one sig Left, Right extends World {}

fact OneRoutingEvidencePerSubjectDay {
  all w: World, s: Subject, d: Day |
    lone { r: w.routes | r.subject = s and r.effectiveOn = d }
}

fun visibleRoutes[w: World, s: Subject, d: Day]: set RoutingEvidence {
  { r: w.routes |
    r.subject = s and
    r.effectiveOn in d.*(ord/prev)
  }
}

fun latestRoute[w: World, s: Subject, d: Day]: lone RoutingEvidence {
  { r: visibleRoutes[w, s, d] |
    no newer: visibleRoutes[w, s, d] - r |
      newer.effectiveOn in r.effectiveOn.^(ord/next)
  }
}

fun routedPurposeAt[w: World, s: Subject, d: Day]: lone Purpose {
  { p: Purpose |
    some r: latestRoute[w, s, d] |
      p in r.purpose
  }
}

fun routedAt[w: World, d: Day]: Subject -> Purpose {
  { s: Subject, p: Purpose |
    p in routedPurposeAt[w, s, d]
  }
}

fun actualSubjects[w: World]: set Subject {
  { s: Subject | s->ActualKind in w.kindOf }
}

fun scheduledSubjects[w: World]: set Subject {
  { s: Subject | s->ScheduledKind in w.kindOf }
}

fun actualRoutingAt[w: World, d: Day]: Subject -> Purpose {
  routedAt[w, d] & (actualSubjects[w] -> Purpose)
}

fun scheduledRoutingAt[w: World, d: Day]: Subject -> Purpose {
  routedAt[w, d] & (scheduledSubjects[w] -> Purpose)
}

pred representativeSharedHistory {
  some a: actualSubjects[Left] | some a.(actualRoutingAt[Left, ord/last])
  some s: scheduledSubjects[Left] | some s.(scheduledRoutingAt[Left, ord/last])

  some s: Subject, d1, d2: Day | {
    ord/lt[d1, d2]
    routedPurposeAt[Left, s, d1] != routedPurposeAt[Left, s, d2]
  }
}

pred sameCurrentRoutingDifferentHistory {
  Left.kindOf = Right.kindOf
  routedAt[Left, ord/last] = routedAt[Right, ord/last]

  some d: Day - ord/last |
    routedAt[Left, d] != routedAt[Right, d]
}

pred sameRoutingEvidenceDifferentSubjectMeaning {
  Left.routes = Right.routes
  Left.kindOf != Right.kindOf

  actualRoutingAt[Left, ord/last] != actualRoutingAt[Right, ord/last]
  or
  scheduledRoutingAt[Left, ord/last] != scheduledRoutingAt[Right, ord/last]
}

pred managedThenExplicitlyUnmanaged {
  some s: Subject, earlierDay, laterDay: Day | {
    ord/lt[earlierDay, laterDay]
    some routedPurposeAt[Left, s, earlierDay]
    no routedPurposeAt[Left, s, laterDay]
    some r: latestRoute[Left, s, laterDay] | no r.purpose
  }
}

assert CurrentRoutingDeterminesHistoricalRouting {
  routedAt[Left, ord/last] = routedAt[Right, ord/last]
  implies
  all d: Day | routedAt[Left, d] = routedAt[Right, d]
}

assert SharedRoutingEvidenceDeterminesTypedAnswersWithoutSubjectKind {
  Left.routes = Right.routes
  implies
  all d: Day | {
    actualRoutingAt[Left, d] = actualRoutingAt[Right, d]
    scheduledRoutingAt[Left, d] = scheduledRoutingAt[Right, d]
  }
}

assert ExplicitHistoryAndSubjectKindDetermineTypedAnswers {
  Left.routes = Right.routes and Left.kindOf = Right.kindOf
  implies
  all d: Day | {
    routedAt[Left, d] = routedAt[Right, d]
    actualRoutingAt[Left, d] = actualRoutingAt[Right, d]
    scheduledRoutingAt[Left, d] = scheduledRoutingAt[Right, d]
  }
}

assert LatestRouteIsUnique {
  all w: World, s: Subject, d: Day |
    lone latestRoute[w, s, d]
}

run representativeSharedHistory for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
run sameCurrentRoutingDifferentHistory for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
run sameRoutingEvidenceDifferentSubjectMeaning for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
run managedThenExplicitlyUnmanaged for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
check CurrentRoutingDeterminesHistoricalRouting for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
check SharedRoutingEvidenceDeterminesTypedAnswersWithoutSubjectKind for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
check ExplicitHistoryAndSubjectKindDetermineTypedAnswers for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
check LatestRouteIsUnique for exactly 4 Day, exactly 3 Subject, exactly 2 Purpose, exactly 6 RoutingEvidence, exactly 2 World
