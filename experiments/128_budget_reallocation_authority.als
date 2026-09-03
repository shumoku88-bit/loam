module experiments/observation_128_budget_reallocation_authority

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Holding {
  quantity: one Int
}
one sig Bank, Cash extends Holding {}

-- World-specific signed deltas deliberately reuse one balanced-movement shape.
-- Capacity is indexed only by Purpose. Backing is indexed by Holding x Purpose.
abstract sig World {
  capacityDelta: Purpose -> one Int,
  backingDelta: Holding -> Purpose -> one Int
}
one sig Before, CapacityOnly, BackingBank, BackingCash, BothBank, CopyBothBank extends World {}

fun capDelta[w: World, p: Purpose]: one Int {
  p.(w.capacityDelta)
}

fun backDelta[w: World, h: Holding, p: Purpose]: one Int {
  p.(h.(w.backingDelta))
}

fun baseCapacity[p: Purpose]: one Int {
  p = Food => 6 else 4
}

fun baseBacking[h: Holding, p: Purpose]: one Int {
  h = Bank and p = Food => 4 else
  h = Bank and p = Travel => 1 else
  h = Cash and p = Food => 2 else
  3
}

fun entitlement[w: World, p: Purpose]: one Int {
  add[baseCapacity[p], capDelta[w, p]]
}

fun backingAt[w: World, h: Holding, p: Purpose]: one Int {
  add[baseBacking[h, p], backDelta[w, h, p]]
}

fun totalBacked[w: World, p: Purpose]: one Int {
  sum h: Holding | backingAt[w, h, p]
}

-- A selected-holding view is intentionally retained as a household question.
-- It exposes whether erasing the Holding coordinate from Backing loses meaning.
fun bankBacked[w: World, p: Purpose]: one Int {
  backingAt[w, Bank, p]
}

fun funded[w: World, p: Purpose]: one Int {
  let e = entitlement[w, p], b = totalBacked[w, p] |
    b >= e => e else b
}

fun gap[w: World, p: Purpose]: one Int {
  sub[entitlement[w, p], funded[w, p]]
}

fun aggregateBackingDelta[w: World, p: Purpose]: one Int {
  sum h: Holding | backDelta[w, h, p]
}

pred zeroCapacity[w: World] {
  all p: Purpose | capDelta[w, p] = 0
}

pred moveCapacity[w: World] {
  capDelta[w, Food] = -2
  capDelta[w, Travel] = 2
}

pred zeroBacking[w: World] {
  all h: Holding, p: Purpose | backDelta[w, h, p] = 0
}

pred moveBacking[w: World, subject: Holding] {
  backDelta[w, subject, Food] = -2
  backDelta[w, subject, Travel] = 2
  all h: Holding - subject, p: Purpose |
    backDelta[w, h, p] = 0
}

pred capacityChanges[w: World] {
  some p: Purpose | capDelta[w, p] != 0
}

pred backingChanges[w: World] {
  some h: Holding, p: Purpose | backDelta[w, h, p] != 0
}

fact Specimen {
  Bank.quantity = 5
  Cash.quantity = 5

  zeroCapacity[Before]
  zeroBacking[Before]

  moveCapacity[CapacityOnly]
  zeroBacking[CapacityOnly]

  zeroCapacity[BackingBank]
  moveBacking[BackingBank, Bank]

  zeroCapacity[BackingCash]
  moveBacking[BackingCash, Cash]

  moveCapacity[BothBank]
  moveBacking[BothBank, Bank]

  -- Keep an inhabited duplicate of the fully typed evidence so the final
  -- sufficiency assertion is not qualified only vacuously.
  moveCapacity[CopyBothBank]
  moveBacking[CopyBothBank, Bank]

  -- Bounded admission: neither Capacity nor per-Holding Backing may become
  -- negative, and Backing assigned from one Holding may not exceed its stock.
  all w: World, p: Purpose |
    entitlement[w, p] >= 0
  all w: World, h: Holding, p: Purpose |
    backingAt[w, h, p] >= 0
  all w: World, h: Holding |
    (sum p: Purpose | backingAt[w, h, p]) <= h.quantity
}

-- The same household-facing phrase "move 2 from Food to Travel" can have
-- three observably different authority readings.
pred sameSurfaceTransferSupportsThreeAuthorityReadings {
  capacityChanges[CapacityOnly]
  not backingChanges[CapacityOnly]

  not capacityChanges[BackingBank]
  backingChanges[BackingBank]

  capacityChanges[BothBank]
  backingChanges[BothBank]

  gap[CapacityOnly, Food] = 0
  gap[CapacityOnly, Travel] = 2

  gap[BackingBank, Food] = 2
  gap[BackingBank, Travel] = 0

  gap[BothBank, Food] = 0
  gap[BothBank, Travel] = 0
}

-- Even after fixing Backing authority and the aggregate Purpose vector,
-- which Holding carried the reallocation changes a selected-holding answer.
pred sameBackingPurposeVectorDifferentHoldingAnswer {
  all p: Purpose |
    aggregateBackingDelta[BackingBank, p] =
      aggregateBackingDelta[BackingCash, p]

  bankBacked[BackingBank, Food] != bankBacked[BackingCash, Food]
  bankBacked[BackingBank, Travel] != bankBacked[BackingCash, Travel]
}

pred composedCapacityAndBackingClosesDifferentGaps {
  gap[CapacityOnly, Travel] > 0
  gap[BackingBank, Food] > 0
  gap[BothBank, Food] = 0
  gap[BothBank, Travel] = 0
}

pred inhabitedTypedDeltaCopy {
  all p: Purpose |
    capDelta[BothBank, p] = capDelta[CopyBothBank, p]
  all h: Holding, p: Purpose |
    backDelta[BothBank, h, p] = backDelta[CopyBothBank, h, p]

  all p: Purpose | {
    entitlement[BothBank, p] = entitlement[CopyBothBank, p]
    totalBacked[BothBank, p] = totalBacked[CopyBothBank, p]
    bankBacked[BothBank, p] = bankBacked[CopyBothBank, p]
    funded[BothBank, p] = funded[CopyBothBank, p]
    gap[BothBank, p] = gap[CopyBothBank, p]
  }
}

-- Deliberately too strong: one user-facing reallocation must belong to exactly
-- one authority plane. BothBank is the expected counterexample; a practical UI
-- may need to compose two evidence changes rather than invent one combined fact.
assert OneSemanticPlanePerReallocationIsEnough {
  all w: World - Before |
    capacityChanges[w] iff not backingChanges[w]
}

-- Deliberately too strong: Backing plane + Purpose delta alone determines the
-- selected-holding Backing answer. BackingBank / BackingCash should refute it.
assert BackingPlanePurposeVectorDeterminesSelectedBacking {
  all w1, w2: World |
    (all p: Purpose |
      aggregateBackingDelta[w1, p] = aggregateBackingDelta[w2, p]) implies
        all p: Purpose |
          bankBacked[w1, p] = bankBacked[w2, p]
}

-- Capacity already has the smaller Purpose coordinate observed in 106.
assert CapacityPurposeDeltaDeterminesEntitlement {
  all w1, w2: World |
    (all p: Purpose |
      capDelta[w1, p] = capDelta[w2, p]) implies
        all p: Purpose |
          entitlement[w1, p] = entitlement[w2, p]
}

-- Once the Backing delta retains Holding x Purpose coordinates, the selected
-- Backing answers should be fixed in this bounded specimen.
assert HoldingPurposeBackingDeltaDeterminesBackingAnswers {
  all w1, w2: World |
    (all h: Holding, p: Purpose |
      backDelta[w1, h, p] = backDelta[w2, h, p]) implies
        all p: Purpose | {
          totalBacked[w1, p] = totalBacked[w2, p]
          bankBacked[w1, p] = bankBacked[w2, p]
        }
}

-- The candidate compression under test: reuse signed movement mechanics, but
-- preserve domain-specific coordinates rather than adding EnvelopeTransfer.
assert TypedDeltasDetermineBudgetProjection {
  all w1, w2: World |
    (all p: Purpose |
      capDelta[w1, p] = capDelta[w2, p]) and
    (all h: Holding, p: Purpose |
      backDelta[w1, h, p] = backDelta[w2, h, p]) implies
        all p: Purpose | {
          entitlement[w1, p] = entitlement[w2, p]
          totalBacked[w1, p] = totalBacked[w2, p]
          bankBacked[w1, p] = bankBacked[w2, p]
          funded[w1, p] = funded[w2, p]
          gap[w1, p] = gap[w2, p]
        }
}

run sameSurfaceTransferSupportsThreeAuthorityReadings for 6 Int
run sameBackingPurposeVectorDifferentHoldingAnswer for 6 Int
run composedCapacityAndBackingClosesDifferentGaps for 6 Int
run inhabitedTypedDeltaCopy for 6 Int
check OneSemanticPlanePerReallocationIsEnough for 6 Int
check BackingPlanePurposeVectorDeterminesSelectedBacking for 6 Int
check CapacityPurposeDeltaDeterminesEntitlement for 6 Int
check HoldingPurposeBackingDeltaDeterminesBackingAnswers for 6 Int
check TypedDeltasDetermineBudgetProjection for 6 Int
