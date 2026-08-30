module model/observation_049_accounting_role_overlay

sig Locus {}
sig Measure {}
sig Event {}

sig Cell {
  locus: one Locus,
  measure: one Measure
}

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

abstract sig World {
  present: set Event,
  effect: Event -> Cell -> lone Int,
  parent: Event -> set Event,
  role: Locus -> one AccountingRole
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
    w.parent in w.present -> w.present
    no iden & ^(w.parent)

    all e: w.present | {
      some e.(w.effect) or some e.(w.parent)
      all c: Cell |
        let n = amount[w, e, c] |
          n >= -3 and n <= 3
    }
  }
}

fun amount[w: World, e: Event, c: Cell]: one Int {
  sum { i: Int | e->c->i in w.effect }
}

fun superseded[w: World]: set Event {
  w.present.(w.parent)
}

fun tips[w: World]: set Event {
  w.present - superseded[w]
}

fun balanceAt[w: World, c: Cell]: one Int {
  sum e: tips[w] | amount[w, e, c]
}

fun coordinateBalances[w: World]: Cell -> Int {
  { c: Cell, i: Int | i = balanceAt[w, c] }
}

fun measureContribution[w: World, c: Cell, m: Measure]: one Int {
  (c.measure = m) => balanceAt[w, c] else 0
}

fun totalByMeasure[w: World]: Measure -> Int {
  { m: Measure, i: Int |
      i = (sum c: Cell | measureContribution[w, c, m]) }
}

fun lociInRoles[w: World, rs: set AccountingRole]: set Locus {
  { l: Locus | some (l.(w.role) & rs) }
}

fun balancesInRoles[w: World, rs: set AccountingRole]: Cell -> Int {
  { c: Cell, i: Int |
      c.locus in lociInRoles[w, rs] and
      i = balanceAt[w, c] }
}

fun balanceSheetLoci[w: World]: set Locus {
  lociInRoles[w, AssetRole + LiabilityRole + EquityRole]
}

fun profitAndLossLoci[w: World]: set Locus {
  lociInRoles[w, IncomeRole + ExpenseRole]
}

fun balanceSheetBalances[w: World]: Cell -> Int {
  balancesInRoles[w, AssetRole + LiabilityRole + EquityRole]
}

fun profitAndLossBalances[w: World]: Cell -> Int {
  balancesInRoles[w, IncomeRole + ExpenseRole]
}

fun assetBalances[w: World]: Cell -> Int {
  balancesInRoles[w, AssetRole]
}

fun liabilityBalances[w: World]: Cell -> Int {
  balancesInRoles[w, LiabilityRole]
}

fun equityBalances[w: World]: Cell -> Int {
  balancesInRoles[w, EquityRole]
}

fun incomeBalances[w: World]: Cell -> Int {
  balancesInRoles[w, IncomeRole]
}

fun expenseBalances[w: World]: Cell -> Int {
  balancesInRoles[w, ExpenseRole]
}

pred samePhysicalCore[a, b: World] {
  a.present = b.present
  a.effect = b.effect
  a.parent = b.parent
}

pred samePhysicalAnswers[a, b: World] {
  coordinateBalances[a] = coordinateBalances[b]
  totalByMeasure[a] = totalByMeasure[b]
}

pred sameAccountingAnswers[a, b: World] {
  balanceSheetLoci[a] = balanceSheetLoci[b]
  profitAndLossLoci[a] = profitAndLossLoci[b]
  balanceSheetBalances[a] = balanceSheetBalances[b]
  profitAndLossBalances[a] = profitAndLossBalances[b]
  assetBalances[a] = assetBalances[b]
  liabilityBalances[a] = liabilityBalances[b]
  equityBalances[a] = equityBalances[b]
  incomeBalances[a] = incomeBalances[b]
  expenseBalances[a] = expenseBalances[b]
}

pred accountingRoleOverlayCanChangeStatementPlacement {
  #Left.present = 2
  samePhysicalCore[Left, Right]
  samePhysicalAnswers[Left, Right]
  all c: Cell | balanceAt[Left, c] > 0

  some disj a, b: Locus | {
    a->AssetRole in Left.role
    a->IncomeRole in Right.role
    b->IncomeRole in Left.role
    b->AssetRole in Right.role
  }

  balanceSheetBalances[Left] != balanceSheetBalances[Right]
  profitAndLossBalances[Left] != profitAndLossBalances[Right]
}

pred accountingRoleOverlayCanChangeWithinStatements {
  #Left.present = 2
  samePhysicalCore[Left, Right]
  samePhysicalAnswers[Left, Right]
  all c: Cell | balanceAt[Left, c] > 0

  some disj a, b: Locus | {
    a->AssetRole in Left.role
    a->LiabilityRole in Right.role
    b->IncomeRole in Left.role
    b->ExpenseRole in Right.role
  }

  balanceSheetLoci[Left] = balanceSheetLoci[Right]
  profitAndLossLoci[Left] = profitAndLossLoci[Right]
  assetBalances[Left] != assetBalances[Right]
  liabilityBalances[Left] != liabilityBalances[Right]
  incomeBalances[Left] != incomeBalances[Right]
  expenseBalances[Left] != expenseBalances[Right]
}

assert PhysicalCoreDeterminesPhysicalAnswers {
  samePhysicalCore[Left, Right] implies
    samePhysicalAnswers[Left, Right]
}

assert PhysicalCoreDeterminesAccountingVocabulary {
  samePhysicalCore[Left, Right] implies
    sameAccountingAnswers[Left, Right]
}

assert PhysicalCorePlusAccountingRoleDeterminesSelectedVocabulary {
  (samePhysicalCore[Left, Right] and Left.role = Right.role) implies {
    samePhysicalAnswers[Left, Right]
    sameAccountingAnswers[Left, Right]
  }
}

run accountingRoleOverlayCanChangeStatementPlacement for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 5 AccountingRole, exactly 2 World, 5 Int
run accountingRoleOverlayCanChangeWithinStatements for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 5 AccountingRole, exactly 2 World, 5 Int
check PhysicalCoreDeterminesPhysicalAnswers for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 5 AccountingRole, exactly 2 World, 5 Int
check PhysicalCoreDeterminesAccountingVocabulary for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 5 AccountingRole, exactly 2 World, 5 Int
check PhysicalCorePlusAccountingRoleDeterminesSelectedVocabulary for exactly 2 Event, exactly 2 Locus, exactly 1 Measure, exactly 2 Cell, exactly 5 AccountingRole, exactly 2 World, 5 Int
