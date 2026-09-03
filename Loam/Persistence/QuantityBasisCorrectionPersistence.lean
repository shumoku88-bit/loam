import Loam.Core.QuantityBasisCorrectionMemory
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Version marker for the first raw quantity-basis correction format. -/
def quantityBasisCorrectionMemoryHeader : String :=
  "LOAM-QUANTITY-BASIS-CORRECTION-MEMORY\t1"

private def encodeQuantityBasisCorrectionRow?
    (correction : QuantityBasisCorrection) : Option String :=
  let idToken := correction.id.token
  let targetToken := correction.target.token
  let replacementToken := correction.replacement.token
  if validToken idToken && validToken targetToken && validToken replacementToken then
    some ("CORRECTION\t" ++ idToken ++ "\t" ++ targetToken ++ "\t" ++ replacementToken)
  else
    none

private def decodeQuantityBasisCorrectionRow?
    (row : String) : Option QuantityBasisCorrection :=
  match row.splitOn "\t" with
  | ["CORRECTION", idToken, targetToken, replacementToken] =>
      if validToken idToken && validToken targetToken && validToken replacementToken then
        some {
          id := ⟨idToken⟩
          target := ⟨targetToken⟩
          replacement := ⟨replacementToken⟩
        }
      else
        none
  | _ => none

/-- Encode one raw correction stream without assigning list-order authority. -/
def encodeQuantityBasisCorrectionMemory?
    (memory : QuantityBasisCorrectionMemory) : Option String :=
  match memory.corrections.mapM encodeQuantityBasisCorrectionRow? with
  | some rows =>
      some (String.intercalate "\n" (quantityBasisCorrectionMemoryHeader :: rows) ++ "\n")
  | none => none

/-- Decode one version-1 basis-correction stream and re-admit unique relation identity. -/
def decodeQuantityBasisCorrectionMemory?
    (input : String) : Option QuantityBasisCorrectionMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = quantityBasisCorrectionMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows =>
            match reversedRows.reverse.mapM decodeQuantityBasisCorrectionRow? with
            | some corrections => QuantityBasisCorrectionMemory.ofCorrections? corrections
            | none => none
        | _ => none
      else
        none
  | _ => none

private def quantityBasisCorrectionStagePath
    (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish the complete typed relation stream by sibling staging plus rename. -/
def saveQuantityBasisCorrectionMemory?
    (path : System.FilePath)
    (memory : QuantityBasisCorrectionMemory) : IO Bool := do
  match encodeQuantityBasisCorrectionMemory? memory with
  | some text =>
      let stagePath := quantityBasisCorrectionStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true
  | none => return false

/-- Read and fail-closed decode one typed basis-correction stream. -/
def loadQuantityBasisCorrectionMemory?
    (path : System.FilePath) : IO (Option QuantityBasisCorrectionMemory) := do
  let input ← IO.FS.readFile path
  return decodeQuantityBasisCorrectionMemory? input

end Loam.Persistence
