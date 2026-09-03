module experiments/observation_127_backing_apportionment

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Holding {
  quantity: one Int
}
one sig Bank extends Holding {}

abstract sig CapacityClaim {
  purpose: one Purpose,
  quantity: one Int
}
one sig FoodCapacity, TravelCapacity extends CapacityClaim {}

abstract sig World {
  eligible: set Holding,
  share: Holding -> Purpose -> one Int
}
one sig Full, Skew, Copy extends World {}

fun entitlement[p: Purpose]: one Int {
  sum c: { c: CapacityClaim | c.purpose = p } | c.quantity
}

fun shareQty[w: World, h: Holding, p: Purpose]: one Int {
  p.(h.(w.share))
}

fun used[w: World, h: Holding]: one Int {
  sum p: Purpose | shareQty[w, h, p]
}

fun backed[w: World, p: Purpose]: one Int {
  sum h: Holding | shareQty[w, h, p]
}

fun funded[w: World, p: Purpose]: one Int {
  let e = entitlement[p], b = backed[w, p] |
    b >= e => e else b
}

fun totalFunded[w: World]: one Int {
  sum p: Purpose | funded[w, p]
}

fun topology[w: World]: Holding -> Purpose {
  { h: Holding, p: Purpose | shareQty[w, h, p] > 0 }
}

fact Specimen {
  Bank.quantity = 10

  FoodCapacity.purpose = Food
  FoodCapacity.quantity = 6
  TravelCapacity.purpose = Travel
  TravelCapacity.quantity = 4

  -- Eligibility is fixed here. Observation 126 already asks whether an
  -- eligible holding must additionally be related to a Capacity purpose.
  all w: World | w.eligible = Holding

  -- Backing shares are non-negative and cannot allocate more of one holding
  -- than physically exists in this bounded single-Measure specimen.
  all w: World, h: Holding, p: Purpose |
    shareQty[w, h, p] >= 0
  all w: World, h: Holding |
    used[w, h] <= h.quantity

  -- Same Holding, same Capacity, same eligibility, same quantity-free
  -- topology. Only apportionment differs.
  shareQty[Full, Bank, Food] = 6
  shareQty[Full, Bank, Travel] = 4

  shareQty[Skew, Bank, Food] = 4
  shareQty[Skew, Bank, Travel] = 6

  -- Keep an inhabited pair with identical quantity-bearing evidence so the
  -- final sufficiency assertion is not qualified only vacuously.
  shareQty[Copy, Bank, Food] = 6
  shareQty[Copy, Bank, Travel] = 4
}

pred oneHoldingCanFullyBackTwoPurposes {
  topology[Full] = Bank->Food + Bank->Travel
  used[Full, Bank] = Bank.quantity
  funded[Full, Food] = entitlement[Food]
  funded[Full, Travel] = entitlement[Travel]
}

pred sameTopologyDifferentApportionment {
  topology[Full] = topology[Skew]
  used[Full, Bank] = used[Skew, Bank]
  shareQty[Full, Bank, Food] != shareQty[Skew, Bank, Food]
}

pred sameTopologySameTotalDifferentFunding {
  topology[Full] = topology[Skew]
  used[Full, Bank] = used[Skew, Bank]
  totalFunded[Full] != totalFunded[Skew]
}

pred partialBackingAppearsWithoutCapacityChange {
  entitlement[Food] = 6
  funded[Full, Food] = 6
  funded[Skew, Food] = 4
}

pred identicalSharesRecoverSameAnswer {
  all h: Holding, p: Purpose |
    shareQty[Full, h, p] = shareQty[Copy, h, p]
  all p: Purpose |
    funded[Full, p] = funded[Copy, p]
}

assert TopologyDeterminesPurposeFunding {
  all w1, w2: World |
    topology[w1] = topology[w2] implies
      all p: Purpose | funded[w1, p] = funded[w2, p]
}

assert TopologyAndUsedQuantityDeterminePurposeFunding {
  all w1, w2: World |
    topology[w1] = topology[w2] and
    (all h: Holding | used[w1, h] = used[w2, h]) implies
      all p: Purpose | funded[w1, p] = funded[w2, p]
}

assert QuantitySharesDetermineSelectedFunding {
  all w1, w2: World |
    (all h: Holding, p: Purpose |
      shareQty[w1, h, p] = shareQty[w2, h, p]) implies {
        all p: Purpose | {
          backed[w1, p] = backed[w2, p]
          funded[w1, p] = funded[w2, p]
        }
        totalFunded[w1] = totalFunded[w2]
      }
}

run oneHoldingCanFullyBackTwoPurposes for 6 Int
run sameTopologyDifferentApportionment for 6 Int
run sameTopologySameTotalDifferentFunding for 6 Int
run partialBackingAppearsWithoutCapacityChange for 6 Int
run identicalSharesRecoverSameAnswer for 6 Int
check TopologyDeterminesPurposeFunding for 6 Int
check TopologyAndUsedQuantityDeterminePurposeFunding for 6 Int
check QuantitySharesDetermineSelectedFunding for 6 Int
