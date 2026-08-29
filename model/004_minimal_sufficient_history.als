module model/004_minimal_sufficient_history

open util/ordering[Time]

sig Time {}
abstract sig Purpose {}
one sig Target, Other extends Purpose {}
abstract sig Unit {}
one sig U0, U1 extends Unit {}

abstract sig Trace {
  at: Time -> Unit -> Purpose
}

one sig Left, Right extends Trace {}

fun purposeAt[tr: Trace, t: Time, u: Unit]: one Purpose {
  u.(t.(tr.at))
}

fun stayedAtTarget[tr: Trace]: set Unit {
  { u: Unit | all t: Time | purposeAt[tr, t, u] = Target }
}

fact CompletePlacement {
  all tr: Trace, t: Time, u: Unit |
    one u.(t.(tr.at))
}

pred sameCurrentPlacement {
  all u: Unit |
    purposeAt[Left, last, u] = purposeAt[Right, last, u]
}

pred sameStayedCount {
  # stayedAtTarget[Left] = # stayedAtTarget[Right]
}

pred u0ContinuityDiffers {
  (U0 in stayedAtTarget[Left]) iff
    (U0 not in stayedAtTarget[Right])
}

pred bothHistoriesMove {
  all tr: Trace |
    some t: Time - last, u: Unit |
      purposeAt[tr, t, u] != purposeAt[tr, next[t], u]
}

pred countSummaryCollision {
  sameCurrentPlacement
  sameStayedCount
  u0ContinuityDiffers
  bothHistoriesMove
}

run countSummaryCollision for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit
