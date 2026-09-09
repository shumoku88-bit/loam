import Loam.LocusAdmissionPublisher
import Loam.AccountingRolePublisher
import Loam.MovementManifestAuthority
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tui.AccountingRoleAdministration
import Loam.Tui.AccountingRoleAdministrationSession
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

The session owns only local interaction state. The authoritative Locus write is
delegated to `LocusAdmissionPublisher.publishManifestAdmission`.

While editing, Tab opens the separate initial-AccountingRole administration
surface. That surface computes candidates from current authorities and delegates
its write to `AccountingRolePublisher`; Locus admission and role assignment stay
separate publication boundaries even though their administration is colocated.
-/

private def runInitialRoleAdministration
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.LocusAdmissionAdministration.State) : IO String := do
  let scheduledFile := root / ".." / "scheduled.loam"
  let roleFile := root / ".." / "accounting-role.loam"
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return "AccountingRole unavailable: " ++ message
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return "AccountingRole unavailable: Scheduled lifecycle authority is missing, malformed, or unsupported."
  if !(← roleFile.pathExists) then
    return "AccountingRole unavailable: authority file is missing."
  let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | return "AccountingRole unavailable: authority is malformed or unsupported."
  let candidates := Loam.AccountingRolePublisher.eligibleInitialLoci
    world lifecycle.scheduled roles
  let admin := Loam.Tui.AccountingRoleAdministration.initial candidates
  let adminFrame := compileWidget (Loam.Tui.AccountingRoleAdministration.view bounds admin)
  IO.print "\x1b[2J"
  Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) adminFrame
  Loam.Tui.AccountingRoleAdministrationSession.run
    bounds scheduledFile root roleFile admin adminFrame

partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.LocusAdmissionAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  if key = .tab then
    match state.phase with
    | .editing =>
        let notice ← runInitialRoleAdministration bounds root state
        let resumed := { state with notice := notice }
        let resumedFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds resumed)
        IO.print "\x1b[2J"
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 (compileWidget (.row [])) resumedFrame
        run bounds root resumed resumedFrame
    | .preview =>
        let step := Loam.Tui.LocusAdmissionAdministration.update state key
        let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root step.state nextFrame
  else
    let step := Loam.Tui.LocusAdmissionAdministration.update state key
    if step.cancel then
      return "Locus admission cancelled."
    match step.publish with
    | some draft =>
        match ← Loam.LocusAdmissionPublisher.publishManifestAdmission root.toString draft with
        | .ok receipt =>
            return "Admitted Locus " ++ receipt.locus.token ++ " for new writes. Vocabulary: " ++
              toString receipt.previousCount ++ " -> " ++ toString receipt.currentCount ++ "."
        | .error message => return "Locus admission refused: " ++ message
    | none =>
        let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
        Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
        run bounds root step.state nextFrame

end Loam.Tui.LocusAdmissionAdministrationSession
