import Loam.Publisher.AccountingRolePublisher
import Loam.MovementWorldLoader
import Loam.Authority.CurrentSupportAuthority
import Loam.Authority.AccountingRoleAuthority
import Loam.Authority.ScheduledLifecycleAuthority

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
world distinction merely to hide Scheduled, current-anchor and AccountingRole
file topology. Candidate results are advisory; publication re-reads the guarded
authorities under writer ownership.
-/
def loadInitialCandidates
    (dataDir actualRoot : System.FilePath) : IO (Except String (List LocusId)) := do
  let world ←
    match ← Loam.MovementWorldLoader.loadSelectedWorld? actualRoot with
    | .ok world => pure world
    | .error message => return .error message
  let lifecycle ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? dataDir with
    | .ok lifecycle => pure lifecycle
    | .error message => return .error message
  let anchor ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? dataDir with
    | .ok observed => pure observed.snapshot.anchor
    | .error message => return .error message
  let roles ←
    match ← Loam.AccountingRoleAuthority.loadHouseholdCurrent? dataDir with
    | .ok roles => pure roles
    | .error message => return .error message
  return .ok <| Loam.AccountingRolePublisher.eligibleInitialLoci
    world.locusAdmission world.events lifecycle.scheduled anchor roles

end Loam.AccountingRoleReview
