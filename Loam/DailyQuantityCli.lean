import Loam.Application.CurrentQuantity
import Loam.QuantityBasisCorrectionCli
import Loam.QuantityBasisCorrectionPersistence
import Loam.QuantityBasisPersistence
import Loam.WriterOwnership
import Std

namespace Loam.DailyQuantityCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "LOAM daily quantity\n\n" ++
  "Set one JPY starting quantity:\n" ++
  "  ./tools/loam starting-quantity <basis-file>\n\n" ++
  "Correct one starting quantity append-only:\n" ++
  "  ./tools/loam correct-starting-quantity <basis-file> <basis-correction-file>\n\n" ++
  "Show tracked balances only:\n" ++
  "  ./tools/loam balances <event-memory> <event-correction-memory> <basis-file> [basis-correction-file]\n\n" ++
  "Show anchored current quantities:\n" ++
  "  ./tools/loam current <event-memory> <event-correction-memory> <basis-file> [basis-correction-file]"

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def loadBasisMemoryForEntry?
    (path : System.FilePath) : IO (Option QuantityBasisMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadQuantityBasisMemory? path
  else
    return QuantityBasisMemory.ofBases? []

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

private def coordinateAlreadyPresent
    (memory : QuantityBasisMemory)
    (coordinate : EffectCoordinate) : Bool :=
  memory.bases.any fun basis => decide (basis.coordinate = coordinate)

private def recordStartingJpyUnlocked (basisPath : String) : IO UInt32 := do
  let basisFile := System.FilePath.mk basisPath
  match ← loadBasisMemoryForEntry? basisFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported quantity-basis file"
      return 2
  | some memory =>
      let locusToken ← promptLine "Starting at? "
      if Loam.Persistence.validToken locusToken then
        let quantityText ← promptLine "Starting quantity? "
        match quantityText.toInt? with
        | none =>
            IO.eprintln "loam: starting quantity must be an integer"
            return 2
        | some quanta =>
            let coordinate : EffectCoordinate := ⟨⟨locusToken⟩, ⟨"jpy"⟩⟩
            if coordinateAlreadyPresent memory coordinate then
              IO.eprintln
                "loam: a starting quantity is already represented for this locus; use correct-starting-quantity"
              return 1
            else
              match freshBasisId? memory with
              | none =>
                  IO.eprintln "loam: could not generate a fresh basis identity"
                  return 2
              | some basisId =>
                  let basis :=
                    QuantityBasis.ofQuantity
                      basisId ⟨locusToken⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)
                  match QuantityBasisMemory.add? memory basis with
                  | none =>
                      IO.eprintln "loam: generated basis identity already remembered"
                      return 2
                  | some updated =>
                      if ← Loam.Persistence.saveQuantityBasisMemory? basisFile updated then
                        IO.println
                          ("Recorded starting quantity: " ++ locusToken ++ " = " ++
                            toString quanta ++ " jpy.")
                        return 0
                      else
                        IO.eprintln "loam: starting quantity contains an unrepresentable identity token"
                        return 2
      else
        IO.eprintln "loam: starting locus must be a nonempty single-line token"
        return 2

/-- Record one explicit JPY quantity basis under basis-file writer ownership. -/
def recordStartingJpy (basisPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk basisPath)
    (recordStartingJpyUnlocked basisPath)

private def loadEventMemoryForView?
    (path : System.FilePath) : IO (Option EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return EventMemory.ofEvents? []

private def loadEventCorrectionMemoryForView?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return EventCorrectionMemory.ofCorrections? []

private def loadBasisMemoryForView?
    (path : System.FilePath) : IO (Option QuantityBasisMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadQuantityBasisMemory? path
  else
    return QuantityBasisMemory.ofBases? []

private def loadBasisCorrectionMemoryForView?
    (path? : Option String) : IO (Option QuantityBasisCorrectionMemory) := do
  match path? with
  | none => return QuantityBasisCorrectionMemory.ofCorrections? []
  | some pathText =>
      let path := System.FilePath.mk pathText
      if ← path.pathExists then
        Loam.Persistence.loadQuantityBasisCorrectionMemory? path
      else
        return QuantityBasisCorrectionMemory.ofCorrections? []

private def addCoordinateIfAbsent
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) : List EffectCoordinate :=
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def basisCoordinatesFrom (bases : List QuantityBasis) : List EffectCoordinate :=
  bases.foldl
    (fun coordinates basis => addCoordinateIfAbsent coordinates basis.coordinate)
    []

private def basisCoordinates (memory : QuantityBasisMemory) : List EffectCoordinate :=
  basisCoordinatesFrom memory.bases

private def eventCoordinates
    (memory : EventMemory)
    (start : List EffectCoordinate) : List EffectCoordinate :=
  memory.events.foldl
    (fun coordinates event =>
      event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        coordinates)
    start

private def quantityLine (coordinate : EffectCoordinate) (quantity : Quantity) : String :=
  "  " ++ coordinate.locus.token ++ ": " ++
    toString quantity.quanta ++ " " ++ coordinate.measure.token

private inductive CollectionResult where
  | lines (value : List String)
  | basisMissing (coordinate : EffectCoordinate)
  | basisFrontierRequired
  | missingEventCorrectionEndpoint
  | eventFrontierRequired

private def collectCurrentLines
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (includeZero : Bool) :
    List EffectCoordinate → CollectionResult
  | [] => .lines []
  | coordinate :: rest =>
      match Loam.Application.inspectCurrentQuantityWithBasisCorrections
          events eventCorrections bases basisCorrections coordinate.locus coordinate.measure with
      | .current quantity =>
          match collectCurrentLines
              events eventCorrections bases basisCorrections includeZero rest with
          | .lines later =>
              if quantity.quanta = 0 then
                if includeZero then
                  .lines (quantityLine coordinate quantity :: later)
                else
                  .lines later
              else
                .lines (quantityLine coordinate quantity :: later)
          | other => other
      | .basisMissing => .basisMissing coordinate
      | .basisFrontierRequired => .basisFrontierRequired
      | .missingEventCorrectionEndpoint => .missingEventCorrectionEndpoint
      | .eventFrontierRequired => .eventFrontierRequired

/--
Show quantities anchored by an admitted starting-basis frontier and adjusted by
the existing correction-aware Event projection. No row is printed until the
whole view is admitted, so a broken relation cannot produce a partial current
view.
-/
def showCurrentQuantities
    (memoryPath eventCorrectionPath basisPath : String)
    (basisCorrectionPath? : Option String := none) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let eventCorrectionFile := System.FilePath.mk eventCorrectionPath
  let basisFile := System.FilePath.mk basisPath
  match ← loadEventMemoryForView? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some events =>
      match ← loadEventCorrectionMemoryForView? eventCorrectionFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported correction-memory file"
          return 2
      | some eventCorrections =>
          match ← loadBasisMemoryForView? basisFile with
          | none =>
              IO.eprintln "loam: malformed or unsupported quantity-basis file"
              return 2
          | some bases =>
              match ← loadBasisCorrectionMemoryForView? basisCorrectionPath? with
              | none =>
                  IO.eprintln "loam: malformed or unsupported quantity-basis correction file"
                  return 2
              | some basisCorrections =>
                  let coordinates := eventCoordinates events (basisCoordinates bases)
                  match collectCurrentLines
                      events eventCorrections bases basisCorrections false coordinates with
                  | .lines lines =>
                      if coordinates.isEmpty then
                        IO.println "No anchored current quantities."
                      else
                        IO.println
                          "Current quantities (starting-basis frontier + effective recorded changes; zero coordinates omitted):"
                        for line in lines do IO.println line
                      return 0
                  | .basisMissing coordinate =>
                      IO.eprintln
                        ("loam: current quantity unavailable: starting quantity missing for " ++
                          coordinate.locus.token ++ " / " ++ coordinate.measure.token)
                      return 1
                  | .basisFrontierRequired =>
                      IO.eprintln
                        "loam: current quantity unavailable: starting-quantity revisions do not justify one frontier"
                      return 1
                  | .missingEventCorrectionEndpoint =>
                      IO.eprintln "loam: current quantity unavailable: correction references are not closed"
                      return 1
                  | .eventFrontierRequired =>
                      IO.eprintln
                        "loam: current quantity unavailable: event corrections do not justify one frontier"
                      return 1

/--
Show only coordinates retained by the admitted starting-basis frontier. This is
an application-facing balance view: a use locus that appears only in Events is
not silently promoted into a tracked balance, while an explicitly anchored zero
balance remains visible.
-/
def showBalances
    (memoryPath eventCorrectionPath basisPath : String)
    (basisCorrectionPath? : Option String := none) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let eventCorrectionFile := System.FilePath.mk eventCorrectionPath
  let basisFile := System.FilePath.mk basisPath
  match ← loadEventMemoryForView? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some events =>
      match ← loadEventCorrectionMemoryForView? eventCorrectionFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported correction-memory file"
          return 2
      | some eventCorrections =>
          match ← loadBasisMemoryForView? basisFile with
          | none =>
              IO.eprintln "loam: malformed or unsupported quantity-basis file"
              return 2
          | some bases =>
              match ← loadBasisCorrectionMemoryForView? basisCorrectionPath? with
              | none =>
                  IO.eprintln "loam: malformed or unsupported quantity-basis correction file"
                  return 2
              | some basisCorrections =>
                  match Loam.Application.admittedQuantityBasisFrontier? bases basisCorrections with
                  | none =>
                      IO.eprintln
                        "loam: balances unavailable: starting-balance revisions do not justify one frontier"
                      return 1
                  | some frontier =>
                      let coordinates := basisCoordinatesFrom frontier
                      match collectCurrentLines
                          events eventCorrections bases basisCorrections true coordinates with
                      | .lines lines =>
                          if coordinates.isEmpty then
                            IO.println
                              "No balances are being tracked. Set a starting balance before recording changes you want included."
                          else
                            IO.println "Balances (starting balance + effective recorded changes):"
                            for line in lines do IO.println line
                          return 0
                      | .basisMissing coordinate =>
                          IO.eprintln
                            ("loam: balances unavailable: starting balance missing for " ++
                              coordinate.locus.token ++ " / " ++ coordinate.measure.token)
                          return 1
                      | .basisFrontierRequired =>
                          IO.eprintln
                            "loam: balances unavailable: starting-balance revisions do not justify one frontier"
                          return 1
                      | .missingEventCorrectionEndpoint =>
                          IO.eprintln "loam: balances unavailable: correction references are not closed"
                          return 1
                      | .eventFrontierRequired =>
                          IO.eprintln
                            "loam: balances unavailable: event corrections do not justify one frontier"
                          return 1

/-- Dispatcher for the narrow daily quantity executable behind `tools/loam`. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["starting-quantity", basisPath] => recordStartingJpy basisPath
  | ["correct-starting-quantity", basisPath, basisCorrectionPath] =>
      Loam.QuantityBasisCorrectionCli.correctStartingJpy basisPath basisCorrectionPath
  | ["balances", memoryPath, eventCorrectionPath, basisPath] =>
      showBalances memoryPath eventCorrectionPath basisPath
  | ["balances", memoryPath, eventCorrectionPath, basisPath, basisCorrectionPath] =>
      showBalances memoryPath eventCorrectionPath basisPath (some basisCorrectionPath)
  | ["current", memoryPath, eventCorrectionPath, basisPath] =>
      showCurrentQuantities memoryPath eventCorrectionPath basisPath
  | ["current", memoryPath, eventCorrectionPath, basisPath, basisCorrectionPath] =>
      showCurrentQuantities memoryPath eventCorrectionPath basisPath (some basisCorrectionPath)
  | _ => do
      IO.eprintln "loam: daily quantity command not understood"
      IO.eprintln usage
      return 2

end Loam.DailyQuantityCli

def main (args : List String) : IO UInt32 :=
  Loam.DailyQuantityCli.run args
