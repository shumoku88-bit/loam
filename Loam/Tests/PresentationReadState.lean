import Loam.Presentation.HouseholdSnapshot

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let loadedNone : Loam.Presentation.ReadState (Option Nat) := .loaded none
  match loadedNone with
  | .loaded none => pure ()
  | _ => throw (IO.userError "loaded none collapsed into read unavailability")

  let failed : Loam.Presentation.ReadState Nat := .failed "diagnostic"
  match Loam.Presentation.ReadState.map failed (fun value => value + 1) with
  | .failed "diagnostic" => pure ()
  | _ => throw (IO.userError "ReadState.map changed failure classification or diagnostic")

  match Loam.Presentation.ReadState.fromExcept (Except.ok 7 : Except String Nat) with
  | .loaded 7 => pure ()
  | _ => throw (IO.userError "ReadState.fromExcept did not preserve a loaded value")

  match Loam.Presentation.ReadState.fromExcept (Except.error "refused" : Except String Nat) with
  | .failed "refused" => pure ()
  | _ => throw (IO.userError "ReadState.fromExcept did not classify refusal as failed")

  let budget : Loam.CycleBudgetReview.Snapshot := {
    observedAt := "2026-09-25"
    window := .error "not relevant"
    coverage := .error "not relevant"
    physical := .error "not relevant"
    selection := .error "not relevant"
    funding := .error "not relevant"
  }
  let snapshot : Loam.Presentation.HouseholdSnapshot := {
    observedAt := "2026-09-25"
    actual := .loaded []
    scheduled := .loaded []
    attention := .unavailable
    budget := budget
    capacity := .loaded { rows := [] }
  }

  match snapshot.pace with
  | .notRequested => pure ()
  | _ => throw (IO.userError "Daily Pace must default to notRequested")
  match snapshot.stockFlow with
  | .notRequested => pure ()
  | _ => throw (IO.userError "Stock-Flow must default to notRequested")
  match snapshot.roleFlow with
  | .notRequested => pure ()
  | _ => throw (IO.userError "Role Flow must default to notRequested")
  match snapshot.roleBalances with
  | .notRequested => pure ()
  | _ => throw (IO.userError "Role Balances must default to notRequested")
  match snapshot.transactionsFlow with
  | .notRequested => pure ()
  | _ => throw (IO.userError "Transactions Flow must default to notRequested")

  expect true "typed read-state qualification completed"
  IO.println "Presentation ReadState: loaded emptiness, failure, and not-requested defaults passed."
