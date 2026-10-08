import Loam.HouseholdPaths
import Loam.Authority.ActualAuthority
import Loam.MovementWorldLoader
import Loam.HouseholdCommand
import Loam.Presentation.LocusCatalog
import Loam.Presentation.MeasurePresentation
import Loam.Presentation.PurposeCatalog
import Loam.Persistence.TokenSyntax
import Loam.Tui.LocusAdmissionAdministration
import Loam.Tui.LocusAdmissionAdministrationSession
import Loam.Tui.Record
import Loam.Tui.RecordSession
import Loam.Tui.Exchange
import Loam.Tui.ExchangeSession
import Loam.Authority.LocusAdmissionAuthority
import Loam.Tui.AttentionAdministration
import Loam.Tui.AttentionAdministrationSession
import Loam.Tui.Balances
import Loam.Tui.SettlementWorkspace
import Loam.Tui.SettlementAction
import Loam.Tui.SettlementActionSession
import Loam.Review.SettlementReview
import Loam.Tui.Capacity
import Loam.Tui.CapacitySession
import Loam.Tui.CycleBudget
import Loam.Tui.CycleBudgetSession
import Loam.Review.CycleSpendingPaceReview
import Loam.Tui.CurrentQuantityAnchor
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.ActualRoutingAdministrationSession
import Loam.Tui.Reports
import Loam.Tui.ReportsSession
import Loam.Tui.FavaLaunch
import Loam.Config.BoundaryPresetConfig
import Loam.Tui.CompletionPrompt
import Loam.ActualDate
import Loam.Review.ActualReview
import Loam.Review.ScheduledReview
import Loam.Review.ScheduledCoverageReview
import Loam.Review.AttentionReview
import Loam.Config.BalanceViewConfig
import Loam.Review.CurrentBalanceReview
import Loam.Review.RoleBalanceReview
import Loam.Review.RoleFlowReview
import Loam.Review.CapacityReview
import Loam.Review.ActualRoutingReview
import Loam.Tui.Main
import Loam.Tui.Home
import Loam.Tui.HomeCommandPalette
import Loam.Tui.DailyPaceTrend
import Loam.Tui.ActualWorkspace
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.ScheduledWorkspaceSession
import Loam.Tui.SelectedDay
import Loam.Tui.SelectedDaySession
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.Cli

open Loam.Tui.Kernel
open Loam.Tui.Runtime
open Loam.Tui.Main

set_option autoImplicit false

private def resolveDataDir (args : List String) : IO (Except String System.FilePath) := do
  match args with
  | [] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")
  | [path] =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | _ => return .error "usage: loamTui [LOAM_DATA_DIR]"

private def resolveActualRoot
    (dataDir : System.FilePath) : IO (Except String System.FilePath) := do
  return .ok dataDir

private def currentLocusMetadata
    (dataDir : System.FilePath) : IO (List Loam.LocusCatalog.Metadata) := do
  match ← Loam.LocusCatalog.loadMetadata dataDir with
  | .ok metadata => return metadata
  | .error _ => return []

private def currentPurposeMetadata
    (dataDir : System.FilePath) : IO (List Loam.PurposeCatalog.Metadata) := do
  match ← Loam.PurposeCatalog.loadMetadata dataDir with
  | .ok metadata => return metadata
  | .error _ => return []

/--
Measure scale changes how typed decimal text becomes exact quanta. A malformed
configured convention therefore refuses the editor instead of silently falling
back to a different numeric interpretation.
-/
private def currentMeasurePresentation
    (dataDir : System.FilePath) : IO (List Loam.MeasurePresentation.Metadata) := do
  match ← Loam.MeasurePresentation.loadMetadata dataDir with
  | .ok metadata => return metadata
  | .error message => throw (IO.userError message)

private def configuredMeasure : IO (Except String Loam.Core.MeasureId) := do
  let token := (← IO.getEnv "LOAM_MEASURE").getD "jpy"
  if !Loam.Persistence.validToken token then
    return .error "loam: Measure must be a nonempty single-line token"
  return .ok ⟨token⟩

private def requireConfiguredMeasure : IO Loam.Core.MeasureId := do
  match ← configuredMeasure with
  | .ok measure => pure measure
  | .error message => throw (IO.userError message)

private def currentLocusCatalog
    (dataDir : System.FilePath) (world : Loam.MovementAdmission.World) :
    IO Loam.LocusCatalog.Catalog := do
  match ← Loam.LocusCatalog.loadForVocabulary dataDir world.locusAdmission with
  | .ok catalog => return catalog
  | .error _ => return Loam.LocusCatalog.fallback world.locusAdmission

/--
Compose one Home snapshot from one already-admitted Actual generation.

Every Actual-backed Home branch receives the same `ActualAuthority.Image`.
Actual rows and quantity projections use that image's admitted current
interpretation. Scheduled completion validation uses retained Event identities
from the same image: Correction changes current interpretation but does not erase
the occurrence identity referenced by an already-retained completion.

Independent authorities such as Scheduled storage and Attention remain
independently refreshed; this boundary promises same-Actual-generation
composition, not a cross-file atomic snapshot.
-/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (today : String)
    (image : Loam.ActualAuthority.Image) : IO (Except String Snapshot) := do
  let actualRecords := Loam.ActualReview.recordsFromActualImage image
  let scheduled ←
    Loam.ScheduledReview.loadHouseholdEvidenceForEvents dataDir image.evidence.events
  let attentionResult ←
    Loam.AttentionReview.loadEvidence (Loam.HouseholdPaths.attention dataDir)
  let attention : Loam.Presentation.ReadState Loam.AttentionReview.Snapshot :=
    match attentionResult with
    | .error message => .failed message
    | .ok .unavailable => .unavailable
    | .ok (.available snapshot) => .loaded snapshot
  let (pace, paceHistory) :
      Loam.Presentation.ReadState Loam.CycleSpendingPaceReview.Snapshot ×
      Loam.Presentation.ReadState (List Loam.CycleSpendingPaceReview.Snapshot) ←
    match scheduled with
    | .error message => pure (.failed message, .failed message)
    | .ok scheduledEvidence =>
        match ← Loam.CycleSpendingPaceReview.loadPaceAndHistoryFromActualImageAt
            dataDir image scheduledEvidence today 7 with
        | .error message => pure (.failed message, .failed message)
        | .ok (paceSnapshot, historySnapshots) =>
            pure (.loaded paceSnapshot, .loaded historySnapshots)
  let moneyCalendar : Loam.Presentation.ReadState MoneyCalendarSnapshot ←
    match ← Loam.RoleFlowReview.loadRoleMap dataDir with
    | .error message => pure (.failed message)
    | .ok roles =>
        match ← Loam.MeasurePresentation.loadMetadata dataDir with
        | .error message => pure (.failed message)
        | .ok presentation =>
            pure (.loaded {
              flow := Loam.CalendarMoneyReview.project actualRecords roles
              presentation := presentation
            })
  let actual : ActualSnapshot := {
    today := today
    allRecords := actualRecords
  }
  return .ok {
    actual := actual
    scheduled := scheduled
    attention := attention
    pace := pace
    paceHistory := paceHistory
    moneyCalendar := moneyCalendar
  }

private def loadSnapshot (dataDir : System.FilePath) : IO (Except String Snapshot) := do
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local date"
  let image ←
    match ← Loam.ActualAuthority.loadImage? dataDir with
    | .error message => return .error message
    | .ok image => pure image
  loadSnapshotFromActualImage dataDir today image

private def requireReload {α : Type} (notice : String)
    (reload : IO (Except String α)) : IO α := do
  match ← reload with
  | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
  | .ok value => pure value

private def unavailableNotice (subject message : String) : String :=
  "[Unavailable] " ++ subject ++ ": " ++ message

def compiledFrameFor (bounds : Bounds) (snapshot : Snapshot) (state : State) : CompiledWidget :=
  compileWidget (Loam.Tui.Home.view bounds snapshot state)


theorem compiledFrameFor_spec (bounds : Bounds) (snapshot : Snapshot) (state : State) :
    (compiledFrameFor bounds snapshot state).toScreen bounds 0 0 =
      renderAt bounds 0 0 (Loam.Tui.Home.view bounds snapshot state) := by
  simpa [compiledFrameFor] using
    compileWidget_spec bounds 0 0 (Loam.Tui.Home.view bounds snapshot state)


def eventOfKey : Loam.Tui.Terminal.Key → Event
  | .left => .left
  | .right => .right
  | .up => .up
  | .down => .down
  | .input 'q' => .quit
  | .input 'Q' => .quit
  | _ => .other

/-- Home navigation grammar, with arrows retained as equivalent navigation keys. -/
def homeEventOfKey : Loam.Tui.Terminal.Key → Event
  | .input 'h' | .input 'H' => .left
  | .input 'l' | .input 'L' => .right
  | .input 'k' | .input 'K' => .up
  | .input 'j' | .input 'J' => .down
  | key => eventOfKey key

/-- Actual workspace interaction grammar over presentation-only pane and cursor state. -/
def actualWorkspaceEventOfKey
    (state : Loam.Tui.ActualWorkspace.State) :
    Loam.Tui.Terminal.Key → Loam.Tui.ActualWorkspace.Event :=
  if state.searchEditing then
    fun key =>
      match key with
      | .escape => .cancelSearch
      | .backspace | .delete => .searchBackspace
      | .enter => .acceptSearch
      | .input char => .searchInput char
      | .paste text => .searchPaste text
      | _ => .other
  else
    fun key =>
      match key with
      | .up | .input 'k' | .input 'K' => .previous
      | .down | .input 'j' | .input 'J' => .next
      | .pageUp => .pageUp
      | .pageDown => .pageDown
      | .home => .home
      | .«end» => .«end»
      | .left | .input 'h' | .input 'H' => .focusLeft
      | .right | .input 'l' | .input 'L' => .focusRight
      | .input 'f' | .input 'F' => .cycleFilter
      | .input 's' | .input 'S' => .cycleOrder
      | .input '/' => .beginSearch
      | .enter => .openSelected
      | .input 'n' | .input 'N' => .recordNew
      | .escape | .input 'q' | .input 'Q' => .back
      | .ctrl 'l' => .redraw
      | .input 'y' | .input 'Y' => .yank
      | _ => .other

/-- Actual workspace session. `q` returns to Home; `n` reuses the shared Movement writer. -/
partial def actualWorkspaceLoop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : Loam.Tui.ActualWorkspace.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let (key, repeatCount) ← Loam.Tui.Terminal.readKeyWithRepeat
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.ActualWorkspace.view active snapshot state)
  if key == .other then return (← actualWorkspaceLoop bounds dataDir root snapshot state frame)
  let step := Loam.Tui.ActualWorkspace.updateWithRepeat snapshot state
    (actualWorkspaceEventOfKey state key) repeatCount
  match step.command with
  | .back => return snapshot
  | .openSelected =>
      match Loam.Tui.ActualWorkspace.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected to open." }
          let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          actualWorkspaceLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.SelectedDay.initialForActual? snapshot record with
          | none =>
              let next := { step.state with
                notice := "The selected Actual has no dated day workspace coordinate." }
              let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              actualWorkspaceLoop bounds dataDir root snapshot next nextFrame
          | some day =>
              let dayFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot day)
              Loam.Tui.Terminal.redrawFromBlank bounds dayFrame
              let fresh ← Loam.Tui.SelectedDaySession.run
                bounds dataDir root (loadSnapshot dataDir) snapshot day dayFrame
              let refreshed := Loam.Tui.ActualWorkspace.refreshed fresh step.state
              let next := { refreshed with notice := "" }
              let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              actualWorkspaceLoop bounds dataDir root fresh next nextFrame
  | .recordNew =>
      let world ←
        match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := world.locusAdmission.approved.map (fun locus => locus.token)
      let catalog ← currentLocusCatalog dataDir world
      let measurePresentation ← currentMeasurePresentation dataDir
      let editor := Loam.Tui.Record.withMeasurePresentation
        (Loam.Tui.Record.withCatalog
          (Loam.Tui.Record.initialWithMeasure (← requireConfiguredMeasure) state.focusDate) catalog)
        measurePresentation
      let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
      Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
      let notice ← Loam.Tui.RecordSession.run bounds root world known editor editorFrame
      let fresh ← requireReload notice (loadSnapshot dataDir)
      let refreshed := Loam.Tui.ActualWorkspace.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      actualWorkspaceLoop bounds dataDir root fresh next nextFrame
  | .redraw =>
      let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot step.state)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      actualWorkspaceLoop bounds dataDir root snapshot step.state nextFrame
  | .yank =>
      let success ← Loam.Tui.Terminal.copyScreenToClipboard bounds frame
      let notice := if success then "Copied screen to clipboard." else "Failed to copy screen to clipboard."
      let next := { step.state with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      actualWorkspaceLoop bounds dataDir root snapshot next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      actualWorkspaceLoop bounds dataDir root snapshot step.state nextFrame

/-- Read-only balance-view session; q/Esc returns to Home; y copies screen to clipboard. -/
partial def balancesLoop (bounds : Bounds)
    (state : Loam.Tui.Balances.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.Balances.viewForBounds active state)
  if key = .input 'y' || key = .input 'Y' then
    let success ← Loam.Tui.Terminal.copyScreenToClipboard bounds frame
    let next := { state with notice := if success then "Copied visible screen." else "Clipboard unavailable." }
    let nextFrame := compileWidget (Loam.Tui.Balances.viewForBounds bounds next)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    balancesLoop bounds next nextFrame
  else
    let back := key = .escape || key = .input 'q' || key = .input 'Q'
    match Loam.Tui.Balances.update state back with
    | .back => return ()
    | .stay next =>
        let nextFrame := compileWidget (Loam.Tui.Balances.viewForBounds bounds next)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        balancesLoop bounds next nextFrame

/-- Read-only settlement review session; q/Esc returns to Home; y copies screen to clipboard. -/
partial def settlementLoop
    (bounds : Bounds)
    (root : System.FilePath)
    (today : String)
    (state : Loam.Tui.SettlementWorkspace.State)
    (frame : CompiledWidget) : IO Unit := do
  let (key, repeatCount) ← Loam.Tui.Terminal.readKeyWithRepeat
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.SettlementWorkspace.view active state)
  if key = .input 'y' || key = .input 'Y' then
    let success ← Loam.Tui.Terminal.copyScreenToClipboard bounds frame
    let notice := if success then "Copied screen to clipboard." else "Failed to copy screen to clipboard."
    let next := { state with notice := notice }
    let nextFrame := compileWidget (Loam.Tui.SettlementWorkspace.view bounds next)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    settlementLoop bounds root today next nextFrame
    return ()
  let event : Loam.Tui.SettlementWorkspace.Event :=
    match key with
    | .up | .input 'k' | .input 'K' => .previous
    | .down | .input 'j' | .input 'J' => .next
    | .input 'f' | .input 'F' => .cycleScope
    | .input 'a' | .input 'A' => .action
    | .input 'd' | .input 'D' => .toggleDetail
    | .escape | .input 'q' | .input 'Q' => .back
    | _ => .other
  let step := Loam.Tui.SettlementWorkspace.updateWithRepeat state event repeatCount
  match step.command with
  | .back => return ()
  | .action =>
      match Loam.Tui.SettlementWorkspace.selectedRow? step.state with
      | none =>
          let next := { step.state with notice := "No item is selected." }
          let nextFrame :=
            compileWidget (Loam.Tui.SettlementWorkspace.view bounds next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          settlementLoop bounds root today next nextFrame
      | some row =>
          let action := Loam.Tui.SettlementAction.initial today row
          let actionFrame := compileWidget (Loam.Tui.SettlementAction.view action)
          Loam.Tui.Terminal.redrawFromBlank bounds actionFrame
          let notice ← Loam.Tui.SettlementActionSession.run
            bounds root action actionFrame
          let refreshedSnapshot ←
            match ← Loam.SettlementReview.loadSnapshot root with
            | .ok snapshot => pure snapshot
            | .error message =>
                throw (IO.userError ("Settlement action completed but reload failed: " ++ message))
          let next :=
            Loam.Tui.SettlementWorkspace.refreshed
              refreshedSnapshot step.state notice
          let nextFrame :=
            compileWidget (Loam.Tui.SettlementWorkspace.view bounds next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          settlementLoop bounds root today next nextFrame
  | .stay =>
      let nextFrame :=
        compileWidget (Loam.Tui.SettlementWorkspace.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      settlementLoop bounds root today step.state nextFrame

/-- Current quantity observations stay presentation-local until one new reconciliation group is published. -/
partial def currentQuantityAnchorLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.CurrentQuantityAnchor.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.CurrentQuantityAnchor.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Current quantity observation cancelled."
  match step.publish with
  | some assertions =>
      match ← Loam.HouseholdCommand.observeCurrentQuantities root assertions with
      | .ok () =>
          return "Published current quantity anchor for " ++
            toString assertions.length ++ " observed coordinate(s)."
      | .error message =>
          let next := Loam.Tui.CurrentQuantityAnchor.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.CurrentQuantityAnchor.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          currentQuantityAnchorLoop bounds root next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.CurrentQuantityAnchor.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      currentQuantityAnchorLoop bounds root step.state nextFrame

/-- Read-only Daily Pace history drill-down. Any unrelated key leaves the view unchanged. -/
partial def dailyPaceTrendLoop : IO Unit := do
  match ← Loam.Tui.Terminal.readKey with
  | .escape | .input 'q' | .input 'Q' => return ()
  | _ => dailyPaceTrendLoop

partial def loop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : State) (frame : CompiledWidget)
    (paletteChoice : Option Loam.Tui.HomeCommandPalette.Choice := none) : IO Unit := do
  let (key, repeatCount) ←
    match paletteChoice with
    | none => Loam.Tui.Terminal.readKeyWithRepeat
    | some .budget => pure (Loam.Tui.Terminal.Key.input 'c', 1)
    | some .capacity => pure (Loam.Tui.Terminal.Key.input 'e', 1)
    | some .purposeRouting => pure (Loam.Tui.Terminal.Key.input 'p', 1)
  let fromPalette := paletteChoice.isSome
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compiledFrameFor active snapshot (Loam.Tui.Home.reconcileState active snapshot state)
  if key == .other then return (← loop bounds dataDir root snapshot state frame)
  let state := Loam.Tui.Home.reconcileState bounds snapshot state
  if let some home :=
      (if fromPalette then none
       else Loam.Tui.Home.navigationKey bounds snapshot state key repeatCount) then
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if key == .input ' ' && !fromPalette then
    let selected ← Loam.Tui.HomeCommandPalette.run bounds
    let nextFrame := compiledFrameFor bounds snapshot state
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot state nextFrame selected
  else if key = .enter then
    let day? :=
      if state.activePane == .detail then do
        let record ← Loam.Tui.Main.selectedDetailRecord? snapshot state
        Loam.Tui.SelectedDay.initialForActual? snapshot record
      else some (Loam.Tui.SelectedDay.initial state.selectedDate)
    match day? with
    | none =>
        let home := { state with notice := "No transaction selected." }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | some day =>
        let dayFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot day)
        Loam.Tui.Terminal.redrawFromBlank bounds dayFrame
        let fresh ← Loam.Tui.SelectedDaySession.run
          bounds dataDir root (loadSnapshot dataDir) snapshot day dayFrame
        let home := Loam.Tui.Home.reconcileState bounds fresh { state with notice := "" }
        let nextFrame := compiledFrameFor bounds fresh home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root fresh home nextFrame
  else if (key = .input 'm' || key = .input 'M') then
    let world ←
      match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
      | .error message => throw (IO.userError message)
      | .ok world => pure world
    let catalog ← currentLocusCatalog dataDir world
    let admin := Loam.Tui.LocusAdmissionAdministration.initial catalog
    let adminFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds admin)
    Loam.Tui.Terminal.redrawFromBlank bounds adminFrame
    let notice ← Loam.Tui.LocusAdmissionAdministrationSession.run
      bounds dataDir root admin adminFrame
    let home := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'd' || key = .input 'D') then
    let paceFrame := compileWidget (Loam.Tui.DailyPaceTrend.view bounds snapshot)
    Loam.Tui.Terminal.redrawFromBlank bounds paceFrame
    dailyPaceTrendLoop
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'a' || key = .input 'A') then
    let metadata ← currentLocusMetadata dataDir
    let actual := Loam.Tui.ActualWorkspace.withMetadata
      (Loam.Tui.ActualWorkspace.initial state.selectedDate) metadata
    let actualFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot actual)
    Loam.Tui.Terminal.redrawFromBlank bounds actualFrame
    let fresh ← actualWorkspaceLoop bounds dataDir root snapshot actual actualFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if (key = .input 's' || key = .input 'S') then
    let scheduled := Loam.Tui.ScheduledWorkspace.initial state.selectedDate
    let coverage ← Loam.ScheduledCoverageReview.loadSnapshot
      dataDir root snapshot.actual.today 18
    let scheduledFrame := compileWidget
      (Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot scheduled coverage)
    Loam.Tui.Terminal.redrawFromBlank bounds scheduledFrame
    let fresh ← Loam.Tui.ScheduledWorkspaceSession.run
      bounds dataDir root (loadSnapshot dataDir) snapshot coverage scheduled scheduledFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if (key = .input 'i' || key = .input 'I') then
    match ← Loam.AttentionReview.loadHouseholdEvidence root with
    | .error message =>
        let home := { state with notice := unavailableNotice "Attention" message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok evidence =>
        let admin := Loam.Tui.AttentionAdministration.initial evidence snapshot.actual.today
        let adminFrame := compileWidget (Loam.Tui.AttentionAdministration.view admin)
        Loam.Tui.Terminal.redrawFromBlank bounds adminFrame
        Loam.Tui.AttentionAdministrationSession.run bounds root admin adminFrame
        let fresh ← requireReload "Attention administration completed." (loadSnapshot dataDir)
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor bounds fresh home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root fresh home nextFrame
  else if (key = .input 'y' || key = .input 'Y') then
    let success ← Loam.Tui.Terminal.copyScreenToClipboard bounds frame
    let notice := if success then "Copied screen to clipboard." else "Failed to copy screen to clipboard."
    let home := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'u' || key = .input 'U') then
    match ← Loam.SettlementReview.loadSnapshot root with
    | .error message =>
        let home := { state with notice := unavailableNotice "Settlement" message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok settlementSnapshot =>
        let settlement := Loam.Tui.SettlementWorkspace.initial settlementSnapshot
        let settlementFrame :=
          compileWidget (Loam.Tui.SettlementWorkspace.view bounds settlement)
        Loam.Tui.Terminal.redrawFromBlank bounds settlementFrame
        settlementLoop bounds root snapshot.actual.today settlement settlementFrame
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'b' || key = .input 'B') then
    match ← Loam.BalanceViewConfig.load? (Loam.HouseholdPaths.balanceView dataDir) with
    | none =>
        let home := {
          state with
          notice := unavailableNotice "Balances" "loam: malformed or unsupported balance-view config"
        }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | some selected =>
        match ← Loam.CurrentBalanceReview.loadSnapshot dataDir root with
        | .error message =>
            let home := { state with notice := unavailableNotice "Balances" message }
            let nextFrame := compiledFrameFor bounds snapshot home
            Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
            loop bounds dataDir root snapshot home nextFrame
        | .ok balanceSnapshot =>
            let balances := Loam.Tui.Balances.initial balanceSnapshot selected
            let balancesFrame := compileWidget (Loam.Tui.Balances.viewForBounds bounds balances)
            Loam.Tui.Terminal.redrawFromBlank bounds balancesFrame
            balancesLoop bounds balances balancesFrame
            let home := { state with notice := "" }
            let nextFrame := compiledFrameFor bounds snapshot home
            Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
            loop bounds dataDir root snapshot home nextFrame
  else if fromPalette && Loam.Tui.CycleBudget.isHomeEntrance key then
    match ← configuredMeasure with
    | .error message =>
        let home := { state with notice := message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok measure =>
        let answer ← Loam.CycleBudgetReview.loadSnapshotAtForMeasure
          measure dataDir root snapshot.actual.today
        let purposeMetadata ← currentPurposeMetadata dataDir
        let budget := Loam.Tui.CycleBudget.withPurposeMetadata purposeMetadata
          ({ snapshot := answer } : Loam.Tui.CycleBudget.State)
        let budgetFrame := compileWidget (Loam.Tui.CycleBudget.view bounds budget)
        Loam.Tui.Terminal.redrawFromBlank bounds budgetFrame
        Loam.Tui.CycleBudgetSession.run bounds dataDir root budget budgetFrame
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root snapshot home nextFrame
  else if fromPalette && (key = .input 'p' || key = .input 'P') then
    match ← Loam.ActualRoutingReview.loadSnapshot dataDir root snapshot.actual.today with
    | .error message =>
        let home := { state with notice := unavailableNotice "Purpose routes" message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok routingSnapshot =>
        let administration := Loam.Tui.ActualRoutingAdministration.initial routingSnapshot
        let administrationFrame :=
          compileWidget (Loam.Tui.ActualRoutingAdministration.view bounds administration)
        Loam.Tui.Terminal.redrawFromBlank bounds administrationFrame
        let notice ← Loam.Tui.ActualRoutingAdministrationSession.run
          bounds root administration administrationFrame
        let home := { state with notice := notice }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root snapshot home nextFrame
  else if fromPalette && (key = .input 'e' || key = .input 'E') then
    match ← configuredMeasure with
    | .error message =>
        let home := { state with notice := message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok measure =>
        match ← Loam.CapacityReview.loadSnapshotFromHouseholdRootForMeasure
            measure dataDir with
        | .error message =>
            let home := { state with notice := unavailableNotice "Capacity" message }
            let nextFrame := compiledFrameFor bounds snapshot home
            Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
            loop bounds dataDir root snapshot home nextFrame
        | .ok capacitySnapshot =>
            let purposeMetadata ← currentPurposeMetadata dataDir
            let baseCapacity := Loam.Tui.Capacity.withPurposeMetadata purposeMetadata
              (Loam.Tui.Capacity.initial capacitySnapshot)
            Loam.Tui.CapacitySession.run
              bounds dataDir root snapshot.actual.today baseCapacity frame
            let home := { state with notice := "" }
            let nextFrame := compiledFrameFor bounds snapshot home
            Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
            loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'o' || key = .input 'O') then
    let editor := Loam.Tui.CurrentQuantityAnchor.initialWithMeasure (← requireConfiguredMeasure)
    let editorFrame := compileWidget (Loam.Tui.CurrentQuantityAnchor.view editor)
    Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
    let notice ← currentQuantityAnchorLoop bounds root editor editorFrame
    let home := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'v' || key = .input 'V') then
    match ← configuredMeasure with
    | .error message =>
        let home := { state with notice := message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok measure =>
        let reports ←
          match ← Loam.BoundaryPresetConfig.load?
              (Loam.HouseholdPaths.boundaryPresets dataDir) with
          | some presets =>
              pure (Loam.Tui.Reports.initialForDateWithPresetsForMeasure
                measure state.selectedDate presets)
          | none =>
              let base := Loam.Tui.Reports.initialForDateForMeasure
                measure state.selectedDate
              pure { base with
                notice := "Boundary preset config malformed; named presets unavailable." }
        Loam.Tui.Terminal.redrawWidgetDirect
          bounds (Loam.Tui.Reports.viewForBounds bounds reports)
        let nextBounds ←
          Loam.Tui.ReportsSession.run bounds dataDir root reports
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor nextBounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank nextBounds nextFrame
        loop nextBounds dataDir root snapshot home nextFrame
  else if (key = .input 'x' || key = .input 'X') then
    let evidence ←
      match ← Loam.ActualAuthority.loadActual? root with
      | .error message => throw (IO.userError message)
      | .ok value => pure value
    let locusAdmission ←
      match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
      | .error message => throw (IO.userError message)
      | .ok value => pure value
    let world : Loam.ExchangeAdmission.World := {
      events := evidence.events
      validity := evidence.validity
      descriptions := evidence.descriptions
      exchanges := evidence.exchanges
      corrections := evidence.corrections
      locusAdmission := locusAdmission
    }
    let measurePresentation ← currentMeasurePresentation dataDir
    let editor := Loam.Tui.Exchange.withMeasurePresentation
      (Loam.Tui.Exchange.initialWithMeasure (← requireConfiguredMeasure) state.selectedDate)
      measurePresentation
    let editorFrame := compileWidget (Loam.Tui.Exchange.view editor)
    Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
    let notice ← Loam.Tui.ExchangeSession.run bounds root world editor editorFrame
    let fresh ← requireReload notice (loadSnapshot dataDir)
    let destination := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds fresh destination
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh destination nextFrame
  else if (key = .input 'r' || key = .input 'R') then
    let world ←
      match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
      | .error message => throw (IO.userError message)
      | .ok world => pure world
    let known := world.locusAdmission.approved.map (fun locus => locus.token)
    let catalog ← currentLocusCatalog dataDir world
    let measurePresentation ← currentMeasurePresentation dataDir
    let editor := Loam.Tui.Record.withMeasurePresentation
      (Loam.Tui.Record.withCatalog
        (Loam.Tui.Record.initialWithMeasure (← requireConfiguredMeasure) state.selectedDate) catalog)
      measurePresentation
    let notice ←
      Loam.Tui.RecordSession.runAdaptive bounds root world known editor frame
    let fresh ← requireReload notice (loadSnapshot dataDir)
    let destination := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds fresh destination
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh destination nextFrame
  else
    let event := homeEventOfKey key
    let step := update state event
    if step.quit then return
    let nextFrame := compiledFrameFor bounds snapshot step.state
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    loop bounds dataDir root snapshot step.state nextFrame


def run (args : List String) : IO UInt32 := do
  let dataDir ←
    match ← resolveDataDir args with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  let snapshot ←
    match ← loadSnapshot dataDir with
    | .error message => IO.eprintln message; return 2
    | .ok snapshot => pure snapshot
  let root ←
    match ← resolveActualRoot dataDir with
    | .error message => IO.eprintln message; return 2
    | .ok root => pure root
  let bounds ← Loam.Tui.Terminal.currentBounds
  Loam.Tui.Terminal.enter
  try
    let state := { initialState snapshot.actual.today with homeMode := .daily }
    let frame := compiledFrameFor bounds snapshot state
    Loam.Tui.Terminal.redrawFromBlank bounds frame
    loop bounds dataDir root snapshot state frame
    return 0
  finally
    Loam.Tui.Terminal.leave
    Loam.Tui.FavaLaunch.shutdown

end Loam.Tui.Cli
