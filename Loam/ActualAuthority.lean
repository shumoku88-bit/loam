import Loam.ActualEvidence
import Loam.LocusAdmissionAuthority
import Loam.MovementAdmission
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
def actualFileName : String := "actual.loam"

/-- The authoritative filepath for actual evidence under a given repository root. -/
def actualPath (root : System.FilePath) : System.FilePath :=
  root / actualFileName

/-- Load one fully admitted Actual image from an explicit file path. -/
def loadImageFile? (path : System.FilePath) : IO (Except String Image) := do
  if !(← path.pathExists) then
    return .error s!"loam: actual authority not found: {path}"
  let text ← IO.FS.readFile path
  match Loam.Persistence.decodeNormalizedActualImage? text with
  | some image => return .ok image
  | none => return .error s!"loam: actual authority is malformed or unsupported: {path}"

/-- Load one fully admitted Actual image from the repository root. -/
def loadImage? (root : System.FilePath) : IO (Except String Image) :=
  loadImageFile? (actualPath root)

/--
Compatibility loader exposing only retained ActualEvidence.
Read-side callers that need current Event or validity views should prefer
`loadImageFile?` so normalized admission is not recomputed downstream.
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
Construct the Movement admission view from retained Actual evidence and the
independent current new-write Locus policy.

This is a pure representation boundary. It does not merge the two authorities
or grant persistence ownership to the semantic `World` type.
-/
def movementWorld
    (evidence : ActualEvidence)
    (locusAdmission : LocusAdmissionVocabulary) : Loam.MovementAdmission.World := {
  events := evidence.events
  validity := evidence.validity
  descriptions := evidence.descriptions
  relations := evidence.relations
  discharges := evidence.discharges
  locusAdmission := locusAdmission
}

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

/--
Load the full typed MovementAdmission.World by combining authoritative ActualEvidence
from `actual.loam` and current new-write policy from `locus-admission.loam`.
The caller-selected root is exact: missing or malformed authority fails closed
instead of searching parent directories for a different household authority.
-/
def loadSelectedWorld? (root : System.FilePath) : IO (Except String Loam.MovementAdmission.World) := do
  let path :=
    if root.fileName == some actualFileName then root
    else actualPath root
  let dataDir := if root.fileName == some actualFileName then root.parent.getD root else root
  let evidence ←
    match ← loadActualFile? path with
    | .ok ev => pure ev
    | .error msg => return .error msg
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? dataDir with
    | .ok la => pure la
    | .error msg => return .error msg
  return .ok (movementWorld evidence locusAdmission)

end Loam.ActualAuthority