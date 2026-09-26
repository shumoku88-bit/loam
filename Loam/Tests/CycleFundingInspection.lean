import Loam.CycleFundingInspection

open Loam.Core
open Loam.CycleFundingInspection

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) : IO α :=
  match value with
  | .ok result => pure result
  | .error message => throw (IO.userError message)

private def yen : MeasureId := ⟨"jpy"⟩
private def wallet : EffectCoordinate := ⟨⟨"selected-wallet"⟩, yen⟩
private def overdraft : EffectCoordinate := ⟨⟨"selected-overdraft"⟩, yen⟩
private def knownZero : EffectCoordinate := ⟨⟨"known-zero"⟩, yen⟩

private def balanceRow (coordinate : EffectCoordinate) (quanta : Int) : Loam.BalanceReview.Row :=
  { coordinate := coordinate, quantity := Quantity.ofQuanta quanta }

private def balances (rows : List Loam.BalanceReview.Row) : Loam.BalanceReview.Snapshot :=
  { rows := rows }

private def row (purpose : String) (remaining : Int) (commitment : Int := 0) :
    Loam.CurrentCoverageReview.Row :=
  { purpose := ⟨purpose⟩
    entitlement := Quantity.ofQuanta (remaining + 6000)
    consumption := Quantity.ofQuanta 6000
    commitment := Quantity.ofQuanta commitment }

private def current (rows : List Loam.CurrentCoverageReview.Row) :
    Loam.CurrentCoverageReview.Snapshot :=
  { currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows := rows
    scheduledFrontier := some {
      unmanaged := Quantity.ofQuanta 3
      unrouted := Quantity.ofQuanta 5
      unresolvedEligibility := Quantity.ofQuanta 4810 } }

private def assertAmounts (label : String) (summary : Summary)
    (backing assigned residual : Int) : IO Unit := do
  expect (summary.measure == yen) s!"{label}: measure"
  expect (summary.budgetableBacking.quanta == backing) s!"{label}: signed backing"
  expect (summary.remainingAssigned.quanta == assigned) s!"{label}: remaining assigned"
  expect (summary.residualBeforeUnresolved.quanta == residual) s!"{label}: residual"

def main : IO Unit := do
  let walletBalances := balances [balanceRow wallet 100]
  let inspect := fun selection exact snapshot =>
    project exact selection yen snapshot
  let inspectRows := fun rows => requireOk (inspect [wallet] walletBalances (current rows))

  let basic ← inspectRows [row "food" 70]
  assertAmounts "A/I basic and separate frontier" basic 100 70 30

  assertAmounts "B negative remaining" (← inspectRows [row "food" 70, row "general" (-20)])
    100 70 30

  let before ← inspectRows [row "general" (-20)]
  let filled ← inspectRows [row "general" 0]
  let future ← inspectRows [row "general" 20]
  assertAmounts "C before fill" before 100 0 100
  assertAmounts "C retroactive fill" filled 100 0 100
  assertAmounts "D future allocation" future 100 20 80
  expect (before.remainingAssigned == filled.remainingAssigned) "retroactive fill increased assignment"
  expect (filled.residualBeforeUnresolved.quanta - future.residualBeforeUnresolved.quanta == 20)
    "future allocation did not reduce residual by 20"

  assertAmounts "E remaining not headroom" (← inspectRows [row "fixed" 100 30]) 100 100 0

  expect (!(inspect [wallet, wallet]
      (balances [balanceRow wallet 100, balanceRow wallet 100]) (current [])).isOk)
    "duplicate funding selection accepted"

  expect (!(inspect [wallet] (balances []) (current [])).isOk)
    "missing exact current balance accepted"
  assertAmounts "evidenced zero"
    (← requireOk (inspect [knownZero] (balances [balanceRow knownZero 0]) (current [])))
    0 0 0

  let usd : MeasureId := ⟨"usd"⟩
  let dollars : EffectCoordinate := ⟨wallet.locus, usd⟩
  expect (!(project
      (balances [balanceRow wallet 100, balanceRow dollars 100])
      [wallet, dollars] yen (current [])).isOk)
    "mixed-measure selection accepted"
  expect (!(project (balances [balanceRow dollars 100]) [dollars] usd (current [])).isOk)
    "JPY CurrentCoverage was coerced to another measure"

  let rows := [row "food" 70, row "general" 0, row "fixed" 0]
  let multi ← inspectRows rows
  assertAmounts "J multiple Purposes" multi 100 70 30
  expect (multi == basic) "Purpose count changed independent funding quantities"
  expect ((← inspectRows rows.reverse) == multi) "row order changed funding"
  expect (!(inspect [wallet] walletBalances { current [] with scheduledFrontier := none }).isOk)
    "missing Scheduled frontier became zero"
  expect (!(inspect [wallet] walletBalances (current [row "food" 70, row "food" 70])).isOk)
    "duplicate Purpose rows double counted assignment"

  let signedBalances := balances [balanceRow wallet 100, balanceRow overdraft (-40)]
  assertAmounts "signed selected balances"
    (← requireOk (inspect [wallet, overdraft] signedBalances (current []))) 60 0 60
  assertAmounts "negative backing"
    (← requireOk (inspect [overdraft] (balances [balanceRow overdraft (-40)]) (current [])))
    (-40) 0 (-40)
  assertAmounts "explicit empty selection"
    (← requireOk (inspect [] (balances []) (current [row "food" 70]))) 0 70 (-70)

  expect (!(inspect [wallet, overdraft]
      (balances [balanceRow overdraft (-40), balanceRow wallet 100]) (current [])).isOk)
    "funding accepted a balance answer with mismatched caller order"

  IO.println
    "Cycle Funding: current exact backing arithmetic, explicit selection and CurrentCoverage frontier passed."
