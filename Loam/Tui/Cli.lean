import Loam.HouseholdPaths
import Loam.ActualAuthority
import Loam.MovementWorldLoader
import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.PurposeCatalog
import Loam.Tui.LocusAdmissionAdministration
import Loam.Tui.LocusAdmissionAdministrationSession
import Loam.Tui.Record
import Loam.Tui.RecordSession
import Loam.Tui.AttentionAdministration
import Loam.Tui.AttentionAdministrationSession
import Loam.Tui.Balances
import Loam.Tui.Capacity
import Loam.Tui.CapacitySession
import Loam.Tui.CycleBudget
import Loam.Tui.CycleBudgetSession
import Loam.CycleSpendingPaceReview
import Loam.Tui.CurrentQuantityAnchor
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.ActualRoutingAdministrationSession
import Loam.Tui.Reports
import Loam.Tui.ReportsSession
import Loam.Tui.FavaLaunch
import Loam.BoundaryPresetConfig
import Loam.Tui.CompletionPrompt
import Loam.ActualDate
import Loam.ActualReview
import Loam.ScheduledReview
import Loam.AttentionReview
import Loam.BalanceReview
import Loam.CapacityReview
import Loam.ActualRoutingReview
import Loam.Tui.Main
import Loam.Tui.Home
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

private def currentLocusCatalog
    (dataDir : System.FilePath) (world : Loam.MovementAdmission.World) :
    IO Loam.LocusCatalog.Catalog := do
  match ← Loam.LocusCatalog.loadForVocabulary dataDir world.locusAdmission with
  | .ok catalog => return catalog
  | .error _ => return Loam.LocusCatalog.fallback world.locusAdmission

/--
Compose one Home snapshot from one already-admitted Actual generation.

Every Actual-backed Home branch receives the same `ActualAuthority.Image`:
Actual rows, Scheduled completion validation, current Daily Pace, and recent pace
history. Independent authorities such as Scheduled storage and Attention remain
independently refreshed; this boundary promises same-Actual-generation
composition, not a cross-file atomic snapshot.
-/
def loadSnapshotFromActualImage
    (dataDir : System.FilePath)
    (today : String)
    (image : Loam.ActualAuthority.Image) : IO (Except String Snapshot) := do
  let actualRecords := Loam.ActualReview.recordsFromActualImage image
  let scheduled ←
    Loam.ScheduledReview.loadHouseholdEvidenceForEvents dataDir image.currentEvents
  let attentionResult ←
    Loam.AttentionReview.loadEvidence (Loam.HouseholdPaths.attention dataDir)
  let attention : Loam.Presentation.ReadState Loam.AttentionReview.Snapshot :=
    match attentionResult with
    | .error message => .failed message
    | .ok .unavailable => .unavailable
    | .ok (.available snapshot) => .loaded snapshot
  let paceResult ←
    Loam.CycleSpendingPaceReview.loadSnapshotFromActualImageAt dataDir image today
  let pace := Loam.Presentation.ReadState.fromExcept paceResult
  let paceHistoryResult ←
    Loam.CycleSpendingPaceReview.loadHistoryFromActualImageAt dataDir image today 7
  let paceHistory := Loam.Presentation.ReadState.fromExcept paceHistoryResult
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
def actualWorkspaceEventOfKey : Loam.Tui.Terminal.Key → Loam.Tui.ActualWorkspace.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .input 'f' | .input 'F' => .cycleFilter
  | .input 's' | .input 'S' => .cycleOrder
  | .input 'n' | .input 'N' => .recordNew
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other

/-- Actual workspace session. `q` returns to Home; `n` reuses the shared Movement writer. -/
partial def actualWorkspaceLoop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : Loam.Tui.ActualWorkspace.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.ActualWorkspace.update snapshot state
    (actualWorkspaceEventOfKey (← Loam.Tui.Terminal.readKey))
  match step.command with
  | .back => return snapshot
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
          (Loam.Tui.Record.initial state.focusDate) catalog)
        measurePresentation
      let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.RecordSession.run bounds root world known editor editorFrame
      let fresh ← requireReload notice (loadSnapshot dataDir)
      let refreshed := Loam.Tui.ActualWorkspace.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      actualWorkspaceLoop bounds dataDir root fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      actualWorkspaceLoop bounds dataDir root snapshot step.state nextFrame

/-- Read-only balance-view session; q/Esc returns to Home. -/
partial def balancesLoop (bounds : Bounds)
    (state : Loam.Tui.Balances.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let back := key = .escape || key = .input 'q' || key = .input 'Q'
  match Loam.Tui.Balances.update state back with
  | .back => return ()
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Balances.view next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      balancesLoop bounds next nextFrame

/-- Current quantity observations stay presentation-local until one complete image is published. -/
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

partial def loop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .enter then
    let day := Loam.Tui.SelectedDay.initial state.selectedDate
    let dayFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot day)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame dayFrame
    let fresh ← Loam.Tui.SelectedDaySession.run
      bounds dataDir root (loadSnapshot dataDir) snapshot day dayFrame
    let home := { state with notice := "" }
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
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame adminFrame
    let notice ← Loam.Tui.LocusAdmissionAdministrationSession.run
      bounds dataDir root admin adminFrame
    let home := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'a' || key = .input 'A') then
    let metadata ← currentLocusMetadata dataDir
    let actual := Loam.Tui.ActualWorkspace.withMetadata
      (Loam.Tui.ActualWorkspace.initial state.selectedDate) metadata
    let actualFrame := compileWidget (Loam.Tui.ActualWorkspace.view bounds snapshot actual)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame actualFrame
    let fresh ← actualWorkspaceLoop bounds dataDir root snapshot actual actualFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if (key = .input 's' || key = .input 'S') then
    let scheduled := Loam.Tui.ScheduledWorkspace.initial state.selectedDate
    let scheduledFrame := compileWidget (Loam.Tui.ScheduledWorkspace.view bounds snapshot scheduled)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame scheduledFrame
    let fresh ← Loam.Tui.ScheduledWorkspaceSession.run
      bounds dataDir root (loadSnapshot dataDir) snapshot scheduled scheduledFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if (key = .input 'i' || key = .input 'I') then
    match ← Loam.AttentionReview.loadEvidence (Loam.HouseholdPaths.attention root) with
    | .error message =>
        let home := { state with notice := unavailableNotice "Attention" message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok evidence =>
        let admin := Loam.Tui.AttentionAdministration.initial evidence snapshot.actual.today
        let adminFrame := compileWidget (Loam.Tui.AttentionAdministration.view admin)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame adminFrame
        Loam.Tui.AttentionAdministrationSession.run bounds root admin adminFrame
        let fresh ← requireReload "Attention administration completed." (loadSnapshot dataDir)
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor bounds fresh home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root fresh home nextFrame
  else if (key = .input 'b' || key = .input 'B') then
    match ← Loam.BalanceReview.loadSnapshot dataDir root with
    | .error message =>
        let home := { state with notice := unavailableNotice "Balances" message }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        loop bounds dataDir root snapshot home nextFrame
    | .ok balanceSnapshot =>
        let balances := Loam.Tui.Balances.initial balanceSnapshot
        let balancesFrame := compileWidget (Loam.Tui.Balances.view balances)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame balancesFrame
        balancesLoop bounds balances balancesFrame
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root snapshot home nextFrame
  else if Loam.Tui.CycleBudget.isHomeEntrance key then
    let answer ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root snapshot.actual.today
    let purposeMetadata ← currentPurposeMetadata dataDir
    let budget := Loam.Tui.CycleBudget.withPurposeMetadata purposeMetadata
      ({ snapshot := answer } : Loam.Tui.CycleBudget.State)
    let budgetFrame := compileWidget (Loam.Tui.CycleBudget.view bounds budget)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame budgetFrame
    Loam.Tui.CycleBudgetSession.run bounds dataDir root budget budgetFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'p' || key = .input 'P') then
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
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame administrationFrame
        let notice ← Loam.Tui.ActualRoutingAdministrationSession.run
          bounds root administration administrationFrame
        let home := { state with notice := notice }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'e' || key = .input 'E') then
    match ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir with
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
    let editor := Loam.Tui.CurrentQuantityAnchor.initial
    let editorFrame := compileWidget (Loam.Tui.CurrentQuantityAnchor.view editor)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
    let notice ← currentQuantityAnchorLoop bounds root editor editorFrame
    let home := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 'v' || key = .input 'V') then
    let reports ←
      match ← Loam.BoundaryPresetConfig.load? (Loam.HouseholdPaths.boundaryPresets dataDir) with
      | some presets =>
          pure (Loam.Tui.Reports.initialForDateWithPresets state.selectedDate presets)
      | none =>
          let base := Loam.Tui.Reports.initialForDate state.selectedDate
          pure { base with
            notice := "Boundary preset config malformed; named presets unavailable." }
    let reportsFrame := compileWidget (Loam.Tui.Reports.viewForBounds bounds reports)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame reportsFrame
    Loam.Tui.ReportsSession.run bounds dataDir root reports reportsFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (key = .input 't' || key = .input 'T') then
    let home :=
      { state with selectedDate := snapshot.actual.today, notice := "", detailScroll := 0 }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    loop bounds dataDir root snapshot home nextFrame
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
        (Loam.Tui.Record.initial state.selectedDate) catalog)
      measurePresentation
    let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
    let notice ← Loam.Tui.RecordSession.run bounds root world known editor editorFrame
    let fresh ← requireReload notice (loadSnapshot dataDir)
    let destination := { state with notice := notice }
    let nextFrame := compiledFrameFor bounds fresh destination
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh destination nextFrame
  else if let some forward := Loam.Tui.Home.detailScrollDirection? bounds key then
    let home := Loam.Tui.Home.scrollWideDetail bounds snapshot state forward
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    loop bounds dataDir root snapshot home nextFrame
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
    let state := initialState snapshot.actual.today
    let frame := compiledFrameFor bounds snapshot state
    let blank := compileWidget (.row [])
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 blank frame
    loop bounds dataDir root snapshot state frame
    return 0
  finally
    Loam.Tui.Terminal.leave
    Loam.Tui.FavaLaunch.shutdown

end Loam.Tui.Cli
