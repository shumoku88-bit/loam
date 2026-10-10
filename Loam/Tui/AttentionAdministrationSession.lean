import Loam.Review.AttentionReview
import Loam.HouseholdCommand
import Loam.HouseholdPaths
import Loam.Tui.AttentionAdministration
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.AttentionAdministrationSession

open Loam.Tui.Kernel Loam.Tui.Runtime
set_option autoImplicit false

private def reload (root : System.FilePath) : IO (Except String Loam.AttentionReview.Availability) :=
  Loam.AttentionReview.loadHouseholdEvidence root

private def closeVerb : Loam.Core.AttentionClosureKind → String
  | .resolved => "Resolved"
  | .dropped => "Dropped"

private def draw (bounds : Bounds) (state : Loam.Tui.AttentionAdministration.State)
    (frame : CompiledWidget) (reset : Bool := false) : IO (Bounds × CompiledWidget) := do
  let active ← Loam.Tui.Terminal.currentBounds
  let next := compileWidget (Loam.Tui.AttentionAdministration.viewForBounds active state)
  if reset || active != bounds then Loam.Tui.Terminal.redrawFromBlank active next
  else Loam.Tui.Terminal.emitDirtyDiff active 0 0 frame next
  pure (active, next)

/--
Only accepted publication sets `changed`. Navigation/cancellation does not reload
household evidence; emitted intents still cross HouseholdCommand/AttentionPublisher
and successful writes reload the canonical HouseholdImage Attention answer.
-/
partial def run (bounds : Bounds) (root : System.FilePath)
    (state : Loam.Tui.AttentionAdministration.State) (frame : CompiledWidget)
    (changed : Bool := false) : IO Bool := do
  let (key, repeatCount) ← Loam.Tui.Terminal.readKeyWithRepeat
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (Loam.Tui.AttentionAdministration.viewForBounds active state)
  if key == .other then return (← run bounds root state frame changed)
  let step := Loam.Tui.AttentionAdministration.updateForBounds bounds state key repeatCount
  if step.back then return changed
  match step.add with
  | some draft =>
      match ← Loam.HouseholdCommand.addAttention root draft with
      | .error message =>
          let next := Loam.Tui.AttentionAdministration.withPublishError step.state message
          let (active, nextFrame) ← draw bounds next frame
          run active root next nextFrame changed
      | .ok id =>
          match ← reload root with
          | .error message => throw (IO.userError ("Attention added, but reload failed: " ++ message))
          | .ok evidence =>
              let next := Loam.Tui.AttentionAdministration.refreshed evidence ("Added " ++ id.token ++ ".") step.state
              let (active, nextFrame) ← draw bounds next frame true
              run active root next nextFrame true
  | none =>
      match step.close with
      | some draft =>
          match ← Loam.HouseholdCommand.closeAttention root draft with
          | .error message =>
              let next := Loam.Tui.AttentionAdministration.withPublishError step.state message
              let (active, nextFrame) ← draw bounds next frame
              run active root next nextFrame changed
          | .ok () =>
              match ← reload root with
              | .error message => throw (IO.userError ("Attention closed, but reload failed: " ++ message))
              | .ok evidence =>
                  let next := Loam.Tui.AttentionAdministration.refreshed evidence
                    (closeVerb draft.kind ++ " " ++ draft.attention.token ++ ".") step.state
                  let (active, nextFrame) ← draw bounds next frame true
                  run active root next nextFrame true
      | none =>
          let (active, nextFrame) ← draw bounds step.state frame
          run active root step.state nextFrame changed

end Loam.Tui.AttentionAdministrationSession
