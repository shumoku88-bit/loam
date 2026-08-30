module model/observation_039_factor_time_and_explanation

abstract sig Time {}
one sig T0, T1, T2, T3 extends Time {}

abstract sig Event {}
one sig A, B, C, D, R extends Event {}

abstract sig World {
  learned: Event -> one Time,
  parent: Event -> set Event
}

one sig Left, Right extends World {}

fun elapsed[t: Time]: set Time {
  t = T0 => T0 else
  t = T1 => T0 + T1 else
  t = T2 => T0 + T1 + T2 else
  Time
}

fun previous[t: Time]: lone Time {
  t = T1 => T0 else
  t = T2 => T1 else
  t = T3 => T2 else
  none
}

fact WellFormed {
  all w: World | {
    A.(w.learned) = T0
    B.(w.learned) = T0
    C.(w.learned) in T1 + T2
    D.(w.learned) in T1 + T2
    R.(w.learned) = T3

    no A.(w.parent)
    no B.(w.parent)

    one C.(w.parent)
    one D.(w.parent)
    C.(w.parent) in A + B
    D.(w.parent) in A + B
    C.(w.parent) != D.(w.parent)

    R.(w.parent) = C + D

    no iden & ^(w.parent)
  }
}

fun known[w: World, t: Time]: set Event {
  { e: Event | e.(w.learned) in elapsed[t] }
}

fun superseded[w: World, t: Time]: set Event {
  known[w, t].(w.parent)
}

fun frontier[w: World, t: Time]: set Event {
  known[w, t] - superseded[w, t]
}

pred changedAt[w: World, t: Time] {
  t = T0 or frontier[w, t] != frontier[w, previous[t]]
}

fun sparseIndex[w: World]: Time -> Event {
  { t: Time, e: Event |
      changedAt[w, t] and e in frontier[w, t] }
}

fun whyAsOf[w: World, t: Time]: Event -> Event {
  frontier[w, t] <: ^(w.parent)
}

pred sameSparseIndex[a, b: World] {
  sparseIndex[a] = sparseIndex[b]
}

pred sameGraph[a, b: World] {
  a.parent = b.parent
}

pred sameSelectedAnswers[a, b: World] {
  all t: Time | {
    frontier[a, t] = frontier[b, t]
    whyAsOf[a, t] = whyAsOf[b, t]
  }
}

pred factorizedMemoryCarriesHistoricalMeaning {
  C.(Left.learned) = T1
  D.(Left.learned) = T2

  frontier[Left, T0] = A + B
  #frontier[Left, T1] = 2
  frontier[Left, T2] = C + D
  frontier[Left, T3] = R

  R->C in whyAsOf[Left, T3]
  R->D in whyAsOf[Left, T3]
  some (R->(A + B)) & whyAsOf[Left, T3]
}

pred sameSparseIndexDifferentExplanation {
  sameSparseIndex[Left, Right]
  Left.parent != Right.parent
  some t: Time | whyAsOf[Left, t] != whyAsOf[Right, t]
}

pred sameGraphDifferentSparseIndex {
  sameGraph[Left, Right]
  sparseIndex[Left] != sparseIndex[Right]
  some t: Time | frontier[Left, t] != frontier[Right, t]
}

assert SparseIndexDeterminesFrontier {
  sameSparseIndex[Left, Right] implies
    all t: Time | frontier[Left, t] = frontier[Right, t]
}

assert TimelessGraphDoesNotLeakFuture {
  all w: World, t: Time, e: frontier[w, t] |
    e.^(w.parent) in known[w, t]
}

assert FactorizedMemoryDeterminesSelectedVocabulary {
  (sameSparseIndex[Left, Right] and sameGraph[Left, Right]) implies
    sameSelectedAnswers[Left, Right]
}

run factorizedMemoryCarriesHistoricalMeaning for exactly 4 Time, exactly 5 Event, exactly 2 World
run sameSparseIndexDifferentExplanation for exactly 4 Time, exactly 5 Event, exactly 2 World
run sameGraphDifferentSparseIndex for exactly 4 Time, exactly 5 Event, exactly 2 World
check SparseIndexDeterminesFrontier for exactly 4 Time, exactly 5 Event, exactly 2 World
check TimelessGraphDoesNotLeakFuture for exactly 4 Time, exactly 5 Event, exactly 2 World
check FactorizedMemoryDeterminesSelectedVocabulary for exactly 4 Time, exactly 5 Event, exactly 2 World
