import Loam.Core.QuantityBasisMemory
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-- Version marker for the first raw quantity-basis memory format. -/
def quantityBasisMemoryHeader : String := "LOAM-QUANTITY-BASIS-MEMORY\t1"

private def encodeQuantityBasisRow? (basis : QuantityBasis) : Option String :=
  let idToken := basis.id.token
  let locusToken := basis.locus.token
  let measureToken := basis.measure.token
  if validToken idToken && validToken locusToken && validToken measureToken then
    some ("BASIS\t" ++ idToken ++ "\t" ++ locusToken ++ "\t" ++ measureToken ++ "\t" ++
      toString basis.quantity.quanta)
  else
    none

private def decodeQuantityBasisRow? (row : String) : Option QuantityBasis :=
  match row.splitOn "\t" with
  | ["BASIS", idToken, locusToken, measureToken, quantaText] =>
      if validToken idToken && validToken locusToken && validToken measureToken then
        match quantaText.toInt? with
        | some quanta =>
            some (QuantityBasis.ofQuantity
              ⟨idToken⟩ ⟨locusToken⟩ ⟨measureToken⟩
              (Quantity.ofQuanta quanta))
        | none => none
      else
        none
  | _ => none

/--
Encode raw basis memory without imposing coordinate-level currentness.

Repeated `Locus × Measure` coordinates remain representable because append-only
basis revision may retain several historical facts at one coordinate. Stable
basis identity is already unique by `QuantityBasisMemory` law.
-/
def encodeQuantityBasisMemory? (memory : QuantityBasisMemory) : Option String :=
  match memory.bases.mapM encodeQuantityBasisRow? with
  | some rows =>
      some (String.intercalate "\n" (quantityBasisMemoryHeader :: rows) ++ "\n")
  | none => none

/-- Decode one raw version-1 basis stream and re-admit unique basis identity. -/
def decodeQuantityBasisMemory? (input : String) : Option QuantityBasisMemory :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = quantityBasisMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows =>
            match reversedRows.reverse.mapM decodeQuantityBasisRow? with
            | some bases => QuantityBasisMemory.ofBases? bases
            | none => none
        | _ => none
      else
        none
  | _ => none

private def quantityBasisMemoryStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one raw basis stream by complete sibling staging plus rename. -/
def saveQuantityBasisMemory?
    (path : System.FilePath)
    (memory : QuantityBasisMemory) : IO Bool := do
  match encodeQuantityBasisMemory? memory with
  | some text =>
      let stagePath := quantityBasisMemoryStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true
  | none =>
      return false

/-- Read and fail-closed decode one raw quantity-basis stream. -/
def loadQuantityBasisMemory?
    (path : System.FilePath) : IO (Option QuantityBasisMemory) := do
  let input ← IO.FS.readFile path
  return decodeQuantityBasisMemory? input

end Loam.Persistence
