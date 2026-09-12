import Loam.LocusAdmissionPublisher
import Loam.AccountingRolePublisher
import Loam.ActualAuthority
import Loam.HouseholdCommand
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tui.AccountingRoleAdministration
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
surface. That surface computes candidates from current authorities and delegates
its write through `HouseholdCommand`; Locus admission and role assignment stay
separate publication boundaries even though their terminal orchestration shares
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
      | .ok receipt =>
          return "Assigned initial AccountingRole to " ++ receipt.locus.token ++ ". Roles: " ++
            toString receipt.previousCount ++ " -> " ++ toString receipt.currentCount ++ "."
      | .error message => return "AccountingRole assignment refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      runInitialRoleEditor bounds root step.state nextFrame

private def runInitialRoleAdministration
    (bounds : Bounds)
    (dataDir root : System.FilePath) : IO String := do
  let scheduledFile := dataDir / "scheduled.loam"
  let roleFile := dataDir / "accounting-role.loam"
  let world ←
    match ← Loam.ActualAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return "AccountingRole unavailable: " ++ message
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return "AccountingRole unavailable: Scheduled lifecycle authority is missing, malformed, or unsupported."
  if !(← roleFile.pathExists) then
    return "AccountingRole unavailable: authority file is missing."
  let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | return "AccountingRole unavailable: authority is malformed or unsupported."
  let candidates := Loam.AccountingRolePublisher.eligibleInitialLoci
    world.locusAdmission world.events lifecycle.scheduled roles
  let admin := Loam.Tui.AccountingRoleAdministration.initial candidates
  let adminFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds admin)
  Loam.Tui.Terminal.redrawFromBlank bounds adminFrame
  runInitialRoleEditor bounds root admin adminFrame

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
  else
    let step := Loam.Tui.LocusAdmissionAdministration.update state key
    if step.cancel then
      return "Locus admission cancelled."
    match step.publish with
    | some draft =>
        match ← Loam.HouseholdCommand.admitLocus root draft with
        | .ok receipt =>
            return "Admitted Locus " ++ receipt.locus.token ++ " for new writes. Vocabulary: " ++
              toString receipt.previousCount ++ " -> " ++ toString receipt.currentCount ++ "."
        | .error message => return "Locus admission refused: " ++ message
    | none =>
        let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds dataDir root step.state nextFrame

end Loam.Tui.LocusAdmissionAdministrationSession
