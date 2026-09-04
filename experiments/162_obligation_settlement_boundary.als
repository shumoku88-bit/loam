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

pred sameBasis[pre: World, post: World] {
  pre != post
  post.incurred = pre.incurred
  post.burden = pre.burden
  post.claims = pre.claims
  post.debtor = pre.debtor
  post.creditor = pre.creditor
}

pred settleCore[pre: World, post: World, u: Unit] {
  sameBasis[pre, post]
  u in pre.claims - pre.settled
  post.settled = pre.settled + u
}

pred settleHouseholdPayable[pre: World, post: World, u: Unit] {
  settleCore[pre, post, u]
  pre.debtor[u] = Household
  pre.creditor[u] != Household
  post.cashOut = pre.cashOut + u
  post.cashIn = pre.cashIn
}

pred settleHouseholdReceivable[pre: World, post: World, u: Unit] {
  settleCore[pre, post, u]
  pre.creditor[u] = Household
  pre.debtor[u] != Household
  post.cashIn = pre.cashIn + u
  post.cashOut = pre.cashOut
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
  some sharedPre, sharedPost, cardPre, cardPost: World,
       sharedUnit, cardUnit: Unit | {
    sharedPre != sharedPost
    cardPre != cardPost
    sharedUnit != cardUnit

    sharedUnit in sharedPre.claims
    sharedUnit not in sharedPre.burden
    sharedPre.debtor[sharedUnit] = Friend
    sharedPre.creditor[sharedUnit] = Household
    sharedPre.cashOut = sharedPre.incurred
    no sharedPre.cashIn
    no sharedPre.settled
    settleHouseholdReceivable[sharedPre, sharedPost, sharedUnit]

    cardUnit in cardPre.claims
    cardUnit in cardPre.burden
    cardPre.debtor[cardUnit] = Household
    cardPre.creditor[cardUnit] = CardIssuer
    no cardPre.cashOut
    no cardPre.cashIn
    no cardPre.settled
    settleHouseholdPayable[cardPre, cardPost, cardUnit]
  }
}

pred cardSettlementChangesCashNotBurden {
  some pre, post: World, u: Unit | {
    #pre.incurred = 1
    pre.burden = pre.incurred
    pre.claims = pre.incurred
    no pre.settled
    no pre.cashOut
    no pre.cashIn
    pre.debtor[u] = Household
    pre.creditor[u] = CardIssuer
    u in pre.claims

    settleHouseholdPayable[pre, post, u]

    pre.burden = post.burden
    u not in pre.cashOut
    u in post.cashOut
    #payableOutstanding[pre] = 1
    #payableOutstanding[post] = 0
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
  all pre, post: World, u: Unit |
    settleCore[pre, post, u] implies
      post.burden = pre.burden
}

assert SettlementDischargesExactlyOneClaim {
  all pre, post: World, u: Unit |
    settleCore[pre, post, u] implies
      post.claims - post.settled = (pre.claims - pre.settled) - u
}

run sharedCostOpenWitness for 6 but exactly 3 Party, 4 Unit, 2 World
run cardPurchaseOpenWitness for 6 but exactly 3 Party, 4 Unit, 2 World
run sameSettlementCoreOppositeDirections for 8 but exactly 3 Party, 5 Unit, 4 World
run cardSettlementChangesCashNotBurden for 6 but exactly 3 Party, 3 Unit, 2 World
run directPurchaseNeedsNoObligation for 5 but exactly 3 Party, 2 Unit, 1 World

check ObligationConservation for 7 but exactly 3 Party, 5 Unit, 3 World
check SettlementCorePreservesBurden for 7 but exactly 3 Party, 5 Unit, 3 World
check SettlementDischargesExactlyOneClaim for 7 but exactly 3 Party, 5 Unit, 3 World
