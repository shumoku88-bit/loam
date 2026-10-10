import Loam.Review.DailyPacePeriods

open Loam.DailyPacePeriods

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def configured : List Loam.BoundaryPresetConfig.Preset :=
  [{name := "explicit", boundaries := ["2025-12-21", "2026-01-21", "2026-02-21", "2026-03-21", "2026-04-21"]}]

private def range (preset : Preset) (day start through : String) : IO Unit :=
  expect (decide ((resolve preset day configured).toOption = some {start, through})) (preset.label ++ " range drift")

def main : IO Unit := do
  expect (presets.length == 5) "missing range choice"
  range .tenDays "2026-03-01" "2026-02-20" "2026-03-01"
  range .thirtyDays "2026-03-01" "2026-01-31" "2026-03-01"
  range .month "2026-03-01" "2026-03-01" "2026-03-01"
  range .month "2026-03-31" "2026-03-01" "2026-03-31"
  range .cycle "2026-03-01" "2026-02-21" "2026-03-01"
  range .cycle "2026-03-21" "2026-03-21" "2026-03-21"
  range .previousCycle "2026-03-01" "2026-01-21" "2026-02-20"
  range .previousCycle "2026-03-21" "2026-02-21" "2026-03-20"
  range .tenDays "2026-01-01" "2025-12-23" "2026-01-01"
  expect ((resolve .tenDays "2026-03-01" []).isOk && (resolve .month "2026-03-01" []).isOk)
    "display coordinates unnecessarily depend on cycle evidence"
  for choice in [.cycle, .previousCycle] do
    expect (!(resolve choice "2026-03-01" []).isOk) "missing cycle guessed"
    expect (!(resolve choice "2026-03-01" (configured ++ [{name := "overlap", boundaries := ["2026-02-01", "2026-04-01"]}])).isOk)
      "ambiguous current cycle assigned precedence"
  expect (!(resolve .previousCycle "2025-12-22" configured).isOk) "previous boundary extrapolated"
  expect (!(resolve .month "2026-02-30" configured).isOk) "invalid observation admitted"
  let leap := ({start := "2024-02-28", through := "2024-03-01"} : Range).dates
  expect (leap.toOption == some ["2024-02-28", "2024-02-29", "2024-03-01"]) "inclusive leap-day enumeration drift"
  IO.println "Daily Pace periods: five daily ranges, calendar edges and explicit cycle/refusal resolution passed."
