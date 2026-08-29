module model/observation_005_vocabulary_induced_state

open util/ordering[Time]

sig Time {}
abstract sig Purpose {}
one sig Target, Other extends Purpose {}
abstract sig Unit {}
one sig U0, U1 extends Unit {}

one sig H00 { at: Time -> Unit -> Purpose }
one sig H10 { at: Time -> Unit -> Purpose }
one sig H01 { at: Time -> Unit -> Purpose }
one sig H11 { at: Time -> Unit -> Purpose }

fun purposeAt[r: Time -> Unit -> Purpose, t: Time, u: Unit]: one Purpose {
  u.(t.r)
}

fun stayedAtTarget[r: Time -> Unit -> Purpose]: set Unit {
  { u: Unit | all t: Time | purposeAt[r, t, u] = Target }
}

pred complete[r: Time -> Unit -> Purpose] {
  all t: Time, u: Unit | one purposeAt[r, t, u]
}

pred finishesAtTarget[r: Time -> Unit -> Purpose] {
  all u: Unit | purposeAt[r, last, u] = Target
}

fact CompletePlacements {
  complete[H00.at]
  complete[H10.at]
  complete[H01.at]
  complete[H11.at]
}

pred fourVisibleClasses {
  finishesAtTarget[H00.at]
  finishesAtTarget[H10.at]
  finishesAtTarget[H01.at]
  finishesAtTarget[H11.at]

  no stayedAtTarget[H00.at]
  stayedAtTarget[H10.at] = U0
  stayedAtTarget[H01.at] = U1
  stayedAtTarget[H11.at] = U0 + U1
}

run fourVisibleClasses for exactly 3 Time, exactly 2 Purpose, exactly 2 Unit
