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

This boundary owns the physical authority mechanics for the installed
`household.loam` generation.

Production semantic families move here incrementally. A family is authoritative
here only after its explicit read/write cutover; untouched families continue to
use their legacy authorities until their own qualified cutover.

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

/--
A year-named book under journal/YYYY is currently an immutable saved source,
never the active publication owner. All ordinary publishers still write the
installed root/household.loam. Future annual cutover must explicitly promote a
single writable year under the shared ownership protocol *before* changing this
guard. No caller may infer write permission merely because an archived file
can be opened successfully.
-/
def isSavedYearRoot (root : System.FilePath) : Bool :=
  match root.fileName, root.parent with
  | some year, some parent =>
      parent.fileName == some "journal" &&
        year.length == 4 && year.toNat?.isSome && year != "0000"
  | _, _ => false

private def requireCurrentWriter (root : System.FilePath) : Except String Unit :=
  if isSavedYearRoot root then
    .error "loam: saved journal/YYYY household is read-only; use the installed household root for recording"
  else
    .ok ()

/-- One pointer selects the only active annual HouseholdImage. The old installed
root remains a qualified, immutable predecessor after a cutover. -/
def activeYearPath (root : System.FilePath) : System.FilePath :=
  root / "journal" / "active-year"

private def validYear (year : String) : Bool :=
  year.length == 4 && year.toNat?.isSome && year != "0000"

/-- Inspect the installed active-year pointer without interpreting missing as
a year. A malformed present pointer fails closed; it never falls back. -/
def selectedYear? (root : System.FilePath) : IO (Except String (Option String)) := do
  if isSavedYearRoot root then return .ok none
  let pointer := activeYearPath root
  if !(← pointer.pathExists) then return .ok none
  let wire ← IO.FS.readFile pointer
  match wire.splitOn "\n" with
  | ["LOAM-ACTIVE-YEAR\t1", year, ""] =>
      if validYear year then return .ok (some year)
      return .error "loam: malformed active-year pointer: invalid year"
  | _ => return .error "loam: malformed or unsupported active-year pointer"

/-- Resolve one canonical current HouseholdImage; the marker's existence makes
a missing or corrupt selected year an error, never a legacy-root fallback. -/
def selectedPath? (root : System.FilePath) : IO (Except String System.FilePath) := do
  match ← selectedYear? root with
  | .error message => return .error message
  | .ok none => return .ok (path root)
  | .ok (some year) =>
      let target := root / "journal" / year / fileName
      if !(← target.pathExists) then
        return .error ("loam: active year " ++ year ++ " has no HouseholdImage")
      return .ok target


/--
Run one cross-family operation under the same writer ownership used by
HouseholdImage publication.

This is exposed only for operations that must serialize a read-only admission
check against HouseholdImage writers, such as Measure presentation scale
changes. Semantic publishers should continue to use `publishObserved?`.
-/
def withOwnership {α : Type}
    (root : System.FilePath)
    (action : IO α) : IO α :=
  Loam.WriterOwnership.withOwnership (path root) action

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

/-- Retain the admitted Actual produced by qualification; absence stays absence. -/
private def qualifyActual?
    (image : Image) : Except String (Option Loam.Persistence.AdmittedActualImage) := do
  match body? image "Actual" with
  | none => return none
  | some body =>
      let some actual := Loam.Persistence.decodeNormalizedActualImage? body
        | throw "loam: HouseholdImage section is malformed or unsupported: Actual"
      return some actual

private def qualifyOtherKnownSections (image : Image) : Except String Unit := do
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

/--
Decode every present known section through its existing production codec.
Absence remains for individual consumers to interpret; no family is skipped.
-/
def qualifyKnownSections (image : Image) : Except String Unit := do
  let _ ← qualifyActual? image
  qualifyOtherKnownSections image

structure Generation where
  wire : String
  image : Image
deriving Repr, BEq

private def decodeGenerationWithActual (wire : String) :
    Except String (Generation × Option Loam.Persistence.AdmittedActualImage) := do
  let image ←
    match Loam.Persistence.HouseholdImage.decode? wire with
    | some image => pure image
    | none => throw "loam: malformed or unsupported HouseholdImage"
  let actual ← qualifyActual? image
  qualifyOtherKnownSections image
  return ({ wire := wire, image := image }, actual)

private def decodeGeneration (wire : String) : Except String Generation :=
  (decodeGenerationWithActual wire).map Prod.fst

/--
Fully qualify the current generation once and return its already-admitted Actual.
The pair is a local read result, not a cache added to mutable Generation fields.
-/
def loadCurrentWithActual? (root : System.FilePath) :
    IO (Except String (Generation × Option Loam.Persistence.AdmittedActualImage)) := do
  let current ←
    match ← selectedPath? root with
    | .ok selected => pure selected
    | .error message => return .error message
  if !(← current.pathExists) then
    return .error s!"loam: HouseholdImage authority is missing: {current}"
  let wire ← IO.FS.readFile current
  return decodeGenerationWithActual wire

def loadCurrent? (root : System.FilePath) : IO (Except String Generation) := do
  return (← loadCurrentWithActual? root).map Prod.fst

inductive RecoverySource where
  | current
  | previous
deriving Repr, DecidableEq, BEq

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
  let current ←
    match ← selectedPath? root with
    | .ok selected => pure selected
    | .error message => return .error message
  if ← current.pathExists then
    let wire ← IO.FS.readFile current
    match decodeGeneration wire with
    | .ok generation =>
        return .ok { source := .current, generation := generation }
    | .error _ => pure ()

  let previous := System.FilePath.mk (current.toString ++ ".prev")
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
  match requireCurrentWriter root with
  | .ok () => pure ()
  | .error message => return .error message
  let ownershipAnchor := path root
  Loam.WriterOwnership.withOwnership ownershipAnchor do
    let current ←
      match ← selectedPath? root with
      | .ok selected => pure selected
      | .error message => return .error message
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

    IO.FS.rename previousStage (System.FilePath.mk (current.toString ++ ".prev"))
    IO.FS.rename (stagePath current) current
    return .ok stagedGeneration

/--
Restore a qualified previous generation explicitly under the same writer lock.

The previous file remains available after restoration; Git remains the intended
long-term history mechanism.
-/
def restorePrevious?
    (root : System.FilePath) : IO (Except String Generation) := do
  match requireCurrentWriter root with
  | .ok () => pure ()
  | .error message => return .error message
  Loam.WriterOwnership.withOwnership (path root) do
    let current ←
      match ← selectedPath? root with
      | .ok selected => pure selected
      | .error message => return .error message
    let previous := System.FilePath.mk (current.toString ++ ".prev")
    if !(← previous.pathExists) then
      return .error "loam: previous HouseholdImage generation is missing"
    let wire ← IO.FS.readFile previous
    match decodeGeneration wire with
    | .ok _ => pure ()
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
