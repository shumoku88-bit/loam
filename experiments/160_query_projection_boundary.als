module experiments/observation_160_query_projection_boundary

sig Purpose {}

sig CapacityFact {
  purpose: one Purpose
}

sig ActualFact {
  purpose: one Purpose
}

sig Snapshot {
  capacity: set CapacityFact,
  actual: set ActualFact
}

sig Query {
  purpose: one Purpose
}

sig Hypothesis {
  addCapacity: set CapacityFact,
  addActual: set ActualFact
}

abstract sig Surface {}
one sig ChatGPT, TUI, CLI extends Surface {}

sig BoundResponse {
  source: one Snapshot,
  query: one Query,
  surface: one Surface,
  hypothesis: lone Hypothesis,
  value: one Int
}

sig BareResponse {
  query: one Query,
  surface: one Surface,
  hypothesis: lone Hypothesis,
  value: one Int
}

sig Execution {
  before: one Snapshot,
  after: one Snapshot,
  response: one BoundResponse
}

fun capacityFor[s: Snapshot, q: Query]: set CapacityFact {
  { c: s.capacity | c.purpose = q.purpose }
}

fun actualFor[s: Snapshot, q: Query]: set ActualFact {
  { a: s.actual | a.purpose = q.purpose }
}

fun remaining[s: Snapshot, q: Query]: one Int {
  sub[#capacityFor[s, q], #actualFor[s, q]]
}

fun hypotheticalCapacityFor[s: Snapshot, q: Query, h: Hypothesis]: set CapacityFact {
  { c: CapacityFact |
    c in s.capacity + h.addCapacity and
    c.purpose = q.purpose
  }
}

fun hypotheticalActualFor[s: Snapshot, q: Query, h: Hypothesis]: set ActualFact {
  { a: ActualFact |
    a in s.actual + h.addActual and
    a.purpose = q.purpose
  }
}

fun hypotheticalRemaining[s: Snapshot, q: Query, h: Hypothesis]: one Int {
  sub[#hypotheticalCapacityFor[s, q, h], #hypotheticalActualFor[s, q, h]]
}

fact BoundResponsesAreDerived {
  all r: BoundResponse |
    (no r.hypothesis and r.value = remaining[r.source, r.query])
    or
    (some h: r.hypothesis |
      r.value = hypotheticalRemaining[r.source, r.query, h])
}

pred freshHypothesis[s: Snapshot, h: Hypothesis] {
  no h.addCapacity & s.capacity
  no h.addActual & s.actual
}

pred appliesHypothesis[base, after: Snapshot, h: Hypothesis] {
  after.capacity = base.capacity + h.addCapacity
  after.actual = base.actual + h.addActual
}

pred readOnlyExecution[e: Execution] {
  e.response.source = e.before
  e.after.capacity = e.before.capacity
  e.after.actual = e.before.actual
}

pred crossSurfaceBoundResponseWitness {
  some disj left, right: BoundResponse | {
    left.source = right.source
    left.query = right.query
    left.hypothesis = right.hypothesis
    left.surface != right.surface
    left.value = right.value
  }
}

pred hypotheticalOverlayChangesAnswer {
  some s: Snapshot, q: Query, h: Hypothesis, c: CapacityFact | {
    h.addCapacity = c
    no h.addActual
    c.purpose = q.purpose
    freshHypothesis[s, h]
    hypotheticalRemaining[s, q, h] = add[remaining[s, q], 1]
  }
}

pred simulationMatchesExplicitApply {
  some disj base, after: Snapshot, q: Query, h: Hypothesis | {
    freshHypothesis[base, h]
    some h.addCapacity + h.addActual
    appliesHypothesis[base, after, h]
    hypotheticalRemaining[base, q, h] = remaining[after, q]
    base.capacity != after.capacity or base.actual != after.actual
  }
}

pred bareResponseStalenessWitness {
  some b: BareResponse, disj old, current: Snapshot | {
    no b.hypothesis
    b.value = remaining[old, b.query]
    b.value != remaining[current, b.query]
  }
}

assert CrossSurfaceDeterminism {
  all left, right: BoundResponse |
    left.source = right.source and
    left.query = right.query and
    left.hypothesis = right.hypothesis implies
      left.value = right.value
}

assert ReadOnlyExecutionPreservesAnyCanonicalQuery {
  all e: Execution |
    readOnlyExecution[e] implies
      all q: Query |
        remaining[e.before, q] = remaining[e.after, q]
}

assert BoundCurrentResponseMatchesCurrentSnapshot {
  all r: BoundResponse, current: Snapshot |
    r.source = current and no r.hypothesis implies
      r.value = remaining[current, r.query]
}

run crossSurfaceBoundResponseWitness for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
run hypotheticalOverlayChangesAnswer for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
run simulationMatchesExplicitApply for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
run bareResponseStalenessWitness for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
check CrossSurfaceDeterminism for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
check ReadOnlyExecutionPreservesAnyCanonicalQuery for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
check BoundCurrentResponseMatchesCurrentSnapshot for exactly 2 Purpose, exactly 4 CapacityFact, exactly 4 ActualFact, exactly 3 Snapshot, exactly 2 Query, exactly 2 Hypothesis, exactly 4 BoundResponse, exactly 2 BareResponse, exactly 2 Execution, 5 Int
