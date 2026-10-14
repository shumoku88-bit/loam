import Loam.Tui.Kernel
import Loam.Tui.ModalSurface
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.EditorSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/--
Shared terminal shell for editors whose publication refusal is returned to the
same local editor state. Domain state, drafts, commands, and success values stay
caller-owned; stale-state editors deliberately do not use this helper.
-/
structure Step (State Draft : Type) where
  state : State
  cancel : Bool := false
  publish : Option Draft := none
  deriving Repr

partial def runUntilPublished
    {State Draft ResultType : Type}
    (bounds : Bounds)
    (update : State → Loam.Tui.Terminal.Key → Step State Draft)
    (view : State → Widget)
    (withPublishError : State → String → State)
    (cancelResult : ResultType)
    (publish : Draft → IO (Except String ResultType))
    (state : State)
    (frame : CompiledWidget) : IO ResultType := do
  let step := update state (← Loam.Tui.Terminal.readKey)
  if step.cancel then
    return cancelResult
  match step.publish with
  | some draft =>
      match ← publish draft with
      | .ok result =>
          return result
      | .error message =>
          let next := withPublishError step.state message
          let nextFrame := compileWidget (view next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          runUntilPublished bounds update view withPublishError cancelResult publish next nextFrame
  | none =>
      let nextFrame := compileWidget (view step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runUntilPublished bounds update view withPublishError cancelResult publish step.state nextFrame


/--
Resize-aware editor shell. A terminal size change rebuilds the *same* local
editor state at fresh bounds before interpreting the next key or publication
request. In particular, viewport-gated Publish always sees current geometry.
The older fixed-bounds shell stays available for unrelated editors.
-/
partial def runUntilPublishedResizing
    {State Draft ResultType : Type}
    (bounds : Bounds)
    (update : Bounds → State → Loam.Tui.Terminal.Key → Step State Draft)
    (view : Bounds → State → Widget)
    (withPublishError : State → String → State)
    (cancelResult : ResultType)
    (publish : Draft → IO (Except String ResultType))
    (state : State)
    (frame : CompiledWidget) : IO ResultType := do
  let key ← Loam.Tui.Terminal.readKey
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (view active state)
  let step := update bounds state key
  if step.cancel then
    return cancelResult
  match step.publish with
  | some draft =>
      match ← publish draft with
      | .ok result =>
          return result
      | .error message =>
          let next := withPublishError step.state message
          let nextFrame := compileWidget (view bounds next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          runUntilPublishedResizing bounds update view withPublishError
            cancelResult publish next nextFrame
  | none =>
      let nextFrame := compileWidget (view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runUntilPublishedResizing bounds update view withPublishError
        cancelResult publish step.state nextFrame

/--
Resize-aware floating editor session. Only geometry, parent repaint and frame
diffs are shared; the caller retains local transitions, publication refusal,
and its authoritative publisher callback. Rebuild the parent at current bounds
on resize rather than retaining stale pixels or household evidence.
Callers may opt into skipping .other only when their domain update is known
to treat that key as inert. The default preserves generic update semantics.
-/
partial def runUntilPublishedAdaptive
    {State Draft ResultType : Type}
    (bounds : Bounds)
    (geometry : Bounds → Option Loam.Tui.ModalSurface.Rectangle)
    (parent : Bounds → CompiledWidget)
    (update : Bounds → State → Loam.Tui.Terminal.Key → Step State Draft)
    (view : Bounds → State → Widget)
    (withPublishError : State → String → State)
    (cancelResult : ResultType)
    (publish : Draft → IO (Except String ResultType))
    (state : State)
    (frame : CompiledWidget)
    (skipInertOther : Bool := false) : IO ResultType := do
  let key ← Loam.Tui.Terminal.readKey
  let active ← Loam.Tui.Terminal.currentBounds
  let region := geometry active
  let frame ←
    if active == bounds then pure frame
    else do
      let resized := compileWidget (view active state)
      Loam.Tui.ModalSurface.repaintOverParent active region (parent active) resized
      pure resized
  -- An opted-in, unchanged frame needs neither state transition nor painting.
  -- On live resize, still repaint and pass the key to the domain updater.
  if skipInertOther && key == .other && active == bounds then
    return (← runUntilPublishedAdaptive active geometry parent update view
      withPublishError cancelResult publish state frame skipInertOther)
  let step := update active state key
  if step.cancel then return cancelResult
  match step.publish with
  | some draft =>
      match ← publish draft with
      | .ok result => return result
      | .error message =>
          let next := withPublishError step.state message
          let nextFrame := compileWidget (view active next)
          Loam.Tui.ModalSurface.paint active region .dirtyDiff frame nextFrame
          runUntilPublishedAdaptive active geometry parent update view
            withPublishError cancelResult publish next nextFrame skipInertOther
  | none =>
      let nextFrame := compileWidget (view active step.state)
      Loam.Tui.ModalSurface.paint active region .dirtyDiff frame nextFrame
      runUntilPublishedAdaptive active geometry parent update view
        withPublishError cancelResult publish step.state nextFrame skipInertOther


/--
Resize-aware shell for editors that must **leave on any publication attempt**,
including a publisher refusal. For Capacity, a refusal may mean that shared
evidence changed while the draft was open. The caller must reload an authoritative
snapshot before permitting a retry, never continue in a stale editor.

Unlike `runUntilPublishedResizing`, `publish` here returns a terminal result
rather than an `Except` to retry locally. Both acceptance and refusal end the
session. Domain validation and keyboard meanings stay caller-owned.
-/
partial def runUntilAttemptResizing
    {State Draft ResultType : Type}
    (bounds : Bounds)
    (update : State → Loam.Tui.Terminal.Key → Step State Draft)
    (view : Bounds → State → Widget)
    (cancel : State → ResultType)
    (publish : Draft → IO ResultType)
    (state : State)
    (frame : CompiledWidget) : IO ResultType := do
  let key ← Loam.Tui.Terminal.readKey
  let (bounds, frame) ← Loam.Tui.Terminal.refreshFrame bounds frame fun active =>
    compileWidget (view active state)
  let step := update state key
  if step.cancel then
    return cancel step.state
  match step.publish with
  | some draft => publish draft
  | none =>
      let nextFrame := compileWidget (view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runUntilAttemptResizing bounds update view cancel publish step.state nextFrame

end Loam.Tui.EditorSession
