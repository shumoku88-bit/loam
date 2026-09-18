import Loam.ScheduledGeneration

namespace Loam.Tests.ScheduledGeneration

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def expectPlan
    (label observedAt anchor endExclusive : String)
    (cadence : Loam.ScheduledGeneration.GenerationCadence)
    (expected : List String) : IO Unit := do
  match Loam.ScheduledGeneration.plan
      { endExclusive := endExclusive } observedAt { anchor, cadence } with
  | .error message =>
      throw (IO.userError (label ++ ": unexpected refusal: " ++ message))
  | .ok dates =>
      expect (dates == expected)
        s!"{label}: expected {repr expected}, got {repr dates}"

def run : IO Unit := do
  expectPlan "monthly wifi before arbitrary limit"
    "2026-09-08" "2026-09-08" "2026-10-15"
    .monthly ["2026-10-08"]

  expectPlan "exclusive limit remains excluded"
    "2026-09-15" "2026-09-15" "2026-10-15"
    .monthly []

  expectPlan "two-month cadence remains explicit"
    "2026-08-14" "2026-08-14" "2026-10-15"
    .everyTwoMonths ["2026-10-14"]

  expectPlan "already-past candidates are not recreated"
    "2026-09-18" "2026-08-14" "2026-10-15"
    .monthly ["2026-10-14"]

  expectPlan "far fill limit crosses household-cycle boundaries without knowing them"
    "2026-09-18" "2026-08-15" "2027-02-15"
    .monthly ["2026-10-15", "2026-11-15", "2026-12-15", "2027-01-15"]

  expectPlan "non-boundary custom date is a valid fill limit"
    "2026-09-18" "2026-08-15" "2027-01-20"
    .monthly ["2026-10-15", "2026-11-15", "2026-12-15", "2027-01-15"]

  expectPlan "old source can seed after an unrelated reporting boundary switch"
    "2026-10-16" "2026-09-15" "2026-12-15"
    .monthly ["2026-11-15"]

  let shortLimit : Loam.ScheduledGeneration.FillLimit := {
    endExclusive := "2026-03-15"
  }
  match Loam.ScheduledGeneration.planCandidates shortLimit "2026-01-01"
      { anchor := "2026-01-31", cadence := .monthly } with
  | .error message =>
      throw (IO.userError ("day-31 candidate planning unexpectedly refused: " ++ message))
  | .ok candidates =>
      expect (candidates == [.needsDate 2026 2 31])
        s!"day-31 candidate did not stay explicitly unresolved: {repr candidates}"

  match Loam.ScheduledGeneration.plan shortLimit "2026-01-01"
      { anchor := "2026-01-31", cadence := .monthly } with
  | .ok dates =>
      throw (IO.userError s!"day-31 monthly fill silently invented dates: {repr dates}")
  | .error _ => pure ()

  expect (Loam.ScheduledGeneration.validResolvedDate
      shortLimit "2026-01-01" "2026-02-28")
    "human-resolved February 28 was not accepted before the fill limit"
  expect (!Loam.ScheduledGeneration.validResolvedDate
      shortLimit "2026-01-01" "2026-03-15")
    "exclusive fill limit was accepted as a human-resolved date"
  expect (!Loam.ScheduledGeneration.validResolvedDate
      shortLimit "2026-02-28" "2026-02-27")
    "review accepted a date before the observation coordinate"

  let twoMonthLimit : Loam.ScheduledGeneration.FillLimit := {
    endExclusive := "2026-04-15"
  }
  match Loam.ScheduledGeneration.plan twoMonthLimit "2026-01-01"
      { anchor := "2026-01-31", cadence := .everyTwoMonths } with
  | .error message =>
      throw (IO.userError ("two-month day-31 fill refused valid March target: " ++ message))
  | .ok dates =>
      expect (dates == ["2026-03-31"])
        s!"two-month day-31 fill changed target: {repr dates}"

  match Loam.ScheduledGeneration.plan
      { endExclusive := "2026-09-18" } "2026-09-18"
      { anchor := "2026-08-15", cadence := .monthly } with
  | .ok dates =>
      throw (IO.userError s!"observation equal to fill limit was accepted: {repr dates}")
  | .error _ => pure ()

  IO.println "Scheduled generation: cycle-independent fill-limit checks succeeded."

end Loam.Tests.ScheduledGeneration

def main : IO Unit :=
  Loam.Tests.ScheduledGeneration.run
