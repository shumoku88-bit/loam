namespace Loam.Tui.Reports

set_option autoImplicit false

/-- Direct report entrances, distinct from report-internal comparison/detail modes. -/
inductive Destination where
  | incomeExpense
  | transactionsFlow
  | stockFlow
  | locusTrendCompare
  | balances
  | liquidity
  | budgetWindow
  | multimeasureSpend
  | favaProjection
  deriving Repr, DecidableEq

namespace Destination

def label : Destination → String
  | .incomeExpense => "Income & Expense"
  | .transactionsFlow => "Transactions Flow"
  | .stockFlow => "Stock–Flow"
  | .locusTrendCompare => "Trend / Locus comparison"
  | .balances => "Balances / Accounting"
  | .liquidity => "Liquidity"
  | .budgetWindow => "Budget Window"
  | .multimeasureSpend => "Multicurrency Spend"
  | .favaProjection => "Fava Projection (external)"

def all : List Destination :=
  [.incomeExpense, .transactionsFlow, .stockFlow, .locusTrendCompare,
   .balances, .liquidity, .budgetWindow, .multimeasureSpend, .favaProjection]

end Destination
end Loam.Tui.Reports
