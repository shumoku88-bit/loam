import Loam.CapacityReview
import Loam.CycleBudgetReview
import Loam.Tui.CapacityRebalance
import Loam.Tui.CapacityRebalanceSession
import Loam.Tui.CapacityTransfer
import Loam.Tui.CapacityTransferSession
import Loam.Tui.CycleBudget
import Loam.Tui.Kernel
import Loam.Tui.Runtime
import Loam.Tui.ScheduledRouting
import Loam.Tui.ScheduledRoutingSession
import Loam.Tui.Terminal

namespace Loam.Tui.CycleBudgetSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Cycle Budget workspace session

Owns only the terminal/session orchestration for the existing Cycle Budget
presentation. It composes existing Capacity and Scheduled-routing sessions and
shared Review answers without defining household semantics or publication rules.
-/

/-- Current-cycle Budget composes shared actions without adding a second semantic engine. -/
partial def run (bounds : Bounds) (dataDir root : System.FilePath)
    (state : Loam.Tui.CycleBudget.State) (frame : CompiledWidget) : IO Unit := do
  let key ← Loam.Tui.Terminal.readKey
  let (next, intent) := Loam.Tui.CycleBudget.update bounds state key
  match intent with
  | .home => return ()
  | .stay =>
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
    run bounds dataDir root next nextFrame
  | .rebalance =>
    let notice ←
      match ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir with
      | .error message => pure ("Capacity unavailable: " ++ message)
      | .ok capacitySnapshot =>
        let coverage :=
          match state.snapshot.coverage with
          | .ok coverage => some coverage
          | .error _ => none
        let editor := Loam.Tui.CapacityRebalance.initial
          capacitySnapshot coverage state.snapshot.observedAt
        let editorFrame := compileWidget (Loam.Tui.CapacityRebalance.view bounds editor)
        Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
        Loam.Tui.CapacityRebalanceSession.run
          bounds root editor editorFrame
    let fresh ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root state.snapshot.observedAt
    let next := Loam.Tui.CycleBudget.refreshed fresh notice state
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    run bounds dataDir root next nextFrame
  | .unresolved =>
    let notice ←
      match state.snapshot.coverage with
      | .error message => pure ("CurrentCoverage unavailable: " ++ message)
      | .ok coverage =>
        let routingState := Loam.Tui.ScheduledRouting.initial coverage state.snapshot.observedAt
        let routingFrame := compileWidget (Loam.Tui.ScheduledRouting.view bounds routingState)
        Loam.Tui.Terminal.redrawFromBlank bounds routingFrame
        Loam.Tui.ScheduledRoutingSession.run bounds root routingState routingFrame
    let fresh ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root state.snapshot.observedAt
    let next := Loam.Tui.CycleBudget.refreshed fresh notice state
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    run bounds dataDir root next nextFrame
  | .grant row =>
    let notice ←
      match ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir with
      | .error message => pure ("Capacity unavailable: " ++ message)
      | .ok capacitySnapshot =>
        let residual :=
          match state.snapshot.funding with
          | .ok summary => some summary.residualBeforeUnresolved
          | .error _ => none
        let editor := Loam.Tui.CapacityTransfer.initialGrant
          capacitySnapshot state.snapshot.observedAt row residual
        let editorFrame := compileWidget (Loam.Tui.CapacityTransfer.view editor)
        Loam.Tui.Terminal.redrawFromBlank bounds editorFrame
        Loam.Tui.CapacityTransferSession.run
          bounds root editor editorFrame
    let fresh ← Loam.CycleBudgetReview.loadSnapshotAt dataDir root state.snapshot.observedAt
    let next := Loam.Tui.CycleBudget.refreshed fresh notice state
    let nextFrame := compileWidget (Loam.Tui.CycleBudget.view bounds next)
    Loam.Tui.Terminal.redrawFromBlank bounds nextFrame
    run bounds dataDir root next nextFrame


end Loam.Tui.CycleBudgetSession
