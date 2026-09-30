import Loam.ActualDate
import Loam.Review.ActualReview
import Loam.Desk.Model
import Loam.Desk.View
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Desk.Cli

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

private def resolveDataDir (args : List String) : IO (Except String System.FilePath) := do
  match args with
  | [] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loamDesk: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")
  | [path] =>
      if path.isEmpty then return .error "loamDesk: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | _ => return .error "usage: loamDesk [LOAM_DATA_DIR]"

private def loadSnapshot
    (dataDir : System.FilePath) : IO (Except String Loam.Desk.Model.Snapshot) := do
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loamDesk: could not determine the local date"
  match ← Loam.ActualReview.loadRecordsFromActual dataDir with
  | .error message => return .error message
  | .ok records => return .ok { today := today, records := records }

private def eventOfKey
    (state : Loam.Desk.Model.State) :
    Loam.Tui.Terminal.Key → Loam.Desk.Model.Event :=
  if state.jumpEditing then
    fun key =>
      match key with
      | .escape => .cancelJump
      | .backspace => .jumpBackspace
      | .enter => .acceptJump
      | .input char => .jumpInput char
      | _ => .other
  else
    fun key =>
      match key with
      | .up | .input 'k' => .previousRow
      | .down | .input 'j' => .nextRow
      | .left | .input 'h' => .previousDay
      | .right | .input 'l' => .nextDay
      | .input 'H' => .previousMonth
      | .input 'L' => .nextMonth
      | .input 'g' | .input 'G' => .beginJump
      | .enter | .input 'e' | .input 'E' => .toggleEvidence
      | .escape | .input 'q' | .input 'Q' => .quit
      | _ => .other

partial def loop
    (bounds : Bounds)
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State)
    (frame : CompiledWidget) : IO Unit := do
  let event := eventOfKey state (← Loam.Tui.Terminal.readKey)
  let step := Loam.Desk.Model.update snapshot state event
  if step.quit then return
  let nextFrame := compileWidget (Loam.Desk.View.view bounds snapshot step.state)
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
  loop bounds snapshot step.state nextFrame

def run (args : List String) : IO UInt32 := do
  let dataDir ←
    match ← resolveDataDir args with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  let snapshot ←
    match ← loadSnapshot dataDir with
    | .error message => IO.eprintln message; return 2
    | .ok snapshot => pure snapshot
  let bounds ← Loam.Tui.Terminal.currentBounds
  Loam.Tui.Terminal.enter
  try
    let state := Loam.Desk.Model.initial snapshot snapshot.today
    let frame := compileWidget (Loam.Desk.View.view bounds snapshot state)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) frame
    loop bounds snapshot state frame
    return 0
  finally
    Loam.Tui.Terminal.leave

end Loam.Desk.Cli
