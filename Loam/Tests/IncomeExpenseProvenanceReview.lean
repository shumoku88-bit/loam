import Loam.Review.IncomeExpenseProvenanceReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def effect (key locus : String) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def rowQuantity
    (rows : List Loam.RoleFlowReview.Row)
    (locus : String) : Int :=
  match rows.find? fun row => row.coordinate.locus.token == locus with
  | some row => row.quantity.quanta
  | none => 0

def main : IO Unit := do
  let plannedRoot ← requireSome
    (Event.ofEffects? ⟨"planned-root"⟩
      [effect "wallet-old" "wallet" (-100), effect "rent-old" "rent" 100])
    "planned root Event"
  let plannedCorrected ← requireSome
    (Event.ofEffects? ⟨"planned-corrected"⟩
      [effect "wallet-new" "wallet" (-120), effect "rent-new" "rent" 120])
    "planned corrected Event"
  let coffee ← requireSome
    (Event.ofEffects? ⟨"coffee"⟩
      [effect "wallet-coffee" "wallet" (-30), effect "coffee-expense" "coffee" 30])
    "coffee Event"

  let records : List Loam.ActualReview.Record := [
    {
      event := plannedRoot
      date := some "2026-09-01"
      description := "planned original"
      replacement := some plannedCorrected.id
    },
    {
      event := plannedCorrected
      date := some "2026-09-01"
      description := "planned corrected"
      replacement := none
    },
    {
      event := coffee
      date := some "2026-09-02"
      description := "coffee"
      replacement := none
    }
  ]

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [
      { locus := ⟨"wallet"⟩, role := .asset },
      { locus := ⟨"rent"⟩, role := .expense },
      { locus := ⟨"coffee"⟩, role := .expense }
    ])
    "role map"

  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [{
      source := ⟨"scheduled-rent"⟩
      target := some (.actual plannedRoot.id)
    }])
    "Scheduled terminal memory"

  let evidence : Loam.IncomeExpenseProvenanceReview.Evidence := {
    records := records
    roles := roles
    rootedCurrent := [
      (plannedRoot.id, plannedCorrected),
      (coffee.id, coffee)
    ]
    scheduledTerminals := .ok terminals
  }

  let .ok snapshot :=
      Loam.IncomeExpenseProvenanceReview.project
        evidence "2026-09-01" "2026-10-01"
    | throw (IO.userError "provenance fixture refused")

  let rentTotal :=
    snapshot.roleFlow.rows.find? fun row =>
      row.coordinate.locus.token == "rent"
  let rent ← requireSome rentTotal "rent RoleFlow row"
  expect (rent.quantity.quanta == 120)
    "corrected rent did not remain the current RoleFlow quantity"

  match snapshot.expenseProvenance with
  | .unknown _ =>
      throw (IO.userError "qualified Scheduled provenance became UNKNOWN")
  | .available partition =>
      expect (rowQuantity partition.scheduledLinked "rent" == 120)
        "corrected Scheduled completion lost its stable-root provenance"
      expect (rowQuantity partition.noScheduledLink "rent" == 0)
        "corrected Scheduled-linked rent leaked into No Scheduled link"
      expect (rowQuantity partition.scheduledLinked "coffee" == 0)
        "unlinked coffee was incorrectly classified as Scheduled-linked"
      expect (rowQuantity partition.noScheduledLink "coffee" == 30)
        "unlinked coffee did not remain in No Scheduled link"
      for row in snapshot.roleFlow.rows.filter fun row =>
          decide (row.role = AccountingRole.expense) do
        let linked := rowQuantity partition.scheduledLinked row.coordinate.locus.token
        let unlinked := rowQuantity partition.noScheduledLink row.coordinate.locus.token
        expect (linked + unlinked == row.quantity.quanta)
          ("expense partition did not reconstruct " ++ row.coordinate.locus.token)

  let .ok wide :=
      Loam.IncomeExpenseProvenanceReview.project
        evidence "2026-07-15" "2026-10-01"
    | throw (IO.userError "wide monthly projection fixture refused")
  expect (wide.monthly.months == ["2026-07", "2026-08", "2026-09"])
    "Monthly Accounts did not retain the continuous observed month axis"
  let monthlyRent ← requireSome
    (wide.monthly.rows.find? fun row => row.coordinate.locus.token == "rent")
    "monthly rent row"
  expect
    ((Loam.MonthlyRoleFlowReview.Row.quantityAt monthlyRent "2026-07").quanta == 0 &&
      (Loam.MonthlyRoleFlowReview.Row.quantityAt monthlyRent "2026-08").quanta == 0 &&
      (Loam.MonthlyRoleFlowReview.Row.quantityAt monthlyRent "2026-09").quanta == 120)
    "Monthly Accounts did not preserve zero/zero/activity month cells"
  expect ((Loam.MonthlyRoleFlowReview.Row.total monthlyRent).quanta == 120)
    "Monthly Accounts row total did not reconstruct the period quantity"

  expect (snapshot.daily.dates == ["2026-09-01", "2026-09-02"])
    "Daily Flow did not retain sparse classified activity dates"
  let dailyRent ← requireSome
    (snapshot.daily.rows.find? fun row => row.coordinate.locus.token == "rent")
    "daily rent row"
  let dailyCoffee ← requireSome
    (snapshot.daily.rows.find? fun row => row.coordinate.locus.token == "coffee")
    "daily coffee row"
  expect
    ((Loam.DailyRoleFlowReview.Row.quantityAt dailyRent "2026-09-01").quanta == 120 &&
      (Loam.DailyRoleFlowReview.Row.quantityAt dailyRent "2026-09-02").quanta == 0 &&
      (Loam.DailyRoleFlowReview.Row.quantityAt dailyCoffee "2026-09-01").quanta == 0 &&
      (Loam.DailyRoleFlowReview.Row.quantityAt dailyCoffee "2026-09-02").quanta == 30)
    "Daily Flow did not preserve sparse per-date Expense cells"
  expect
    ((Loam.DailyRoleFlowReview.Row.total dailyRent).quanta == 120 &&
      (Loam.DailyRoleFlowReview.Row.total dailyCoffee).quanta == 30)
    "Daily Flow row totals did not reconstruct the selected-window quantities"

  let unknownEvidence : Loam.IncomeExpenseProvenanceReview.Evidence := {
    evidence with
      scheduledTerminals := .error "Scheduled lifecycle unavailable"
  }
  let .ok unknown :=
      Loam.IncomeExpenseProvenanceReview.project
        unknownEvidence "2026-09-01" "2026-10-01"
    | throw (IO.userError "UNKNOWN provenance discarded the RoleFlow answer")
  expect (unknown.roleFlow.rows == snapshot.roleFlow.rows)
    "UNKNOWN provenance changed the underlying RoleFlow answer"
  match unknown.expenseProvenance with
  | .available _ =>
      throw (IO.userError "missing Scheduled evidence became a false negative partition")
  | .unknown reason =>
      expect (reason == "Scheduled lifecycle unavailable")
        "UNKNOWN provenance lost its diagnostic"

  IO.println
    "Income Expense provenance: Scheduled completion, correction continuity, exact partition and Unknown fallback passed."
