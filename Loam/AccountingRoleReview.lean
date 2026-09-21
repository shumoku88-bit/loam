import Loam.AccountingRolePublisher
import Loam.MovementWorldLoader
import Loam.CurrentQuantityAnchorPublisher
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.AccountingRoleReview

open Loam.Core

set_option autoImplicit false

/-!
# Initial AccountingRole review

This is the presentation-neutral read boundary for the currently qualified
initial AccountingRole question: which admitted Loci are still eligible for one
first role assignment?

Candidate semantics remain owned by `AccountingRolePublisher.eligibleInitialLoci`
so read presentation cannot drift from publication admission. This module owns
only the canonical household evidence loading needed to ask that question. It
does not create role history, infer roles, or add a second source of truth.
-/

private def loadCurrentAnchor
    (dataDir : System.FilePath) : IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  let anchorFile := Loam.CurrentQuantityAnchorPublisher.path dataDir
  if ← anchorFile.pathExists then
    match ← Loam.Persistence.loadCurrentQuantityAnchor? anchorFile with
    | some anchor => return .ok anchor
    | none => return .error "loam: current quantity anchor authority is malformed or unsupported"
  else
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty

/--
Load the current initial-role candidate set from canonical household evidence.
The Actual source remains explicit so callers do not lose the existing selected
world distinction merely to hide Scheduled, current-anchor and AccountingRole
file topology. Candidate results are advisory; publication re-reads the guarded
authorities under writer ownership.
-/
def loadInitialCandidates
    (dataDir actualRoot : System.FilePath) : IO (Except String (List LocusId)) := do
  let scheduledFile := dataDir / "scheduled.loam"
  let roleFile := dataDir / "accounting-role.loam"
  let world ←
    match ← Loam.MovementWorldLoader.loadSelectedWorld? actualRoot with
    | .ok world => pure world
    | .error message => return .error message
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  let anchor ←
    match ← loadCurrentAnchor dataDir with
    | .ok value => pure value
    | .error message => return .error message
  if !(← roleFile.pathExists) then
    return .error "loam: AccountingRole authority file is missing"
  let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | return .error "loam: AccountingRole authority is malformed or unsupported"
  return .ok <| Loam.AccountingRolePublisher.eligibleInitialLoci
    world.locusAdmission world.events lifecycle.scheduled anchor roles

end Loam.AccountingRoleReview
