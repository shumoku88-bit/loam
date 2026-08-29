module model/observation_012_envelope_as_projection

open util/ordering[Time]

sig Time {}
sig Purpose {}
sig Unit {}

one sig Origin {
  initial: set Unit
}

one sig Trace {
  at: Time -> Unit -> Purpose
}

sig Use {
  when: one Time,
  unit: one Unit,
  purpose: one Purpose
}

sig Change {
  when: one Time,
  unit: one Unit,
  from: one Purpose,
  to: one Purpose
}

fact ClosedResourceWorld {
  Origin.initial = Unit
}

fun purposeAt[t: Time, u: Unit]: set Purpose {
  u.(t.(Trace.at))
}

fun usedAt[t: Time]: set Unit {
  { u: Unit |
    some e: Use |
      e.when = t and e.unit = u
  }
}

fun usedBefore[t: Time]: set Unit {
  { u: Unit |
    some e: Use |
      e.unit = u and e.when in t.^prev
  }
}

fun derivedAvailable[t: Time]: set Unit {
  Origin.initial - usedBefore[t]
}

fun liveAtPurpose[t: Time, p: Purpose]: set Unit {
  { u: Unit |
    u in derivedAvailable[t] and
    p in purposeAt[t, u]
  }
}

pred totalPlacement {
  all t: Time, u: Unit |
    one purposeAt[t, u]
}

pred usesRespectUnderlyingBoundary {
  all e: Use |
    e.unit in derivedAvailable[e.when] and
    e.purpose in purposeAt[e.when, e.unit]

  all t: Time, u: Unit |
    lone e: Use |
      e.when = t and e.unit = u
}

pred changesNameMovement {
  all t: Time - last, u: Unit, p, q: Purpose |
    (p in purposeAt[t, u] and
     q in purposeAt[next[t], u] and
     p != q)
    implies
    some c: Change |
      c.when = t and
      c.unit = u and
      c.from = p and
      c.to = q

  all c: Change |
    c.when != last and
    c.from != c.to and
    c.from in purposeAt[c.when, c.unit] and
    c.to in purposeAt[next[c.when], c.unit]
}

pred projectionLaws {
  totalPlacement
  usesRespectUnderlyingBoundary
  changesNameMovement
}

pred nontrivialProjectionWorld {
  projectionLaws

  some Use
  some Change

  some t: Time - last, u: Unit |
    u in derivedAvailable[t] and
    u not in usedAt[t] and
    purposeAt[t, u] != purposeAt[next[t], u]

  some t: Time - first |
    some usedBefore[t] and
    some derivedAvailable[t]
}

assert LiveViewsPartitionAvailability {
  projectionLaws implies
    all t: Time, u: Unit |
      u in derivedAvailable[t]
      iff
      one p: Purpose |
        u in liveAtPurpose[t, p]
}

assert UseIsLocalToLiveView {
  projectionLaws implies
    all e: Use |
      e.unit in liveAtPurpose[e.when, e.purpose]
}

assert ConsumptionRemovesFromAllLaterLiveViews {
  projectionLaws implies
    all e: Use, t: e.when.^next, p: Purpose |
      e.unit not in liveAtPurpose[t, p]
}

assert LiveReassignmentMovesWithoutConsumption {
  projectionLaws implies
    all c: Change |
      c.unit in derivedAvailable[c.when] and
      c.unit not in usedAt[c.when]
      implies
      (c.unit in liveAtPurpose[c.when, c.from] and
       c.unit in liveAtPurpose[next[c.when], c.to])
}

pred projectedViewChangesForTwoReasons {
  projectionLaws

  some disj moved, spent: Unit, t: Time - last |
    moved in derivedAvailable[t] and
    moved not in usedAt[t] and
    purposeAt[t, moved] != purposeAt[next[t], moved] and

    spent in usedAt[t] and

    some p, q: Purpose |
      moved in liveAtPurpose[t, p] and
      moved in liveAtPurpose[next[t], q] and
      p != q and
      spent in liveAtPurpose[t, p] and
      spent not in liveAtPurpose[next[t], p]
}

run nontrivialProjectionWorld for exactly 3 Time, exactly 2 Purpose, exactly 3 Unit, 4 Use, 8 Change
check LiveViewsPartitionAvailability for exactly 4 Time, exactly 3 Purpose, exactly 4 Unit, 6 Use, 12 Change
check UseIsLocalToLiveView for exactly 4 Time, exactly 3 Purpose, exactly 4 Unit, 6 Use, 12 Change
check ConsumptionRemovesFromAllLaterLiveViews for exactly 4 Time, exactly 3 Purpose, exactly 4 Unit, 6 Use, 12 Change
check LiveReassignmentMovesWithoutConsumption for exactly 4 Time, exactly 3 Purpose, exactly 4 Unit, 6 Use, 12 Change
run projectedViewChangesForTwoReasons for exactly 3 Time, exactly 2 Purpose, exactly 3 Unit, 4 Use, 8 Change
