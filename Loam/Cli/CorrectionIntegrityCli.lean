import Loam.Core.CorrectionQuantity
import Loam.Persistence
import Std

namespace Loam.CorrectionIntegrityCli

set_option autoImplicit false

private def loadCorrectionMemoryForView?
    (path : System.FilePath) : IO (Option Loam.Core.EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return Loam.Core.EventCorrectionMemory.ofCorrections? []

private def printEffects (effects : List Loam.Core.Effect) : IO Unit := do
  for effect in effects do
    IO.println
      ("    " ++ effect.locus.token ++ ": " ++
        toString effect.quantity.quanta ++ " " ++ effect.measure.token)

private def printCorrection
    (memory : Loam.Core.EventMemory)
    (correction : Loam.Core.EventCorrection) : IO Bool := do
  IO.println ("Correction " ++ correction.id.token)
  IO.println
    ("  " ++ correction.target.token ++ " -> " ++ correction.replacement.token)
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
      if correction.target = correction.replacement then
        IO.println "  Projection law: self-relation leaves recorded quantities unchanged"
      else
        IO.println "  Projection law: original contribution excluded; replacement retained once"
      IO.println "  Arithmetic balance: not asserted across different coordinates or measures"
      IO.println ""
      return true

/--
Show why recorded correction facts are structurally usable without pretending
that unlike coordinates can be arithmetically balanced against each other.
-/
def showCorrectionIntegrity (memoryPath correctionPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  if !(← correctionFile.pathExists) then
    IO.println "No corrections recorded."
    return 0
  else if !(← memoryFile.pathExists) then
    IO.eprintln "loam: correction memory exists but event memory is missing"
    return 2
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some memory =>
        match ← loadCorrectionMemoryForView? correctionFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported correction-memory file"
            return 2
        | some corrections =>
            match corrections.corrections with
            | [] =>
                IO.println "No corrections recorded."
                return 0
            | items =>
                IO.println "Correction integrity:"
                let mut allClosed := true
                for correction in items do
                  if !(← printCorrection memory correction) then
                    allClosed := false
                if allClosed then
                  IO.println "All correction relations are closed."
                  return 0
                else
                  IO.eprintln "loam: one or more correction relations are open"
                  return 1

end Loam.CorrectionIntegrityCli
