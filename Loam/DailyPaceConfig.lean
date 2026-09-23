import Loam.BalanceViewConfig

namespace Loam.DailyPaceConfig

open Loam.Core

set_option autoImplicit false

/-!
# Daily Pace pool selection

Replaceable application/query configuration selecting the current JPY balance
coordinates that may fund ordinary day-to-day spending.

This is deliberately separate from `balance-view.tsv` and
`cycle-funding.tsv`. Display selection, budget backing, and day-to-day spending
eligibility answer different questions. This file is not canonical household
history and carries no writer, identity, or append-only semantics.
-/

def decode? (input : String) : Option (List EffectCoordinate) := do
  let coordinates ← Loam.BalanceViewConfig.decode? input
  if decide coordinates.Nodup &&
      coordinates.all (fun coordinate => coordinate.measure.token == "jpy") then
    some coordinates
  else
    none

def load (path : System.FilePath) : IO (Except String (List EffectCoordinate)) := do
  try
    if !(← path.pathExists) then
      return .error "Daily Pace pool not configured (config/daily-pace.tsv missing)"
    match decode? (← IO.FS.readFile path) with
    | some coordinates => return .ok coordinates
    | none =>
        return .error
          "daily-pace.tsv malformed, contains duplicate coordinates, or uses a non-JPY measure"
  catch error =>
    return .error ("daily-pace.tsv unreadable: " ++ error.toString)

end Loam.DailyPaceConfig
