import Loam.Persistence.HouseholdImagePersistence
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.NormalizedCapacityPersistence
import Loam.Persistence.AttentionPersistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.Persistence.OpeningSupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.CurrentQuantityPresencePersistence
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.WriterOwnership

namespace Loam.HouseholdAuthority

open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Household generation authority

This boundary owns only the physical authority mechanics for a future
`household.loam` generation.

It does not yet select this file as production household truth. Existing
thirteen-file readers and publishers remain authoritative until a later cutover.

The boundary centralizes the mechanics qualified by the HouseholdImage research:

- one current path;
- one previous-generation path;
- one writer ownership scope;
- stale observed-generation refusal;
- staged readback before replacement;
- exact preservation of every unmarked section, including unknown sections;
- explicit recovery source.

Known section payloads are decoded with their existing production codecs when
present. Missing sections remain missing and are not normalized to empty.
-/

def fileName : String := "household.loam"

def path (root : System.FilePath) : System.FilePath :=
  root / fileName

def previousPath (root : System.FilePath) : System.FilePath :=
  root / (fileName ++ ".prev")

private def stagePath (target : System.FilePath) : System.FilePath :=
  System.FilePath.mk (target.toString ++ ".loam-stage")

private def previousStagePath (target : System.FilePath) : System.FilePath :=
  System.FilePath.mk (target.toString ++ ".prev.loam-stage")

def knownSectionNames : List String := [
  "Actual",
  "Scheduled",
  "Capacity",
  "Attention",
  "ActualRouting",
  "ScheduledRouting",
  "AccountingRole",
  "LocusAdmission",
  "ZeroOrigin",
  "OpeningSupport",
  "CurrentQuantityAnchor",
  "CurrentQuantityPresence",
  "BoundedHistorySupport"
]

private def qualifyIfPresent
    (image : Image)
    (name : String)
    (accepts : String → Bool) : Except String Unit := do
  match body? image name with
  | none => pure ()
  | some body =>
      if accepts body then
        pure ()
      else
        throw ("loam: HouseholdImage section is malformed or unsupported: " ++ name)

/--
Decode every present known section through its existing production codec.

Absence is intentionally accepted here. Individual consumers still own whether
absence means empty, unavailable, or error.
-/
def qualifyKnownSections (image : Image) : Except String Unit := do
  qualifyIfPresent image "Actual"
    (fun body => (Loam.Persistence.decodeNormalizedActual? body).isSome)
  qualifyIfPresent image "Scheduled"
    (fun body => (Loam.Persistence.decodeScheduledLifecycleImage? body).isSome)
  qualifyIfPresent image "Capacity"
    (fun body => (Loam.Persistence.decodeNormalizedCapacity? body).isSome)
  qualifyIfPresent image "Attention"
    (fun body => (Loam.Persistence.decodeAttentionMemory? body).isSome)
  qualifyIfPresent image "ActualRouting"
    (fun body => (Loam.Persistence.decodeActualRoutingHistory? body).isSome)
  qualifyIfPresent image "ScheduledRouting"
    (fun body => (Loam.Persistence.decodeScheduledRoutingHistory? body).isSome)
  qualifyIfPresent image "AccountingRole"
    (fun body => (Loam.Persistence.decodeAccountingRoleMap? body).isSome)
  qualifyIfPresent image "LocusAdmission"
    (fun body => (Loam.Persistence.decodeLocusAdmissionVocabulary? body).isSome)
  qualifyIfPresent image "ZeroOrigin"
    (fun body => (Loam.Persistence.decodeZeroOriginCoverage? body).isSome)
  qualifyIfPresent image "OpeningSupport"
    (fun body => (Loam.Persistence.decodeOpeningSupportMap? body).isSome)
  qualifyIfPresent image "CurrentQuantityAnchor"
    (fun body => (Loam.Persistence.decodeCurrentQuantityAnchor? body).isSome)
  qualifyIfPresent image "CurrentQuantityPresence"
    (fun body => (Loam.Persistence.decodeCurrentQuantityPresence? body).isSome)
  qualifyIfPresent image "BoundedHistorySupport"
    (fun body => (Loam.Persistence.decodeBoundedHistorySupport? body).isSome)

structure Generation where
  wire : String
  image : Image
deriving Repr, BEq

private def decodeGeneration (wire : String) : Except String Generation := do
  let image ←
    match Loam.Persistence.HouseholdImage.decode? wire with
    | some image => pure image
    | none => throw "loam: malformed or unsupported HouseholdImage"
  qualifyKnownSections image
  pure { wire := wire, image := image }

def loadCurrent? (root : System.FilePath) : IO (Except String Generation) := do
  let current := path root
  if !(← current.pathExists) then
    return .error s!"loam: HouseholdImage authority is missing: {current}"
  let wire ← IO.FS.readFile current
  return decodeGeneration wire

inductive RecoverySource where
  | current
  | previous
deriving Repr, DecidableEq

structure RecoveredGeneration where
  source : RecoverySource
  generation : Generation
deriving Repr, BEq

/--
Load current when valid. If current is missing or malformed, expose a qualified
previous generation explicitly.

Previous evidence is never silently relabeled as current.
-/
def loadRecoverable? (root : System.FilePath) : IO (Except String RecoveredGeneration) := do
  let current := path root
  if ← current.pathExists then
    let wire ← IO.FS.readFile current
    match decodeGeneration wire with
    | .ok generation =>
        return .ok { source := .current, generation := generation }
    | .error _ => pure ()

  let previous := previousPath root
  if ← previous.pathExists then
    let wire ← IO.FS.readFile previous
    match decodeGeneration wire with
    | .ok generation =>
        return .ok { source := .previous, generation := generation }
    | .error _ => pure ()

  return .error
    "loam: neither current nor previous HouseholdImage generation is usable"

private def changedNamesAdmissible (changedNames : List String) : Bool :=
  !changedNames.isEmpty &&
    changedNames.all fun name => knownSectionNames.contains name

private def untouchedSections
    (image : Image)
    (changedNames : List String) : List Section :=
  image.sections.filter fun part => !(changedNames.contains part.name)

/--
All sections not explicitly named by the semantic writer must remain exactly
identical and in the same relative order.

Because changed names must be known section identities, unknown future evidence
can never be modified through this publication boundary.
-/
def preservesUntouched
    (base candidate : Image)
    (changedNames : List String) : Bool :=
  untouchedSections base changedNames == untouchedSections candidate changedNames

private def qualifyTransition
    (base candidate : Image)
    (changedNames : List String) : Except String Unit := do
  if !changedNamesAdmissible changedNames then
    throw "loam: HouseholdImage changed-section set is empty or contains an unknown identity"
  if base == candidate then
    throw "loam: HouseholdImage publication has no change"
  if !preservesUntouched base candidate changedNames then
    throw "loam: HouseholdImage publication changed an unmarked section"
  qualifyKnownSections candidate

private def stageQualified
    (target : System.FilePath)
    (wire : String) : IO (Except String Generation) := do
  let stage := stagePath target
  IO.FS.writeFile stage wire
  let staged ← IO.FS.readFile stage
  if staged != wire then
    return .error s!"loam: staged HouseholdImage mismatch: {stage}"
  match decodeGeneration staged with
  | .ok generation => return .ok generation
  | .error message => return .error message

/--
Install the first complete HouseholdImage authority.

This does not inspect, delete, or modify the legacy thirteen-file layout.
A later migration command can use this only after separately proving legacy
answer equivalence.
-/
def installInitial?
    (root : System.FilePath)
    (candidate : Image) : IO (Except String Generation) := do
  let current := path root
  Loam.WriterOwnership.withOwnership current do
    if ← current.pathExists then
      return .error "loam: HouseholdImage authority already exists"
    match qualifyKnownSections candidate with
    | .error message => return .error message
    | .ok () => pure ()
    let some wire := Loam.Persistence.HouseholdImage.encode? candidate
      | return .error "loam: HouseholdImage candidate could not be encoded"
    if let some parent := current.parent then
      IO.FS.createDirAll parent
    let staged ← stageQualified current wire
    match staged with
    | .error message => return .error message
    | .ok generation =>
        IO.FS.rename (stagePath current) current
        return .ok generation

/--
Publish one candidate derived from an exact observed generation.

The current bytes are re-read under one writer lock. A stale writer is refused.
Every unmarked section must remain exactly preserved. The old current generation
is staged and qualified as `household.loam.prev` before the final current
rename.
-/
def publishObserved?
    (root : System.FilePath)
    (observedWire : String)
    (changedNames : List String)
    (candidate : Image) : IO (Except String Generation) := do
  let current := path root
  Loam.WriterOwnership.withOwnership current do
    if !(← current.pathExists) then
      return .error "loam: HouseholdImage authority is missing"
    let currentWire ← IO.FS.readFile current
    if currentWire != observedWire then
      return .error "loam: stale HouseholdImage generation"

    let base ←
      match decodeGeneration currentWire with
      | .ok generation => pure generation
      | .error message => return .error message

    match qualifyTransition base.image candidate changedNames with
    | .error message => return .error message
    | .ok () => pure ()

    let some candidateWire := Loam.Persistence.HouseholdImage.encode? candidate
      | return .error "loam: HouseholdImage candidate could not be encoded"

    let staged ← stageQualified current candidateWire
    let stagedGeneration ←
      match staged with
      | .ok generation => pure generation
      | .error message => return .error message

    match qualifyTransition base.image stagedGeneration.image changedNames with
    | .error message => return .error message
    | .ok () => pure ()

    let previousStage := previousStagePath current
    IO.FS.writeFile previousStage currentWire
    let previousWire ← IO.FS.readFile previousStage
    if previousWire != currentWire then
      return .error "loam: staged previous HouseholdImage mismatch"
    match decodeGeneration previousWire with
    | .error message => return .error message
    | .ok _ => pure ()

    IO.FS.rename previousStage (previousPath root)
    IO.FS.rename (stagePath current) current
    return .ok stagedGeneration

/--
Restore a qualified previous generation explicitly under the same writer lock.

The previous file remains available after restoration; Git remains the intended
long-term history mechanism.
-/
def restorePrevious?
    (root : System.FilePath) : IO (Except String Generation) := do
  let current := path root
  Loam.WriterOwnership.withOwnership current do
    let previous := previousPath root
    if !(← previous.pathExists) then
      return .error "loam: previous HouseholdImage generation is missing"
    let wire ← IO.FS.readFile previous
    let generation ←
      match decodeGeneration wire with
      | .ok generation => pure generation
      | .error message => return .error message

    if let some parent := current.parent then
      IO.FS.createDirAll parent
    let staged ← stageQualified current wire
    match staged with
    | .error message => return .error message
    | .ok stagedGeneration =>
        IO.FS.rename (stagePath current) current
        return .ok stagedGeneration

end Loam.HouseholdAuthority
