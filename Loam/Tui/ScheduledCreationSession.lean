import Loam.HouseholdCommand
import Loam.Publisher.ScheduledCreationPublisher
import Loam.Review.ScheduledReview
import Loam.Tui.EditorSession
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.ScheduledCreation
import Loam.Tui.ScheduledCoverageSetupSession
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCreationSession

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/--
Run the existing Scheduled editor until the user either confirms one draft or
cancels, without publishing anything.

Higher-level construction helpers can therefore collect several explicit drafts,
show the complete set, and only then publish through the ordinary household
command boundary.
-/
def collectDraft
    (bounds : Bounds)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) :
    IO (Option Loam.ScheduledCreationPublisher.Draft) :=
  -- Reuse the same resize/keyboard/redraw shell as standalone creation.
  -- Returning a draft to the caller is not a household publication; the
  -- generation workflow still owns its explicit final review and write.
  Loam.Tui.EditorSession.runUntilPublishedResizing bounds
    (fun active editor key => Loam.Tui.ScheduledCreation.updateForBounds active known editor key)
    (fun active editor => Loam.Tui.ScheduledCreation.view active known editor)
    Loam.Tui.ScheduledCreation.withPublishError
    none
    (fun draft => pure (.ok (some draft)))
    state frame

/--
Run one presentation-only Scheduled creation editor session, returning the created Scheduled identity if published.
-/
def runWithScheduledId
    (bounds : Bounds) (root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) :
    IO (Option ScheduledId × String) :=
  Loam.Tui.EditorSession.runUntilPublishedResizing bounds
    (fun active editor key => Loam.Tui.ScheduledCreation.updateForBounds
      active known editor key)
    (fun active editor => Loam.Tui.ScheduledCreation.view active known editor)
    Loam.Tui.ScheduledCreation.withPublishError
    (none, "Scheduled creation cancelled.")
    (fun draft => do
      match ← Loam.HouseholdCommand.createScheduled root draft with
      | .ok scheduledId =>
          return .ok
            (some scheduledId,
              "Scheduled " ++ scheduledId.token ++ " for " ++ draft.scheduledOn ++ ".")
      | .error message =>
          return .error message)
    state frame

/--
After a successful ordinary create, re-read its exact identity and optionally
offer expected-pace monitoring. Both compact and floating sessions use this
same post-publication continuation; group draft collection never calls it.
-/
private def finishCreated
    (dataDir root : System.FilePath)
    (created? : Option ScheduledId) (notice : String) : IO String := do
  let some created := created? | return notice
  -- Never silently infer a one-off or recurrence when the fresh read fails.
  let .ok evidence ← Loam.ScheduledReview.loadHouseholdEvidence dataDir root
    | return notice ++ " Expected-pace setup unavailable: Scheduled evidence could not be reloaded."
  let .ok records := Loam.ScheduledReview.orderedCurrentOpenRecords evidence
    | return notice ++ " Expected-pace setup unavailable: open Scheduled evidence is unreadable."
  let some source := records.find? (fun record => record.id.token == created.token)
    | return notice ++ " Expected-pace setup unavailable: new Scheduled identity not found."
  let bounds ← Loam.Tui.Terminal.currentBounds
  let paceNotice ← Loam.Tui.ScheduledCoverageSetupSession.runAfterCreation
    bounds dataDir source
  return notice ++ " " ++ paceNotice

/--
Original full-screen Scheduled creation session. Kept for existing consumers;
both ordinary workspace launchers now use the adaptive variant below.
-/
def run
    (bounds : Bounds) (dataDir root : System.FilePath)
    (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget) : IO String := do
  let (created?, notice) ← runWithScheduledId bounds root known state frame
  finishCreated dataDir root created? notice


/-!
# Adaptive standalone creation

The original collectDraft / runWithScheduledId paths above remain available
to group generation and explicit continuation. Only the two ordinary create
launchers use this new surface. The shared modal owns no Scheduled authority.
-/

/-- Standalone creation only floats when its complete bounded form can fit. -/
def floatingGeometry? (bounds : Bounds) : Option Loam.Tui.ModalSurface.Rectangle :=
  Loam.Tui.ModalSurface.centered? bounds 78 35 88 33

def editorBounds (bounds : Bounds) : Bounds :=
  Loam.Tui.ModalSurface.contentBounds bounds (floatingGeometry? bounds)

/-- Same Scheduled fields and preview in either physical presentation mode. -/
def modalViewForBounds (bounds : Bounds) (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) : Widget :=
  Loam.Tui.ModalSurface.framedView bounds (floatingGeometry? bounds)
    "Scheduled / New"
    (fun inner => Loam.Tui.ScheduledCreation.view inner known state)

private def modalFrame (bounds : Bounds) (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) : CompiledWidget :=
  compileWidget (modalViewForBounds bounds known state)

/--
The standalone creation editor owns refusal-to-edit and its one precise
publisher. No publication is attempted by merely entering preview or resizing.
-/
private partial def modalLoop
    (bounds : Bounds) (root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledCreation.State) (frame : CompiledWidget)
    (parent : Bounds → CompiledWidget) : IO (Option ScheduledId × String) := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let rect := floatingGeometry? active
  let frame ←
    if active == bounds then pure frame
    else do
      let next := modalFrame active known state
      Loam.Tui.ModalSurface.repaintOverParent active rect (parent active) next
      pure next
  if key == .other then
    return (← modalLoop active root known state frame parent)
  let step := Loam.Tui.ScheduledCreation.updateForBounds
    (editorBounds active) known state key
  if step.cancel then
    return (none, "Scheduled creation cancelled.")
  let outcome ←
    match step.publish with
    | none => pure (.ok step.state :
        Except (ScheduledId × String) Loam.Tui.ScheduledCreation.State)
    | some draft =>
        match ← Loam.HouseholdCommand.createScheduled root draft with
        | .ok scheduledId =>
            pure (.error (scheduledId,
              "Scheduled " ++ scheduledId.token ++ " for " ++ draft.scheduledOn ++ "."))
        | .error message =>
            pure (.ok (Loam.Tui.ScheduledCreation.withPublishError step.state message))
  match outcome with
  | .error (created, notice) => return (some created, notice)
  | .ok nextState =>
      let nextFrame := modalFrame active known nextState
      Loam.Tui.ModalSurface.paint active rect .dirtyDiff frame nextFrame
      modalLoop active root known nextState nextFrame parent

/--
Return an exact created identity, preserving the ordinary creation publisher
without changing continuation's independent full-screen call path.
-/
def runAdaptiveWithScheduledId
    (bounds : Bounds) (root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledCreation.State)
    (parent : Bounds → CompiledWidget) : IO (Option ScheduledId × String) := do
  let active ← Loam.Tui.Terminal.currentBounds
  let rect := floatingGeometry? active
  let frame := modalFrame active known state
  if active == bounds then
    Loam.Tui.ModalSurface.paint active rect .fromBlank
      (compileWidget (.row [])) frame
  else
    Loam.Tui.ModalSurface.repaintOverParent active rect (parent active) frame
  modalLoop active root known state frame parent

/--
Standalone create keeps the existing *post-publication* expected-pace setup.
This is deliberately not invoked for generation's draft collector.
-/
def runAdaptive
    (bounds : Bounds) (dataDir root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledCreation.State)
    (parent : Bounds → CompiledWidget) : IO String := do
  let (created?, notice) ← runAdaptiveWithScheduledId bounds root known state parent
  finishCreated dataDir root created? notice

end Loam.Tui.ScheduledCreationSession
