module experiments/observation_201_quantity_assertion_vs_reconstruction

abstract sig Quantity {}
one sig Q8, Q10 extends Quantity {}

one sig LedgerHistory {
  reconstructed: one Quantity
}

abstract sig World {
  history: one LedgerHistory,
  asserted: one Quantity
}

one sig Left, Right extends World {}

fact SharedRetainedHistory {
  Left.history = Right.history
}

pred conflict[w: World] {
  w.asserted != w.history.reconstructed
}

pred representativeConflict {
  Left.history.reconstructed = Q10
  Left.asserted = Q10
  Right.asserted = Q8
  not conflict[Left]
  conflict[Right]
}

pred sameHistoryDifferentAssertion {
  Left.history = Right.history
  Left.asserted != Right.asserted
}

pred sameReconstructionDifferentConflict {
  Left.history.reconstructed = Right.history.reconstructed
  (conflict[Left] and not conflict[Right]) or
  (not conflict[Left] and conflict[Right])
}

assert HistoryDeterminesPhysicalAssertion {
  Left.history = Right.history implies Left.asserted = Right.asserted
}

assert ReconstructedQuantityDeterminesConflict {
  Left.history.reconstructed = Right.history.reconstructed implies
    (conflict[Left] iff conflict[Right])
}

assert ExplicitAssertionAndHistoryDetermineConflict {
  Left.history = Right.history and Left.asserted = Right.asserted implies
    (conflict[Left] iff conflict[Right])
}

run representativeConflict for exactly 2 World, exactly 2 Quantity
run sameHistoryDifferentAssertion for exactly 2 World, exactly 2 Quantity
run sameReconstructionDifferentConflict for exactly 2 World, exactly 2 Quantity
check HistoryDeterminesPhysicalAssertion for exactly 2 World, exactly 2 Quantity
check ReconstructedQuantityDeterminesConflict for exactly 2 World, exactly 2 Quantity
check ExplicitAssertionAndHistoryDetermineConflict for exactly 2 World, exactly 2 Quantity
