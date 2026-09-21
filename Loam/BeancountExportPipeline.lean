import Loam.ActualAuthority
import Loam.ActualJournalProjection
import Loam.BeancountExport
import Loam.Core.AccountingRole
import Loam.MeasurePresentation
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.SiblingStage

namespace Loam.BeancountExportPipeline

set_option autoImplicit false

def pathsConflict (pathA pathB : System.FilePath) : IO Bool := do
  if pathA == pathB then
    return true
  if (← pathA.pathExists) && (← pathB.pathExists) then
    let resA ← IO.FS.realPath pathA
    let resB ← IO.FS.realPath pathB
    return resA == resB
  return false

def conflictsWithSource
    (actualPath rolePath targetPath : System.FilePath) : IO Bool := do
  if targetPath == actualPath || targetPath == rolePath then
    return true
  if !(← targetPath.pathExists) then
    return false
  let actualResolved ← IO.FS.realPath actualPath
  let roleResolved ← IO.FS.realPath rolePath
  let targetResolved ← IO.FS.realPath targetPath
  return targetResolved == actualResolved || targetResolved == roleResolved

structure LoadedInputs where
  presentation : List Loam.MeasurePresentation.Metadata
  roles : Loam.Core.AccountingRoleMap
  entries : List Loam.ActualJournalProjection.Entry

def loadInputs
    (actualFile roleFile : System.FilePath) : IO (Except String LoadedInputs) := do
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualFile with
    | .error message => return .error message
    | .ok image => pure image

  if !(← roleFile.pathExists) then
    return .error "AccountingRole authority file is missing"

  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? roleFile with
    | some roles => pure roles
    | none => return .error "AccountingRole authority is malformed or unsupported"

  let presentation ←
    match ← Loam.MeasurePresentation.loadForActualFile actualFile with
    | .ok metadata => pure metadata
    | .error message => return .error message

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .error message => return .error message
    | .ok entries => pure entries

  return .ok { presentation, roles, entries }

/--
Regenerate one disposable suspense Beancount view and human-readable report
from current LOAM Actual evidence plus explicit AccountingRole evidence.
Guards against overwriting canonical household sources.
-/
def exportSuspense
    (actualFile roleFile outputFile reportFile : System.FilePath) :
    IO (Except String Loam.BeancountExport.SuspenseExportResult) := do
  let presentationFile := Loam.MeasurePresentation.configPathForActualFile actualFile
  if (← conflictsWithSource actualFile roleFile outputFile) ||
     (← conflictsWithSource actualFile roleFile reportFile) ||
     (← pathsConflict presentationFile outputFile) ||
     (← pathsConflict presentationFile reportFile) ||
     (← pathsConflict outputFile reportFile) then
    return .error "Beancount output and report must not replace Actual, AccountingRole, or Measure presentation input, or conflict with each other"

  let inputs ←
    match ← loadInputs actualFile roleFile with
    | .error message => return .error message
    | .ok inputs => pure inputs

  match Loam.BeancountExport.renderSuspenseWithPresentation? inputs.presentation inputs.roles inputs.entries with
  | .error message => return .error message
  | .ok res =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile res.beancount
      Loam.Persistence.replaceTextViaSiblingStage reportFile res.report
      return .ok res

/--
Regenerate one disposable partial Beancount view and human-readable report
from current LOAM Actual evidence plus explicit AccountingRole evidence.
Guards against overwriting canonical household sources.
-/
def exportPartial
    (actualFile roleFile outputFile reportFile : System.FilePath) :
    IO (Except String Loam.BeancountExport.PartialExportResult) := do
  let presentationFile := Loam.MeasurePresentation.configPathForActualFile actualFile
  if (← conflictsWithSource actualFile roleFile outputFile) ||
     (← conflictsWithSource actualFile roleFile reportFile) ||
     (← pathsConflict presentationFile outputFile) ||
     (← pathsConflict presentationFile reportFile) ||
     (← pathsConflict outputFile reportFile) then
    return .error "Beancount output and report must not replace Actual, AccountingRole, or Measure presentation input, or conflict with each other"

  let inputs ←
    match ← loadInputs actualFile roleFile with
    | .error message => return .error message
    | .ok inputs => pure inputs

  match Loam.BeancountExport.renderPartialWithPresentation? inputs.presentation inputs.roles inputs.entries with
  | .error message => return .error message
  | .ok res =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile res.beancount
      Loam.Persistence.replaceTextViaSiblingStage reportFile res.report
      return .ok res

/--
Regenerate one disposable strict Beancount view from current LOAM Actual evidence
plus explicit AccountingRole evidence. Fails closed if any locus lacks an AccountingRole.
Guards against overwriting canonical household sources.
-/
def exportStrict
    (actualFile roleFile outputFile : System.FilePath) :
    IO (Except String Unit) := do
  let presentationFile := Loam.MeasurePresentation.configPathForActualFile actualFile
  if (← conflictsWithSource actualFile roleFile outputFile) ||
     (← pathsConflict presentationFile outputFile) then
    return .error "Beancount output must not replace Actual, AccountingRole, or Measure presentation input"

  let inputs ←
    match ← loadInputs actualFile roleFile with
    | .error message => return .error message
    | .ok inputs => pure inputs

  match Loam.BeancountExport.renderWithPresentation? inputs.presentation inputs.roles inputs.entries with
  | .error message => return .error message
  | .ok rendered =>
      Loam.Persistence.replaceTextViaSiblingStage outputFile rendered
      return .ok ()

end Loam.BeancountExportPipeline
