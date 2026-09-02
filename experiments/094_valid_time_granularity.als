module experiments/observation_094_valid_time_granularity

open util/ordering[Day] as DO

abstract sig Event {}
one sig Origin, X, Y extends Event {}

sig Day {}

abstract sig Phase {}
one sig Before, At, After extends Phase {}

abstract sig World {
  validDay : Event -> one Day,
  actualBefore : Event -> Event,
  cut : Event -> one Phase
}
one sig Left, Right extends World {}

fact ActualOrderIsStrictTotal {
  all w : World {
    no iden & w.actualBefore
    all e1, e2, e3 : Event |
      (e1->e2 in w.actualBefore and e2->e3 in w.actualBefore) implies
        e1->e3 in w.actualBefore
    all disj e1, e2 : Event |
      e1->e2 in w.actualBefore or e2->e1 in w.actualBefore
  }
}

fact ValidDayRespectsActualOrderAcrossDays {
  all w : World |
    all disj e1, e2 : Event |
      e1->e2 in w.actualBefore implies
        (e1.(w.validDay) = e2.(w.validDay)
         or DO/lt[e1.(w.validDay), e2.(w.validDay)])
}

fact CutMatchesOriginRelativeOrder {
  all w : World {
    Origin.(w.cut) = At
    all e : Event - Origin |
      (e->Origin in w.actualBefore iff e.(w.cut) = Before)
      and
      (Origin->e in w.actualBefore iff e.(w.cut) = After)
  }
}

fun dayMembers[w : World, d : Day] : set Event {
  { e : Event | e.(w.validDay) = d }
}

fun postOrigin[w : World] : set Event {
  Origin + Origin.^(w.actualBefore)
}

fun postByCut[w : World] : set Event {
  { e : Event | e.(w.cut) = At or e.(w.cut) = After }
}

pred sameDayOriginBoundaryWitness {
  X.(Left.validDay) = Origin.(Left.validDay)
  Y.(Left.validDay) = Origin.(Left.validDay)
  X.(Left.cut) = Before
  Y.(Left.cut) = After
}

pred sameValidDayDifferentPostOrigin {
  Left.validDay = Right.validDay
  postOrigin[Left] != postOrigin[Right]
  X.(Left.validDay) = Origin.(Left.validDay)
}

pred sameDateAndCutDifferentGlobalOrder {
  Left.validDay = Right.validDay
  Left.cut = Right.cut
  X.(Left.cut) = After
  Y.(Left.cut) = After
  Left.actualBefore != Right.actualBefore
}

assert ValidDayDeterminesDayProjection {
  all disj w1, w2 : World |
    w1.validDay = w2.validDay implies
      all d : Day | dayMembers[w1, d] = dayMembers[w2, d]
}

assert ValidDayDeterminesPostOrigin {
  all disj w1, w2 : World |
    w1.validDay = w2.validDay implies
      postOrigin[w1] = postOrigin[w2]
}

assert CutMatchesPostOrigin {
  all w : World |
    postByCut[w] = postOrigin[w]
}

assert ValidDayAndCutDetermineBothQueries {
  all disj w1, w2 : World |
    (w1.validDay = w2.validDay and w1.cut = w2.cut) implies {
      all d : Day | dayMembers[w1, d] = dayMembers[w2, d]
      postOrigin[w1] = postOrigin[w2]
    }
}

run sameDayOriginBoundaryWitness for exactly 2 Day
run sameValidDayDifferentPostOrigin for exactly 2 Day
run sameDateAndCutDifferentGlobalOrder for exactly 2 Day
check ValidDayDeterminesDayProjection for exactly 2 Day
check ValidDayDeterminesPostOrigin for exactly 2 Day
check CutMatchesPostOrigin for exactly 2 Day
check ValidDayAndCutDetermineBothQueries for exactly 2 Day
