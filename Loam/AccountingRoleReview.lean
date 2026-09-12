import Loam.AccountingRolePublisher
import Loam.ActualAuthority
import Loam.Persistence.AccountingRolePersistence
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

/--
Load the current initial-role candidate set from canonical household evidence.
The Actual source remains explicit so callers do not lose the existing selected
world distinction merely to hide Scheduled and AccountingRole file topology.
-/
def loadInitialCandidates
    (dataDir actualRoot : System.FilePath) : IO (Except String (List LocusId)) := do
  let scheduledFile := dataDir / "scheduled.loam"
  let roleFile := dataDir / "accounting-role.loam"
  let world ←
    match ← Loam.ActualAuthority.loadSelectedWorld? actualRoot with
    | .ok world => pure world
    | .error message => return .error message
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  if !(← roleFile.pathExists) then
    return .error "loam: AccountingRole authority file is missing"
  let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | return .error "loam: AccountingRole authority is malformed or unsupported"
  return .ok <| Loam.AccountingRolePublisher.eligibleInitialLoci
    world.locusAdmission world.events lifecycle.scheduled roles

end Loam.AccountingRoleReview
