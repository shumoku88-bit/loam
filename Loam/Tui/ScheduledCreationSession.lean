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

/--
Return the exact created Scheduled identity. The existing adaptive session now
owns the standalone modal's key, resize, paint, and refusal-retry loop; this
caller still owns the creation command and post-publication continuation.
Group draft collection retains its distinct non-publishing entry point.
-/
def runAdaptiveWithScheduledId
    (bounds : Bounds) (root : System.FilePath) (known : List String)
    (state : Loam.Tui.ScheduledCreation.State)
    (parent : Bounds → CompiledWidget) : IO (Option ScheduledId × String) := do
  let active ← Loam.Tui.Terminal.currentBounds
  let rect := floatingGeometry? active
  let frame := compileWidget (modalViewForBounds active known state)
  Loam.Tui.ModalSurface.paintEntrance bounds active rect parent frame
  Loam.Tui.EditorSession.runUntilPublishedAdaptive active
    floatingGeometry?
    parent
    (fun current editor key =>
      Loam.Tui.ScheduledCreation.updateForBounds
        (editorBounds current) known editor key)
    (fun current editor => modalViewForBounds current known editor)
    Loam.Tui.ScheduledCreation.withPublishError
    (none, "Scheduled creation cancelled.")
    (fun draft => do
      match ← Loam.HouseholdCommand.createScheduled root draft with
      | .ok scheduledId =>
          return .ok (some scheduledId,
            "Scheduled " ++ scheduledId.token ++ " for " ++ draft.scheduledOn ++ ".")
      | .error message => return .error message)
    state frame

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
