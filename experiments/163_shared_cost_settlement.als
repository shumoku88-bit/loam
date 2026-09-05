module experiments/observation_163_shared_cost_settlement

sig Cost {}

sig Unit {
  cost: one Cost
}

abstract sig Bearer {}
one sig Household extends Bearer {}
sig Outside extends Bearer {}

abstract sig OffsetKind {}
one sig MerchantRefund, SharedSettlement extends OffsetKind {}

sig World {
  paid: set Unit,
  offset: set Unit,
  bearer: Unit -> lone Bearer,
  settled: set Unit,
  offsetKind: Unit -> lone OffsetKind
}

one sig Left, Right extends World {}

fact WellFormedEvidence {
  all w: World | {
    w.offset in w.paid
    w.settled in w.paid

    w.bearer in w.paid -> Bearer
    all u: Unit | (u in w.paid) iff one u.(w.bearer)

    w.offsetKind in w.offset -> OffsetKind
    all u: Unit | (u in w.offset) iff one u.(w.offsetKind)

    all u: w.offset | {
      u.(w.offsetKind) = MerchantRefund implies
        u.(w.bearer) = Household
      u.(w.offsetKind) = SharedSettlement implies
        u.(w.bearer) in Outside
    }

    all u: Unit |
      (u in w.settled) iff
        (u in w.offset and u.(w.offsetKind) = SharedSettlement)
  }
}

fun paidFor[w: World, c: Cost]: set Unit {
  { u: w.paid | u.cost = c }
}

fun offsetFor[w: World, c: Cost]: set Unit {
  { u: w.offset | u.cost = c }
}

fun refundUnits[w: World, c: Cost]: set Unit {
  { u: w.offset |
    u.cost = c and u.(w.offsetKind) = MerchantRefund
  }
}

fun sharedSettlementUnits[w: World, c: Cost]: set Unit {
  { u: w.offset |
    u.cost = c and u.(w.offsetKind) = SharedSettlement
  }
}

fun householdBorne[w: World, c: Cost]: set Unit {
  { u: w.paid |
    u.cost = c and u.(w.bearer) = Household
  }
}

fun outsideBorne[w: World, c: Cost]: set Unit {
  { u: w.paid |
    u.cost = c and u.(w.bearer) in Outside
  }
}

fun netExpense[w: World, c: Cost]: one Int {
  sub[#paidFor[w, c], #offsetFor[w, c]]
}

fun householdBurden[w: World, c: Cost]: one Int {
  sub[#householdBorne[w, c], #refundUnits[w, c]]
}

fun outsideOutstanding[w: World, c: Cost]: one Int {
  #{ u: outsideBorne[w, c] | u not in w.settled }
}

fun outsideOutstandingFor[w: World, c: Cost, b: Outside]: one Int {
  #{ u: w.paid |
    u.cost = c and u.(w.bearer) = b and u not in w.settled
  }
}

pred sameNetDifferentMeaning {
  some c: Cost, disj ownUnit, returnedUnit: Unit, friend: Outside | {
    ownUnit.cost = c
    returnedUnit.cost = c

    Left.paid = ownUnit + returnedUnit
    Right.paid = ownUnit + returnedUnit
    Left.offset = returnedUnit
    Right.offset = returnedUnit

    Left.bearer = ownUnit->Household + returnedUnit->Household
    Right.bearer = ownUnit->Household + returnedUnit->friend

    Left.offsetKind = returnedUnit->MerchantRefund
    Right.offsetKind = returnedUnit->SharedSettlement
    no Left.settled
    Right.settled = returnedUnit

    netExpense[Left, c] = 1
    netExpense[Right, c] = 1
    householdBurden[Left, c] = 1
    householdBurden[Right, c] = 1

    one refundUnits[Left, c]
    no refundUnits[Right, c]
    no sharedSettlementUnits[Left, c]
    one sharedSettlementUnits[Right, c]
  }
}

pred preSettlementOutstandingPressure {
  some c: Cost, disj ownUnit, sharedUnit: Unit, friend: Outside | {
    ownUnit.cost = c
    sharedUnit.cost = c

    Left.paid = ownUnit + sharedUnit
    Right.paid = ownUnit + sharedUnit
    no Left.offset
    no Right.offset
    no Left.offsetKind
    no Right.offsetKind
    no Left.settled
    no Right.settled

    Left.bearer = ownUnit->Household + sharedUnit->Household
    Right.bearer = ownUnit->Household + sharedUnit->friend

    netExpense[Left, c] = 2
    netExpense[Right, c] = 2

    householdBurden[Left, c] = 2
    householdBurden[Right, c] = 1
    outsideOutstanding[Left, c] = 0
    outsideOutstanding[Right, c] = 1
  }
}

pred settlementChangesOutstandingNotBurden {
  some c: Cost, disj ownUnit, sharedUnit: Unit, friend: Outside | {
    ownUnit.cost = c
    sharedUnit.cost = c

    Left.paid = ownUnit + sharedUnit
    Right.paid = ownUnit + sharedUnit
    Left.bearer = ownUnit->Household + sharedUnit->friend
    Right.bearer = ownUnit->Household + sharedUnit->friend

    no Left.offset
    no Left.offsetKind
    no Left.settled

    Right.offset = sharedUnit
    Right.offsetKind = sharedUnit->SharedSettlement
    Right.settled = sharedUnit

    householdBurden[Left, c] = 1
    householdBurden[Right, c] = 1
    outsideOutstanding[Left, c] = 1
    outsideOutstanding[Right, c] = 0
    netExpense[Left, c] = 2
    netExpense[Right, c] = 1
  }
}

pred multipleBearerIdentityPressure {
  some c: Cost,
       disj firstUnit, secondUnit, thirdUnit: Unit,
       disj alice, bob: Outside | {
    firstUnit.cost = c
    secondUnit.cost = c
    thirdUnit.cost = c

    Left.paid = firstUnit + secondUnit + thirdUnit
    Right.paid = firstUnit + secondUnit + thirdUnit
    no Left.offset
    no Right.offset
    no Left.offsetKind
    no Right.offsetKind
    no Left.settled
    no Right.settled

    Left.bearer = firstUnit->alice + secondUnit->alice + thirdUnit->bob
    Right.bearer = firstUnit->alice + secondUnit->bob + thirdUnit->bob

    outsideBorne[Left, c] = outsideBorne[Right, c]
    outsideOutstanding[Left, c] = 3
    outsideOutstanding[Right, c] = 3
    outsideOutstandingFor[Left, c, alice] = 2
    outsideOutstandingFor[Right, c, alice] = 1
  }
}

assert NetDecomposesIntoBurdenAndOutstanding {
  all w: World, c: Cost |
    netExpense[w, c] =
      add[householdBurden[w, c], outsideOutstanding[w, c]]
}

assert SettlementCannotChangeBurdenWhenAllocationAndRefundsAgree {
  all left, right: World, c: Cost |
    left.paid = right.paid and
    left.bearer = right.bearer and
    refundUnits[left, c] = refundUnits[right, c]
    implies
      householdBurden[left, c] = householdBurden[right, c]
}

assert AnonymousExternalOutstandingIgnoresBearerIdentity {
  all left, right: World, c: Cost |
    outsideBorne[left, c] = outsideBorne[right, c] and
    left.settled = right.settled
    implies
      outsideOutstanding[left, c] = outsideOutstanding[right, c]
}

run sameNetDifferentMeaning for exactly 1 Cost, exactly 3 Unit, exactly 2 Outside, exactly 2 World, 5 Int
run preSettlementOutstandingPressure for exactly 1 Cost, exactly 3 Unit, exactly 2 Outside, exactly 2 World, 5 Int
run settlementChangesOutstandingNotBurden for exactly 1 Cost, exactly 3 Unit, exactly 2 Outside, exactly 2 World, 5 Int
run multipleBearerIdentityPressure for exactly 1 Cost, exactly 3 Unit, exactly 2 Outside, exactly 2 World, 5 Int
check NetDecomposesIntoBurdenAndOutstanding for exactly 2 Cost, exactly 4 Unit, exactly 2 Outside, exactly 2 World, 5 Int
check SettlementCannotChangeBurdenWhenAllocationAndRefundsAgree for exactly 2 Cost, exactly 4 Unit, exactly 2 Outside, exactly 2 World, 5 Int
check AnonymousExternalOutstandingIgnoresBearerIdentity for exactly 2 Cost, exactly 4 Unit, exactly 2 Outside, exactly 2 World, 5 Int
