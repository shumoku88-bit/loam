import Loam.Authority.ActualAuthority
import Loam.HouseholdCommand
import Loam.Presentation.LocusCatalog
import Loam.Presentation.MeasurePresentation
import Loam.Persistence.TokenSyntax
import Loam.MovementWorldLoader
import Loam.Tui.ActualDateCorrection
import Loam.Tui.ActualReversal
import Loam.Tui.ActualReversalSession
import Loam.Tui.Correction
import Loam.Tui.CorrectionSession
import Loam.Tui.EventMerchant
import Loam.Tui.EditorSession
import Loam.Tui.LocusAdmissionAdministration
import Loam.Tui.LocusAdmissionAdministrationSession
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.ModalSurface
import Loam.Tui.Record
import Loam.Tui.RecordSession
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledCancellationSession
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledCompletionSession
import Loam.Tui.ScheduledContinuationSession
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.ScheduledReplacement
import Loam.Tui.ScheduledReplacementSession
import Loam.Tui.SelectedDay
import Loam.Tui.Terminal

namespace Loam.Tui.SelectedDaySession

open Loam.Tui.Kernel
open Loam.Tui.Runtime
open Loam.Tui.Main

set_option autoImplicit false

/-!
# Selected Day / single-transaction session

Owns only the terminal/session lifetime for the dated browser and focused Event entrance.
Shared Home snapshot evidence remains the read source. Record, correction,
reversal, Scheduled, date, and Merchant publication continue through their
existing writer/session boundaries.
-/

private def currentMeasurePresentation
    (dataDir : System.FilePath) : IO (List Loam.MeasurePresentation.Metadata) := do
  match ← Loam.MeasurePresentation.loadMetadata dataDir with
  | .ok metadata => return metadata
  | .error message => throw (IO.userError message)

private def configuredMeasure : IO Loam.Core.MeasureId := do
  let token := (← IO.getEnv "LOAM_MEASURE").getD "jpy"
  if !Loam.Persistence.validToken token then
    throw (IO.userError "loam: Measure must be a nonempty single-line token")
  pure ⟨token⟩

private def currentLocusCatalog
    (dataDir : System.FilePath) (world : Loam.MovementAdmission.World) :
    IO Loam.LocusCatalog.Catalog := do
  match ← Loam.LocusCatalog.loadForVocabulary dataDir world.locusAdmission with
  | .ok catalog => return catalog
  | .error _ => return Loam.LocusCatalog.fallback world.locusAdmission

private def requireReload {α : Type} (notice : String)
    (reload : IO (Except String α)) : IO α := do
  match ← reload with
  | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
  | .ok value => pure value

/-- HRA-shaped one-date grammar; object-local verbs depend on the active pane. -/
def eventOfKey
    (pane : Loam.Tui.SelectedDay.Pane) :
    Loam.Tui.Terminal.Key → Loam.Tui.SelectedDay.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .pageUp | .ctrl 'u' => .pageUp
  | .pageDown | .ctrl 'd' => .pageDown
  | .home => .home
  | .«end» => .«end»
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .tab | .shiftTab | .input 'i' | .input 'I' => .focusDetails
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
  | .input 'g' | .input 'G' => .manageLoci
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other


/-- Date editing retains its exact publisher and Selected Day reload boundary.
    Terminal geometry/resize mechanics are shared with Actual reversal. -/
def actualDateCorrectionLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.ActualDateCorrection.State) (frame : CompiledWidget)
    (parent : Bounds → CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilPublishedAdaptive bounds
    Loam.Tui.ActualDateCorrection.floatingGeometry?
    parent
    Loam.Tui.ActualDateCorrection.updateForBounds
    Loam.Tui.ActualDateCorrection.viewForBounds
    Loam.Tui.ActualDateCorrection.withPublishError
    "Date correction cancelled."
    (fun draft => do
      match ← Loam.HouseholdCommand.correctActualDate root draft with
      | .ok () => return .ok ("Date set to " ++ draft.validOn ++ ".")
      | .error message => return .error message)
    state frame


/-- Classification-specific publisher and reload stay here. Only the
    adaptive terminal lifecycle is shared with Actual date and reversal. -/
def eventMerchantLoop
    (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.EventMerchant.State) (frame : CompiledWidget)
    (parent : Bounds → CompiledWidget) : IO String :=
  Loam.Tui.EditorSession.runUntilPublishedAdaptive bounds
    Loam.Tui.EventMerchant.floatingGeometry?
    parent
    (fun active editor key =>
      Loam.Tui.EventMerchant.updateForBounds
        (Loam.Tui.EventMerchant.editorBounds active) editor key)
    Loam.Tui.EventMerchant.viewForBounds
    Loam.Tui.EventMerchant.withPublishError
    "Merchant classification cancelled."
    (fun draft => do
      match ← Loam.HouseholdCommand.classifyEventMerchant root draft with
      | .ok () => return .ok
          ("Published " ++ Loam.Tui.EventMerchant.dispositionText draft.disposition ++
            " for " ++ draft.target.token ++ ".")
      | .error message => return .error message)
    state frame


/-- Both entrances use the same editors, confirmations, publishers and required reloads.
    SelectedDay resolves focused actions by Event ID, never a neighboring day row. -/
partial def run (bounds : Bounds) (dataDir root : System.FilePath)
    (reload : IO (Except String Snapshot))
    (snapshot : Snapshot) (state : Loam.Tui.SelectedDay.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let (key, repeatCount) ← Loam.Tui.Terminal.readKeyWithRepeat
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.SelectedDay.view active snapshot state)
  let step := Loam.Tui.SelectedDay.updateForBounds bounds snapshot state
    (eventOfKey state.pane key) repeatCount
  match step.command with
  | .back => return snapshot
  | .manageLoci =>
      let world ←
        match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let catalog ← currentLocusCatalog dataDir world
      let admin := Loam.Tui.LocusAdmissionAdministration.initial catalog
      let adminFrame :=
        compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds admin)
      Loam.Tui.Terminal.redrawFromBlank bounds adminFrame
      let notice ← Loam.Tui.LocusAdmissionAdministrationSession.run
        bounds dataDir root admin adminFrame
      let bounds ← Loam.Tui.Terminal.currentBounds
      let fresh ← requireReload notice reload
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      run bounds dataDir root reload fresh next nextFrame
  | .createScheduled =>
      let world ←
        match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := world.locusAdmission.approved.map (fun locus => locus.token)
      let catalog ← currentLocusCatalog dataDir world
      let editor := Loam.Tui.ScheduledCreation.withCatalog
        (Loam.Tui.ScheduledCreation.initial step.state.focusDate) catalog
      let notice ← Loam.Tui.ScheduledCreationSession.runAdaptive
        bounds dataDir root known editor (fun active =>
          compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state))
      let bounds ← Loam.Tui.Terminal.currentBounds
      let fresh ← requireReload notice reload
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      run bounds dataDir root reload fresh next nextFrame
  | .completeScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for completion." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.ScheduledCompletion.initialWithPresentation?
              measurePresentation record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let completed ← Loam.Tui.ScheduledCompletionSession.runAdaptive
                bounds root world known editor (fun active =>
                  compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state))
              let bounds ← Loam.Tui.Terminal.currentBounds
              let notice ←
                if !completed then
                  pure "Scheduled completion cancelled."
                else
                  Loam.Tui.ScheduledContinuationSession.runAfterCompletion
                    bounds root known record snapshot.actual.today
                    (currentLocusCatalog dataDir world)
              let bounds ← Loam.Tui.Terminal.currentBounds
              let fresh ← requireReload notice reload
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .cancelScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for cancellation." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let confirmation := Loam.Tui.ScheduledCancellation.initial record
          let notice ← Loam.Tui.ScheduledCancellationSession.runAdaptive
            bounds root confirmation (fun active =>
              compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state))
          let bounds ← Loam.Tui.Terminal.currentBounds
          let fresh ← requireReload notice reload
          let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload fresh next nextFrame
  | .replaceScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for supersede." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          match Loam.Tui.ScheduledReplacement.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let notice ← Loam.Tui.ScheduledReplacementSession.runAdaptive
                bounds root known editor (fun active =>
                  compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state))
              let bounds ← Loam.Tui.Terminal.currentBounds
              let fresh ← requireReload notice reload
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .correctDate =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for date correction." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          match Loam.Tui.ActualDateCorrection.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot next nextFrame
          | .ok editor =>
              let parent := fun active =>
                compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state)
              let active ← Loam.Tui.Terminal.currentBounds
              let region := Loam.Tui.ActualDateCorrection.floatingGeometry? active
              let editorFrame := compileWidget (Loam.Tui.ActualDateCorrection.viewForBounds active editor)
              if active == bounds then
                Loam.Tui.ModalSurface.paint active region .fromBlank
                  (compileWidget (.row [])) editorFrame
              else
                Loam.Tui.ModalSurface.repaintOverParent active region (parent active) editorFrame
              let notice ← actualDateCorrectionLoop
                active root editor editorFrame parent
              let bounds ← Loam.Tui.Terminal.currentBounds
              let fresh ← requireReload notice reload
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .classifyMerchant =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for Merchant classification." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
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
              run bounds dataDir root reload snapshot next nextFrame
          | none =>
              let editor := Loam.Tui.EventMerchant.initial record
              let parent := fun active =>
                compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state)
              let active ← Loam.Tui.Terminal.currentBounds
              let region := Loam.Tui.EventMerchant.floatingGeometry? active
              let editorFrame := compileWidget (Loam.Tui.EventMerchant.viewForBounds active editor)
              if active == bounds then
                Loam.Tui.ModalSurface.paint active region .fromBlank
                  (compileWidget (.row [])) editorFrame
              else
                Loam.Tui.ModalSurface.repaintOverParent active region (parent active) editorFrame
              let notice ← eventMerchantLoop active root editor editorFrame parent
              let bounds ← Loam.Tui.Terminal.currentBounds
              let fresh ← requireReload notice reload
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .correctActual =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for correction." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.Correction.initialWithPresentation? measurePresentation record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot next nextFrame
          | .ok rawEditor =>
              let world ←
                match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := world.locusAdmission.approved.map (fun locus => locus.token)
              let catalog ← currentLocusCatalog dataDir world
              let editor := {
                rawEditor with
                editor := Loam.Tui.Record.withCatalog rawEditor.editor catalog
              }
              let editorFrame := compileWidget (Loam.Tui.Correction.view bounds known editor)
              Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
              let notice ← Loam.Tui.CorrectionSession.run bounds root
                world known editor editorFrame
              let bounds ← Loam.Tui.Terminal.currentBounds
              let fresh ← requireReload notice reload
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .reverseActual =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for reversal." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          match Loam.Tui.ActualReversal.initial? record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot next nextFrame
          | .ok editor =>
              let parent := fun active =>
                compileWidget (Loam.Tui.SelectedDay.view active snapshot step.state)
              let active ← Loam.Tui.Terminal.currentBounds
              let region := Loam.Tui.ActualReversal.floatingGeometry? active
              let editorFrame := compileWidget (Loam.Tui.ActualReversal.viewForBounds active editor)
              if active == bounds then
                Loam.Tui.ModalSurface.paint active region .fromBlank
                  (compileWidget (.row [])) editorFrame
              else
                Loam.Tui.ModalSurface.repaintOverParent active region (parent active) editorFrame
              let notice ← Loam.Tui.ActualReversalSession.runAdaptive
                active root editor editorFrame parent
              let bounds ← Loam.Tui.Terminal.currentBounds
              let fresh ← requireReload notice reload
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
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
          (Loam.Tui.Record.initialWithMeasure (← configuredMeasure) state.focusDate) catalog)
        measurePresentation
      let editorFrame := compileWidget (Loam.Tui.Record.viewForBounds bounds known editor)
      Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
      let result ← Loam.Tui.RecordSession.run bounds root world known editor editorFrame
      let bounds ← Loam.Tui.Terminal.currentBounds
      let notice := result.notice
      let fresh ←
        if result.requiresReload then requireReload notice reload
        else pure snapshot
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      run bounds dataDir root reload fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds dataDir root reload snapshot step.state nextFrame


end Loam.Tui.SelectedDaySession
