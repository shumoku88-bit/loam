import Loam.HouseholdPaths
import Loam.LocusCatalog
import Loam.Authority.ActualAuthority
import Loam.Authority.LocusAdmissionAuthority
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence

namespace Loam.LocusCoherenceReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Read-only Locus coherence review

This boundary compares already-retained Locus evidence without creating another
semantic authority.

The compared meanings remain independent:

- `LocusAdmission`: current permission for new quantity-bearing writes;
- `AccountingRole`: partial accounting classification;
- `ActualRouting`: retained Purpose-routing evidence;
- Actual Event history: retained occurrence evidence;
- `LocusCatalog`: presentation-only metadata.

A difference between these sets is not automatically an error. In particular,
historical/read-only identities are allowed to remain in Actual, Role, Routing,
or presentation metadata after current new-write admission has been withdrawn.
This review therefore reports exact differences for human inspection and never
infers admission, retirement, aliases, role changes, or historical rewrites.
-/

structure NonAdmittedRow where
  locus : LocusId
  retainedOccurrences : Nat
  currentOccurrences : Nat
  role : Option AccountingRole
  hasRoutingEvidence : Bool
  label : String
  help : String
  deriving Repr, DecidableEq

structure Snapshot where
  admittedLoci : List LocusId
  retainedActualLoci : List LocusId
  currentActualLoci : List LocusId
  admittedMissingRole : List LocusId
  admittedMissingMetadata : List LocusId
  nonAdmitted : List NonAdmittedRow
  deriving Repr, DecidableEq

private def containsLocus (loci : List LocusId) (locus : LocusId) : Bool :=
  loci.any fun candidate => decide (candidate = locus)

private def actualLoci (events : EventMemory) : List LocusId :=
  (events.events.flatMap fun event =>
    event.effects.map fun effect => effect.coordinate.locus).eraseDups

private def actualOccurrences (events : EventMemory) (locus : LocusId) : Nat :=
  (events.events.filter fun event =>
    event.effects.any fun effect => decide (effect.coordinate.locus = locus)).length

private def roleLoci (roles : AccountingRoleMap) : List LocusId :=
  roles.assignments.map fun assignment => assignment.locus

private def routingLoci (routing : ActualRoutingHistory) : List LocusId :=
  routing.entries.map (fun entry => entry.subject) |>.eraseDups

/--
Build one read-only cross-authority snapshot from already-loaded evidence.
Retained Actual and correction-frontier current Actual stay visible separately.

List order is presentation convenience only: admitted rows preserve admission
order, while non-admitted rows preserve first occurrence across retained Actual,
AccountingRole, and ActualRouting evidence.
-/
def review
    (admission : LocusAdmissionVocabulary)
    (retainedEvents currentEvents : EventMemory)
    (roles : AccountingRoleMap)
    (routing : ActualRoutingHistory)
    (metadata : List Loam.LocusCatalog.Metadata) : Snapshot :=
  let admitted := admission.approved
  let retainedActual := actualLoci retainedEvents
  let currentActual := actualLoci currentEvents
  let routed := routingLoci routing
  let known := (retainedActual ++ roleLoci roles ++ routed).eraseDups
  let admittedMissingRole :=
    admitted.filter fun locus => (roles.roleOf? locus).isNone
  let admittedMissingMetadata :=
    admitted.filter fun locus =>
      (Loam.LocusCatalog.metadataForToken? metadata locus.token).isNone
  let nonAdmittedLoci :=
    known.filter fun locus => !containsLocus admitted locus
  let nonAdmitted :=
    nonAdmittedLoci.map fun locus =>
      { locus := locus
        retainedOccurrences := actualOccurrences retainedEvents locus
        currentOccurrences := actualOccurrences currentEvents locus
        role := roles.roleOf? locus
        hasRoutingEvidence := containsLocus routed locus
        label := Loam.LocusCatalog.labelForToken metadata locus.token
        help := Loam.LocusCatalog.helpForToken metadata locus.token }
  { admittedLoci := admitted
    retainedActualLoci := retainedActual
    currentActualLoci := currentActual
    admittedMissingRole := admittedMissingRole
    admittedMissingMetadata := admittedMissingMetadata
    nonAdmitted := nonAdmitted }

/--
Load the current household authorities needed for the read-only coherence view.
No writer, repair path, or inferred policy is invoked.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath) : IO (Except String Snapshot) := do
  let image ←
    match ← Loam.ActualAuthority.loadImage? actualRoot with
    | .ok image => pure image
    | .error message => return .error message
  let admission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? dataDir with
    | .ok admission => pure admission
    | .error message => return .error message

  let rolePath := Loam.HouseholdPaths.accountingRole dataDir
  if !(← rolePath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"
  let roles ←
    match ← loadAccountingRoleMap? rolePath with
    | some roles => pure roles
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  let routingPath := Loam.HouseholdPaths.actualRouting dataDir
  if !(← routingPath.pathExists) then
    return .error "loam: required Actual routing evidence is missing"
  let routing ←
    match ← loadActualRoutingHistory? routingPath with
    | some routing => pure routing
    | none => return .error "loam: malformed or unsupported Actual routing evidence"

  let metadata ←
    match ← Loam.LocusCatalog.loadMetadata dataDir with
    | .ok metadata => pure metadata
    | .error message => return .error message

  return .ok (review admission image.evidence.events image.currentEvents roles routing metadata)

end Loam.LocusCoherenceReview
