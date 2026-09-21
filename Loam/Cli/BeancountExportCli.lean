import Loam.BeancountExportPipeline
import Loam.WriterOwnership

namespace Loam.BeancountExportCli

set_option autoImplicit false

/--
Regenerate one disposable Beancount view from current LOAM Actual evidence plus
explicit AccountingRole evidence.
-/
def exportBeancount
    (actualPath rolePath outputPath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let roleFile := System.FilePath.mk rolePath
  let outputFile := System.FilePath.mk outputPath
  match ← Loam.BeancountExportPipeline.exportStrict actualFile roleFile outputFile with
  | .error message =>
      IO.eprintln s!"loam: {message}"
      return 2
  | .ok () =>
      IO.println s!"Regenerated disposable Beancount view: {outputPath}"
      return 0

/--
Regenerate one disposable partial Beancount view and human-readable report
from current LOAM Actual evidence plus explicit AccountingRole evidence.
-/
def exportPartialBeancount
    (actualPath rolePath outputPath reportPath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let roleFile := System.FilePath.mk rolePath
  let outputFile := System.FilePath.mk outputPath
  let reportFile := System.FilePath.mk reportPath
  match ← Loam.BeancountExportPipeline.exportPartial actualFile roleFile outputFile reportFile with
  | .error message =>
      IO.eprintln s!"loam: {message}"
      return 2
  | .ok res =>
      IO.println s!"Regenerated disposable partial Beancount view ({res.exportedCount} exported, {res.skippedCount} skipped): {outputPath}"
      IO.println s!"Generated partial export report: {reportPath}"
      return 0

/--
Regenerate one disposable suspense Beancount view and human-readable report
from current LOAM Actual evidence plus explicit AccountingRole evidence.
-/
def exportSuspenseBeancount
    (actualPath rolePath outputPath reportPath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let roleFile := System.FilePath.mk rolePath
  let outputFile := System.FilePath.mk outputPath
  let reportFile := System.FilePath.mk reportPath
  match ← Loam.BeancountExportPipeline.exportSuspense actualFile roleFile outputFile reportFile with
  | .error message =>
      IO.eprintln s!"loam: {message}"
      return 2
  | .ok res =>
      IO.println s!"Regenerated disposable suspense Beancount view ({res.exportedCount} exported, {res.unresolvedEffectCount} suspense effects): {outputPath}"
      IO.println s!"Generated suspense export report: {reportPath}"
      return 0

end Loam.BeancountExportCli

private def usage : String :=
  "Usage:\n" ++
  "  loamBeancountExport ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE\n" ++
  "  loamBeancountExport --partial ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE REPORT_FILE\n" ++
  "  loamBeancountExport --suspense ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE REPORT_FILE"

def main (args : List String) : IO UInt32 :=
  match args with
  | ["--suspense", actualPath, rolePath, outputPath, reportPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (Loam.BeancountExportCli.exportSuspenseBeancount
          actualPath rolePath outputPath reportPath)
  | ["--partial", actualPath, rolePath, outputPath, reportPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (Loam.BeancountExportCli.exportPartialBeancount
          actualPath rolePath outputPath reportPath)
  | [actualPath, rolePath, outputPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (Loam.BeancountExportCli.exportBeancount
          actualPath rolePath outputPath)
  | _ => do
      IO.eprintln usage
      return 2
