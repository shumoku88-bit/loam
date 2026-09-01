module experiments/observation_079_check_result_context

abstract sig CommandMode {}
one sig WitnessSearch, AssertionCheck extends CommandMode {}

abstract sig RawResult {}
one sig Sat, Unsat extends RawResult {}

abstract sig Interpretation {}
one sig WitnessFound, NoWitnessInScope, CounterexampleFound, NoCounterexampleInScope extends Interpretation {}

abstract sig Qualification {}
one sig Success, Failure extends Qualification {}

sig Claim {}

sig Check {
  claim: one Claim,
  mode: one CommandMode,
  raw: one RawResult,
  expected: one RawResult
}

pred interpretsAs[c: Check, meaning: Interpretation] {
  (c.mode = WitnessSearch and c.raw = Sat and meaning = WitnessFound) or
  (c.mode = WitnessSearch and c.raw = Unsat and meaning = NoWitnessInScope) or
  (c.mode = AssertionCheck and c.raw = Sat and meaning = CounterexampleFound) or
  (c.mode = AssertionCheck and c.raw = Unsat and meaning = NoCounterexampleInScope)
}

pred hasQualification[c: Check, q: Qualification] {
  (c.raw = c.expected and q = Success) or
  (c.raw != c.expected and q = Failure)
}

fact UniqueInterpretationAndQualification {
  all c: Check | {
    one meaning: Interpretation | interpretsAs[c, meaning]
    one q: Qualification | hasQualification[c, q]
  }
}

pred sameSatDifferentMeaning {
  some disj left, right: Check, disj leftMeaning, rightMeaning: Interpretation | {
    left.raw = Sat
    right.raw = Sat
    left.mode = WitnessSearch
    right.mode = AssertionCheck
    interpretsAs[left, leftMeaning]
    interpretsAs[right, rightMeaning]
    leftMeaning != rightMeaning
  }
}

pred sameSuccessDifferentRaw {
  some disj left, right: Check | {
    some q: Qualification | {
      q = Success
      hasQualification[left, q]
      hasQualification[right, q]
    }
    left.raw != right.raw
  }
}

pred sameSuccessDifferentMeaning {
  some disj left, right: Check, disj leftMeaning, rightMeaning: Interpretation | {
    some q: Qualification | {
      q = Success
      hasQualification[left, q]
      hasQualification[right, q]
    }
    interpretsAs[left, leftMeaning]
    interpretsAs[right, rightMeaning]
    leftMeaning != rightMeaning
  }
}

pred sameRawDifferentQualification {
  some disj left, right: Check, disj leftQ, rightQ: Qualification | {
    left.raw = right.raw
    left.expected != right.expected
    hasQualification[left, leftQ]
    hasQualification[right, rightQ]
    leftQ != rightQ
  }
}

pred sameRawModeDifferentClaim {
  some disj left, right: Check | {
    left.raw = right.raw
    left.mode = right.mode
    left.claim != right.claim
  }
}

assert RawResultDeterminesMeaning {
  all left, right: Check, leftMeaning, rightMeaning: Interpretation |
    left.raw = right.raw and
    interpretsAs[left, leftMeaning] and
    interpretsAs[right, rightMeaning] implies
      leftMeaning = rightMeaning
}

assert WorkflowSuccessDeterminesRaw {
  all left, right: Check |
    hasQualification[left, Success] and
    hasQualification[right, Success] implies
      left.raw = right.raw
}

assert WorkflowSuccessDeterminesMeaning {
  all left, right: Check, leftMeaning, rightMeaning: Interpretation |
    hasQualification[left, Success] and
    hasQualification[right, Success] and
    interpretsAs[left, leftMeaning] and
    interpretsAs[right, rightMeaning] implies
      leftMeaning = rightMeaning
}

assert RawResultDeterminesQualification {
  all left, right: Check, leftQ, rightQ: Qualification |
    left.raw = right.raw and
    hasQualification[left, leftQ] and
    hasQualification[right, rightQ] implies
      leftQ = rightQ
}

assert RawAndModeDetermineMeaning {
  all left, right: Check, leftMeaning, rightMeaning: Interpretation |
    left.raw = right.raw and
    left.mode = right.mode and
    interpretsAs[left, leftMeaning] and
    interpretsAs[right, rightMeaning] implies
      leftMeaning = rightMeaning
}

assert RawAndModeDetermineClaim {
  all left, right: Check |
    left.raw = right.raw and
    left.mode = right.mode implies
      left.claim = right.claim
}

assert RawAndExpectedDetermineQualification {
  all left, right: Check, leftQ, rightQ: Qualification |
    left.raw = right.raw and
    left.expected = right.expected and
    hasQualification[left, leftQ] and
    hasQualification[right, rightQ] implies
      leftQ = rightQ
}

assert FullSemanticReceiptDeterminesMeaning {
  all left, right: Check, leftMeaning, rightMeaning: Interpretation |
    left.claim = right.claim and
    left.mode = right.mode and
    left.raw = right.raw and
    interpretsAs[left, leftMeaning] and
    interpretsAs[right, rightMeaning] implies
      leftMeaning = rightMeaning
}

run sameSatDifferentMeaning for exactly 2 Claim, exactly 2 Check
run sameSuccessDifferentRaw for exactly 2 Claim, exactly 2 Check
run sameSuccessDifferentMeaning for exactly 2 Claim, exactly 2 Check
run sameRawDifferentQualification for exactly 2 Claim, exactly 2 Check
run sameRawModeDifferentClaim for exactly 2 Claim, exactly 2 Check

check RawResultDeterminesMeaning for exactly 2 Claim, exactly 2 Check
check WorkflowSuccessDeterminesRaw for exactly 2 Claim, exactly 2 Check
check WorkflowSuccessDeterminesMeaning for exactly 2 Claim, exactly 2 Check
check RawResultDeterminesQualification for exactly 2 Claim, exactly 2 Check
check RawAndModeDetermineMeaning for exactly 2 Claim, exactly 2 Check
check RawAndModeDetermineClaim for exactly 2 Claim, exactly 2 Check
check RawAndExpectedDetermineQualification for exactly 2 Claim, exactly 2 Check
check FullSemanticReceiptDeterminesMeaning for exactly 2 Claim, exactly 2 Check
