import Loam.HistoricalPrepare
import Loam.WriterOwnership
import Loam.Application.BasisCut
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.QuantityBasisPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.BalanceViewConfig

/-!
# Historical Actual publisher

Production-specific, one-time publication of an already sealed Historical Actual
PREPARED bundle.  This module never constructs candidates or issues identity.
It recognizes only the phase shapes qualified by Observation 145, holds the
existing EventMemory writer lock for the whole operation, and refuses every
other physical state.

## Source authority boundary and operational quiescence precondition

- Source is a pre-authority-commit qualification input only:
    - Before invoking real publisher: freeze HRA writes and verify current
      SHA matches the approved source SHA.
    - Pre-commit (before E1): live source SHA must match manifest SOURCE-SHA256.
      Source missing or drifting before E1 aborts publication without committing E1.
    - Post-commit (after E1): LOAM becomes the sole Actual authority.  External
      source is never read again.  Recovery relies entirely on sealed PREPARED,
      the archived destination snapshot S1, manifest, and final canonical state.
    - Completed state (after Receipt + PREPARED cleanup): verification is
      entirely self-contained in LOAM (`Receipt` + archived snapshot + canonical files).
      External source can be missing, modified, or renamed without affecting LOAM.

## Product boundary

This is one-time cutover machinery.  It does NOT implement:
- generic import frameworks
- permanent HRA connectors
- source synchronization
- cross-system distributed transaction frameworks
-/

namespace Loam.HistoricalPublisher

open Loam.Core
open Loam.Persistence
open Loam.HistoricalPrepare

set_option autoImplicit false

inductive RestartAction
  | resumePreCommitPublication
  | resumePostCommitRetirement
  | recoverReceiptOnly
  | cleanupLeftoverPrepared
  | complete
  deriving Repr, DecidableEq

private def candidatePaths : List String := [
  "memory.loam",
  "memory.loam.actual-validity",
  "memory.loam.descriptions",
  "basis.loam",
  "scheduled.loam",
  "balance-view.tsv",
  "historical-admission/actual.journal.snapshot"
]

private def presentMutationPaths : List String := [
  "memory.loam.actual-validity",
  "memory.loam.descriptions",
  "basis.loam",
  "historical-admission/actual.journal.snapshot",
  "memory.loam"
]

private def unchangedPaths : List String := [
  "basis-corrections.loam",
  "scheduled.loam",
  "scheduled.loam.completions",
  "balance-view.tsv"
]

private def retiredPaths : List String := ["corrections.loam", "basis-cut.tsv"]

private def receiptRelPath : String := "historical-admission/admission-receipt"
private def finalMarkerName : String := "FINAL-VERIFIED"
private def receiptHeader : String := "LOAM-HISTORICAL-ADMISSION-RECEIPT\t1"
private def markerHeader : String := "LOAM-HISTORICAL-FINAL-VERIFIED\t1"

private def fail {α : Type} (message : String) : IO (Except String α) := do
  return Except.error message

private def decodeUtf8? (bytes : ByteArray) : Except String String :=
  match String.fromUTF8? bytes with
  | some text => Except.ok text
  | none => Except.error "invalid UTF-8"

private def validSha256Text (digest : String) : Bool :=
  digest.length == 64 && digest.toList.all fun c =>
    c.isDigit || ('a' ≤ c && c ≤ 'f')

private def baseEntry? (manifest : Manifest) (name : String) : Option (String × String) :=
  match manifest.destBase.find? (fun row => row.1 == name) with
  | none => none
  | some row => some (row.2.1, row.2.2)

private def candidateEntry? (manifest : Manifest) (name : String) : Option (Nat × String) :=
  match manifest.candidates.find? (fun row => row.1 == name) with
  | none => none
  | some row => some (row.2.1, row.2.2)

private def fileMatches
    (path : System.FilePath) (sha byteCount : String) : IO Bool := do
  match ← fingerprintFile? path with
  | none => return sha == "ABSENT" && byteCount == "ABSENT"
  | some (bytes, actualSha) =>
      return sha != "ABSENT" && actualSha == sha && toString bytes.size == byteCount

private def matchesBase
    (manifest : Manifest) (destination : System.FilePath) (name : String) : IO Bool := do
  match baseEntry? manifest name with
  | none => return false
  | some (sha, bytes) => fileMatches (destination / name) sha bytes

private def matchesCandidate
    (manifest : Manifest) (destination : System.FilePath) (name : String) : IO Bool := do
  match candidateEntry? manifest name with
  | none => return false
  | some (bytes, sha) => fileMatches (destination / name) sha (toString bytes)

private def candidateFileMatches
    (manifest : Manifest) (candidateRoot : System.FilePath) (name : String) : IO Bool := do
  match candidateEntry? manifest name with
  | none => return false
  | some (bytes, sha) => fileMatches (candidateRoot / name) sha (toString bytes)

private def pathAbsent (path : System.FilePath) : IO Bool := do
  return !(← path.pathExists)

private def writeApprovedBytesAtomically
    (source target : System.FilePath) : IO (Except String Unit) := do
  try
    let bytes ← IO.FS.readBinFile source
    if let some parent := target.parent then IO.FS.createDirAll parent
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeBinFile stage bytes
    let staged ← IO.FS.readBinFile stage
    if staged != bytes then
      return Except.error s!"staged bytes differ for {target}"
    IO.FS.rename stage target
    return Except.ok ()
  catch e =>
    return Except.error s!"could not atomically publish {target}: {e}"

private def writeTextAtomically
    (target : System.FilePath) (text : String) : IO (Except String Unit) := do
  try
    if let some parent := target.parent then IO.FS.createDirAll parent
    let stage := System.FilePath.mk (target.toString ++ ".loam-stage")
    IO.FS.writeFile stage text
    IO.FS.rename stage target
    return Except.ok ()
  catch e =>
    return Except.error s!"could not atomically publish {target}: {e}"

private def maybeCrashAfter (boundary : String) : IO Unit := do
  match ← IO.getEnv "LOAM_HISTORICAL_PUBLISH_CRASH_AFTER" with
  | some requested =>
      if requested == boundary then
        IO.eprintln s!"qualification crash injection after {boundary}"
        IO.Process.exit 86
  | none => pure ()

private def maybeHoldForLockQualification : IO Unit := do
  match ← IO.getEnv "LOAM_HISTORICAL_PUBLISH_HOLD_MILLIS" with
  | some text =>
      match text.toNat? with
      | some millis => IO.sleep (UInt32.ofNat millis)
      | none => pure ()
  | none => pure ()

private def verifySealedCandidate
    (manifest : Manifest)
    (candidateRoot : System.FilePath) : IO (Except String Unit) := do
  if manifest.candidates.map (·.1) != candidatePaths then
    return ← fail "manifest CANDIDATE rows are not the exact publisher candidate set"
  for row in manifest.candidates do
    if !(← candidateFileMatches manifest candidateRoot row.1) then
      return ← fail s!"candidate fingerprint mismatch: {row.1}"
  for name in ["basis-cut.tsv", "corrections.loam", "basis-corrections.loam",
      "scheduled.loam.completions", receiptRelPath] do
    if !(← pathAbsent (candidateRoot / name)) then
      return ← fail s!"candidate path must be physically ABSENT: {name}"
  let snapshot ←
    match ← fingerprintFile? (candidateRoot / "historical-admission/actual.journal.snapshot") with
    | none => return ← fail "candidate snapshot missing"
    | some pair => pure pair
  if snapshot.2 != manifest.sourceSha256 || snapshot.1.size != manifest.sourceBytes then
    return ← fail "candidate snapshot does not match manifest source fingerprint"
  let events ←
    match ← loadEventMemory? (candidateRoot / "memory.loam") with
    | none => return ← fail "production loader rejected candidate EventMemory"
    | some value => pure value
  let validities ←
    match ← loadActualValidityHistory? (candidateRoot / "memory.loam.actual-validity") with
    | none => return ← fail "production loader rejected candidate ActualValidity"
    | some value => pure value
  let descriptions ←
    match ← loadEventDescriptionMemory? (candidateRoot / "memory.loam.descriptions") with
    | none => return ← fail "production loader rejected candidate EventDescription"
    | some value => pure value
  let bases ←
    match ← loadQuantityBasisMemory? (candidateRoot / "basis.loam") with
    | none => return ← fail "production loader rejected candidate QuantityBasis"
    | some value => pure value
  if (← loadScheduledMemory? (candidateRoot / "scheduled.loam")).isNone then
    return ← fail "production loader rejected candidate ScheduledMemory"
  if events.events.length != manifest.sourceEventCount ||
      validities.facts.length != manifest.sourceEventCount ||
      descriptions.entries.length != manifest.sourceEventCount ||
      !validities.corrections.isEmpty then
    return ← fail "candidate production counts or validity frontier shape mismatch"
  let eventIds := events.events.map (·.id.token)
  let validityIds := validities.facts.map (·.event.token)
  let descriptionIds := descriptions.entries.map (·.event.token)
  if eventIds.length != eventIds.eraseDups.length ||
      validityIds.length != validityIds.eraseDups.length ||
      descriptionIds.length != descriptionIds.eraseDups.length then
    return ← fail "candidate contains repeated Event-scoped identity"
  for id in eventIds do
    if !validityIds.contains id || !descriptionIds.contains id then
      return ← fail s!"candidate Event lacks validity or description: {id}"
  for id in validityIds ++ descriptionIds do
    if !eventIds.contains id then
      return ← fail s!"candidate auxiliary stream has dangling EventId: {id}"
  let effectKeys := events.events.foldl
    (fun acc event => acc ++ event.effects.map (·.key.token)) []
  if effectKeys.length != manifest.sourceEffectCount ||
      effectKeys.length != effectKeys.eraseDups.length then
    return ← fail "candidate EffectKey count or uniqueness mismatch"
  let basisIds := bases.bases.map (·.id.token)
  if basisIds.length != basisIds.eraseDups.length then
    return ← fail "candidate QuantityBasis identity is repeated"
  for basis in bases.bases do
    if basis.quantity.quanta != 0 then
      return ← fail "candidate origin QuantityBasis is not explicit zero"
  let view ←
    match ← Loam.BalanceViewConfig.load? (candidateRoot / "balance-view.tsv") with
    | none => return ← fail "production loader rejected candidate balance-view"
    | some value => pure value
  let basisCoordinates := bases.bases.map QuantityBasis.coordinate
  if basisCoordinates.length != basisCoordinates.eraseDups.length ||
      view.length != view.eraseDups.length || basisCoordinates.length != view.length then
    return ← fail "candidate basis/view coordinate shape mismatch"
  for coordinate in view do
    if !basisCoordinates.contains coordinate then
      return ← fail "candidate basis does not cover balance-view coordinate"
  let noEventCorrections : EventCorrectionMemory :=
    { corrections := [], idNodup := by simp }
  let noBasisCorrections : QuantityBasisCorrectionMemory :=
    { corrections := [], idNodup := by simp }
  for coordinate in view do
    let expected := events.quantityAtRecorded coordinate.locus coordinate.measure
    match Loam.Application.BasisCut.inspectCurrentQuantityWithBasisCut?
        events noEventCorrections bases noBasisCorrections []
        coordinate.locus coordinate.measure with
    | some (.current actual) =>
        if actual != expected then
          return ← fail "candidate CurrentQuantity parity mismatch"
    | _ => return ← fail "candidate CurrentQuantity unavailable"
  return Except.ok ()

private def verifyLiveSourceStillQualified
    (manifest : Manifest) (source : System.FilePath) : IO (Except String Unit) := do
  let (sourceBytes, sourceSha) ←
    match ← fingerprintFile? source with
    | none => return ← fail "live source file missing before authority commit"
    | some pair => pure pair
  if sourceSha != manifest.sourceSha256 || sourceBytes.size != manifest.sourceBytes then
    return ← fail "SOURCE-DRIFT: live source differs from PREPARED before authority commit"
  return Except.ok ()

private def verifyUnchanged
    (manifest : Manifest)
    (candidateRoot destination : System.FilePath) : IO (Except String Unit) := do
  for name in unchangedPaths do
    if !(← matchesBase manifest destination name) then
      return ← fail s!"unchanged destination stream drift: {name}"
  for name in ["scheduled.loam", "balance-view.tsv"] do
    let base ←
      match baseEntry? manifest name with
      | none => return ← fail s!"manifest base row missing: {name}"
      | some value => pure value
    let candidate ←
      match candidateEntry? manifest name with
      | none => return ← fail s!"manifest candidate row missing: {name}"
      | some value => pure value
    if base.1 != candidate.2 || base.2 != toString candidate.1 then
      return ← fail s!"candidate/base fingerprint inequality for no-rewrite stream: {name}"
    if !(← candidateFileMatches manifest candidateRoot name) then
      return ← fail s!"no-rewrite candidate fingerprint mismatch: {name}"
  return Except.ok ()

private inductive PhysicalPhase
  | initial | afterValidity | afterDescription | afterBasis | afterSnapshot
  | afterEvent | afterCorrections | afterCut
  deriving Repr, DecidableEq

private def classifyPhase
    (manifest : Manifest) (destination : System.FilePath) : IO (Option PhysicalPhase) := do
  let v0 ← matchesBase manifest destination "memory.loam.actual-validity"
  let v1 ← matchesCandidate manifest destination "memory.loam.actual-validity"
  let d0 ← matchesBase manifest destination "memory.loam.descriptions"
  let d1 ← matchesCandidate manifest destination "memory.loam.descriptions"
  let b0 ← matchesBase manifest destination "basis.loam"
  let b1 ← matchesCandidate manifest destination "basis.loam"
  let s0 ← pathAbsent (destination / "historical-admission/actual.journal.snapshot")
  let s1 ← matchesCandidate manifest destination "historical-admission/actual.journal.snapshot"
  let e0 ← matchesBase manifest destination "memory.loam"
  let e1 ← matchesCandidate manifest destination "memory.loam"
  let c0 ← matchesBase manifest destination "corrections.loam"
  let c1 ← pathAbsent (destination / "corrections.loam")
  let k0 ← matchesBase manifest destination "basis-cut.tsv"
  let k1 ← pathAbsent (destination / "basis-cut.tsv")
  if e0 && v0 && d0 && b0 && s0 && c0 && k0 then return some .initial
  if e0 && v1 && d0 && b0 && s0 && c0 && k0 then return some .afterValidity
  if e0 && v1 && d1 && b0 && s0 && c0 && k0 then return some .afterDescription
  if e0 && v1 && d1 && b1 && s0 && c0 && k0 then return some .afterBasis
  if e0 && v1 && d1 && b1 && s1 && c0 && k0 then return some .afterSnapshot
  if e1 && v1 && d1 && b1 && s1 && c0 && k0 then return some .afterEvent
  if e1 && v1 && d1 && b1 && s1 && c1 && k0 then return some .afterCorrections
  if e1 && v1 && d1 && b1 && s1 && c1 && k1 then return some .afterCut
  return none

private def finalFingerprints
    (manifestSha : String)
    (manifest : Manifest)
    (destination : System.FilePath) : IO (Except String (List (String × String))) := do
  let mut rows : List (String × String) := [
    ("APPROVED-PREPARED-MANIFEST-SHA256", manifestSha),
    ("SOURCE-SNAPSHOT-SHA256", manifest.sourceSha256),
    ("ADMITTED-EVENT-COUNT", toString manifest.sourceEventCount)
  ]
  for pair in [
      ("FINAL-EVENT-MEMORY-SHA256", "memory.loam"),
      ("FINAL-ACTUAL-VALIDITY-SHA256", "memory.loam.actual-validity"),
      ("FINAL-EVENT-DESCRIPTION-SHA256", "memory.loam.descriptions"),
      ("FINAL-QUANTITY-BASIS-SHA256", "basis.loam"),
      ("ARCHIVED-SNAPSHOT-SHA256", "historical-admission/actual.journal.snapshot")] do
    match ← fingerprintFile? (destination / pair.2) with
    | none => return ← fail s!"final file missing: {pair.2}"
    | some (_, sha) => rows := rows ++ [(pair.1, sha)]
  return Except.ok rows

private def encodeRows (header : String) (rows : List (String × String)) : String :=
  "\n".intercalate (header :: rows.map fun row => row.1 ++ "\t" ++ row.2) ++ "\n"

private def parseRows?
    (header input : String) (expectedKeys : List String) : Option (List (String × String)) := do
  let lines := match input.splitOn "\n" |>.reverse with
    | "" :: rest => rest.reverse
    | other => other.reverse
  let actualHeader ← lines.head?
  if actualHeader != header then none
  let mut rows : List (String × String) := []
  for line in lines.drop 1 do
    match line.splitOn "\t" with
    | [key, value] => rows := rows ++ [(key, value)]
    | _ => none
  if rows.map (·.1) != expectedKeys then none
  return rows

private def markerKeys : List String := [
  "APPROVED-PREPARED-MANIFEST-SHA256", "SOURCE-SNAPSHOT-SHA256",
  "ADMITTED-EVENT-COUNT", "FINAL-EVENT-MEMORY-SHA256",
  "FINAL-ACTUAL-VALIDITY-SHA256", "FINAL-EVENT-DESCRIPTION-SHA256",
  "FINAL-QUANTITY-BASIS-SHA256", "ARCHIVED-SNAPSHOT-SHA256"
]

private def receiptKeys : List String := markerKeys ++ ["COMPLETED-AT"]

private def markerMatches
    (bundle : System.FilePath) (expected : List (String × String)) : IO Bool := do
  match ← fingerprintFile? (bundle / finalMarkerName) with
  | none => return false
  | some (bytes, _) =>
      match decodeUtf8? bytes with
      | Except.error _ => return false
      | Except.ok text => return parseRows? markerHeader text markerKeys == some expected

private def receiptMatches
    (destination : System.FilePath)
    (expected : List (String × String)) : IO Bool := do
  match ← fingerprintFile? (destination / receiptRelPath) with
  | none => return false
  | some (bytes, _) =>
      match decodeUtf8? bytes with
      | Except.error _ => return false
      | Except.ok text =>
          match parseRows? receiptHeader text receiptKeys with
          | none => return false
          | some rows =>
              return rows.take expected.length == expected &&
                !(rows.getLast!.2.isEmpty)

private def retireExpectedOld
    (manifest : Manifest) (destination : System.FilePath) (name : String) :
    IO (Except String Unit) := do
  if ← pathAbsent (destination / name) then return Except.ok ()
  if !(← matchesBase manifest destination name) then
    return ← fail s!"refuse retirement of unexpected bytes: {name}"
  try
    IO.FS.removeFile (destination / name)
    return Except.ok ()
  catch e => return ← fail s!"could not retire {name}: {e}"

private def verifyFinalProduction
    (manifestSha : String)
    (manifest : Manifest)
    (candidateRoot destination : System.FilePath) : IO (Except (String) (List (String × String))) := do
  let phase ← classifyPhase manifest destination
  if phase != some .afterCut then return ← fail "final generation is not exact"
  for name in presentMutationPaths do
    if !(← matchesCandidate manifest destination name) then
      return ← fail s!"final candidate fingerprint mismatch: {name}"
  match ← verifyUnchanged manifest candidateRoot destination with
  | Except.error message => return ← fail message
  | Except.ok () => pure ()
  -- Re-run production loaders over canonical final paths.
  if (← loadEventMemory? (destination / "memory.loam")).isNone then
    return ← fail "final EventMemory rejected by production loader"
  if (← loadActualValidityHistory?
      (destination / "memory.loam.actual-validity")).isNone then
    return ← fail "final ActualValidity rejected by production loader"
  if (← loadEventDescriptionMemory?
      (destination / "memory.loam.descriptions")).isNone then
    return ← fail "final EventDescription rejected by production loader"
  if (← loadQuantityBasisMemory? (destination / "basis.loam")).isNone then
    return ← fail "final QuantityBasis rejected by production loader"
  finalFingerprints manifestSha manifest destination

private def completionTimestamp (marker : System.FilePath) : IO String := do
  let metadata ← marker.metadata
  return utcStampOfEpochSeconds metadata.modified.sec.toNat.toUInt64

private def publishRemaining
    (_phase : PhysicalPhase)
    (manifestSha : String)
    (manifest : Manifest)
    (bundle candidateRoot destination : System.FilePath) : IO (Except String Unit) := do
  let publishIfNeeded (name : String) : IO (Except String Unit) := do
    if ← matchesCandidate manifest destination name then return Except.ok ()
    let predecessorMatches ←
      if name == "historical-admission/actual.journal.snapshot" then
        pathAbsent (destination / name)
      else
        matchesBase manifest destination name
    if !predecessorMatches then
      return ← fail s!"publication predecessor mismatch: {name}"
    writeApprovedBytesAtomically (candidateRoot / name) (destination / name)
  maybeCrashAfter "before-v1"
  for pair in [
      ("memory.loam.actual-validity", "v1"),
      ("memory.loam.descriptions", "d1"),
      ("basis.loam", "b1"),
      ("historical-admission/actual.journal.snapshot", "s1"),
      ("memory.loam", "e1")] do
    match ← publishIfNeeded pair.1 with
    | Except.error message => return ← fail message
    | Except.ok () => maybeCrashAfter pair.2
  match ← retireExpectedOld manifest destination "corrections.loam" with
  | Except.error message => return ← fail message
  | Except.ok () => maybeCrashAfter "c0-retired"
  match ← retireExpectedOld manifest destination "basis-cut.tsv" with
  | Except.error message => return ← fail message
  | Except.ok () => maybeCrashAfter "k0-retired"
  let finalRows ←
    match ← verifyFinalProduction manifestSha manifest candidateRoot destination with
    | Except.error message => return ← fail message
    | Except.ok rows => pure rows
  match ← writeTextAtomically (bundle / finalMarkerName) (encodeRows markerHeader finalRows) with
  | Except.error message => return ← fail message
  | Except.ok () => pure ()
  maybeCrashAfter "final-verified"
  let timestamp ← completionTimestamp (bundle / finalMarkerName)
  match ← writeTextAtomically (destination / receiptRelPath)
      (encodeRows receiptHeader (finalRows ++ [("COMPLETED-AT", timestamp)])) with
  | Except.error message => return ← fail message
  | Except.ok () => pure ()
  maybeCrashAfter "receipt"
  try IO.FS.removeDirAll bundle
  catch e => return ← fail s!"could not retire PREPARED: {e}"
  maybeCrashAfter "prepared-cleanup"
  return Except.ok ()

private def completeWithoutPrepared
    (destination : System.FilePath) (approvedSha : String) : IO (Except String RestartAction) := do
  if !(validSha256Text approvedSha) then return ← fail "invalid approved manifest SHA-256"
  let receiptBytes ←
    match ← fingerprintFile? (destination / receiptRelPath) with
    | none => return ← fail "PREPARED missing before Receipt"
    | some pair => pure pair.1
  let rows ←
    match decodeUtf8? receiptBytes with
    | Except.error message => return ← fail s!"receipt rejected: {message}"
    | Except.ok text =>
        match parseRows? receiptHeader text receiptKeys with
        | none => return ← fail "receipt malformed or incomplete"
        | some rows => pure rows
  if rows[0]?.map (·.2) != some approvedSha then
    return ← fail "receipt does not bind caller-approved PREPARED manifest SHA-256"
  let receiptSourceSha ←
    match rows[1]?.map (·.2) with
    | none => return ← fail "receipt SOURCE-SNAPSHOT-SHA256 missing"
    | some value => pure value
  let receiptArchivedSha ←
    match rows[7]?.map (·.2) with
    | none => return ← fail "receipt ARCHIVED-SNAPSHOT-SHA256 missing"
    | some value => pure value
  if receiptSourceSha != receiptArchivedSha then
    return ← fail "receipt source SHA does not match receipt archived snapshot SHA"
  let actualArchivedSha ←
    match ← fingerprintFile? (destination / "historical-admission/actual.journal.snapshot") with
    | none => return ← fail "completed archived snapshot missing: historical-admission/actual.journal.snapshot"
    | some (_, sha) => pure sha
  if actualArchivedSha != receiptArchivedSha then
    return ← fail "completed archived snapshot SHA does not match receipt"
  for pair in [
      (3, "memory.loam"), (4, "memory.loam.actual-validity"),
      (5, "memory.loam.descriptions"), (6, "basis.loam")] do
    let expected ←
      match rows[pair.1]?.map (·.2) with
      | none => return ← fail "receipt final fingerprint row missing"
      | some value => pure value
    match ← fingerprintFile? (destination / pair.2) with
    | none => return ← fail s!"completed final file missing: {pair.2}"
    | some (_, sha) => if sha != expected then
        return ← fail s!"completed final fingerprint mismatch: {pair.2}"
  for name in retiredPaths do
    if !(← pathAbsent (destination / name)) then
      return ← fail s!"Receipt present but retired stream is present: {name}"
  return Except.ok .complete

private def publishLocked
    (bundle source destination : System.FilePath)
    (approvedSha : String) : IO (Except String RestartAction) := do
  maybeHoldForLockQualification
  if !(← bundle.pathExists) then
    return ← completeWithoutPrepared destination approvedSha
  if !validSha256Text approvedSha then return ← fail "invalid approved manifest SHA-256"
  let (manifestBytes, manifestSha) ←
    match ← fingerprintFile? (bundle / "manifest") with
    | none => return ← fail "PREPARED manifest missing"
    | some pair => pure pair
  if manifestSha != approvedSha then
    return ← fail s!"MANIFEST-NOT-APPROVED: caller SHA-256 does not match PREPARED manifest"
  let manifestText ←
    match decodeUtf8? manifestBytes with
    | Except.error message => return ← fail s!"manifest rejected: {message}"
    | Except.ok text => pure text
  let manifest ←
    match parseManifest? manifestText with
    | Except.error message => return ← fail s!"manifest rejected: {message}"
    | Except.ok value => pure value
  if manifest.sourcePath != source.toString || manifest.destinationRoot != destination.toString then
    return ← fail "requested source/destination do not match PREPARED manifest"
  let candidateRoot := bundle / "candidate-root"
  match ← verifySealedCandidate manifest candidateRoot with
  | Except.error message => return ← fail message
  | Except.ok () => pure ()
  match ← verifyUnchanged manifest candidateRoot destination with
  | Except.error message => return ← fail message
  | Except.ok () => pure ()
  let phase ←
    match ← classifyPhase manifest destination with
    | none => return ← fail "FailClosedInconsistent: destination is not a permitted publication phase"
    | some value => pure value
  let finalRows ←
    match ← finalFingerprints manifestSha manifest destination with
    | Except.ok rows => pure (some rows)
    | Except.error _ => pure none
  let receiptPresent ← (destination / receiptRelPath).pathExists
  let markerPresent ← (bundle / finalMarkerName).pathExists
  if receiptPresent then
    if phase != .afterCut then
      return ← fail "FailClosedInconsistent: Receipt present before full retirement"
    let rows ← match finalRows with
      | none => return ← fail "Receipt present but final fingerprints unavailable"
      | some rows => pure rows
    if !(← receiptMatches destination rows) then
      return ← fail "Receipt present but does not bind exact final generation"
    if !markerPresent || !(← markerMatches bundle rows) then
      return ← fail "Receipt present but final-verification evidence is missing or invalid"
    IO.println "restart: CleanupLeftoverPrepared"
    try IO.FS.removeDirAll bundle
    catch e => return ← fail s!"could not retire PREPARED: {e}"
    maybeCrashAfter "prepared-cleanup"
    return Except.ok .cleanupLeftoverPrepared
  if markerPresent then
    if phase != .afterCut then
      return ← fail "FailClosedInconsistent: final-verification marker precedes final state"
    let rows ← match finalRows with
      | none => return ← fail "final-verification marker has no exact final state"
      | some rows => pure rows
    if !(← markerMatches bundle rows) then
      return ← fail "final-verification marker mismatch"
    IO.println "restart: RecoverReceiptOnly"
    let timestamp ← completionTimestamp (bundle / finalMarkerName)
    match ← writeTextAtomically (destination / receiptRelPath)
        (encodeRows receiptHeader (rows ++ [("COMPLETED-AT", timestamp)])) with
    | Except.error message => return ← fail message
    | Except.ok () => pure ()
    maybeCrashAfter "receipt"
    try IO.FS.removeDirAll bundle
    catch e => return ← fail s!"could not retire PREPARED: {e}"
    maybeCrashAfter "prepared-cleanup"
    return Except.ok .recoverReceiptOnly
  let isPreCommit :=
    match phase with
    | .initial | .afterValidity | .afterDescription | .afterBasis | .afterSnapshot => true
    | .afterEvent | .afterCorrections | .afterCut => false
  if isPreCommit then
    match ← verifyLiveSourceStillQualified manifest source with
    | Except.error message => return ← fail message
    | Except.ok () => pure ()
    IO.println "restart: ResumePreCommitPublication"
  else
    IO.println "restart: ResumePostCommitRetirement"
  let action :=
    if isPreCommit then
      RestartAction.resumePreCommitPublication
    else
      RestartAction.resumePostCommitRetirement
  match ← publishRemaining phase manifestSha manifest bundle candidateRoot destination with
  | Except.error message => return ← fail message
  | Except.ok () => return Except.ok action

/--
Publish or recover one approved PREPARED bundle while holding the existing
EventMemory sibling writer lock.  No candidate construction occurs here.
The `source` path is checked strictly prior to authority commit (pre-commit);
post-commit recovery and completed verification are fully self-contained in LOAM.
-/
def publish
    (bundle source destination : System.FilePath)
    (approvedManifestSha256 : String) : IO (Except String RestartAction) :=
  Loam.WriterOwnership.withOwnership (destination / "memory.loam") <|
    publishLocked bundle source destination approvedManifestSha256

end Loam.HistoricalPublisher
