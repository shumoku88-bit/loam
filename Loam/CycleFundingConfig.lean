import Loam.BalanceViewConfig

namespace Loam.CycleFundingConfig

open Loam.Core
set_option autoImplicit false

/-!
Replaceable application/query selection, not canonical or append-only authority.
Shares only the two-column TSV grammar with BalanceViewConfig, never its file,
loader, or selection. CurrentCoverage is JPY-only; other measures are refused.
An explicitly empty file selects nothing. Absence is an error, not that choice.
-/
def decode? (input : String) : Option (List EffectCoordinate) := do
  let coordinates ← Loam.BalanceViewConfig.decode? input
  if decide coordinates.Nodup && coordinates.all (fun c => c.measure.token == "jpy") then
    some coordinates
  else none

def load (path : System.FilePath) : IO (Except String (List EffectCoordinate)) := do
  try
    if !(← path.pathExists) then
      return .error "Budgetable backing not configured (config/cycle-funding.tsv missing)"
    match decode? (← IO.FS.readFile path) with
    | some coordinates => return .ok coordinates
    | none => return .error "cycle-funding.tsv malformed, duplicate coordinate, or non-JPY measure"
  catch error => return .error ("cycle-funding.tsv unreadable: " ++ error.toString)

end Loam.CycleFundingConfig
