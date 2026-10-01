import Loam.Config.BalanceViewConfig

namespace Loam.DailyPaceConfig

open Loam.Core

set_option autoImplicit false

/-!
# Daily Pace pool selection

Replaceable application/query configuration selecting the current single-Measure
balance coordinates that may fund ordinary day-to-day spending.

This is deliberately separate from `balance-view.tsv` and
`cycle-funding.tsv`. Display selection, budget backing, and day-to-day spending
eligibility answer different questions. This file is not canonical household
history and carries no writer, identity, or append-only semantics.
-/

def decodeForMeasure? (measure : MeasureId) (input : String) : Option (List EffectCoordinate) := do
  let coordinates ← Loam.BalanceViewConfig.decode? input
  if decide coordinates.Nodup &&
      coordinates.all (fun coordinate => coordinate.measure == measure) then
    some coordinates
  else
    none

/-- Backward-compatible Daily Pace configuration decoder for the current JPY household. -/
def decode? (input : String) : Option (List EffectCoordinate) :=
  decodeForMeasure? ⟨"jpy"⟩ input

def loadForMeasure
    (measure : MeasureId)
    (path : System.FilePath) : IO (Except String (List EffectCoordinate)) := do
  try
    if !(← path.pathExists) then
      return .error "Daily Pace pool not configured (config/daily-pace.tsv missing)"
    match decodeForMeasure? measure (← IO.FS.readFile path) with
    | some coordinates => return .ok coordinates
    | none =>
        return .error
          ("daily-pace.tsv malformed, contains duplicate coordinates, or uses a Measure other than " ++
            measure.token)
  catch error =>
    return .error ("daily-pace.tsv unreadable: " ++ error.toString)

/-- Backward-compatible Daily Pace configuration loader for the current JPY household. -/
def load (path : System.FilePath) : IO (Except String (List EffectCoordinate)) :=
  loadForMeasure ⟨"jpy"⟩ path

end Loam.DailyPaceConfig
