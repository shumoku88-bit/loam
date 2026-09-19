import Loam.ScheduledCoverageConfig
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCoverageSetup
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCoverageSetupSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

private partial def loop
    (bounds : Bounds)
    (dataDir : System.FilePath)
    (state : Loam.Tui.ScheduledCoverageSetup.State)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCoverageSetup.update state
    (← Loam.Tui.Terminal.readKey)
  match step.action with
  | some .cancel =>
      return "Plan monitoring unchanged."
  | some (.save months) =>
      match Loam.Tui.ScheduledCoverageSetup.ruleFor? step.state.source months with
      | .error message =>
          let next := { step.state with notice := message }
          let nextFrame := compileWidget (Loam.Tui.ScheduledCoverageSetup.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          loop bounds dataDir next nextFrame
      | .ok rule =>
          let path := dataDir / "config" / "scheduled-coverage.tsv"
          match ← Loam.ScheduledCoverageConfig.upsertAt path rule with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget (Loam.Tui.ScheduledCoverageSetup.view next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              loop bounds dataDir next nextFrame
          | .ok _ =>
              return ("Monitoring " ++ rule.name ++ ": " ++
                Loam.Tui.ScheduledCoverageSetup.cadenceLabel months ++
                " from " ++ rule.anchor ++
                ". No Scheduled occurrence was created.")
  | none =>
      let nextFrame := compileWidget (Loam.Tui.ScheduledCoverageSetup.view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      loop bounds dataDir step.state nextFrame

def run
    (bounds : Bounds)
    (dataDir : System.FilePath)
    (source : Loam.Tui.ScheduledCoverageSetup.Record) : IO String := do
  let state := Loam.Tui.ScheduledCoverageSetup.initial source
  let frame := compileWidget (Loam.Tui.ScheduledCoverageSetup.view state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  loop bounds dataDir state frame

end Loam.Tui.ScheduledCoverageSetupSession
