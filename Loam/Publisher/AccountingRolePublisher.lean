import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.CurrentQuantityAnchorPublisher
import Loam.LocusAdmissionAuthority
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.ScheduledActualOwnership
import Loam.WriterOwnership

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

private def loadCurrentAnchor
    (anchorFile : System.FilePath) : IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if ← anchorFile.pathExists then
    match ← Loam.Persistence.loadCurrentQuantityAnchor? anchorFile with
    | some anchor => return .ok anchor
    | none => return .error "loam: current quantity anchor authority is malformed or unsupported"
  else
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty

private def publishUnderOwnership
    (scheduledFile root anchorFile roleFile : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
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
  let anchor ←
    match ← loadCurrentAnchor anchorFile with
    | .ok value => pure value
    | .error message => return .error message
  if !(← roleFile.pathExists) then
    return .error "loam: AccountingRole authority file is missing"
  let some roles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | return .error "loam: AccountingRole authority is malformed or unsupported"
  let updated ←
    match propose? locusAdmission evidence.events lifecycle.scheduled anchor roles draft with
    | .ok value => pure value
    | .error message => return .error message
  if !(← Loam.Persistence.saveAccountingRoleMap? roleFile updated) then
    return .error "loam: AccountingRole authority could not be published"
  return .ok ()

/--
Publish one first role assertion while excluding concurrent Scheduled creation,
Actual publication, current quantity reconciliation, and AccountingRole
publication from the admission check/write interval.

The lock order extends the existing shared orders without reversing either one:
`scheduled -> actual.loam -> current-quantity-anchor.loam -> roleFile`.
-/
def publishInitialRole
    (scheduledPath rootPath rolePath : String)
    (draft : Draft) : IO (Except String Unit) := do
  if scheduledPath.isEmpty then
    return .error "loam: scheduled path must not be empty"
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  if rolePath.isEmpty then
    return .error "loam: AccountingRole path must not be empty"
  let scheduledFile := System.FilePath.mk scheduledPath
  let root := System.FilePath.mk rootPath
  let anchorFile := Loam.CurrentQuantityAnchorPublisher.path root
  let roleFile := System.FilePath.mk rolePath
  Loam.ScheduledActualOwnership.withOwnership scheduledFile root <|
    Loam.WriterOwnership.withOwnership anchorFile <|
      Loam.WriterOwnership.withOwnership roleFile
        (publishUnderOwnership scheduledFile root anchorFile roleFile draft)

end Loam.AccountingRolePublisher
