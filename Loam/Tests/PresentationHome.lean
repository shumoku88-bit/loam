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
    actual := .loaded []
    scheduled := .loaded []
    attention := .loaded { openItems := [] }
    budget := budget
    capacity := .failed "capacity unavailable"
    pace := .loaded {
      observedAt := "2026-09-24"
      endExclusive := "2026-09-28"
      remainingDays := 4
      eligiblePool := Quantity.ofQuanta 5000
      automaticDeductions := Quantity.ofQuanta 1000
      availableThroughEnd := Quantity.ofQuanta 4000
    }
    purposeMetadata := []
  }

  let home := Loam.Presentation.Home.fromSnapshot snapshot

  match home.recentActualCount with
  | .loaded 0 => pure ()
  | _ => throw (IO.userError
      "Home must preserve an evidenced empty recent Actual answer")

  match home.nextScheduled with
  | .loaded none => pure ()
  | _ => throw (IO.userError
      "Home must preserve an evidenced empty current-open Scheduled answer")

  match home.attentionOpenCount with
  | .loaded 0 => pure ()
  | _ => throw (IO.userError
      "Home must distinguish configured-empty Attention from unavailable Attention")

  match home.dailyPace with
  | .loaded (some pace) =>
      expect (pace.quantaPerDay == 1000)
        "Home changed the exact Daily Pace quotient"
      expect (pace.availableThroughEnd.quanta == 4000)
        "Home changed Daily Pace available-through-end quantity"
      expect (pace.remainingDays == 4)
        "Home changed Daily Pace remaining-day evidence"
      expect (pace.endExclusive == "2026-09-28")
        "Home changed Daily Pace cycle end"
  | _ => throw (IO.userError
      "Home unexpectedly lost available Daily Pace evidence")

  match home.funding with
  | .notRequested =>
      throw (IO.userError "Home unexpectedly left funding not requested")
  | .unavailable =>
      throw (IO.userError "Home unexpectedly classified funding as unavailable")
  | .failed message =>
      throw (IO.userError ("Home unexpectedly lost funding evidence: " ++ message))
  | .loaded funding =>
      expect (funding.budgetableBacking.quanta == 1000)
        "Home changed budgetable backing"
      expect (funding.remainingAssigned.quanta == 400)
        "Home changed remaining assigned quantity"
      expect (funding.residualBeforeUnresolved.quanta == 600)
        "Home did not derive the exact residual from shared funding evidence"

  let unavailableAttention :=
    Loam.Presentation.Home.fromSnapshot { snapshot with attention := .unavailable }
  match unavailableAttention.attentionOpenCount with
  | .unavailable => pure ()
  | _ => throw (IO.userError
      "Home collapsed unavailable Attention into configured-empty Attention")

  IO.println "Home presentation: shared evidence, explicit availability, and exact funding derivation passed."
