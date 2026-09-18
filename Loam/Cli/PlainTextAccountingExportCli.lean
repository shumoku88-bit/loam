import Loam.ActualAuthority
import Loam.ActualJournalProjection
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.SiblingStage
import Loam.PlainTextAccountingExport
import Loam.WriterOwnership

namespace Loam.PlainTextAccountingExportCli

set_option autoImplicit false

private def conflictsWithSource
    (actualPath rolePath outputPath : String) : Bool :=
  outputPath == actualPath || outputPath == rolePath

/--
Regenerate one hledger/Ledger-compatible accounting journal from current LOAM
Actual evidence plus explicit AccountingRole evidence.
-/
def export
    (actualPath rolePath outputPath : String) : IO UInt32 := do
  if conflictsWithSource actualPath rolePath outputPath then
    IO.eprintln "loam: PTA output must not replace Actual or AccountingRole authority"
    return 2

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
  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? roleFile with
    | some roles => pure roles
    | none =>
        IO.eprintln "loam: AccountingRole authority is malformed or unsupported"
        return 2

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok entries => pure entries

  match Loam.PlainTextAccountingExport.render? roles entries with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok rendered =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile rendered
      IO.println ("Regenerated Plain Text Accounting journal: " ++ outputPath)
      return 0

end Loam.PlainTextAccountingExportCli

private def usage : String :=
  "Usage: loamPtaExport ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE"

def main (args : List String) : IO UInt32 :=
  match args with
  | [actualPath, rolePath, outputPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (Loam.PlainTextAccountingExportCli.export actualPath rolePath outputPath)
  | _ => do
      IO.eprintln usage
      return 2
