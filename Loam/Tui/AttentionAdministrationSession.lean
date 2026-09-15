import Loam.AttentionReview
import Loam.HouseholdCommand
import Loam.Tui.AttentionAdministration
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.AttentionAdministrationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

private def reload
    (root : System.FilePath) : IO (Except String Loam.AttentionReview.Availability) :=
  Loam.AttentionReview.loadEvidence (root / "attention.loam")

private def closeVerb : Loam.Core.AttentionClosureKind → String
  | .resolved => "Resolved"
  | .dropped => "Dropped"

/--
Run the small Attention writer surface.

The session owns no lifecycle semantics. Every emitted intent crosses
`HouseholdCommand` and is re-admitted by `AttentionPublisher` under writer
ownership before this loop reloads the canonical read answer.
-/
partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.AttentionAdministration.State)
    (frame : CompiledWidget) : IO Unit := do
  let step := Loam.Tui.AttentionAdministration.update state (← Loam.Tui.Terminal.readKey)
  if step.back then return
  match step.add with
  | some draft =>
      match ← Loam.HouseholdCommand.addAttention root draft with
      | .error message =>
          let next := Loam.Tui.AttentionAdministration.withPublishError step.state message
          let nextFrame := compileWidget (Loam.Tui.AttentionAdministration.view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root next nextFrame
      | .ok id =>
          match ← reload root with
          | .error message => throw (IO.userError ("Attention added, but reload failed: " ++ message))
          | .ok evidence =>
              let next := Loam.Tui.AttentionAdministration.refreshed
                evidence ("Added " ++ id.token ++ ".") step.state
              let nextFrame := compileWidget (Loam.Tui.AttentionAdministration.view next)
              Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
              run bounds root next nextFrame
  | none =>
      match step.close with
      | some draft =>
          match ← Loam.HouseholdCommand.closeAttention root draft with
          | .error message =>
              let next := Loam.Tui.AttentionAdministration.withPublishError step.state message
              let nextFrame := compileWidget (Loam.Tui.AttentionAdministration.view next)
              Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
              run bounds root next nextFrame
          | .ok () =>
              match ← reload root with
              | .error message => throw (IO.userError ("Attention closed, but reload failed: " ++ message))
              | .ok evidence =>
                  let notice := closeVerb draft.kind ++ " " ++ draft.attention.token ++ "."
                  let next := Loam.Tui.AttentionAdministration.refreshed evidence notice step.state
                  let nextFrame := compileWidget (Loam.Tui.AttentionAdministration.view next)
                  Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
                  run bounds root next nextFrame
      | none =>
          let nextFrame := compileWidget (Loam.Tui.AttentionAdministration.view step.state)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          run bounds root step.state nextFrame

end Loam.Tui.AttentionAdministrationSession
