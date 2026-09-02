module experiments/observation_105_scheduled_lifecycle_edge

open util/ordering[Day] as ord

sig Day {}

abstract sig Endpoint {}

sig Scheduled extends Endpoint {
  scheduledDay: one Day
}

sig Movement extends Endpoint {}

-- One generic piece of lifecycle evidence:
--
--   target = Movement   => completion / realization
--   target = Scheduled  => supersession / reschedule
--   target = none       => retirement / cancellation
--
-- knownOn records when that evidence is available to a query horizon.
sig LifecycleEdge {
  source: one Scheduled,
  target: lone Endpoint,
  knownOn: one Day
}

sig World {
  evidence: set LifecycleEdge
}

one sig Left, Right extends World {}

one sig Query {
  knownThrough: one Day,
  today: one Day,
  selectedDay: one Day
}

fun fullCompletion[w: World]: Scheduled -> Movement {
  { s: Scheduled, m: Movement |
    some e: w.evidence | e.source = s and e.target = m
  }
}

fun fullSuccessor[w: World]: Scheduled -> Scheduled {
  { s: Scheduled, n: Scheduled |
    some e: w.evidence | e.source = s and e.target = n
  }
}

fact LifecycleEvidenceIsSimple {
  -- A lifecycle edge never points back to its own scheduled occurrence.
  all e: LifecycleEdge | e.target != e.source

  -- Current pressure needs at most one terminal lifecycle edge per occurrence.
  all w: World, s: Scheduled |
    lone { e: w.evidence | e.source = s }

  -- Keep the same one-to-one completion boundary already used by Observation 063.
  all w: World, m: Movement |
    lone m.~(fullCompletion[w])

  -- A replacement occurrence has at most one predecessor in this first model.
  all w: World, n: Scheduled |
    lone n.~(fullSuccessor[w])

  -- Replacement chains are allowed, replacement cycles are not.
  all w: World |
    no iden & ^(fullSuccessor[w])

  -- A query cannot know through a day after its own "today" coordinate.
  ord/lte[Query.knownThrough, Query.today]
}

fun visibleEvidence[w: World]: set LifecycleEdge {
  { e: w.evidence | ord/lte[e.knownOn, Query.knownThrough] }
}

fun completion[w: World]: Scheduled -> Movement {
  { s: Scheduled, m: Movement |
    some e: visibleEvidence[w] | e.source = s and e.target = m
  }
}

fun retired[w: World]: set Scheduled {
  { s: Scheduled |
    some e: visibleEvidence[w] | e.source = s and no e.target
  }
}

fun successor[w: World]: Scheduled -> Scheduled {
  { s: Scheduled, n: Scheduled |
    some e: visibleEvidence[w] | e.source = s and e.target = n
  }
}

fun completed[w: World]: set Scheduled {
  { s: Scheduled | some s.(completion[w]) }
}

fun superseded[w: World]: set Scheduled {
  { s: Scheduled | some s.(successor[w]) }
}

fun terminal[w: World]: set Scheduled {
  completed[w] + retired[w] + superseded[w]
}

fun liveScheduled[w: World]: set Scheduled {
  Scheduled - terminal[w]
}

fun selectedOpen[w: World]: set Scheduled {
  { s: liveScheduled[w] | s.scheduledDay = Query.selectedDay }
}

fun overdue[w: World]: set Scheduled {
  { s: liveScheduled[w] | ord/lt[s.scheduledDay, Query.today] }
}

fun dueToday[w: World]: set Scheduled {
  { s: liveScheduled[w] | s.scheduledDay = Query.today }
}

fun upcoming[w: World]: set Scheduled {
  { s: liveScheduled[w] | ord/lt[Query.today, s.scheduledDay] }
}

fun postponed[w: World]: set Scheduled {
  { s: Scheduled |
    some n: s.(successor[w]) |
      ord/lt[s.scheduledDay, n.scheduledDay]
  }
}

fun advanced[w: World]: set Scheduled {
  { s: Scheduled |
    some n: s.(successor[w]) |
      ord/lt[n.scheduledDay, s.scheduledDay]
  }
}

fun sameDayReplacement[w: World]: set Scheduled {
  { s: Scheduled |
    some n: s.(successor[w]) |
      n.scheduledDay = s.scheduledDay
  }
}

pred representativeLifecycle {
  Query.knownThrough = Query.today

  some disj done, cancelled, old, replacement, pastOpen, futureOpen: Scheduled,
       m: Movement | {
    done->m in completion[Left]
    cancelled in retired[Left]
    old->replacement in successor[Left]
    replacement in liveScheduled[Left]
    pastOpen in overdue[Left]
    futureOpen in upcoming[Left]
  }
}

pred futureEvidenceLeavesEarlierViewOpen {
  some s: Scheduled, e: Left.evidence | {
    e.source = s
    ord/lt[Query.knownThrough, e.knownOn]
    s in liveScheduled[Left]
  }
}

pred sameOpenDifferentTerminalMeaning {
  liveScheduled[Left] = liveScheduled[Right]
  terminal[Left] = terminal[Right]
  completed[Left] != completed[Right]
    or retired[Left] != retired[Right]
    or superseded[Left] != superseded[Right]
}

pred sameKindsDifferentSuccessorProvenance {
  completed[Left] = completed[Right]
  retired[Left] = retired[Right]
  superseded[Left] = superseded[Right]
  liveScheduled[Left] = liveScheduled[Right]
  successor[Left] != successor[Right]
}

pred directionWithoutOperationKinds {
  some disj p, a: Scheduled | {
    p in postponed[Left]
    a in advanced[Left]
  }
}

assert ClosedSummaryDeterminesLifecycleMeaning {
  terminal[Left] = terminal[Right] implies {
    completed[Left] = completed[Right]
    retired[Left] = retired[Right]
    successor[Left] = successor[Right]
  }
}

assert StatusKindsDetermineSuccessorProvenance {
  completed[Left] = completed[Right] and
  retired[Left] = retired[Right] and
  superseded[Left] = superseded[Right] implies
    successor[Left] = successor[Right]
}

assert DecodedLifecycleDeterminesSelectedViews {
  completion[Left] = completion[Right] and
  retired[Left] = retired[Right] and
  successor[Left] = successor[Right] implies {
    liveScheduled[Left] = liveScheduled[Right]
    selectedOpen[Left] = selectedOpen[Right]
    overdue[Left] = overdue[Right]
    dueToday[Left] = dueToday[Right]
    upcoming[Left] = upcoming[Right]
    postponed[Left] = postponed[Right]
    advanced[Left] = advanced[Right]
    sameDayReplacement[Left] = sameDayReplacement[Right]
  }
}

assert TerminalKindsPartitionTerminal {
  all w: World | {
    terminal[w] = completed[w] + retired[w] + superseded[w]
    no completed[w] & retired[w]
    no completed[w] & superseded[w]
    no retired[w] & superseded[w]
  }
}

assert TemporalViewsPartitionOpen {
  all w: World | {
    liveScheduled[w] = overdue[w] + dueToday[w] + upcoming[w]
    no overdue[w] & dueToday[w]
    no overdue[w] & upcoming[w]
    no dueToday[w] & upcoming[w]
  }
}

run representativeLifecycle for exactly 7 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
run futureEvidenceLeavesEarlierViewOpen for exactly 5 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 6 LifecycleEdge, exactly 2 World
run sameOpenDifferentTerminalMeaning for exactly 5 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 6 LifecycleEdge, exactly 2 World
run sameKindsDifferentSuccessorProvenance for exactly 6 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
run directionWithoutOperationKinds for exactly 6 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
check ClosedSummaryDeterminesLifecycleMeaning for exactly 5 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 6 LifecycleEdge, exactly 2 World
check StatusKindsDetermineSuccessorProvenance for exactly 6 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
check DecodedLifecycleDeterminesSelectedViews for exactly 6 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
check TerminalKindsPartitionTerminal for exactly 6 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
check TemporalViewsPartitionOpen for exactly 6 Scheduled, exactly 2 Movement, exactly 5 Day, exactly 8 LifecycleEdge, exactly 2 World
