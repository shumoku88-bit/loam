import Loam.RoleBalanceAnswerability

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def coordinate (locus : String) : EffectCoordinate :=
  ⟨⟨locus⟩, ⟨"jpy"⟩⟩

def main : IO Unit := do
  let asset : Loam.RoleBalanceReview.Row := {
    coordinate := coordinate "cash"
    role := .asset
    quantity := Quantity.ofQuanta 100
  }
  let unresolved : Loam.RoleBalanceReview.UnresolvedRole := {
    coordinate := coordinate "mystery"
    quantity := Quantity.ofQuanta 5
  }
  let presentLiability : Loam.RoleBalanceReview.KnownPresentBalance := {
    coordinate := coordinate "debt"
    role := some .liability
  }
  let unsupportedExpense : Loam.RoleBalanceReview.UnsupportedBalance := {
    coordinate := coordinate "food"
    role := some .expense
  }
  let unsupportedAsset : Loam.RoleBalanceReview.UnsupportedBalance := {
    coordinate := coordinate "bank"
    role := some .asset
  }

  let snapshot : Loam.RoleBalanceReview.Snapshot := {
    rows := [asset]
    unresolvedRoles := [unresolved]
    knownPresentBalances := [presentLiability]
    unsupportedBalances := [unsupportedExpense, unsupportedAsset]
  }

  let summary := Loam.RoleBalanceAnswerability.summarize snapshot

  expect (summary.totalCoordinates == 5) "total coordinate count changed"
  expect (summary.exactCurrentQuantitySupport == 2)
    "exact current quantity support count changed"
  expect (summary.accountingRoleCoverage == 4)
    "AccountingRole coverage count changed"
  expect (!summary.balanceSheetAnswerable)
    "Balance Sheet became answerable despite blockers"
  expect (!summary.netWorthAnswerable)
    "Net Worth became answerable despite blockers"
  expect (summary.balanceSheetAmountUnknown.length == 1)
    "Balance Sheet amount-unknown blocker disappeared"
  expect (summary.balanceSheetUnsupported.length == 1)
    "Balance Sheet unsupported blocker disappeared"
  expect (summary.netWorthAmountUnknown.length == 1)
    "Net Worth amount-unknown blocker disappeared"
  expect (summary.netWorthUnsupported.length == 1)
    "Net Worth unsupported blocker disappeared"
  expect (summary.roleBlockers.length == 1)
    "unresolved AccountingRole blocker disappeared"
  expect (summary.flowRoleQuantityGaps.length == 1)
    "flow-role quantity gap disappeared"
  expect
    (summary.flowRoleQuantityGaps.head?.map (fun row => row.coordinate.locus.token) ==
      some "food")
    "flow gap classification changed"

  let clean : Loam.RoleBalanceReview.Snapshot := {
    rows := [asset]
    unresolvedRoles := []
    knownPresentBalances := []
    unsupportedBalances := [unsupportedExpense]
  }
  let cleanSummary := Loam.RoleBalanceAnswerability.summarize clean
  expect cleanSummary.balanceSheetAnswerable
    "flow-only quantity gap blocked Balance Sheet"
  expect cleanSummary.netWorthAnswerable
    "flow-only quantity gap blocked Net Worth"

  IO.println
    "RoleBalance answerability: shared stock blockers and nonblocking flow gaps qualified."
