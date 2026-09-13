import Loam.RoleFlowReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def findRow?
    (snapshot : Loam.RoleFlowReview.Snapshot)
    (locus : String) : Option Loam.RoleFlowReview.Row :=
  snapshot.rows.find? fun row => row.coordinate.locus.token == locus

def main : IO Unit := do
  let receipt ← requireSome
    (Event.ofEffects? ⟨"receipt"⟩
      [effect "wallet-in" "wallet" 100, effect "income-out" "income" (-100)])
    "receipt event"
  let purchase ← requireSome
    (Event.ofEffects? ⟨"purchase"⟩
      [effect "wallet-out" "wallet" (-30), effect "food-in" "food" 25,
       effect "mystery-in" "mystery" 5])
    "purchase event"

  let records : List Loam.ActualReview.Record := [
    { event := receipt, date := some "2026-09-01", description := "receipt", replacement := none },
    { event := purchase, date := some "2026-09-02", description := "purchase", replacement := none }
  ]
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [
      { locus := ⟨"wallet"⟩, role := .asset },
      { locus := ⟨"income"⟩, role := .income },
      { locus := ⟨"food"⟩, role := .expense }
    ])
    "role map"

  let .ok flow := Loam.TransactionsFlowReview.project records "2026-09-01" "2026-09-03"
    | throw (IO.userError "transactions-flow fixture refused")
  let snapshot := Loam.RoleFlowReview.project flow roles

  expect (snapshot.start == flow.start && snapshot.endExclusive == flow.endExclusive)
    "role flow changed the shared date window"
  expect (snapshot.rows.length == 3) "classified coordinate rows changed unexpectedly"

  let wallet ← requireSome (findRow? snapshot "wallet") "wallet role row"
  let income ← requireSome (findRow? snapshot "income") "income role row"
  let food ← requireSome (findRow? snapshot "food") "food role row"

  expect (wallet.quantity.quanta == 70) "wallet quantity diverged from TransactionsFlow"
  expect (income.quantity.quanta == -100) "income quantity diverged from TransactionsFlow"
  expect (food.quantity.quanta == 25) "expense quantity diverged from TransactionsFlow"
  expect (decide (wallet.role = AccountingRole.asset)) "wallet role changed"
  expect (decide (income.role = AccountingRole.income)) "income role changed"
  expect (decide (food.role = AccountingRole.expense)) "food role changed"

  expect (snapshot.unresolvedEffects.length == 1)
    "unclassified Effect frontier was not preserved"
  let unresolved ← requireSome snapshot.unresolvedEffects.head? "missing unresolved Effect"
  expect (unresolved.event.token == "purchase") "unresolved Event witness changed"
  expect (unresolved.date == "2026-09-02") "unresolved date witness changed"
  expect (unresolved.effect.locus.token == "mystery") "unresolved Locus witness changed"
  expect (unresolved.effect.quantity.quanta == 5) "unresolved quantity witness changed"

  let walletCoordinate : EffectCoordinate := ⟨⟨"wallet"⟩, ⟨"jpy"⟩⟩
  expect
    (wallet.quantity.quanta ==
      (Loam.TransactionsFlowReview.rowTotal flow walletCoordinate).quanta)
    "RoleFlow introduced a second quantity calculation"

  IO.println
    "Role Flow Review: TransactionsFlow composition, explicit roles and unresolved Effect frontier passed."
