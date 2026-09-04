module experiments/observation_158_budget_window_coordinate

open util/ordering[Day] as ord

sig Day {}
sig Purpose {}

sig CapacityFact {
  purpose: one Purpose
}

sig ActualFact {
  purpose: one Purpose
}

sig Period {
  start: one Day,
  end: one Day
}

sig World {
  capacity: set CapacityFact,
  actual: set ActualFact,
  capDay: CapacityFact -> lone Day,
  actualDay: ActualFact -> lone Day,
  periods: set Period,
  capPeriod: CapacityFact -> lone Period,
  actualPeriod: ActualFact -> lone Period
}

one sig Left, Right extends World {}

fact RetainedFactsHaveCoordinates {
  all w: World | {
    w.capDay in w.capacity -> Day
    w.actualDay in w.actual -> Day
    all c: CapacityFact | (c in w.capacity) iff one c.(w.capDay)
    all a: ActualFact | (a in w.actual) iff one a.(w.actualDay)

    w.capPeriod in w.capacity -> w.periods
    w.actualPeriod in w.actual -> w.periods
  }
}

fact PeriodsAreHalfOpenIntervals {
  all p: Period | ord/lt[p.start, p.end]
}

pred inHalfOpen[d, start, end: Day] {
  (d = start or ord/lt[start, d])
  and ord/lt[d, end]
}

fun capacityIn[w: World, p: Purpose, start, end: Day]: set CapacityFact {
  { c: w.capacity |
    c.purpose = p and
    some d: c.(w.capDay) | inHalfOpen[d, start, end]
  }
}

fun actualIn[w: World, p: Purpose, start, end: Day]: set ActualFact {
  { a: w.actual |
    a.purpose = p and
    some d: a.(w.actualDay) | inHalfOpen[d, start, end]
  }
}

fun coordinateRemaining[w: World, p: Purpose, start, end: Day]: one Int {
  sub[#capacityIn[w, p, start, end], #actualIn[w, p, start, end]]
}

fun allHistoryRemaining[w: World, p: Purpose]: one Int {
  sub[#{ c: w.capacity | c.purpose = p }, #{ a: w.actual | a.purpose = p }]
}

fun explicitPeriodCapacity[w: World, p: Purpose, period: Period]: set CapacityFact {
  { c: w.capacity | c.purpose = p and c->period in w.capPeriod }
}

fun explicitPeriodActual[w: World, p: Purpose, period: Period]: set ActualFact {
  { a: w.actual | a.purpose = p and a->period in w.actualPeriod }
}

fun explicitPeriodRemaining[w: World, p: Purpose, period: Period]: one Int {
  sub[#explicitPeriodCapacity[w, p, period], #explicitPeriodActual[w, p, period]]
}

pred periodsDisjoint[w: World] {
  all disj left, right: w.periods |
    no d: Day |
      inHalfOpen[d, left.start, left.end]
      and inHalfOpen[d, right.start, right.end]
}

pred coordinateMembership[w: World] {
  all c: w.capacity, period: w.periods |
    (c->period in w.capPeriod) iff
      some d: c.(w.capDay) | inHalfOpen[d, period.start, period.end]

  all a: w.actual, period: w.periods |
    (a->period in w.actualPeriod) iff
      some d: a.(w.actualDay) | inHalfOpen[d, period.start, period.end]
}

pred cleanEpochCoordinateWitness {
  some p: Purpose, c: CapacityFact, disj oldActual, insideActual: ActualFact,
       start, end: Day | {
    ord/next[ord/first] = start
    end = ord/last

    Left.capacity = c
    Left.actual = oldActual + insideActual
    c.purpose = p
    oldActual.purpose = p
    insideActual.purpose = p

    Left.capDay = c->start
    Left.actualDay = oldActual->ord/first + insideActual->start

    coordinateRemaining[Left, p, start, end] = 0
    allHistoryRemaining[Left, p] = -1
  }
}

pred sameFactsDifferentDatesDifferentRemaining {
  some p: Purpose, c: CapacityFact, a: ActualFact, start, end: Day | {
    ord/next[ord/first] = start
    end = ord/last

    Left.capacity = c
    Right.capacity = c
    Left.actual = a
    Right.actual = a
    c.purpose = p
    a.purpose = p

    Left.capDay = c->start
    Right.capDay = c->start
    Left.actualDay = a->start
    Right.actualDay = a->ord/first

    coordinateRemaining[Left, p, start, end] = 0
    coordinateRemaining[Right, p, start, end] = 1
  }
}

pred parallelPeriodIdentityPressure {
  some p: Purpose, c: CapacityFact, a: ActualFact,
       disj firstPeriod, secondPeriod: Period,
       start, end: Day | {
    ord/next[ord/first] = start
    end = ord/last

    firstPeriod.start = start
    firstPeriod.end = end
    secondPeriod.start = start
    secondPeriod.end = end

    Left.capacity = c
    Left.actual = a
    Left.periods = firstPeriod + secondPeriod
    c.purpose = p
    a.purpose = p
    Left.capDay = c->start
    Left.actualDay = a->start

    Left.capPeriod = c->firstPeriod
    Left.actualPeriod = a->secondPeriod

    coordinateRemaining[Left, p, firstPeriod.start, firstPeriod.end] = 0
    coordinateRemaining[Left, p, secondPeriod.start, secondPeriod.end] = 0
    explicitPeriodRemaining[Left, p, firstPeriod] = 1
    explicitPeriodRemaining[Left, p, secondPeriod] = -1
  }
}

assert DisjointCoordinateMembershipMatches {
  all w: World |
    periodsDisjoint[w] and coordinateMembership[w] implies
      all p: Purpose, period: w.periods |
        explicitPeriodRemaining[w, p, period] =
          coordinateRemaining[w, p, period.start, period.end]
}

assert SameWindowCoordinatesSameCoordinateAnswer {
  all w: World, p: Purpose, leftPeriod, rightPeriod: Period |
    leftPeriod.start = rightPeriod.start and
    leftPeriod.end = rightPeriod.end implies
      coordinateRemaining[w, p, leftPeriod.start, leftPeriod.end] =
        coordinateRemaining[w, p, rightPeriod.start, rightPeriod.end]
}

run cleanEpochCoordinateWitness for exactly 3 Day, exactly 2 Purpose, exactly 3 CapacityFact, exactly 3 ActualFact, exactly 2 Period, exactly 2 World, 5 Int
run sameFactsDifferentDatesDifferentRemaining for exactly 3 Day, exactly 2 Purpose, exactly 3 CapacityFact, exactly 3 ActualFact, exactly 2 Period, exactly 2 World, 5 Int
run parallelPeriodIdentityPressure for exactly 3 Day, exactly 2 Purpose, exactly 3 CapacityFact, exactly 3 ActualFact, exactly 2 Period, exactly 2 World, 5 Int
check DisjointCoordinateMembershipMatches for exactly 3 Day, exactly 2 Purpose, exactly 3 CapacityFact, exactly 3 ActualFact, exactly 2 Period, exactly 2 World, 5 Int
check SameWindowCoordinatesSameCoordinateAnswer for exactly 3 Day, exactly 2 Purpose, exactly 3 CapacityFact, exactly 3 ActualFact, exactly 2 Period, exactly 2 World, 5 Int
