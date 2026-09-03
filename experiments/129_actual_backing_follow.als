module experiments/observation_129_actual_backing_follow

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Holding {}
one sig Bank, Cash extends Holding {}

-- Every World is a possible post-spend Backing allocation after the same
-- household Actual. The Actual itself and the prior state are fixed globally.
abstract sig World {
  backing: Holding -> Purpose -> one Int
}
one sig ReleaseTravel, Rebalanced, CopyRebalanced extends World {}

fun capacity[p: Purpose]: one Int {
  p = Food => 6 else 4
}

-- One Actual spends 1 from Bank and is routed to Food.
fun consumption[p: Purpose]: one Int {
  p = Food => 1 else 0
}

fun remaining[p: Purpose]: one Int {
  sub[capacity[p], consumption[p]]
}

fun priorHolding[h: Holding]: one Int {
  h = Bank => 4 else 6
}

fun postHolding[h: Holding]: one Int {
  h = Bank => 3 else 6
}

-- Before the Actual, Bank backs only Travel and Cash backs only Food.
-- This deliberately denies the local Bank x Food cell any backing to consume.
fun priorBacking[h: Holding, p: Purpose]: one Int {
  h = Bank and p = Travel => 4 else
  h = Cash and p = Food => 6 else
  0
}

fun backingAt[w: World, h: Holding, p: Purpose]: one Int {
  p.(h.(w.backing))
}

fun backed[w: World, p: Purpose]: one Int {
  sum h: Holding | backingAt[w, h, p]
}

fun fundedRemaining[w: World, p: Purpose]: one Int {
  let r = remaining[p], b = backed[w, p] |
    b >= r => r else b
}

fun gap[w: World, p: Purpose]: one Int {
  sub[remaining[p], fundedRemaining[w, p]]
}

fun backingDelta[w: World, h: Holding, p: Purpose]: one Int {
  sub[backingAt[w, h, p], priorBacking[h, p]]
}

fact FixedActualAndPriorState {
  -- The Actual reduces Bank by exactly one and consumes one unit of Food
  -- capacity. No Backing response is encoded here.
  postHolding[Bank] = sub[priorHolding[Bank], 1]
  postHolding[Cash] = priorHolding[Cash]
  remaining[Food] = 5
  remaining[Travel] = 4

  -- Prior Backing exactly uses both holdings.
  (sum p: Purpose | priorBacking[Bank, p]) = priorHolding[Bank]
  (sum p: Purpose | priorBacking[Cash, p]) = priorHolding[Cash]
}

fact AdmissiblePostBacking {
  all w: World, h: Holding, p: Purpose |
    backingAt[w, h, p] >= 0

  -- Keep the specimen strong: every post-spend physical unit remains assigned
  -- to some purpose. The ambiguity is not caused by leaving money unbacked.
  all w: World, h: Holding |
    (sum p: Purpose | backingAt[w, h, p]) = postHolding[h]
}

fact QualifiedResponses {
  -- Response A: make only the minimum local physical adjustment. Bank lost one
  -- unit, so Travel loses one unit of Bank support. Cash is untouched.
  backingAt[ReleaseTravel, Bank, Food] = 0
  backingAt[ReleaseTravel, Bank, Travel] = 3
  backingAt[ReleaseTravel, Cash, Food] = 6
  backingAt[ReleaseTravel, Cash, Travel] = 0

  -- Response B: preserve full Remaining coverage by also reallocating one Cash
  -- unit from Food to Travel.
  backingAt[Rebalanced, Bank, Food] = 0
  backingAt[Rebalanced, Bank, Travel] = 3
  backingAt[Rebalanced, Cash, Food] = 5
  backingAt[Rebalanced, Cash, Travel] = 1

  -- Inhabited same-evidence pair for the final sufficiency check.
  all h: Holding, p: Purpose |
    backingAt[CopyRebalanced, h, p] = backingAt[Rebalanced, h, p]
}

pred twoValidBackingResponsesSameActual {
  backingAt[ReleaseTravel, Bank, Travel] = 3
  backingAt[Rebalanced, Bank, Travel] = 3
  backingAt[ReleaseTravel, Cash, Travel] != backingAt[Rebalanced, Cash, Travel]
}

pred sameActualDifferentBudgetGap {
  gap[ReleaseTravel, Travel] = 1
  gap[Rebalanced, Travel] = 0
  gap[ReleaseTravel, Food] = 0
  gap[Rebalanced, Food] = 0
}

pred globalRebalanceCanRestoreCoverage {
  all p: Purpose | gap[Rebalanced, p] = 0
  some p: Purpose | gap[ReleaseTravel, p] > 0
}

-- The naive local rule would decrement Backing at the spending Holding and the
-- consumed Purpose. Here that cell begins at zero, so the candidate response
-- would have negative Backing and is not admissible.
pred samePurposeLocalAutoFollowAdmissible {
  let bankFoodAfter = sub[priorBacking[Bank, Food], 1] |
    bankFoodAfter >= 0 and
    add[bankFoodAfter, priorBacking[Bank, Travel]] = postHolding[Bank]
}

pred inhabitedPostBackingCopy {
  all h: Holding, p: Purpose |
    backingAt[Rebalanced, h, p] = backingAt[CopyRebalanced, h, p]
  all p: Purpose | {
    backed[Rebalanced, p] = backed[CopyRebalanced, p]
    fundedRemaining[Rebalanced, p] = fundedRemaining[CopyRebalanced, p]
    gap[Rebalanced, p] = gap[CopyRebalanced, p]
  }
}

-- Deliberately too strong. The same Actual, same routing, same prior Backing,
-- same post holdings, and same Remaining state still admit different Backing.
assert ActualAndPriorBackingDeterminePostBacking {
  all w1, w2: World |
    all h: Holding, p: Purpose |
      backingAt[w1, h, p] = backingAt[w2, h, p]
}

-- Deliberately too strong. Even the selected envelope-health answer is not
-- determined by the Actual and prior evidence in this specimen.
assert ActualAndPriorBackingDetermineBudgetGap {
  all w1, w2: World, p: Purpose |
    gap[w1, p] = gap[w2, p]
}

-- Once the post-spend Backing allocation itself is fixed, the selected bounded
-- Backed / FundedRemaining / Gap answers are fixed.
assert ExplicitPostBackingDeterminesSelectedProjection {
  all w1, w2: World |
    (all h: Holding, p: Purpose |
      backingAt[w1, h, p] = backingAt[w2, h, p]) implies
        all p: Purpose | {
          backed[w1, p] = backed[w2, p]
          fundedRemaining[w1, p] = fundedRemaining[w2, p]
          gap[w1, p] = gap[w2, p]
        }
}

run twoValidBackingResponsesSameActual for 6 Int
run sameActualDifferentBudgetGap for 6 Int
run globalRebalanceCanRestoreCoverage for 6 Int
run samePurposeLocalAutoFollowAdmissible for 6 Int
run inhabitedPostBackingCopy for 6 Int
check ActualAndPriorBackingDeterminePostBacking for 6 Int
check ActualAndPriorBackingDetermineBudgetGap for 6 Int
check ExplicitPostBackingDeterminesSelectedProjection for 6 Int
