module experiments/observation_206_discrepancy_repair_epistemic_boundary

abstract sig Quantity {}
one sig Q8, Q10 extends Quantity {}

abstract sig HistoryStatus {}
one sig Complete, Incomplete extends HistoryStatus {}

abstract sig RepairPolicy {}
one sig LeaveUnknown, PadToAssertion extends RepairPolicy {}

abstract sig World {
  reconstructed: one Quantity,
  asserted: one Quantity,
  status: one HistoryStatus,
  repair: lone RepairPolicy
}

one sig Left, Right extends World {}

fact RepairOnlyForIncompleteHistory {
  all w: World |
    (w.status = Complete iff no w.repair) and
    (w.status = Incomplete iff one w.repair)
}

fun selectedReconstruction[w: World]: lone Quantity {
  { q: Quantity |
      (w.status = Complete and q = w.reconstructed) or
      (w.status = Incomplete and w.repair = PadToAssertion and q = w.asserted) }
}

pred unresolved[w: World] {
  w.status = Incomplete and w.repair = LeaveUnknown
}

pred representativeLeaveUnknownVsPad {
  Left.reconstructed = Q10
  Right.reconstructed = Q10
  Left.asserted = Q8
  Right.asserted = Q8
  Left.status = Incomplete
  Right.status = Incomplete
  Left.repair = LeaveUnknown
  Right.repair = PadToAssertion
  no selectedReconstruction[Left]
  selectedReconstruction[Right] = Q8
}

pred sameEvidenceDifferentCompleteness {
  Left.reconstructed = Right.reconstructed
  Left.asserted = Right.asserted
  Left.reconstructed = Q10
  Left.asserted = Q8
  Left.status = Complete
  Right.status = Incomplete
  Right.repair = LeaveUnknown
}

pred sameSelectedDifferentProvenance {
  Left.reconstructed = Q8
  Left.asserted = Q8
  Left.status = Complete

  Right.reconstructed = Q10
  Right.asserted = Q8
  Right.status = Incomplete
  Right.repair = PadToAssertion

  selectedReconstruction[Left] = Q8
  selectedReconstruction[Right] = Q8
}

assert ReconstructionAndAssertionDetermineCompleteness {
  Left.reconstructed = Right.reconstructed and
  Left.asserted = Right.asserted implies
    Left.status = Right.status
}

assert IncompleteEvidenceDeterminesRepairOutcome {
  Left.reconstructed = Right.reconstructed and
  Left.asserted = Right.asserted and
  Left.status = Right.status implies
    selectedReconstruction[Left] = selectedReconstruction[Right]
}

assert SelectedReconstructionDeterminesProvenance {
  some selectedReconstruction[Left] and
  selectedReconstruction[Left] = selectedReconstruction[Right] implies
    (Left.reconstructed = Right.reconstructed and
     Left.status = Right.status and
     Left.repair = Right.repair)
}

assert ExplicitAdditiveEvidenceDeterminesSelectedView {
  Left.reconstructed = Right.reconstructed and
  Left.asserted = Right.asserted and
  Left.status = Right.status and
  Left.repair = Right.repair implies
    (selectedReconstruction[Left] = selectedReconstruction[Right] and
     (unresolved[Left] iff unresolved[Right]))
}

assert LeaveUnknownHasNoSelectedReconstruction {
  all w: World |
    w.status = Incomplete and w.repair = LeaveUnknown implies
      no selectedReconstruction[w]
}

assert PadToAssertionSelectsAssertion {
  all w: World |
    w.status = Incomplete and w.repair = PadToAssertion implies
      selectedReconstruction[w] = w.asserted
}

run representativeLeaveUnknownVsPad for exactly 2 Quantity, exactly 2 World
run sameEvidenceDifferentCompleteness for exactly 2 Quantity, exactly 2 World
run sameSelectedDifferentProvenance for exactly 2 Quantity, exactly 2 World
check ReconstructionAndAssertionDetermineCompleteness for exactly 2 Quantity, exactly 2 World
check IncompleteEvidenceDeterminesRepairOutcome for exactly 2 Quantity, exactly 2 World
check SelectedReconstructionDeterminesProvenance for exactly 2 Quantity, exactly 2 World
check ExplicitAdditiveEvidenceDeterminesSelectedView for exactly 2 Quantity, exactly 2 World
check LeaveUnknownHasNoSelectedReconstruction for exactly 2 Quantity, exactly 2 World
check PadToAssertionSelectsAssertion for exactly 2 Quantity, exactly 2 World
