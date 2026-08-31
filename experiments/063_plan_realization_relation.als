module experiments/observation_063_plan_realization_relation

abstract sig Time {}
abstract sig Shape {}

sig Plan {
  expectedTime: one Time,
  expectedAmount: one Int,
  expectedShape: one Shape
}

sig Event {
  actualTime: one Time,
  actualAmount: one Int,
  actualShape: one Shape
}

sig World {
  realizes: Plan -> lone Event
}

one sig Left, Right extends World {}

fact NonzeroAmounts {
  all p: Plan | p.expectedAmount != 0
  all e: Event | e.actualAmount != 0
}

fact RealizationIsPartialMatching {
  all w: World, e: Event | lone e.~(w.realizes)
}

fun completed[w: World]: set Plan {
  { p: Plan | some p.(w.realizes) }
}

fun realizedEvents[w: World]: set Event {
  { e: Event | some e.~(w.realizes) }
}

fun amountMismatch[w: World]: set Plan {
  { p: Plan |
    some e: p.(w.realizes) |
      p.expectedAmount != e.actualAmount
  }
}

fun timeMismatch[w: World]: set Plan {
  { p: Plan |
    some e: p.(w.realizes) |
      p.expectedTime != e.actualTime
  }
}

fun shapeMismatch[w: World]: set Plan {
  { p: Plan |
    some e: p.(w.realizes) |
      p.expectedShape != e.actualShape
  }
}

fun exactCandidates[p: Plan]: set Event {
  { e: Event |
    p.expectedTime = e.actualTime and
    p.expectedAmount = e.actualAmount and
    p.expectedShape = e.actualShape
  }
}

pred realizationCanLinkNonidenticalRecords {
  some p: Plan, e: Event | {
    p->e in Left.realizes
    p.expectedShape = e.actualShape
    p.expectedTime != e.actualTime
    p.expectedAmount != e.actualAmount
  }
}

pred sameRecordsDifferentCompletion {
  completed[Left] != completed[Right]
}

pred sameCompletionDifferentRealization {
  completed[Left] = Plan
  completed[Right] = Plan
  Left.realizes != Right.realizes
}

pred sameActualCanBePlannedOrUnplanned {
  some e: Event |
    e in realizedEvents[Left] and
    e not in realizedEvents[Right]
}

pred exactContentCanBeAmbiguous {
  some p: Plan | {
    #exactCandidates[p] >= 2
    one p.(Left.realizes)
    p.(Left.realizes) in exactCandidates[p]
  }
}

assert PlanEventRecordsDetermineCompletion {
  completed[Left] = completed[Right]
}

assert CompletionSummaryDeterminesRealization {
  completed[Left] = completed[Right] implies
    Left.realizes = Right.realizes
}

assert ExplicitRelationDeterminesSelectedAnswers {
  Left.realizes = Right.realizes implies {
    completed[Left] = completed[Right]
    realizedEvents[Left] = realizedEvents[Right]
    amountMismatch[Left] = amountMismatch[Right]
    timeMismatch[Left] = timeMismatch[Right]
    shapeMismatch[Left] = shapeMismatch[Right]
  }
}

run realizationCanLinkNonidenticalRecords for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
run sameRecordsDifferentCompletion for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
run sameCompletionDifferentRealization for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
run sameActualCanBePlannedOrUnplanned for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
run exactContentCanBeAmbiguous for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
check PlanEventRecordsDetermineCompletion for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
check CompletionSummaryDeterminesRealization for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
check ExplicitRelationDeterminesSelectedAnswers for exactly 3 Plan, exactly 3 Event, exactly 2 Time, exactly 2 Shape, exactly 2 World, 5 Int
