module experiments/observation_062_real_ledger_account_pressure

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

sig AccountName {}
sig EventKind {}

sig Event {}
sig Locus {}

sig Effect {
  event: one Event,
  locus: one Locus,
  quantity: one Int
}

sig World {
  role: Locus -> one AccountingRole,
  accountName: Locus -> one AccountName,
  eventKind: Event -> one EventKind
}

one sig Left, Right extends World {}

fun effectsOf[e: Event]: set Effect {
  e.~event
}

fun effectsWithRole[w: World, e: Event, r: AccountingRole]: set Effect {
  { x: effectsOf[e] | x.locus.(w.role) = r }
}

fun eventTotal[e: Event]: Int {
  sum x: effectsOf[e] | x.quantity
}

fact SparseNonzeroEffects {
  all x: Effect | x.quantity != 0
  all e: Event, l: Locus |
    lone { x: Effect | x.event = e and x.locus = l }
  all e: Event | some effectsOf[e]
}

pred assetTransfer[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  all x: effectsOf[e] | x.locus.(w.role) = AssetRole
  one x: effectsOf[e] | x.quantity < 0
  one x: effectsOf[e] | x.quantity > 0
}

pred expense[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  #effectsWithRole[w, e, AssetRole] = 1
  #effectsWithRole[w, e, ExpenseRole] = 1
  one x: effectsWithRole[w, e, AssetRole] | x.quantity < 0
  one x: effectsWithRole[w, e, ExpenseRole] | x.quantity > 0
}

pred splitExpense[w: World, e: Event] {
  #effectsOf[e] = 3
  eventTotal[e] = 0
  #effectsWithRole[w, e, AssetRole] = 1
  #effectsWithRole[w, e, ExpenseRole] = 2
  one x: effectsWithRole[w, e, AssetRole] | x.quantity < 0
  all x: effectsWithRole[w, e, ExpenseRole] | x.quantity > 0
}

pred income[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  #effectsWithRole[w, e, AssetRole] = 1
  #effectsWithRole[w, e, IncomeRole] = 1
  one x: effectsWithRole[w, e, AssetRole] | x.quantity > 0
  one x: effectsWithRole[w, e, IncomeRole] | x.quantity < 0
}

pred liabilityFundedExpense[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  #effectsWithRole[w, e, ExpenseRole] = 1
  #effectsWithRole[w, e, LiabilityRole] = 1
  one x: effectsWithRole[w, e, ExpenseRole] | x.quantity > 0
  one x: effectsWithRole[w, e, LiabilityRole] | x.quantity < 0
}

pred liabilityRepayment[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  #effectsWithRole[w, e, AssetRole] = 1
  #effectsWithRole[w, e, LiabilityRole] = 1
  one x: effectsWithRole[w, e, AssetRole] | x.quantity < 0
  one x: effectsWithRole[w, e, LiabilityRole] | x.quantity > 0
}

pred expenseRefund[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  #effectsWithRole[w, e, AssetRole] = 1
  #effectsWithRole[w, e, ExpenseRole] = 1
  one x: effectsWithRole[w, e, AssetRole] | x.quantity > 0
  one x: effectsWithRole[w, e, ExpenseRole] | x.quantity < 0
}

pred openingBalance[w: World, e: Event] {
  #effectsOf[e] = 2
  eventTotal[e] = 0
  #effectsWithRole[w, e, AssetRole] = 1
  #effectsWithRole[w, e, EquityRole] = 1
  one x: effectsWithRole[w, e, AssetRole] | x.quantity > 0
  one x: effectsWithRole[w, e, EquityRole] | x.quantity < 0
}

fun assetTransfers[w: World]: set Event {
  { e: Event | assetTransfer[w, e] }
}

fun expenses[w: World]: set Event {
  { e: Event | expense[w, e] }
}

fun splitExpenses[w: World]: set Event {
  { e: Event | splitExpense[w, e] }
}

fun incomes[w: World]: set Event {
  { e: Event | income[w, e] }
}

fun liabilityFundedExpenses[w: World]: set Event {
  { e: Event | liabilityFundedExpense[w, e] }
}

fun liabilityRepayments[w: World]: set Event {
  { e: Event | liabilityRepayment[w, e] }
}

fun expenseRefunds[w: World]: set Event {
  { e: Event | expenseRefund[w, e] }
}

fun openingBalances[w: World]: set Event {
  { e: Event | openingBalance[w, e] }
}

pred representativeLedgerShapes[w: World] {
  some disj transferEvent, expenseEvent, splitEvent, incomeEvent,
      liabilityExpenseEvent, repaymentEvent, refundEvent, openingEvent: Event | {
    assetTransfer[w, transferEvent]
    expense[w, expenseEvent]
    splitExpense[w, splitEvent]
    income[w, incomeEvent]
    liabilityFundedExpense[w, liabilityExpenseEvent]
    liabilityRepayment[w, repaymentEvent]
    expenseRefund[w, refundEvent]
    openingBalance[w, openingEvent]
  }
}

pred sameSemanticCoreDifferentNominals {
  representativeLedgerShapes[Left]
  Left.role = Right.role
  Left.accountName != Right.accountName
  Left.eventKind != Right.eventKind
}

pred roleOverlayCanChangeRecognizedShape {
  representativeLedgerShapes[Left]
  Left.accountName = Right.accountName
  Left.eventKind = Right.eventKind
  some e: Event | expense[Left, e] and assetTransfer[Right, e]
}

assert EffectCoreAloneDeterminesSelectedShapes {
  assetTransfers[Left] = assetTransfers[Right]
  expenses[Left] = expenses[Right]
  splitExpenses[Left] = splitExpenses[Right]
  incomes[Left] = incomes[Right]
  liabilityFundedExpenses[Left] = liabilityFundedExpenses[Right]
  liabilityRepayments[Left] = liabilityRepayments[Right]
  expenseRefunds[Left] = expenseRefunds[Right]
  openingBalances[Left] = openingBalances[Right]
}

assert EffectCorePlusRoleDeterminesSelectedShapes {
  Left.role = Right.role implies {
    assetTransfers[Left] = assetTransfers[Right]
    expenses[Left] = expenses[Right]
    splitExpenses[Left] = splitExpenses[Right]
    incomes[Left] = incomes[Right]
    liabilityFundedExpenses[Left] = liabilityFundedExpenses[Right]
    liabilityRepayments[Left] = liabilityRepayments[Right]
    expenseRefunds[Left] = expenseRefunds[Right]
    openingBalances[Left] = openingBalances[Right]
  }
}

assert NominalPresentationCannotChangeSelectedShapes {
  (Left.role = Right.role and
      Left.accountName != Right.accountName and
      Left.eventKind != Right.eventKind) implies {
    assetTransfers[Left] = assetTransfers[Right]
    expenses[Left] = expenses[Right]
    splitExpenses[Left] = splitExpenses[Right]
    incomes[Left] = incomes[Right]
    liabilityFundedExpenses[Left] = liabilityFundedExpenses[Right]
    liabilityRepayments[Left] = liabilityRepayments[Right]
    expenseRefunds[Left] = expenseRefunds[Right]
    openingBalances[Left] = openingBalances[Right]
  }
}

run representativeLedgerShapes for exactly 8 Event, exactly 7 Locus, exactly 17 Effect, exactly 2 AccountName, exactly 2 EventKind, exactly 2 World, 5 Int
run sameSemanticCoreDifferentNominals for exactly 8 Event, exactly 7 Locus, exactly 17 Effect, exactly 2 AccountName, exactly 2 EventKind, exactly 2 World, 5 Int
run roleOverlayCanChangeRecognizedShape for exactly 8 Event, exactly 7 Locus, exactly 17 Effect, exactly 2 AccountName, exactly 2 EventKind, exactly 2 World, 5 Int
check EffectCoreAloneDeterminesSelectedShapes for exactly 8 Event, exactly 7 Locus, exactly 17 Effect, exactly 2 AccountName, exactly 2 EventKind, exactly 2 World, 5 Int
check EffectCorePlusRoleDeterminesSelectedShapes for exactly 8 Event, exactly 7 Locus, exactly 17 Effect, exactly 2 AccountName, exactly 2 EventKind, exactly 2 World, 5 Int
check NominalPresentationCannotChangeSelectedShapes for exactly 8 Event, exactly 7 Locus, exactly 17 Effect, exactly 2 AccountName, exactly 2 EventKind, exactly 2 World, 5 Int
