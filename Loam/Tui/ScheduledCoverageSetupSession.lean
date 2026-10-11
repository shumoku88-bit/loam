import Loam.HouseholdPaths
import Loam.Config.ScheduledCoverageConfig
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
          let path := Loam.HouseholdPaths.scheduledCoverage dataDir
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


/-- Post-publication optional expected-pace selection. Esc preserves the already
    published occurrence and does not alter any coverage configuration. -/
private partial def createdPaceLoop
    (bounds : Bounds) (dataDir : System.FilePath)
    (state : Loam.Tui.ScheduledCoverageSetup.CreatedPaceState)
    (frame : CompiledWidget) : IO String := do
  let step := Loam.Tui.ScheduledCoverageSetup.updateCreatedPace state
    (← Loam.Tui.Terminal.readKey)
  match step.action with
  | some .keepOne =>
      return "Expected pace unchanged; no future Scheduled created."
  | some action =>
      let rule? :=
        match action with
        | .save months =>
            Loam.Tui.ScheduledCoverageSetup.ruleFor? step.state.source months
        | .undecided =>
            match Loam.Tui.ScheduledCoverageSetup.ruleFor? step.state.source 1 with
            | .ok template => .ok { template with everyMonths := 0 }
            | .error message => .error message
        | .keepOne =>
            .error "Unreachable one-off creation action."
      match rule? with
      | .error message =>
          let next := { step.state with notice := message }
          let nextFrame := compileWidget
            (Loam.Tui.ScheduledCoverageSetup.viewCreatedPace bounds next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          createdPaceLoop bounds dataDir next nextFrame
      | .ok rule =>
          let path := Loam.HouseholdPaths.scheduledCoverage dataDir
          match ← Loam.ScheduledCoverageConfig.upsertAt path rule with
          | .error message =>
              let next := { step.state with notice := message }
              let nextFrame := compileWidget
                (Loam.Tui.ScheduledCoverageSetup.viewCreatedPace bounds next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              createdPaceLoop bounds dataDir next nextFrame
          | .ok _ =>
              return "Expected pace: " ++
                (if rule.everyMonths == 0 then "undecided"
                 else Loam.Tui.ScheduledCoverageSetup.cadenceLabel rule.everyMonths) ++
                ". No future Scheduled created; use e to extend explicitly."
  | none =>
      let nextFrame := compileWidget
        (Loam.Tui.ScheduledCoverageSetup.viewCreatedPace bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      createdPaceLoop bounds dataDir step.state nextFrame

/-- The caller has already published this precise Scheduled occurrence. -/
def runAfterCreation
    (bounds : Bounds) (dataDir : System.FilePath)
    (source : Loam.Tui.ScheduledCoverageSetup.Record) : IO String := do
  let state : Loam.Tui.ScheduledCoverageSetup.CreatedPaceState := { source }
  let frame := compileWidget
    (Loam.Tui.ScheduledCoverageSetup.viewCreatedPace bounds state)
  Loam.Tui.Terminal.redrawFromBlank bounds frame
  createdPaceLoop bounds dataDir state frame

end Loam.Tui.ScheduledCoverageSetupSession
