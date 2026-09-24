import Loam.BoundaryPresetConfig
import Loam.CapacityReview
import Loam.CurrentCoverageReview
import Loam.Tui.Capacity
import Loam.Tui.CapacityRebalance
import Loam.Tui.CapacityRebalanceSession
import Loam.Tui.CapacityTransfer
import Loam.Tui.CapacityTransferSession
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.CapacitySession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Capacity workspace session

Owns only the terminal/session lifetime for the existing Capacity presentation.
Coverage comes from the shared Review boundary, while transfer and rebalance
publication remain in their existing session/publisher owners.
-/

private def requireReload {α : Type} (notice : String)
    (reload : IO (Except String α)) : IO α := do
  match ← reload with
  | .error message => throw (IO.userError (notice ++ " Reload failed: " ++ message))
  | .ok value => pure value

private def attachCurrentCoverage
    (dataDir root : System.FilePath)
    (observedAt : String)
    (state : Loam.Tui.Capacity.State) : IO Loam.Tui.Capacity.State := do
  match ← Loam.BoundaryPresetConfig.loadCurrentWindow dataDir observedAt with
  | .error message => return Loam.Tui.Capacity.withoutCoverage message state
  | .ok window =>
    match ← Loam.CurrentCoverageReview.loadSnapshotAt
        dataDir root window.start observedAt window.endExclusive with
    | .error message => return Loam.Tui.Capacity.withoutCoverage message state
    | .ok coverage =>
      return Loam.Tui.Capacity.withCoverage coverage ("preset " ++ window.source) state

/-- All-retained Capacity session with shared current coverage and local transfer/rebalance entrances. -/
partial def loop
    (bounds : Bounds) (dataDir root : System.FilePath)
    (observedAt : String)
    (state : Loam.Tui.Capacity.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let backKey := key = .escape || key = .input 'q' || key = .input 'Q'
  let event : Loam.Tui.Capacity.Event :=
    if backKey then .back
    else
      match key with
      | .up | .input 'k' | .input 'K' => .up
      | .down | .input 'j' | .input 'J' => .down
      | .input 't' | .input 'T' => .transfer
      | .input 'r' | .input 'R' => .rebalance
      | _ => .other
  match Loam.Tui.Capacity.update state event with
  | .back => return ()
  | .transfer current =>
      let editor := Loam.Tui.CapacityTransfer.initial
        current.snapshot observedAt (Loam.Tui.Capacity.selectedPurpose? current)
      let editorFrame := compileWidget (Loam.Tui.CapacityTransfer.view editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.CapacityTransferSession.run
        bounds root editor editorFrame
      let fresh ← requireReload notice (Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir)
      let refreshed := Loam.Tui.Capacity.refreshed fresh current
      let covered ← attachCurrentCoverage dataDir root observedAt refreshed
      let next := { covered with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      loop bounds dataDir root observedAt next nextFrame
  | .rebalance current =>
      let editor := Loam.Tui.CapacityRebalance.initial
        current.snapshot current.coverage observedAt (Loam.Tui.Capacity.selectedPurpose? current)
      let editorFrame := compileWidget (Loam.Tui.CapacityRebalance.view bounds editor)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame editorFrame
      let notice ← Loam.Tui.CapacityRebalanceSession.run
        bounds root editor editorFrame
      let fresh ← requireReload notice (Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir)
      let refreshed := Loam.Tui.Capacity.refreshed fresh current
      let covered ← attachCurrentCoverage dataDir root observedAt refreshed
      let next := { covered with notice := notice }
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
      loop bounds dataDir root observedAt next nextFrame
  | .stay next =>
      let nextFrame := compileWidget (Loam.Tui.Capacity.view next)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      loop bounds dataDir root observedAt next nextFrame


def run
    (bounds : Bounds) (dataDir root : System.FilePath)
    (observedAt : String) (state : Loam.Tui.Capacity.State)
    (homeFrame : CompiledWidget) : IO Unit := do
  let capacity ← attachCurrentCoverage dataDir root observedAt state
  let frame := compileWidget (Loam.Tui.Capacity.view capacity)
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 homeFrame frame
  loop bounds dataDir root observedAt capacity frame

end Loam.Tui.CapacitySession
