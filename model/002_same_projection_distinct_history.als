module model/observation_002_same_projection_distinct_history

open util/ordering[Time]

sig Time {}
sig Purpose {}
sig Unit {}

one sig Left {
  at: Time -> Unit -> Purpose
}

one sig Right {
  at: Time -> Unit -> Purpose
}

fun purposeAt[placement: Time -> Unit -> Purpose, t: Time, u: Unit]: set Purpose {
  u.(t.placement)
}

fun membersAt[placement: Time -> Unit -> Purpose, t: Time, p: Purpose]: set Unit {
  { u: Unit | purposeAt[placement, t, u] = p }
}

fact EveryUnitHasOnePurposeAtEveryTimeInBothHistories {
  all t: Time, u: Unit |
    one purposeAt[Left.at, t, u] and
    one purposeAt[Right.at, t, u]
}

pred sameCountProjection {
  all t: Time, p: Purpose |
    # membersAt[Left.at, t, p] = # membersAt[Right.at, t, p]
}

pred distinctIdentityHistory {
  some t: Time, u: Unit |
    purposeAt[Left.at, t, u] != purposeAt[Right.at, t, u]
}

pred persistentAt[placement: Time -> Unit -> Purpose, u: Unit, p: Purpose] {
  all t: Time |
    purposeAt[placement, t, u] = p
}

pred differentContinuityAtSamePurpose {
  some p: Purpose |
    (some u: Unit | persistentAt[Left.at, u, p]) and
    (no u: Unit | persistentAt[Right.at, u, p])
}

pred bothHistoriesMove {
  some t: Time - last, u: Unit |
    purposeAt[Left.at, t, u] != purposeAt[Left.at, next[t], u]

  some t: Time - last, u: Unit |
    purposeAt[Right.at, t, u] != purposeAt[Right.at, next[t], u]
}

pred observationalCollision {
  sameCountProjection
  distinctIdentityHistory
  differentContinuityAtSamePurpose
  bothHistoriesMove
}

run observationalCollision for exactly 3 Time, exactly 2 Purpose, exactly 4 Unit
