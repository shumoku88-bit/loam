import Loam.Authority.ActualAuthority
import Loam.Core.ActualEvidence
import Loam.Authority.LocusAdmissionAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Authority.AccountingRoleAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ScheduledLifecyclePersistence

namespace Loam.AccountingRolePublisher

open Loam.Core

set_option autoImplicit false

/-!
# Initial AccountingRole publication

The current AccountingRole authority has no qualified role-change history.
This publisher therefore admits only the smallest safe mutation needed after a
new Locus is admitted: one first role assignment before that Locus has appeared
in any retained Actual Event, Scheduled occurrence, or current quantity anchor.

It deliberately does not implement role replacement, deletion, effective dates,
retroactive reclassification, aliases, or inference from signs/names/Purpose.
-/

structure Draft where
  locus : LocusId
  role : AccountingRole
deriving Repr, DecidableEq

private def actualUsesLocus
    (events : EventMemory) (locus : LocusId) : Bool :=
  events.events.any fun event =>
    event.effects.any fun effect => decide (effect.coordinate.locus = locus)

private def scheduledUsesLocus
    (scheduled : ScheduledMemory String) (locus : LocusId) : Bool :=
  scheduled.occurrences.any fun occurrence =>
    occurrence.movement.changes.any fun change => decide (change.coordinate = locus)

private def currentAnchorUsesLocus
    (anchor : Loam.CurrentQuantityAnchor.Evidence) (locus : LocusId) : Bool :=
  anchor.assertions.any fun assertion =>
    decide (assertion.coordinate.locus = locus)

/--
Return only currently admitted, unresolved Loci whose retained Actual, Scheduled,
and current-anchor quantity evidence is still empty. Presentation surfaces may
use this as a candidate projection without reimplementing publisher admission
semantics.
-/
def eligibleInitialLoci
    (locusAdmission : LocusAdmissionVocabulary)
    (events : EventMemory)
    (scheduled : ScheduledMemory String)
    (anchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap) : List LocusId :=
  locusAdmission.approved.filter fun locus =>
    (roles.roleOf? locus).isNone &&
      !actualUsesLocus events locus &&
      !scheduledUsesLocus scheduled locus &&
      !currentAnchorUsesLocus anchor locus

/--
Propose exactly one first AccountingRole assertion.

A Locus must already be admitted for new Movement publication, must be unresolved
in the current role map, and must be absent from all retained Actual, Scheduled,
and current-anchor quantity evidence. This keeps the operation from silently
changing the classification of already-retained household facts while role
history semantics remain unqualified.
-/
def propose?
    (locusAdmission : LocusAdmissionVocabulary)
    (events : EventMemory)
    (scheduled : ScheduledMemory String)
    (anchor : Loam.CurrentQuantityAnchor.Evidence)
    (roles : AccountingRoleMap)
    (draft : Draft) : Except String AccountingRoleMap := do
  if !locusAdmission.allows draft.locus then
    throw "loam: AccountingRole assignment requires a currently admitted Locus"
  if actualUsesLocus events draft.locus then
    throw "loam: AccountingRole initial assignment refuses a Locus already used by Actual evidence"
  if scheduledUsesLocus scheduled draft.locus then
    throw "loam: AccountingRole initial assignment refuses a Locus already used by Scheduled evidence"
  if currentAnchorUsesLocus anchor draft.locus then
    throw "loam: AccountingRole initial assignment refuses a Locus already used by current quantity anchor evidence"
  let assignments := roles.assignments ++ [{ locus := draft.locus, role := draft.role }]
  let some updated := AccountingRoleMap.ofAssignments? assignments
    | throw "loam: AccountingRole is already assigned; role replacement is not qualified"
  return updated

private def publishHouseholdFromGeneration
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message

  let actual ←
    match Loam.ActualAuthority.decodeHouseholdGeneration? generation with
    | .ok image => pure image
    | .error message => return .error message
  let evidence := actual.evidence

  let lifecycle ←
    match Loam.Persistence.HouseholdImage.body? generation.image "Scheduled" with
    | none =>
        return .error "loam: required HouseholdImage Scheduled lifecycle section is missing"
    | some body =>
        match Loam.Persistence.decodeScheduledLifecycleImage? body with
        | some lifecycle => pure lifecycle
        | none =>
            return .error
              "loam: malformed or unsupported HouseholdImage Scheduled lifecycle authority"

  let locusAdmission ←
    match Loam.Persistence.HouseholdImage.body? generation.image "LocusAdmission" with
    | none =>
        return .error "loam: required HouseholdImage Locus admission section is missing"
    | some body =>
        match Loam.Persistence.decodeLocusAdmissionVocabulary? body with
        | some vocabulary => pure vocabulary
        | none =>
            return .error
              "loam: malformed or unsupported HouseholdImage Locus admission authority"

  let anchor ←
    match Loam.Persistence.HouseholdImage.body? generation.image "CurrentQuantityAnchor" with
    | none => pure Loam.CurrentQuantityAnchor.Evidence.empty
    | some body =>
        match Loam.Persistence.decodeCurrentQuantityAnchor? body with
        | some anchor => pure anchor
        | none =>
            return .error
              "loam: malformed or unsupported HouseholdImage current quantity anchor authority"

  let roles ←
    match Loam.AccountingRoleAuthority.decodeGeneration? generation with
    | .ok roles => pure roles
    | .error message => return .error message

  let updated ←
    match propose? locusAdmission evidence.events lifecycle.scheduled anchor roles draft with
    | .ok value => pure value
    | .error message => return .error message

  let observed : Loam.AccountingRoleAuthority.Observed := {
    generation := generation
    roles := roles
  }
  match ← Loam.AccountingRoleAuthority.publishObserved? root observed updated with
  | .ok _ => return .ok ()
  | .error message => return .error message

/--
Production initial-role publication after P10 AccountingRole cutover.

The publisher loads exactly one Household generation and decodes Actual,
Scheduled, LocusAdmission, CurrentQuantityAnchor, and AccountingRole from that
same generation. Only the AccountingRole section is replaced. A concurrent
Household writer is detected by the shared stale-generation check, so no
separate Actual serializer is needed for this publication path.
-/
def publishInitialRoleHousehold
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  if root.toString.isEmpty then
    return .error "loam: data directory must not be empty"
  publishHouseholdFromGeneration root draft


end Loam.AccountingRolePublisher
