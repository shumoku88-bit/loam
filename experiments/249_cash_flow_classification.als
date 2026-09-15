module experiments/observation_249_cash_flow_classification

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

abstract sig CashFlowClass {}
one sig Operating, Investing, Financing extends CashFlowClass {}

abstract sig EconomicKind {
  accountingRole: one AccountingRole,
  cashFlowClass: one CashFlowClass
}

one sig InventoryPurchase, EquipmentPurchase,
        TradePayableSettlement, BorrowingRepayment extends EconomicKind {}

fact QualifiedExamples {
  InventoryPurchase.accountingRole = AssetRole
  EquipmentPurchase.accountingRole = AssetRole
  TradePayableSettlement.accountingRole = LiabilityRole
  BorrowingRepayment.accountingRole = LiabilityRole

  InventoryPurchase.cashFlowClass = Operating
  EquipmentPurchase.cashFlowClass = Investing
  TradePayableSettlement.cashFlowClass = Operating
  BorrowingRepayment.cashFlowClass = Financing
}

abstract sig World {
  kind: one EconomicKind,
  cashDelta: one Int,
  counterpartDelta: one Int,
  explicitCashFlowClass: lone CashFlowClass
}

one sig Left, Right extends World {}

fact BalancedCashOutflow {
  all w: World | {
    w.cashDelta < 0
    w.counterpartDelta > 0
    w.cashDelta = 0 - w.counterpartDelta
    w.cashDelta >= -6
    w.counterpartDelta <= 6
  }
}

fun counterpartRole[w: World]: one AccountingRole {
  w.kind.accountingRole
}

fun requiredCashFlowClass[w: World]: one CashFlowClass {
  w.kind.cashFlowClass
}

pred sameCurrentLoamEvidence[a, b: World] {
  a.cashDelta = b.cashDelta
  a.counterpartDelta = b.counterpartDelta
  counterpartRole[a] = counterpartRole[b]
}

pred sameAssetRoleEvidenceDifferentCashFlowClass {
  Left.kind = InventoryPurchase
  Right.kind = EquipmentPurchase
  sameCurrentLoamEvidence[Left, Right]
  requiredCashFlowClass[Left] != requiredCashFlowClass[Right]
}

pred sameLiabilityRoleEvidenceDifferentCashFlowClass {
  Left.kind = TradePayableSettlement
  Right.kind = BorrowingRepayment
  sameCurrentLoamEvidence[Left, Right]
  requiredCashFlowClass[Left] != requiredCashFlowClass[Right]
}

assert CurrentLoamEvidenceDeterminesCashFlowClass {
  sameCurrentLoamEvidence[Left, Right] implies
    requiredCashFlowClass[Left] = requiredCashFlowClass[Right]
}

assert ExplicitCashFlowClassificationDeterminesReportClass {
  (sameCurrentLoamEvidence[Left, Right] and
   one Left.explicitCashFlowClass and
   Left.explicitCashFlowClass = Right.explicitCashFlowClass and
   Left.explicitCashFlowClass = requiredCashFlowClass[Left] and
   Right.explicitCashFlowClass = requiredCashFlowClass[Right]) implies
    requiredCashFlowClass[Left] = requiredCashFlowClass[Right]
}

run sameAssetRoleEvidenceDifferentCashFlowClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 4 EconomicKind, 5 Int
run sameLiabilityRoleEvidenceDifferentCashFlowClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 4 EconomicKind, 5 Int
check CurrentLoamEvidenceDeterminesCashFlowClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 4 EconomicKind, 5 Int
check ExplicitCashFlowClassificationDeterminesReportClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 4 EconomicKind, 5 Int
