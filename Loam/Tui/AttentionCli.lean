import Loam.ActualDate
import Loam.AttentionReview
import Loam.Tui.AttentionAdministration
import Loam.Tui.AttentionAdministrationSession
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.AttentionCli

open Loam.Tui.Kernel
open Loam.Tui.Runtime

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
  | _ => return .error "usage: loamAttention [LOAM_DATA_DIR]"

/-- Run the first practical Attention writer over the canonical household root. -/
def run (args : List String) : IO UInt32 := do
  let root ←
    match ← resolveDataDir args with
    | .error message => IO.eprintln message; return 2
    | .ok path => pure path
  let some today ← Loam.ActualDate.todayIso?
    | IO.eprintln "loam: could not determine the local date"; return 2
  let evidence ←
    match ← Loam.AttentionReview.loadEvidence (root / "attention.loam") with
    | .error message => IO.eprintln message; return 2
    | .ok evidence => pure evidence
  let bounds ← Loam.Tui.Terminal.currentBounds
  Loam.Tui.Terminal.enter
  try
    let state := Loam.Tui.AttentionAdministration.initial evidence today
    let frame := compileWidget (Loam.Tui.AttentionAdministration.view state)
    let blank := compileWidget (.row [])
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 blank frame
    Loam.Tui.AttentionAdministrationSession.run bounds root state frame
    return 0
  finally
    Loam.Tui.Terminal.leave

end Loam.Tui.AttentionCli
