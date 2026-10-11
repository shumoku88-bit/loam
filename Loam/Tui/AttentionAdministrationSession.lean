import Loam.Review.AttentionReview
import Loam.HouseholdCommand
import Loam.HouseholdPaths
import Loam.Tui.AttentionAdministration
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
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

/-!
Only the Attention *close confirmation* is a floating modal. Browsing,
new-context, due-meaning and date-entry retain their existing workspace loop.
This keeps different control-flow assumptions out of ModalSurface.
-/

/-- A close prompt floats when its content can retain review and actions. -/
def closeGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 72 24 76 21

/-- Domain-owned review receives available inner bounds, not terminal bounds. -/
def closeContentBounds (bounds : Bounds) : Bounds :=
  match closeGeometry? bounds with
  | none => bounds
  | some region => { width := region.width - 1, height := region.height - 1 }

def closeViewForBounds (bounds : Bounds)
    (state : Loam.Tui.AttentionAdministration.State) : Widget :=
  match closeGeometry? bounds with
  | none => Loam.Tui.AttentionAdministration.viewForBounds bounds state
  | some region =>
      Loam.Tui.Layout.framedPanel region.width region.height
        "Attention / Close"
        (Loam.Tui.AttentionAdministration.viewForBounds
          (closeContentBounds bounds) state) true

private def parentFrame (bounds : Bounds)
    (browse : Loam.Tui.AttentionAdministration.State) : CompiledWidget :=
  compileWidget (Loam.Tui.AttentionAdministration.viewForBounds bounds browse)

/--
Keep selected identity and precise resolve/drop intent in Attention's existing
pure update. Restore parent frame before returning to the existing publisher and
reload loop, so a rejected publication cannot diff against overlay coordinates.
-/
private partial def closeLoop
    (bounds : Bounds) (browse : Loam.Tui.AttentionAdministration.State)
    (state : Loam.Tui.AttentionAdministration.State)
    (frame : CompiledWidget) :
    IO (Loam.Tui.AttentionAdministration.Step × Bounds × CompiledWidget) := do
  let (key, repeatCount) ← Loam.Tui.Terminal.readKeyWithRepeat
  let active ← Loam.Tui.Terminal.currentBounds
  let rectangle := closeGeometry? active
  let frame ←
    if active == bounds then pure frame
    else do
      let next := compileWidget (closeViewForBounds active state)
      Loam.Tui.ModalSurface.repaintOverParent active rectangle
        (parentFrame active browse) next
      pure next
  if key == .other then
    closeLoop active browse state frame
  else
    let step := Loam.Tui.AttentionAdministration.updateForBounds
      (closeContentBounds active) state key repeatCount
    if step.close.isSome || step.state.mode == .browse then
      let nextParent := parentFrame active browse
      Loam.Tui.Terminal.redrawFromBlank active nextParent
      return (step, active, nextParent)
    else
      let next := compileWidget (closeViewForBounds active step.state)
      Loam.Tui.ModalSurface.paint active rectangle .dirtyDiff frame next
      closeLoop active browse step.state next

private def openClose
    (bounds : Bounds) (browse : Loam.Tui.AttentionAdministration.State)
    (confirmation : Loam.Tui.AttentionAdministration.State) :
    IO (Loam.Tui.AttentionAdministration.Step × Bounds × CompiledWidget) := do
  let active ← Loam.Tui.Terminal.currentBounds
  let rectangle := closeGeometry? active
  let frame := compileWidget (closeViewForBounds active confirmation)
  if active == bounds then
    Loam.Tui.ModalSurface.paint active rectangle .fromBlank
      (compileWidget (.row [])) frame
  else
    Loam.Tui.ModalSurface.repaintOverParent active rectangle
      (parentFrame active browse) frame
  closeLoop active browse confirmation frame

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
  -- Browse launches a short-lived confirmation; all original writers stay here.
  let (step, bounds, frame) ←
    if state.mode == .browse &&
        (match step.state.mode with | .confirmClose _ _ => true | _ => false) then
      openClose bounds state step.state
    else
      pure (step, bounds, frame)
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
