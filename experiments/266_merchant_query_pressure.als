module experiments/observation_266_merchant_query_pressure

-- Observation 266 asks for the smallest independent relation needed by an exact
-- cross-Event merchant-expense query. Quantity remains derived from existing
-- Effects plus explicit AccountingRole evidence.

sig Locus {}
sig Measure {}
sig Event {}
sig Party {}

sig Cell {
  locus: one Locus,
  measure: one Measure
}

abstract sig AccountingRole {}
one sig AssetRole, ExpenseRole extends AccountingRole {}

abstract sig World {
  present: set Event,
  effect: Event -> Cell -> lone Int,
  role: Locus -> lone AccountingRole,
  merchant: Event -> lone Party,
  selectedCounterparty: Event -> lone Party,
  -- Future negative control only, not a production proposal.
  sellerAt: Event -> Cell -> lone Party
}

one sig Left, Right extends World {}

fact CoordinateCells {
  all l: Locus, m: Measure |
    one c: Cell | c.locus = l and c.measure = m

  all disj a, b: Cell |
    a.locus != b.locus or a.measure != b.measure
}

fact WellFormed {
  all w: World | {
    w.effect.Int in w.present -> Cell
    w.merchant in w.present -> Party
    w.selectedCounterparty in w.present -> Party
    w.sellerAt in w.present -> Cell -> Party

    all e: w.present, c: Cell |
      let n = amount[w, e, c] |
        n >= -6 and n <= 6
  }
}

fun amount[w: World, e: Event, c: Cell]: one Int {
  sum { i: Int | e->c->i in w.effect }
}

fun expenseContribution[w: World, e: Event, c: Cell, m: Measure]: one Int {
  (c.measure = m and c.locus->ExpenseRole in w.role)
    => amount[w, e, c]
    else 0
}

fun eventExpense[w: World, e: Event, m: Measure]: one Int {
  sum c: Cell | expenseContribution[w, e, c, m]
}

fun merchantContribution[w: World, e: Event, p: Party, m: Measure]: one Int {
  (p in e.(w.merchant)) => eventExpense[w, e, m] else 0
}

-- Signed Expense-role quantity associated with explicit merchant identity.
fun merchantExpense[w: World, p: Party, m: Measure]: one Int {
  sum e: w.present | merchantContribution[w, e, p, m]
}

fun selectedCounterpartyContribution[
    w: World, e: Event, p: Party, m: Measure
]: one Int {
  (p in e.(w.selectedCounterparty)) => eventExpense[w, e, m] else 0
}

fun selectedCounterpartyExpense[w: World, p: Party, m: Measure]: one Int {
  sum e: w.present | selectedCounterpartyContribution[w, e, p, m]
}

-- Exactness requires role evidence for every nonzero Effect in the queried
-- Measure of every Event selected for the merchant.
pred merchantQueryReady[w: World, p: Party, m: Measure] {
  all e: w.present |
    p in e.(w.merchant) implies
      all c: Cell |
        (c.measure = m and amount[w, e, c] != 0) implies
          one c.locus.(w.role)
}

pred samePhysicalCore[a, b: World] {
  a.present = b.present
  a.effect = b.effect
}

pred sameRoleEvidence[a, b: World] {
  a.role = b.role
}

pred sameMerchantEvidence[a, b: World] {
  a.merchant = b.merchant
}

pred sameSelectedCounterpartyEvidence[a, b: World] {
  a.selectedCounterparty = b.selectedCounterparty
}

pred splitExpenseOneMerchantNeedsNoStoredMerchantAmount {
  some e: Left.present, p: Party, disj expenseA, expenseB, payment: Cell | {
    p in e.(Left.merchant)
    expenseA.locus->ExpenseRole in Left.role
    expenseB.locus->ExpenseRole in Left.role
    payment.locus->AssetRole in Left.role

    amount[Left, e, expenseA] = 1
    amount[Left, e, expenseB] = 2
    amount[Left, e, payment] = -3
    all other: Cell - expenseA - expenseB - payment |
      amount[Left, e, other] = 0

    merchantQueryReady[Left, p, expenseA.measure]
    merchantExpense[Left, p, expenseA.measure] = 3
  }
}

pred counterpartyCanExistWithoutMerchant {
  some e: Left.present, p: Party, c: Cell | {
    p in e.(Left.selectedCounterparty)
    no e.(Left.merchant)
    c.locus->ExpenseRole in Left.role
    amount[Left, e, c] > 0
    selectedCounterpartyExpense[Left, p, c.measure] >
      merchantExpense[Left, p, c.measure]
  }
}

pred merchantCanMatchCounterpartyForSimplePurchase {
  some e: Left.present, p: Party, c: Cell | {
    e.(Left.merchant) = p
    e.(Left.selectedCounterparty) = p
    c.locus->ExpenseRole in Left.role
    amount[Left, e, c] > 0
  }
}

pred merchantEvidenceCanExistWithUnresolvedRole {
  some e: Left.present, p: Party, c: Cell | {
    p in e.(Left.merchant)
    amount[Left, e, c] != 0
    no c.locus.(Left.role)
    not merchantQueryReady[Left, p, c.measure]
  }
}

fun sellerContribution[
    w: World, e: Event, c: Cell, p: Party, m: Measure
]: one Int {
  (c.measure = m and
   c.locus->ExpenseRole in w.role and
   e->c->p in w.sellerAt)
    => amount[w, e, c]
    else 0
}

fun sellerExpenseAtEvent[
    w: World, e: Event, p: Party, m: Measure
]: one Int {
  sum c: Cell | sellerContribution[w, e, c, p, m]
}

fun eventMerchantExpense[
    w: World, e: Event, p: Party, m: Measure
]: one Int {
  merchantContribution[w, e, p, m]
}

pred multiMerchantEffectPressureEscapesEventLoneMerchant {
  some e: Left.present, m: Measure,
       disj sellerA, sellerB: Party,
       disj cellA, cellB: Cell | {
    cellA.measure = m
    cellB.measure = m
    cellA.locus->ExpenseRole in Left.role
    cellB.locus->ExpenseRole in Left.role
    amount[Left, e, cellA] > 0
    amount[Left, e, cellB] > 0
    e->cellA->sellerA in Left.sellerAt
    e->cellB->sellerB in Left.sellerAt

    eventMerchantExpense[Left, e, sellerA, m] !=
      sellerExpenseAtEvent[Left, e, sellerA, m]
    or
    eventMerchantExpense[Left, e, sellerB, m] !=
      sellerExpenseAtEvent[Left, e, sellerB, m]
  }
}

assert PhysicalRoleAndMerchantDetermineMerchantExpense {
  (samePhysicalCore[Left, Right] and
   sameRoleEvidence[Left, Right] and
   sameMerchantEvidence[Left, Right]) implies
    all p: Party, m: Measure |
      merchantExpense[Left, p, m] = merchantExpense[Right, p, m]
}

assert PhysicalAndMerchantDetermineMerchantExpense {
  (samePhysicalCore[Left, Right] and
   sameMerchantEvidence[Left, Right]) implies
    all p: Party, m: Measure |
      merchantExpense[Left, p, m] = merchantExpense[Right, p, m]
}

assert PhysicalAndRoleDetermineMerchantExpense {
  (samePhysicalCore[Left, Right] and
   sameRoleEvidence[Left, Right]) implies
    all p: Party, m: Measure |
      merchantExpense[Left, p, m] = merchantExpense[Right, p, m]
}

assert SelectedCounterpartyDeterminesMerchantExpense {
  (samePhysicalCore[Left, Right] and
   sameRoleEvidence[Left, Right] and
   sameSelectedCounterpartyEvidence[Left, Right]) implies
    all p: Party, m: Measure |
      merchantExpense[Left, p, m] = merchantExpense[Right, p, m]
}

assert MerchantEvidenceImpliesQueryReady {
  all w: World, p: Party, m: Measure |
    (some e: w.present | p in e.(w.merchant)) implies
      merchantQueryReady[w, p, m]
}

assert LoneEventMerchantCannotExactlyPartitionTwoSellers {
  all w: World, e: w.present, m: Measure,
      disj sellerA, sellerB: Party,
      disj cellA, cellB: Cell |
    (cellA.measure = m and
     cellB.measure = m and
     cellA.locus->ExpenseRole in w.role and
     cellB.locus->ExpenseRole in w.role and
     amount[w, e, cellA] > 0 and
     amount[w, e, cellB] > 0 and
     e->cellA->sellerA in w.sellerAt and
     e->cellB->sellerB in w.sellerAt)
    implies
      (eventMerchantExpense[w, e, sellerA, m] !=
         sellerExpenseAtEvent[w, e, sellerA, m] or
       eventMerchantExpense[w, e, sellerB, m] !=
         sellerExpenseAtEvent[w, e, sellerB, m])
}

-- Each command uses only the atoms needed by that probe. This keeps the
-- qualification cheap without weakening the local property under test.
run splitExpenseOneMerchantNeedsNoStoredMerchantAmount for exactly 1 Event, exactly 3 Locus, exactly 1 Measure, exactly 3 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
run counterpartyCanExistWithoutMerchant for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
run merchantCanMatchCounterpartyForSimplePurchase for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
run merchantEvidenceCanExistWithUnresolvedRole for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
run multiMerchantEffectPressureEscapesEventLoneMerchant for exactly 1 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int

check PhysicalRoleAndMerchantDetermineMerchantExpense for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
check PhysicalAndMerchantDetermineMerchantExpense for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
check PhysicalAndRoleDetermineMerchantExpense for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
check SelectedCounterpartyDeterminesMerchantExpense for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
check MerchantEvidenceImpliesQueryReady for exactly 1 Event, exactly 1 Locus, exactly 1 Measure, exactly 1 Cell, exactly 1 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
check LoneEventMerchantCannotExactlyPartitionTwoSellers for exactly 1 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 2 Party, exactly 2 AccountingRole, exactly 2 World, 4 Int
