module model/observation_010_purpose_becomes_envelope

open util/ordering[Time]

sig Time {}
sig Purpose {}
sig Unit {}

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

pred exclusivePlacement {
  all t: Time, u: Unit |
    one u.(t.(Trace.at))
}

pred useFollowsPlacement {
  all e: Use |
    e.purpose in e.unit.(e.when.(Trace.at))
}

pred changesNameMovement {
  all t: Time - last, u: Unit, p, q: Purpose |
    (p in u.(t.(Trace.at)) and
     q in u.(next[t].(Trace.at)) and
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
    c.from in c.unit.(c.when.(Trace.at)) and
    c.to in c.unit.(next[c.when].(Trace.at))
}

pred someMovement {
  some t: Time - last, u: Unit, p, q: Purpose |
    p in u.(t.(Trace.at)) and
    q in u.(next[t].(Trace.at)) and
    p != q
}

pred baselineEnvelopeLike {
  exclusivePlacement
  useFollowsPlacement
  changesNameMovement
  some Use
  some Change
  someMovement
}

pred withoutExclusivePlacement {
  useFollowsPlacement
  changesNameMovement
  some Use
  some Change
  someMovement
  not exclusivePlacement
}

pred withoutUseBoundary {
  exclusivePlacement
  changesNameMovement
  some Change
  someMovement
  some e: Use |
    e.purpose not in e.unit.(e.when.(Trace.at))
}

pred withoutNamedMovement {
  exclusivePlacement
  useFollowsPlacement
  some Use
  some t: Time - last, u: Unit, p, q: Purpose |
    p in u.(t.(Trace.at)) and
    q in u.(next[t].(Trace.at)) and
    p != q and
    no c: Change |
      c.when = t and
      c.unit = u and
      c.from = p and
      c.to = q
}

pred repeatedUseUnderCandidateLaws {
  exclusivePlacement
  useFollowsPlacement
  changesNameMovement
  some disj e1, e2: Use |
    e1.unit = e2.unit and
    e1.when != e2.when
}

run baselineEnvelopeLike for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit, 4 Use, 8 Change
run withoutExclusivePlacement for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit, 4 Use, 8 Change
run withoutUseBoundary for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit, 4 Use, 8 Change
run withoutNamedMovement for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit, 4 Use, 8 Change
run repeatedUseUnderCandidateLaws for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit, 4 Use, 8 Change
