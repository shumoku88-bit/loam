module experiments/observation_126_capacity_backing_topology

abstract sig Purpose {}
one sig Food, Travel extends Purpose {}

abstract sig Holding {
  quantity: one Int
}
one sig Bank, Points extends Holding {}

abstract sig CapacityClaim {
  purpose: one Purpose,
  quantity: one Int
}
one sig FoodCapacity, TravelCapacity extends CapacityClaim {}

abstract sig World {
  eligible: set Holding,
  backing: Holding -> lone Purpose
}
one sig Left, Right extends World {}

fact Specimen {
  Bank.quantity = 6
  Points.quantity = 4

  FoodCapacity.purpose = Food
  FoodCapacity.quantity = 6
  TravelCapacity.purpose = Travel
  TravelCapacity.quantity = 4

  -- Observation 048 already established that eligibility is additional to
  -- physical holding. Keep that overlay fixed here so only topology varies.
  all w: World | w.eligible = Holding
  all w: World, h: Holding, p: Purpose |
    h->p in w.backing implies h in w.eligible

  -- Same holdings, same Capacity, same eligibility; only Backing topology differs.
  Left.backing = Bank->Food + Points->Travel
  Right.backing = Bank->Travel + Points->Food
}

fun entitlement[p: Purpose]: one Int {
  sum c: { c: CapacityClaim | c.purpose = p } | c.quantity
}

fun backed[w: World, p: Purpose]: one Int {
  sum h: { h: Holding | h->p in w.backing } | h.quantity
}

fun funded[w: World, p: Purpose]: one Int {
  let e = entitlement[p], b = backed[w, p] |
    b >= e => e else b
}

fun totalEligible[w: World]: one Int {
  sum h: w.eligible | h.quantity
}

fun totalEntitlement: one Int {
  sum c: CapacityClaim | c.quantity
}

fun totalFunded[w: World]: one Int {
  sum p: Purpose | funded[w, p]
}

pred backingTopologyChangesPurposeFunding {
  totalEligible[Left] = totalEligible[Right]
  totalEligible[Left] = totalEntitlement
  funded[Left, Food] = entitlement[Food]
  funded[Right, Food] < entitlement[Food]
}

pred capacityCanRemainUnderbacked {
  some w: World, p: Purpose |
    entitlement[p] > backed[w, p]
}

pred backingCanExceedCapacity {
  some w: World, p: Purpose |
    backed[w, p] > entitlement[p]
}

pred sameAggregateFundingDifferentPurposeAnswer {
  totalEligible[Left] = totalEligible[Right]
  totalEligible[Left] = totalEntitlement
  totalFunded[Left] != totalFunded[Right]
}

assert CapacityAndEligibilityDeterminePurposeFunding {
  all w1, w2: World |
    w1.eligible = w2.eligible implies
      all p: Purpose | funded[w1, p] = funded[w2, p]
}

assert AggregateEligibleQuantityDeterminesTotalFunded {
  all w1, w2: World |
    totalEligible[w1] = totalEligible[w2] implies
      totalFunded[w1] = totalFunded[w2]
}

assert ExplicitBackingDeterminesSelectedFunding {
  all w1, w2: World |
    w1.eligible = w2.eligible and w1.backing = w2.backing implies {
      all p: Purpose | {
        backed[w1, p] = backed[w2, p]
        funded[w1, p] = funded[w2, p]
      }
      totalFunded[w1] = totalFunded[w2]
    }
}

run backingTopologyChangesPurposeFunding for 5 Int
run capacityCanRemainUnderbacked for 5 Int
run backingCanExceedCapacity for 5 Int
run sameAggregateFundingDifferentPurposeAnswer for 5 Int
check CapacityAndEligibilityDeterminePurposeFunding for 5 Int
check AggregateEligibleQuantityDeterminesTotalFunded for 5 Int
check ExplicitBackingDeterminesSelectedFunding for 5 Int
