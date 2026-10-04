import Loam.Core.ActualEvidence
import Loam.Authority.HouseholdAuthority
import Loam.HouseholdPaths
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.WriterOwnership

namespace Loam.ActualAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Normalized Actual authority

Production household Actual evidence is the required `Actual` section of
`household.loam`. Explicit `actual.loam` file loaders and publishers remain as
legacy diagnostic/migration entrances, but production root selection does not
fall back to them.

The production section still uses the existing normalized Actual codec, so
referential closure and validity remain enforced by `NormalizedActualPersistence`.
Household publication inherits generation-stale refusal, staged qualification,
unknown-section preservation, and `.prev` retention from `HouseholdAuthority`.
-/

/-- The admitted normalized Actual image exposed to read-side callers. -/
abbrev Image := Loam.Persistence.AdmittedActualImage

/--
One exact Household generation paired with its required admitted Actual section.

This adapter is qualified ahead of the P11 production cutover. Existing
standalone Actual entrypoints below remain unchanged until production callers are
migrated deliberately.
-/
structure HouseholdObserved where
  generation : Loam.HouseholdAuthority.Generation
  image : Image

/-- The standard canonical filename for normalized Actual authority. -/
def actualFileName : String := Loam.HouseholdPaths.actualFileName

/-- The authoritative filepath for actual evidence under a given repository root. -/
def actualPath (root : System.FilePath) : System.FilePath :=
  Loam.HouseholdPaths.actual root

/--
Resolve a caller-supplied household Actual location to the canonical authority
file path.

Shared reviews historically accept either the household root or the canonical
`actual.loam` file itself. Keep that lexical compatibility decision here so
readers, observation locks, and diagnostics select the same authority identity.
-/
def actualPathFromRootOrFile (rootOrFile : System.FilePath) : System.FilePath :=
  if rootOrFile.fileName == some actualFileName ||
      rootOrFile.fileName == some Loam.HouseholdAuthority.fileName then
    rootOrFile
  else
    Loam.HouseholdAuthority.path rootOrFile

/--
Detailed load error preserving structured persistence diagnostics and file context.
-/
inductive LoadError where
  | fileNotFound (path : System.FilePath)
  | decode (path : System.FilePath) (err : Loam.Persistence.NormalizedActualDecodeError)
deriving Repr, DecidableEq

/-- Human-readable formatting for authority load errors. -/
def LoadError.message : LoadError → String
  | .fileNotFound path =>
      s!"loam: actual authority not found: {path}"
  | .decode path err =>
      s!"failed to load Actual: {path}\n{err}"

instance : ToString LoadError where
  toString := LoadError.message

/-- Load one fully admitted Actual image from an explicit file path with structured diagnostics. -/
def loadImageFileDetailed (path : System.FilePath) : IO (Except LoadError Image) := do
  if !(← path.pathExists) then
    return .error (.fileNotFound path)
  let text ← IO.FS.readFile path
  match Loam.Persistence.decodeNormalizedActualImageDetailed text with
  | .ok image => return .ok image
  | .error err => return .error (.decode path err)

/-- Load one fully admitted Actual image from the repository root with structured diagnostics. -/
def loadImageDetailed (root : System.FilePath) : IO (Except LoadError Image) :=
  loadImageFileDetailed (actualPath root)

/-- Detailed loader exposing retained ActualEvidence with structured diagnostics. -/
def loadActualFileDetailed (path : System.FilePath) : IO (Except LoadError ActualEvidence) := do
  match ← loadImageFileDetailed path with
  | .ok image => return .ok image.evidence
  | .error err => return .error err

/-- Detailed root loader exposing retained ActualEvidence with structured diagnostics. -/
def loadActualDetailed (root : System.FilePath) : IO (Except LoadError ActualEvidence) := do
  match ← loadImageDetailed root with
  | .ok image => return .ok image.evidence
  | .error err => return .error err

private def decodeHouseholdActualGeneration?
    (generation : Loam.HouseholdAuthority.Generation) :
    Except String Image := do
  let some body :=
      Loam.Persistence.HouseholdImage.body? generation.image "Actual"
    | throw "loam: required HouseholdImage Actual section is missing"
  match Loam.Persistence.decodeNormalizedActualImageDetailed body with
  | .ok image => return image
  | .error _ =>
      throw "loam: malformed or unsupported HouseholdImage Actual authority"

/--
Compatibility loader for one selected Actual authority file.

An explicit `actual.loam` remains a legacy diagnostic/migration entrance.
A selected `household.loam` loads its required normalized `Actual` section.
-/
def loadImageFile? (path : System.FilePath) : IO (Except String Image) := do
  if path.fileName == some Loam.HouseholdAuthority.fileName then
    let root := path.parent.getD path
    let generation ←
      match ← Loam.HouseholdAuthority.loadCurrent? root with
      | .ok generation => pure generation
      | .error message => return .error message
    return decodeHouseholdActualGeneration? generation
  match ← loadImageFileDetailed path with
  | .ok image => return .ok image
  | .error (.fileNotFound path) =>
      return .error s!"loam: actual authority not found: {path}"
  | .error (.decode path _) =>
      return .error s!"loam: actual authority is malformed or unsupported: {path}"

/-- Load production Actual from the selected household root. -/
def loadImage? (root : System.FilePath) : IO (Except String Image) :=
  loadImageFile? (actualPathFromRootOrFile root)

/--
Compatibility loader exposing only retained ActualEvidence.
Read-side callers that need current Event or validity views should prefer
`loadImageFileDetailed` so normalized admission is not recomputed downstream.
-/
def loadActualFile? (path : System.FilePath) : IO (Except String ActualEvidence) := do
  match ← loadImageFile? path with
  | .ok image => return .ok image.evidence
  | .error message => return .error message

/-- Compatibility root loader exposing only retained ActualEvidence. -/
def loadActual? (root : System.FilePath) : IO (Except String ActualEvidence) := do
  match ← loadImage? root with
  | .ok image => return .ok image.evidence
  | .error message => return .error message

/--
Decode the required Actual section from one already-qualified Household
generation.

Absence is an error. A malformed present section fails closed through the
existing normalized Actual decoder.
-/
def decodeHouseholdGeneration?
    (generation : Loam.HouseholdAuthority.Generation) :
    Except String Image :=
  decodeHouseholdActualGeneration? generation

/-- Load required Household Actual together with the exact generation observed. -/
def loadHouseholdObserved?
    (root : System.FilePath) : IO (Except String HouseholdObserved) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let image ←
    match decodeHouseholdGeneration? generation with
    | .ok image => pure image
    | .error message => return .error message
  return .ok { generation, image }

/-- Load only the admitted Actual image from current Household authority. -/
def loadHouseholdImage?
    (root : System.FilePath) : IO (Except String Image) := do
  match ← loadHouseholdObserved? root with
  | .ok observed => return .ok observed.image
  | .error message => return .error message

/-- Load only retained Actual evidence from current Household authority. -/
def loadHouseholdActual?
    (root : System.FilePath) : IO (Except String ActualEvidence) := do
  match ← loadHouseholdImage? root with
  | .ok image => return .ok image.evidence
  | .error message => return .error message

/--
Publish proposed Actual evidence against the exact Household generation that was
observed.

Only the required Actual section is replaced. HouseholdAuthority preserves all
unmarked and unknown sections, rejects stale observed generations, and owns
current/previous atomic publication.
-/
def publishHouseholdObserved?
    (root : System.FilePath)
    (observed : HouseholdObserved)
    (proposed : ActualEvidence) :
    IO (Except String Loam.HouseholdAuthority.Generation) := do
  let some currentBody :=
      Loam.Persistence.HouseholdImage.body? observed.generation.image "Actual"
    | return .error "loam: required HouseholdImage Actual section is missing"
  let some proposedBody := Loam.Persistence.encodeNormalizedActual? proposed
    | return .error "loam: proposed HouseholdImage Actual authority did not encode"
  if currentBody == proposedBody then
    return .ok observed.generation
  let some candidate :=
      Loam.Persistence.HouseholdImage.replaceBody?
        observed.generation.image "Actual" proposedBody
    | return .error
        "loam: HouseholdImage Actual section disappeared before publication"
  Loam.HouseholdAuthority.publishObserved?
    root observed.generation.wire ["Actual"] candidate


/--
Publish one complete generation of Actual evidence to an explicit file path.
Fails closed without altering existing authority if encoding or staged re-decoding fails.
-/
def publishActualFile? (path : System.FilePath) (evidence : ActualEvidence) : IO (Except String Unit) := do
  let text ←
    match Loam.Persistence.encodeNormalizedActual? evidence with
    | some text => pure text
    | none => return .error "loam: production encoder rejected actual evidence"
  if let some parent := path.parent then
    IO.FS.createDirAll parent
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  if staged != text then
    return .error s!"loam: staged actual mismatch: {stage}"
  match Loam.Persistence.decodeNormalizedActual? staged with
  | some _ => pure ()
  | none => return .error "loam: staged actual failed typed decoding"
  IO.FS.rename stage path
  return .ok ()

/--
Publish production Actual evidence to the required HouseholdImage Actual section.

The standalone `actual.loam` is not read or written here.
-/
def publishActual? (root : System.FilePath) (evidence : ActualEvidence) : IO (Except String Unit) := do
  let observed ←
    match ← loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  match ← publishHouseholdObserved? root observed evidence with
  | .ok _ => return .ok ()
  | .error message => return .error message

/-- Initialize an empty Actual authority at an explicit file path. -/
def initActualFile? (path : System.FilePath) : IO (Except String Unit) :=
  publishActualFile? path ActualEvidence.empty

/-- Run an IO action under exclusive writer ownership for an explicit actual file path. -/
def withActualFileOwnership {α : Type} (path : System.FilePath) (action : IO α) : IO α :=
  Loam.WriterOwnership.withOwnership path action

/--
Run one production Actual mutation under the existing Actual serializer.

P11 keeps this lock identity temporarily so already-cut-over Household publishers
do not recursively acquire the Household lock. Actual data itself is no longer
selected from or published to `actual.loam`; a later cleanup may collapse this
serializer after the remaining cross-family writer topology is simplified.
-/
def withActualOwnership {α : Type} (root : System.FilePath) (action : IO α) : IO α :=
  withActualFileOwnership (actualPath root) action

end Loam.ActualAuthority