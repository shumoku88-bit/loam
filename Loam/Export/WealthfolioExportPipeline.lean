import Loam.Authority.ActualAuthority
import Loam.HouseholdPaths
import Loam.Review.ActualJournalProjection
import Loam.Review.CurrentBalanceReview
import Loam.Review.OpeningPositionReview
import Loam.Export.WealthfolioExport
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.SiblingStage
import Loam.Presentation.MeasurePresentation

namespace Loam.WealthfolioExportPipeline

open Loam.Core

set_option autoImplicit false

/-!
# Wealthfolio cash-export pipeline

This pipeline composes existing read authorities into one disposable CSV:

- normalized Actual image;
- explicit AccountingRole;
- neutral exact current-balance support;
- derived Opening Position at an explicit Accounting Epoch;
- correction-aware current Actual journal;
- optional Measure decimal presentation.

No target result is written back into LOAM authority.
-/

private def pathsConflict
    (pathA pathB : System.FilePath) : IO Bool := do
  if pathA == pathB then
    return true
  if (← pathA.pathExists) && (← pathB.pathExists) then
    return (← IO.FS.realPath pathA) == (← IO.FS.realPath pathB)
  return false

private def conflictsAny
    (sources : List System.FilePath)
    (target : System.FilePath) : IO Bool := do
  for source in sources do
    if ← pathsConflict source target then
      return true
  return false

private def coordinateLabel (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

private def assetCoordinates
    (roles : AccountingRoleMap)
    (current : Loam.CurrentBalanceReview.Snapshot) :
    Except String (List EffectCoordinate) := do
  let blockers :=
    (current.knownPresent ++ current.unsupported).filter fun coordinate =>
      roles.roleOf? coordinate.locus == some .asset
  if !blockers.isEmpty then
    throw
      ("Wealthfolio cash export requires exact current quantity support for Asset coordinates: " ++
        String.intercalate ", " (blockers.map coordinateLabel))
  else
    return
      (current.rows.filterMap fun row =>
        if roles.roleOf? row.coordinate.locus == some .asset then
          some row.coordinate
        else
          none).eraseDups

/--
Regenerate one disposable Wealthfolio cash-activity CSV from a household root.

The Accounting Epoch is not persisted here. Opening quantities are derived from
the existing historical-support boundary for every exact current Asset
coordinate. If any selected Asset cannot be justified at the requested epoch,
the export fails closed.
-/
def exportCsv
    (root : System.FilePath)
    (accountingEpoch : String)
    (outputFile : System.FilePath) : IO (Except String Unit) := do
  let actualFile := Loam.HouseholdPaths.actual root
  let roleFile := Loam.HouseholdPaths.accountingRole root
  let sourceFiles :=
    [ actualFile
    , roleFile
    , Loam.HouseholdPaths.zeroOriginCoverage root
    , Loam.HouseholdPaths.openingSupport root
    , Loam.HouseholdPaths.currentQuantityAnchor root
    , Loam.HouseholdPaths.currentQuantityPresence root
    , Loam.HouseholdPaths.boundedHistorySupport root
    , Loam.HouseholdPaths.measurePresentation root
    ]
  if ← conflictsAny sourceFiles outputFile then
    return .error "Wealthfolio output must not replace a LOAM authority or Measure presentation input"

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
    match ← Loam.MeasurePresentation.loadMetadata root with
    | .error message => return .error message
    | .ok metadata => pure metadata

  let current ←
    match ← Loam.CurrentBalanceReview.loadSnapshotFromActualImage root image with
    | .error message => return .error message
    | .ok snapshot => pure snapshot
  let coordinates ←
    match assetCoordinates roles current with
    | .error message => return .error message
    | .ok coordinates => pure coordinates

  let opening ←
    match ← Loam.OpeningPositionReview.loadFromActualImage
        root image accountingEpoch coordinates with
    | .error message => return .error message
    | .ok snapshot => pure snapshot

  let entries ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .error message => return .error message
    | .ok entries => pure entries

  let rendered ←
    match Loam.WealthfolioExport.renderWithPresentation?
        presentation roles opening entries with
    | .error message => return .error message
    | .ok rendered => pure rendered

  Loam.Persistence.replaceTextViaSiblingStage outputFile rendered
  return .ok ()

end Loam.WealthfolioExportPipeline
