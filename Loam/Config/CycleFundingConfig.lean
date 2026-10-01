import Loam.Config.BalanceViewConfig

namespace Loam.CycleFundingConfig

open Loam.Core
set_option autoImplicit false

/-!
Replaceable application/query selection, not canonical or append-only authority.
Shares only the two-column TSV grammar with BalanceViewConfig, never its file,
loader, or selection. One funding selection is always single-Measure and must
match the CurrentCoverage Measure. An explicitly empty file selects nothing.
Absence is an error, not that choice.
-/
def decodeForMeasure? (measure : MeasureId) (input : String) : Option (List EffectCoordinate) := do
  let coordinates ← Loam.BalanceViewConfig.decode? input
  if decide coordinates.Nodup && coordinates.all (fun c => c.measure == measure) then
    some coordinates
  else none

/-- Backward-compatible funding decoder for the current JPY household. -/
def decode? (input : String) : Option (List EffectCoordinate) :=
  decodeForMeasure? ⟨"jpy"⟩ input

def loadForMeasure
    (measure : MeasureId)
    (path : System.FilePath) : IO (Except String (List EffectCoordinate)) := do
  try
    if !(← path.pathExists) then
      return .error "Budgetable backing not configured (config/cycle-funding.tsv missing)"
    match decodeForMeasure? measure (← IO.FS.readFile path) with
    | some coordinates => return .ok coordinates
    | none =>
        return .error
          ("cycle-funding.tsv malformed, duplicate coordinate, or uses a Measure other than " ++
            measure.token)
  catch error => return .error ("cycle-funding.tsv unreadable: " ++ error.toString)

/-- Backward-compatible funding loader for the current JPY household. -/
def load (path : System.FilePath) : IO (Except String (List EffectCoordinate)) :=
  loadForMeasure ⟨"jpy"⟩ path

end Loam.CycleFundingConfig
