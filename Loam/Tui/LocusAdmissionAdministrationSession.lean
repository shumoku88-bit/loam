import Loam.LocusAdmissionPublisher
import Loam.Review.AccountingRoleReview
import Loam.Review.BoundedHistorySupportReview
import Loam.HouseholdCommand
import Loam.Tui.AccountingRoleAdministration
import Loam.Tui.BoundedHistorySupportAdministration
import Loam.Tui.Kernel
import Loam.Tui.LocusAdmissionAdministration
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.LocusAdmissionAdministrationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Locus admission administration terminal session

The session owns only local interaction state. Authoritative writes are delegated
to the shared household command boundary.

While editing, Tab opens the separate initial-AccountingRole administration
surface and Shift-Tab opens bounded historical-support administration. Both
surfaces compute candidates from current authorities and delegate writes through
`HouseholdCommand`; Locus admission, role assignment, and history certification
remain separate publication boundaries even though terminal orchestration shares
this session.
-/

private partial def runInitialRoleEditor
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.AccountingRoleAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.AccountingRoleAdministration.update state key
  if step.cancel then
    return "AccountingRole assignment cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.assignInitialAccountingRole root draft with
      | .ok () =>
          return "Assigned initial AccountingRole to " ++ draft.locus.token ++ "."
      | .error message => return "AccountingRole assignment refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runInitialRoleEditor bounds root step.state nextFrame

private def runInitialRoleAdministration
    (bounds : Bounds)
    (dataDir root : System.FilePath) : IO String := do
  let candidates ←
    match ← Loam.AccountingRoleReview.loadInitialCandidates dataDir root with
    | .ok candidates => pure candidates
    | .error message => return "AccountingRole unavailable: " ++ message
  let admin := Loam.Tui.AccountingRoleAdministration.initial candidates
  let adminFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds admin)
  Loam.Tui.Terminal.redrawFromBlank bounds adminFrame
  runInitialRoleEditor bounds root admin adminFrame


private partial def runHistorySupportEditor
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.BoundedHistorySupportAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.BoundedHistorySupportAdministration.update state key
  if step.cancel then
    return "History support administration cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.HouseholdCommand.updateBoundedHistorySupport root draft with
      | .ok () =>
          match draft.startDay with
          | some day =>
              return "History support for " ++ draft.coordinate.locus.token ++
                " / " ++ draft.coordinate.measure.token ++ " now starts " ++ day ++ "."
          | none =>
              return "Removed bounded history support for " ++
                draft.coordinate.locus.token ++ " / " ++ draft.coordinate.measure.token ++ "."
      | .error message =>
          let next := { step.state with notice := message }
          let nextFrame :=
            compileWidget (Loam.Tui.BoundedHistorySupportAdministration.view bounds next)
          Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
          runHistorySupportEditor bounds root next nextFrame
  | none =>
      let nextFrame :=
        compileWidget (Loam.Tui.BoundedHistorySupportAdministration.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runHistorySupportEditor bounds root step.state nextFrame

private def runHistorySupportAdministration
    (bounds : Bounds)
    (root : System.FilePath) : IO String := do
  let snapshot ←
    match ← Loam.BoundedHistorySupportReview.loadSnapshot root with
    | .ok snapshot => pure snapshot
    | .error message => return "History support unavailable: " ++ message
  let admin := Loam.Tui.BoundedHistorySupportAdministration.initial snapshot
  let adminFrame :=
    compileWidget (Loam.Tui.BoundedHistorySupportAdministration.view bounds admin)
  Loam.Tui.Terminal.redrawFromBlank bounds adminFrame
  runHistorySupportEditor bounds root admin adminFrame

partial def run
    (bounds : Bounds)
    (dataDir root : System.FilePath)
    (state : Loam.Tui.LocusAdmissionAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .tab then
    match state.phase with
    | .editing =>
        let notice ← runInitialRoleAdministration bounds dataDir root
        let resumed := { state with notice := notice }
        let resumedFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds resumed)
        Loam.Tui.Terminal.redrawFromBlank bounds resumedFrame
        run bounds dataDir root resumed resumedFrame
    | .preview =>
        let step := Loam.Tui.LocusAdmissionAdministration.update state key
        let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds dataDir root step.state nextFrame
  else if key = .shiftTab then
    match state.phase with
    | .editing =>
        let notice ← runHistorySupportAdministration bounds root
        let resumed := { state with notice := notice }
        let resumedFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds resumed)
        Loam.Tui.Terminal.redrawFromBlank bounds resumedFrame
        run bounds dataDir root resumed resumedFrame
    | .preview =>
        let step := Loam.Tui.LocusAdmissionAdministration.update state key
        let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds dataDir root step.state nextFrame
  else
    let step := Loam.Tui.LocusAdmissionAdministration.update state key
    if step.cancel then
      return "Locus admission cancelled."
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.admitLocus root draft with
        | .ok () =>
            return "Admitted Locus " ++ draft.token ++ " for new writes."
        | .error message => return "Locus admission refused: " ++ message
    | none =>
        let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds dataDir root step.state nextFrame

end Loam.Tui.LocusAdmissionAdministrationSession
