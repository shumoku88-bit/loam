import Loam.Export.WealthfolioExportPipeline
import Loam.HouseholdPaths
import Loam.Persistence.WriterOwnership

namespace Loam.WealthfolioExportCli

set_option autoImplicit false

private def usage : String :=
  "Usage:\n" ++
  "  loam export wealthfolio DATA_ROOT ACCOUNTING_EPOCH OUTPUT_FILE\n\n" ++
  "ACCOUNTING_EPOCH must be YYYY-MM-DD. The CSV is a disposable Asset/cash projection."

/-- Regenerate one disposable Wealthfolio cash CSV from a canonical household root. -/
def exportWealthfolio
    (rootPath accountingEpoch outputPath : String) : IO UInt32 := do
  if rootPath.isEmpty then
    IO.eprintln "loam: data directory must not be empty"
    return 2
  let root := System.FilePath.mk rootPath
  let outputFile := System.FilePath.mk outputPath
  match ← Loam.WealthfolioExportPipeline.exportCsv root accountingEpoch outputFile with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok () =>
      IO.println ("Regenerated disposable Wealthfolio cash CSV: " ++ outputPath)
      return 0

def run (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, accountingEpoch, outputPath] =>
      let root := System.FilePath.mk rootPath
      Loam.WriterOwnership.withOwnership
        (Loam.HouseholdPaths.actual root)
        (exportWealthfolio rootPath accountingEpoch outputPath)
  | _ => do
      IO.eprintln usage
      return 2

end Loam.WealthfolioExportCli
