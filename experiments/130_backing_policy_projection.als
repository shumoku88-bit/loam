module experiments/observation_130_backing_policy_projection

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Holding {}
one sig Bank, Cash extends Holding {}

abstract sig Policy {}
one sig AffinityPolicy, CoveragePolicy, CoveragePolicyCopy extends Policy {}

abstract sig World {
  policy: one Policy
}
one sig AffinityWorld, CoverageWorld, CoverageCopyWorld extends World {}

-- Current household facts after the same Actual history used by Observation 129.
-- No Backing relation is stored in World.
fun holding[h: Holding]: one Int {
  h = Bank => 3 else 6
}

fun remaining[p: Purpose]: one Int {
  p = Food => 5 else 4
}

-- Backing is projected from current facts plus an explicit deterministic policy.
-- AffinityPolicy keeps each Holding on its established household purpose even if
-- that leaves one purpose under-backed.
-- CoveragePolicy uses the same physical stock but globally restores current
-- Remaining coverage. CoveragePolicyCopy has identical behavior under a
-- different policy identity so sufficiency checks are inhabited rather than
-- relying on one unique Policy atom.
fun projectedBacking[pol: Policy, h: Holding, p: Purpose]: one Int {
  pol = AffinityPolicy =>
    (h = Bank and p = Travel => 3 else
     h = Cash and p = Food => 6 else
     0)
  else
    (h = Bank and p = Travel => 3 else
     h = Cash and p = Food => 5 else
     h = Cash and p = Travel => 1 else
     0)
}

fun backingAt[w: World, h: Holding, p: Purpose]: one Int {
  projectedBacking[w.policy, h, p]
}

fun backed[w: World, p: Purpose]: one Int {
  sum h: Holding | backingAt[w, h, p]
}

fun funded[w: World, p: Purpose]: one Int {
  let r = remaining[p], b = backed[w, p] |
    b >= r => r else b
}

fun gap[w: World, p: Purpose]: one Int {
  sub[remaining[p], funded[w, p]]
}

pred samePolicyDefinition[p1, p2: Policy] {
  all h: Holding, p: Purpose |
    projectedBacking[p1, h, p] = projectedBacking[p2, h, p]
}

fact FixedPolicySelection {
  AffinityWorld.policy = AffinityPolicy
  CoverageWorld.policy = CoveragePolicy
  CoverageCopyWorld.policy = CoveragePolicyCopy
}

-- The candidate is required to remain physically admissible even though no
-- retained Backing state exists.
fact PolicyProjectionAdmissible {
  all pol: Policy, h: Holding, p: Purpose |
    projectedBacking[pol, h, p] >= 0

  all pol: Policy, h: Holding |
    (sum p: Purpose | projectedBacking[pol, h, p]) = holding[h]
}

pred backingCanBeProjectedWithoutStoredState {
  gap[AffinityWorld, Food] = 0
  gap[AffinityWorld, Travel] = 1
  gap[CoverageWorld, Food] = 0
  gap[CoverageWorld, Travel] = 0
}

pred sameCurrentFactsDifferentPolicyDifferentGap {
  gap[AffinityWorld, Travel] != gap[CoverageWorld, Travel]
}

pred sameCurrentFactsDifferentPolicyDifferentHoldingAnswer {
  backingAt[AffinityWorld, Cash, Food] != backingAt[CoverageWorld, Cash, Food]
  backingAt[AffinityWorld, Cash, Travel] != backingAt[CoverageWorld, Cash, Travel]
}

pred coveragePolicyClosesCurrentGap {
  all p: Purpose | gap[CoverageWorld, p] = 0
  some p: Purpose | gap[AffinityWorld, p] > 0
}

pred inhabitedSameDefinitionCopy {
  samePolicyDefinition[CoveragePolicy, CoveragePolicyCopy]
  all h: Holding, p: Purpose |
    backingAt[CoverageWorld, h, p] = backingAt[CoverageCopyWorld, h, p]
  all p: Purpose | {
    backed[CoverageWorld, p] = backed[CoverageCopyWorld, p]
    funded[CoverageWorld, p] = funded[CoverageCopyWorld, p]
    gap[CoverageWorld, p] = gap[CoverageCopyWorld, p]
  }
}

-- Deliberately too strong: current household facts alone determine Backing.
-- They are globally fixed in this model, so AffinityWorld / CoverageWorld are
-- the expected counterexample if policy authority is independently observable.
assert CurrentFactsAloneDetermineBacking {
  all w1, w2: World, h: Holding, p: Purpose |
    backingAt[w1, h, p] = backingAt[w2, h, p]
}

-- Deliberately too strong: current household facts alone determine every Gap.
assert CurrentFactsAloneDetermineGap {
  all w1, w2: World, p: Purpose |
    gap[w1, p] = gap[w2, p]
}

-- If policy projection is a viable current-state compression, equal policy
-- definitions over the same current facts must determine equal Backing and the
-- selected current budget projection.
assert CurrentFactsPlusPolicyDefinitionDetermineProjection {
  all w1, w2: World |
    samePolicyDefinition[w1.policy, w2.policy] implies {
      all h: Holding, p: Purpose |
        backingAt[w1, h, p] = backingAt[w2, h, p]
      all p: Purpose | {
        backed[w1, p] = backed[w2, p]
        funded[w1, p] = funded[w2, p]
        gap[w1, p] = gap[w2, p]
      }
    }
}

-- The deterministic projection itself must never invent or destroy physical
-- stock in this bounded specimen.
assert ProjectedBackingConservesHoldings {
  all w: World, h: Holding |
    (sum p: Purpose | backingAt[w, h, p]) = holding[h]
}

run backingCanBeProjectedWithoutStoredState for 6 Int
run sameCurrentFactsDifferentPolicyDifferentGap for 6 Int
run sameCurrentFactsDifferentPolicyDifferentHoldingAnswer for 6 Int
run coveragePolicyClosesCurrentGap for 6 Int
run inhabitedSameDefinitionCopy for 6 Int
check CurrentFactsAloneDetermineBacking for 6 Int
check CurrentFactsAloneDetermineGap for 6 Int
check CurrentFactsPlusPolicyDefinitionDetermineProjection for 6 Int
check ProjectedBackingConservesHoldings for 6 Int
