import Loam.Tui.Record
import Loam.Tui.Correction
import Loam.Tui.ActualDateCorrection
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledReplacement
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.Attention
import Loam.Tui.Balances
import Loam.Tui.Capacity
import Loam.Tui.CapacityTransfer
import Loam.Tui.CapacityTransferSession
import Loam.Tui.Reports
import Loam.BoundaryPresetConfig
import Loam.MovementPublisher
import Loam.CompletionPrompt
import Loam.ActualDate
import Loam.ActualReview
import Loam.ScheduledReview
import Loam.AttentionReview
import Loam.BalanceReview
import Loam.CapacityReview
import Loam.BudgetWindowReview
import Loam.ConditionalBalancePathReview
import Loam.StockFlowReview
import Loam.Tui.Main
import Loam.Tui.HraHome
import Loam.Tui.HraActual
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

private def resolveManifestRoot
    (dataDir : System.FilePath) : IO (Except String System.FilePath) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some path =>
      if path.isEmpty then return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      return .ok (System.FilePath.mk path)
  | none => return .ok (dataDir / "movement-authority")

private def loadSnapshot (dataDir : System.FilePath) : IO (Except String Snapshot) := do
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local date"
  let manifestRoot ←
    match ← resolveManifestRoot dataDir with
    | .error message => return .error message
    | .ok root => pure root
  let correctionPath := (dataDir / "corrections.loam").toString
  let actualRecords ←
    match ← Loam.ActualReview.loadRecordsFromManifest manifestRoot (some correctionPath) with
    | .error message => return .error message
    | .ok records => pure records
  let scheduled ←
    match ← Loam.ScheduledReview.loadEvidenceFromManifest
        (dataDir / "scheduled.loam") manifestRoot with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let actual : ActualSnapshot := {
    today := today
    allRecords := actualRecords
    undatedCount := (Loam.ActualReview.select actualRecords .undated).length
  }
  return .ok { actual := actual, scheduled := scheduled }


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
  | .tab => .tab
  | .enter => .enter
  | .escape => .back
  | .input 'b' => .back
  | .input 'B' => .back
  | .input 'q' => .quit
  | .input 'Q' => .quit
  | _ => .other

/-- HRA's Home navigation grammar, with arrows retained as equivalent navigation keys. -/
def homeEventOfKey : Loam.Tui.Terminal.Key → Event
  | .input 'h' | .input 'H' => .left
  | .input 'l' | .input 'L' => .right
  | .input 'k' | .input 'K' => .up
  | .input 'j' | .input 'J' => .down
  | .input 'p' | .input 'P' => .tab
  | key => eventOfKey key

/-- HRA Actual interaction grammar over presentation-only pane and cursor state. -/
def hraActualEventOfKey : Loam.Tui.Terminal.Key → Loam.Tui.HraActual.Event
  | .up | .input 'k' | .input 'K' => .previous
  | .down | .input 'j' | .input 'J' => .next
  | .left | .input 'h' | .input 'H' => .focusLeft
  | .right | .input 'l' | .input 'L' => .focusRight
  | .input 'f' | .input 'F' => .cycleFilter
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
  | .input 's' | .input 'S' => .replaceScheduled
  | .input 'x' | .input 'X' => .cancelScheduled
  | .input 'd' | .input 'D' => .correctDate
  | .escape | .input 'q' | .input 'Q' => .back
  | _ => .other

/-- A Record session emits one explicit publication intent at most.
The caller reloads canonical evidence and chooses the presentation destination. -/
partial def recordLoop (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Record.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Record.update world known state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Record cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.MovementPublisher.publishManifestDraft root.toString draft with
      | .ok receipt => return "Recorded " ++ receipt.eventId.token ++ "."
      | .error message =>
          let next := { step.state with mode := Loam.Tui.Record.Mode.editing, notice := message }
          let nextFrame := compileWidget (Loam.Tui.Record.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          recordLoop bounds root world known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.Record.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      recordLoop bounds root world known step.state nextFrame

/-- A Correction session emits one target-bound replacement intent at most.
Only the shared CorrectionPublisher performs the authoritative re-read and write. -/
partial def correctionLoop (bounds : Bounds) (root correctionFile : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Correction.update world known state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Correction cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.CorrectionPublisher.publishManifestCorrection
          root.toString correctionFile.toString draft with
      | .ok receipt =>
          return "Corrected " ++ receipt.target.token ++ " -> " ++ receipt.replacement.token ++ "."
      | .error message =>
          let next := Loam.Tui.Correction.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.Correction.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          correctionLoop bounds root correctionFile world known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.Correction.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      correctionLoop bounds root correctionFile world known step.state nextFrame

/-- Date editing stays local; the shared publisher performs every authoritative re-check. -/
partial def actualDateCorrectionLoop
    (bounds : Bounds) (root correctionFile : System.FilePath)
    (state : Loam.Tui.ActualDateCorrection.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ActualDateCorrection.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Date correction cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.ActualValidityPublisher.publishManifestDate
          root.toString correctionFile.toString draft with
      | .ok receipt =>
          if receipt.changed then
            return "Date corrected to " ++ receipt.validOn ++ "."
          else
            return "Date is already current; nothing changed."
      | .error message =>
          let next := Loam.Tui.ActualDateCorrection.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ActualDateCorrection.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          actualDateCorrectionLoop bounds root correctionFile next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ActualDateCorrection.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      actualDateCorrectionLoop bounds root correctionFile step.state nextFrame

/--
Scheduled completion edits an Actual draft; shared publication re-reads both
authorities. A successful result returns the durable receipt so the caller may
optionally open a separate next-Scheduled creation editor without conflating the
facts or deriving continuation from presentation text.
-/
partial def scheduledCompletionLoop
    (bounds : Bounds) (scheduledFile root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (state : Loam.Tui.ScheduledCompletion.State) (frame : CompiledWidget) :
    IO (Option Loam.ScheduledTerminalPublisher.CompletionReceipt) := do
  let step := Loam.Tui.ScheduledCompletion.update world known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return none
  match step.publish with
  | some draft =>
      match ← Loam.ScheduledTerminalPublisher.publishManifestCompletion
          scheduledFile.toString root.toString draft with
      | .ok receipt => return some receipt
      | .error message =>
          let next := Loam.Tui.ScheduledCompletion.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          scheduledCompletionLoop bounds scheduledFile root world known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      scheduledCompletionLoop bounds scheduledFile root world known step.state nextFrame

/-- Cancellation confirmation is presentation-only; publisher refusal returns to fresh day evidence. -/
partial def scheduledCancellationLoop
    (bounds : Bounds) (scheduledFile root : System.FilePath)
    (state : Loam.Tui.ScheduledCancellation.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCancellation.update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled cancellation kept the occurrence open."
  match step.publish with
  | some draft =>
      match ← Loam.ScheduledTerminalPublisher.publishManifestCancellation
          scheduledFile.toString root.toString draft with
      | .ok receipt => return "Cancelled " ++ receipt.scheduled.token ++ "."
      | .error message => return "Scheduled cancellation refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCancellation.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      scheduledCancellationLoop bounds scheduledFile root step.state nextFrame

/-- Scheduled replacement editor emits one source-bound replacement draft at most. -/
partial def scheduledReplacementLoop
    (bounds : Bounds) (scheduledFile root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledReplacement.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledReplacement.update known state
    (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Scheduled supersede cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.ScheduledReplacementPublisher.publishManifestReplacement
          scheduledFile.toString root.toString draft with
      | .ok receipt =>
          return "Superseded " ++ receipt.source.token ++ " -> " ++ receipt.replacement.token ++ "."
      | .error message =>
          let next := Loam.Tui.ScheduledReplacement.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          scheduledReplacementLoop bounds scheduledFile root known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      scheduledReplacementLoop bounds scheduledFile root known step.state nextFrame

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
        match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
        Loam.CompletionPrompt.knownLoci world.events).eraseDups
      let editor := Loam.Tui.Record.initial state.focusDate
      let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← recordLoop bounds root world known editor editorFrame
      let fresh ←
        match ← loadSnapshot dataDir with
        | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
        | .ok fresh => pure fresh
      let refreshed := Loam.Tui.HraActual.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.HraActual.view bounds fresh next)
      IO.print "\x1b[2J"
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
      hraActualLoop bounds dataDir root fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.HraActual.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      hraActualLoop bounds dataDir root snapshot step.state nextFrame

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
        match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
        Loam.CompletionPrompt.knownLoci world.events).eraseDups
      let editor := Loam.Tui.ScheduledCreation.initial step.state.focusDate
      let editorFrame := compileWidget (Loam.Tui.ScheduledCreation.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.ScheduledCreationSession.run
        bounds (dataDir / "scheduled.loam") root known editor editorFrame
      let fresh ←
        match ← loadSnapshot dataDir with
        | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
        | .ok fresh => pure fresh
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      IO.print "\x1b[2J"
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
      selectedDayLoop bounds dataDir root fresh next nextFrame
  | .completeScheduled =>
      match Loam.Tui.SelectedDay.selectedScheduled? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current-open Scheduled occurrence is selected for completion." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.ScheduledCompletion.initial? record snapshot.actual.today with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
                Loam.CompletionPrompt.knownLoci world.events).eraseDups
              let editorFrame := compileWidget (Loam.Tui.ScheduledCompletion.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let completion ← scheduledCompletionLoop
                bounds (dataDir / "scheduled.loam") root world known editor editorFrame
              let notice ←
                match completion with
                | none => pure "Scheduled completion cancelled."
                | some receipt =>
                    let completedNotice :=
                      "Completed " ++ receipt.scheduled.token ++ " as " ++ receipt.actual.token ++ "."
                    match Loam.Tui.ScheduledCreation.initialFromScheduled? record with
                    | .error message =>
                        pure (completedNotice ++ " Next Scheduled editor unavailable: " ++ message)
                    | .ok nextEditor =>
                        let nextEditorFrame :=
                          compileWidget (Loam.Tui.ScheduledCreation.view known nextEditor)
                        IO.print "\x1b[2J"
                        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0
                          (compileWidget (.row [])) nextEditorFrame
                        let nextNotice ← Loam.Tui.ScheduledCreationSession.run
                          bounds (dataDir / "scheduled.loam") root known nextEditor nextEditorFrame
                        if nextNotice == "Scheduled creation cancelled." then
                          pure (completedNotice ++ " No next Scheduled created.")
                        else
                          pure (completedNotice ++ " " ++ nextNotice)
              let fresh ←
                match ← loadSnapshot dataDir with
                | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
                | .ok fresh => pure fresh
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              IO.print "\x1b[2J"
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
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
            bounds (dataDir / "scheduled.loam") root confirmation confirmationFrame
          let fresh ←
            match ← loadSnapshot dataDir with
            | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
            | .ok fresh => pure fresh
          let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
          let next := { refreshed with notice := notice }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
          IO.print "\x1b[2J"
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
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
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot step.state)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
                Loam.CompletionPrompt.knownLoci world.events).eraseDups
              let editorFrame := compileWidget (Loam.Tui.ScheduledReplacement.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← scheduledReplacementLoop
                bounds (dataDir / "scheduled.loam") root known editor editorFrame
              let fresh ←
                match ← loadSnapshot dataDir with
                | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
                | .ok fresh => pure fresh
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              IO.print "\x1b[2J"
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
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
                bounds root (dataDir / "corrections.loam") editor editorFrame
              let fresh ←
                match ← loadSnapshot dataDir with
                | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
                | .ok fresh => pure fresh
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              IO.print "\x1b[2J"
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .correctActual =>
      match Loam.Tui.SelectedDay.selectedActual? snapshot step.state with
      | none =>
          let next := { step.state with notice := "No current Actual is selected for correction." }
          let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          selectedDayLoop bounds dataDir root snapshot next nextFrame
      | some record =>
          match Loam.Tui.Correction.initial? record with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              selectedDayLoop bounds dataDir root snapshot next nextFrame
          | .ok editor =>
              let world ←
                match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
                | .error message => throw (IO.userError message)
                | .ok world => pure world
              let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
                Loam.CompletionPrompt.knownLoci world.events).eraseDups
              let editorFrame := compileWidget (Loam.Tui.Correction.view known editor)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
              let notice ← correctionLoop bounds root (dataDir / "corrections.loam")
                world known editor editorFrame
              let fresh ←
                match ← loadSnapshot dataDir with
                | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
                | .ok fresh => pure fresh
              let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
              let next := { refreshed with notice := notice }
              let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
              IO.print "\x1b[2J"
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
              selectedDayLoop bounds dataDir root fresh next nextFrame
  | .recordNew =>
      let world ←
        match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
        | .error message => throw (IO.userError message)
        | .ok world => pure world
      let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
        Loam.CompletionPrompt.knownLoci world.events).eraseDups
      let editor := Loam.Tui.Record.initial state.focusDate
      let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← recordLoop bounds root world known editor editorFrame
      let fresh ←
        match ← loadSnapshot dataDir with
        | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
        | .ok fresh => pure fresh
      let refreshed := Loam.Tui.SelectedDay.refreshed fresh step.state
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds fresh next)
      IO.print "\x1b[2J"
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
      selectedDayLoop bounds dataDir root fresh next nextFrame
  | .stay =>
      let nextFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      selectedDayLoop bounds dataDir root snapshot step.state nextFrame

/-- Read-only Attention session. `true` means the user chose to quit LOAM. -/
partial def attentionLoop (bounds : Bounds)
    (state : Loam.Tui.Attention.State) (frame : CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .input 'q' || key = .input 'Q' then
    return true
  let back := key = .escape || key = .input 'b' || key = .input 'B'
  match Loam.Tui.Attention.update state back with
  | .back => return false
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Attention.view next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      attentionLoop bounds next nextFrame

/-- Read-only balance-view session. `true` means quit LOAM. -/
partial def balancesLoop (bounds : Bounds)
    (state : Loam.Tui.Balances.State) (frame : CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .input 'q' || key = .input 'Q' then
    return true
  let back := key = .escape || key = .input 'b' || key = .input 'B'
  match Loam.Tui.Balances.update state back with
  | .back => return false
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Balances.view next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      balancesLoop bounds next nextFrame

/-- All-retained Capacity session with a local transfer entrance. `true` means quit LOAM. -/
partial def capacityLoop
    (bounds : Bounds) (dataDir : System.FilePath) (focusDate : String)
    (state : Loam.Tui.Capacity.State) (frame : CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .input 'q' || key = .input 'Q' then
    return true
  let backKey := key = .escape || key = .input 'b' || key = .input 'B'
  let event : Loam.Tui.Capacity.Event :=
    if backKey then .back
    else
      match key with
      | .up | .input 'k' | .input 'K' => .up
      | .down | .input 'j' | .input 'J' => .down
      | .input 't' | .input 'T' => .transfer
      | _ => .other
  match Loam.Tui.Capacity.update state event with
  | .back => return false
  | .transfer current =>
      let editor := Loam.Tui.CapacityTransfer.initial
        current.snapshot focusDate (Loam.Tui.Capacity.selectedPurpose? current)
      let editorFrame := compileWidget (Loam.Tui.CapacityTransfer.view editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.CapacityTransferSession.run
        bounds (dataDir / "capacity.loam") editor editorFrame
      let fresh ←
        match ← Loam.CapacityReview.loadSnapshot (dataDir / "capacity.loam") with
        | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
        | .ok fresh => pure fresh
      let refreshed := Loam.Tui.Capacity.refreshed fresh current
      let next := { refreshed with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      IO.print "\x1b[2J"
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
      capacityLoop bounds dataDir focusDate next nextFrame
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      capacityLoop bounds dataDir focusDate next nextFrame

/-- Reports session. `true` means quit LOAM. -/
partial def reportsLoop (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.Reports.State) (frame : CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .input 'q' || key = .input 'Q' then
    return true
  let step := Loam.Tui.Reports.update state key
  if step.back then return false
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
    | some (.conditionalLiquidity assumedCompleteThrough) =>
        match ← Loam.ConditionalBalancePathReview.loadSnapshot
            dataDir root assumedCompleteThrough with
        | .ok snapshot => pure (Loam.Tui.Reports.withLiquiditySnapshot step.state snapshot)
        | .error message => pure (Loam.Tui.Reports.withError step.state message)
  let nextFrame := compileWidget (Loam.Tui.Reports.view next)
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
  reportsLoop bounds dataDir root next nextFrame

partial def loop (bounds : Bounds) (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let isHome := match state.surface with | .home _ => true | _ => false
  let isActualBrowse := match state.surface with | .actual _ .browse => true | _ => false
  if isHome && key = .enter then
    let day := Loam.Tui.SelectedDay.initial state.selectedDate
    let dayFrame := compileWidget (Loam.Tui.SelectedDay.view bounds snapshot day)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame dayFrame
    let fresh ← selectedDayLoop bounds dataDir root snapshot day dayFrame
    let home := { state with surface := .home none, notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if isHome && (key = .input 'a' || key = .input 'A') then
    let actual := Loam.Tui.HraActual.initial state.selectedDate
    let actualFrame := compileWidget (Loam.Tui.HraActual.view bounds snapshot actual)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame actualFrame
    let fresh ← hraActualLoop bounds dataDir root snapshot actual actualFrame
    let home := { state with surface := .home none, notice := "" }
    let nextFrame := compiledFrameFor bounds fresh home
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root fresh home nextFrame
  else if isHome && (key = .input 'i' || key = .input 'I') then
    let evidence ←
      match ← Loam.AttentionReview.loadEvidence (dataDir / "attention.loam") with
      | .error message => throw (IO.userError message)
      | .ok evidence => pure evidence
    let attention := Loam.Tui.Attention.initial evidence
    let attentionFrame := compileWidget (Loam.Tui.Attention.view attention)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame attentionFrame
    if ← attentionLoop bounds attention attentionFrame then
      return
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if isHome && (key = .input 'b' || key = .input 'B') then
    let balanceSnapshot ←
      match ← Loam.BalanceReview.loadSnapshot dataDir root with
      | .error message => throw (IO.userError message)
      | .ok balanceSnapshot => pure balanceSnapshot
    let balances := Loam.Tui.Balances.initial balanceSnapshot
    let balancesFrame := compileWidget (Loam.Tui.Balances.view balances)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame balancesFrame
    if ← balancesLoop bounds balances balancesFrame then
      return
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if isHome &&
      (key = .input 'e' || key = .input 'E' || key = .input 'c' || key = .input 'C') then
    let capacitySnapshot ←
      match ← Loam.CapacityReview.loadSnapshot (dataDir / "capacity.loam") with
      | .error message => throw (IO.userError message)
      | .ok capacitySnapshot => pure capacitySnapshot
    let capacity := Loam.Tui.Capacity.initial capacitySnapshot
    let capacityFrame := compileWidget (Loam.Tui.Capacity.view capacity)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame capacityFrame
    if ← capacityLoop bounds dataDir state.selectedDate capacity capacityFrame then
      return
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if isHome && (key = .input 'v' || key = .input 'V') then
    let reports ←
      match ← Loam.BoundaryPresetConfig.load? (dataDir / "boundary-presets.tsv") with
      | some presets =>
          pure (Loam.Tui.Reports.initialForDateWithPresets state.selectedDate presets)
      | none =>
          let base := Loam.Tui.Reports.initialForDate state.selectedDate
          pure { base with
            notice := "Boundary preset config malformed; named presets unavailable." }
    let reportsFrame := compileWidget (Loam.Tui.Reports.view reports)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame reportsFrame
    if ← reportsLoop bounds dataDir root reports reportsFrame then
      return
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if isHome && (key = .input 'g' || key = .input 'G') then
    let home :=
      { state with selectedDate := snapshot.actual.today, surface := .home none, notice := "" }
    let nextFrame := compiledFrameFor bounds snapshot home
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    loop bounds dataDir root snapshot home nextFrame
  else if (isHome || isActualBrowse) && (key = .input 'r' || key = .input 'R') then
    let world ←
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
      | .error message => throw (IO.userError message)
      | .ok world => pure world
    let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
      Loam.CompletionPrompt.knownLoci world.events).eraseDups
    let editor := Loam.Tui.Record.initial state.selectedDate
    let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
    let notice ← recordLoop bounds root world known editor editorFrame
    let fresh ←
      match ← loadSnapshot dataDir with
      | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
      | .ok fresh => pure fresh
    let destination :=
      if isActualBrowse then
        { state with
            surface := .actual (cursorForDay fresh state.selectedDate) .browse
            notice := notice }
      else
        { state with surface := .home none, notice := notice }
    let nextFrame := compiledFrameFor bounds fresh destination
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) nextFrame
    loop bounds dataDir root fresh destination nextFrame
  else
    let event := if isHome then homeEventOfKey key else eventOfKey key
    let step := update snapshot state event
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
    match ← resolveManifestRoot dataDir with
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

end Loam.Tui.Cli


def main (args : List String) : IO UInt32 :=
  Loam.Tui.Cli.run args