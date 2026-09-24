import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.MovementWorldLoader
import Loam.Tui.HraScheduled
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledCancellationSession
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledCompletionSession
import Loam.Tui.ScheduledContinuationSession
import Loam.Tui.ScheduledCoverageSetupSession
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.ScheduledGeneration
import Loam.Tui.ScheduledGenerationSession
import Loam.Tui.ScheduledReplacement
import Loam.Tui.ScheduledReplacementSession
import Loam.Tui.Terminal

namespace Loam.Tui.HraScheduledSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime
open Loam.Tui.Main

set_option autoImplicit false

/-!
# Scheduled workspace session

Owns only the terminal/session lifetime for the existing HRA-shaped Scheduled
presentation. Shared Review evidence stays in the Home snapshot, while creation,
completion, continuation, generation, replacement, coverage setup, and cancellation
remain delegated to their existing session/publisher owners.
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

def eventOfKey
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

/-- HRA-shaped Scheduled session. `q` returns to Home; mutations remain delegated. -/
partial def run
    (bounds : Bounds) (dataDir root : System.FilePath)
    (reload : IO (Except String Snapshot))
    (snapshot : Snapshot) (state : Loam.Tui.HraScheduled.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.HraScheduled.update snapshot state
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
      let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      run bounds dataDir root reload fresh next nextFrame
  | .fillCurrentCycle =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is selected as the cycle-fill source." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let world ←
            match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
            | .error message => throw (IO.userError message)
            | .ok world => pure world
          let known := world.locusAdmission.approved.map (fun locus => locus.token)
          let catalog ← currentLocusCatalog dataDir world
          let notice ← Loam.Tui.ScheduledGenerationSession.run
            bounds dataDir root known catalog record snapshot.actual.today
          let fresh ← requireReload notice reload
          let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload fresh next nextFrame
  | .monitorCoverage =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is selected for monitoring." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let notice ← Loam.Tui.ScheduledCoverageSetupSession.run bounds dataDir record
          let next := { step.state with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload snapshot next nextFrame
  | .completeScheduled =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for completion." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.ScheduledCompletion.initialWithPresentation?
              measurePresentation record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
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
              let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .cancelScheduled =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for cancellation." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          let confirmation := Loam.Tui.ScheduledCancellation.initial record
          let confirmationFrame := compileWidget (Loam.Tui.ScheduledCancellation.view confirmation)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame confirmationFrame
          let notice ← Loam.Tui.ScheduledCancellationSession.run
            bounds root confirmation confirmationFrame
          let fresh ← requireReload notice reload
          let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload fresh next nextFrame
  | .replaceScheduled =>
      match Loam.Tui.HraScheduled.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for supersede." }
          let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot next nextFrame
      | some record =>
          match Loam.Tui.ScheduledReplacement.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot next)
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
              let refreshed := Loam.Tui.HraScheduled.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds fresh next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.HraScheduled.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds dataDir root reload snapshot step.state nextFrame

end Loam.Tui.HraScheduledSession
