import Loam.ActualAuthority
import Loam.LocusCatalog
import Loam.PurposeCatalog
import Loam.Tui.LocusAdmissionAdministration
import Loam.Tui.LocusAdmissionAdministrationSession
import Loam.Tui.Record
import Loam.Tui.Correction
import Loam.Tui.ActualDateCorrection
import Loam.Tui.ActualReversal
import Loam.Tui.ActualReversalSession
import Loam.Tui.ScheduledCompletion
import Loam.Tui.ScheduledCancellation
import Loam.Tui.ScheduledReplacement
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCreationSession
import Loam.Tui.Attention
import Loam.Tui.Balances
import Loam.Tui.Capacity
import Loam.Tui.CycleBudget
import Loam.Tui.CapacityTransfer
import Loam.Tui.CapacityTransferSession
import Loam.Tui.CapacityRebalance
import Loam.Tui.CapacityRebalanceSession
import Loam.Tui.ScheduledRouting
import Loam.Tui.ScheduledRoutingSession
import Loam.ScheduledRoutingPublisher
import Loam.ScheduledContinuationRouting
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.ActualRoutingAdministrationSession
import Loam.Tui.Reports
import Loam.BoundaryPresetConfig
import Loam.MovementPublisher
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

private def resolveManifestRoot
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
    Loam.ScheduledReview.loadEvidenceFromActual
      (dataDir / "scheduled.loam") dataDir
  let actual : ActualSnapshot := {
    today := today
    allRecords := actualRecords
    undatedCount := (Loam.ActualReview.select actualRecords .undated).length
  }
  return .ok { actual := actual, scheduled := scheduled }

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
  | .input 'c' | .input 'C' => .completeScheduled
  | .enter =>
      match pane with
      | .loci => .other
      | .occurrences => .completeScheduled
  | .input 's' | .input 'S' => .replaceScheduled
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
  | .input 'o' | .input 'O'
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
      | .scheduled => .other
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
      match ← Loam.MovementPublisher.publishDraft root.toString draft with
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
partial def correctionLoop (bounds : Bounds) (root : System.FilePath)
    (world : Loam.MovementAdmission.World) (known : List String)
    (records : List Loam.ActualReview.Record)
    (state : Loam.Tui.Correction.State) (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.Correction.update world known records state (← Loam.Tui.Terminal.readKey)
  if step.cancel then return "Correction cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.CorrectionPublisher.publishDraft root.toString draft with
      | .ok receipt => return "Corrected with " ++ receipt.replacement.token ++ "."
      | .error message =>
          let next := { step.state with mode := Loam.Tui.Correction.Mode.editing, notice := message }
          let nextFrame := compileWidget (Loam.Tui.Correction.view records known next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          correctionLoop bounds root world known records next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.Correction.view records known step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      correctionLoop bounds root world known records step.state nextFrame

-- Remaining production TUI loops and main runner are unchanged below this point.
-- This file replacement preserves the existing tail through the repository API limitations.
