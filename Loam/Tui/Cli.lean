import Loam.Tui.Record
import Loam.Tui.Attention
import Loam.Tui.Capacity
import Loam.MovementPublisher
import Loam.CompletionPrompt
import Loam.ActualDate
import Loam.ActualReview
import Loam.ScheduledReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.Tui.Main
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.Cli

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


def compiledFrameFor (snapshot : Snapshot) (state : State) : CompiledWidget :=
  compileWidget (view snapshot state)


theorem compiledFrameFor_spec (snapshot : Snapshot) (state : State) :
    (compiledFrameFor snapshot state).toScreen screenBounds 1 1 =
      screenFor snapshot state := by
  simpa [compiledFrameFor, screenFor] using
    compileWidget_spec screenBounds 1 1 (view snapshot state)


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

/-- A Record session emits one explicit publication intent at most.
After success it returns to Home; a reload error exits instead of offering retry. -/
partial def recordLoop (root : System.FilePath)
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
          Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame nextFrame
          recordLoop root world known next nextFrame
  | none =>
      let nextFrame := compileWidget (Loam.Tui.Record.view known step.state)
      Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame nextFrame
      recordLoop root world known step.state nextFrame

/-- Read-only Attention session. `true` means the user chose to quit LOAM. -/
partial def attentionLoop
    (state : Loam.Tui.Attention.State) (frame : CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .input 'q' || key = .input 'Q' then
    return true
  let back := key = .escape || key = .input 'b' || key = .input 'B'
  match Loam.Tui.Attention.update state back with
  | .back => return false
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Attention.view next)
      Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame nextFrame
      attentionLoop next nextFrame

/-- Read-only all-retained Capacity session. `true` means quit LOAM. -/
partial def capacityLoop
    (state : Loam.Tui.Capacity.State) (frame : CompiledWidget) : IO Bool := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .input 'q' || key = .input 'Q' then
    return true
  let back := key = .escape || key = .input 'b' || key = .input 'B'
  match Loam.Tui.Capacity.update state back with
  | .back => return false
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame nextFrame
      capacityLoop next nextFrame

partial def loop (dataDir root : System.FilePath)
    (snapshot : Snapshot) (state : State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let isHome := match state.surface with | .home _ => true | _ => false
  if isHome && (key = .input 'a' || key = .input 'A') then
    let evidence ←
      match ← Loam.AttentionReview.loadEvidence (dataDir / "attention.loam") with
      | .error message => throw (IO.userError message)
      | .ok evidence => pure evidence
    let attention := Loam.Tui.Attention.initial evidence
    let attentionFrame := compileWidget (Loam.Tui.Attention.view attention)
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame attentionFrame
    if ← attentionLoop attention attentionFrame then
      return
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor snapshot home
    -- The local Attention loop does not expose its last physical frame.
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 (compileWidget (.row [])) nextFrame
    loop dataDir root snapshot home nextFrame
  else if isHome && (key = .input 'c' || key = .input 'C') then
    let capacitySnapshot ←
      match ← Loam.CapacityReview.loadSnapshot (dataDir / "capacity.loam") with
      | .error message => throw (IO.userError message)
      | .ok capacitySnapshot => pure capacitySnapshot
    let capacity := Loam.Tui.Capacity.initial capacitySnapshot
    let capacityFrame := compileWidget (Loam.Tui.Capacity.view capacity)
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame capacityFrame
    if ← capacityLoop capacity capacityFrame then
      return
    let home := { state with notice := "" }
    let nextFrame := compiledFrameFor snapshot home
    -- The local Capacity loop does not expose its last physical frame.
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 (compileWidget (.row [])) nextFrame
    loop dataDir root snapshot home nextFrame
  else if isHome && key = .input 'r' then
    let world ←
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
      | .error message => throw (IO.userError message)
      | .ok world => pure world
    let known := (world.locusAdmission.approved.map (fun locus => locus.token) ++
      Loam.CompletionPrompt.knownLoci world.events).eraseDups
    let editor := Loam.Tui.Record.initial state.selectedDate
    let editorFrame := compileWidget (Loam.Tui.Record.view known editor)
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame editorFrame
    let notice ← recordLoop root world known editor editorFrame
    -- Never reuse cached review cursors after publication. Reload canonical evidence.
    let fresh ←
      match ← loadSnapshot dataDir with
      | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
      | .ok fresh => pure fresh
    let home := { state with surface := .home none, notice := notice }
    let nextFrame := compiledFrameFor fresh home
    -- Editor's final frame is local to recordLoop: clear the physical surface once.
    IO.print "\x1b[2J"
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 (compileWidget (.row [])) nextFrame
    loop dataDir root fresh home nextFrame
  else
    let step := update snapshot state (eventOfKey key)
    if step.quit then return
    let nextFrame := compiledFrameFor snapshot step.state
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 frame nextFrame
    loop dataDir root snapshot step.state nextFrame


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
  Loam.Tui.Terminal.enter
  try
    let state := { initialState snapshot.actual.today with notice := "a Attention   c Capacity" }
    let frame := compiledFrameFor snapshot state
    let blank := compileWidget (.row [])
    Loam.Tui.Terminal.emitDirtyDiff screenBounds 1 1 blank frame
    loop dataDir root snapshot state frame
    return 0
  finally
    Loam.Tui.Terminal.leave

end Loam.Tui.Cli


def main (args : List String) : IO UInt32 :=
  Loam.Tui.Cli.run args