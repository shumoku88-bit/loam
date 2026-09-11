import Loam.MovementAdmission
import Loam.Persistence.EventPersistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.Sha256
import Std

namespace Loam.MovementManifestAuthority

set_option autoImplicit false

/-!
# Movement generation-manifest authority

This is a Movement-specific physical authority boundary for the canonical fact
families needed by the practical Movement writer plus the independently meaningful
Locus new-write admission vocabulary earned by Observation 212. It deliberately
does not merge those meanings into one semantic family and does not perform
Movement admission.

A selected generation is named only by `CURRENT`. Family images are immutable,
content-addressed objects. Preparing objects does not make them authoritative;
`commitPrepared?` changes authority through one `CURRENT` replacement.

Validated pre-switch `CURRENT` manifests are retained as content-addressed recovery
candidates. Those copies are not authority and are never discovered as fallback
reads. `CURRENT` remains the only selected generation. Recovery selection is always
explicit and validates the candidate manifest, every referenced object digest, and
typed production decoding before replacing `CURRENT`.

Version 1 manifests contained only the five historical Movement evidence families.
They remain readable so existing household history and read-only projections do
not disappear during migration. They decode with an empty Locus admission
vocabulary, which means every new quantity-bearing Movement fails closed until a
version 2 generation explicitly publishes the sixth policy family.

## Design Rationale

- **Current semantics**: Physical publication and loading boundary for the six core Movement
  fact families (Event, ActualValidity, EventDescription, RelationUnit, RelationDischarge,
  and LocusAdmission). Authority is governed strictly by the single pointer `CURRENT`, referencing
  immutable, content-addressed family files under `objects/<Family>/<sha256>.loam`.

- **Why this design**: Provides multi-stream atomic publication across process crashes while
  avoiding a single monolithic storage format. Writing content-addressed objects is staged
  off-authority (`prepareWorld?`); authority switches via a single atomic file rename of `CURRENT`
  (`commitPrepared?`). Validated pre-switch manifests are archived under `recovery/manifests/`.

- **Prohibited simplifications**:
  1. *Why not mutable sidecar files (e.g. in-place appended .loam files)?*: Multi-stream
     persistence across physically separate files cannot be mutated in place atomically across
     crashes. A crash during a write leaves torn states where relations refer to missing events
     or validity records refer to non-existent events, violating referential closure.
  2. *Why not automatic fallback or recovery discovery?*: If `CURRENT` is missing, unreadable,
     or digest-corrupted, falling back to legacy sidecars or scanning for "latest recovery"
     masks real data loss or corruption (as observed during early menu cutover where missing
     authority silently rendered a populated household as empty). Missing authority must fail
     closed; recovery requires explicit digest specification.
  3. *Why not a monolithic single-file snapshot?*: Merging all six families into one unified file
     would conflate distinct semantic authorities, destroy content-addressed deduplication
     across generations (`reusedObjects`), and force rewriting entire datasets on every transaction.
  4. *Why not a generic / universal manifest framework?*: Movement fact families require strict
     mutual referential closure. Scheduled lifecycle and routing have different atomicity and
     mutation boundaries (e.g. ScheduledRouting is independent of Scheduled lifecycle). A generic
     framework prematurely couples disparate lifecycle requirements.

- **Permanent evidence references**:
  - Observation 055: Modeled multi-stream publication boundaries in Alloy, proving uncoordinated
    streams expose torn relational state (`correctionPublicationCanTear: SAT`) and establishing
    fail-closed referential closure requirements.
  - Observation 129: Lean proofs on crash recovery and atomic candidate commit across streams.
  - Observation 212: Qualification of LocusAdmissionVocabulary as an independent policy family
    incorporated into Manifest V2.
  - `docs/movement_manifest_menu_cutover.md`: Operational record of failure modes when manifest
    authority was bypassed with fallback heuristics.
-/

private structure FamilyRef where
  path : String
  sha256 : String
  deriving Repr, BEq

private structure EvidenceManifest where
  events : FamilyRef
  validity : FamilyRef
  descriptions : FamilyRef
  relations : FamilyRef
  discharges : FamilyRef
  deriving Repr, BEq

private structure Manifest where
  events : FamilyRef
  validity : FamilyRef
  descriptions : FamilyRef
  relations : FamilyRef
  discharges : FamilyRef
  locusAdmission : Option FamilyRef
  deriving Repr, BEq

private structure WorldBytes where
  events : String
  validity : String
  descriptions : String
  relations : String
  discharges : String
  locusAdmission : String
  deriving Repr, BEq

/--
The five selected household Movement evidence families, without current new-write
policy. This is a decoded physical authority view, not a new retained semantic
family or a second Movement engine.
-/
structure EvidenceWorld where
  events : Loam.Core.EventMemory
  validity : Loam.Core.ActualValidityHistory String
  descriptions : Loam.Core.EventDescriptionMemory
  relations : List Loam.Core.RelationUnit
  discharges : List Loam.Core.RelationDischarge

/--
An off-authority Movement generation whose referenced objects have already been
prepared and verified. `reusedObjects` is observational only and has no semantic
or authority meaning.
-/
structure Prepared where
  manifestText : String
  reusedObjects : Nat
  deriving Repr, BEq

private def manifestHeaderV1 : String := "LOAM-MOVEMENT-MANIFEST\t1"
private def manifestHeaderV2 : String := "LOAM-MOVEMENT-MANIFEST\t2"

private def objectRelativePath (family digest : String) : String :=
  "objects/" ++ family ++ "/" ++ digest ++ ".loam"

private def manifestRow (family : String) (ref : FamilyRef) : String :=
  family ++ "\t" ++ ref.path ++ "\t" ++ ref.sha256

private def encodeManifest (manifest : Manifest) : String :=
  match manifest.locusAdmission with
  | none =>
      String.intercalate "\n" [
        manifestHeaderV1,
        manifestRow "Event" manifest.events,
        manifestRow "ActualValidity" manifest.validity,
        manifestRow "EventDescription" manifest.descriptions,
        manifestRow "RelationUnit" manifest.relations,
        manifestRow "RelationDischarge" manifest.discharges
      ] ++ "\n"
  | some locusAdmission =>
      String.intercalate "\n" [
        manifestHeaderV2,
        manifestRow "Event" manifest.events,
        manifestRow "ActualValidity" manifest.validity,
        manifestRow "EventDescription" manifest.descriptions,
        manifestRow "RelationUnit" manifest.relations,
        manifestRow "RelationDischarge" manifest.discharges,
        manifestRow "LocusAdmission" locusAdmission
      ] ++ "\n"

private def decodeManifestRow? (expected : String) (row : String) : Option FamilyRef :=
  match row.splitOn "\t" with
  | [family, path, digest] =>
      if family == expected && digest.length == 64 &&
          path == objectRelativePath expected digest then
        some { path := path, sha256 := digest }
      else
        none
  | _ => none

private def decodeEvidenceRows?
    (eventRow validityRow descriptionRow relationRow dischargeRow : String) :
    Option EvidenceManifest := do
  let events ← decodeManifestRow? "Event" eventRow
  let validity ← decodeManifestRow? "ActualValidity" validityRow
  let descriptions ← decodeManifestRow? "EventDescription" descriptionRow
  let relations ← decodeManifestRow? "RelationUnit" relationRow
  let discharges ← decodeManifestRow? "RelationDischarge" dischargeRow
  some { events, validity, descriptions, relations, discharges }

private def decodeEvidenceManifest? (input : String) : Option EvidenceManifest :=
  match input.splitOn "\n" with
  | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow, trailing] =>
      if header != manifestHeaderV1 || trailing != "" then
        none
      else
        decodeEvidenceRows? eventRow validityRow descriptionRow relationRow dischargeRow
  | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow,
      _policyRow, trailing] =>
      if header != manifestHeaderV2 || trailing != "" then
        none
      else
        decodeEvidenceRows? eventRow validityRow descriptionRow relationRow dischargeRow
  | _ => none

private def decodeManifest? (input : String) : Option Manifest :=
  match input.splitOn "\n" with
  | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow, trailing] =>
      if header != manifestHeaderV1 || trailing != "" then
        none
      else do
        let evidence ←
          decodeEvidenceRows? eventRow validityRow descriptionRow relationRow dischargeRow
        some {
          events := evidence.events
          validity := evidence.validity
          descriptions := evidence.descriptions
          relations := evidence.relations
          discharges := evidence.discharges
          locusAdmission := none
        }
  | [header, eventRow, validityRow, descriptionRow, relationRow, dischargeRow,
      locusAdmissionRow, trailing] =>
      if header != manifestHeaderV2 || trailing != "" then
        none
      else do
        let evidence ←
          decodeEvidenceRows? eventRow validityRow descriptionRow relationRow dischargeRow
        let locusAdmission ← decodeManifestRow? "LocusAdmission" locusAdmissionRow
        some {
          events := evidence.events
          validity := evidence.validity
          descriptions := evidence.descriptions
          relations := evidence.relations
          discharges := evidence.discharges
          locusAdmission := some locusAdmission
        }
  | _ => none

private def recoveryManifestRelativePath (digest : String) : String :=
  "recovery/manifests/" ++ digest ++ ".loam"

private def failedCurrentRelativePath (digest : String) : String :=
  "recovery/failed-current/" ++ digest ++ ".loam"

private def safeRecoveryDigestToken (digest : String) : Bool :=
  digest.length == 64 &&
    !digest.contains '/' &&
    !digest.contains '\\' &&
    Loam.Persistence.validToken digest

/--
Retain one already-validated manifest as an immutable off-authority recovery
candidate. The caller is responsible for proving that its referenced generation is
currently readable before invoking this physical retention step.
-/
private def retainRecoveryManifest?
    (root : System.FilePath) (text : String) : IO (Except String String) := do
  match decodeManifest? text with
  | none => return .error "loam: recovery candidate manifest is malformed or unsupported"
  | some _ => pure ()
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := recoveryManifestRelativePath digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    if existing != text then
      return .error s!"loam: content-addressed recovery manifest mismatch: {relative}"
    return .ok digest
  let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  if staged != text then
    return .error s!"loam: staged recovery manifest mismatch: {relative}"
  IO.FS.rename stage target
  return .ok digest

/--
Preserve unreadable `CURRENT` bytes for diagnosis before an explicit recovery
selection. These bytes are forensic evidence only and never become a recovery
candidate or selected authority.
-/
private def retainFailedCurrent?
    (root : System.FilePath) (text : String) : IO (Except String String) := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := failedCurrentRelativePath digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  if ← target.pathExists then
    let existing ← IO.FS.readFile target
    if existing != text then
      return .error s!"loam: content-addressed failed CURRENT mismatch: {relative}"
    return .ok digest
  let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  if staged != text then
    return .error s!"loam: staged failed CURRENT mismatch: {relative}"
  IO.FS.rename stage target
  return .ok digest

private def boolNat (value : Bool) : Nat := if value then 1 else 0

private def encodeWorld?
    (world : Loam.MovementAdmission.World) : Option WorldBytes := do
  let events ← Loam.Persistence.encodeEventMemory? world.events
  let validity ← Loam.Persistence.encodeActualValidityHistory? world.validity
  let descriptions ← Loam.Persistence.encodeEventDescriptionMemory? world.descriptions
  let relations ← Loam.Persistence.encodeOpenRelationUnits? world.relations
  let discharges ← Loam.Persistence.encodeRelationDischarges? world.discharges
  let locusAdmission ←
    Loam.Persistence.encodeLocusAdmissionVocabulary? world.locusAdmission
  some { events, validity, descriptions, relations, discharges, locusAdmission }

private def decodeEvidence?
    (events validity descriptions relations discharges : String) : Option EvidenceWorld := do
  let eventMemory ← Loam.Persistence.decodeEventMemory? events
  let validityHistory ← Loam.Persistence.decodeActualValidityHistory? validity
  let descriptionMemory ← Loam.Persistence.decodeEventDescriptionMemory? descriptions
  let relationUnits ← Loam.Persistence.decodeOpenRelationUnits? relations
  let relationDischarges ← Loam.Persistence.decodeRelationDischarges? discharges
  some {
    events := eventMemory
    validity := validityHistory
    descriptions := descriptionMemory
    relations := relationUnits
    discharges := relationDischarges
  }

private def worldWithPolicy
    (evidence : EvidenceWorld)
    (locusAdmission : Loam.Core.LocusAdmissionVocabulary) : Loam.MovementAdmission.World := {
  events := evidence.events
  validity := evidence.validity
  descriptions := evidence.descriptions
  relations := evidence.relations
  discharges := evidence.discharges
  locusAdmission := locusAdmission
}

private def ensureObject?
    (root : System.FilePath) (family text : String) : IO (Except String (FamilyRef × Bool)) := do
  let digest := Loam.Sha256.hash text.toUTF8
  let relative := objectRelativePath family digest
  let target := root / relative
  if let some parent := target.parent then
    IO.FS.createDirAll parent
  let existed ← target.pathExists
  if existed then
    let existing ← IO.FS.readFile target
    if existing == text then
      return Except.ok ({ path := relative, sha256 := digest }, true)
    else
      return Except.error s!"loam: content-addressed Movement object mismatch: {relative}"
  else
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    if staged != text then
      return Except.error s!"loam: staged Movement object mismatch: {relative}"
    IO.FS.rename stage target
    return Except.ok ({ path := relative, sha256 := digest }, false)

private def loadReferenced?
    (root : System.FilePath) (ref : FamilyRef) : IO (Except String String) := do
  let target := root / ref.path
  if !(← target.pathExists) then
    return Except.error s!"loam: selected Movement object is missing: {ref.path}"
  let text ← IO.FS.readFile target
  if Loam.Sha256.hash text.toUTF8 != ref.sha256 then
    return Except.error s!"loam: selected Movement object failed digest verification: {ref.path}"
  return Except.ok text

private def loadEvidenceForRefs?
    (root : System.FilePath)
    (manifest : EvidenceManifest) : IO (Except String EvidenceWorld) := do
  let events ←
    match ← loadReferenced? root manifest.events with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let validity ←
    match ← loadReferenced? root manifest.validity with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let descriptions ←
    match ← loadReferenced? root manifest.descriptions with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let relations ←
    match ← loadReferenced? root manifest.relations with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  let discharges ←
    match ← loadReferenced? root manifest.discharges with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  match decodeEvidence? events validity descriptions relations discharges with
  | some evidence => return Except.ok evidence
  | none => return Except.error "loam: selected Movement evidence failed production typed decoding"

private def evidenceRefs (manifest : Manifest) : EvidenceManifest := {
  events := manifest.events
  validity := manifest.validity
  descriptions := manifest.descriptions
  relations := manifest.relations
  discharges := manifest.discharges
}

private def loadWorldForManifest?
    (root : System.FilePath)
    (manifest : Manifest) : IO (Except String Loam.MovementAdmission.World) := do
  let evidence ←
    match ← loadEvidenceForRefs? root (evidenceRefs manifest) with
    | Except.ok evidence => pure evidence
    | Except.error message => return Except.error message
  match manifest.locusAdmission with
  | none =>
      return Except.ok (worldWithPolicy evidence Loam.Core.LocusAdmissionVocabulary.empty)
  | some locusAdmissionRef =>
      let locusAdmissionText ←
        match ← loadReferenced? root locusAdmissionRef with
        | Except.ok text => pure text
        | Except.error message => return Except.error message
      let locusAdmission ←
        match Loam.Persistence.decodeLocusAdmissionVocabulary? locusAdmissionText with
        | some vocabulary => pure vocabulary
        | none => return Except.error "loam: selected Locus admission policy failed production typed decoding"
      return Except.ok (worldWithPolicy evidence locusAdmission)

private def loadSelectedManifestText?
    (root : System.FilePath) : IO (Except String String) := do
  let current := root / "CURRENT"
  if !(← current.pathExists) then
    return Except.error "loam: selected Movement manifest CURRENT is missing"
  return Except.ok (← IO.FS.readFile current)

private def loadSelectedManifest?
    (root : System.FilePath) : IO (Except String Manifest) := do
  let text ←
    match ← loadSelectedManifestText? root with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  match decodeManifest? text with
  | some manifest => return Except.ok manifest
  | none => return Except.error "loam: selected Movement manifest CURRENT is malformed or unsupported"

private def loadSelectedEvidenceManifest?
    (root : System.FilePath) : IO (Except String EvidenceManifest) := do
  let text ←
    match ← loadSelectedManifestText? root with
    | Except.ok text => pure text
    | Except.error message => return Except.error message
  match decodeEvidenceManifest? text with
  | some manifest => return Except.ok manifest
  | none =>
      return Except.error "loam: selected Movement evidence manifest CURRENT is malformed or unsupported"

/--
Load the five selected household Movement evidence families without requiring the
selected LocusAdmission object or policy manifest row to be readable.

The `CURRENT` manifest envelope and all five evidence object references still fail
closed on missing, malformed, digest-invalid, or typed-invalid state. This function
only removes current new-write policy from read-only household availability; it
does not authorize publication or weaken evidence-generation closure. Full-world,
publication, and exact-recovery paths continue to require strict full-manifest
decoding.
-/
def loadSelectedEvidence?
    (root : System.FilePath) : IO (Except String EvidenceWorld) := do
  let manifest ←
    match ← loadSelectedEvidenceManifest? root with
    | Except.ok manifest => pure manifest
    | Except.error message => return Except.error message
  loadEvidenceForRefs? root manifest

/--
Load exactly one selected Movement generation including current new-write policy.
There is no sidecar discovery or legacy fallback: missing, malformed, unsupported,
or digest-invalid selected authority fails closed.

A version 1 generation remains readable but receives the empty new-write
vocabulary. It can therefore support review/projection while refusing every new
Movement at `MovementAdmission.admit?` until an explicit version 2 cutover.
-/
def loadSelectedWorld?
    (root : System.FilePath) : IO (Except String Loam.MovementAdmission.World) := do
  let manifest ←
    match ← loadSelectedManifest? root with
    | Except.ok manifest => pure manifest
    | Except.error message => return Except.error message
  loadWorldForManifest? root manifest

private def loadRecoveryManifestText?
    (root : System.FilePath) (digest : String) : IO (Except String String) := do
  if !safeRecoveryDigestToken digest then
    return .error "loam: recovery digest must be one 64-character path-safe SHA-256 token"
  let candidate := root / recoveryManifestRelativePath digest
  if !(← candidate.pathExists) then
    return .error "loam: requested Movement recovery candidate does not exist"
  let text ← IO.FS.readFile candidate
  if Loam.Sha256.hash text.toUTF8 != digest then
    return .error "loam: requested Movement recovery candidate failed manifest digest verification"
  let manifest ←
    match decodeManifest? text with
    | some manifest => pure manifest
    | none => return .error "loam: requested Movement recovery candidate is malformed or unsupported"
  match ← loadWorldForManifest? root manifest with
  | .error message =>
      return .error ("loam: requested Movement recovery candidate failed generation validation: " ++ message)
  | .ok _ => return .ok text

/-- Verify one retained recovery candidate without selecting it. -/
def validateRecoveryCandidate?
    (root : System.FilePath) (digest : String) : IO (Except String Unit) := do
  match ← loadRecoveryManifestText? root digest with
  | .error message => return .error message
  | .ok _ => return .ok ()

/--
Explicitly select one retained recovery candidate after full validation.

This operation never searches for or guesses a candidate. The caller supplies the
exact manifest digest. If current authority is readable, its manifest is first
retained as an ordinary recovery candidate so the restore is reversible. If current
authority is unreadable, its exact bytes are retained only as failed-current
diagnostic evidence before replacement.

Writer ownership of `root / "CURRENT"` belongs to the caller, matching the existing
physical publication boundary.
-/
def restoreRecoveryCandidate?
    (root : System.FilePath) (digest : String) : IO (Except String Unit) := do
  let candidateText ←
    match ← loadRecoveryManifestText? root digest with
    | .error message => return .error message
    | .ok text => pure text
  let expected ←
    match decodeManifest? candidateText with
    | some manifest => pure manifest
    | none => return .error "loam: validated recovery candidate changed before selection"
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  if ← target.pathExists then
    let currentText ← IO.FS.readFile target
    match ← loadSelectedWorld? root with
    | .ok _ =>
        match ← retainRecoveryManifest? root currentText with
        | .error message => return .error message
        | .ok _ => pure ()
    | .error _ =>
        match ← retainFailedCurrent? root currentText with
        | .error message => return .error message
        | .ok _ => pure ()
  let stage := root / "CURRENT.loam-stage"
  IO.FS.writeFile stage candidateText
  let staged ←
    match decodeManifest? (← IO.FS.readFile stage) with
    | some manifest => pure manifest
    | none => return .error "loam: staged recovery CURRENT failed decoding"
  if staged != expected then
    return .error "loam: staged recovery CURRENT changed typed references"
  IO.FS.rename stage target
  match ← loadSelectedWorld? root with
  | .error message => return .error ("loam: restored Movement CURRENT failed post-selection validation: " ++ message)
  | .ok _ => return .ok ()

/--
Prepare all six typed family images off authority. Existing byte-identical
content-addressed objects are reused. No `CURRENT` change occurs here. Every new
prepared generation is version 2 and therefore carries explicit new-write policy.
-/
def prepareWorld?
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO (Except String Prepared) := do
  let bytes ←
    match encodeWorld? world with
    | some bytes => pure bytes
    | none => return Except.error "loam: production encoders rejected admitted Movement world"
  IO.FS.createDirAll root
  let (events, reusedEvents) ←
    match ← ensureObject? root "Event" bytes.events with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (validity, reusedValidity) ←
    match ← ensureObject? root "ActualValidity" bytes.validity with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (descriptions, reusedDescriptions) ←
    match ← ensureObject? root "EventDescription" bytes.descriptions with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (relations, reusedRelations) ←
    match ← ensureObject? root "RelationUnit" bytes.relations with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (discharges, reusedDischarges) ←
    match ← ensureObject? root "RelationDischarge" bytes.discharges with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let (locusAdmission, reusedLocusAdmission) ←
    match ← ensureObject? root "LocusAdmission" bytes.locusAdmission with
    | Except.ok value => pure value
    | Except.error message => return Except.error message
  let manifest : Manifest := {
    events, validity, descriptions, relations, discharges,
    locusAdmission := some locusAdmission
  }
  let reused := boolNat reusedEvents + boolNat reusedValidity + boolNat reusedDescriptions +
    boolNat reusedRelations + boolNat reusedDischarges + boolNat reusedLocusAdmission
  return Except.ok {
    manifestText := encodeManifest manifest
    reusedObjects := reused
  }

/--
Atomically select one already-prepared Movement generation by replacing only
`CURRENT`. Before switching, an existing selected generation must fully validate and
its exact manifest is retained as an immutable off-authority recovery candidate.
A malformed or unreadable current authority therefore blocks the switch rather than
being overwritten and hidden.
-/
def commitPrepared?
    (root : System.FilePath) (prepared : Prepared) : IO (Except String Unit) := do
  let expected ←
    match decodeManifest? prepared.manifestText with
    | some manifest => pure manifest
    | none => return Except.error "loam: prepared Movement manifest is malformed"
  IO.FS.createDirAll root
  let target := root / "CURRENT"
  if ← target.pathExists then
    match ← loadSelectedWorld? root with
    | .error message =>
        return .error ("loam: existing Movement CURRENT cannot be retained for recovery: " ++ message)
    | .ok _ => pure ()
    let currentText ← IO.FS.readFile target
    match ← retainRecoveryManifest? root currentText with
    | .error message => return .error message
    | .ok _ => pure ()
  let stage := root / "CURRENT.loam-stage"
  IO.FS.writeFile stage prepared.manifestText
  let staged ←
    match decodeManifest? (← IO.FS.readFile stage) with
    | some manifest => pure manifest
    | none => return Except.error "loam: staged Movement CURRENT failed decoding"
  if staged != expected then
    return Except.error "loam: staged Movement CURRENT changed typed references"
  IO.FS.rename stage target
  return Except.ok ()

/-- Prepare immutable objects and then perform one Movement authority switch. -/
def publishWorld?
    (root : System.FilePath)
    (world : Loam.MovementAdmission.World) : IO (Except String Nat) := do
  match ← prepareWorld? root world with
  | Except.error message => return Except.error message
  | Except.ok prepared =>
      match ← commitPrepared? root prepared with
      | Except.error message => return Except.error message
      | Except.ok () => return Except.ok prepared.reusedObjects

end Loam.MovementManifestAuthority