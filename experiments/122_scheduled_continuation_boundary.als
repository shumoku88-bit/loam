module experiments/observation_122_scheduled_continuation_boundary

open util/ordering[Day] as ord

sig Day {}
sig MovementShape {}
sig Scheduled {
  scheduledDay: one Day,
  shape: one MovementShape
}
sig Actual {}

sig World {
  completion: Scheduled -> lone Actual,
  replacement: Scheduled -> lone Scheduled,
  continuation: Scheduled -> lone Scheduled
}

one sig Left, Right extends World {}

fact RelationShape {
  all w: World, a: Actual |
    lone a.~(w.completion)

  all w: World, n: Scheduled |
    lone n.~(w.replacement)

  all w: World, n: Scheduled |
    lone n.~(w.continuation)

  all w: World | {
    no iden & ^(w.replacement)
    no iden & ^(w.continuation)
  }

  -- Observation 105's successor/replacement is terminal lifecycle evidence.
  -- It deliberately cannot coexist with completion for the same source.
  all w: World, s: Scheduled |
    not (some s.(w.completion) and some s.(w.replacement))

  -- A next-occurrence continuation points forward in Scheduled coordinates,
  -- but it is provenance, not terminal lifecycle evidence.
  all w: World, s, n: Scheduled |
    s->n in w.continuation implies ord/lt[s.scheduledDay, n.scheduledDay]
}

fun completed[w: World]: set Scheduled {
  { s: Scheduled | some s.(w.completion) }
}

fun superseded[w: World]: set Scheduled {
  { s: Scheduled | some s.(w.replacement) }
}

fun live[w: World]: set Scheduled {
  Scheduled - completed[w] - superseded[w]
}

fun linkedNext[w: World, s: Scheduled]: set Scheduled {
  s.(w.continuation)
}

fun similarFuture[s: Scheduled]: set Scheduled {
  { n: Scheduled |
    n.shape = s.shape and
    ord/lt[s.scheduledDay, n.scheduledDay]
  }
}

pred completedOccurrenceCanHaveLinkedNext {
  some s, n: Scheduled, a: Actual | {
    s != n
    s->a in Left.completion
    s->n in Left.continuation
    n in live[Left]
  }
}

pred precreatedFutureChainBeforeCompletion {
  some disj s, n1, n2: Scheduled | {
    s.shape = n1.shape
    n1.shape = n2.shape
    s->n1 in Left.continuation
    n1->n2 in Left.continuation
    s in live[Left]
    n1 in live[Left]
    n2 in live[Left]
  }
}

pred precreatedFutureChainSurvivesCompletion {
  some disj s, n1, n2: Scheduled, a: Actual | {
    s.shape = n1.shape
    n1.shape = n2.shape
    s->a in Left.completion
    s->n1 in Left.continuation
    n1->n2 in Left.continuation
    n1 in live[Left]
    n2 in live[Left]
  }
}

-- Reusing Observation 105's terminal replacement edge as the next-occurrence
-- edge would conflict with a completed source under its already-earned meaning.
pred completionPlusReplacementAsNext {
  some s, n: Scheduled, a: Actual | {
    s != n
    s->a in Left.completion
    s->n in Left.replacement
  }
}

-- Even when exactly one later Scheduled fact has the same retained movement
-- shape, endpoint similarity alone does not say whether it is "the next one".
pred oneSimilarFutureStillNeedsProvenance {
  Left.completion = Right.completion
  Left.replacement = Right.replacement

  some s, n: Scheduled, a: Actual | {
    s != n
    s->a in Left.completion
    similarFuture[s] = n
    s->n in Left.continuation
    Right.continuation = Left.continuation - s->n
    n in live[Left]
    n in live[Right]
  }
}

pred sameLifecycleDifferentContinuation {
  Left.completion = Right.completion
  Left.replacement = Right.replacement
  completed[Left] = completed[Right]
  superseded[Left] = superseded[Right]
  live[Left] = live[Right]
  Left.continuation != Right.continuation
}

assert StructuralFutureDeterminesContinuation {
  Left.completion = Right.completion and
  Left.replacement = Right.replacement
  implies Left.continuation = Right.continuation
}

assert ContinuationDoesNotCloseSource {
  all w: World, s: Scheduled |
    some linkedNext[w, s] and
    no s.(w.completion) and
    no s.(w.replacement)
    implies s in live[w]
}

run completedOccurrenceCanHaveLinkedNext for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
run precreatedFutureChainBeforeCompletion for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
run precreatedFutureChainSurvivesCompletion for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
run completionPlusReplacementAsNext for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
run oneSimilarFutureStillNeedsProvenance for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
run sameLifecycleDifferentContinuation for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
check StructuralFutureDeterminesContinuation for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
check ContinuationDoesNotCloseSource for exactly 5 Scheduled, exactly 2 Actual, exactly 5 Day, exactly 2 MovementShape, exactly 2 World
