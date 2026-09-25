import Loam.HouseholdPaths
import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.MovementWorldLoader
import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.CycleBudgetReview
import Loam.CycleSpendingPaceReview
import Loam.PurposeCatalog
import Loam.RoleBalanceReview
import Loam.RoleFlowReview
import Loam.ScheduledReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview
import Loam.Web.Snapshot
import Loam.Web.Record

namespace Loam.Web.Cli

set_option autoImplicit false

private def resolveDataDir (explicit : Option String) : IO (Except String System.FilePath) := do
  match explicit with
  | some path =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")

private def resolvedPathInside
    (root candidate : System.FilePath) : Bool :=
  let rootText := root.toString
  let candidateText := candidate.toString
  let rootPrefix := if rootText.endsWith "/" then rootText else rootText ++ "/"
  candidateText == rootText || candidateText.startsWith rootPrefix

/--
Web output is presentation, never household persistence.

Refuse both direct paths inside the selected household root and existing aliases
(such as symbolic links) that resolve back into it. For a new output file, the
resolved parent is sufficient to establish whether the destination would be
created inside household storage.
-/
private def outputConflictsWithHouseholdRoot
    (dataDir output : System.FilePath) : IO Bool := do
  if !(← dataDir.pathExists) then
    return false
  let rootResolved ← IO.FS.realPath dataDir
  if ← output.pathExists then
    let outputResolved ← IO.FS.realPath output
    return resolvedPathInside rootResolved outputResolved
  let parent := output.parent.getD (System.FilePath.mk ".")
  if !(← parent.pathExists) then
    return false
  let parentResolved ← IO.FS.realPath parent
  return resolvedPathInside rootResolved parentResolved

private def loadScheduledFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image) :
    IO (Except String (List Loam.ScheduledReview.Record)) := do
  match ← Loam.ScheduledReview.loadHouseholdEvidenceForEvents dataDir image.currentEvents with
  | .error message => return .error message
  | .ok evidence => return Loam.ScheduledReview.orderedCurrentOpenRecords evidence

private def currentPurposeMetadata
    (dataDir : System.FilePath) : IO (List Loam.PurposeCatalog.Metadata) := do
  match ← Loam.PurposeCatalog.loadMetadata dataDir with
  | .ok metadata => return metadata
  | .error _ => return []

private def actualFailureState {α : Type}
    (error : Loam.ActualAuthority.LoadError) : Loam.Presentation.ReadState α :=
  match error with
  | .fileNotFound _ => .unavailable
  | .decode _ _ =>
      .failed (Loam.ActualAuthority.LoadError.message error)

private def attentionReadState
    (result : Except String Loam.AttentionReview.Availability) :
    Loam.Presentation.ReadState Loam.AttentionReview.Snapshot :=
  match result with
  | .error message => .failed message
  | .ok .unavailable => .unavailable
  | .ok (.available snapshot) => .loaded snapshot


private def loadRecordContext
    (dataDir : System.FilePath) :
    IO (Except String
      (Loam.MovementAdmission.World ×
        Loam.LocusCatalog.Catalog ×
        List Loam.MeasurePresentation.Metadata)) := do
  match ← Loam.MovementWorldLoader.loadSelectedWorld? dataDir with
  | .error message => return .error message
  | .ok world =>
      let catalog ←
        match ← Loam.LocusCatalog.loadForVocabulary dataDir world.locusAdmission with
        | .ok catalog => pure catalog
        | .error _ => pure (Loam.LocusCatalog.fallback world.locusAdmission)
      match ← Loam.MeasurePresentation.loadMetadata dataDir with
      | .error message => return .error message
      | .ok metadata => return .ok (world, catalog, metadata)

private def renderRecordFormDocument
    (dataDir : System.FilePath) (operation : String) : IO String := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | return Loam.Web.Record.renderUnavailable
        "loam: could not determine the local date"
  match ← loadRecordContext dataDir with
  | .error message => return Loam.Web.Record.renderUnavailable message
  | .ok (_, catalog, metadata) =>
      return Loam.Web.Record.render
        (Loam.Web.Record.initial operation observedAt catalog metadata)

private def renderRecordPreviewDocument
    (dataDir : System.FilePath)
    (operation : String)
    (request : Loam.Web.Record.Request) : IO String := do
  match ← loadRecordContext dataDir with
  | .error message => return Loam.Web.Record.renderUnavailable message
  | .ok (world, catalog, metadata) =>
      let model : Loam.Web.Record.Model := {
        operation := operation
        request := request
        catalog := catalog
        measurePresentation := metadata
      }
      return Loam.Web.Record.render (Loam.Web.Record.review world model)

private def loadCurrentSnapshot
    (dataDir : System.FilePath) : IO (Except String Loam.Web.Snapshot.Snapshot) := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local date"

  /-
  Actual, current-open Scheduled validation, and Daily Pace share one admitted
  Actual generation. Independent authorities such as Attention and budget
  configuration remain independently observed.
  -/
  let actualImage ← Loam.ActualAuthority.loadImageDetailed dataDir
  let actual : Loam.Presentation.ReadState (List Loam.ActualReview.Record) :=
    match actualImage with
    | .error error => actualFailureState error
    | .ok image => .loaded (Loam.ActualReview.recordsFromActualImage image)
  let scheduled ←
    match actualImage with
    | .error error =>
        pure (actualFailureState error :
          Loam.Presentation.ReadState (List Loam.ScheduledReview.Record))
    | .ok image => do
        let result ← loadScheduledFromActualImage dataDir image
        pure (Loam.Presentation.ReadState.fromExcept result)
  let pace ←
    match actualImage with
    | .error error =>
        pure (actualFailureState error :
          Loam.Presentation.ReadState Loam.CycleSpendingPaceReview.Snapshot)
    | .ok image => do
        let result ←
          Loam.CycleSpendingPaceReview.loadSnapshotFromActualImageAt
            dataDir image observedAt
        pure (Loam.Presentation.ReadState.fromExcept result)
  let attentionResult ←
    Loam.AttentionReview.loadEvidence (Loam.HouseholdPaths.attention dataDir)
  let attention := attentionReadState attentionResult
  let budget ← Loam.CycleBudgetReview.loadSnapshotAt dataDir dataDir observedAt
  let stockFlow ←
    match actualImage, budget.window with
    | .error error, _ =>
        pure (actualFailureState error :
          Loam.Presentation.ReadState Loam.StockFlowReview.Snapshot)
    | _, .error message =>
        pure (.failed ("loam: Stock-Flow current window unavailable: " ++ message))
    | .ok image, .ok window => do
        let result ←
          Loam.StockFlowReview.loadSnapshotFromActualImage
            dataDir image window.start window.endExclusive
        pure (Loam.Presentation.ReadState.fromExcept result)
  let transactionsFlow : Loam.Presentation.ReadState Loam.TransactionsFlowReview.Snapshot :=
    match actualImage, budget.window with
    | .error error, _ => actualFailureState error
    | _, .error message =>
        .failed ("loam: Transactions Flow current window unavailable: " ++ message)
    | .ok image, .ok window =>
        Loam.Presentation.ReadState.fromExcept
          (Loam.TransactionsFlowReview.projectImage image window.start window.endExclusive)
  let roleFlow ←
    match actualImage, budget.window with
    | .error error, _ =>
        pure (actualFailureState error :
          Loam.Presentation.ReadState Loam.RoleFlowReview.Snapshot)
    | _, .error message =>
        pure (.failed ("loam: Income & Expense current window unavailable: " ++ message))
    | .ok image, .ok window => do
        let result ←
          Loam.RoleFlowReview.loadSnapshotFromActualImage
            dataDir image window.start window.endExclusive
        pure (Loam.Presentation.ReadState.fromExcept result)
  let roleBalances ←
    match actualImage with
    | .error error =>
        pure (actualFailureState error :
          Loam.Presentation.ReadState Loam.RoleBalanceReview.Snapshot)
    | .ok image => do
        let result ← Loam.RoleBalanceReview.loadSnapshotFromActualImage dataDir image
        pure (Loam.Presentation.ReadState.fromExcept result)
  let capacityResult ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir
  let capacity := Loam.Presentation.ReadState.fromExcept capacityResult
  let purposeMetadata ← currentPurposeMetadata dataDir

  let snapshot : Loam.Web.Snapshot.Snapshot := {
    observedAt := observedAt
    actual := actual
    scheduled := scheduled
    attention := attention
    budget := budget
    capacity := capacity
    pace := pace
    stockFlow := stockFlow
    transactionsFlow := transactionsFlow
    roleFlow := roleFlow
    roleBalances := roleBalances
    purposeMetadata := purposeMetadata
  }

  return .ok snapshot

private def renderCurrent
    (dataDir : System.FilePath) : IO (Except String String) := do
  match ← loadCurrentSnapshot dataDir with
  | .error message => return .error message
  | .ok snapshot => return .ok (Loam.Web.Snapshot.render snapshot)

private def renderRecordPublishDocument
    (dataDir : System.FilePath)
    (operation : String)
    (request : Loam.Web.Record.Request) : IO String := do
  match ← loadRecordContext dataDir with
  | .error message => return Loam.Web.Record.renderUnavailable message
  | .ok (_, catalog, metadata) =>
      let rejected (message : String) : String :=
        Loam.Web.Record.render {
          operation := operation
          request := request
          catalog := catalog
          measurePresentation := metadata
          review := .rejected message
        }
      let .ok input := request.toInput?
        | return rejected "The submitted Record input is no longer valid."
      let .ok draft := Loam.Presentation.Record.draftWithPresentation? metadata input
        | return rejected "The submitted Record draft is no longer valid."
      let result ← Loam.HouseholdCommand.recordIdempotent dataDir ⟨operation⟩ draft
      match result with
      | .error message => return rejected message
      | .ok publication =>
          let (event, notice) :=
            match publication with
            | .applied event =>
                (event, "Recorded Event " ++ event.token ++ ". Canonical household state re-read.")
            | .alreadyApplied event =>
                (event, "Record already completed as Event " ++ event.token ++
                  ". Canonical household state re-read.")
          match ← loadCurrentSnapshot dataDir with
          | .error message =>
              return Loam.Web.Record.renderUnavailable
                ("Record publication succeeded for " ++ event.token ++
                  ", but the fresh household snapshot failed: " ++ message)
          | .ok snapshot =>
              return Loam.Web.Snapshot.renderWithNotice snapshot (some notice)

private def renderTo
    (dataDir output : System.FilePath) : IO UInt32 := do
  match ← renderCurrent dataDir with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok html =>
      if output.toString = "-" then
        IO.print html
        return 0
      try
        if ← outputConflictsWithHouseholdRoot dataDir output then
          IO.eprintln "loam: Web output must remain outside the household data root"
          return 2
        IO.FS.writeFile output html
        IO.println ("LOAM Web snapshot: " ++ output.toString)
        return 0
      catch error =>
        IO.eprintln ("loam: could not write Web snapshot: " ++ error.toString)
        return 2

private def usage : String :=
  "Render the LOAM Web frontend:\n" ++
  "  loamWeb [LOAM_DATA_DIR] [OUTPUT_HTML]\n\n" ++
  "Defaults: LOAM_DATA_DIR or ../loam-data; output ./loam-web.html.\n" ++
  "Use OUTPUT_HTML '-' to write only the current HTML document to stdout.\n" ++
  "Household reads use shared Review boundaries; Record publication uses HouseholdCommand."

def run (args : List String) : IO UInt32 := do
  match args with
  | ["--record-form", dataPath, operation] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir =>
          IO.print (← renderRecordFormDocument dataDir operation)
          return 0
  | ["--record-preview", dataPath, operation, date, description, measure,
      fromLocus, toLocus, amount] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir =>
          IO.print (← renderRecordPreviewDocument dataDir operation {
            date := date
            description := description
            measure := measure
            fromLocus := fromLocus
            toLocus := toLocus
            amount := amount
          })
          return 0
  | ["--record-confirm", dataPath, operation, date, description, measure,
      fromLocus, toLocus, amount] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir =>
          IO.print (← renderRecordPublishDocument dataDir operation {
            date := date
            description := description
            measure := measure
            fromLocus := fromLocus
            toLocus := toLocus
            amount := amount
          })
          return 0
  | [] =>
      match ← resolveDataDir none with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir => renderTo dataDir (System.FilePath.mk "loam-web.html")
  | [dataPath] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir => renderTo dataDir (System.FilePath.mk "loam-web.html")
  | [dataPath, outputPath] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir => renderTo dataDir (System.FilePath.mk outputPath)
  | _ =>
      IO.eprintln usage
      return 2

end Loam.Web.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Web.Cli.run args
