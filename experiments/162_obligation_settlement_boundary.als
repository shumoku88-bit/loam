module obligation_settlement_boundary

abstract sig Party {}
one sig Household, CardIssuer, Friend extends Party {}

sig Unit {}

sig World {
  incurred: set Unit,
  burden: set Unit,
  claims: set Unit,
  debtor: Unit -> lone Party,
  creditor: Unit -> lone Party,
  settled: set Unit,
  cashOut: set Unit,
  cashIn: set Unit
}

fact WellFormedWorlds {
  all w: World {
    w.burden in w.incurred
    w.claims in w.incurred
    w.settled in w.claims
    w.cashOut in w.incurred
    w.cashIn in w.incurred

    all u: w.claims |
      one w.debtor[u] and
      one w.creditor[u] and
      w.debtor[u] != w.creditor[u]

    all u: Unit - w.claims |
      no w.debtor[u] and no w.creditor[u]

    all u: w.settled |
      (w.debtor[u] = Household implies u in w.cashOut) and
      (w.creditor[u] = Household implies u in w.cashIn)
  }
}

fun householdPayables[w: World]: set Unit {
  {u: w.claims | w.debtor[u] = Household and w.creditor[u] != Household}
}

fun householdReceivables[w: World]: set Unit {
  {u: w.claims | w.creditor[u] = Household and w.debtor[u] != Household}
}

fun payableOutstanding[w: World]: set Unit {
  householdPayables[w] - w.settled
}

fun receivableOutstanding[w: World]: set Unit {
  householdReceivables[w] - w.settled
}

pred sameBasis[before, after: World] {
  before != after
  after.incurred = before.incurred
  after.burden = before.burden
  after.claims = before.claims
  after.debtor = before.debtor
  after.creditor = before.creditor
}

pred settleCore[before, after: World, u: Unit] {
  sameBasis[before, after]
  u in before.claims - before.settled
  after.settled = before.settled + u
}

pred settleHouseholdPayable[before, after: World, u: Unit] {
  settleCore[before, after, u]
  before.debtor[u] = Household
  before.creditor[u] != Household
  after.cashOut = before.cashOut + u
  after.cashIn = before.cashIn
}

pred settleHouseholdReceivable[before, after: World, u: Unit] {
  settleCore[before, after, u]
  before.creditor[u] = Household
  before.debtor[u] != Household
  after.cashIn = before.cashIn + u
  after.cashOut = before.cashOut
}

pred sharedCostOpenWitness {
  some w: World | {
    #w.incurred = 2
    #w.burden = 1
    w.cashOut = w.incurred
    no w.cashIn
    no w.settled

    one u: w.claims | {
      w.claims = u
      u not in w.burden
      w.debtor[u] = Friend
      w.creditor[u] = Household
    }

    #receivableOutstanding[w] = 1
    #payableOutstanding[w] = 0
  }
}

pred cardPurchaseOpenWitness {
  some w: World | {
    #w.incurred = 2
    w.burden = w.incurred
    w.claims = w.incurred
    no w.settled
    no w.cashOut
    no w.cashIn

    all u: w.claims | {
      w.debtor[u] = Household
      w.creditor[u] = CardIssuer
    }

    #payableOutstanding[w] = 2
    #receivableOutstanding[w] = 0
  }
}

pred sameSettlementCoreOppositeDirections {
  some sharedBefore, sharedAfter, cardBefore, cardAfter: World,
       sharedUnit, cardUnit: Unit | {
    sharedBefore != sharedAfter
    cardBefore != cardAfter
    sharedUnit != cardUnit

    sharedUnit in sharedBefore.claims
    sharedUnit not in sharedBefore.burden
    sharedBefore.debtor[sharedUnit] = Friend
    sharedBefore.creditor[sharedUnit] = Household
    sharedBefore.cashOut = sharedBefore.incurred
    no sharedBefore.cashIn
    no sharedBefore.settled
    settleHouseholdReceivable[sharedBefore, sharedAfter, sharedUnit]

    cardUnit in cardBefore.claims
    cardUnit in cardBefore.burden
    cardBefore.debtor[cardUnit] = Household
    cardBefore.creditor[cardUnit] = CardIssuer
    no cardBefore.cashOut
    no cardBefore.cashIn
    no cardBefore.settled
    settleHouseholdPayable[cardBefore, cardAfter, cardUnit]
  }
}

pred cardSettlementChangesCashNotBurden {
  some before, after: World, u: Unit | {
    #before.incurred = 1
    before.burden = before.incurred
    before.claims = before.incurred
    no before.settled
    no before.cashOut
    no before.cashIn
    before.debtor[u] = Household
    before.creditor[u] = CardIssuer
    u in before.claims

    settleHouseholdPayable[before, after, u]

    before.burden = after.burden
    u not in before.cashOut
    u in after.cashOut
    #payableOutstanding[before] = 1
    #payableOutstanding[after] = 0
  }
}

pred directPurchaseNeedsNoObligation {
  some w: World | {
    #w.incurred = 1
    w.burden = w.incurred
    w.cashOut = w.incurred
    no w.cashIn
    no w.claims
    no w.settled
  }
}

assert ObligationConservation {
  all w: World |
    #householdPayables[w] = #(w.settled & householdPayables[w]) + #payableOutstanding[w]
    and
    #householdReceivables[w] = #(w.settled & householdReceivables[w]) + #receivableOutstanding[w]
}

assert SettlementCorePreservesBurden {
  all before, after: World, u: Unit |
    settleCore[before, after, u] implies
      after.burden = before.burden
}

assert SettlementDischargesExactlyOneClaim {
  all before, after: World, u: Unit |
    settleCore[before, after, u] implies
      after.claims - after.settled = (before.claims - before.settled) - u
}

run sharedCostOpenWitness for 6 but exactly 3 Party, 4 Unit, 2 World
run cardPurchaseOpenWitness for 6 but exactly 3 Party, 4 Unit, 2 World
run sameSettlementCoreOppositeDirections for 8 but exactly 3 Party, 5 Unit, 4 World
run cardSettlementChangesCashNotBurden for 6 but exactly 3 Party, 3 Unit, 2 World
run directPurchaseNeedsNoObligation for 5 but exactly 3 Party, 2 Unit, 1 World

check ObligationConservation for 7 but exactly 3 Party, 5 Unit, 3 World
check SettlementCorePreservesBurden for 7 but exactly 3 Party, 5 Unit, 3 World
check SettlementDischargesExactlyOneClaim for 7 but exactly 3 Party, 5 Unit, 3 World
