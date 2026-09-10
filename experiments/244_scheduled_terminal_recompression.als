module experiments/observation_244_scheduled_terminal_recompression

-- Observation 244: modern Scheduled terminal re-compression pressure
--
-- Observation 105 represented completion, retirement and replacement as one
-- target-preserving LifecycleEdge. Production later realized those meanings as
-- three typed memories. This model asks the answer-first question again against
-- the mature read contract, including dangling completion activation, unknown
-- references, replacement cycles and cross-kind terminal conflicts.
--
-- It deliberately models no file, codec, publisher or migration shape.

abstract sig Endpoint {}
sig Scheduled extends Endpoint {}
sig Event extends Endpoint {}

-- One raw target-preserving Scheduled terminal fact.
--
-- target Event      => completion
-- target Scheduled  => replacement
-- no target         => retirement
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

-- Mirror the current per-family Core uniqueness boundaries while allowing the
-- same cross-kind conflict that production ScheduledInspection detects after
-- loading the three individual memories.
fact RawTerminalMemoryShape {
  all edge : TerminalEdge |
    edge.target != edge.source

  all w : World | {
    all s : Scheduled | {
      lone { edge : w.terminals | edge.source = s and edge.target in Event }
      lone { edge : w.terminals | edge.source = s and no edge.target }
      lone { edge : w.terminals | edge.source = s and edge.target in Scheduled }
    }

    all actual : Event |
      lone { edge : w.terminals | edge.target = actual }

    all successor : Scheduled |
      lone { edge : w.terminals | edge.target = successor }
  }
}

-- The three current production facets are projections of one target-typed edge
-- relation; no extra lifecycle kind field is needed.
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
    edge.target in Event implies edge.source in w.scheduled
}

pred retirementSourcesKnownByEdges[w : World] {
  all edge : w.terminals |
    no edge.target implies edge.source in w.scheduled
}

pred replacementEndpointsKnownByEdges[w : World] {
  all edge : w.terminals |
    edge.target in Scheduled implies
      edge.source in w.scheduled and edge.target in w.scheduled
}

pred terminalConflictByEdges[w : World] {
  some s : Scheduled |
    # { edge : w.terminals | edge.source = s } > 1
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

-- Same decision order as the current replacement-aware Scheduled inspection,
-- but phrased through the three legacy facet projections.
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
    some actual : Event |
      s->actual in completions[w] and actual in w.events
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
       or edge.target in Scheduled
       or (edge.target in Event and edge.target in w.events))
  }
}

pred representativeMatureLifecycle {
  some w : World | {
    reviewByEdges[w] = OpenResult
    some completedSources[w]
    some retirements[w]
    some replacementSources[w]
    some openByEdges[w]
  }
}

-- Current publication permits a completion relation to exist before its Actual
-- endpoint becomes authoritative. It remains inert for the open-set answer.
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

-- A plain closed/open summary loses which terminal meaning happened.
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

-- Even keeping completion/retirement/replacement source kinds is too small when
-- the target identity differs.
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

assert TargetTypedEdgePartitionsCurrentFacets {
  all w : World |
    terminalSources[w] =
      completedSources[w] + retirements[w] + replacementSources[w]
}

assert EdgeAndFacetFailureClassificationAgree {
  all w : World |
    reviewByEdges[w] = reviewByFacets[w]
}

assert EdgeAndFacetCurrentOpenAgree {
  all w : World |
    reviewByEdges[w] = OpenResult implies
      openByEdges[w] = openByFacets[w]
}

-- Once the target-preserving facet projections and retained endpoint sets are
-- fixed, the mature read answer is fixed. There is no additional lifecycle
-- state hidden behind the three current memory names.
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

run representativeMatureLifecycle for 8 but exactly 8 Scheduled, exactly 4 Event, 12 TerminalEdge, 3 World, 5 Int
run danglingCompletionStaysOpen for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 2 World, 5 Int
run unknownCompletionSourceVisible for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 2 World, 5 Int
run unknownRetirementSourceVisible for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 2 World, 5 Int
run unknownReplacementEndpointVisible for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 2 World, 5 Int
run replacementCycleVisible for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 2 World, 5 Int
run crossKindConflictVisible for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 2 World, 5 Int
run sameTerminalSourcesDifferentMeaning for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 3 World, 5 Int
run sameKindsDifferentTargetProvenance for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 3 World, 5 Int

check TargetTypedEdgePartitionsCurrentFacets for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 3 World, 5 Int
check EdgeAndFacetFailureClassificationAgree for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 3 World, 5 Int
check EdgeAndFacetCurrentOpenAgree for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 3 World, 5 Int
check TargetPreservingLifecycleDeterminesReadAnswer for 6 but 6 Scheduled, 4 Event, 8 TerminalEdge, 3 World, 5 Int
