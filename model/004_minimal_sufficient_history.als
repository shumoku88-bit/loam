module model/observation_004_minimal_sufficient_history

open util/ordering[Time]

sig Time {}
abstract sig Purpose {}
one sig Target, Other extends Purpose {}
abstract sig Unit {}
one sig U0, U1 extends Unit {}

one sig Left {
  at: Time -> Unit -> Purpose
}

one sig Right {
  at: Time -> Unit -> Purpose
}

fun leftPurposeAt[t: Time, u: Unit]: one Purpose {
  u.(t.(Left.at))
}

fun rightPurposeAt[t: Time, u: Unit]: one Purpose {
  u.(t.(Right.at))
}

fun leftStayedAtTarget: set Unit {
  { u: Unit | all t: Time | leftPurposeAt[t, u] = Target }
}

fun rightStayedAtTarget: set Unit {
  { u: Unit | all t: Time | rightPurposeAt[t, u] = Target }
}

fact CompletePlacement {
  all t: Time, u: Unit |
    one u.(t.(Left.at)) and
    one u.(t.(Right.at))
}

pred sameCurrentPlacement {
  all u: Unit |
    leftPurposeAt[last, u] = rightPurposeAt[last, u]
}

pred sameStayedCount {
  # leftStayedAtTarget = # rightStayedAtTarget
}

pred u0ContinuityDiffers {
  (U0 in leftStayedAtTarget) iff
    (U0 not in rightStayedAtTarget)
}

pred bothHistoriesMove {
  (some t: Time - last, u: Unit |
    leftPurposeAt[t, u] != leftPurposeAt[next[t], u])
  and
  (some t: Time - last, u: Unit |
    rightPurposeAt[t, u] != rightPurposeAt[next[t], u])
}

pred countSummaryCollision {
  sameCurrentPlacement
  sameStayedCount
  u0ContinuityDiffers
  bothHistoriesMove
}

run countSummaryCollision for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit
