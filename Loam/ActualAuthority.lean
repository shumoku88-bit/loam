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

All historical Actual evidence (Events, Validity history, Descriptions,
Corrections, Reversals, Relations, and Discharges) lives co-published within
one generation in `actual.loam`. Referential closure and validity are enforced
at decode/encode time by `NormalizedActualPersistence`.

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

/-- The standard canonical filename for normalized Actual authority. -/
def actualFileName : String := "actual.loam"

/-- The authoritative filepath for actual evidence under a given repository root. -/
def actualPath (root : System.FilePath) : System.FilePath :=
  root / actualFileName

/-- Load authoritative Actual evidence from an explicit file path. -/
def loadActualFile? (path : System.FilePath) : IO (Except String ActualEvidence) := do
  if !(← path.pathExists) then
    return .error s!"loam: actual authority not found: {path}"
  let text ← IO.FS.readFile path
  match Loam.Persistence.decodeNormalizedActual? text with
  | some evidence => return .ok evidence
  | none => return .error s!"loam: actual authority is malformed or unsupported: {path}"

/-- Load authoritative Actual evidence from the repository root. -/
def loadActual? (root : System.FilePath) : IO (Except String ActualEvidence) :=
  loadActualFile? (actualPath root)

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
Execute a read-modify-write operation under cross-process writer ownership on an explicit file path.
-/
def updateActualFile? {α : Type}
    (path : System.FilePath)
    (propose : ActualEvidence → Except String (ActualEvidence × α)) : IO (Except String α) :=
  withActualFileOwnership path do
    let evidence ←
      match ← loadActualFile? path with
      | .ok ev => pure ev
      | .error msg => return .error msg
    let (updated, result) ←
      match propose evidence with
      | .ok val => pure val
      | .error msg => return .error msg
    match ← publishActualFile? path updated with
    | .ok () => return .ok result
    | .error msg => return .error msg

/--
Execute a read-modify-write operation under cross-process writer ownership on the repository root.
-/
def updateActual? {α : Type}
    (root : System.FilePath)
    (propose : ActualEvidence → Except String (ActualEvidence × α)) : IO (Except String α) :=
  updateActualFile? (actualPath root) propose

/--
Load the full typed MovementAdmission.World by combining authoritative ActualEvidence
from `actual.loam` and current new-write policy from `locus-admission.loam`.
-/
def loadSelectedWorld? (root : System.FilePath) : IO (Except String Loam.MovementAdmission.World) := do
  let path :=
    if root.fileName == some actualFileName then root
    else actualPath root
  let dataDir := if root.fileName == some actualFileName then root.parent.getD root else root
  let (evidence, finalDir) ←
    match ← loadActualFile? path with
    | .ok ev => pure (ev, dataDir)
    | .error msg =>
        if let some parent := root.parent then
          match ← loadActualFile? (actualPath parent) with
          | .ok ev => pure (ev, parent)
          | .error _ => return .error msg
        else return .error msg
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? finalDir with
    | .ok la => pure la
    | .error msg =>
        if let some parent := finalDir.parent then
          match ← Loam.LocusAdmissionAuthority.loadCurrent? parent with
          | .ok la => pure la
          | .error _ => return .error msg
        else return .error msg
  return .ok {
    events := evidence.events
    validity := evidence.validity
    descriptions := evidence.descriptions
    relations := evidence.relations
    discharges := evidence.discharges
    locusAdmission := locusAdmission
  }

/--
Publish one complete MovementAdmission.World by atomically writing `actual.loam` and `locus-admission.loam`.
-/
def publishWorld? (root : System.FilePath) (world : Loam.MovementAdmission.World) : IO (Except String Unit) := do
  let evidence : ActualEvidence := {
    events := world.events
    validity := world.validity
    descriptions := world.descriptions
    corrections := { corrections := [], idNodup := by simp }
    reversals := ActualReversalMemory.empty
    relations := world.relations
    discharges := world.discharges
  }
  let path :=
    if root.fileName == some actualFileName then root
    else actualPath root
  let dataDir := if root.fileName == some actualFileName then root.parent.getD root else root
  match ← publishActualFile? path evidence with
  | .error err => return .error err
  | .ok () =>
      Loam.LocusAdmissionAuthority.publishCurrent? dataDir world.locusAdmission

end Loam.ActualAuthority
