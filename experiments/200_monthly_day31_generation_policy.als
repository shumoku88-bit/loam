module experiments/observation_200_monthly_day31_generation_policy

-- F055 asks whether Series membership plus recurring Plan shape determines
-- what happens when a nominal monthly day does not exist in one month.
--
-- The model deliberately avoids a full calendar. JanLike and MarLike merely
-- stand for neighboring months where day 31 exists; Short stands for a month
-- where it does not. The selected question is information independence, not
-- calendar arithmetic.

sig Series {}

abstract sig Recurrence {}
one sig Monthly extends Recurrence {}

abstract sig Day {}
one sig Day31, LastDay extends Day {}

abstract sig GenerationPolicy {}
one sig SkipMissing, ClampLast extends GenerationPolicy {}

sig World {
  memberOf: one Series,
  recurrence: one Recurrence,
  nominalDay: one Day,
  observedJanLike: one Day,
  observedMarLike: one Day,
  policy: one GenerationPolicy,
  generatedShort: lone Day
}

one sig Left, Right extends World {}
one sig S extends Series {}

fact CommonShape {
  all w: World | {
    w.memberOf = S
    w.recurrence = Monthly
    w.nominalDay = Day31
    w.observedJanLike = Day31
    w.observedMarLike = Day31

    w.policy = SkipMissing implies no w.generatedShort
    w.policy = ClampLast implies w.generatedShort = LastDay
  }
}

pred representativeClampAtShortMonth {
  Left.policy = ClampLast
  Left.generatedShort = LastDay
}

pred sameSeriesAndObservedPatternDifferentBoundary {
  Left.memberOf = Right.memberOf
  Left.recurrence = Right.recurrence
  Left.nominalDay = Right.nominalDay
  Left.observedJanLike = Right.observedJanLike
  Left.observedMarLike = Right.observedMarLike

  Left.policy = SkipMissing
  Right.policy = ClampLast

  no Left.generatedShort
  Right.generatedShort = LastDay
}

-- Deliberately too strong: same Series membership, recurrence kind, nominal
-- day and neighboring observed occurrences do not force one short-month
-- generation result.
assert ExistingSeriesEvidenceDeterminesShortMonthGeneration {
  Left.memberOf = Right.memberOf and
  Left.recurrence = Right.recurrence and
  Left.nominalDay = Right.nominalDay and
  Left.observedJanLike = Right.observedJanLike and
  Left.observedMarLike = Right.observedMarLike implies
    Left.generatedShort = Right.generatedShort
}

-- The same observed day-31 pattern on both sides of the boundary does not
-- reconstruct which boundary policy applies.
assert NeighboringOccurrencesDetermineGenerationPolicy {
  Left.memberOf = Right.memberOf and
  Left.recurrence = Right.recurrence and
  Left.nominalDay = Right.nominalDay and
  Left.observedJanLike = Right.observedJanLike and
  Left.observedMarLike = Right.observedMarLike implies
    Left.policy = Right.policy
}

-- Positive sufficiency check for the selected vocabulary. Once the generation
-- policy is fixed, the short-month result is fixed in this bounded model.
assert ExplicitGenerationPolicyDeterminesBoundary {
  Left.memberOf = Right.memberOf and
  Left.recurrence = Right.recurrence and
  Left.nominalDay = Right.nominalDay and
  Left.policy = Right.policy implies
    Left.generatedShort = Right.generatedShort
}

run representativeClampAtShortMonth for exactly 1 Series, exactly 2 World
run sameSeriesAndObservedPatternDifferentBoundary for exactly 1 Series, exactly 2 World
check ExistingSeriesEvidenceDeterminesShortMonthGeneration for exactly 1 Series, exactly 2 World
check NeighboringOccurrencesDetermineGenerationPolicy for exactly 1 Series, exactly 2 World
check ExplicitGenerationPolicyDeterminesBoundary for exactly 1 Series, exactly 2 World
