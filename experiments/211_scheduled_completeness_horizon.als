module experiments/observation_211_scheduled_completeness_horizon

-- Household pressure:
-- finite explicit Scheduled occurrences do not say whether an absent future
-- occurrence is truly absent or merely not materialized yet.
--
-- `actualDue` is observation-local ground truth used only to test information
-- sufficiency. It is not a proposed LOAM production fact.
--
-- `completeThrough` is likewise observation vocabulary. It means that, for
-- every subject and month in the covered prefix, every actually-due occurrence
-- is represented explicitly in Scheduled. It is deliberately different from
-- LOAM's existing epistemic `known-through` horizon.

abstract sig Subject {}
one sig Rent, Subscription extends Subject {}

abstract sig Month {}
one sig Sep, Oct, Nov, Dec extends Month {}

sig World {
  actualDue: Subject -> set Month,
  explicit: Subject -> set Month,
  completeThrough: lone Month
}

one sig Left, Right extends World {}

fun prefix[m: Month]: set Month {
  { x: Month |
    (m = Sep and x = Sep) or
    (m = Oct and x in Sep + Oct) or
    (m = Nov and x in Sep + Oct + Nov) or
    (m = Dec and x in Sep + Oct + Nov + Dec)
  }
}

fun coveredMonths[w: World]: set Month {
  { m: Month | some h: w.completeThrough | m in prefix[h] }
}

fact ExplicitScheduledIsRealDueEvidence {
  all w: World | w.explicit in w.actualDue
}

fact CompletenessClaimMeansExactCoverage {
  all w: World, h: Month |
    w.completeThrough = h implies
      (w.actualDue & (Subject -> prefix[h])) =
      (w.explicit & (Subject -> prefix[h]))
}

-- A source-shaped rent specimen: September and November are explicit while
-- October is absent. A global completeness claim through November makes that
-- October absence meaningful without storing a recurrence rule.
pred representativeCoveredBimonthlyLikeRent {
  Left.completeThrough = Nov
  Rent->Sep in Left.explicit
  Rent->Oct not in Left.explicit
  Rent->Nov in Left.explicit
  Subscription->Oct in Left.explicit
}

-- Same finite Scheduled evidence, different truth about October rent.
-- This is the ambiguity an AI must not resolve by silently assuming monthly or
-- bimonthly recurrence.
pred sameExplicitNoCoverageDifferentOctoberRent {
  no Left.completeThrough
  no Right.completeThrough
  Left.explicit = Right.explicit

  Rent->Sep in Left.explicit
  Rent->Nov in Left.explicit
  Rent->Oct not in Left.explicit

  Rent->Oct not in Left.actualDue
  Rent->Oct in Right.actualDue
}

-- A completeness horizon intentionally says nothing beyond itself. Two worlds
-- can agree completely through October and still disagree about November.
pred sameExplicitAndCoverageDifferentBeyond {
  Left.completeThrough = Oct
  Right.completeThrough = Oct
  Left.explicit = Right.explicit

  Rent->Sep in Left.explicit
  Rent->Nov not in Left.explicit
  Rent->Nov not in Left.actualDue
  Rent->Nov in Right.actualDue
}

-- Positive explicit evidence is sound in every admitted world.
assert ExplicitScheduledDeterminesPositiveDue {
  all w: World, s: Subject, m: Month |
    s->m in w.explicit implies s->m in w.actualDue
}

-- Deliberately too strong closed-world reading. Absence from finite Scheduled
-- does not establish NotDue when no completeness evidence covers the query.
assert ExplicitAbsenceDeterminesNotDue {
  all w: World, s: Subject, m: Month |
    s->m not in w.explicit implies s->m not in w.actualDue
}

-- Within a claimed complete prefix, absence is a sound negative answer.
assert CoveredAbsenceDeterminesNotDue {
  all w: World, s: Subject, m: Month |
    m in coveredMonths[w] and s->m not in w.explicit implies
      s->m not in w.actualDue
}

-- Equal explicit Scheduled evidence plus the same completeness horizon fixes
-- the due/not-due truth inside that covered prefix.
assert SameExplicitAndCoverageDetermineCoveredTruth {
  all h: Month |
    Left.explicit = Right.explicit and
    Left.completeThrough = h and
    Right.completeThrough = h implies
      (Left.actualDue & (Subject -> prefix[h])) =
      (Right.actualDue & (Subject -> prefix[h]))
}

-- Deliberately too strong. Even when both worlds really carry the same nonempty
-- completeness horizon, that bounded claim is not recurrence and does not
-- determine due truth outside the covered prefix.
assert CoverageDeterminesAllFutureTruth {
  (some h: Month |
    Left.explicit = Right.explicit and
    Left.completeThrough = h and
    Right.completeThrough = h) implies
      Left.actualDue = Right.actualDue
}

run representativeCoveredBimonthlyLikeRent for exactly 2 Subject, exactly 4 Month, exactly 2 World
run sameExplicitNoCoverageDifferentOctoberRent for exactly 2 Subject, exactly 4 Month, exactly 2 World
run sameExplicitAndCoverageDifferentBeyond for exactly 2 Subject, exactly 4 Month, exactly 2 World
check ExplicitScheduledDeterminesPositiveDue for exactly 2 Subject, exactly 4 Month, exactly 2 World
check ExplicitAbsenceDeterminesNotDue for exactly 2 Subject, exactly 4 Month, exactly 2 World
check CoveredAbsenceDeterminesNotDue for exactly 2 Subject, exactly 4 Month, exactly 2 World
check SameExplicitAndCoverageDetermineCoveredTruth for exactly 2 Subject, exactly 4 Month, exactly 2 World
check CoverageDeterminesAllFutureTruth for exactly 2 Subject, exactly 4 Month, exactly 2 World
