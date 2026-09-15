import Loam.ActualAuthority
import Loam.Cli.CurrentQuantityAnchorCli
import Loam.Cli.ReviewCli
import Loam.WriterOwnership
import Loam.Cli.EffectiveCli
import Loam.Cli.CorrectionIntegrityCli
import Loam.Cli.ScheduledCli
import Loam.RoleBalanceReview
import Loam.Tui.Kernel
import Loam.Tui.RoleBalances
import Std

namespace Loam.Cli

set_option autoImplicit false

private def practicalUsage : String :=
  "LOAM practical dogfood\n\n" ++
  "Open TUI interface (primary entrance):\n" ++
  "  ./tools/loam\n\n" ++
  "Operational diagnosis:\n" ++
  "  ./tools/loam doctor [LOAM_DATA_DIR]\n\n" ++
  "Print the evidence-aware Balances report as plain text:\n" ++
  "  ./tools/loam report balances [LOAM_DATA_DIR]\n\n" ++
  "Publish one complete current quantity observation image:\n" ++
  "  ./tools/loam current-quantity-anchor LOCUS MEASURE QUANTITY [LOCUS MEASURE QUANTITY ...]\n\n" ++
  "Scheduled persistence (read-only here; production Scheduled mutation uses loamTui):\n" ++
  "  ./tools/loam scheduled show SCHEDULED_FILE\n\n" ++
  "Review current records (optional YYYY-MM-DD, /text search, or u for undated):\n" ++
  "  ./tools/loam review ACTUAL_FILE [QUERY]\n\n" ++
  "Show recorded quantities:\n" ++
  "  ./tools/loam summary ACTUAL_FILE"

private def recordedCoordinates
    (memory : Loam.Core.EventMemory) : List Loam.Core.EffectCoordinate :=
  (memory.events.flatMap fun event =>
    event.effects.map fun effect => effect.coordinate).eraseDups

private def resolveReportDataDir
    (path? : Option String) : IO (Except String System.FilePath) := do
  match path? with
  | some path =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")

private def widgetText (widget : Loam.Tui.Kernel.Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map fun cell => cell.glyph)

private def roleBalanceReportText
    (snapshot : Loam.RoleBalanceReview.Snapshot) : String :=
  String.intercalate "\n"
    [ "Reports / Balances"
    , "Current evidence-aware accounting projections from shared RoleBalance."
    , "Balance Sheet / Net Worth / Trial Balance are presentations, not separate engines."
    , ""
    , widgetText (.column (Loam.Tui.RoleBalances.lines snapshot))
    ]

/-- Print the same evidence-aware Balances presentation without TUI paging. -/
def showRoleBalanceReport (path? : Option String := none) : IO UInt32 := do
  let dataDir ←
    match ← resolveReportDataDir path? with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok path => pure path
  match ← Loam.RoleBalanceReview.loadSnapshot dataDir dataDir with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok snapshot =>
      IO.println (roleBalanceReportText snapshot)
      return 0

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
  | ["report", "balances"] => showRoleBalanceReport
  | ["report", "balances", dataDir] => showRoleBalanceReport (some dataDir)
  | "current-quantity-anchor" :: observationArgs =>
      Loam.CurrentQuantityAnchorCli.run observationArgs
  | ["scheduled", "show", scheduledPath] =>
      Loam.ScheduledCli.showScheduled scheduledPath
  | ["review", actualPath] => Loam.ReviewCli.review actualPath
  | ["review", actualPath, query] =>
      Loam.ReviewCli.review actualPath (some query)
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
