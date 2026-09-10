module experiments/observation_244_scheduled_terminal_recompression

-- Observation 244
--
-- Observation 105 represented completion, retirement and replacement as one
-- target-preserving LifecycleEdge. Production later realized those meanings as
-- three typed memories. Re-test that smaller representation against the mature
-- current-open and write-admission contracts without choosing a file, codec,
-- generic publisher, or migration.

abstract sig Endpoint {}
sig Scheduled extends Endpoint {}
sig Event extends Endpoint {}

-- Event target      = completion
-- Scheduled target  = replacement
-- no target         = retirement
sig TerminalEdge {
  source : one Scheduled,
  target : lone Endpoint
}

sig World {
  scheduled : set Scheduled,
  events : set Event,
  terminals : set TerminalEdge
}

abstract sig ReviewResult {}
one sig OpenResult,
        UnknownCompletionScheduled,
        UnknownRetirementScheduled,
        UnknownReplacementScheduled,
        InvalidReplacementGraph,
        ConflictingTerminalEvidence extends ReviewResult {}

fact RawShape {
  all edge : TerminalEdge | edge.target != edge.source

  all w : World, s : Scheduled | {
    lone { edge : w.terminals |
      edge.source = s and some edge.target and edge.target in Event }
    lone { edge : w.terminals | edge.source = s and no edge.target }
    lone { edge : w.terminals |
      edge.source = s and some edge.target and edge.target in Scheduled }
  }

  all w : World, actual : Event |
    lone { edge : w.terminals | edge.target = actual }

  all w : World, successor : Scheduled |
    lone { edge : w.terminals | edge.target = successor }
}

fun completions[w : World] : Scheduled -> Event {
  { s : Scheduled, actual : Event |
    some edge : w.terminals |
      edge.source = s and edge.target = actual
  }
}

fun retirements[w : World] : set Scheduled {
  { s : Scheduled |
    some edge : w.terminals |
      edge.source = s and no edge.target
  }
}

fun replacements[w : World] : Scheduled -> Scheduled {
  { s, successor : Scheduled |
    some edge : w.terminals |
      edge.source = s and edge.target = successor
  }
}

fun terminalSources[w : World] : set Scheduled {
  { s : Scheduled | some edge : w.terminals | edge.source = s }
}

fun completedSources[w : World] : set Scheduled {
  { s : Scheduled | some s.(completions[w]) }
}

fun replacementSources[w : World] : set Scheduled {
  { s : Scheduled | some s.(replacements[w]) }
}

pred completionSourcesKnownByEdges[w : World] {
  all edge : w.terminals |
    (some edge.target and edge.target in Event) implies
      edge.source in w.scheduled
}

pred retirementSourcesKnownByEdges[w : World] {
  all edge : w.terminals |
    no edge.target implies edge.source in w.scheduled
}

pred replacementEndpointsKnownByEdges[w : World] {
  all edge : w.terminals |
    (some edge.target and edge.target in Scheduled) implies {
      edge.source in w.scheduled
      edge.target in w.scheduled
    }
}

pred terminalConflictByEdges[w : World] {
  some s : Scheduled, disj left, right : w.terminals |
    left.source = s and right.source = s
}

pred completionSourcesKnownByFacets[w : World] {
  all s : Scheduled |
    some s.(completions[w]) implies s in w.scheduled
}

pred retirementSourcesKnownByFacets[w : World] {
  retirements[w] in w.scheduled
}

pred replacementEndpointsKnownByFacets[w : World] {
  all s : Scheduled |
    some s.(replacements[w]) implies {
      s in w.scheduled
      s.(replacements[w]) in w.scheduled
    }
}

pred terminalConflictByFacets[w : World] {
  some s : Scheduled | {
    (some s.(completions[w]) and s in retirements[w])
    or (some s.(completions[w]) and some s.(replacements[w]))
    or (s in retirements[w] and some s.(replacements[w]))
  }
}

fun reviewByEdges[w : World] : one ReviewResult {
  (not completionSourcesKnownByEdges[w]) => UnknownCompletionScheduled else
  (not retirementSourcesKnownByEdges[w]) => UnknownRetirementScheduled else
  (not replacementEndpointsKnownByEdges[w]) => UnknownReplacementScheduled else
  (some iden & ^(replacements[w])) => InvalidReplacementGraph else
  terminalConflictByEdges[w] => ConflictingTerminalEvidence else
  OpenResult
}

fun reviewByFacets[w : World] : one ReviewResult {
  (not completionSourcesKnownByFacets[w]) => UnknownCompletionScheduled else
  (not retirementSourcesKnownByFacets[w]) => UnknownRetirementScheduled else
  (not replacementEndpointsKnownByFacets[w]) => UnknownReplacementScheduled else
  (some iden & ^(replacements[w])) => InvalidReplacementGraph else
  terminalConflictByFacets[w] => ConflictingTerminalEvidence else
  OpenResult
}

fun effectiveCompleted[w : World] : set Scheduled {
  { s : w.scheduled |
    some actual : w.events | s->actual in completions[w]
  }
}

fun openByFacets[w : World] : set Scheduled {
  w.scheduled - retirements[w] - effectiveCompleted[w] - replacementSources[w]
}

fun openByEdges[w : World] : set Scheduled {
  { s : w.scheduled |
    no edge : w.terminals |
      edge.source = s and
      (no edge.target
       or (some edge.target and edge.target in Scheduled)
       or edge.target in w.events)
  }
}

pred representativeMatureLifecycle {
  some w : World | {
    reviewByEdges[w] = OpenResult
    some effectiveCompleted[w]
    some retirements[w]
    some replacementSources[w]
    some openByEdges[w]
  }
}

pred danglingCompletionStaysOpen {
  some w : World, s : w.scheduled, actual : Event - w.events | {
    s->actual in completions[w]
    reviewByEdges[w] = OpenResult
    s in openByEdges[w]
  }
}

pred unknownCompletionSourceVisible {
  some w : World | reviewByEdges[w] = UnknownCompletionScheduled
}

pred unknownRetirementSourceVisible {
  some w : World | reviewByEdges[w] = UnknownRetirementScheduled
}

pred unknownReplacementEndpointVisible {
  some w : World | reviewByEdges[w] = UnknownReplacementScheduled
}

pred replacementCycleVisible {
  some w : World | reviewByEdges[w] = InvalidReplacementGraph
}

pred crossKindConflictVisible {
  some w : World | reviewByEdges[w] = ConflictingTerminalEvidence
}

pred sameTerminalSourcesDifferentMeaning {
  some disj left, right : World | {
    left.scheduled = right.scheduled
    left.events = right.events
    terminalSources[left] = terminalSources[right]
    completions[left] != completions[right]
      or retirements[left] != retirements[right]
      or replacements[left] != replacements[right]
  }
}

pred sameKindsDifferentTargetProvenance {
  some disj left, right : World | {
    left.scheduled = right.scheduled
    left.events = right.events
    completedSources[left] = completedSources[right]
    retirements[left] = retirements[right]
    replacementSources[left] = replacementSources[right]
    completions[left] != completions[right]
      or replacements[left] != replacements[right]
  }
}

-- Q_write: retained terminal representation may be shared while
-- operation-specific writers remain distinct.
pred readableOpenByEdges[w : World, s : Scheduled] {
  reviewByEdges[w] = OpenResult
  s in openByEdges[w]
}

pred readableOpenByFacets[w : World, s : Scheduled] {
  reviewByFacets[w] = OpenResult
  s in openByFacets[w]
}

pred completionWriteByEdges[w : World, s : Scheduled] {
  readableOpenByEdges[w, s]
}

pred completionWriteByFacets[w : World, s : Scheduled] {
  readableOpenByFacets[w, s]
}

pred cancellationWriteByEdges[w : World, s : Scheduled] {
  readableOpenByEdges[w, s]
  no edge : w.terminals | edge.source = s
}

pred cancellationWriteByFacets[w : World, s : Scheduled] {
  readableOpenByFacets[w, s]
  no s.(completions[w])
  s not in retirements[w]
  no s.(replacements[w])
}

pred replacementWriteByEdges[w : World, s : Scheduled] {
  readableOpenByEdges[w, s]
  no edge : w.terminals | edge.source = s
}

pred replacementWriteByFacets[w : World, s : Scheduled] {
  readableOpenByFacets[w, s]
  no s.(completions[w])
  s not in retirements[w]
  no s.(replacements[w])
}

pred danglingCompletionAllowsRetryButBlocksCompetingTerminalWrites {
  some w : World, s : w.scheduled, actual : Event - w.events, edge : w.terminals | {
    edge.source = s
    edge.target = actual
    reviewByEdges[w] = OpenResult
    completionWriteByEdges[w, s]
    not cancellationWriteByEdges[w, s]
    not replacementWriteByEdges[w, s]
  }
}

pred completionSupportThenEventActivates {
  some disj initial, supported, activated : World | {
    some s : Scheduled, actual : Event, edge : TerminalEdge | {
      s in initial.scheduled
      actual not in initial.events
      no prior : initial.terminals | prior.source = s
      edge.source = s
      edge.target = actual
      supported.scheduled = initial.scheduled
      supported.events = initial.events
      supported.terminals = initial.terminals + edge
      activated.scheduled = supported.scheduled
      activated.terminals = supported.terminals
      activated.events = supported.events + actual
      reviewByEdges[initial] = OpenResult
      reviewByEdges[supported] = OpenResult
      reviewByEdges[activated] = OpenResult
      s in openByEdges[initial]
      s in openByEdges[supported]
      s not in openByEdges[activated]
    }
  }
}

pred cancellationAppendClosesSource {
  some disj initial, updated : World | {
    some s : Scheduled, edge : TerminalEdge | {
      s in initial.scheduled
      cancellationWriteByEdges[initial, s]
      edge.source = s
      no edge.target
      updated.scheduled = initial.scheduled
      updated.events = initial.events
      updated.terminals = initial.terminals + edge
      reviewByEdges[updated] = OpenResult
      s not in openByEdges[updated]
    }
  }
}

pred replacementAppendClosesSourceAndOpensSuccessor {
  some disj initial, updated : World | {
    some src, successor : Scheduled, edge : TerminalEdge | {
      src in initial.scheduled
      successor not in initial.scheduled
      replacementWriteByEdges[initial, src]
      edge.source = src
      edge.target = successor
      updated.scheduled = initial.scheduled + successor
      updated.events = initial.events
      updated.terminals = initial.terminals + edge
      reviewByEdges[updated] = OpenResult
      src not in openByEdges[updated]
      successor in openByEdges[updated]
    }
  }
}

assert TargetTypedEdgePartitionsCurrentFacets {
  all w : World |
    terminalSources[w] =
      completedSources[w] + retirements[w] + replacementSources[w]
}

assert EdgeAndFacetFailureClassificationAgree {
  all w : World | reviewByEdges[w] = reviewByFacets[w]
}

assert EdgeAndFacetCurrentOpenAgree {
  all w : World |
    reviewByEdges[w] = OpenResult implies
      openByEdges[w] = openByFacets[w]
}

assert TargetPreservingLifecycleDeterminesReadAnswer {
  all left, right : World |
    left.scheduled = right.scheduled and
    left.events = right.events and
    completions[left] = completions[right] and
    retirements[left] = retirements[right] and
    replacements[left] = replacements[right] implies {
      reviewByEdges[left] = reviewByEdges[right]
      openByEdges[left] = openByEdges[right]
    }
}

assert EdgeAndFacetCompletionAdmissionAgree {
  all w : World, s : Scheduled |
    completionWriteByEdges[w, s] iff completionWriteByFacets[w, s]
}

assert EdgeAndFacetCancellationAdmissionAgree {
  all w : World, s : Scheduled |
    cancellationWriteByEdges[w, s] iff cancellationWriteByFacets[w, s]
}

assert EdgeAndFacetReplacementAdmissionAgree {
  all w : World, s : Scheduled |
    replacementWriteByEdges[w, s] iff replacementWriteByFacets[w, s]
}

run representativeMatureLifecycle for exactly 5 Scheduled, exactly 2 Event, 5 TerminalEdge, exactly 1 World
run danglingCompletionStaysOpen for exactly 2 Scheduled, exactly 2 Event, 2 TerminalEdge, exactly 1 World
run unknownCompletionSourceVisible for exactly 2 Scheduled, exactly 1 Event, 2 TerminalEdge, exactly 1 World
run unknownRetirementSourceVisible for exactly 2 Scheduled, exactly 1 Event, 2 TerminalEdge, exactly 1 World
run unknownReplacementEndpointVisible for exactly 3 Scheduled, exactly 1 Event, 3 TerminalEdge, exactly 1 World
run replacementCycleVisible for exactly 2 Scheduled, exactly 1 Event, 2 TerminalEdge, exactly 1 World
run crossKindConflictVisible for exactly 2 Scheduled, exactly 1 Event, 2 TerminalEdge, exactly 1 World
run sameTerminalSourcesDifferentMeaning for exactly 2 Scheduled, exactly 1 Event, 3 TerminalEdge, exactly 2 World
run sameKindsDifferentTargetProvenance for exactly 1 Scheduled, exactly 2 Event, 2 TerminalEdge, exactly 2 World
run danglingCompletionAllowsRetryButBlocksCompetingTerminalWrites for exactly 2 Scheduled, exactly 2 Event, 2 TerminalEdge, exactly 1 World
run completionSupportThenEventActivates for exactly 2 Scheduled, exactly 2 Event, 2 TerminalEdge, exactly 3 World
run cancellationAppendClosesSource for exactly 2 Scheduled, exactly 1 Event, 2 TerminalEdge, exactly 2 World
run replacementAppendClosesSourceAndOpensSuccessor for exactly 3 Scheduled, exactly 1 Event, 2 TerminalEdge, exactly 2 World

check TargetTypedEdgePartitionsCurrentFacets for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 1 World
check EdgeAndFacetFailureClassificationAgree for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 1 World
check EdgeAndFacetCurrentOpenAgree for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 1 World
check TargetPreservingLifecycleDeterminesReadAnswer for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 2 World
check EdgeAndFacetCompletionAdmissionAgree for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 1 World
check EdgeAndFacetCancellationAdmissionAgree for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 1 World
check EdgeAndFacetReplacementAdmissionAgree for 3 Scheduled, 2 Event, 4 TerminalEdge, exactly 1 World
