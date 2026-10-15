module experiments/daily_pace_knowledge_minimality

-- Observation 381: what day-end Daily Pace can and cannot forget.
--
-- Two worlds may retain exactly the same immutable policy/Scheduled facts
-- and equal knowledge-day buckets yet need different latest-winner answers
-- if an order-sensitive write has no retained replacement/winner relation.
--
-- All atoms and amounts are synthetic and deliberately small. The model
-- does not stand in for the full HouseholdImage publisher protocol.

abstract sig Day {}
one sig D0, D1 extends Day {}

abstract sig Slot {}
one sig Early, Late extends Slot {}

abstract sig Policy {
  protected: one Int
}
one sig Original, Revised extends Policy {}

abstract sig Source {
  contribution: one Int
}
one sig SourceA, SourceB extends Source {}

abstract sig World {
  learned: Policy -> one Day,
  position: Policy -> one Slot,
  selectedSource: one Source
}
one sig Left, Right extends World {}

fact QualifiedFixtures {
  Original.protected = 3
  Revised.protected = 4

  SourceA.contribution = 3
  SourceB.contribution = 3

  -- The original planned obligation was known on the first day.
  all w: World | Original.(w.learned) = D0

  -- Local order is a total order of two same-day publications; the retained
  -- bucket is deliberately only the learned-day-to-fact membership map.
  all w: World | Original.(w.position) != Revised.(w.position)
}

-- An explicitly retained replacement relation, Original -> Revised,
-- makes the current successor depend on learned days, not row order.
fun withExplicitReplacementAtD0[w: World]: one Policy {
  (Revised.(w.learned) = D0) => Revised else Original
}

-- A mutable last-write-wins policy without an identified replacement edge
-- needs additional order/winner evidence when both writes fall on one day.
fun lastWriteWinsAtD0[w: World]: one Policy {
  (Revised.(w.learned) = D0) =>
    { p: Policy | p.(w.position) = Late }
  else Original
}

pred sameFinalFactsDifferentKnownDay {
  Revised.(Left.learned) = D0
  Revised.(Right.learned) = D1
  withExplicitReplacementAtD0[Left].protected !=
    withExplicitReplacementAtD0[Right].protected
}

pred sameDayBucketsDifferentWinner {
  Left.learned = Right.learned
  Revised.(Left.learned) = D0
  lastWriteWinsAtD0[Left] != lastWriteWinsAtD0[Right]
}

pred sameScalarDifferentSourceIdentity {
  Left.selectedSource != Right.selectedSource
  Left.selectedSource.contribution = Right.selectedSource.contribution
}

-- Intentionally false: one bucket of source IDs does not encode all
-- order-sensitive winners merely by retaining its member set.
assert DayBucketsAloneDetermineLastWriteWins {
  all disj a, b: World |
    a.learned = b.learned implies
      lastWriteWinsAtD0[a] = lastWriteWinsAtD0[b]
}

-- Intentionally false: total quantity can erase which source was protected.
assert NumericContributionDeterminesSourceIdentity {
  all disj a, b: World |
    a.selectedSource.contribution = b.selectedSource.contribution implies
      a.selectedSource = b.selectedSource
}

-- Positive boundary: when successor identity is already retained, day-end
-- selection is determined by known-day membership, regardless of row order.
assert ExistingReplacementRelationDeterminesDayEnd {
  all disj a, b: World |
    a.learned = b.learned implies
      withExplicitReplacementAtD0[a] =
        withExplicitReplacementAtD0[b]
}

run sameFinalFactsDifferentKnownDay
  for exactly 2 Day, exactly 2 Slot, exactly 2 Policy,
      exactly 2 Source, exactly 2 World, 4 Int
run sameDayBucketsDifferentWinner
  for exactly 2 Day, exactly 2 Slot, exactly 2 Policy,
      exactly 2 Source, exactly 2 World, 4 Int
run sameScalarDifferentSourceIdentity
  for exactly 2 Day, exactly 2 Slot, exactly 2 Policy,
      exactly 2 Source, exactly 2 World, 4 Int

check DayBucketsAloneDetermineLastWriteWins
  for exactly 2 Day, exactly 2 Slot, exactly 2 Policy,
      exactly 2 Source, exactly 2 World, 4 Int
check NumericContributionDeterminesSourceIdentity
  for exactly 2 Day, exactly 2 Slot, exactly 2 Policy,
      exactly 2 Source, exactly 2 World, 4 Int
check ExistingReplacementRelationDeterminesDayEnd
  for exactly 2 Day, exactly 2 Slot, exactly 2 Policy,
      exactly 2 Source, exactly 2 World, 4 Int
