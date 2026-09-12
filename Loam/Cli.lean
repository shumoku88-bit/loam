import Loam.ActualAuthority
import Loam.Cli.ReviewCli
import Loam.WriterOwnership
import Loam.Cli.EffectiveCli
import Loam.Cli.CorrectionIntegrityCli
import Loam.Cli.ScheduledCli
import Std

namespace Loam.Cli

set_option autoImplicit false

private def practicalUsage : String :=
  "LOAM practical dogfood\n\n" ++
  "Open TUI interface (primary entrance):\n" ++
  "  ./tools/loam\n\n" ++
  "Operational diagnosis:\n" ++
  "  ./tools/loam doctor [LOAM_DATA_DIR]\n\n" ++
  "Scheduled persistence (read-only here; production Scheduled mutation uses loamTui):\n" ++
  "  ./tools/loam scheduled show SCHEDULED_FILE\n\n" ++
  "Review current records (optional YYYY-MM-DD, /text search, or u for undated):\n" ++
  "  ./tools/loam review ACTUAL_FILE [QUERY]\n\n" ++
  "Show recorded quantities:\n" ++
  "  ./tools/loam summary ACTUAL_FILE"

private def addCoordinateIfAbsent
    (coordinates : List Loam.Core.EffectCoordinate)
    (coordinate : Loam.Core.EffectCoordinate) : List Loam.Core.EffectCoordinate :=
  if coordinate ∈ coordinates then coordinates else coordinates ++ [coordinate]

private def recordedCoordinates
    (memory : Loam.Core.EventMemory) : List Loam.Core.EffectCoordinate :=
  memory.events.foldl
    (fun coordinates event =>
      event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        coordinates)
    []

/-- Show recorded quantities without adding correction or balance semantics. -/
def showRecordedQuantitySummary (path : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk path
  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok ev => pure ev
  let memory := evidence.events
  match recordedCoordinates memory with
  | [] =>
      IO.println "No recorded quantities."
      return 0
  | coordinates =>
      IO.println "Recorded quantities (all recorded facts; display order has no time meaning):"
      for coordinate in coordinates do
        let quantity :=
          Loam.Core.EventMemory.quantityAtRecorded
            memory coordinate.locus coordinate.measure
        IO.println
          ("  " ++ coordinate.locus.token ++ ": " ++
            toString quantity.quanta ++ " " ++ coordinate.measure.token)
      return 0

/-- Command dispatcher for the New-only normalized Actual runtime. -/
def run (args : List String) : IO UInt32 := do
  match args with
  | [] => do
      IO.println practicalUsage
      return 0
  | ["help"] => do
      IO.println practicalUsage
      return 0
  | ["scheduled", "show", scheduledPath] =>
      Loam.ScheduledCli.showScheduled scheduledPath
  | ["review", actualPath] => Loam.ReviewCli.review actualPath ""
  | ["review", actualPath, query] =>
      Loam.ReviewCli.review actualPath "" (some query)
  | ["summary", actualPath] => showRecordedQuantitySummary actualPath
  | ["effective", actualPath] =>
      Loam.EffectiveCli.showEffectiveQuantities actualPath
  | ["correction-integrity", actualPath] =>
      Loam.CorrectionIntegrityCli.showCorrectionIntegrity actualPath
  | _ => do
      IO.eprintln "loam: command not understood"
      IO.eprintln practicalUsage
      return 2

end Loam.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.run args
