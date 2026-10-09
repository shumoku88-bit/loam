import Loam.Review.CurrentBalanceReview
import Loam.MovementWorldLoader

/-!
Manual compiled phase probe for an immutable synthetic Household fixture.
Build/run instructions and limits: docs/research/TUI_RESOURCE_QUALITY_2026-10-09.md.
Pure work is deferred through a thunk so it runs AFTER the first clock sample.
Re-admission is measured separately on decoded evidence, not added to codec time.
-/

private def need {α : Type} (value : Option α) (label : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError label)

private def require {α : Type} (value : Except String α) : IO α :=
  match value with
  | .ok value => pure value
  | .error label => throw (IO.userError label)

private def phase {α : Type} (label : String) (action : Unit → IO α) : IO α := do
  let start ← IO.monoNanosNow
  let value ← action ()
  let finish ← IO.monoNanosNow
  IO.println s!"{label}: {(finish - start) / 1000000}ms"
  return value

def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "immutable synthetic root required")
  let root := System.FilePath.mk path
  let wire ← phase "file IO" fun _ => IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let outer ← phase "outer framing" fun _ =>
    need (Loam.Persistence.HouseholdImage.decode? wire) "outer refused"
  let body ← need (Loam.Persistence.HouseholdImage.body? outer "Actual") "missing Actual"
  let image ← phase "Actual parse+construction+admission" fun _ =>
    need (Loam.Persistence.decodeNormalizedActualImage? body) "Actual refused"
  let admitted ← phase "re-admission alone" fun _ =>
    need (Loam.Persistence.admitActualImage? image.evidence) "admission refused"
  let (generation, actual) ← phase "full household selection" fun _ => do
    require (← Loam.HouseholdAuthority.loadCurrentWithActual? root)
  unless generation.wire == wire do throw (IO.userError "fixture changed during profiling")
  let balances ← phase "Balance projection from generation" fun _ => do
    require (Loam.CurrentBalanceReview.projectFromGeneration generation image)
  let world ← phase "fresh Record world" fun _ => do
    require (← Loam.MovementWorldLoader.loadSelectedWorld? root)
  unless (← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == wire do
    throw (IO.userError "fixture changed during profiling")
  IO.println s!"events={admitted.evidence.events.events.length}, Actual present={actual.isSome}, balances={balances.rows.length}, world events={world.events.events.length}"
