import Loam.ActualAuthority
import Loam.BalanceViewConfig
import Loam.Persistence.ZeroOriginCoveragePersistence
import Std

namespace Loam.DailyQuantityCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "LOAM daily quantity\n\n" ++
  "Show balances from explicit zero-origin coverage:\n" ++
  "  loam balances <actual-file> <zero-origin-coverage> [balance-view]\n\n" ++
  "Show all nonzero current quantities admitted by zero-origin coverage:\n" ++
  "  loam current <actual-file> <zero-origin-coverage>\n\n" ++
  "Starting-quantity writers are retired. Zero-origin coverage is changed only by explicit reconstruction/cutover."

private def loadImageForView?
    (path : System.FilePath) : IO (Except String Loam.ActualAuthority.Image) :=
  if path.fileName == some Loam.ActualAuthority.actualFileName then
    Loam.ActualAuthority.loadImageFile? path
  else
    Loam.ActualAuthority.loadImage? path

private def loadCoverageForView?
    (path : System.FilePath) : IO (Option ZeroOriginCoverage) := do
  if ← path.pathExists then
    Loam.Persistence.loadZeroOriginCoverage? path
  else
    return some ZeroOriginCoverage.empty

private def quantityLine (coordinate : EffectCoordinate) (quantity : Quantity) : String :=
  "  " ++ coordinate.locus.token ++ ": " ++
    toString quantity.quanta ++ " " ++ coordinate.measure.token

private inductive CollectionResult where
  | lines (value : List String)
  | coverageMissing (coordinate : EffectCoordinate)

private def collectCurrentLines
    (basis : EventMemory)
    (coverage : ZeroOriginCoverage)
    (includeZero : Bool) :
    List EffectCoordinate → CollectionResult
  | [] => .lines []
  | coordinate :: rest =>
      if coverage.covers coordinate then
        let quantity :=
          EventMemory.quantityAtRecorded basis coordinate.locus coordinate.measure
        match collectCurrentLines basis coverage includeZero rest with
        | .lines later =>
            if quantity.quanta = 0 then
              if includeZero then
                .lines (quantityLine coordinate quantity :: later)
              else
                .lines later
            else
              .lines (quantityLine coordinate quantity :: later)
        | other => other
      else
        .coverageMissing coordinate

private def reportCollectionFailure
    (contextLabel : String) : CollectionResult → IO UInt32
  | .lines _ => pure 0
  | .coverageMissing coordinate => do
      IO.eprintln
        ("loam: " ++ contextLabel ++ " unavailable: zero-origin coverage missing for " ++
          coordinate.locus.token ++ " / " ++ coordinate.measure.token)
      pure 1

/-- Show all nonzero current quantities whose retained history is explicitly complete from zero. -/
def showCurrentQuantities
    (actualPath coveragePath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let coverageFile := System.FilePath.mk coveragePath
  match ← loadImageForView? actualFile with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok image =>
      match ← loadCoverageForView? coverageFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported zero-origin coverage file"
          return 2
      | some coverage =>
          let coordinates := coverage.coordinates
          match collectCurrentLines image.currentEvents coverage false coordinates with
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
    (actualPath coveragePath : String)
    (balanceViewPath? : Option String := none) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let coverageFile := System.FilePath.mk coveragePath
  match ← loadImageForView? actualFile with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok image =>
      match ← loadCoverageForView? coverageFile with
          | none =>
              IO.eprintln "loam: malformed or unsupported zero-origin coverage file"
              return 2
          | some coverage =>
              let coordinates? ←
                match balanceViewPath? with
                | none => pure (some coverage.coordinates)
                | some pathText =>
                    match ← Loam.BalanceViewConfig.load? (System.FilePath.mk pathText) with
                    | none => pure none
                    | some selected => pure (some selected.eraseDups)
              match coordinates? with
              | none =>
                  IO.eprintln "loam: malformed or unsupported balance-view config"
                  return 2
              | some coordinates =>
                  match collectCurrentLines image.currentEvents coverage true coordinates with
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
def run (args : List String) : IO UInt32 := do
  match args with
  | ["balances", actualPath, coveragePath] =>
      showBalances actualPath coveragePath
  | ["balances", actualPath, coveragePath, balanceViewPath] =>
      showBalances actualPath coveragePath (some balanceViewPath)
  | ["current", actualPath, coveragePath] =>
      showCurrentQuantities actualPath coveragePath
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
