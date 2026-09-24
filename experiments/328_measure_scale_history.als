module experiments/observation_328_measure_scale_history

sig Measure {}
abstract sig Scale {}
one sig Scale0, Scale2 extends Scale {}

sig RetainedQuantity {
  measure: one Measure
}

sig World {
  retained: set RetainedQuantity,
  currentScale: Measure -> lone Scale,
  recordedScale: Measure -> lone Scale
}

// recordedScale is model-only historical truth: the convention under which retained
// quanta acquired their human fixed-point meaning. Current LOAM does not retain
// this relation beside the quantities.
pred completeForRetained[w: World] {
  all q: w.retained | {
    one q.measure.(w.currentScale)
    one q.measure.(w.recordedScale)
  }
}

pred sameCurrentSnapshot[a, b: World] {
  a.retained = b.retained
  a.currentScale = b.currentScale
}

fun historicalConvention[w: World, q: RetainedQuantity]: lone Scale {
  q.measure.(w.recordedScale)
}

pred ambiguousCurrentSnapshot {
  some disj a, b: World, q: RetainedQuantity | {
    completeForRetained[a]
    completeForRetained[b]
    q in a.retained
    q in b.retained
    sameCurrentSnapshot[a, b]
    historicalConvention[a, q] != historicalConvention[b, q]
  }
}

pred silentScaleRewriteExists {
  some w: World, q: RetainedQuantity | {
    completeForRetained[w]
    q in w.retained
    historicalConvention[w, q] = Scale2
    q.measure.(w.currentScale) = Scale0
  }
}

pred stableUseExists {
  some w: World, q: RetainedQuantity | {
    completeForRetained[w]
    q in w.retained
    historicalConvention[w, q] = Scale2
    q.measure.(w.currentScale) = Scale2
  }
}

assert CurrentSnapshotDeterminesHistoricalConvention {
  all a, b: World, q: RetainedQuantity | {
    completeForRetained[a]
    completeForRetained[b]
    q in a.retained
    q in b.retained
    sameCurrentSnapshot[a, b]
  } implies historicalConvention[a, q] = historicalConvention[b, q]
}

pred sameQualifiedSnapshot[a, b: World] {
  sameCurrentSnapshot[a, b]
  a.recordedScale = b.recordedScale
}

assert QualifiedSnapshotDeterminesHistoricalConvention {
  all a, b: World, q: RetainedQuantity | {
    completeForRetained[a]
    completeForRetained[b]
    q in a.retained
    q in b.retained
    sameQualifiedSnapshot[a, b]
  } implies historicalConvention[a, q] = historicalConvention[b, q]
}

run ambiguousCurrentSnapshot
  for exactly 1 Measure, exactly 1 RetainedQuantity, exactly 2 World

run silentScaleRewriteExists
  for exactly 1 Measure, exactly 1 RetainedQuantity, exactly 1 World

run stableUseExists
  for exactly 1 Measure, exactly 1 RetainedQuantity, exactly 1 World

check CurrentSnapshotDeterminesHistoricalConvention
  for exactly 1 Measure, exactly 1 RetainedQuantity, exactly 2 World

check QualifiedSnapshotDeterminesHistoricalConvention
  for exactly 1 Measure, exactly 1 RetainedQuantity, exactly 2 World
