module experiments/normalized_actual_writer_authority

sig ActualGeneration {}
sig PolicyGeneration {}
sig ScheduledGeneration {}

sig Snapshot {
  actual: one ActualGeneration,
  policy: one PolicyGeneration,
  scheduled: one ScheduledGeneration
}

abstract sig WriteKind {}
one sig MovementWrite extends WriteKind {}
one sig DateRevisionWrite extends WriteKind {}
one sig CorrectionWrite extends WriteKind {}
one sig ReversalWrite extends WriteKind {}

sig Write {
  kind: one WriteKind,
  pre: one Snapshot,
  post: one Snapshot,
  candidate: one ActualGeneration,
  policyRead: lone PolicyGeneration,
  scheduledRead: lone ScheduledGeneration
}

pred needsPolicy[kind: WriteKind] {
  kind in MovementWrite + CorrectionWrite + ReversalWrite
}

pred needsScheduled[kind: WriteKind] {
  kind = ReversalWrite
}

pred dependenciesRead[w: Write] {
  needsPolicy[w.kind] implies w.policyRead = w.pre.policy
  not needsPolicy[w.kind] implies no w.policyRead

  needsScheduled[w.kind] implies w.scheduledRead = w.pre.scheduled
  not needsScheduled[w.kind] implies no w.scheduledRead
}

// Actual publication selects one candidate generation. Only authorities whose
// current meaning was used by admission must remain at the version read.
pred guardedCommit[w: Write] {
  dependenciesRead[w]
  w.post.actual = w.candidate
  needsPolicy[w.kind] implies w.post.policy = w.pre.policy
  needsScheduled[w.kind] implies w.post.scheduled = w.pre.scheduled
}

// These races are intentionally satisfiable without the corresponding guard.
pred unguardedPolicyRace {
  some w: Write | {
    needsPolicy[w.kind]
    dependenciesRead[w]
    w.post.actual = w.candidate
    w.post.policy != w.pre.policy
  }
}

pred unguardedScheduledRace {
  some w: Write | {
    w.kind = ReversalWrite
    dependenciesRead[w]
    w.post.actual = w.candidate
    w.post.scheduled != w.pre.scheduled
  }
}

// These witnesses are intentionally satisfiable: unrelated authorities need not
// be co-published merely because Actual selects a new generation.
pred dateRevisionWhilePolicyAdvances {
  some w: Write | {
    w.kind = DateRevisionWrite
    guardedCommit[w]
    w.post.policy != w.pre.policy
  }
}

pred movementWhileScheduledAdvances {
  some w: Write | {
    w.kind = MovementWrite
    guardedCommit[w]
    w.post.scheduled != w.pre.scheduled
  }
}

assert GuardedPolicyDependencyCannotRace {
  all w: Write |
    guardedCommit[w] and needsPolicy[w.kind] implies
      w.post.policy = w.policyRead
}

assert GuardedScheduledDependencyCannotRace {
  all w: Write |
    guardedCommit[w] and needsScheduled[w.kind] implies
      w.post.scheduled = w.scheduledRead
}

assert GuardedCommitSelectsCandidateActual {
  all w: Write |
    guardedCommit[w] implies w.post.actual = w.candidate
}

run unguardedPolicyRace for 5 but exactly 1 Write, exactly 2 Snapshot, exactly 1 ActualGeneration, exactly 2 PolicyGeneration, exactly 1 ScheduledGeneration
run unguardedScheduledRace for 5 but exactly 1 Write, exactly 2 Snapshot, exactly 1 ActualGeneration, exactly 1 PolicyGeneration, exactly 2 ScheduledGeneration
run dateRevisionWhilePolicyAdvances for 5 but exactly 1 Write, exactly 2 Snapshot, exactly 1 ActualGeneration, exactly 2 PolicyGeneration, exactly 1 ScheduledGeneration
run movementWhileScheduledAdvances for 5 but exactly 1 Write, exactly 2 Snapshot, exactly 1 ActualGeneration, exactly 1 PolicyGeneration, exactly 2 ScheduledGeneration

check GuardedPolicyDependencyCannotRace for 6 but exactly 1 Write, exactly 2 Snapshot, exactly 2 ActualGeneration, exactly 2 PolicyGeneration, exactly 2 ScheduledGeneration
check GuardedScheduledDependencyCannotRace for 6 but exactly 1 Write, exactly 2 Snapshot, exactly 2 ActualGeneration, exactly 2 PolicyGeneration, exactly 2 ScheduledGeneration
check GuardedCommitSelectsCandidateActual for 6 but exactly 1 Write, exactly 2 Snapshot, exactly 2 ActualGeneration, exactly 2 PolicyGeneration, exactly 2 ScheduledGeneration
