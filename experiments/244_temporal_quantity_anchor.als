module experiments/observation_244_temporal_quantity_anchor

open util/ordering[Moment]

sig Moment {}
sig Coordinate {}

abstract sig World {
  -- A bare observed quantity at one boundary. By itself this says nothing
  -- about whether later unretained changes exist.
  observedMoment: Coordinate -> lone Moment,
  observedValue: Coordinate -> lone Int,

  -- A qualified temporal anchor: quantity is known at this boundary and the
  -- retained frontier is complete enough after the boundary for derivation.
  anchorMoment: Coordinate -> lone Moment,
  anchorValue: Coordinate -> lone Int,

  -- Raw retained movement and the correction-selected frontier are kept
  -- separate so an anchor cannot bypass correction semantics.
  rawDelta: Coordinate -> Moment -> one Int,
  frontierDelta: Coordinate -> Moment -> one Int,

  -- Model-side witness for changes that are not in the retained frontier.
  -- Qualified anchors rule these out after their boundary; bare observations do not.
  hiddenDelta: Coordinate -> Moment -> one Int
}

one sig Left, Right extends World {}

fact PairedEvidence {
  all w: World, c: Coordinate | {
    (some c.(w.observedMoment)) iff (some c.(w.observedValue))
    (some c.(w.anchorMoment)) iff (some c.(w.anchorValue))
  }
}

fun observedValueAt[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.observedValue }
}

fun anchorValueAt[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.anchorValue }
}

fun rawAt[w: World, c: Coordinate, m: Moment]: one Int {
  sum { i: Int | c->m->i in w.rawDelta }
}

fun frontierAt[w: World, c: Coordinate, m: Moment]: one Int {
  sum { i: Int | c->m->i in w.frontierDelta }
}

fun hiddenAt[w: World, c: Coordinate, m: Moment]: one Int {
  sum { i: Int | c->m->i in w.hiddenDelta }
}

fact SmallQuantities {
  all w: World, c: Coordinate | {
    all i: c.(w.observedValue) + c.(w.anchorValue) |
      i >= -3 and i <= 3
    all m: Moment | {
      let r = rawAt[w, c, m] | r >= -3 and r <= 3
      let f = frontierAt[w, c, m] | f >= -3 and f <= 3
      let h = hiddenAt[w, c, m] | h >= -3 and h <= 3
    }
  }
}

-- Qualification is stronger than merely observing a number. Once an anchor is
-- admitted, the retained frontier after it is assumed complete for this coordinate.
fact QualifiedAnchorClosesLaterHiddenChange {
  all w: World, c: Coordinate, a: c.(w.anchorMoment), m: Moment |
    lt[a, m] implies hiddenAt[w, c, m] = 0
}

fun frontierAfter[w: World, c: Coordinate, a, t: Moment]: one Int {
  sum m: Moment |
    (lt[a, m] and lte[m, t]) => frontierAt[w, c, m] else 0
}

fun hiddenAfter[w: World, c: Coordinate, a, t: Moment]: one Int {
  sum m: Moment |
    (lt[a, m] and lte[m, t]) => hiddenAt[w, c, m] else 0
}

fun anchorDerivedAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    anchorValueAt[w, c],
    sum a: c.(w.anchorMoment) | frontierAfter[w, c, a, t]
  ]
}

fun anchorActualAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    anchorDerivedAt[w, c, t],
    sum a: c.(w.anchorMoment) | hiddenAfter[w, c, a, t]
  ]
}

fun observedDerivedAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    observedValueAt[w, c],
    sum a: c.(w.observedMoment) | frontierAfter[w, c, a, t]
  ]
}

fun observedActualAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    observedDerivedAt[w, c, t],
    sum a: c.(w.observedMoment) | hiddenAfter[w, c, a, t]
  ]
}

pred anchoredAt[w: World, c: Coordinate, t: Moment] {
  some a: c.(w.anchorMoment) | lte[a, t]
}

fun oldZeroOriginAnswer[w: World, c: Coordinate, t: Moment]: one Int {
  frontierAfter[w, c, first, t]
}

pred zeroOriginAsUnifiedAnchor {
  some c: Coordinate | {
    c.(Left.anchorMoment) = first
    anchorValueAt[Left, c] = 0
    all t: Moment | anchoredAt[Left, c, t]
  }
}

pred laterNonzeroAnchorSupportsCurrentOnly {
  some c: Coordinate, a: Moment | {
    a != first
    c.(Left.anchorMoment) = a
    anchorValueAt[Left, c] != 0
    anchoredAt[Left, c, last]
    not anchoredAt[Left, c, first]
  }
}

pred missingAnchorWithZeroNetStillUnsupported {
  some c: Coordinate | {
    no c.(Left.anchorMoment)
    (sum m: Moment | frontierAt[Left, c, m]) = 0
    not anchoredAt[Left, c, last]
  }
}

-- Same scalar quantity and same selected movement are not enough when the
-- boundary at which that quantity applies is different.
pred scalarBasisCannotPlaceLaterAnchor {
  some c: Coordinate | {
    Left.anchorValue = Right.anchorValue
    Left.frontierDelta = Right.frontierDelta
    c.(Left.anchorMoment) != c.(Right.anchorMoment)
    some c.(Left.anchorMoment)
    some c.(Right.anchorMoment)
    anchoredAt[Left, c, last]
    anchoredAt[Right, c, last]
    anchorDerivedAt[Left, c, last] != anchorDerivedAt[Right, c, last]
  }
}

-- A bare observed quantity does not establish that the retained delta stream
-- after it is complete.
pred bareObservationDoesNotDetermineCurrent {
  some c: Coordinate | {
    Left.observedMoment = Right.observedMoment
    Left.observedValue = Right.observedValue
    Left.frontierDelta = Right.frontierDelta
    some c.(Left.observedMoment)
    observedActualAt[Left, c, last] != observedActualAt[Right, c, last]
  }
}

-- Correction selection remains independent of the anchor: raw movement can be
-- identical while the effective frontier and therefore the answer differ.
pred correctionsRemainRelevant {
  some c: Coordinate | {
    Left.anchorMoment = Right.anchorMoment
    Left.anchorValue = Right.anchorValue
    Left.rawDelta = Right.rawDelta
    Left.frontierDelta != Right.frontierDelta
    some c.(Left.anchorMoment)
    anchoredAt[Left, c, last]
    anchorDerivedAt[Left, c, last] != anchorDerivedAt[Right, c, last]
  }
}

assert ZeroOriginEncodingPreservesAnswer {
  all w: World, c: Coordinate |
    (c.(w.anchorMoment) = first and anchorValueAt[w, c] = 0) implies
      all t: Moment |
        anchorDerivedAt[w, c, t] = oldZeroOriginAnswer[w, c, t]
}

assert LaterAnchorNeverSupportsEarlierBoundary {
  all w: World, c: Coordinate, a: c.(w.anchorMoment), t: Moment |
    lt[t, a] implies not anchoredAt[w, c, t]
}

assert BareObservationDeterminesCurrentReality {
  (Left.observedMoment = Right.observedMoment and
   Left.observedValue = Right.observedValue and
   Left.frontierDelta = Right.frontierDelta) implies
    all c: Coordinate |
      observedActualAt[Left, c, last] = observedActualAt[Right, c, last]
}

assert ScalarBasisDeterminesTemporalAnswer {
  (Left.anchorValue = Right.anchorValue and
   Left.frontierDelta = Right.frontierDelta) implies
    all c: Coordinate |
      (anchoredAt[Left, c, last] and anchoredAt[Right, c, last]) implies
        anchorDerivedAt[Left, c, last] = anchorDerivedAt[Right, c, last]
}

assert RawDeltaDeterminesAnchoredAnswer {
  (Left.anchorMoment = Right.anchorMoment and
   Left.anchorValue = Right.anchorValue and
   Left.rawDelta = Right.rawDelta) implies
    all c: Coordinate |
      anchorDerivedAt[Left, c, last] = anchorDerivedAt[Right, c, last]
}

assert QualifiedAnchorAndFrontierDetermineAnswer {
  (Left.anchorMoment = Right.anchorMoment and
   Left.anchorValue = Right.anchorValue and
   Left.frontierDelta = Right.frontierDelta) implies
    all c: Coordinate, t: Moment | {
      anchoredAt[Left, c, t] iff anchoredAt[Right, c, t]
      anchoredAt[Left, c, t] implies {
        anchorDerivedAt[Left, c, t] = anchorDerivedAt[Right, c, t]
        anchorActualAt[Left, c, t] = anchorActualAt[Right, c, t]
      }
    }
}

run zeroOriginAsUnifiedAnchor for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
run laterNonzeroAnchorSupportsCurrentOnly for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
run missingAnchorWithZeroNetStillUnsupported for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
run scalarBasisCannotPlaceLaterAnchor for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
run bareObservationDoesNotDetermineCurrent for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
run correctionsRemainRelevant for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
check ZeroOriginEncodingPreservesAnswer for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
check LaterAnchorNeverSupportsEarlierBoundary for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
check BareObservationDeterminesCurrentReality for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
check ScalarBasisDeterminesTemporalAnswer for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
check RawDeltaDeterminesAnchoredAnswer for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
check QualifiedAnchorAndFrontierDetermineAnswer for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, 5 Int
