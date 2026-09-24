import Loam.Presentation.Home

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let budget : Loam.CycleBudgetReview.Snapshot := {
    observedAt := "2026-09-24"
    window := .error "window unavailable"
    coverage := .error "coverage unavailable"
    physical := .error "physical unavailable"
    selection := .error "selection unavailable"
    funding := .ok {
      budgetableBacking := Quantity.ofQuanta 1000
      remainingAssigned := Quantity.ofQuanta 400
    }
  }

  let snapshot : Loam.Presentation.HouseholdSnapshot := {
    observedAt := "2026-09-24"
    actual := .ok []
    scheduled := .ok []
    attention := .ok (.available { openItems := [] })
    budget := budget
    capacity := .error "capacity unavailable"
    purposeMetadata := []
  }

  let home := Loam.Presentation.Home.fromSnapshot snapshot

  match home.recentActualCount with
  | .ok 0 => pure ()
  | _ => throw (IO.userError
      "Home must preserve an evidenced empty recent Actual answer")

  match home.nextScheduled with
  | .ok none => pure ()
  | _ => throw (IO.userError
      "Home must preserve an evidenced empty current-open Scheduled answer")

  match home.attentionOpenCount with
  | .ok (some 0) => pure ()
  | _ => throw (IO.userError
      "Home must distinguish configured-empty Attention from unavailable Attention")

  match home.funding with
  | .error message =>
      throw (IO.userError ("Home unexpectedly lost funding evidence: " ++ message))
  | .ok funding =>
      expect (funding.budgetableBacking.quanta == 1000)
        "Home changed budgetable backing"
      expect (funding.remainingAssigned.quanta == 400)
        "Home changed remaining assigned quantity"
      expect (funding.residualBeforeUnresolved.quanta == 600)
        "Home did not derive the exact residual from shared funding evidence"

  let unavailableAttention :=
    Loam.Presentation.Home.fromSnapshot { snapshot with attention := .ok .unavailable }
  match unavailableAttention.attentionOpenCount with
  | .ok none => pure ()
  | _ => throw (IO.userError
      "Home collapsed unavailable Attention into configured-empty Attention")

  IO.println "Home presentation: shared evidence, explicit availability, and exact funding derivation passed."
