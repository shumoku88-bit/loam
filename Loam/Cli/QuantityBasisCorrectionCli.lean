import Loam.Application.QuantityBasisFrontier
import Loam.Persistence.QuantityBasisCorrectionPersistence
import Loam.Persistence.QuantityBasisPersistence
import Loam.WriterOwnership
import Std

namespace Loam.QuantityBasisCorrectionCli

open Loam.Core

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def getAt? {α : Type} : List α → Nat → Option α
  | [], _ => none
  | item :: _, 0 => some item
  | _ :: rest, index + 1 => getAt? rest index

private def printCandidates : Nat → List QuantityBasis → IO Unit
  | _, [] => pure ()
  | index, basis :: rest => do
      IO.println
        (toString index ++ ". " ++ basis.locus.token ++ ": " ++
          toString basis.quantity.quanta ++ " " ++ basis.measure.token ++
          "  [" ++ basis.id.token ++ "]")
      printCandidates (index + 1) rest

private def loadBasisMemoryForCorrection?
    (path : System.FilePath) : IO (Option QuantityBasisMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadQuantityBasisMemory? path
  else
    return none

private def loadBasisCorrectionMemoryForEntry?
    (path : System.FilePath) : IO (Option QuantityBasisCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadQuantityBasisCorrectionMemory? path
  else
    return QuantityBasisCorrectionMemory.ofCorrections? []

private def freshBasisIdFrom
    (memory : QuantityBasisMemory) : Nat → Nat → Option QuantityBasisId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : QuantityBasisId := ⟨"basis-" ++ toString index⟩
      match QuantityBasisMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshBasisIdFrom memory (index + 1) fuel

private def freshBasisId? (memory : QuantityBasisMemory) : Option QuantityBasisId :=
  freshBasisIdFrom memory 1 (memory.bases.length + 1)

private def freshCorrectionIdFrom
    (memory : QuantityBasisCorrectionMemory) : Nat → Nat → Option QuantityBasisCorrectionId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : QuantityBasisCorrectionId := ⟨"basis-correction-" ++ toString index⟩
      match QuantityBasisCorrectionMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshCorrectionIdFrom memory (index + 1) fuel

private def freshCorrectionId?
    (memory : QuantityBasisCorrectionMemory) : Option QuantityBasisCorrectionId :=
  freshCorrectionIdFrom memory 1 (memory.corrections.length + 1)

private def correctStartingJpyUnlocked
    (basisPath basisCorrectionPath : String) : IO UInt32 := do
  let basisFile := System.FilePath.mk basisPath
  let correctionFile := System.FilePath.mk basisCorrectionPath
  match ← loadBasisMemoryForCorrection? basisFile with
  | none =>
      IO.eprintln "loam: no valid starting quantities are available to correct"
      return 2
  | some bases =>
      match ← loadBasisCorrectionMemoryForEntry? correctionFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported quantity-basis correction file"
          return 2
      | some corrections =>
          match Loam.Application.admittedQuantityBasisFrontier? bases corrections with
          | none =>
              IO.eprintln
                "loam: starting quantity correction unavailable: remembered basis facts do not justify one current frontier"
              return 1
          | some candidates =>
              match candidates with
              | [] =>
                  IO.println "No starting quantities are available to correct."
                  return 0
              | _ =>
                  IO.println "Which starting quantity should be corrected?"
                  printCandidates 1 candidates
                  let selectionText ← promptLine "Select number: "
                  match selectionText.toNat? with
                  | none =>
                      IO.eprintln "loam: choose one of the displayed numbers"
                      return 2
                  | some 0 =>
                      IO.eprintln "loam: choose one of the displayed numbers"
                      return 2
                  | some selection =>
                      match getAt? candidates (selection - 1) with
                      | none =>
                          IO.eprintln "loam: choose one of the displayed numbers"
                          return 2
                      | some target =>
                          let quantityText ← promptLine "Correct starting quantity to? "
                          match quantityText.toInt? with
                          | none =>
                              IO.eprintln "loam: starting quantity must be an integer"
                              return 2
                          | some quanta =>
                              match freshBasisId? bases, freshCorrectionId? corrections with
                              | some replacementId, some correctionId =>
                                  let replacement :=
                                    QuantityBasis.ofQuantity
                                      replacementId target.locus target.measure
                                      (Quantity.ofQuanta quanta)
                                  let correction : QuantityBasisCorrection := {
                                    id := correctionId
                                    target := target.id
                                    replacement := replacement.id
                                  }
                                  match QuantityBasisMemory.add? bases replacement,
                                      QuantityBasisCorrectionMemory.add? corrections correction with
                                  | some updatedBases, some updatedCorrections =>
                                      match Loam.Application.admittedQuantityBasisFrontier?
                                          updatedBases updatedCorrections with
                                      | none =>
                                          IO.eprintln
                                            "loam: generated starting quantity correction did not justify one current frontier"
                                          return 2
                                      | some _ =>
                                          if ← Loam.Persistence.saveQuantityBasisCorrectionMemory?
                                              correctionFile updatedCorrections then
                                            if ← Loam.Persistence.saveQuantityBasisMemory?
                                                basisFile updatedBases then
                                              IO.println
                                                ("Starting quantity corrected: " ++ target.locus.token ++
                                                  " = " ++ toString quanta ++ " " ++ target.measure.token ++ ".")
                                              return 0
                                            else
                                              IO.eprintln
                                                "loam: replacement basis was not published; the correction remains inactive until its referenced basis is present"
                                              return 2
                                          else
                                            IO.eprintln
                                              "loam: quantity-basis correction contains an unrepresentable identity token"
                                            return 2
                                  | _, _ =>
                                      IO.eprintln "loam: could not append starting quantity correction facts"
                                      return 2
                              | _, _ =>
                                  IO.eprintln "loam: could not generate fresh starting quantity correction identities"
                                  return 2

/--
Correct one current basis quantity append-only under basis-file writer ownership.

The relation stream is published before its replacement basis, matching the
existing Event-correction safety pattern: a dangling relation fails admission
instead of selecting a nonexistent replacement. The replacement copies the
selected basis coordinate, so this entrance cannot move a basis between loci or
measures.
-/
def correctStartingJpy
    (basisPath basisCorrectionPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk basisPath)
    (correctStartingJpyUnlocked basisPath basisCorrectionPath)

end Loam.QuantityBasisCorrectionCli
