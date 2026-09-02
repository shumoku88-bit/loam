module experiments/observation_092_origin_relative_time_cut

open util/ordering[Moment] as MO

abstract sig Event {}
one sig Origin, X, Y extends Event {}

sig Moment {}

abstract sig Phase {}
one sig Before, At, After extends Phase {}

abstract sig World {
  retained : set Event,
  actualBefore : Event -> Event,
  coarseTime : Event -> one Moment,
  cut : Event -> one Phase
}
one sig Left, Right extends World {}

fact RetainedSnapshot {
  all w : World | w.retained = Event
}

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

fact CoarseTimeRespectsActualOrder {
  all w : World |
    all disj e1, e2 : Event |
      e1->e2 in w.actualBefore implies
        (e1.(w.coarseTime) = e2.(w.coarseTime)
         or MO/lt[e1.(w.coarseTime), e2.(w.coarseTime)])
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

fun postOrigin[w : World] : set Event {
  Origin + Origin.^(w.actualBefore)
}

fun postByCut[w : World] : set Event {
  { e : Event | e.(w.cut) = At or e.(w.cut) = After }
}

pred injectiveTime[w : World] {
  all disj e1, e2 : Event |
    e1.(w.coarseTime) != e2.(w.coarseTime)
}

pred injectiveTimeWitness {
  injectiveTime[Left]
}

pred sameUnorderedSnapshotDifferentPostOrigin {
  Left.retained = Right.retained
  postOrigin[Left] != postOrigin[Right]
}

pred sameCoarseTimeDifferentPostOrigin {
  Left.coarseTime = Right.coarseTime
  postOrigin[Left] != postOrigin[Right]
  some e : Event - Origin |
    e.(Left.coarseTime) = Origin.(Left.coarseTime)
}

pred sameCutDifferentGlobalOrder {
  Left.cut = Right.cut
  Left.cut[X] = After
  Left.cut[Y] = After
  Left.actualBefore != Right.actualBefore
}

assert UnorderedSnapshotDeterminesPostOrigin {
  all disj w1, w2 : World |
    w1.retained = w2.retained implies
      postOrigin[w1] = postOrigin[w2]
}

assert CoarseTimeDeterminesPostOrigin {
  all disj w1, w2 : World |
    (w1.retained = w2.retained
     and w1.coarseTime = w2.coarseTime) implies
      postOrigin[w1] = postOrigin[w2]
}

assert InjectiveMonotoneTimeDeterminesPostOrigin {
  all disj w1, w2 : World |
    (w1.retained = w2.retained
     and w1.coarseTime = w2.coarseTime
     and injectiveTime[w1]
     and injectiveTime[w2]) implies
      postOrigin[w1] = postOrigin[w2]
}

assert OriginRelativeCutMatchesScope {
  all w : World |
    postByCut[w] = postOrigin[w]
}

assert OriginRelativeCutDeterminesPostOrigin {
  all disj w1, w2 : World |
    w1.cut = w2.cut implies
      postOrigin[w1] = postOrigin[w2]
}

run injectiveTimeWitness for exactly 3 Moment
run sameUnorderedSnapshotDifferentPostOrigin for exactly 3 Moment
run sameCoarseTimeDifferentPostOrigin for exactly 3 Moment
run sameCutDifferentGlobalOrder for exactly 3 Moment
check UnorderedSnapshotDeterminesPostOrigin for exactly 3 Moment
check CoarseTimeDeterminesPostOrigin for exactly 3 Moment
check InjectiveMonotoneTimeDeterminesPostOrigin for exactly 3 Moment
check OriginRelativeCutMatchesScope for exactly 3 Moment
check OriginRelativeCutDeterminesPostOrigin for exactly 3 Moment
