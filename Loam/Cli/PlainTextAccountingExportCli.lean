import Loam.ActualAuthority
import Loam.ActualJournalProjection
import Loam.MeasurePresentation
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.SiblingStage
import Loam.PlainTextAccountingExport
import Loam.WriterOwnership

namespace Loam.PlainTextAccountingExportCli

set_option autoImplicit false

private def pathsConflict (pathA pathB : System.FilePath) : IO Bool := do
  if pathA == pathB then
    return true
  if (← pathA.pathExists) && (← pathB.pathExists) then
    let resA ← IO.FS.realPath pathA
    let resB ← IO.FS.realPath pathB
    return resA == resB
  return false

/--
Return true when an existing output path resolves to either input authority.

Comparing the raw CLI strings is insufficient: `actual.loam`,
`./actual.loam`, `dir/../actual.loam`, and a symbolic link may all name the
same file. `IO.FS.realPath` resolves those aliases before the one-way export is
allowed to replace its target.

A non-existing output cannot already be either existing input authority, so it
needs no identity comparison.
-/
private def conflictsWithSource
    (actualPath rolePath outputPath : System.FilePath) : IO Bool := do
  if !(← outputPath.pathExists) then
    return false
  let actualResolved ← IO.FS.realPath actualPath
  let roleResolved ← IO.FS.realPath rolePath
  let outputResolved ← IO.FS.realPath outputPath
  return outputResolved == actualResolved || outputResolved == roleResolved

/--
Regenerate one hledger/Ledger-compatible accounting journal from current LOAM
Actual evidence plus explicit AccountingRole evidence.
-/
def exportJournal
    (actualPath rolePath outputPath : String) : IO UInt32 := do
  let actualFile := System.FilePath.mk actualPath
  let roleFile := System.FilePath.mk rolePath
  let outputFile := System.FilePath.mk outputPath
  let presentationFile := Loam.MeasurePresentation.configPathForActualFile actualFile

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
     (← pathsConflict presentationFile outputFile) then
    IO.eprintln
      "loam: PTA output must not replace Actual, AccountingRole, or Measure presentation input"
    return 2

  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? roleFile with
    | some roles => pure roles
    | none =>
        IO.eprintln "loam: AccountingRole authority is malformed or unsupported"
        return 2

  let presentation ←
    match ← Loam.MeasurePresentation.loadForActualFile actualFile with
    | .ok metadata => pure metadata
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok entries => pure entries

  match Loam.PlainTextAccountingExport.renderWithPresentation? presentation roles entries with
  | .error message =>
      IO.eprintln ("loam: " ++ message)
      return 2
  | .ok rendered =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile rendered
      IO.println ("Regenerated Plain Text Accounting journal: " ++ outputPath)
      return 0

private def usage : String :=
  "Usage: loam export pta ACTUAL_FILE ACCOUNTING_ROLE_FILE OUTPUT_FILE"

/-- Command dispatcher for regenerating a Plain Text Accounting journal. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [actualPath, rolePath, outputPath] =>
      Loam.WriterOwnership.withOwnership
        (System.FilePath.mk actualPath)
        (exportJournal actualPath rolePath outputPath)
  | _ => do
      IO.eprintln usage
      return 2

end Loam.PlainTextAccountingExportCli
