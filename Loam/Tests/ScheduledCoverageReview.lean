import Loam.ScheduledCoverageReview
import Loam.Tui.ScheduledCoveragePane

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def widgetText (widgets : List Widget) : String :=
  String.intercalate "\n" <| widgets.flatMap fun widget =>
    widget.lines.map fun cells => String.ofList (cells.map Cell.glyph)

private def occurrence?
    (id date negative positive : String) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨negative⟩, quantity := Quantity.ofQuanta (-1000) }
    , { coordinate := ⟨positive⟩, quantity := Quantity.ofQuanta 1000 } ]
  pure { id := ⟨id⟩, scheduledOn := date, movement := movement }

def main : IO Unit := do
  let monthly : Loam.ScheduledCoverageConfig.Rule := {
    name := "gpt-plus"
    anchor := "2026-08-15"
    everyMonths := 1
    negativeLoci := ["cash"]
    positiveLoci := ["gpt-plus"]
  }
  let bimonthly : Loam.ScheduledCoverageConfig.Rule := {
    name := "pension"
    anchor := "2026-09-15"
    everyMonths := 2
    negativeLoci := ["pension"]
    positiveLoci := ["cash"]
  }
  let some octGpt := occurrence? "scheduled-1" "2026-10-15" "cash" "gpt-plus"
    | throw (IO.userError "fixture oct gpt")
  let some novGpt := occurrence? "scheduled-2" "2026-11-15" "cash" "gpt-plus"
    | throw (IO.userError "fixture nov gpt")
  let some novPension := occurrence? "scheduled-3" "2026-11-15" "pension" "cash"
    | throw (IO.userError "fixture nov pension")
  let some decPension := occurrence? "scheduled-4" "2026-12-15" "pension" "cash"
    | throw (IO.userError "fixture off-pattern pension")

  let snapshot ←
    match Loam.ScheduledCoverageReview.projectRecords
        [monthly, bimonthly] [octGpt, novGpt, novPension, decPension]
        "2026-09-18" 4 with
    | .error message => throw (IO.userError message)
    | .ok snapshot => pure snapshot

  expect (snapshot.months == ["2026-10", "2026-11", "2026-12", "2027-01"])
    "Scheduled coverage month grid did not advance from the observation month"

  let some gpt := snapshot.rows[0]? | throw (IO.userError "missing monthly row")
  expect (gpt.firstMissing == some "2026-12")
    "monthly coverage did not expose the first missing expected month"
  let some pension := snapshot.rows[1]? | throw (IO.userError "missing bimonthly row")
  expect (pension.firstMissing == some "2027-01")
    "bimonthly coverage did not preserve anchor parity"

  let rendered := widgetText (Loam.Tui.ScheduledCoveragePane.lines snapshot)
  expect (contains "gpt-plus" rendered && contains "pension" rendered)
    "Scheduled coverage pane did not render configured rules"
  expect (contains "through 2026-11" rendered && contains "next gap 2026-12" rendered)
    "monthly Scheduled coverage pane did not render entered-through and next-gap diagnostics"
  expect (contains "through 2026-11" rendered && contains "next gap 2027-01" rendered)
    "bimonthly Scheduled coverage pane did not render entered-through and next-gap diagnostics"
  expect (contains "explicit off-pattern" rendered)
    "Scheduled coverage pane lost the explicit off-pattern distinction"
  expect (contains "do not create recurrence authority" rendered)
    "Scheduled coverage pane overstated read-side monitoring rules"

  let goodConfig :=
    "gpt-plus\t2026-08-15\t1\tcash\tgpt-plus\n" ++
    "pension\t2026-09-15\t2\tpension\tcash\n" ++
    "support\t2026-09-15\t2\tsupport\tcash\n"
  expect (Loam.ScheduledCoverageConfig.decode? goodConfig).isSome
    "Scheduled coverage config rejected valid monthly/bimonthly rules"
  expect (Loam.ScheduledCoverageConfig.decode?
      "bad\t2026-09-15\t0\tpension\tcash\n").isNone
    "Scheduled coverage config accepted zero month cadence"
  expect (Loam.ScheduledCoverageConfig.decode?
      "one\t2026-09-15\t1\tpension\tcash\ntwo\t2026-10-15\t2\tpension\tcash\n").isNone
    "Scheduled coverage config accepted an ambiguous duplicate signed-Locus selector"

  IO.println "Scheduled coverage: monthly/bimonthly grid, first-gap detection, off-pattern evidence, config validation, and TUI rendering passed."
