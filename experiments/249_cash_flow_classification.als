module experiments/observation_249_cash_flow_classification

abstract sig AccountingRole {}
one sig AssetRole, LiabilityRole, EquityRole, IncomeRole, ExpenseRole extends AccountingRole {}

abstract sig CashFlowClass {}
one sig Operating, Investing, Financing extends CashFlowClass {}

/*
Two exact incidence quantities are enough for this distinguishability probe.
Their arithmetic is deliberately outside the model: both worlds receive the same
cash-outflow / counterpart-inflow shape, so quantity arithmetic cannot explain a
difference in cash-flow classification.
*/
abstract sig SignedQuantity {}
one sig CashOut, CounterpartIn extends SignedQuantity {}

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
  cashQuantity: one SignedQuantity,
  counterpartQuantity: one SignedQuantity,
  explicitCashFlowClass: lone CashFlowClass
}

one sig Left, Right extends World {}

fact SameCashOutflowShape {
  all w: World | {
    w.cashQuantity = CashOut
    w.counterpartQuantity = CounterpartIn
  }
}

fun counterpartRole[w: World]: one AccountingRole {
  w.kind.accountingRole
}

fun requiredCashFlowClass[w: World]: one CashFlowClass {
  w.kind.cashFlowClass
}

pred sameCurrentLoamEvidence[a, b: World] {
  a.cashQuantity = b.cashQuantity
  a.counterpartQuantity = b.counterpartQuantity
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

run sameAssetRoleEvidenceDifferentCashFlowClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 2 SignedQuantity, exactly 4 EconomicKind
run sameLiabilityRoleEvidenceDifferentCashFlowClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 2 SignedQuantity, exactly 4 EconomicKind
check CurrentLoamEvidenceDeterminesCashFlowClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 2 SignedQuantity, exactly 4 EconomicKind
check ExplicitCashFlowClassificationDeterminesReportClass for exactly 2 World, exactly 5 AccountingRole, exactly 3 CashFlowClass, exactly 2 SignedQuantity, exactly 4 EconomicKind
