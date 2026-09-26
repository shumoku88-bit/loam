module experiments/observation_346_backward_anchor_reconstruction

open util/ordering[Moment]

sig Moment {}
sig Coordinate {}

abstract sig World {
  startAt: Coordinate -> one Moment,
  anchorAt: Coordinate -> one Moment,
  anchorValue: Coordinate -> one Int,
  trueStartValue: Coordinate -> one Int,
  retainedDelta: Moment -> Coordinate -> one Int,
  hiddenDelta: Moment -> Coordinate -> one Int,
  adjustmentDelta: Moment -> Coordinate -> one Int,
  completeFromStart: set Coordinate
}

one sig Left, Right extends World {}

fun start[w: World, c: Coordinate]: one Moment {
  c.(w.startAt)
}

fun anchor[w: World, c: Coordinate]: one Moment {
  c.(w.anchorAt)
}

fun anchorQuantity[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.anchorValue }
}

fun trueStart[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.trueStartValue }
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

pred inside[w: World, c: Coordinate, m: Moment] {
  lte[start[w, c], m]
  lte[m, anchor[w, c]]
}

fun afterStartThrough[w: World, c: Coordinate, t: Moment]: set Moment {
  { m: Moment |
      lt[start[w, c], m] and
      lte[m, t]
  }
}

fun afterThroughAnchor[w: World, c: Coordinate, t: Moment]: set Moment {
  { m: Moment |
      lt[t, m] and
      lte[m, anchor[w, c]]
  }
}

fun retainedAfterStartThrough[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: afterStartThrough[w, c, t] | retainedAt[w, m, c]
}

fun hiddenAfterStartThrough[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: afterStartThrough[w, c, t] | hiddenAt[w, m, c]
}

fun ledgerDeltaAfter[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: afterThroughAnchor[w, c, t] |
    add[retainedAt[w, m, c], adjustmentAt[w, m, c]]
}

fun retainedDeltaAfter[w: World, c: Coordinate, t: Moment]: one Int {
  sum m: afterThroughAnchor[w, c, t] | retainedAt[w, m, c]
}

fun realityAt[w: World, c: Coordinate, t: Moment]: one Int {
  add[
    trueStart[w, c],
    add[
      retainedAfterStartThrough[w, c, t],
      hiddenAfterStartThrough[w, c, t]
    ]
  ]
}

fun backwardLedgerAt[w: World, c: Coordinate, t: Moment]: one Int {
  sub[anchorQuantity[w, c], ledgerDeltaAfter[w, c, t]]
}

fun backwardOrdinaryAt[w: World, c: Coordinate, t: Moment]: one Int {
  sub[anchorQuantity[w, c], retainedDeltaAfter[w, c, t]]
}

pred noAdjustmentInInterval[w: World, c: Coordinate] {
  all m: Moment |
    inside[w, c, m] implies adjustmentAt[w, m, c] = 0
}

pred cleanCompleteInterval[w: World, c: Coordinate] {
  c in w.completeFromStart
  noAdjustmentInInterval[w, c]
}

fact BoundaryOrder {
  all w: World, c: Coordinate |
    lte[start[w, c], anchor[w, c]]
}

fact AnchorTruth {
  all w: World, c: Coordinate |
    anchorQuantity[w, c] = realityAt[w, c, anchor[w, c]]
}

fact CompletenessMeaning {
  all w: World, c: Coordinate |
    c in w.completeFromStart implies
      all m: Moment |
        (lt[start[w, c], m] and lte[m, anchor[w, c]]) implies
          hiddenAt[w, m, c] = 0
}

fact SmallNumbers {
  all w: World, c: Coordinate | {
    trueStart[w, c] >= -2
    trueStart[w, c] <= 2
    anchorQuantity[w, c] >= -12
    anchorQuantity[w, c] <= 12
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

pred backwardReconstructionWithoutStoredOpening {
  some w: World, c: Coordinate | {
    start[w, c] != first
    anchor[w, c] = last
    cleanCompleteInterval[w, c]
    trueStart[w, c] != 0
    backwardOrdinaryAt[w, c, start[w, c]] = trueStart[w, c]

    all t: Moment |
      inside[w, c, t] implies
        backwardOrdinaryAt[w, c, t] = realityAt[w, c, t]
  }
}

pred sameAnchorAndDeltasForceSameOpening {
  some c: Coordinate | {
    Left.startAt = Right.startAt
    Left.anchorAt = Right.anchorAt
    Left.anchorValue = Right.anchorValue
    Left.retainedDelta = Right.retainedDelta

    cleanCompleteInterval[Left, c]
    cleanCompleteInterval[Right, c]

    trueStart[Left, c] = trueStart[Right, c]
  }
}

pred adjustmentBlocksBackwardTraversal {
  some w: World, c: Coordinate, a: Moment | {
    inside[w, c, a]
    lt[start[w, c], a]
    lt[a, anchor[w, c]]
    adjustmentAt[w, a, c] != 0
    c not in w.completeFromStart

    backwardLedgerAt[w, c, anchor[w, c]] = anchorQuantity[w, c]

    some t: Moment | {
      inside[w, c, t]
      lt[t, a]
      backwardLedgerAt[w, c, t] != realityAt[w, c, t]
    }
  }
}

pred samePostAdjustmentEvidenceDifferentEarlierReality {
  some c: Coordinate, a: Moment | {
    Left.startAt = Right.startAt
    Left.anchorAt = Right.anchorAt
    Left.anchorValue = Right.anchorValue
    Left.retainedDelta = Right.retainedDelta
    Left.adjustmentDelta = Right.adjustmentDelta

    inside[Left, c, a]
    adjustmentAt[Left, a, c] != 0

    some t: Moment | {
      inside[Left, c, t]
      lt[t, a]
      realityAt[Left, c, t] != realityAt[Right, c, t]
    }
  }
}

assert CleanCompleteAnchorDeterminesEveryBoundary {
  all w: World, c: Coordinate |
    cleanCompleteInterval[w, c] implies
      all t: Moment |
        inside[w, c, t] implies
          backwardOrdinaryAt[w, c, t] = realityAt[w, c, t]
}

assert CleanCompleteAnchorDeterminesOpening {
  all w: World, c: Coordinate |
    cleanCompleteInterval[w, c] implies
      backwardOrdinaryAt[w, c, start[w, c]] = trueStart[w, c]
}

assert SameCleanAnchorAndDeltasDetermineOpening {
  (Left.startAt = Right.startAt and
   Left.anchorAt = Right.anchorAt and
   Left.anchorValue = Right.anchorValue and
   Left.retainedDelta = Right.retainedDelta) implies
    all c: Coordinate |
      (cleanCompleteInterval[Left, c] and cleanCompleteInterval[Right, c]) implies
        trueStart[Left, c] = trueStart[Right, c]
}

assert ExactLaterAnchorAloneDeterminesEarlierReality {
  (Left.startAt = Right.startAt and
   Left.anchorAt = Right.anchorAt and
   Left.anchorValue = Right.anchorValue and
   Left.retainedDelta = Right.retainedDelta and
   Left.adjustmentDelta = Right.adjustmentDelta) implies
    all c: Coordinate, t: Moment |
      inside[Left, c, t] implies
        realityAt[Left, c, t] = realityAt[Right, c, t]
}

assert AdjustmentCanBeTraversedBackwardAsOrdinaryDelta {
  all w: World, c: Coordinate |
    all t: Moment |
      inside[w, c, t] implies
        backwardLedgerAt[w, c, t] = realityAt[w, c, t]
}

run backwardReconstructionWithoutStoredOpening
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run sameAnchorAndDeltasForceSameOpening
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run adjustmentBlocksBackwardTraversal
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

run samePostAdjustmentEvidenceDifferentEarlierReality
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check CleanCompleteAnchorDeterminesEveryBoundary
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check CleanCompleteAnchorDeterminesOpening
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check SameCleanAnchorAndDeltasDetermineOpening
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check ExactLaterAnchorAloneDeterminesEarlierReality
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int

check AdjustmentCanBeTraversedBackwardAsOrdinaryDelta
  for exactly 2 World, exactly 1 Coordinate, exactly 4 Moment, 5 Int
