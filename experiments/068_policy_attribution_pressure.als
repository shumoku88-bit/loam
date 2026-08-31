module experiments/observation_068_policy_attribution_pressure

sig Position {}
one sig Earlier, Later extends Position {}

sig AcquisitionEffect {
  position: one Position,
  quantity: one Int
}

one sig DisposalEffect {
  quantity: one Int
}

abstract sig Policy {}
one sig PreferEarlier, PreferLater extends Policy {}

abstract sig World {
  policy: one Policy,
  explicitConsumption: AcquisitionEffect -> one Int
}

one sig Left, Right extends World {}

fact RepresentativePhysicalFacts {
  all a: AcquisitionEffect | a.quantity = 3
  one a: AcquisitionEffect | a.position = Earlier
  one a: AcquisitionEffect | a.position = Later

  DisposalEffect.quantity = 4

  all w: World, a: AcquisitionEffect | {
    a.(w.explicitConsumption) >= 0
    a.(w.explicitConsumption) <= a.quantity
  }

  all w: World |
    (sum a: AcquisitionEffect | a.(w.explicitConsumption)) = DisposalEffect.quantity
}

pred policyAssigns[p: Policy, a: AcquisitionEffect, q: Int] {
  (p = PreferEarlier and a.position = Earlier and q = 3) or
  (p = PreferEarlier and a.position = Later and q = 1) or
  (p = PreferLater and a.position = Earlier and q = 1) or
  (p = PreferLater and a.position = Later and q = 3)
}

fun policyConsumption[p: Policy, a: AcquisitionEffect]: one Int {
  { q: Int | policyAssigns[p, a, q] }
}

pred conformsToPolicy[w: World] {
  all a: AcquisitionEffect |
    a.(w.explicitConsumption) = policyConsumption[w.policy, a]
}

pred representativePolicyAttribution {
  Left.policy = PreferEarlier
  conformsToPolicy[Left]
}

pred oppositePoliciesDifferentQuantityAttribution {
  Left.policy = PreferEarlier
  Right.policy = PreferLater

  some a: AcquisitionEffect |
    policyConsumption[Left.policy, a] != policyConsumption[Right.policy, a]
}

pred samePolicyDifferentExplicitRelation {
  Left.policy = Right.policy
  Left.explicitConsumption != Right.explicitConsumption
}

pred sameExplicitRelationDifferentPolicy {
  Left.explicitConsumption = Right.explicitConsumption
  Left.policy != Right.policy
}

pred policyAndExplicitCanDisagree {
  some w: World, a: AcquisitionEffect |
    a.(w.explicitConsumption) != policyConsumption[w.policy, a]
}

assert PolicyDeterminesExplicitConsumption {
  Left.policy = Right.policy implies
    Left.explicitConsumption = Right.explicitConsumption
}

assert ExplicitConsumptionDeterminesPolicy {
  Left.explicitConsumption = Right.explicitConsumption implies
    Left.policy = Right.policy
}

assert ExplicitConsumptionMustEqualPolicyAttribution {
  all w: World | conformsToPolicy[w]
}

assert PolicyDeterminesPolicyAttribution {
  Left.policy = Right.policy implies
    all a: AcquisitionEffect |
      policyConsumption[Left.policy, a] = policyConsumption[Right.policy, a]
}

assert SamePolicyAndConformanceDetermineExplicitConsumption {
  Left.policy = Right.policy and
  conformsToPolicy[Left] and
  conformsToPolicy[Right] implies
    Left.explicitConsumption = Right.explicitConsumption
}

run representativePolicyAttribution for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
run oppositePoliciesDifferentQuantityAttribution for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
run samePolicyDifferentExplicitRelation for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
run sameExplicitRelationDifferentPolicy for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
run policyAndExplicitCanDisagree for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
check PolicyDeterminesExplicitConsumption for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
check ExplicitConsumptionDeterminesPolicy for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
check ExplicitConsumptionMustEqualPolicyAttribution for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
check PolicyDeterminesPolicyAttribution for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
check SamePolicyAndConformanceDetermineExplicitConsumption for exactly 2 AcquisitionEffect, exactly 2 Position, exactly 2 Policy, exactly 2 World, 4 Int
