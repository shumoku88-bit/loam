import Loam.Tui.Kernel
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

end Loam.Tui.EditorSession
