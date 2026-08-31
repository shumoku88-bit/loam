module experiments/observation_070_policy_provenance_pressure

sig Position {}
one sig Earlier, Later extends Position {}

sig DisposalCase {}
one sig HistoricalCase, DistinguishingCase extends DisposalCase {}

abstract sig Policy {}
one sig PolicyA, PolicyB extends Policy {}

abstract sig World {
  recordedUnder: one Policy,
  currentPolicy: one Policy,
  retainedAttribution: Position -> one Int
}

one sig Left, Right extends World {}

pred policyAssigns[p: Policy, c: DisposalCase, pos: Position, q: Int] {
  (c = HistoricalCase and pos = Earlier and q = 3) or
  (c = HistoricalCase and pos = Later and q = 1) or
  (c = DistinguishingCase and p = PolicyA and pos = Earlier and q = 3) or
  (c = DistinguishingCase and p = PolicyA and pos = Later and q = 1) or
  (c = DistinguishingCase and p = PolicyB and pos = Earlier and q = 1) or
  (c = DistinguishingCase and p = PolicyB and pos = Later and q = 3)
}

fun policyAttribution[p: Policy, c: DisposalCase, pos: Position]: one Int {
  { q: Int | policyAssigns[p, c, pos, q] }
}

fact RetainedAttributionShape {
  all w: World, pos: Position | {
    pos.(w.retainedAttribution) >= 0
    pos.(w.retainedAttribution) <= 3
  }

  all w: World |
    (sum pos: Position | pos.(w.retainedAttribution)) = 4
}

pred conformsToRecordedPolicy[w: World] {
  all pos: Position |
    pos.(w.retainedAttribution) =
      policyAttribution[w.recordedUnder, HistoricalCase, pos]
}

pred policiesAgreeOnHistoricalCase {
  all pos: Position |
    policyAttribution[PolicyA, HistoricalCase, pos] =
      policyAttribution[PolicyB, HistoricalCase, pos]
}

pred policiesDifferOnAnotherCase {
  some pos: Position |
    policyAttribution[PolicyA, DistinguishingCase, pos] !=
      policyAttribution[PolicyB, DistinguishingCase, pos]
}

pred representativePolicyProvenanceAmbiguity {
  Left.recordedUnder = PolicyA
  Right.recordedUnder = PolicyB
  Left.currentPolicy = Right.currentPolicy
  Left.retainedAttribution = Right.retainedAttribution
  conformsToRecordedPolicy[Left]
  conformsToRecordedPolicy[Right]
  policiesAgreeOnHistoricalCase
  policiesDifferOnAnotherCase
}

pred sameAttributionSameCurrentDifferentRecordedUnder {
  Left.retainedAttribution = Right.retainedAttribution
  Left.currentPolicy = Right.currentPolicy
  Left.recordedUnder != Right.recordedUnder
  conformsToRecordedPolicy[Left]
  conformsToRecordedPolicy[Right]
}

assert RetainedAttributionDeterminesPolicyProvenance {
  Left.retainedAttribution = Right.retainedAttribution implies
    Left.recordedUnder = Right.recordedUnder
}

assert RetainedAndCurrentPolicyDeterminePolicyProvenance {
  Left.retainedAttribution = Right.retainedAttribution and
  Left.currentPolicy = Right.currentPolicy implies
    Left.recordedUnder = Right.recordedUnder
}

assert AgreementOnOneCaseMeansPoliciesEquivalent {
  (all pos: Position |
    policyAttribution[PolicyA, HistoricalCase, pos] =
      policyAttribution[PolicyB, HistoricalCase, pos]) implies
  (all c: DisposalCase, pos: Position |
    policyAttribution[PolicyA, c, pos] =
      policyAttribution[PolicyB, c, pos])
}

assert SamePolicyProvenanceAndConformanceDetermineRetainedAttribution {
  Left.recordedUnder = Right.recordedUnder and
  conformsToRecordedPolicy[Left] and
  conformsToRecordedPolicy[Right] implies
    Left.retainedAttribution = Right.retainedAttribution
}

run policiesAgreeOnHistoricalCase for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
run policiesDifferOnAnotherCase for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
run representativePolicyProvenanceAmbiguity for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
run sameAttributionSameCurrentDifferentRecordedUnder for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
check RetainedAttributionDeterminesPolicyProvenance for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
check RetainedAndCurrentPolicyDeterminePolicyProvenance for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
check AgreementOnOneCaseMeansPoliciesEquivalent for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
check SamePolicyProvenanceAndConformanceDetermineRetainedAttribution for exactly 2 Position, exactly 2 DisposalCase, exactly 2 Policy, exactly 2 World, 4 Int
