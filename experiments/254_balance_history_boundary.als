module experiments/observation_254_balance_history_boundary

-- Observation 254 begins the history-level connection study.
--
-- The selected question is whether a Ledger/Pacioli-shaped balance image can
-- distinguish how stable LOAM Event identities partition the same retained
-- quantity effects. The model is deliberately smaller than either full LOAM or
-- ledger-semantics. It tests only information loss at this boundary.

abstract sig Locus {}
one sig CashLocus, GoodsLocus extends Locus {}

abstract sig Measure {}
one sig JPY extends Measure {}

-- These atoms stand for stable Event identities, not event kinds.
abstract sig Event {}
one sig EventA, EventB extends Event {}

abstract sig Effect {
  locus: one Locus,
  measure: one Measure,
  quantity: one Int
}
one sig Cash1, Cash2, Goods1, Goods2 extends Effect {}

-- A world retains the same physical quantity effects but may partition them
-- among Event identities differently.
abstract sig World {
  retained: set Effect,
  eventOf: Effect -> lone Event
}
one sig Joined, Split, RowLeft, RowRight extends World {}

fact StableEffectEvidence {
  all w: World | w.retained = Effect
  all w: World | all e: w.retained | one e.(w.eventOf)

  all e: Effect | e.measure = JPY

  Cash1.locus = CashLocus
  Cash2.locus = CashLocus
  Goods1.locus = GoodsLocus
  Goods2.locus = GoodsLocus

  Cash1.quantity = -1
  Cash2.quantity = -1
  Goods1.quantity = 1
  Goods2.quantity = 1
}

-- Two selected histories over exactly the same retained quantity evidence.
-- Joined records one Event identity containing all four effects.
-- Split records two Event identities, each containing one cash/goods pair.
fact SelectedHistories {
  all e: Effect | e.(Joined.eventOf) = EventA

  Cash1.(Split.eventOf) = EventA
  Goods1.(Split.eventOf) = EventA
  Cash2.(Split.eventOf) = EventB
  Goods2.(Split.eventOf) = EventB
}

-- Pacioli-shaped balance observation: aggregate by Locus x Measure and forget
-- Event membership entirely.
fun balanceAt[w: World, l: Locus, m: Measure]: Int {
  sum e: { x: w.retained | x.locus = l and x.measure = m } | e.quantity
}

-- Register-shaped observation used only for this experiment: aggregate by
-- Event identity as well as Locus x Measure. This is not claimed to be the full
-- ledger-semantics Register model.
fun eventFlowAt[w: World, ev: Event, l: Locus, m: Measure]: Int {
  sum e: {
    x: w.retained |
      x.locus = l and
      x.measure = m and
      x.(w.eventOf) = ev
  } | e.quantity
}

pred sameBalanceDifferentEventPartition {
  Joined.eventOf != Split.eventOf
  all l: Locus, m: Measure |
    balanceAt[Joined, l, m] = balanceAt[Split, l, m]
}

-- The selected one-Event and two-Event histories should be distinguishable as
-- soon as Event identity is retained in the observation coordinate.
pred selectedHistoriesDifferAtRegisterLevel {
  all l: Locus, m: Measure |
    balanceAt[Joined, l, m] = balanceAt[Split, l, m]
  some ev: Event, l: Locus, m: Measure |
    eventFlowAt[Joined, ev, l, m] != eventFlowAt[Split, ev, l, m]
}

-- Even an event-indexed quantity register can still forget finer effect
-- membership when equal-quantity effects are exchangeable. RowLeft and
-- RowRight are free worlds used to search for exactly that collision.
pred sameEventRegisterDifferentEffectMembership {
  RowLeft.eventOf != RowRight.eventOf
  all ev: Event, l: Locus, m: Measure |
    eventFlowAt[RowLeft, ev, l, m] = eventFlowAt[RowRight, ev, l, m]
}

-- Deliberately too strong: equal balance images do not determine Event
-- partition.
assert BalanceImageDeterminesEventPartition {
  (all l: Locus, m: Measure |
      balanceAt[Joined, l, m] = balanceAt[Split, l, m]) implies
    Joined.eventOf = Split.eventOf
}

-- Positive control for the selected Joined/Split pair.
assert SelectedHistoriesHaveDifferentRegisterImage {
  some ev: Event, l: Locus, m: Measure |
    eventFlowAt[Joined, ev, l, m] != eventFlowAt[Split, ev, l, m]
}

-- Deliberately too strong: event-indexed aggregate quantities still need not
-- determine exact Effect-to-Event membership when distinguishable Effect atoms
-- carry equal quantities at the same coordinate.
assert EventRegisterDeterminesEffectMembership {
  (all ev: Event, l: Locus, m: Measure |
      eventFlowAt[RowLeft, ev, l, m] = eventFlowAt[RowRight, ev, l, m]) implies
    RowLeft.eventOf = RowRight.eventOf
}

run sameBalanceDifferentEventPartition for exactly 2 Locus, exactly 1 Measure, exactly 2 Event, exactly 4 Effect, exactly 4 World, 4 Int
run selectedHistoriesDifferAtRegisterLevel for exactly 2 Locus, exactly 1 Measure, exactly 2 Event, exactly 4 Effect, exactly 4 World, 4 Int
run sameEventRegisterDifferentEffectMembership for exactly 2 Locus, exactly 1 Measure, exactly 2 Event, exactly 4 Effect, exactly 4 World, 4 Int
check BalanceImageDeterminesEventPartition for exactly 2 Locus, exactly 1 Measure, exactly 2 Event, exactly 4 Effect, exactly 4 World, 4 Int
check SelectedHistoriesHaveDifferentRegisterImage for exactly 2 Locus, exactly 1 Measure, exactly 2 Event, exactly 4 Effect, exactly 4 World, 4 Int
check EventRegisterDeterminesEffectMembership for exactly 2 Locus, exactly 1 Measure, exactly 2 Event, exactly 4 Effect, exactly 4 World, 4 Int
