import Loam.ActualAuthority
import Loam.ActualJournalProjection
import Loam.BeancountExport
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.SiblingStage
import Loam.WriterOwnership

namespace Loam.BeancountExportCli

set_option autoImplicit false

private def pathsConflict (pathA pathB : System.FilePath) : IO Bool := do
  if pathA == pathB then
    return true
  if (← pathA.pathExists) && (← pathB.pathExists) then
    let resA ← IO.FS.realPath pathA
    let resB ← IO.FS.realPath pathB
    return resA == resB
  return false

private def conflictsWithSource
    (actualPath rolePath targetPath : System.FilePath) : IO Bool := do
  if targetPath == actualPath || targetPath == rolePath then
    return true
  if !(← targetPath.pathExists) then
    return false
  let actualResolved ← IO.FS.realPath actualPath
  let roleResolved ← IO.FS.realPath rolePath
  let targetResolved ← IO.FS.realPath targetPath
  return targetResolved == actualResolved || targetResolved == roleResolved

/--
Regenerate one disposable Beancount view from current LOAM Actual evidence plus
explicit AccountingRole evidence.
-/
def exportBeancount
    (actualPath rolePath outputPath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let roleFile := System.FilePath.mk rolePath
  let outputFile := System.FilePath.mk outputPath

  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok image => pure image

  if !(← roleFile.pathExists) then
    IO.eprintln "loam: AccountingRole authority file is missing"
    return 2

  if ← conflictsWithSource actualFile roleFile outputFile then
    IO.eprintln
      "loam: Beancount output must not replace Actual or AccountingRole authority"
    return 2

  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? roleFile with
    | some roles => pure roles
    | none =>
        IO.eprintln
          "loam: AccountingRole authority is malformed or unsupported"
        return 2

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok entries => pure entries

  match Loam.BeancountExport.render? roles entries with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok rendered =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile rendered
      IO.println ("Regenerated disposable Beancount view: " ++ outputPath)
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

  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualFile with
    | .error message =>
        IO.eprintln message
        return 2
    | .ok image => pure image

  if !(← roleFile.pathExists) then
    IO.eprintln "loam: AccountingRole authority file is missing"
    return 2

  if (← conflictsWithSource actualFile roleFile outputFile) ||
     (← conflictsWithSource actualFile roleFile reportFile) ||
     (← pathsConflict outputFile reportFile) then
    IO.eprintln
      "loam: Beancount output and report must not replace Actual or AccountingRole authority, or conflict with each other"
    return 2

  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? roleFile with
    | some roles => pure roles
    | none =>
        IO.eprintln
          "loam: AccountingRole authority is malformed or unsupported"
        return 2

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok entries => pure entries

  match Loam.BeancountExport.renderPartial? roles entries with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok res =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile res.beancount
      Loam.Persistence.replaceTextViaSiblingStage reportFile res.report
      IO.println (s!"Regenerated disposable partial Beancount view ({res.exportedCount} exported, {res.skippedCount} skipped): " ++ outputPath)
      IO.println ("Generated partial export report: " ++ reportPath)
      return 0

end Loam.BeancountExportCli

private def usage : String :=
  "Usage:\n" ++
  "  loamBeancountExport ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE\n" ++
  "  loamBeancountExport --partial ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE REPORT_FILE"

def main (args : List String) : IO UInt32 :=
  match args with
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
