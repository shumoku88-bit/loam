module discharge_correspondence_minimum

abstract sig Party {}
one sig Household, OutsideA, OutsideB extends Party {}

sig Event {}
sig Unit {}

sig World {
  incurred: set Unit,
  burden: set Unit,
  claims: set Unit,
  debtor: Unit -> lone Party,
  creditor: Unit -> lone Party,
  origin: Unit -> lone Event,
  events: set Event,
  cashOut: Event -> set Unit,
  cashIn: Event -> set Unit,
  discharges: Event -> set Unit
}

fact WellFormedWorlds {
  all w: World {
    w.burden in w.incurred
    w.claims in w.incurred

    all u: w.incurred | one w.origin[u] and w.origin[u] in w.events
    all u: Unit - w.incurred | no w.origin[u]

    all u: w.claims | {
      one w.debtor[u]
      one w.creditor[u]
      w.debtor[u] != w.creditor[u]
      w.debtor[u] = Household or w.creditor[u] = Household
    }

    all u: Unit - w.claims |
      no w.debtor[u] and no w.creditor[u]

    all e: w.events | {
      w.discharges[e] in w.claims
      w.cashOut[e] in w.incurred
      w.cashIn[e] in w.incurred
    }

    all e: Event - w.events |
      no w.discharges[e] and no w.cashOut[e] and no w.cashIn[e]

    all u: w.claims |
      lone {e: w.events | u in w.discharges[e]}

    all e: w.events, u: w.discharges[e] | {
      w.debtor[u] = Household implies u in w.cashOut[e]
      w.creditor[u] = Household implies u in w.cashIn[e]
    }
  }
}

fun discharged[w: World]: set Unit {
  {u: w.claims | some e: w.events | u in w.discharges[e]}
}

fun outstanding[w: World]: set Unit {
  w.claims - discharged[w]
}

fun householdPayables[w: World]: set Unit {
  {u: w.claims | w.debtor[u] = Household}
}

fun householdReceivables[w: World]: set Unit {
  {u: w.claims | w.creditor[u] = Household}
}

fun payableOutstanding[w: World]: set Unit {
  outstanding[w] & householdPayables[w]
}

fun receivableOutstanding[w: World]: set Unit {
  outstanding[w] & householdReceivables[w]
}

fun outstandingFrom[w: World, source: Event]: set Unit {
  {u: outstanding[w] | w.origin[u] = source}
}

pred batchDischargeWitness {
  some w: World, purchaseA, purchaseB, debit: Event,
       uA, uB: Unit | {
    purchaseA != purchaseB
    purchaseA != debit
    purchaseB != debit
    uA != uB

    w.events = purchaseA + purchaseB + debit
    w.incurred = uA + uB
    w.burden = w.incurred
    w.claims = w.incurred
    w.origin[uA] = purchaseA
    w.origin[uB] = purchaseB

    w.debtor[uA] = Household
    w.creditor[uA] = OutsideA
    w.debtor[uB] = Household
    w.creditor[uB] = OutsideA

    no w.cashOut[purchaseA]
    no w.cashOut[purchaseB]
    no w.cashIn[purchaseA]
    no w.cashIn[purchaseB]
    w.cashOut[debit] = uA + uB
    no w.cashIn[debit]
    w.discharges[debit] = uA + uB

    no outstanding[w]
  }
}

pred partialDischargeWitness {
  some w: World, purchase, debitA, debitB: Event,
       uA, uB: Unit | {
    purchase != debitA
    purchase != debitB
    debitA != debitB
    uA != uB

    w.events = purchase + debitA + debitB
    w.incurred = uA + uB
    w.burden = w.incurred
    w.claims = w.incurred
    w.origin[uA] = purchase
    w.origin[uB] = purchase

    all u: w.claims | {
      w.debtor[u] = Household
      w.creditor[u] = OutsideA
    }

    w.cashOut[debitA] = uA
    w.cashOut[debitB] = uB
    no w.cashIn[debitA]
    no w.cashIn[debitB]
    w.discharges[debitA] = uA
    w.discharges[debitB] = uB

    no outstanding[w]
  }
}

pred sameCashDifferentDischargeWitness {
  some left, right: World, originA, originB, payment: Event,
       uA, uB: Unit | {
    left != right
    originA != originB
    originA != payment
    originB != payment
    uA != uB

    left.events = right.events
    left.events = originA + originB + payment
    left.incurred = right.incurred
    left.incurred = uA + uB
    left.burden = right.burden
    left.burden = left.incurred
    left.claims = right.claims
    left.claims = left.incurred
    left.debtor = right.debtor
    left.creditor = right.creditor
    left.origin = right.origin

    left.origin[uA] = originA
    left.origin[uB] = originB
    all u: left.claims | {
      left.debtor[u] = Household
      left.creditor[u] = OutsideA
    }

    left.cashOut = right.cashOut
    left.cashIn = right.cashIn
    left.cashOut[payment] = uA + uB
    no left.cashIn[payment]

    left.discharges[payment] = uA
    right.discharges[payment] = uB

    #outstandingFrom[left, originA] = 0
    #outstandingFrom[right, originA] = 1
    #outstanding[left] = #outstanding[right]
  }
}

pred directionProjectionWitness {
  some w: World, sourceA, sourceB: Event, payable, receivable: Unit | {
    sourceA != sourceB
    payable != receivable

    w.events = sourceA + sourceB
    w.incurred = payable + receivable
    w.burden = payable
    w.claims = w.incurred
    w.origin[payable] = sourceA
    w.origin[receivable] = sourceB

    w.debtor[payable] = Household
    w.creditor[payable] = OutsideA
    w.debtor[receivable] = OutsideB
    w.creditor[receivable] = Household

    no w.discharges[sourceA]
    no w.discharges[sourceB]

    payableOutstanding[w] = payable
    receivableOutstanding[w] = receivable
  }
}

pred unmatchedMovementNeedsNoClaimWitness {
  some w: World, purchase: Event, u: Unit | {
    w.events = purchase
    w.incurred = u
    w.burden = u
    no w.claims
    w.origin[u] = purchase
    w.cashOut[purchase] = u
    no w.cashIn[purchase]
    no w.discharges[purchase]
    no outstanding[w]
  }
}

assert ClaimPartition {
  all w: World |
    w.claims = discharged[w] + outstanding[w]
    and no (discharged[w] & outstanding[w])
}

assert DischargeCorrespondenceDeterminesOutstanding {
  all left, right: World |
    left.claims = right.claims and
    left.events = right.events and
    left.discharges = right.discharges
    implies
    outstanding[left] = outstanding[right]
}

assert NoClaimUnitDischargedTwice {
  all w: World, u: w.claims |
    lone {e: w.events | u in w.discharges[e]}
}

run batchDischargeWitness for 8 but exactly 3 Party, 5 Event, 5 Unit, 1 World
run partialDischargeWitness for 8 but exactly 3 Party, 5 Event, 5 Unit, 1 World
run sameCashDifferentDischargeWitness for 9 but exactly 3 Party, 5 Event, 5 Unit, 2 World
run directionProjectionWitness for 7 but exactly 3 Party, 4 Event, 4 Unit, 1 World
run unmatchedMovementNeedsNoClaimWitness for 6 but exactly 3 Party, 3 Event, 3 Unit, 1 World

check ClaimPartition for 8 but exactly 3 Party, 5 Event, 5 Unit, 3 World
check DischargeCorrespondenceDeterminesOutstanding for 8 but exactly 3 Party, 5 Event, 5 Unit, 3 World
check NoClaimUnitDischargedTwice for 8 but exactly 3 Party, 5 Event, 5 Unit, 3 World
