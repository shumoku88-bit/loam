module experiments/observation_345_reconciled_interval_boundary

open util/ordering[Moment]

sig Moment {}
sig Coordinate {}

abstract sig World {
  -- Earliest boundary for which this world claims an opening quantity.
  startAt: Coordinate -> one Moment,

  -- Later external quantity observation used as a reconciliation checkpoint.
  observedAt: Coordinate -> one Moment,

  -- Ledger-side opening quantity asserted at the declared start boundary.
  assertedOpening: Coordinate -> one Int,

  -- Model-only reality witness. Production would not store this field.
  trueOpening: Coordinate -> one Int,

  -- Retained LOAM deltas.
  retainedDelta: Moment -> Coordinate -> one Int,

  -- Model-only omitted real-world deltas. These exist only to search for
  -- counterexamples where endpoint equality hides incomplete recording.
  hiddenDelta: Moment -> Coordinate -> one Int,

  -- Explicit ledger adjustment. This changes the ledger image but is not
  -- itself another physical-world movement.
  adjustmentDelta: Moment -> Coordinate -> one Int,

  -- Accepted claim that every real-world delta from start through the
  -- observation boundary is represented by retained evidence.
  completeFromStart: set Coordinate,

  -- External observed quantity at observedAt.
  observedValue: Coordinate -> one Int
}

one sig Left, Right extends World {}

fun start[w: World, c: Coordinate]: one Moment {
  c.(w.startAt)
}

fun observed[w: World, c: Coordinate]: one Moment {
  c.(w.observedAt)
}

fun opening[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.assertedOpening }
}

fun realOpening[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.trueOpening }
}

fun retainedAt[w: World, m: Moment, c: Coordinate]: one Int {
  sum { i: Int | m->c->i in w.retainedDelta }
}

fun hiddenAt[w: World, m: Moment, c: Coordinate]: one Int {
  sum { i: Int | m->c->i in w.hiddenDelta }
}

fun adjustmentAt[w: World, m: Moment, c: Coordinate]: one Int {
  sum { i: Int | m->c->i in w.adjustmentDelta }
}

fun observedValueAt[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.observedValue }
}

pred inside[w: World, c: Coordinate, m: Moment] {
  lte[start[w, c], m]
  lte[m, observed[w, c]]
}

fun intervalThrough[w: World, c: Coordinate, t: Moment]: set Moment {
  { m: Moment |
      lte[start[w, c], m] and
      lte[m, t]
  }
}

fun retainedSumThrough[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: intervalThrough[w, c, t] | retainedAt[w, m, c]
}

fun hiddenSumThrough[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: intervalThrough[w, c, t] | hiddenAt[w, m, c]
}

fun adjustmentSumThrough[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: intervalThrough[w, c, t] | adjustmentAt[w, m, c]
}

fun ledgerAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    opening[w, c],
    add[
      retainedSumThrough[w, c, t],
      adjustmentSumThrough[w, c, t]
    ]
  ]
}

fun realityAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    realOpening[w, c],
    add[
      retainedSumThrough[w, c, t],
      hiddenSumThrough[w, c, t]
    ]
  ]
}

fun priorAdjustmentSum[w: World, c: Coordinate]: one Int {
  sum m: intervalThrough[w, c, observed[w, c]] - observed[w, c] |
    adjustmentAt[w, m, c]
}

fun ledgerBeforeObservedAdjustment[w: World, c: Coordinate]: one Int {
  add[
    opening[w, c],
    add[
      retainedSumThrough[w, c, observed[w, c]],
      priorAdjustmentSum[w, c]
    ]
  ]
}

pred noAdjustmentInInterval[w: World, c: Coordinate] {
  all m: Moment |
    inside[w, c, m] implies adjustmentAt[w, m, c] = 0
}

pred endpointMatches[w: World, c: Coordinate] {
  ledgerAt[w, c, observed[w, c]] = observedValueAt[w, c]
}

pred qualifiedFromStart[w: World, c: Coordinate] {
  c in w.completeFromStart
  noAdjustmentInInterval[w, c]
  endpointMatches[w, c]
}

pred historicallySupportedAt[w: World, c: Coordinate, t: Moment] {
  qualifiedFromStart[w, c]
  inside[w, c, t]
}

pred repairEquationAtObservation[w: World, c: Coordinate] {
  adjustmentAt[w, observed[w, c], c] =
    sub[
      observedValueAt[w, c],
      ledgerBeforeObservedAdjustment[w, c]
    ]
}

pred repairedAtObservation[w: World, c: Coordinate] {
  ledgerBeforeObservedAdjustment[w, c] != observedValueAt[w, c]
  repairEquationAtObservation[w, c]
}

fact BoundaryOrder {
  all w: World, c: Coordinate |
    lte[start[w, c], observed[w, c]]
}

-- An external observation is modelled as a truthful quantity observation.
fact ObservationTruth {
  all w: World, c: Coordinate |
    observedValueAt[w, c] = realityAt[w, c, observed[w, c]]
}

-- Accepting completeFromStart is accepting the semantic claim that no physical
-- delta in that interval is omitted from the retained ledger evidence.
fact CompletenessMeaning {
  all w: World, c: Coordinate |
    c in w.completeFromStart implies
      all m: Moment |
        inside[w, c, m] implies hiddenAt[w, m, c] = 0
}

fact SmallNumbers {
  all w: World, c: Coordinate | {
    opening[w, c] >= -2
    opening[w, c] <= 2
    realOpening[w, c] >= -2
    realOpening[w, c] <= 2
  }

  all w: World, m: Moment, c: Coordinate | {
    retainedAt[w, m, c] >= -2
    retainedAt[w, m, c] <= 2
    hiddenAt[w, m, c] >= -2
    hiddenAt[w, m, c] <= 2
    adjustmentAt[w, m, c] >= -8
    adjustmentAt[w, m, c] <= 8
  }
}

pred qualifiedIntervalWithUnknownEarlierHistory {
  some w: World, c: Coordinate | {
    start[w, c] != first
    qualifiedFromStart[w, c]
    some m: Moment | {
      lt[m, start[w, c]]
      hiddenAt[w, m, c] != 0
    }
  }
}

pred matchingEndpointWithOffsettingOmissions {
  some w: World, c: Coordinate | {
    c not in w.completeFromStart
    noAdjustmentInInterval[w, c]
    opening[w, c] = realOpening[w, c]
    endpointMatches[w, c]
    hiddenSumThrough[w, c, observed[w, c]] = 0

    some positive: Moment | {
      inside[w, c, positive]
      hiddenAt[w, positive, c] > 0
    }

    some negative: Moment | {
      inside[w, c, negative]
      hiddenAt[w, negative, c] < 0
    }

    some t: Moment | {
      inside[w, c, t]
      ledgerAt[w, c, t] != realityAt[w, c, t]
    }
  }
}

pred mismatchWithoutAdjustment {
  some w: World, c: Coordinate | {
    noAdjustmentInInterval[w, c]
    opening[w, c] = realOpening[w, c]
    hiddenSumThrough[w, c, observed[w, c]] != 0
    not endpointMatches[w, c]
  }
}

pred adjustmentEstablishesObservedBoundary {
  some w: World, c: Coordinate | {
    all m: intervalThrough[w, c, observed[w, c]] - observed[w, c] |
      adjustmentAt[w, m, c] = 0
    ledgerBeforeObservedAdjustment[w, c] != observedValueAt[w, c]
    repairEquationAtObservation[w, c]
    endpointMatches[w, c]
  }
}

pred adjustmentLeavesEarlierGapVisible {
  some w: World, c: Coordinate | {
    c not in w.completeFromStart
    repairedAtObservation[w, c]
    endpointMatches[w, c]

    some t: Moment | {
      inside[w, c, t]
      lt[t, observed[w, c]]
      ledgerAt[w, c, t] != realityAt[w, c, t]
    }
  }
}

pred sameVisibleEndpointDifferentIntermediateReality {
  some c: Coordinate | {
    Left.startAt = Right.startAt
    Left.observedAt = Right.observedAt
    Left.assertedOpening = Right.assertedOpening
    Left.retainedDelta = Right.retainedDelta
    Left.adjustmentDelta = Right.adjustmentDelta
    Left.observedValue = Right.observedValue

    endpointMatches[Left, c]
    endpointMatches[Right, c]

    some t: Moment | {
      inside[Left, c, t]
      realityAt[Left, c, t] != realityAt[Right, c, t]
    }
  }
}

assert QualifiedIntervalMatchesReality {
  all w: World, c: Coordinate |
    qualifiedFromStart[w, c] implies
      all t: Moment |
        inside[w, c, t] implies
          ledgerAt[w, c, t] = realityAt[w, c, t]
}

assert EndpointMatchImpliesCompleteHistory {
  all w: World, c: Coordinate |
    endpointMatches[w, c] implies c in w.completeFromStart
}

assert SameVisibleEndpointDeterminesIntermediateReality {
  (Left.startAt = Right.startAt and
   Left.observedAt = Right.observedAt and
   Left.assertedOpening = Right.assertedOpening and
   Left.retainedDelta = Right.retainedDelta and
   Left.adjustmentDelta = Right.adjustmentDelta and
   Left.observedValue = Right.observedValue) implies
    all c: Coordinate, t: Moment |
      inside[Left, c, t] implies
        realityAt[Left, c, t] = realityAt[Right, c, t]
}

assert RepairEquationEstablishesObservedBoundary {
  all w: World, c: Coordinate |
    repairEquationAtObservation[w, c] implies
      ledgerAt[w, c, observed[w, c]] = observedValueAt[w, c]
}

assert AdjustmentReconciliationImpliesPriorCompleteness {
  all w: World, c: Coordinate |
    (repairedAtObservation[w, c] and endpointMatches[w, c]) implies
      c in w.completeFromStart
}

assert QualifiedIntervalNeverSupportsBeforeStart {
  all w: World, c: Coordinate, t: Moment |
    historicallySupportedAt[w, c, t] implies
      not lt[t, start[w, c]]
}

run qualifiedIntervalWithUnknownEarlierHistory
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run matchingEndpointWithOffsettingOmissions
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run mismatchWithoutAdjustment
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run adjustmentEstablishesObservedBoundary
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run adjustmentLeavesEarlierGapVisible
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run sameVisibleEndpointDifferentIntermediateReality
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check QualifiedIntervalMatchesReality
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check EndpointMatchImpliesCompleteHistory
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check SameVisibleEndpointDeterminesIntermediateReality
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check RepairEquationEstablishesObservedBoundary
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check AdjustmentReconciliationImpliesPriorCompleteness
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check QualifiedIntervalNeverSupportsBeforeStart
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int
