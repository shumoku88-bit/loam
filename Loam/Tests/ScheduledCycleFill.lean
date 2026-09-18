import Loam.ScheduledCycleFill

namespace Loam.Tests.ScheduledCycleFill

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def currentWindow : Loam.BoundaryPresetConfig.CurrentWindow := {
  source := "Pension"
  start := "2026-08-14"
  endExclusive := "2026-10-15"
  hasFollowingBoundary := true
}

private def expectPlan
    (label observedAt anchor : String)
    (cadence : Loam.ScheduledCycleFill.GenerationCadence)
    (expected : List String) : IO Unit := do
  match Loam.ScheduledCycleFill.planAfter currentWindow observedAt { anchor, cadence } with
  | .error message =>
      throw (IO.userError (label ++ ": unexpected refusal: " ++ message))
  | .ok dates =>
      expect (dates == expected)
        (label ++ ": expected " ++ repr expected ++ ", got " ++ repr dates)

def main : IO Unit := do
  expectPlan "monthly wifi inside current cycle"
    "2026-09-08" "2026-09-08" .monthly ["2026-10-08"]

  expectPlan "monthly boundary remains excluded"
    "2026-09-15" "2026-09-15" .monthly []

  expectPlan "two-month cadence does not invent an in-cycle occurrence"
    "2026-08-15" "2026-08-15" .everyTwoMonths []

  expectPlan "yearly cadence remains explicit even when it generates nothing"
    "2026-08-15" "2026-08-15" .yearly []

  expectPlan "monthly fill can generate multiple explicit current-cycle dates"
    "2026-08-14" "2026-08-14" .monthly ["2026-09-14", "2026-10-14"]

  expectPlan "already-past candidates are not recreated"
    "2026-09-18" "2026-08-10" .monthly ["2026-10-10"]

  let shortWindow : Loam.BoundaryPresetConfig.CurrentWindow := {
    source := "test"
    start := "2026-01-01"
    endExclusive := "2026-03-15"
    hasFollowingBoundary := true
  }
  match Loam.ScheduledCycleFill.planAfter shortWindow "2026-01-01"
      { anchor := "2026-01-31", cadence := .monthly } with
  | .ok dates =>
      throw (IO.userError ("day-31 monthly fill silently invented dates: " ++ repr dates))
  | .error _ => pure ()

  let twoMonthWindow : Loam.BoundaryPresetConfig.CurrentWindow := {
    source := "test"
    start := "2026-01-01"
    endExclusive := "2026-04-15"
    hasFollowingBoundary := true
  }
  match Loam.ScheduledCycleFill.planAfter twoMonthWindow "2026-01-01"
      { anchor := "2026-01-31", cadence := .everyTwoMonths } with
  | .error message =>
      throw (IO.userError ("two-month day-31 fill refused valid March target: " ++ message))
  | .ok dates =>
      expect (dates == ["2026-03-31"])
        ("two-month day-31 fill changed target: " ++ repr dates)

  IO.println "Scheduled current-cycle generation checks succeeded."

end Loam.Tests.ScheduledCycleFill
