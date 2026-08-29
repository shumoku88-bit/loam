module model/observation_002_same_projection_distinct_history

open util/ordering[Time]

sig Time {}
sig Purpose {}
sig Unit {}

abstract sig Trace {
  at: Time -> Unit -> Purpose
}

one sig Left, Right extends Trace {}

fun purposeAt[tr: Trace, t: Time, u: Unit]: set Purpose {
  u.(t.(tr.at))
}

fun membersAt[tr: Trace, t: Time, p: Purpose]: set Unit {
  { u: Unit | purposeAt[tr, t, u] = p }
}

fact EveryUnitHasOnePurposeAtEveryTimeInEveryTrace {
  all tr: Trace, t: Time, u: Unit |
    one purposeAt[tr, t, u]
}

pred sameCountProjection {
  all t: Time, p: Purpose |
    # membersAt[Left, t, p] = # membersAt[Right, t, p]
}

pred distinctIdentityHistory {
  some t: Time, u: Unit |
    purposeAt[Left, t, u] != purposeAt[Right, t, u]
}

pred persistentAt[tr: Trace, u: Unit, p: Purpose] {
  all t: Time |
    purposeAt[tr, t, u] = p
}

pred differentContinuityAtSamePurpose {
  some p: Purpose |
    (some u: Unit | persistentAt[Left, u, p]) and
    (no u: Unit | persistentAt[Right, u, p])
}

pred bothHistoriesMove {
  all tr: Trace |
    some t: Time - last, u: Unit |
      purposeAt[tr, t, u] != purposeAt[tr, next[t], u]
}

pred observationalCollision {
  sameCountProjection
  distinctIdentityHistory
  differentContinuityAtSamePurpose
  bothHistoriesMove
}

run observationalCollision for exactly 3 Time, exactly 2 Purpose, exactly 4 Unit
