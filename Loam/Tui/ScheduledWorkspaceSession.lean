import Loam.HouseholdPaths
import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.Config.ScheduledCoverageConfig
import Loam.Review.ScheduledCoverageReview
import Loam.ScheduledCoverageSelector
import Loam.ScheduledGeneration
import Loam.MovementWorldLoader
import Loam.Tui.ScheduledWorkspace
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledCancellationSession
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledCompletionSession
import Loam.Tui.ScheduledContinuationSession
import Loam.Tui.ScheduledCoverageSetup
import Loam.Tui.ScheduledCoverageSetupSession
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.ScheduledGeneration
import Loam.Tui.ScheduledGenerationSession
import Loam.Tui.ScheduledReplacement
import Loam.Tui.ScheduledReplacementSession
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledWorkspaceSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime
open Loam.Tui.Main

set_option autoImplicit false

/-!
# Scheduled workspace session

Owns only the terminal/session lifetime for the existing Scheduled workspace
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

private def loadCoverage
    (dataDir root : System.FilePath) (observedAt : String) :
    IO Loam.Tui.ScheduledWorkspace.CoverageEvidence :=
  Loam.ScheduledCoverageReview.loadSnapshot dataDir root observedAt 18

private def workspaceFrame
    (bounds : Bounds) (snapshot : Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (state : Loam.Tui.ScheduledWorkspace.State) : CompiledWidget :=
  compileWidget (Loam.Tui.ScheduledWorkspace.viewWithCoverage bounds snapshot state coverage)

private def monitoredRuleFor?
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (record : Loam.Tui.Main.ScheduledRecord) :
    Option Loam.ScheduledCoverageConfig.Rule :=
  match coverage with
  | .error _ => none
  | .ok snapshot =>
      (snapshot.rows.find? fun row =>
        Loam.ScheduledCoverageSelector.matchesRule record row.rule).map (·.rule)

private def cadenceForRule?
    (rule : Loam.ScheduledCoverageConfig.Rule) :
    Option Loam.ScheduledGeneration.GenerationCadence :=
  Loam.ScheduledGeneration.GenerationCadence.ofMonths? rule.everyMonths

private def selectedActionRecord?
    (snapshot : Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (state : Loam.Tui.ScheduledWorkspace.State) :
    Option Loam.Tui.Main.ScheduledRecord :=
  match state.viewMode with
  | .coverage => Loam.Tui.ScheduledWorkspace.selectedCoverageRecord? snapshot coverage state
  | .planDetail =>
      match Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord? snapshot coverage state with
      | some record => some record
      | none => Loam.Tui.ScheduledWorkspace.selectedCoverageRecord? snapshot coverage state
  | .futureBoard => Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state
  | .list => Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state

private def selectedOccurrenceActionRecord?
    (snapshot : Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (state : Loam.Tui.ScheduledWorkspace.State) :
    Option Loam.Tui.Main.ScheduledRecord :=
  match state.viewMode with
  | .planDetail =>
      Loam.Tui.ScheduledWorkspace.selectedPlanDetailRecord? snapshot coverage state
  | .coverage => none
  | .futureBoard | .list =>
      Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state

private def selectedExtensionRecord?
    (snapshot : Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (state : Loam.Tui.ScheduledWorkspace.State) :
    Option Loam.Tui.Main.ScheduledRecord :=
  match state.viewMode with
  | .coverage | .planDetail =>
      Loam.Tui.ScheduledWorkspace.selectedCoverageReplenishmentRecord?
        snapshot coverage state
  | .futureBoard => Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state
  | .list => Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state

private def selectedMonitoringShape?
    (snapshot : Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (state : Loam.Tui.ScheduledWorkspace.State) :
    Option (List String × List String) :=
  match state.viewMode with
  | .coverage | .planDetail =>
      (Loam.Tui.ScheduledWorkspace.selectedCoverageRow? coverage state).map fun row =>
        (row.rule.negativeLoci, row.rule.positiveLoci)
  | .futureBoard =>
      (Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state).map fun record =>
        let shape := Loam.ScheduledCoverageSelector.ofRecord record
        (shape.negativeLoci, shape.positiveLoci)
  | .list =>
      (Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot state).map fun record =>
        let shape := Loam.ScheduledCoverageSelector.ofRecord record
        (shape.negativeLoci, shape.positiveLoci)

def eventOfKey
    (viewMode : Loam.Tui.ScheduledWorkspace.ViewMode)
    (pane : Loam.Tui.ScheduledWorkspace.Pane) :
    Loam.Tui.Terminal.Key → Loam.Tui.ScheduledWorkspace.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .input 'f' | .input 'F' => .cycleFilter
  | .input 'v' | .input 'V' => .toggleView
  | .input 'n' | .input 'N' => .createScheduled
  | .input 'e' | .input 'E' => .extendPlan
  | .input 'p' | .input 'P' => .changePace
  | .input 's' | .input 'S' => .stopMonitoring
  | .input 'g' | .input 'G' => .fillCurrentCycle
  | .input 'm' | .input 'M' => .monitorCoverage
  | .input 'c' | .input 'C' => .completeScheduled
  | .enter =>
      match viewMode with
      | .coverage => .openSelectedPlan
      | .planDetail => .completeScheduled
      | .futureBoard =>
          match pane with
          | .loci => .other
          | .occurrences => .completeScheduled
      | .list =>
          match pane with
          | .loci => .other
          | .occurrences => .completeScheduled
  | .input 'r' | .input 'R' => .replaceScheduled
  | .input 'x' | .input 'X' => .cancelScheduled
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other

/-- Scheduled workspace session. `q` returns to Home; mutations remain delegated. -/
partial def run
    (bounds : Bounds) (dataDir root : System.FilePath)
    (reload : IO (Except String Snapshot))
    (snapshot : Snapshot)
    (coverage : Loam.Tui.ScheduledWorkspace.CoverageEvidence)
    (state : Loam.Tui.ScheduledWorkspace.State)
    (frame : CompiledWidget) : IO Snapshot := do
  let step := Loam.Tui.ScheduledWorkspace.updateWithCoverage snapshot coverage state
    (eventOfKey state.viewMode state.pane (← Loam.Tui.Terminal.readKey))
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
      let freshCoverage ← loadCoverage dataDir root fresh.actual.today
      let refreshed := Loam.Tui.ScheduledWorkspace.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := workspaceFrame bounds fresh freshCoverage next
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      run bounds dataDir root reload fresh freshCoverage next nextFrame
  | .extendPlan =>
      match selectedExtensionRecord? snapshot coverage step.state with
      | none =>
          let notice :=
            match step.state.viewMode with
            | .coverage | .planDetail =>
                "No explicit Scheduled occurrence on the monitored pace is available before the first gap."
            | .futureBoard | .list =>
                "No Scheduled plan is selected to extend."
          let next := { step.state with notice := notice }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          let activeCoverage ←
            match monitoredRuleFor? coverage record with
            | some _ => pure coverage
            | none =>
                let _ ← Loam.Tui.ScheduledCoverageSetupSession.run bounds dataDir record
                loadCoverage dataDir root snapshot.actual.today
          match monitoredRuleFor? activeCoverage record with
          | none =>
              let next := { step.state with notice :=
                "Extend cancelled; no recurring pattern was selected." }
              let nextFrame := workspaceFrame bounds snapshot activeCoverage next
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload snapshot activeCoverage next nextFrame
          | some rule =>
              match cadenceForRule? rule with
              | none =>
                  let next := { step.state with notice :=
                    "This monitoring pattern cannot be extended automatically." }
                  let nextFrame := workspaceFrame bounds snapshot activeCoverage next
                  Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
                  run bounds dataDir root reload snapshot activeCoverage next nextFrame
              | some cadence =>
                  let world ←
                    match ← Loam.MovementWorldLoader.loadSelectedWorld? root with
                    | .error message => throw (IO.userError message)
                    | .ok world => pure world
                  let known := world.locusAdmission.approved.map (fun locus => locus.token)
                  let catalog ← currentLocusCatalog dataDir world
                  let notice ← Loam.Tui.ScheduledGenerationSession.runWithCadence
                    bounds dataDir root known catalog record snapshot.actual.today cadence
                  let fresh ← requireReload notice reload
                  let freshCoverage ← loadCoverage dataDir root fresh.actual.today
                  let refreshed := Loam.Tui.ScheduledWorkspace.refreshed fresh step.state
                  let next := { refreshed with notice := notice }
                  let nextFrame := workspaceFrame bounds fresh freshCoverage next
                  Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
                  run bounds dataDir root reload fresh freshCoverage next nextFrame
  | .stopMonitoring =>
      match selectedActionRecord? snapshot coverage step.state with
      | none =>
          let next := { step.state with notice := "No recurring plan is selected." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          let undecidedRule : Except String Loam.ScheduledCoverageConfig.Rule :=
            match monitoredRuleFor? coverage record with
            | some rule => .ok { rule with everyMonths := 0 }
            | none =>
                match Loam.Tui.ScheduledCoverageSetup.ruleFor? record 1 with
                | .error message => .error message
                | .ok rule => .ok { rule with everyMonths := 0 }
          match undecidedRule with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := workspaceFrame bounds snapshot coverage next
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot coverage next nextFrame
          | .ok rule =>
              let path := Loam.HouseholdPaths.scheduledCoverage dataDir
              match ← Loam.ScheduledCoverageConfig.upsertAt path rule with
              | .error message =>
                  let next := { step.state with notice := message }
                  let nextFrame := workspaceFrame bounds snapshot coverage next
                  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
                  run bounds dataDir root reload snapshot coverage next nextFrame
              | .ok _ =>
                  let freshCoverage ← loadCoverage dataDir root snapshot.actual.today
                  let coverageRow :=
                    (Loam.Tui.ScheduledWorkspace.coverageRowForRecord?
                      freshCoverage record).getD step.state.coverageRow
                  let next := { step.state with
                    coverageRow := coverageRow
                    notice :=
                      "Future pace is undecided for this plan. Existing Scheduled occurrences were not changed." }
                  let nextFrame := workspaceFrame bounds snapshot freshCoverage next
                  Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
                  run bounds dataDir root reload snapshot freshCoverage next nextFrame
  | .changePace =>
      match selectedActionRecord? snapshot coverage step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is available for the selected recurring plan." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          let notice ← Loam.Tui.ScheduledCoverageSetupSession.run bounds dataDir record
          let freshCoverage ← loadCoverage dataDir root snapshot.actual.today
          let coverageRow :=
            (Loam.Tui.ScheduledWorkspace.coverageRowForRecord?
              freshCoverage record).getD step.state.coverageRow
          let next := { step.state with coverageRow := coverageRow, notice := notice }
          let nextFrame := workspaceFrame bounds snapshot freshCoverage next
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload snapshot freshCoverage next nextFrame
  | .fillCurrentCycle =>
      match Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is selected as the cycle-fill source." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
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

          let freshCoverage ← loadCoverage dataDir root fresh.actual.today
          let refreshed := Loam.Tui.ScheduledWorkspace.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := workspaceFrame bounds fresh freshCoverage next
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload fresh freshCoverage next nextFrame
  | .monitorCoverage =>
      match Loam.Tui.ScheduledWorkspace.selectedRecord? snapshot step.state with
      | none =>
          let next := { step.state with notice :=
            "No current-open Scheduled occurrence is selected for monitoring." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          let notice ← Loam.Tui.ScheduledCoverageSetupSession.run bounds dataDir record
          let freshCoverage ← loadCoverage dataDir root snapshot.actual.today
          let next := { step.state with notice := notice }
          let nextFrame := workspaceFrame bounds snapshot freshCoverage next
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload snapshot freshCoverage next nextFrame
  | .completeScheduled =>
      match selectedOccurrenceActionRecord? snapshot coverage step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for completion." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          let measurePresentation ← currentMeasurePresentation dataDir
          match Loam.Tui.ScheduledCompletion.initialWithPresentation?
              measurePresentation record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := workspaceFrame bounds snapshot coverage next
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot coverage next nextFrame
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

              let freshCoverage ← loadCoverage dataDir root fresh.actual.today
              let refreshed := Loam.Tui.ScheduledWorkspace.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := workspaceFrame bounds fresh freshCoverage next
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh freshCoverage next nextFrame
  | .cancelScheduled =>
      match selectedOccurrenceActionRecord? snapshot coverage step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for cancellation." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          let confirmation := Loam.Tui.ScheduledCancellation.initial record
          let confirmationFrame := compileWidget (Loam.Tui.ScheduledCancellation.view confirmation)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame confirmationFrame
          let notice ← Loam.Tui.ScheduledCancellationSession.run
            bounds root confirmation confirmationFrame
          let fresh ← requireReload notice reload

          let freshCoverage ← loadCoverage dataDir root fresh.actual.today
          let refreshed := Loam.Tui.ScheduledWorkspace.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := workspaceFrame bounds fresh freshCoverage next
          Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
          run bounds dataDir root reload fresh freshCoverage next nextFrame
  | .replaceScheduled =>
      match selectedOccurrenceActionRecord? snapshot coverage step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for supersede." }
          let nextFrame := workspaceFrame bounds snapshot coverage next
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds dataDir root reload snapshot coverage next nextFrame
      | some record =>
          match Loam.Tui.ScheduledReplacement.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := workspaceFrame bounds snapshot coverage next
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds dataDir root reload snapshot coverage next nextFrame
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

              let freshCoverage ← loadCoverage dataDir root fresh.actual.today
              let refreshed := Loam.Tui.ScheduledWorkspace.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := workspaceFrame bounds fresh freshCoverage next
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds dataDir root reload fresh freshCoverage next nextFrame
  | .stay =>
      let nextFrame := workspaceFrame bounds snapshot coverage step.state
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds dataDir root reload snapshot coverage step.state nextFrame

end Loam.Tui.ScheduledWorkspaceSession
