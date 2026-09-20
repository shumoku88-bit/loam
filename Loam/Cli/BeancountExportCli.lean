import Loam.ActualAuthority
import Loam.ActualJournalProjection
import Loam.BeancountExport
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.SiblingStage
import Loam.WriterOwnership

namespace Loam.BeancountExportCli

set_option autoImplicit false

private def conflictsWithSource
    (actualPath rolePath outputPath : System.FilePath) : IO Bool := do
  if !(← outputPath.pathExists) then
    return false
  let actualResolved ← IO.FS.realPath actualPath
  let roleResolved ← IO.FS.realPath rolePath
  let outputResolved ← IO.FS.realPath outputPath
  return outputResolved == actualResolved || outputResolved == roleResolved

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

end Loam.BeancountExportCli

private def usage : String :=
  "Usage: loamBeancountExport ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE"

def main (args : List String) : IO UInt32 :=
  match args with
  | [actualPath, rolePath, outputPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (Loam.BeancountExportCli.exportBeancount
          actualPath rolePath outputPath)
  | _ => do
      IO.eprintln usage
      return 2
