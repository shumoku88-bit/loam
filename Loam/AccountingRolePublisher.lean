import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.LocusAdmissionAuthority
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.WriterOwnership

namespace Loam.AccountingRolePublisher

open Loam.Core

set_option autoImplicit false

/-!
# Initial AccountingRole publication

The current AccountingRole authority has no qualified role-change history.
This publisher therefore admits only the smallest safe mutation needed after a
new Locus is admitted: one first role assignment before that Locus has appeared
in any retained Actual Event or Scheduled occurrence.

It deliberately does not implement role replacement, deletion, effective dates,
retroactive reclassification, aliases, or inference from signs/names/Purpose.
-/

structure Draft where
  locus : LocusId
  role : AccountingRole
deriving Repr, DecidableEq

structure Receipt where
  locus : LocusId
  role : AccountingRole
  previousCount : Nat
  currentCount : Nat
deriving Repr, DecidableEq

private def actualUsesLocus
    (events : EventMemory) (locus : LocusId) : Bool :=
  events.events.any fun event =>
    event.effects.any fun effect => decide (effect.coordinate.locus = locus)

private def scheduledUsesLocus
    (scheduled : ScheduledMemory String) (locus : LocusId) : Bool :=
  scheduled.occurrences.any fun occurrence =>
    occurrence.movement.changes.any fun change => decide (change.coordinate = locus)

/--
Return only currently admitted, unresolved Loci whose retained Actual and
Scheduled evidence is still empty. Presentation surfaces may use this as a
candidate projection without reimplementing publisher admission semantics.
-/
def eligibleInitialLoci
    (locusAdmission : LocusAdmissionVocabulary)
    (events : EventMemory)
    (scheduled : ScheduledMemory String)
    (roles : AccountingRoleMap) : List LocusId :=
  locusAdmission.approved.filter fun locus =>
    (roles.roleOf? locus).isNone &&
      !actualUsesLocus events locus &&
      !scheduledUsesLocus scheduled locus

/--
Propose exactly one first AccountingRole assertion.

A Locus must already be admitted for new Movement publication, must be unresolved
in the current role map, and must be absent from all retained Actual and
Scheduled quantity evidence. This keeps the operation from silently changing the
classification of already-retained household facts while role history semantics
remain unqualified.
-/
def propose?
    (locusAdmission : LocusAdmissionVocabulary)
    (events : EventMemory)
    (scheduled : ScheduledMemory String)
    (roles : AccountingRoleMap)
    (draft : Draft) : Except String (AccountingRoleMap × Receipt) := do
  if !locusAdmission.allows draft.locus then
    throw "loam: AccountingRole assignment requires a currently admitted Locus"
  if (roles.roleOf? draft.locus).isSome then
    throw "loam: AccountingRole is already assigned; role replacement is not qualified"
  if actualUsesLocus events draft.locus then
    throw "loam: AccountingRole initial assignment refuses a Locus already used by Actual evidence"
  if scheduledUsesLocus scheduled draft.locus then
    throw "loam: AccountingRole initial assignment refuses a Locus already used by Scheduled evidence"
  let assignments := roles.assignments ++ [{ locus := draft.locus, role := draft.role }]
  let some updated := AccountingRoleMap.ofAssignments? assignments
    | throw "loam: AccountingRole proposal would violate unique Locus assignment"
  return (updated, {
    locus := draft.locus
    role := draft.role
    previousCount := roles.assignments.length
    currentCount := updated.assignments.length
  })

private def publishUnderOwnership
    (scheduledFile root roleFile : System.FilePath)
    (draft : Draft) : IO (Except String Receipt) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok ev => pure ev
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok la => pure la
    | .error message => return .error message
  let some lifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | return .error "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  if !(← roleFile.pathExists) then
    return .error "loam: AccountingRole authority file is missing"
  let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | return .error "loam: AccountingRole authority is malformed or unsupported"
  let (updated, receipt) ←
    match propose? locusAdmission evidence.events lifecycle.scheduled roles draft with
    | .ok value => pure value
    | .error message => return .error message
  if !(← Loam.Persistence.saveAccountingRoleMap? roleFile updated) then
    return .error "loam: AccountingRole authority could not be published"
  return .ok receipt

/--
Publish one first role assertion while excluding concurrent Scheduled creation,
Movement/Locus publication, and AccountingRole publication from the admission
check/write interval.

The lock order preserves the Scheduled writer order:
`scheduled -> actual.loam -> roleFile`.
-/
def publishInitialRole
    (scheduledPath rootPath rolePath : String)
    (draft : Draft) : IO (Except String Receipt) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  if rolePath.isEmpty then
    return .error "loam: AccountingRole path must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  let roleFile := System.FilePath.mk rolePath
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.ActualAuthority.withActualOwnership root <|
      Loam.WriterOwnership.withOwnership roleFile
        (publishUnderOwnership scheduledFile root roleFile draft)

end Loam.AccountingRolePublisher
