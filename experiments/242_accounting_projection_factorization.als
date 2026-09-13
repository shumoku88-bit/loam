module experiments/observation_242_accounting_projection_factorization

sig Locus {}
sig Measure {}

sig Coordinate {
  locus: one Locus,
  measure: one Measure
}

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

abstract sig World {
  role: Locus -> one AccountingRole,
  flow: Coordinate -> one Int,
  balance: Coordinate -> one Int,
  balanceSupported: set Coordinate
}

one sig Left, Right extends World {}

fact CoordinateProduct {
  all l: Locus, m: Measure |
    one c: Coordinate | c.locus = l and c.measure = m

  all disj a, b: Coordinate |
    a.locus != b.locus or a.measure != b.measure
}

fact SmallQuantities {
  all w: World, c: Coordinate | {
    let f = flowAt[w, c] |
      f >= -6 and f <= 6
    let b = balanceAt[w, c] |
      b >= -6 and b <= 6
  }
}

fun flowAt[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.flow }
}

fun balanceAt[w: World, c: Coordinate]: one Int {
  sum { i: Int | c->i in w.balance }
}

fun roleOf[w: World, c: Coordinate]: one AccountingRole {
  c.locus.(w.role)
}

fun roleFlowRows[w: World]: Coordinate -> AccountingRole -> Int {
  { c: Coordinate, r: AccountingRole, i: Int |
      r = roleOf[w, c] and i = flowAt[w, c] }
}

fun roleBalanceRows[w: World]: Coordinate -> AccountingRole -> Int {
  { c: Coordinate, r: AccountingRole, i: Int |
      c in w.balanceSupported and
      r = roleOf[w, c] and
      i = balanceAt[w, c] }
}

fun roleFlowTotal[w: World, r: AccountingRole, m: Measure]: one Int {
  sum c: Coordinate |
    (c.measure = m and roleOf[w, c] = r) => flowAt[w, c] else 0
}

fun roleBalanceTotal[w: World, r: AccountingRole, m: Measure]: one Int {
  sum c: Coordinate |
    (c in w.balanceSupported and c.measure = m and roleOf[w, c] = r) =>
      balanceAt[w, c]
    else 0
}

fun profitAndLossRows[w: World]: Coordinate -> AccountingRole -> Int {
  { c: Coordinate, r: AccountingRole, i: Int |
      c->r->i in roleFlowRows[w] and
      r in IncomeRole + ExpenseRole }
}

fun balanceSheetRows[w: World]: Coordinate -> AccountingRole -> Int {
  { c: Coordinate, r: AccountingRole, i: Int |
      c->r->i in roleBalanceRows[w] and
      r in AssetRole + LiabilityRole + EquityRole }
}

fun trialBalanceRows[w: World]: Coordinate -> AccountingRole -> Int {
  roleBalanceRows[w]
}

fun balanceSheetUnsupported[w: World]: set Coordinate {
  { c: Coordinate |
      roleOf[w, c] in AssetRole + LiabilityRole + EquityRole and
      c not in w.balanceSupported }
}

fun trialBalanceUnsupported[w: World]: set Coordinate {
  Coordinate - w.balanceSupported
}

fun netWorthByMeasure[w: World]: Measure -> Int {
  { m: Measure, i: Int |
      i = (sum c: Coordinate |
        (c in w.balanceSupported and c.measure = m and
          roleOf[w, c] in AssetRole + LiabilityRole) =>
            balanceAt[w, c]
          else 0) }
}

fun netWorthUnsupported[w: World]: set Coordinate {
  { c: Coordinate |
      roleOf[w, c] in AssetRole + LiabilityRole and
      c not in w.balanceSupported }
}

pred sameRoleTotals[a, b: World] {
  a.role = b.role
  a.balanceSupported = b.balanceSupported
  all r: AccountingRole, m: Measure | {
    roleFlowTotal[a, r, m] = roleFlowTotal[b, r, m]
    roleBalanceTotal[a, r, m] = roleBalanceTotal[b, r, m]
  }
}

pred sameSelectedViews[a, b: World] {
  profitAndLossRows[a] = profitAndLossRows[b]
  balanceSheetRows[a] = balanceSheetRows[b]
  balanceSheetUnsupported[a] = balanceSheetUnsupported[b]
  trialBalanceRows[a] = trialBalanceRows[b]
  trialBalanceUnsupported[a] = trialBalanceUnsupported[b]
  netWorthByMeasure[a] = netWorthByMeasure[b]
  netWorthUnsupported[a] = netWorthUnsupported[b]
}

pred sameRoleTotalsDifferentTrialBalance {
  Left.role = Right.role
  Left.balanceSupported = Coordinate
  Right.balanceSupported = Coordinate
  Left.flow = Right.flow
  sameRoleTotals[Left, Right]
  trialBalanceRows[Left] != trialBalanceRows[Right]
}

pred sameFlowDifferentTrialBalance {
  Left.role = Right.role
  Left.flow = Right.flow
  Left.balanceSupported = Right.balanceSupported
  some Left.balanceSupported
  trialBalanceRows[Left] != trialBalanceRows[Right]
}

pred sameBalanceDifferentProfitAndLoss {
  Left.role = Right.role
  Left.balance = Right.balance
  Left.balanceSupported = Right.balanceSupported
  some l: Locus | l->IncomeRole in Left.role or l->ExpenseRole in Left.role
  profitAndLossRows[Left] != profitAndLossRows[Right]
}

pred sameNumericBalanceDifferentSupport {
  Left.role = Right.role
  Left.balance = Right.balance
  Left.flow = Right.flow
  Left.balanceSupported != Right.balanceSupported
  trialBalanceUnsupported[Left] != trialBalanceUnsupported[Right]
}

assert RoleTotalsDetermineSelectedViews {
  sameRoleTotals[Left, Right] implies sameSelectedViews[Left, Right]
}

assert FlowFamilyDeterminesTrialBalance {
  (Left.role = Right.role and
   Left.flow = Right.flow and
   Left.balanceSupported = Right.balanceSupported) implies
    trialBalanceRows[Left] = trialBalanceRows[Right]
}

assert BalanceFamilyDeterminesProfitAndLoss {
  (Left.role = Right.role and
   Left.balance = Right.balance and
   Left.balanceSupported = Right.balanceSupported) implies
    profitAndLossRows[Left] = profitAndLossRows[Right]
}

assert NumericBalanceDeterminesCompleteness {
  (Left.role = Right.role and Left.balance = Right.balance) implies {
    balanceSheetUnsupported[Left] = balanceSheetUnsupported[Right]
    trialBalanceUnsupported[Left] = trialBalanceUnsupported[Right]
    netWorthUnsupported[Left] = netWorthUnsupported[Right]
  }
}

assert CoordinateFlowDeterminesProfitAndLoss {
  (Left.role = Right.role and Left.flow = Right.flow) implies
    profitAndLossRows[Left] = profitAndLossRows[Right]
}

assert CoordinateBalancePlusSupportDeterminesBalanceViews {
  (Left.role = Right.role and
   Left.balance = Right.balance and
   Left.balanceSupported = Right.balanceSupported) implies {
    balanceSheetRows[Left] = balanceSheetRows[Right]
    balanceSheetUnsupported[Left] = balanceSheetUnsupported[Right]
    trialBalanceRows[Left] = trialBalanceRows[Right]
    trialBalanceUnsupported[Left] = trialBalanceUnsupported[Right]
    netWorthByMeasure[Left] = netWorthByMeasure[Right]
    netWorthUnsupported[Left] = netWorthUnsupported[Right]
  }
}

assert CoordinateFamiliesDetermineSelectedViews {
  (Left.role = Right.role and
   Left.flow = Right.flow and
   Left.balance = Right.balance and
   Left.balanceSupported = Right.balanceSupported) implies
    sameSelectedViews[Left, Right]
}

run sameRoleTotalsDifferentTrialBalance for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
run sameFlowDifferentTrialBalance for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
run sameBalanceDifferentProfitAndLoss for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
run sameNumericBalanceDifferentSupport for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check RoleTotalsDetermineSelectedViews for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check FlowFamilyDeterminesTrialBalance for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check BalanceFamilyDeterminesProfitAndLoss for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check NumericBalanceDeterminesCompleteness for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check CoordinateFlowDeterminesProfitAndLoss for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check CoordinateBalancePlusSupportDeterminesBalanceViews for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
check CoordinateFamiliesDetermineSelectedViews for exactly 2 World, exactly 2 Locus, exactly 1 Measure, exactly 2 Coordinate, exactly 5 AccountingRole, 5 Int
