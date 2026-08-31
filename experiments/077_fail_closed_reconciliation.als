module experiments/observation_077_fail_closed_reconciliation

abstract sig Candidate {}
one sig CandidateA, CandidateB extends Candidate {}

abstract sig Cycle {}
one sig Now, Later extends Cycle {}

one sig SourceOccurrence {}
one sig LoamId {}

abstract sig Operation {
  cycle: one Cycle,
  subject: one SourceOccurrence,
  candidates: set Candidate,
  explicitChoice: lone Candidate,
  admitted: lone Candidate,
  publishedId: lone LoamId
}

one sig NoCandidateOp,
        UniqueCandidateOp,
        AmbiguousOp,
        ReconciledOp,
        LaterAmbiguousOp extends Operation {}

fact SameSubject {
  all op: Operation | op.subject = SourceOccurrence
}

-- The reconciliation entrance is intentionally operation-local.
-- It creates no retained source-to-LOAM mapping relation.
fact FailClosedEntrance {
  all op: Operation |
    (no op.explicitChoice implies
      ((#op.candidates = 1 implies
          op.admitted = op.candidates and some op.publishedId)
       and
       (#op.candidates != 1 implies
          no op.admitted and no op.publishedId)))
    and
    (some op.explicitChoice implies
      op.explicitChoice in op.candidates
      and op.admitted = op.explicitChoice
      and some op.publishedId)
}

pred zeroCandidateReject {
  NoCandidateOp.cycle = Now
  no NoCandidateOp.candidates
  no NoCandidateOp.explicitChoice
  no NoCandidateOp.admitted
  no NoCandidateOp.publishedId
}

pred uniqueCandidateAutomatic {
  UniqueCandidateOp.cycle = Now
  UniqueCandidateOp.candidates = CandidateA
  no UniqueCandidateOp.explicitChoice
  UniqueCandidateOp.admitted = CandidateA
  some UniqueCandidateOp.publishedId
}

pred ambiguousWithoutChoiceReject {
  AmbiguousOp.cycle = Now
  AmbiguousOp.candidates = CandidateA + CandidateB
  no AmbiguousOp.explicitChoice
  no AmbiguousOp.admitted
  no AmbiguousOp.publishedId
}

pred ambiguousWithExplicitChoice {
  ReconciledOp.cycle = Now
  ReconciledOp.candidates = CandidateA + CandidateB
  ReconciledOp.explicitChoice = CandidateA
  ReconciledOp.admitted = CandidateA
  some ReconciledOp.publishedId
}

pred reconciliationDoesNotBecomeFutureMapping {
  ReconciledOp.cycle = Now
  ReconciledOp.candidates = CandidateA + CandidateB
  ReconciledOp.explicitChoice = CandidateA
  ReconciledOp.admitted = CandidateA

  LaterAmbiguousOp.cycle = Later
  LaterAmbiguousOp.candidates = CandidateA + CandidateB
  no LaterAmbiguousOp.explicitChoice
  no LaterAmbiguousOp.admitted
  no LaterAmbiguousOp.publishedId
}

assert NoCandidateNeverAdmits {
  all op: Operation |
    no op.candidates implies no op.admitted and no op.publishedId
}

assert AmbiguityWithoutChoiceNeverAdmits {
  all op: Operation |
    (#op.candidates > 1 and no op.explicitChoice)
      implies no op.admitted and no op.publishedId
}

assert ExplicitChoiceMustBeCandidate {
  all op: Operation |
    some op.explicitChoice implies op.explicitChoice in op.candidates
}

assert AdmissionAlwaysComesFromCandidateSet {
  all op: Operation |
    some op.admitted implies op.admitted in op.candidates
}

assert ExplicitReconciliationSelectsExactlyItsChoice {
  all op: Operation |
    some op.explicitChoice implies op.admitted = op.explicitChoice
}

run zeroCandidateReject for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
run uniqueCandidateAutomatic for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
run ambiguousWithoutChoiceReject for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
run ambiguousWithExplicitChoice for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
run reconciliationDoesNotBecomeFutureMapping for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation

check NoCandidateNeverAdmits for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
check AmbiguityWithoutChoiceNeverAdmits for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
check ExplicitChoiceMustBeCandidate for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
check AdmissionAlwaysComesFromCandidateSet for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
check ExplicitReconciliationSelectsExactlyItsChoice for exactly 2 Candidate, exactly 2 Cycle, exactly 1 SourceOccurrence, exactly 1 LoamId, exactly 5 Operation
