module experiments/observation_380_scheduled_plan_projection_boundary

open util/ordering[Month] as ord

sig Month {}

sig Occurrence {
  scheduledMonth: one Month
}

sig Monitoring {
  expected: set Month
}

abstract sig World {
  retained: set Occurrence,
  terminal: set Occurrence,
  monitoring: one Monitoring
}

one sig Left, Right extends World {}

fact TerminalEvidenceIsRetained {
  all w: World |
    w.terminal in w.retained
}

fact MonitoringHasSomeExpectation {
  all r: Monitoring |
    some r.expected
}

fun currentOpen[w: World]: set Occurrence {
  w.retained - w.terminal
}

fun expectedMonths[w: World]: set Month {
  w.monitoring.expected
}

fun openMonths[w: World]: set Month {
  currentOpen[w].scheduledMonth
}

fun missingMonths[w: World]: set Month {
  expectedMonths[w] - openMonths[w]
}

fun onPaceOccurrences[w: World]: set Occurrence {
  { o: currentOpen[w] |
      o.scheduledMonth in expectedMonths[w]
  }
}

fun outsidePaceOccurrences[w: World]: set Occurrence {
  { o: currentOpen[w] |
      o.scheduledMonth not in expectedMonths[w]
  }
}

fun actionTargets[w: World]: set Occurrence {
  currentOpen[w]
}

fun earliestGap[w: World]: lone Month {
  { m: missingMonths[w] |
      no earlier: missingMonths[w] |
        ord/lt[earlier, m]
  }
}

fun latestOpenMonth[w: World]: lone Month {
  { m: openMonths[w] |
      no later: openMonths[w] |
        ord/lt[m, later]
  }
}

fun replenishmentSourceMonth[w: World]: lone Month {
  { m: openMonths[w] & expectedMonths[w] |
      some g: earliestGap[w] | {
        ord/lt[m, g]
        no later: openMonths[w] & expectedMonths[w] |
          ord/lt[m, later] and ord/lt[later, g]
      }
  }
}

pred monitoringOnlyChange[a, b: World] {
  a.retained = b.retained
  a.terminal = b.terminal
  a.monitoring != b.monitoring
}

pred replenish[a, b: World] {
  a.monitoring = b.monitoring
  a.terminal = b.terminal

  one g: earliestGap[a] |
    one fresh: Occurrence - a.retained | {
      fresh.scheduledMonth = g
      b.retained = a.retained + fresh
    }
}

pred sameLifecycleDifferentMonitoringChangesProjection {
  Left.retained = Right.retained
  Left.terminal = Right.terminal
  expectedMonths[Left] != expectedMonths[Right]

  missingMonths[Left] != missingMonths[Right] or
    outsidePaceOccurrences[Left] != outsidePaceOccurrences[Right]
}

pred sameRetainedDifferentTerminalChangesGap {
  Left.retained = Right.retained
  Left.monitoring = Right.monitoring
  Left.terminal != Right.terminal
  missingMonths[Left] != missingMonths[Right]
}

pred outsidePaceOccurrenceRemainsActionable {
  some w: World, o: Occurrence |
    o in outsidePaceOccurrences[w] and
    o in actionTargets[w]
}

pred terminalExpectedMonthBecomesGap {
  some w: World, o: Occurrence | {
    o in w.terminal
    o.scheduledMonth in expectedMonths[w]
    o.scheduledMonth in missingMonths[w]
  }
}

pred latestExplicitCanDifferFromReplenishmentSource {
  some w: World |
    one g: earliestGap[w] |
      one latest: latestOpenMonth[w] |
        one source: replenishmentSourceMonth[w] | {
          source != latest
          ord/lt[source, g]
          ord/lt[g, latest]
        }
}

pred replenishmentWitness {
  replenish[Left, Right]
}

pred monitoringOnlyChangeCanRelabelWithoutLifecycleMutation {
  monitoringOnlyChange[Left, Right]
  expectedMonths[Left] != expectedMonths[Right]
  outsidePaceOccurrences[Left] != outsidePaceOccurrences[Right] or
    missingMonths[Left] != missingMonths[Right]
}

assert SameOpenAndMonitoringDetermineProjection {
  all a, b: World |
    (currentOpen[a] = currentOpen[b] and
     expectedMonths[a] = expectedMonths[b]) implies {
      missingMonths[a] = missingMonths[b]
      onPaceOccurrences[a] = onPaceOccurrences[b]
      outsidePaceOccurrences[a] = outsidePaceOccurrences[b]
    }
}

assert MissingMonthCannotSelectExplicitActionTarget {
  all w: World, m: Month |
    m in missingMonths[w] implies
      no o: actionTargets[w] |
        o.scheduledMonth = m
}

assert TerminalOccurrenceIsNeverActionTarget {
  all w: World |
    no (w.terminal & actionTargets[w])
}

assert ReplenishmentSourceIsExpectedAndBeforeFirstGap {
  all w: World |
    all source: replenishmentSourceMonth[w] |
      one g: earliestGap[w] | {
        source in expectedMonths[w]
        source in openMonths[w]
        ord/lt[source, g]
      }
}

assert ReplenishmentPreservesExistingLifecycleEvidence {
  all a, b: World |
    replenish[a, b] implies {
      a.retained in b.retained
      a.terminal = b.terminal
      a.monitoring = b.monitoring
    }
}

assert ReplenishmentFillsFirstGap {
  all a, b: World |
    replenish[a, b] implies
      one g: earliestGap[a] |
        g not in missingMonths[b]
}

assert MonitoringOnlyChangePreservesLifecycleEvidence {
  all a, b: World |
    monitoringOnlyChange[a, b] implies {
      a.retained = b.retained
      a.terminal = b.terminal
      currentOpen[a] = currentOpen[b]
    }
}

run sameLifecycleDifferentMonitoringChangesProjection
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

run sameRetainedDifferentTerminalChangesGap
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

run outsidePaceOccurrenceRemainsActionable
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

run terminalExpectedMonthBecomesGap
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

run latestExplicitCanDifferFromReplenishmentSource
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

run replenishmentWitness
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

run monitoringOnlyChangeCanRelabelWithoutLifecycleMutation
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check SameOpenAndMonitoringDetermineProjection
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check MissingMonthCannotSelectExplicitActionTarget
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check TerminalOccurrenceIsNeverActionTarget
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check ReplenishmentSourceIsExpectedAndBeforeFirstGap
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check ReplenishmentPreservesExistingLifecycleEvidence
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check ReplenishmentFillsFirstGap
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence

check MonitoringOnlyChangePreservesLifecycleEvidence
  for exactly 2 World, exactly 2 Monitoring, exactly 6 Month, 8 Occurrence
