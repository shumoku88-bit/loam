module experiments/observation_243_current_vs_historical_balance_support

open util/ordering[Moment]

sig Moment {}
sig Coordinate {}

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

abstract sig World {
  role: Coordinate -> one AccountingRole,

  -- Exact zero at the retained-history origin. This supports every later boundary.
  zeroOrigin: set Coordinate,

  -- A later/current balance anchor. It supports only that anchor and later boundaries.
  anchorAt: Coordinate -> lone Moment
}

one sig Left, Right extends World {}

fun roleOf[w: World, c: Coordinate]: one AccountingRole {
  c.(w.role)
}

pred supportedAt[w: World, c: Coordinate, t: Moment] {
  c in w.zeroOrigin or
  some a: c.(w.anchorAt) | lte[a, t]
}

fun supportedCoordinatesAt[w: World, t: Moment]: set Coordinate {
  { c: Coordinate | supportedAt[w, c, t] }
}

fun currentSupported[w: World]: set Coordinate {
  supportedCoordinatesAt[w, last]
}

fun balanceSheetRelevant[w: World]: set Coordinate {
  { c: Coordinate |
      roleOf[w, c] in AssetRole + LiabilityRole + EquityRole }
}

fun balanceSheetUnsupported[w: World]: set Coordinate {
  balanceSheetRelevant[w] - currentSupported[w]
}

fun stockFlowUnsupportedAt[w: World, t: Moment]: set Coordinate {
  Coordinate - supportedCoordinatesAt[w, t]
}

pred anchoredCurrentWithoutZeroOrigin {
  some c: Coordinate | {
    c not in Left.zeroOrigin
    some c.(Left.anchorAt)
    c in currentSupported[Left]
  }
}

pred sameCurrentSupportDifferentHistoricalSupport {
  Left.role = Right.role
  currentSupported[Left] = currentSupported[Right]
  supportedCoordinatesAt[Left, first] != supportedCoordinatesAt[Right, first]
}

pred completeBalanceSheetButIncompleteOriginHistory {
  no balanceSheetUnsupported[Left]
  some c: balanceSheetRelevant[Left] |
    c in stockFlowUnsupportedAt[Left, first]
}

assert ZeroOriginIsRequiredForEveryCurrentBalance {
  currentSupported[Left] in Left.zeroOrigin
}

assert CurrentSupportDeterminesHistoricalSupport {
  (Left.role = Right.role and
   currentSupported[Left] = currentSupported[Right]) implies
    all t: Moment |
      supportedCoordinatesAt[Left, t] = supportedCoordinatesAt[Right, t]
}

assert BalanceSheetCompletenessImpliesOriginCompleteness {
  no balanceSheetUnsupported[Left] implies
    no (balanceSheetRelevant[Left] & stockFlowUnsupportedAt[Left, first])
}

assert SeparateSupportEvidenceDeterminesAllSupportQuestions {
  (Left.role = Right.role and
   Left.zeroOrigin = Right.zeroOrigin and
   Left.anchorAt = Right.anchorAt) implies {
    currentSupported[Left] = currentSupported[Right]
    balanceSheetUnsupported[Left] = balanceSheetUnsupported[Right]
    all t: Moment |
      stockFlowUnsupportedAt[Left, t] = stockFlowUnsupportedAt[Right, t]
  }
}

run anchoredCurrentWithoutZeroOrigin for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
run sameCurrentSupportDifferentHistoricalSupport for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
run completeBalanceSheetButIncompleteOriginHistory for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
check ZeroOriginIsRequiredForEveryCurrentBalance for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
check CurrentSupportDeterminesHistoricalSupport for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
check BalanceSheetCompletenessImpliesOriginCompleteness for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
check SeparateSupportEvidenceDeterminesAllSupportQuestions for exactly 2 World, exactly 1 Coordinate, exactly 3 Moment, exactly 5 AccountingRole
