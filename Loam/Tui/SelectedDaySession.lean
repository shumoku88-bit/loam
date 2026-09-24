import Loam.ActualAuthority
import Loam.HouseholdCommand
import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.MovementWorldLoader
import Loam.Tui.ActualDateCorrection
import Loam.Tui.ActualReversal
import Loam.Tui.ActualReversalSession
import Loam.Tui.Correction
import Loam.Tui.CorrectionSession
import Loam.Tui.EventMerchant
import Loam.Tui.Kernel
import Loam.Tui.Main
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
# Selected Day workspace session

Owns only the terminal/session lifetime for the existing one-date presentation.
Shared Home snapshot evidence remains the read source. Record, correction,
reversal, Scheduled, date, and Merchant publication continue through their
existing writer/session boundaries.
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


/-- Selected-day session. Shared reads remain the workspace source; writes are delegated. -/
partial def run (bounds : Bounds) (dataDir root : System.FilePath)
    (reload : IO (Except String Snapshot))
    (snapshot : Snapshot) (state : Loam.Tui.SelectedDay.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.SelectedDay.update snapshot state
    (eventOfKey state.pane (← Loam.Tui.Terminal.readKey))
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
          let confirmationFrame := compileWidget (Loam.Tui.ScheduledCancellation.view confirmation)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame confirmationFrame
          let notice ← Loam.Tui.ScheduledCancellationSession.run
            bounds root confirmation confirmationFrame
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
              let editorFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← Loam.Tui.ScheduledReplacementSession.run
                bounds root known editor editorFrame
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
              let editorFrame := compileWidget (Loam.Tui.ActualDateCorrection.view editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← actualDateCorrectionLoop
                bounds root editor editorFrame
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
              let editorFrame := compileWidget (Loam.Tui.EventMerchant.view editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← eventMerchantLoop bounds root editor editorFrame
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
              let editorFrame := compileWidget (Loam.Tui.ActualReversal.view editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← Loam.Tui.ActualReversalSession.run
                bounds root
                  editor editorFrame
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
          (Loam.Tui.Record.initial state.focusDate) catalog)
        measurePresentation
      let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.RecordSession.run bounds root world known editor editorFrame
      let fresh ← requireReload notice reload
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
