module experiments/normalized_actual_scheduled_completion

sig Event {}
sig ScheduledId {}
sig PolicyGeneration {}

sig ActualGeneration {
  events: set Event
}

// Scheduled lifecycle is an independently selected semantic authority. A retained
// completion claim may temporarily name an Actual Event that is not selected yet;
// production readers treat that claim as inert until the target Event exists.
sig ScheduledGeneration {
  completions: ScheduledId -> lone Event
}

sig Snapshot {
  actual: one ActualGeneration,
  scheduled: one ScheduledGeneration,
  policy: one PolicyGeneration
}

sig CompletionWrite {
  start: one Snapshot,
  middle: one Snapshot,
  finish: one Snapshot,
  stagedActual: one ActualGeneration,
  stagedScheduled: one ScheduledGeneration,
  policyRead: one PolicyGeneration,
  source: one ScheduledId,
  target: one Event
}

fun visibleCompletions[s: Snapshot]: ScheduledId -> Event {
  s.scheduled.completions & (ScheduledId -> s.actual.events)
}

// One fresh Scheduled completion necessarily changes two independent semantic
// authorities: Scheduled gains the source->Actual terminal claim and Actual gains
// the new Event. Policy is read for admission but is not itself written.
pred freshCompletion[w: CompletionWrite] {
  no ((w.source -> Event) & w.start.scheduled.completions)
  w.target not in w.start.actual.events

  w.stagedScheduled.completions =
    w.start.scheduled.completions + w.source->w.target
  w.stagedActual.events = w.start.actual.events + w.target
  w.policyRead = w.start.policy
}

// Current production's earned fail-closed protocol: publish the Scheduled claim
// first. During interruption the claim is retained but invisible because the
// target Actual Event is absent. The final Actual switch makes the pair visible.
pred relationFirstCompletion[w: CompletionWrite] {
  freshCompletion[w]

  w.middle.scheduled = w.stagedScheduled
  w.middle.actual = w.start.actual
  w.middle.policy = w.start.policy

  w.finish.scheduled = w.stagedScheduled
  w.finish.actual = w.stagedActual
  w.finish.policy = w.start.policy
}

// The tempting reverse order is observably different: the new Actual Event is
// selected before any Scheduled completion claim names it. That is precisely the
// unlinked Actual exposure the current relation-first protocol avoids.
pred actualFirstExposesUnlinkedActual {
  some w: CompletionWrite | {
    freshCompletion[w]

    w.middle.actual = w.stagedActual
    w.middle.scheduled = w.start.scheduled
    w.middle.policy = w.start.policy

    w.finish.actual = w.stagedActual
    w.finish.scheduled = w.stagedScheduled
    w.finish.policy = w.start.policy

    w.target in w.middle.actual.events
    w.source->w.target not in visibleCompletions[w.middle]
  }
}

// If Locus policy changes after admission but before completion finishes, the
// write was admitted against a stale vocabulary. This witness keeps pressure for
// a lock/CAS guard without merging Policy into either semantic authority.
pred unguardedCompletionPolicyRace {
  some w: CompletionWrite | {
    freshCompletion[w]
    w.middle.scheduled = w.stagedScheduled
    w.middle.actual = w.start.actual
    w.finish.scheduled = w.stagedScheduled
    w.finish.actual = w.stagedActual
    w.finish.policy != w.policyRead
  }
}

pred relationFirstCompletionWitness {
  some w: CompletionWrite | relationFirstCompletion[w]
}

assert RelationFirstInterruptionIsInert {
  all w: CompletionWrite |
    relationFirstCompletion[w] implies {
      w.source->w.target in w.middle.scheduled.completions
      w.target not in w.middle.actual.events
      w.source->w.target not in visibleCompletions[w.middle]
    }
}

assert RelationFirstCompletionBecomesVisible {
  all w: CompletionWrite |
    relationFirstCompletion[w] implies {
      w.target in w.finish.actual.events
      w.source->w.target in visibleCompletions[w.finish]
    }
}

assert ScheduledCompletionChangesBothAuthorities {
  all w: CompletionWrite |
    relationFirstCompletion[w] implies {
      w.finish.actual != w.start.actual
      w.finish.scheduled != w.start.scheduled
    }
}

assert GuardedCompletionPolicyCannotRace {
  all w: CompletionWrite |
    relationFirstCompletion[w] implies
      w.finish.policy = w.policyRead
}

run relationFirstCompletionWitness for 8 but exactly 2 ActualGeneration, 2 ScheduledGeneration, 1 PolicyGeneration, 1 CompletionWrite
run actualFirstExposesUnlinkedActual for 8 but exactly 2 ActualGeneration, 2 ScheduledGeneration, 1 PolicyGeneration, 1 CompletionWrite
run unguardedCompletionPolicyRace for 8 but exactly 2 ActualGeneration, 2 ScheduledGeneration, 2 PolicyGeneration, 1 CompletionWrite

check RelationFirstInterruptionIsInert for 10
check RelationFirstCompletionBecomesVisible for 10
check ScheduledCompletionChangesBothAuthorities for 10
check GuardedCompletionPolicyCannotRace for 10
