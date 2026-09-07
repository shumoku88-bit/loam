import Loam.Application.ZeroOriginQuantity
import Loam.BalanceViewConfig
import Loam.MovementManifestAuthority
import Loam.Persistence.ZeroOriginCoveragePersistence
import Std

namespace Loam.DailyQuantityCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "LOAM daily quantity\n\n" ++
  "Show balances from explicit zero-origin coverage:\n" ++
  "  ./tools/loam balances <event-memory> <event-correction-memory> <zero-origin-coverage> [balance-view]\n\n" ++
  "Show all nonzero current quantities admitted by zero-origin coverage:\n" ++
  "  ./tools/loam current <event-memory> <event-correction-memory> <zero-origin-coverage>\n\n" ++
  "Starting-quantity writers are retired. Zero-origin coverage is changed only by explicit reconstruction/cutover."

private def loadEventMemoryForView?
    (path : System.FilePath) : IO (Except String EventMemory) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? (System.FilePath.mk rootPath) with
      | .error message => return .error message
      | .ok world => return .ok world.events
  | none =>
      let memory ← if ← path.pathExists then
          Loam.Persistence.loadEventMemory? path
        else
          pure (EventMemory.ofEvents? [])
      match memory with
      | none => return .error "loam: malformed or unsupported event-memory file"
      | some events => return .ok events

private def loadEventCorrectionMemoryForView?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return EventCorrectionMemory.ofCorrections? []

private def loadCoverageForView?
    (path : System.FilePath) : IO (Option ZeroOriginCoverage) := do
  if ← path.pathExists then
    Loam.Persistence.loadZeroOriginCoverage? path
  else
    return none

private def addCoordinateIfAbsent
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) : List EffectCoordinate :=
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def normalizeCoordinates
    (coordinates : List EffectCoordinate) : List EffectCoordinate :=
  coordinates.foldl addCoordinateIfAbsent []

private def quantityLine (coordinate : EffectCoordinate) (quantity : Quantity) : String :=
  "  " ++ coordinate.locus.token ++ ": " ++
    toString quantity.quanta ++ " " ++ coordinate.measure.token

private inductive CollectionResult where
  | lines (value : List String)
  | coverageMissing (coordinate : EffectCoordinate)
  | missingEventCorrectionEndpoint
  | eventFrontierRequired

private def collectCurrentLines
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coverage : ZeroOriginCoverage)
    (includeZero : Bool) :
    List EffectCoordinate → CollectionResult
  | [] => .lines []
  | coordinate :: rest =>
      match Loam.Application.inspectZeroOriginQuantity
          coverage events eventCorrections coordinate with
      | .current quantity =>
          match collectCurrentLines events eventCorrections coverage includeZero rest with
          | .lines later =>
              if quantity.quanta = 0 then
                if includeZero then
                  .lines (quantityLine coordinate quantity :: later)
                else
                  .lines later
              else
                .lines (quantityLine coordinate quantity :: later)
          | other => other
      | .coverageMissing => .coverageMissing coordinate
      | .missingEventCorrectionEndpoint => .missingEventCorrectionEndpoint
      | .eventFrontierRequired => .eventFrontierRequired

private def reportCollectionFailure (prefix : String) : CollectionResult → IO UInt32
  | .lines _ => pure 0
  | .coverageMissing coordinate => do
      IO.eprintln
        ("loam: " ++ prefix ++ " unavailable: zero-origin coverage missing for " ++
          coordinate.locus.token ++ " / " ++ coordinate.measure.token)
      pure 1
  | .missingEventCorrectionEndpoint => do
      IO.eprintln ("loam: " ++ prefix ++ " unavailable: correction references are not closed")
      pure 1
  | .eventFrontierRequired => do
      IO.eprintln
        ("loam: " ++ prefix ++ " unavailable: event corrections do not justify one frontier")
      pure 1

/-- Show all nonzero current quantities whose retained history is explicitly complete from zero. -/
def showCurrentQuantities
    (memoryPath eventCorrectionPath coveragePath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let eventCorrectionFile := System.FilePath.mk eventCorrectionPath
  let coverageFile := System.FilePath.mk coveragePath
  match ← loadEventMemoryForView? memoryFile with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok events =>
      match ← loadEventCorrectionMemoryForView? eventCorrectionFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported correction-memory file"
          return 2
      | some eventCorrections =>
          match ← loadCoverageForView? coverageFile with
          | none =>
              IO.eprintln "loam: missing, malformed or unsupported zero-origin coverage file"
              return 2
          | some coverage =>
              let coordinates := coverage.coordinates
              match collectCurrentLines events eventCorrections coverage false coordinates with
              | .lines lines =>
                  if coordinates.isEmpty then
                    IO.println "No current quantities are covered from zero."
                  else
                    IO.println
                      "Current quantities (explicit zero-origin coverage + effective recorded changes; zero coordinates omitted):"
                    for line in lines do IO.println line
                  return 0
              | failure => reportCollectionFailure "current quantity" failure

/--
Show an application-facing balance view. Without an explicit view path, every
zero-origin-covered coordinate is selected. With a view path, presentation
selection remains independent and cannot create coverage.
-/
def showBalances
    (memoryPath eventCorrectionPath coveragePath : String)
    (balanceViewPath? : Option String := none) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let eventCorrectionFile := System.FilePath.mk eventCorrectionPath
  let coverageFile := System.FilePath.mk coveragePath
  match ← loadEventMemoryForView? memoryFile with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok events =>
      match ← loadEventCorrectionMemoryForView? eventCorrectionFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported correction-memory file"
          return 2
      | some eventCorrections =>
          match ← loadCoverageForView? coverageFile with
          | none =>
              IO.eprintln "loam: missing, malformed or unsupported zero-origin coverage file"
              return 2
          | some coverage =>
              let coordinates? ←
                match balanceViewPath? with
                | none => pure (some coverage.coordinates)
                | some pathText =>
                    match ← Loam.BalanceViewConfig.load? (System.FilePath.mk pathText) with
                    | none => pure none
                    | some selected => pure (some (normalizeCoordinates selected))
              match coordinates? with
              | none =>
                  IO.eprintln "loam: malformed or unsupported balance-view config"
                  return 2
              | some coordinates =>
                  match collectCurrentLines events eventCorrections coverage true coordinates with
                  | .lines lines =>
                      if coordinates.isEmpty then
                        match balanceViewPath? with
                        | none => IO.println "No zero-origin balance coordinates are covered."
                        | some _ => IO.println "No balances are selected in the current balance view."
                      else
                        IO.println "Balances (zero-origin coverage + effective recorded changes):"
                        for line in lines do IO.println line
                      return 0
                  | failure => reportCollectionFailure "balances" failure

/-- Dispatcher for the narrow daily quantity executable behind `tools/loam`. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | ["balances", memoryPath, eventCorrectionPath, coveragePath] =>
      showBalances memoryPath eventCorrectionPath coveragePath
  | ["balances", memoryPath, eventCorrectionPath, coveragePath, balanceViewPath] =>
      showBalances memoryPath eventCorrectionPath coveragePath (some balanceViewPath)
  | ["current", memoryPath, eventCorrectionPath, coveragePath] =>
      showCurrentQuantities memoryPath eventCorrectionPath coveragePath
  | "starting-quantity" :: _ => do
      IO.eprintln
        "loam: starting-quantity is retired; zero-origin coverage is explicit reconstruction/cutover evidence"
      return 2
  | "correct-starting-quantity" :: _ => do
      IO.eprintln
        "loam: correct-starting-quantity is retired with QuantityBasis production support"
      return 2
  | _ => do
      IO.eprintln "loam: daily quantity command not understood"
      IO.eprintln usage
      return 2

end Loam.DailyQuantityCli

def main (args : List String) : IO UInt32 :=
  Loam.DailyQuantityCli.run args
