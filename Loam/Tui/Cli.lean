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
import Loam.Tui.Correction
import Loam.Tui.CorrectionSession
import Loam.Tui.ActualDateCorrection
import Loam.Tui.EventMerchant
import Loam.Tui.ActualReversal
import Loam.Tui.ActualReversalSession
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledCompletionSession
import Loam.Tui.ScheduledContinuationSession
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledReplacement
import Loam.Tui.ScheduledReplacementSession
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.ScheduledGeneration
import Loam.Tui.ScheduledGenerationSession
import Loam.Tui.ScheduledCoverageSetupSession
import Loam.ScheduledCoverageReview
import Loam.Tui.AttentionAdministration
import Loam.Tui.AttentionAdministrationSession
import Loam.Tui.Balances
import Loam.Tui.Capacity
import Loam.Tui.CycleBudget
import Loam.CycleSpendingPaceReview
import Loam.Tui.CapacityTransfer
import Loam.Tui.CapacityTransferSession
import Loam.Tui.CapacityRebalance
import Loam.Tui.CapacityRebalanceSession
import Loam.Tui.CurrentQuantityAnchor
import Loam.Tui.ScheduledRouting
import Loam.Tui.ScheduledRoutingSession
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.ActualRoutingAdministrationSession
import Loam.Tui.Reports
import Loam.Tui.FavaLaunch
import Loam.BoundaryPresetConfig
import Loam.Tui.CompletionPrompt
import Loam.ActualDate
import Loam.ActualReview
import Loam.ScheduledReview
import Loam.AttentionReview
import Loam.BalanceReview
import Loam.CapacityReview
import Loam.CurrentCoverageReview
import Loam.ActualRoutingReview
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.StockFlowReview
import Loam.TransactionsFlowReview
import Loam.RoleFlowReview
import Loam.RoleBalanceReview
import Loam.Tui.Main
import Loam.Tui.HraHome
import Loam.Tui.HraActual
import Loam.Tui.HraScheduled
import Loam.Tui.SelectedDay
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

private def loadSnapshot (dataDir : System.FilePath) : IO (Except String Snapshot) := do
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local date"
  let actualRecords ←
    match ← Loam.ActualReview.loadRecordsFromActual dataDir with
    | .error message => return .error message
    | .ok records => pure records
  let scheduled ←
    Loam.ScheduledReview.loadHouseholdEvidence dataDir dataDir
  let pace ←
    Loam.CycleSpendingPaceReview.loadSnapshotAt dataDir dataDir today
  let actual : ActualSnapshot := {
    today := today
    allRecords := actualRecords
  }
  return .ok { actual := actual, scheduled := scheduled, pace := pace }

private def requireReload {α : Type} (notice : String)
    (reload : IO (Except String α)) : IO α := do
  match ← reload with
  | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
  | .ok value => pure value

private def unavailableNotice (subject message : String) : String :=
  "[Unavailable] " ++ subject ++ ": " ++ message

/-- Current Capacity and Budget share one explicit preset selection boundary. -/
private def attachCurrentCoverage
    (dataDir root : System.FilePath)
    (observedAt : String)
    (state : Loam.Tui.Capacity.State) : IO Loam.Tui.Capacity.State := do
  match ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt with
  | .error message => return Loam.Tui.Capacity.withoutCoverage message state
  | .ok window =>
    match ← Loam.CurrentCoverageReview.loadSnapshotAt
        dataDir root window.start observedAt window.endExclusive with
    | .error message => return Loam.Tui.Capacity.withoutCoverage message state
    | .ok coverage =>
      return Loam.Tui.Capacity.withCoverage coverage ("preset " ++ window.source) state


def compiledFrameFor (bounds : Bounds) (snapshot : Snapshot) (state : State) : CompiledWidget :=
  compileWidget (Loam.Tui.HraHome.view bounds snapshot state)


theorem compiledFrameFor_spec (bounds : Bounds) (snapshot : Snapshot) (state : State) :
    (compiledFrameFor bounds snapshot state).toScreen bounds 0 0 =
      renderAt bounds 0 0 (Loam.Tui.HraHome.view bounds snapshot state) := by
  simpa [compiledFrameFor] using
    compileWidget_spec bounds 0 0 (Loam.Tui.HraHome.view bounds snapshot state)


def eventOfKey : Loam.Tui.Terminal.Key → Event
  | .left => .left
  | .right => .right
  | .up => .up
  | .down => .down
  | .input 'q' => .quit
  | .input 'Q' => .quit
  | _ => .other

/-- HRA's Home navigation grammar, with arrows retained as equivalent navigation keys. -/
def homeEventOfKey : Loam.Tui.Terminal.Key → Event
  | .input 'h' | .input 'H' => .left
  | .input 'l' | .input 'L' => .right
  | .input 'k' | .input 'K' => .up
  | .input 'j' | .input 'J' => .down
  | key => eventOfKey key

/-- HRA Scheduled interaction grammar over presentation-only pane and cursor state. -/
def hraScheduledEventOfKey
    (pane : Loam.Tui.HraScheduled.Pane) :
    Loam.Tui.Terminal.Key → Loam.Tui.HraScheduled.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .input 'f' | .input 'F' => .cycleFilter
  | .input 'n' | .input 'N' => .createScheduled
  | .input 'g' | .input 'G' => .fillCurrentCycle
  | .input 'm' | .input 'M' => .monitorCoverage
  | .input 'c' | .input 'C' => .completeScheduled
  | .enter =>
      match pane with
      | .loci => .other
      | .occurrences => .completeScheduled
  | .input 'r' | .input 'R' => .replaceScheduled
  | .input 'x' | .input 'X' => .cancelScheduled
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other

/-- HRA Actual interaction grammar over presentation-only pane and cursor state. -/
def hraActualEventOfKey : Loam.Tui.Terminal.Key → Loam.Tui.HraActual.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .input 'f' | .input 'F' => .cycleFilter
  | .input 's' | .input 'S' => .cycleOrder
  | .input 'n' | .input 'N' => .recordNew
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other

/-- HRA-shaped one-date grammar; object-local verbs depend on the active pane. -/
def selectedDayEventOfKey
    (pane : Loam.Tui.SelectedDay.Pane) :
    Loam.Tui.Terminal.Key → Loam.Tui.SelectedDay.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .input 'n' | .input 'N' =>
      match pane with
      | .actual => .recordNew
      | .scheduled => .createScheduled
  | .input 'c' | .input 'C' =>
      match pane with
      | .actual => .correctActual
      | .scheduled => .completeScheduled
  | .enter =>
      match pane with
      | .actual => .other
      | .scheduled => .completeScheduled
  | .input 'r' | .input 'R' =>
      match pane with
      | .actual => .reverseActual
      | .scheduled => .replaceScheduled
  | .input 'x' | .input 'X' => .cancelScheduled
  | .input 'd' | .input 'D' => .correctDate
  | .input 'm' | .input 'M' => .classifyMerchant
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other

/-- Date editing stays local; the shared publisher performs every authoritative re-check. -/
partial def actualDateCorrectionLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ActualDateCorrection.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ActualDateCorrection.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Date correction cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.correctActualDate root draft with
      | .ok () =>
          return "Date set to " ++ draft.validOn ++ "."
      | .error message =>
          let next := Loam.Tui.ActualDateCorrection.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ActualDateCorrection.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          actualDateCorrectionLoop bounds root next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ActualDateCorrection.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      actualDateCorrectionLoop bounds root step.state nextFrame

/-- Merchant editing stays local; canonical first-classification semantics remain in the publisher. -/
partial def eventMerchantLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.EventMerchant.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.EventMerchant.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Merchant classification cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.classifyEventMerchant root draft with
      | .ok () =>
          return "Published " ++ Loam.Tui.EventMerchant.dispositionText draft.disposition ++
            " for " ++ draft.target.token ++ "."
      | .error message =>
          let next := Loam.Tui.EventMerchant.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.EventMerchant.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          eventMerchantLoop bounds root next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.EventMerchant.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      eventMerchantLoop bounds root step.state nextFrame

/-- Cancellation confirmation is presentation-only; publisher refusal returns to fresh day evidence. -/
partial def scheduledCancellationLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ScheduledCancellation.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCancellation.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled cancellation kept the occurrence open."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.cancelScheduled root draft with
      | .ok () => return "Cancelled " ++ draft.scheduled.token ++ "."
      | .error message => return "Scheduled cancellation refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCancellation.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      scheduledCancellationLoop bounds root step.state nextFrame

/-- HRA-shaped Actual session. `q` returns to Home; `n` reuses the shared Movement writer. -/
partial def hraActualLoop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : Loam.Tui.HraActual.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.HraActual.update snapshot state
    (hraActualEventOfKey (← Loam.Tui.Terminal.readKey))
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
      let refreshed := Loam.Tui.HraActual.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.HraActual.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      hraActualLoop bounds dataDir root fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.HraActual.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      hraActualLoop bounds dataDir root snapshot step.state nextFrame

/-- HRA-shaped Scheduled session. `q` returns to Home; creation/completion/replacement/cancellation are delegated. -/
partial def hraScheduledLoop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : Loam.Tui.HraScheduled.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.HraScheduled.update snapshot state
    (hraScheduledEventOfKey state.pane (← Loam.Tui.Terminal.readKey))
  match step.command with
  | .back => return snapshot
  | .createScheduled =>
      let world ←
        match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := world.locusAdmission.approved.map (fun locus => locus.token)
      let catalog ← currentLocusCatalog dataDir world
      let editor := Loam.Tui.ScheduledCreation.withCatalog
        (Loam.Tui.ScheduledCreation.initial step.state.focusDate) catalog
      let editorFrame := compileWidget (Loam.Tui.ScheduledCreation.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.ScheduledCreationSession.run
        bounds root known editor editorFrame
      let fresh ← requireReload notice (loadSnapshot dataDir)
      let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      hraScheduledLoop bounds dataDir root fresh next nextFrame
  | .fillCurrentCycle =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is selected as the cycle-fill source." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          hraScheduledLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let world ←
            match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
            | .error message => throw (IO.userError message)
            | .ok world => pure world
          let known := world.locusAdmission.approved.map (fun locus => locus.token)
          let catalog ← currentLocusCatalog dataDir world
          let notice ← Loam.Tui.ScheduledGenerationSession.run
            bounds dataDir root known catalog record snapshot.actual.today
          let fresh ← requireReload notice (loadSnapshot dataDir)
          let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          hraScheduledLoop bounds dataDir root fresh next nextFrame
  | .monitorCoverage =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is selected for monitoring." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          hraScheduledLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let notice ← Loam.Tui.ScheduledCoverageSetupSession.run bounds dataDir record
          let next := { step.state with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          hraScheduledLoop bounds dataDir root snapshot next nextFrame
  | .completeScheduled =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for completion." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          hraScheduledLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.ScheduledCompletion.initialWithPresentation?
              measurePresentation record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              hraScheduledLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let editorFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let completed ← Loam.Tui.ScheduledCompletionSession.run
                bounds root world known editor editorFrame
              let notice ←
                if !completed then
                  pure "Scheduled completion cancelled."
                else
                  Loam.Tui.ScheduledContinuationSession.runAfterCompletion
                    bounds root known record snapshot.actual.today
                    (currentLocusCatalog dataDir world)
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              hraScheduledLoop bounds dataDir root fresh next nextFrame
  | .cancelScheduled =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for cancellation." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          hraScheduledLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let confirmation := Loam.Tui.ScheduledCancellation.initial record
          let confirmationFrame := compileWidget (Loam.Tui.ScheduledCancellation.view confirmation)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame confirmationFrame
          let notice ← scheduledCancellationLoop
            bounds root confirmation confirmationFrame
          let fresh ← requireReload notice (loadSnapshot dataDir)
          let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          hraScheduledLoop bounds dataDir root fresh next nextFrame
  | .replaceScheduled =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for supersede." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          hraScheduledLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.ScheduledReplacement.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              hraScheduledLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let editorFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← Loam.Tui.ScheduledReplacementSession.run
                bounds root known editor editorFrame
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              hraScheduledLoop bounds dataDir root fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      hraScheduledLoop bounds dataDir root snapshot step.state nextFrame

/-- Selected-day session. Shared reads remain the workspace source; writes are delegated. -/
partial def selectedDayLoop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : Loam.Tui.SelectedDay.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.SelectedDay.update snapshot state
    (selectedDayEventOfKey state.pane (← Loam.Tui.Terminal.readKey))
  match step.command with
  | .back => return snapshot
  | .createScheduled =>
      let world ←
        match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := world.locusAdmission.approved.map (fun locus => locus.token)
      let catalog ← currentLocusCatalog dataDir world
      let editor := Loam.Tui.ScheduledCreation.withCatalog
        (Loam.Tui.ScheduledCreation.initial step.state.focusDate) catalog
      let editorFrame := compileWidget (Loam.Tui.ScheduledCreation.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.ScheduledCreationSession.run
        bounds root known editor editorFrame
      let fresh ← requireReload notice (loadSnapshot dataDir)
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      selectedDayLoop bounds dataDir root fresh next nextFrame
  | .completeScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for completion." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.ScheduledCompletion.initialWithPresentation?
              measurePresentation record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let editorFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let completed ← Loam.Tui.ScheduledCompletionSession.run
                bounds root world known editor editorFrame
              let notice ←
                if !completed then
                  pure "Scheduled completion cancelled."
                else
                  Loam.Tui.ScheduledContinuationSession.runAfterCompletion
                    bounds root known record snapshot.actual.today
                    (currentLocusCatalog dataDir world)
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .cancelScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for cancellation." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let confirmation := Loam.Tui.ScheduledCancellation.initial record
          let confirmationFrame := compileWidget (Loam.Tui.ScheduledCancellation.view confirmation)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame confirmationFrame
          let notice ← scheduledCancellationLoop
            bounds root confirmation confirmationFrame
          let fresh ← requireReload notice (loadSnapshot dataDir)
          let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          selectedDayLoop bounds dataDir root fresh next nextFrame
  | .replaceScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for supersede." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.ScheduledReplacement.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let editorFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← Loam.Tui.ScheduledReplacementSession.run
                bounds root known editor editorFrame
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .correctDate =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for date correction." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.ActualDateCorrection.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let editorFrame := compileWidget (Loam.Tui.ActualDateCorrection.view editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← actualDateCorrectionLoop
                bounds root editor editorFrame
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .classifyMerchant =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for Merchant classification." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let evidence ←
            match ← Loam.ActualAuthority.loadActual? root with
            | .ok evidence => pure evidence
            | .error message => throw (IO.userError message)
          match evidence.merchants.findDisposition? record.event.id with
          | some disposition =>
              let next := { step.state with
                notice := "Merchant already classified: " ++
                  Loam.Tui.EventMerchant.dispositionText disposition ++ "." }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | none =>
              let editor := Loam.Tui.EventMerchant.initial record
              let editorFrame := compileWidget (Loam.Tui.EventMerchant.view editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← eventMerchantLoop bounds root editor editorFrame
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .correctActual =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for correction." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.Correction.initialWithPresentation? measurePresentation record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let editorFrame := compileWidget (Loam.Tui.Correction.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← Loam.Tui.CorrectionSession.run bounds root
                world known editor editorFrame
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .reverseActual =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for reversal." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.ActualReversal.initial? record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let editorFrame := compileWidget (Loam.Tui.ActualReversal.view editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← Loam.Tui.ActualReversalSession.run
                bounds root
                  editor editorFrame
              let fresh ← requireReload notice (loadSnapshot dataDir)
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
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
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      selectedDayLoop bounds dataDir root fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      selectedDayLoop bounds dataDir root snapshot step.state nextFrame

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

/-- All-retained Capacity session with shared current coverage and a local transfer entrance. -/
partial def capacityLoop
    (bounds : Bounds) (dataDir root : System.FilePath)
    (observedAt : String)
    (state : Loam.Tui.Capacity.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let backKey := key = .escape || key = .input 'q' || key = .input 'Q'
  let event : Loam.Tui.Capacity.Event :=
    if backKey then .back
    else
      match key with
      | .up | .input 'k' | .input 'K' => .up
      | .down | .input 'j' | .input 'J' => .down
      | .input 't' | .input 'T' => .transfer
      | .input 'r' | .input 'R' => .rebalance
      | _ => .other
  match Loam.Tui.Capacity.update state event with
  | .back => return ()
  | .transfer current =>
      let editor := Loam.Tui.CapacityTransfer.initial
        current.snapshot observedAt (Loam.Tui.Capacity.selectedPurpose? current)
      let editorFrame := compileWidget (Loam.Tui.CapacityTransfer.view editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.CapacityTransferSession.run
        bounds root editor editorFrame
      let fresh ← requireReload notice (Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir)
      let refreshed := Loam.Tui.Capacity.refreshed fresh current
      let covered ← attachCurrentCoverage dataDir root observedAt refreshed
      let next := { covered with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      capacityLoop bounds dataDir root observedAt next nextFrame
  | .rebalance current =>
      let editor := Loam.Tui.CapacityRebalance.initial
        current.snapshot current.coverage observedAt (Loam.Tui.Capacity.selectedPurpose? current)
      let editorFrame := compileWidget (Loam.Tui.CapacityRebalance.view bounds editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.CapacityRebalanceSession.run
        bounds root editor editorFrame
      let fresh ← requireReload notice (Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir)
      let refreshed := Loam.Tui.Capacity.refreshed fresh current
      let covered ← attachCurrentCoverage dataDir root observedAt refreshed
      let next := { covered with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      capacityLoop bounds dataDir root observedAt next nextFrame
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      capacityLoop bounds dataDir root observedAt next nextFrame

/-- Current-cycle Budget composes shared actions without adding a second semantic engine. -/
partial def cycleBudgetLoop (bounds : Bounds) (dataDir root : System.FilePath)
    (state : Loam.Tui.CycleBudget.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let (next, intent) := Loam.Tui.CycleBudget.update bounds state key
  match intent with
  | .home => return ()
  | .stay =>
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    cycleBudgetLoop bounds dataDir root next nextFrame
  | .rebalance =>
    let notice ←
      match ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir with
      | .error message => pure ("Capacity unavailable: " ++ message)
      | .ok capacitySnapshot =>
        let coverage :=
          match state.snapshot.coverage with
          | .ok coverage => some coverage
          | .error _ => none
        let editor := Loam.Tui.CapacityRebalance.initial
          capacitySnapshot coverage state.snapshot.observedAt
        let editorFrame := compileWidget (Loam.Tui.CapacityRebalance.view bounds editor)
        Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
        Loam.Tui.CapacityRebalanceSession.run
          bounds root editor editorFrame
    let fresh ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root state.snapshot.observedAt
    let next := Loam.Tui.CycleBudget.refreshed fresh notice state
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    cycleBudgetLoop bounds dataDir root next nextFrame
  | .unresolved =>
    let notice ←
      match state.snapshot.coverage with
      | .error message => pure ("CurrentCoverage unavailable: " ++ message)
      | .ok coverage =>
        let routingState := Loam.Tui.ScheduledRouting.initial coverage state.snapshot.observedAt
        let routingFrame := compileWidget (Loam.Tui.ScheduledRouting.view bounds routingState)
        Loam.Tui.Terminal.redrawFromBlank bounds routingFrame
        Loam.Tui.ScheduledRoutingSession.run bounds root routingState routingFrame
    let fresh ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root state.snapshot.observedAt
    let next := Loam.Tui.CycleBudget.refreshed fresh notice state
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    cycleBudgetLoop bounds dataDir root next nextFrame
  | .grant row =>
    let notice ←
      match ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir with
      | .error message => pure ("Capacity unavailable: " ++ message)
      | .ok capacitySnapshot =>
        let residual :=
          match state.snapshot.funding with
          | .ok summary => some summary.residualBeforeUnresolved
          | .error _ => none
        let editor := Loam.Tui.CapacityTransfer.initialGrant
          capacitySnapshot state.snapshot.observedAt row residual
        let editorFrame := compileWidget (Loam.Tui.CapacityTransfer.view editor)
        Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
        Loam.Tui.CapacityTransferSession.run
          bounds root editor editorFrame
    let fresh ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root state.snapshot.observedAt
    let next := Loam.Tui.CycleBudget.refreshed fresh notice state
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    cycleBudgetLoop bounds dataDir root next nextFrame

/-- Reports session; q/Esc moves back one level and eventually returns Home. -/
partial def reportsLoop (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.Reports.updateForBounds bounds state key
  if step.back then return ()
  let next ←
    match step.query with
    | none => pure step.state
    | some (.budgetWindow start endExclusive) =>
        match ← Loam.BudgetWindowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withBudgetSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.stockFlow start endExclusive) =>
        match ← Loam.StockFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withStockFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.transactionsFlow start endExclusive) =>
        match ← Loam.TransactionsFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withTransactionsFlowSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.incomeExpenseFlow start endExclusive) =>
        match ← Loam.RoleFlowReview.loadSnapshot dataDir root start endExclusive with
        | .ok snapshot => pure (Loam.Tui.Reports.withIncomeExpenseSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some .roleBalances =>
        match ← Loam.RoleBalanceReview.loadSnapshot dataDir root with
        | .ok snapshot => pure (Loam.Tui.Reports.withRoleBalanceSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.conditionalLiquidity assumedCompleteThrough) =>
        match ← Loam.ConditionalBalancePathReview.loadSnapshot
            dataDir root assumedCompleteThrough with
        | .ok snapshot => pure (Loam.Tui.Reports.withLiquiditySnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some (.scheduledCoverage observedAt) =>
        match ← Loam.ScheduledCoverageReview.loadSnapshot
            dataDir root observedAt with
        | .ok snapshot => pure (Loam.Tui.Reports.withScheduledCoverageSnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
    | some .favaProjection =>
        let notice ← Loam.Tui.FavaLaunch.launch dataDir root
        pure { step.state with notice := notice }
  let nextFrame := compileWidget (Loam.Tui.Reports.viewForBounds bounds next)
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
  reportsLoop bounds dataDir root next nextFrame

partial def loop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .enter then
    let day := Loam.Tui.SelectedDay.initial state.selectedDate
    let dayFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot day)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame dayFrame
    let fresh ← selectedDayLoop bounds dataDir root snapshot day dayFrame
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
    let actual := Loam.Tui.HraActual.withMetadata
      (Loam.Tui.HraActual.initial state.selectedDate) metadata
    let actualFrame := compileWidget (Loam.Tui.HraActual.view bounds snapshot actual)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame actualFrame
    let fresh ← hraActualLoop bounds dataDir root snapshot actual actualFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if (key = .input 's' || key = .input 'S') then
    let scheduled := Loam.Tui.HraScheduled.initial state.selectedDate
    let scheduledFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot scheduled)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame scheduledFrame
    let fresh ← hraScheduledLoop bounds dataDir root snapshot scheduled scheduledFrame
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if (key = .input 'i' || key = .input 'I') then
    match ← Loam.AttentionReview.loadEvidence (root / "attention.loam") with
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
        let home := { state with notice := "" }
        let nextFrame := compiledFrameFor bounds snapshot home
        Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
        loop bounds dataDir root snapshot home nextFrame
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
    cycleBudgetLoop bounds dataDir root budget budgetFrame
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
        let capacity ← attachCurrentCoverage dataDir root snapshot.actual.today baseCapacity
        let capacityFrame := compileWidget (Loam.Tui.Capacity.view capacity)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame capacityFrame
        capacityLoop bounds dataDir root snapshot.actual.today capacity capacityFrame
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
      match ← Loam.BoundaryPresetConfig.load? (dataDir / "config" / "boundary-presets.tsv") with
      | some presets =>
          pure (Loam.Tui.Reports.initialForDateWithPresets state.selectedDate presets)
      | none =>
          let base := Loam.Tui.Reports.initialForDate state.selectedDate
          pure { base with
            notice := "Boundary preset config malformed; named presets unavailable." }
    let reportsFrame := compileWidget (Loam.Tui.Reports.viewForBounds bounds reports)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame reportsFrame
    reportsLoop bounds dataDir root reports reportsFrame
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
  else if let some forward := Loam.Tui.HraHome.detailScrollDirection? bounds key then
    let home := Loam.Tui.HraHome.scrollWideDetail bounds snapshot state forward
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
