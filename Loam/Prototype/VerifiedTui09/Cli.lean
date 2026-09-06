import Loam.ActualDate
import Loam.ActualReview
import Loam.Prototype.VerifiedTui04.Main
import Loam.Prototype.VerifiedTui04.Runtime
import Loam.Prototype.VerifiedTui09.Main

namespace Loam.Prototype.VerifiedTui09.Cli

open Loam.Prototype.VerifiedTui04.Kernel
open Loam.Prototype.VerifiedTui04.Runtime
open Loam.Prototype.VerifiedTui09.Main

set_option autoImplicit false

private def resolveDataDir (args : List String) : IO (Except String System.FilePath) := do
  match args with
  | [] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then
            return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")
  | [path] =>
      if path.isEmpty then
        return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | _ =>
      return .error "usage: loamUiPrototype09 [LOAM_DATA_DIR]"

private def resolveManifestRoot
    (dataDir : System.FilePath) : IO (Except String System.FilePath) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some path =>
      if path.isEmpty then
        return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      return .ok (dataDir / "movement-authority")

private def loadSnapshot (dataDir : System.FilePath) : IO (Except String Snapshot) := do
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local date"
  let manifestRoot ←
    match ← resolveManifestRoot dataDir with
    | .error message => return .error message
    | .ok root => pure root
  let correctionPath := (dataDir / "corrections.loam").toString
  let records ←
    match ← Loam.ActualReview.loadRecordsFromManifest manifestRoot (some correctionPath) with
    | .error message => return .error message
    | .ok records => pure records
  return .ok {
    today := today
    allRecords := records
    undatedCount := (Loam.ActualReview.select records .undated).length
  }


def compiledFrameFor (snapshot : Snapshot) (state : State) : CompiledWidget :=
  compileWidget (view snapshot state)


theorem compiledFrameFor_spec (snapshot : Snapshot) (state : State) :
    (compiledFrameFor snapshot state).toScreen screenBounds 1 1 =
      screenFor snapshot state := by
  simpa [compiledFrameFor, screenFor] using
    compileWidget_spec screenBounds 1 1 (view snapshot state)


def keyEvent : Loam.Prototype.VerifiedTui04.Main.Key → Event
  | .left => .left
  | .right => .right
  | .up => .up
  | .down => .down
  | .enter => .enter
  | .back => .back
  | .quit => .quit
  | _ => .other

/-- Reuse the sparse row-damage terminal lowering already qualified by Prototype 07. -/
def emitDirtyDiff (old new : CompiledWidget) : IO Unit := do
  let mut output := ""
  for row in dirtyRows screenBounds 1 old new do
    output := output ++ Loam.Prototype.VerifiedTui04.Main.cursorTo row.val 1
    match new.rowAt 1 row.val with
    | none => pure ()
    | some cells =>
        for cell in cells do
          output := output ++
            Loam.Prototype.VerifiedTui04.Main.ansiStyle cell.style ++
            toString cell.glyph
    output := output ++ "\x1b[0m\x1b[K"
  IO.print output
  (← IO.getStdout).flush


partial def loop
    (snapshot : Snapshot)
    (state : State)
    (frame : CompiledWidget) : IO Unit := do
  let event := keyEvent (← Loam.Prototype.VerifiedTui04.Main.readKey)
  let step := update snapshot state event
  if step.quit then
    return
  let nextFrame := compiledFrameFor snapshot step.state
  emitDirtyDiff frame nextFrame
  loop snapshot step.state nextFrame


def run (args : List String) : IO UInt32 := do
  let dataDir ←
    match ← resolveDataDir args with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  let snapshot ←
    match ← loadSnapshot dataDir with
    | .error message => IO.eprintln message; return 2
    | .ok snapshot => pure snapshot
  Loam.Prototype.VerifiedTui04.Main.enterTerminal
  try
    let state := initialState
    let frame := compiledFrameFor snapshot state
    let blank := compileWidget (.row [])
    emitDirtyDiff blank frame
    loop snapshot state frame
    return 0
  finally
    Loam.Prototype.VerifiedTui04.Main.leaveTerminal

end Loam.Prototype.VerifiedTui09.Cli


def main (args : List String) : IO UInt32 :=
  Loam.Prototype.VerifiedTui09.Cli.run args
