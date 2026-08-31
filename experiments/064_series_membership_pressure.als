module experiments/observation_064_series_membership_pressure

sig Time {}
sig Shape {}

abstract sig Recurrence {}
one sig Once, Monthly, Cycle extends Recurrence {}

sig Series {}

sig Plan {
  expectedTime: one Time,
  expectedAmount: one Int,
  expectedShape: one Shape,
  recurrence: one Recurrence
}

sig World {
  seriesOf: Plan -> Series
}

one sig Left, Right extends World {}

fact EveryPlanHasExactlyOneSeries {
  all w: World, p: Plan | one p.(w.seriesOf)
}

fact NonzeroAmounts {
  all p: Plan | p.expectedAmount != 0
}

fun peers[w: World, p: Plan]: set Plan {
  { q: Plan - p | q.(w.seriesOf) = p.(w.seriesOf) }
}

pred representativeSeriesPressure {
  some disj first, later, parallel: Plan | {
    first.recurrence = Monthly
    later.recurrence = Monthly
    parallel.recurrence = Monthly

    first.expectedShape = later.expectedShape
    first.expectedShape = parallel.expectedShape

    first.expectedTime != later.expectedTime
    first.expectedAmount != later.expectedAmount

    first.(Left.seriesOf) = later.(Left.seriesOf)
    first.(Left.seriesOf) != parallel.(Left.seriesOf)
  }
}

pred sameRecordsDifferentGrouping {
  Left.seriesOf != Right.seriesOf
  some p: Plan | peers[Left, p] != peers[Right, p]
}

pred changingAmountWithinSeries {
  some disj p, q: Plan | {
    p.(Left.seriesOf) = q.(Left.seriesOf)
    p.expectedAmount != q.expectedAmount
  }
}

pred sameRecurrenceAndShapeDifferentSeries {
  some disj p, q: Plan | {
    p.recurrence = q.recurrence
    p.expectedShape = q.expectedShape
    p.(Left.seriesOf) != q.(Left.seriesOf)
  }
}

assert PlanRecordsDetermineSeriesGrouping {
  Left.seriesOf = Right.seriesOf
}

assert SameRecurrenceAndShapeMeansSameSeries {
  all p, q: Plan |
    p.recurrence = q.recurrence and
    p.expectedShape = q.expectedShape
      implies p.(Left.seriesOf) = q.(Left.seriesOf)
}

assert SeriesMembershipRequiresFixedAmount {
  all p, q: Plan |
    p.(Left.seriesOf) = q.(Left.seriesOf)
      implies p.expectedAmount = q.expectedAmount
}

assert ExplicitSeriesRelationDeterminesPeerAnswers {
  Left.seriesOf = Right.seriesOf implies
    all p: Plan | peers[Left, p] = peers[Right, p]
}

run representativeSeriesPressure for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
run sameRecordsDifferentGrouping for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
run changingAmountWithinSeries for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
run sameRecurrenceAndShapeDifferentSeries for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
check PlanRecordsDetermineSeriesGrouping for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
check SameRecurrenceAndShapeMeansSameSeries for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
check SeriesMembershipRequiresFixedAmount for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
check ExplicitSeriesRelationDeterminesPeerAnswers for exactly 4 Plan, exactly 3 Series, exactly 3 Time, exactly 2 Shape, exactly 2 World, 6 Int
