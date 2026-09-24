import Loam.ActualEvidence
import Loam.HouseholdPaths
import Loam.Persistence.NormalizedActualPersistence
import Loam.WriterOwnership

namespace Loam.ActualAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Single-File Normalized Actual Authority

This module provides the production publication and loading boundary for the
canonical single-generation normalized Actual fact families (`actual.loam`).

All historical Actual evidence (Events, Validity history, Descriptions, Merchant
dispositions, Corrections, Reversals, Relations, and Discharges) lives co-published
within one generation in `actual.loam`. Referential closure and validity are
enforced at decode/encode time by `NormalizedActualPersistence`.

Publication follows strict atomic crash-resilient semantics:
1. Writer acquires cross-process exclusive ownership on `actual.loam.loam-writer-lock`.
2. Current authoritative evidence is re-read from `actual.loam`.
3. Candidate transition is admitted by pure domain logic.
4. Proposed evidence is encoded and staged off-authority (`actual.loam.loam-stage`).
5. Staged file is re-read and validated via production typed decoding.
6. Authority switches via a single atomic filesystem rename:
   `actual.loam.loam-stage` -> `actual.loam`.
7. Interruption at any step before rename leaves existing authority completely untouched.
-/

/-- The admitted normalized Actual image exposed to read-side callers. -/
abbrev Image := Loam.Persistence.AdmittedActualImage

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
  if rootOrFile.fileName == some actualFileName then rootOrFile
  else actualPath rootOrFile

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

/--
Compatibility loader returning legacy formatted String error.
Preserves existing error message prefixes for downstream callers.
-/
def loadImageFile? (path : System.FilePath) : IO (Except String Image) := do
  match ← loadImageFileDetailed path with
  | .ok image => return .ok image
  | .error (.fileNotFound path) =>
      return .error s!"loam: actual authority not found: {path}"
  | .error (.decode path _) =>
      return .error s!"loam: actual authority is malformed or unsupported: {path}"

/-- Load one fully admitted Actual image from the repository root (compatibility wrapper). -/
def loadImage? (root : System.FilePath) : IO (Except String Image) :=
  loadImageFile? (actualPath root)

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

/-- Publish one complete generation of Actual evidence to repository root. -/
def publishActual? (root : System.FilePath) (evidence : ActualEvidence) : IO (Except String Unit) :=
  publishActualFile? (actualPath root) evidence

/-- Initialize an empty Actual authority at an explicit file path. -/
def initActualFile? (path : System.FilePath) : IO (Except String Unit) :=
  publishActualFile? path ActualEvidence.empty

/-- Run an IO action under exclusive writer ownership for an explicit actual file path. -/
def withActualFileOwnership {α : Type} (path : System.FilePath) (action : IO α) : IO α :=
  Loam.WriterOwnership.withOwnership path action

/-- Run an IO action under exclusive writer ownership for the repository root's actual authority. -/
def withActualOwnership {α : Type} (root : System.FilePath) (action : IO α) : IO α :=
  withActualFileOwnership (actualPath root) action

end Loam.ActualAuthority