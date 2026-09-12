import Loam.ActualAuthority
import Std

namespace Loam.CorrectionIntegrityCli

set_option autoImplicit false

private def printEffects (effects : List Loam.Core.Effect) : IO Unit := do
  for effect in effects do
    IO.println
      ("    " ++ effect.locus.token ++ ": " ++
        toString effect.quantity.quanta ++ " " ++ effect.measure.token)

private def printCorrection
    (memory : Loam.Core.EventMemory)
    (correction : Loam.Core.EventCorrection) : IO Bool := do
  IO.println
    ("Correction " ++ correction.target.token ++ " -> " ++ correction.replacement.token)
  if correction.target = correction.replacement then
    IO.println "  relation: cyclic (target and replacement are the same Event)"
    IO.println "  effective projection: unavailable"
    IO.println ""
    return false
  else
    match Loam.Core.EventCorrection.project? memory correction with
    | none =>
        IO.println "  relation: open (one or both endpoint Events are missing)"
        IO.println "  effective projection: unavailable"
        IO.println ""
        return false
    | some projected =>
        IO.println "  relation: closed"
        IO.println "  Original contribution:"
        printEffects projected.original.effects
        IO.println "  Replacement contribution:"
        printEffects projected.effective.effects
        IO.println "  Projection law: original contribution excluded; replacement retained once"
        IO.println "  Arithmetic balance: not asserted across different coordinates or measures"
        IO.println ""
        return true

/--
Show why recorded correction facts are structurally usable without pretending
that unlike coordinates can be arithmetically balanced against each other.
-/
def showCorrectionIntegrity (actualPath : String) (_correctionPath : Option String := none) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok ev => pure ev
  let memory := evidence.events
  let corrections := evidence.corrections
  match corrections.corrections with
  | [] =>
      IO.println "No corrections recorded."
      return 0
  | items =>
      IO.println "Correction integrity:"
      let mut allUsable := true
      for correction in items do
        if !(← printCorrection memory correction) then
          allUsable := false
      if allUsable then
        IO.println "All correction relations are closed."
        return 0
      else
        IO.eprintln "loam: one or more correction relations are open or cyclic"
        return 1

end Loam.CorrectionIntegrityCli
