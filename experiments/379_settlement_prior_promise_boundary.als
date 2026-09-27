module experiments/observation_379_settlement_prior_promise_boundary

open util/ordering[Moment] as time

sig Moment {}

sig Event {
  occurredAt: one Moment
}

sig Party {}

sig Measure {}

sig SourceBackedObligation {
  source: one Event,
  debtor: one Party,
  creditor: one Party,
  measure: one Measure,
  quantity: one Int
}

sig PriorPromise {
  target: one SourceBackedObligation,
  promisedAt: one Moment
}

abstract sig World {
  events: set Event,
  obligations: set SourceBackedObligation,

  // Independent evidence that the obligation was already promised before
  // the source Event occurred. Absence means this model does not know such
  // a prior promise; it is not inferred from the later source-backed row.
  priorPromises: set PriorPromise,

  // Abstracts already-admitted settlement quantity. The two selected worlds
  // keep this equal so the current settlement answer is held fixed.
  settled: SourceBackedObligation -> one Int
}

one sig Left, Right extends World {}

fact QuantityShape {
  all o: SourceBackedObligation | {
    o.quantity > 0
    o.quantity <= 10
    o.debtor != o.creditor
  }
}

fact SameSettlementEvidence {
  Left.events = Right.events
  Left.obligations = Right.obligations
  Left.settled = Right.settled
}

fact ReferenceClosure {
  all w: World | {
    w.obligations.source in w.events
    w.priorPromises.target in w.obligations
  }
}

fact PriorPromiseShape {
  all w: World, p: w.priorPromises |
    time/lt[p.promisedAt, p.target.source.occurredAt]
}

fact SettledBounds {
  all w: World, o: w.obligations | {
    o.(w.settled) >= 0
    o.(w.settled) <= o.quantity
  }
}

fun currentOutstanding[w: World, o: SourceBackedObligation]: one Int {
  sub[o.quantity, o.(w.settled)]
}

pred hasPriorPromise[w: World, o: SourceBackedObligation] {
  some p: w.priorPromises | p.target = o
}

pred sameSettlementImageDifferentPriorPromiseWitness {
  some o: SourceBackedObligation,
       p: PriorPromise,
       promised, occurred: Moment | {
    Left.obligations = o
    Right.obligations = o
    Left.events = o.source
    Right.events = o.source

    o.quantity = 10
    o.(Left.settled) = 0
    o.(Right.settled) = 0

    p.target = o
    p.promisedAt = promised
    o.source.occurredAt = occurred
    time/lt[promised, occurred]

    Left.priorPromises = p
    no Right.priorPromises

    hasPriorPromise[Left, o]
    not hasPriorPromise[Right, o]

    currentOutstanding[Left, o] = 10
    currentOutstanding[Right, o] = 10
  }
}

pred eventTriggeredObligationWithoutPriorPromiseWitness {
  some o: SourceBackedObligation | {
    o in Left.obligations
    no Left.priorPromises
    o.quantity = 10
    o.(Left.settled) = 0
    currentOutstanding[Left, o] = 10
    not hasPriorPromise[Left, o]
  }
}

// Deliberately too strong: the current source-backed settlement image does not
// determine whether the same obligation was already promised before its source
// Event.
assert SettlementImageDeterminesPriorPromise {
  all o: SourceBackedObligation |
    o in Left.obligations and
    o in Right.obligations
    implies
      (hasPriorPromise[Left, o] iff hasPriorPromise[Right, o])
}

// Prior-promise evidence is intentionally outside current outstanding
// arithmetic. Holding admitted settlement evidence fixed must therefore keep the
// current quantity answer fixed.
assert PriorPromiseDoesNotAffectCurrentOutstanding {
  all o: SourceBackedObligation |
    o in Left.obligations and
    o in Right.obligations
    implies
      currentOutstanding[Left, o] = currentOutstanding[Right, o]
}

// Deliberately too strong: a source-backed obligation may arise without any
// retained evidence that the same obligation was promised before the source
// Event.
assert EverySourceBackedObligationHasPriorPromise {
  all w: World, o: w.obligations |
    hasPriorPromise[w, o]
}

// Positive sanity law for the observation-local prior-promise relation.
assert RetainedPriorPromisePrecedesSourceEvent {
  all w: World, p: w.priorPromises |
    time/lt[p.promisedAt, p.target.source.occurredAt]
}

run sameSettlementImageDifferentPriorPromiseWitness
  for exactly 2 World, exactly 2 Moment, exactly 1 Event,
      exactly 2 Party, exactly 1 Measure,
      exactly 1 SourceBackedObligation, exactly 1 PriorPromise, 8 Int

run eventTriggeredObligationWithoutPriorPromiseWitness
  for exactly 2 World, exactly 2 Moment, exactly 1 Event,
      exactly 2 Party, exactly 1 Measure,
      exactly 1 SourceBackedObligation, exactly 1 PriorPromise, 8 Int

check SettlementImageDeterminesPriorPromise
  for exactly 2 World, exactly 2 Moment, exactly 1 Event,
      exactly 2 Party, exactly 1 Measure,
      exactly 1 SourceBackedObligation, exactly 1 PriorPromise, 8 Int

check PriorPromiseDoesNotAffectCurrentOutstanding
  for exactly 2 World, exactly 2 Moment, exactly 1 Event,
      exactly 2 Party, exactly 1 Measure,
      exactly 1 SourceBackedObligation, exactly 1 PriorPromise, 8 Int

check EverySourceBackedObligationHasPriorPromise
  for exactly 2 World, exactly 2 Moment, exactly 1 Event,
      exactly 2 Party, exactly 1 Measure,
      exactly 1 SourceBackedObligation, exactly 1 PriorPromise, 8 Int

check RetainedPriorPromisePrecedesSourceEvent
  for exactly 2 World, exactly 2 Moment, exactly 1 Event,
      exactly 2 Party, exactly 1 Measure,
      exactly 1 SourceBackedObligation, exactly 1 PriorPromise, 8 Int
