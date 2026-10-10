import Loam.Review.DailyPacePeriods
import Loam.Tui.Chart

/-! Manual native read-only phase probe. Use only immutable synthetic fixtures.
Both reconstruction variants use the same admitted image and exact shared kernel.
Pure work is delayed through a thunk until after the clock. -/

private def need {α : Type} (answer : Except String α) : IO α :=
  match answer with
  | .ok value => pure value
  | .error message => throw (IO.userError message)

private def phase {α : Type} (label : String) (action : Unit → IO α) : IO α := do
  let start ← IO.monoNanosNow
  let value ← action ()
  let finish ← IO.monoNanosNow
  IO.println s!"{label}: {(finish - start) / 1000000}ms"
  return value

def main (args : List String) : IO Unit := do
  let [path, countText] := args | throw (IO.userError "synthetic root and day count required")
  let some count := countText.toNat? | throw (IO.userError "invalid day count")
  let root := System.FilePath.mk path
  let observed ← phase "Household selection+Actual admission" fun _ => do
    need (← Loam.ActualAuthority.loadHouseholdObserved? root)
  let some today ← Loam.ActualDate.todayIso? | throw (IO.userError "local date missing")
  let some configured ← Loam.BoundaryPresetConfig.load? (Loam.HouseholdPaths.boundaryPresets root)
    | throw (IO.userError "configuration missing")
  let source ← need (Loam.DailyPacePeriods.cyclePreset configured today)
  let selection ← need (← Loam.DailyPaceConfig.loadForMeasure ⟨"jpy"⟩ (Loam.HouseholdPaths.dailyPace root))
  let evidence ← need (Loam.HistoricalBalanceReview.evidenceFromGeneration observed.generation)
  let scheduled ← need (Loam.ScheduledReview.fromGenerationForEvents observed.generation observed.image.evidence.events)
  let days ← (List.range count).mapM fun offset => do
    let some day := Loam.ActualDate.shiftDays? today (-Int.ofNat offset) | throw (IO.userError "calendar bound")
    let some (_, endExclusive) := Loam.BoundaryPresetConfig.windowForDate? source day
      | throw (IO.userError "explicit cycle missing")
    pure (day, endExclusive)
  let ordinary ← phase "singleton daily reconstruction" fun _ => pure (days.flatMap fun day =>
    Loam.CycleSpendingPaceReview.projectHistoricalDaysForMeasure ⟨"jpy"⟩
      observed.image evidence selection scheduled [day])
  let batch ← phase "batched daily reconstruction" fun _ => pure (
    Loam.CycleSpendingPaceReview.projectHistoricalDaysForMeasure ⟨"jpy"⟩
      observed.image evidence selection scheduled days)
  unless ordinary.length == batch.length && (ordinary.zip batch).all (fun (left, right) =>
    match left, right with
    | .ok a, .ok b => a == b
    | .error a, .error b => a == b
    | _, _ => false) do throw (IO.userError "batch changed daily answers")
  let values := batch.filterMap fun result => result.toOption.bind (·.dailyPaceQuanta?)
  let checksum ← phase "shared chart raster+cell expansion x20 (140x18)" fun _ => pure (
    (List.range 20).foldl (fun total selected =>
      let rows := Loam.Tui.Chart.renderInRange .braille 140 18 values selected (Loam.Tui.Chart.rangeFor values)
      total + rows.foldl (fun sum row => sum + row.lines.flatten.foldl (fun n cell => n + cell.glyph.toNat) 0) 0) 0)
  IO.println s!"days={count}; exact singleton/batch parity; raster checksum={checksum}"
