/-
Copyright (c) 2026 LOAM contributors. All rights reserved.
Released under Apache 2.0 license.
-/

import Loam.HistoricalPrepare
import Loam.Application.CurrentQuantity
import Loam.Application.BasisCut
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.QuantityBasisPersistence
import Loam.Persistence.ScheduledPersistence
import Loam.Persistence.ScheduledCompletionPersistence
import Loam.Persistence.BasisCutPersistence
import Loam.BalanceViewConfig

/-!
# Historical Actual prepare / verify CLI

Dry-run qualification boundary for the one-time Historical Actual authority
admission. Two operations:

```text
loamHistoricalPrepare prepare <actual-journal> <destination-root> <bundle-dir> <expected-source-sha256>
loamHistoricalPrepare verify  <bundle-dir> <actual-journal> <destination-root>
```

`prepare` reads the source exactly once, constructs an exact production-format
candidate under `<bundle-dir>/candidate-root`, and seals `<bundle-dir>/manifest`.
It performs no canonical publication, no writer locking, no directory swap, and
creates no admission receipt.

`verify` re-validates a sealed PREPARED bundle without reissuing any identity:
manifest fingerprints, production-loader qualification, identity invariants,
whole-history parity against the source, CurrentQuantity parity, and
source/destination drift detection.

Exit codes: 0 qualification passed, 1 qualification failed (fail closed),
2 usage or IO error.
-/

namespace Loam.Cli.HistoricalPrepareCli

open Loam.Core
open Loam.Persistence
open Loam.HistoricalPrepare

set_option autoImplicit false

private def usage : String :=
  "Historical Actual prepare / verify dry-run qualification\n\n" ++
  "  loamHistoricalPrepare prepare <actual-journal> <destination-root> <bundle-dir> <expected-source-sha256>\n" ++
  "  loamHistoricalPrepare verify  <bundle-dir> <actual-journal> <destination-root>\n"

private def fail (message : String) : IO UInt32 := do
  IO.eprintln s!"loam-historical-prepare: {message}"
  return 1

private def usageFail : IO UInt32 := do
  IO.eprintln usage
  return 2

/-- Deduplicate coordinates without imposing any order meaning. -/
private def dedupCoordinates (coordinates : List EffectCoordinate) : List EffectCoordinate :=
  coordinates.foldl (fun acc coordinate =>
    if acc.any (fun known => decide (known = coordinate)) then acc else acc ++ [coordinate]) []

private def coordinatePresent
    (coordinates : List EffectCoordinate) (target : EffectCoordinate) : Bool :=
  coordinates.any (fun known => decide (known = target))

private def decodeUtf8? (bytes : ByteArray) : Except String String :=
  match String.fromUTF8? bytes with
  | none => Except.error "invalid UTF-8"
  | some text => Except.ok text

private def sortList {α : Type} (items : List α) (lt : α → α → Bool) : List α :=
  (items.toArray.qsort lt).toList

private def candidateRelPaths : List String := [
  "memory.loam",
  "memory.loam.actual-validity",
  "memory.loam.descriptions",
  "basis.loam",
  "scheduled.loam",
  "balance-view.tsv",
  "historical-admission/actual.journal.snapshot"
]

private def captureDestinationBase
    (root : System.FilePath) : IO (List (String × String × String)) := do
  let mut rows : List (String × String × String) := []
  for name in destinationBaseFileNames do
    match ← fingerprintFile? (root / name) with
    | none => rows := rows ++ [(name, "ABSENT", "ABSENT")]
    | some (bytes, sha) => rows := rows ++ [(name, sha, toString bytes.size)]
  return rows

private def validSha256Text (digest : String) : Bool :=
  digest.length == 64 && digest.toList.all fun c =>
    c.isDigit || ('a' ≤ c && c ≤ 'f')

/-! ## prepare -/

private def writeTextChecked
    (path : System.FilePath) (text : String) : IO (Except String Unit) := do
  try
    IO.FS.writeFile path text
    return Except.ok ()
  catch e => return Except.error s!"could not write {path}: {e}"

private def prepare
    (sourcePath destinationRoot bundleDir expectedSourceSha : String) : IO UInt32 := do
  let sourceFile := System.FilePath.mk sourcePath
  let destRoot := System.FilePath.mk destinationRoot
  let bundle := System.FilePath.mk bundleDir
  let root := bundle / "candidate-root"
  -- Refuse to overwrite an existing sealed or partial bundle.
  if ← bundle.pathExists then
    return ← fail s!"bundle directory already exists: {bundleDir}"
  -- 1. Read the source exactly once; hash and parse those same bytes.
  let (sourceBytes, sourceSha) ←
    match ← fingerprintFile? sourceFile with
    | none => return ← fail s!"missing source file: {sourcePath}"
    | some pair => pure pair
  if !validSha256Text expectedSourceSha || sourceSha ≠ expectedSourceSha then
    return ← fail
      s!"SOURCE-NOT-QUALIFIED: caller-approved sha256 {expectedSourceSha} does not match actual source sha256 {sourceSha}"
  let sourceText ←
    match decodeUtf8? sourceBytes with
    | Except.error message => return ← fail s!"source rejected: {message}"
    | Except.ok text => pure text
  let txs ←
    match parseJournal? sourceText with
    | Except.error message => return ← fail s!"source rejected: {message}"
    | Except.ok txs => pure txs
  let stats ←
    match sourceStats txs with
    | Except.error message => return ← fail s!"source rejected: {message}"
    | Except.ok stats => pure stats
  -- Migration-batch qualification guards, not universal HRA/LOAM laws. The
  -- caller-approved source fingerprint is the exact batch authority gate.
  if stats.eventCount ≠ 558 then
    return ← fail s!"source event count {stats.eventCount} ≠ qualified 558"
  if stats.effectCount ≠ 1157 then
    return ← fail s!"source effect count {stats.effectCount} ≠ qualified 1157"
  if stats.completionCandidates ≠ 20 then
    return ← fail s!"source plan-id count {stats.completionCandidates} ≠ qualified 20"
  if stats.explicitSourceEventIds.length ≠ 1 then
    return ← fail s!"explicit source event-id count {stats.explicitSourceEventIds.length} ≠ qualified 1"
  -- 2. Destination base state fingerprints (read-only).
  let destBase ← captureDestinationBase destRoot
  -- Destination EventId namespace for the explicit-token collision check.
  let destinationEventTokens : List String ←
    if ← (destRoot / "memory.loam").pathExists then
      match ← loadEventMemory? (destRoot / "memory.loam") with
      | none => return ← fail "destination memory.loam exists but is malformed"
      | some memory => pure (memory.events.map (·.id.token))
    else
      pure []
  -- Balance-view coordinates drive the zero origin bases.
  let viewCoordinates ←
    match ← Loam.BalanceViewConfig.load? (destRoot / "balance-view.tsv") with
    | none => return ← fail "destination balance-view.tsv is malformed"
    | some [] => return ← fail "destination balance-view selects no coordinates"
    | some coordinates => pure coordinates
  -- 3. Seed the destination-owned opaque identity generator.
  let nanos ← IO.monoNanosNow
  let randomLow ← IO.rand 0 0xffffffff
  let randomHigh ← IO.rand 0 0xffffffff
  let seed : UInt64 := nanos.toUInt64 ^^^ randomLow.toUInt64 ^^^
    (randomHigh.toUInt64 <<< 32)
  let candidate ←
    match buildCandidate txs destinationEventTokens viewCoordinates seed with
    | Except.error message => return ← fail message
    | Except.ok candidate => pure candidate
  -- 4. Construct the production-format candidate root.
  IO.FS.createDirAll root
  IO.FS.createDirAll (root / "historical-admission")
  match encodeEventMemory? candidate.eventMemory with
  | none => return ← fail "internal: candidate EventMemory does not encode"
  | some text =>
      if (decodeEventMemory? text).isNone then
        return ← fail "internal: candidate EventMemory round-trip failed"
      match ← writeTextChecked (root / "memory.loam") text with
      | Except.error message => return ← fail message
      | Except.ok () => pure ()
  match encodeActualValidityHistory? candidate.validityHistory with
  | none => return ← fail "internal: candidate ActualValidity does not encode"
  | some text =>
      if (decodeActualValidityHistory? text).isNone then
        return ← fail "internal: candidate ActualValidity round-trip failed"
      match ← writeTextChecked (root / "memory.loam.actual-validity") text with
      | Except.error message => return ← fail message
      | Except.ok () => pure ()
  match encodeEventDescriptionMemory? candidate.descriptionMemory with
  | none => return ← fail "internal: candidate EventDescription does not encode"
  | some text =>
      if (decodeEventDescriptionMemory? text).isNone then
        return ← fail "internal: candidate EventDescription round-trip failed"
      match ← writeTextChecked (root / "memory.loam.descriptions") text with
      | Except.error message => return ← fail message
      | Except.ok () => pure ()
  match encodeQuantityBasisMemory? candidate.basisMemory with
  | none => return ← fail "internal: candidate QuantityBasis does not encode"
  | some text =>
      if (decodeQuantityBasisMemory? text).isNone then
        return ← fail "internal: candidate QuantityBasis round-trip failed"
      match ← writeTextChecked (root / "basis.loam") text with
      | Except.error message => return ← fail message
      | Except.ok () => pure ()
  -- ScheduledMemory / balance-view: verbatim destination byte preservation.
  for name in ["scheduled.loam", "balance-view.tsv"] do
    match ← fingerprintFile? (destRoot / name) with
    | none => return ← fail s!"destination {name} is required but missing"
    | some (bytes, sha) =>
        match destBase.find? (fun entry => entry.1 == name) with
        | none => return ← fail s!"internal: captured destination row missing for {name}"
        | some captured =>
            if captured.2.1 ≠ sha || captured.2.2 ≠ toString bytes.size then
              return ← fail s!"DESTINATION-DRIFT-DURING-PREPARE: {name} changed before copy"
        IO.FS.writeBinFile (root / name) bytes
        match ← fingerprintFile? (root / name) with
        | none => return ← fail s!"candidate {name} disappeared after copy"
        | some (_, copiedSha) =>
            if copiedSha ≠ sha then
              return ← fail s!"candidate {name} copy fingerprint mismatch"
  if (← loadScheduledMemory? (root / "scheduled.loam")).isNone then
    return ← fail "destination scheduled.loam is malformed under production loader"
  -- Exact source snapshot bytes.
  IO.FS.writeBinFile (root / "historical-admission" / "actual.journal.snapshot") sourceBytes
  -- 5. Candidate fingerprints, taken from the bytes now on disk.
  let mut candidateRows : List (String × Nat × String) := []
  for relPath in candidateRelPaths do
    match ← fingerprintFile? (root / relPath) with
    | none => return ← fail s!"candidate file missing after construction: {relPath}"
    | some (bytes, sha) =>
        candidateRows := candidateRows ++ [(relPath, bytes.size, sha)]
  -- 6. Recheck the destination immediately before sealing PREPARED. Source is
  -- intentionally not reread: hash, parse, and snapshot all used one byte read.
  let currentDestBase ← captureDestinationBase destRoot
  if currentDestBase ≠ destBase then
    return ← fail "DESTINATION-DRIFT-DURING-PREPARE: captured base changed before manifest seal"
  -- Seal the manifest last. No admission receipt: nothing transferred yet.
  let manifest : Manifest := {
    preparedAt := s!"monotonic-nanos:{nanos}"
    sourcePath := sourcePath
    sourceSha256 := sourceSha
    sourceBytes := sourceBytes.size
    sourceEventCount := stats.eventCount
    sourceEffectCount := stats.effectCount
    sourceCompletionCandidates := stats.completionCandidates
    explicitSourceEventId := stats.explicitSourceEventIds.head?
    destinationRoot := destinationRoot
    destBase := destBase
    candidates := candidateRows
  }
  match ← writeTextChecked (bundle / "manifest") (encodeManifest manifest) with
  | Except.error message => return ← fail message
  | Except.ok () => pure ()
  IO.println "prepare: sealed PREPARED historical-admission candidate (dry run only)"
  IO.println s!"  source: {sourcePath}"
  IO.println s!"  source sha256: {sourceSha}"
  IO.println s!"  source bytes: {sourceBytes.size}"
  IO.println s!"  events: {stats.eventCount}"
  IO.println s!"  effects: {stats.effectCount}"
  IO.println s!"  validity facts: {stats.eventCount}"
  IO.println s!"  descriptions: {stats.eventCount}"
  IO.println s!"  zero origin bases: {candidate.basisMemory.bases.length}"
  IO.println s!"  basis-cut rows: 0 (file intentionally absent)"
  IO.println s!"  scheduled completions: 0 (deferred; {stats.completionCandidates} plan-id candidates lexically preserved in snapshot)"
  IO.println s!"  explicit source event-id reuse: {candidate.explicitReusedTokens.length}"
  IO.println s!"  manifest: {bundleDir}/manifest"
  IO.println "  admission receipt: NOT created (authority not transferred)"
  return 0


/-! ## verify -/

/-- Expected posting-cardinality multiset for this qualified migration batch. -/
private def expectedCardinality : List (Nat × Nat) := [(2, 521), (3, 34), (4, 2), (5, 1)]

private def sortedEffectSignature (event : Event) : List (String × String × Int) :=
  sortList (event.effects.map fun effect =>
      (effect.locus.token, effect.amount.measure.token, effect.quantity.quanta))
    (fun a b => toString a < toString b)

private def sortedPostingSignature (tx : SourceTx) : List (String × String × Int) :=
  sortList (tx.postings.map fun posting =>
      (destinationLocus posting.account, destinationMeasure posting.measure, posting.amount))
    (fun a b => toString a < toString b)

private def addToAggregate
    (aggregate : List (String × String × Int))
    (entry : String × String × Int) : List (String × String × Int) :=
  if aggregate.any (fun known => known.1 == entry.1 && known.2.1 == entry.2.1) then
    aggregate.map fun known =>
      if known.1 == entry.1 && known.2.1 == entry.2.1 then
        (known.1, known.2.1, known.2.2 + entry.2.2)
      else
        known
  else
    aggregate ++ [entry]

private def aggregateSignature
    (pairs : List (String × String × Int)) : List (String × String × Int) :=
  sortList (pairs.foldl addToAggregate []) (fun a b => toString a < toString b)

private def verify
    (bundleDir sourcePath destinationRoot : String) : IO UInt32 := do
  let bundle := System.FilePath.mk bundleDir
  let root := bundle / "candidate-root"
  let checks ← IO.mkRef ([] : List String)
  let record (line : String) : IO Unit := do
    let xs ← checks.get
    checks.set (xs ++ [line])
  let reportFailure (message : String) : IO UInt32 := do
    IO.eprintln s!"FAIL: {message}"
    return 1
  -- 1. Manifest parse (fail closed on malformed or incomplete manifest).
  let manifest ←
    match ← fingerprintFile? (bundle / "manifest") with
    | none => return ← reportFailure "manifest missing"
    | some (bytes, _) =>
        let text ←
          match decodeUtf8? bytes with
          | Except.error message => return ← reportFailure s!"manifest rejected: {message}"
          | Except.ok text => pure text
        match parseManifest? text with
        | Except.error message => return ← reportFailure s!"manifest rejected: {message}"
        | Except.ok manifest => pure manifest
  record "manifest parsed"
  if manifest.candidates.map (·.1) ≠ candidateRelPaths then
    return ← reportFailure "manifest CANDIDATE rows do not cover the exact candidate file set"
  if manifest.sourceEventCount ≠ 558 || manifest.sourceEffectCount ≠ 1157 ||
      manifest.sourceCompletionCandidates ≠ 20 then
    return ← reportFailure "manifest source counts differ from qualified 558 / 1157 / 20"
  if manifest.explicitSourceEventId.isNone then
    return ← reportFailure "manifest missing the qualified explicit source EventId"
  if manifest.sourcePath ≠ sourcePath then
    return ← reportFailure
      s!"manifest source path {manifest.sourcePath} does not match requested {sourcePath}"
  if manifest.destinationRoot ≠ destinationRoot then
    return ← reportFailure
      s!"manifest destination root {manifest.destinationRoot} does not match requested {destinationRoot}"
  -- 2. Source drift: read the current source exactly once and compare.
  let (sourceBytes, sourceSha) ←
    match ← fingerprintFile? (System.FilePath.mk sourcePath) with
    | none => return ← reportFailure s!"missing source file: {sourcePath}"
    | some pair => pure pair
  if sourceSha ≠ manifest.sourceSha256 then
    return ← reportFailure
      s!"SOURCE-DRIFT: stale prepared candidate (prepared sha256 {manifest.sourceSha256}, current sha256 {sourceSha})"
  if sourceBytes.size ≠ manifest.sourceBytes then
    return ← reportFailure "source byte length drift"
  record "source fingerprint matches sealed manifest (no source drift)"
  -- 3. Destination drift.
  for entry in manifest.destBase do
    let name := entry.1
    let sha := entry.2.1
    let bytes := entry.2.2
    match ← fingerprintFile? (System.FilePath.mk destinationRoot / name) with
    | none =>
        if sha ≠ "ABSENT" then
          return ← reportFailure s!"DESTINATION-DRIFT: {name} was present when prepared but is missing"
    | some (currentBytes, currentSha) =>
        if sha == "ABSENT" then
          return ← reportFailure s!"DESTINATION-DRIFT: {name} appeared after preparation"
        if currentSha ≠ sha || toString currentBytes.size ≠ bytes then
          return ← reportFailure s!"DESTINATION-DRIFT: {name} changed after preparation"
  record "destination base fingerprints match sealed manifest (no destination drift)"
  -- 4. Candidate file fingerprints.
  for entry in manifest.candidates do
    let relPath := entry.1
    let byteCount := entry.2.1
    let sha := entry.2.2
    match ← fingerprintFile? (root / relPath) with
    | none => return ← reportFailure s!"candidate file missing: {relPath}"
    | some (currentBytes, currentSha) =>
        if currentBytes.size ≠ byteCount || currentSha ≠ sha then
          return ← reportFailure s!"candidate fingerprint mismatch: {relPath}"
  record s!"candidate fingerprints intact ({manifest.candidates.length} files)"
  -- 5. Snapshot byte equality with the current source.
  let snapshot ←
    match ← fingerprintFile? (root / "historical-admission" / "actual.journal.snapshot") with
    | none => return ← reportFailure "snapshot missing"
    | some (bytes, _) => pure bytes
  if snapshot != sourceBytes then
    return ← reportFailure "snapshot bytes differ from current source bytes"
  record "snapshot bytes are exactly the current source bytes"
  -- Exact candidate shape: semantically empty optional streams remain ABSENT,
  -- and no commit-evidence receipt is admitted during PREPARED.
  for relPath in ["basis-cut.tsv", "corrections.loam", "basis-corrections.loam",
      "scheduled.loam.completions", "historical-admission/admission-receipt"] do
    if ← (root / relPath).pathExists then
      return ← reportFailure s!"candidate file must be ABSENT: {relPath}"
  record "empty optional streams and admission receipt are ABSENT"
  -- 6. Production-loader qualification.
  let events ←
    match ← loadEventMemory? (root / "memory.loam") with
    | none => return ← reportFailure "production loader rejected candidate memory.loam"
    | some memory => pure memory
  if events.events.length ≠ manifest.sourceEventCount then
    return ← reportFailure
      s!"EventMemory count {events.events.length} ≠ manifest {manifest.sourceEventCount}"
  let validity ←
    match ← loadActualValidityHistory? (root / "memory.loam.actual-validity") with
    | none => return ← reportFailure "production loader rejected candidate actual-validity"
    | some history => pure history
  if validity.facts.length ≠ manifest.sourceEventCount || !validity.corrections.isEmpty then
    return ← reportFailure "ActualValidity count mismatch or unexpected corrections"
  let descriptions ←
    match ← loadEventDescriptionMemory? (root / "memory.loam.descriptions") with
    | none => return ← reportFailure "production loader rejected candidate descriptions"
    | some memory => pure memory
  if descriptions.entries.length ≠ manifest.sourceEventCount then
    return ← reportFailure "EventDescription count mismatch"
  let bases ←
    match ← loadQuantityBasisMemory? (root / "basis.loam") with
    | none => return ← reportFailure "production loader rejected candidate basis.loam"
    | some memory => pure memory
  let basisCut ←
    match ← Loam.BasisCutPersistence.load? (root / "basis-cut.tsv") with
    | none => return ← reportFailure "candidate basis-cut.tsv exists but is malformed"
    | some cut => pure cut
  if !basisCut.isEmpty then
    return ← reportFailure "candidate basis-cut must be empty (file absent)"
  let eventCorrections ←
    if ← (root / "corrections.loam").pathExists then
      match ← loadEventCorrectionMemory? (root / "corrections.loam") with
      | none => return ← reportFailure "candidate corrections.loam malformed"
      | some memory => pure memory
    else
      match EventCorrectionMemory.ofCorrections? [] with
      | none => return ← reportFailure "internal: empty correction memory invalid"
      | some memory => pure memory
  if !eventCorrections.corrections.isEmpty then
    return ← reportFailure "candidate must not import dogfood correction history"
  let scheduled ←
    match ← loadScheduledMemory? (root / "scheduled.loam") with
    | none => return ← reportFailure "production loader rejected candidate scheduled.loam"
    | some memory => pure memory
  let completionCount ←
    match ← loadScheduledCompletionMemoryOrEmpty?
        (scheduledCompletionPathForScheduledMemory (root / "scheduled.loam")) with
    | none => return ← reportFailure "candidate scheduled completions malformed"
    | some memory => pure memory.completions.length
  if completionCount ≠ 0 then
    return ← reportFailure "ScheduledCompletion must be 0 in this admission"
  if events.events.length ≠ 558 || validity.facts.length ≠ 558 ||
      descriptions.entries.length ≠ 558 || bases.bases.length ≠ 5 ||
      scheduled.occurrences.length ≠ 11 then
    return ← reportFailure "production-loader counts differ from qualified 558 / 558 / 558 / 5 / 11"
  let viewCoordinates ←
    match ← fingerprintFile? (root / "balance-view.tsv") with
    | none => return ← reportFailure "candidate balance-view.tsv missing"
    | some (bytes, _) =>
        let text ←
          match decodeUtf8? bytes with
          | Except.error message => return ← reportFailure s!"candidate balance-view rejected: {message}"
          | Except.ok text => pure text
        match Loam.BalanceViewConfig.decode? text with
        | none => return ← reportFailure "candidate balance-view.tsv malformed"
        | some coordinates => pure coordinates
  record s!"production loaders: events {events.events.length}, validities {validity.facts.length}, descriptions {descriptions.entries.length}, bases {bases.bases.length}, cut {basisCut.length}, corrections {eventCorrections.corrections.length}, scheduled {scheduled.occurrences.length}, completions {completionCount}"
  -- 7. Identity invariants.
  let eventIdTokens := events.events.map (·.id.token)
  if eventIdTokens.length ≠ eventIdTokens.eraseDups.length then
    return ← reportFailure "duplicate EventId"
  let effectKeys :=
    events.events.foldl (fun acc event => acc ++ event.effects.map (·.key.token)) []
  if effectKeys.length ≠ effectKeys.eraseDups.length then
    return ← reportFailure "duplicate EffectKey"
  if effectKeys.length ≠ manifest.sourceEffectCount then
    return ← reportFailure
      s!"EffectKey count {effectKeys.length} ≠ manifest {manifest.sourceEffectCount}"
  let explicitTokens :=
    eventIdTokens.filter fun token => some token == manifest.explicitSourceEventId
  if explicitTokens.length ≠ 1 then
    return ← reportFailure
      s!"explicit source EventId reuse count {explicitTokens.length} ≠ 1"
  let validityEventTokens := validity.facts.map (·.event.token)
  if validityEventTokens.length ≠ validityEventTokens.eraseDups.length then
    return ← reportFailure "more than one active validity fact for one EventId"
  for eventToken in eventIdTokens do
    if !validityEventTokens.contains eventToken then
      return ← reportFailure s!"EventId missing validity: {eventToken}"
  for fact in validity.facts do
    if !eventIdTokens.contains fact.event.token then
      return ← reportFailure s!"dangling validity event reference: {fact.event.token}"
  let factIds := validity.facts.map (·.id.token)
  if factIds.length ≠ factIds.eraseDups.length then
    return ← reportFailure "duplicate validity fact identity"
  let descriptionEventTokens := descriptions.entries.map (·.event.token)
  for eventToken in eventIdTokens do
    if !descriptionEventTokens.contains eventToken then
      return ← reportFailure s!"EventId missing description: {eventToken}"
  for desc in descriptions.entries do
    if !eventIdTokens.contains desc.event.token then
      return ← reportFailure s!"dangling description event reference: {desc.event.token}"
  let basisCoordinates := bases.bases.map QuantityBasis.coordinate
  if basisCoordinates.length ≠ (dedupCoordinates basisCoordinates).length then
    return ← reportFailure "duplicate QuantityBasis coordinate"
  let basisIds := bases.bases.map (·.id.token)
  if basisIds.length ≠ basisIds.eraseDups.length then
    return ← reportFailure "duplicate QuantityBasis identity"
  let distinctView := dedupCoordinates viewCoordinates
  if bases.bases.length ≠ distinctView.length then
    return ← reportFailure "basis coordinates do not mirror the balance view"
  for basis in bases.bases do
    if basis.quantity.quanta ≠ 0 then
      return ← reportFailure
        s!"non-zero origin basis at {basis.locus.token}: historical origin must be zero"
    if !coordinatePresent distinctView (QuantityBasis.coordinate basis) then
      return ← reportFailure
        s!"basis coordinate {basis.locus.token} not selected by balance view"
  record s!"identity invariants: {eventIdTokens.length} unique EventIds, {effectKeys.length} unique EffectKeys, 1 explicit reuse, 0 dangling references"
  -- 8. Whole-history parity (no identity text used as parity key).
  let sourceText ←
    match decodeUtf8? sourceBytes with
    | Except.error message => return ← reportFailure s!"source reparse failed: {message}"
    | Except.ok text => pure text
  let txs ←
    match parseJournal? sourceText with
    | Except.error message => return ← reportFailure s!"source reparse failed: {message}"
    | Except.ok txs => pure txs
  if txs.length ≠ events.events.length then
    return ← reportFailure "source/candidate event count divergence"
  let validityByEvent : List (String × String) :=
    validity.facts.map fun fact => (fact.event.token, fact.validOn)
  let descriptionByEvent : List (String × String) :=
    descriptions.entries.map fun desc => (desc.event.token, desc.text)
  let mut candidateCardinality : List (Nat × Nat) := []
  let mut candidateAggregates : List (String × String × Int) := []
  let mut dateDistribution : List (String × Nat) := []
  for pair in List.zip txs events.events do
    let tx := pair.1
    let event := pair.2
    if sortedPostingSignature tx ≠ sortedEffectSignature event then
      return ← reportFailure
        s!"effect parity broken at {tx.date} '{tx.description}'"
    match tx.metadata.find? (fun entry => entry.1 == "event-id") with
    | some (_, sourceToken) =>
        if event.id.token ≠ sourceToken then
          return ← reportFailure "explicit source EventId was not reused at its source occurrence"
    | none => pure ()
    match validityByEvent.find? (fun entry => entry.1 == event.id.token) with
    | none => return ← reportFailure s!"missing validity for event"
    | some (_, validOn) =>
        if validOn ≠ tx.date then
          return ← reportFailure s!"date parity broken at {tx.date}"
    match descriptionByEvent.find? (fun entry => entry.1 == event.id.token) with
    | none => return ← reportFailure s!"missing description for event"
    | some (_, text) =>
        if text ≠ tx.description then
          return ← reportFailure s!"description parity broken at {tx.date}"
    let card := tx.postings.length
    if candidateCardinality.any (fun entry => entry.1 == card) then
      candidateCardinality := candidateCardinality.map fun entry =>
        if entry.1 == card then (entry.1, entry.2 + 1) else entry
    else
      candidateCardinality := candidateCardinality ++ [(card, 1)]
    for effect in event.effects do
      candidateAggregates := candidateAggregates ++
        [(effect.locus.token, effect.amount.measure.token, effect.quantity.quanta)]
    if dateDistribution.any (fun entry => entry.1 == tx.date) then
      dateDistribution := dateDistribution.map fun entry =>
        if entry.1 == tx.date then (entry.1, entry.2 + 1) else entry
    else
      dateDistribution := dateDistribution ++ [(tx.date, 1)]
  let sortedCardinality :=
    sortList candidateCardinality (fun a b => a.1 < b.1)
  if sortedCardinality ≠ expectedCardinality then
    return ← reportFailure
      s!"posting-cardinality multiset {sortedCardinality} ≠ expected {expectedCardinality}"
  -- Event-by-event zero-sum recheck (the parser already enforces it).
  for event in events.events do
    let mut byMeasure : List (String × Int) := []
    for effect in event.effects do
      let measure := effect.amount.measure.token
      if byMeasure.any (fun entry => entry.1 == measure) then
        byMeasure := byMeasure.map fun entry =>
          if entry.1 == measure then (entry.1, entry.2 + effect.quantity.quanta) else entry
      else
        byMeasure := byMeasure ++ [(measure, effect.quantity.quanta)]
    for entry in byMeasure do
      if entry.2 ≠ 0 then
        return ← reportFailure s!"candidate event not balanced: {event.id.token}"
  -- Aggregate locus × measure parity against the source itself.
  let sourceAggregates :=
    aggregateSignature <|
      txs.foldl (fun acc tx =>
        acc ++ tx.postings.map fun posting =>
          (destinationLocus posting.account, destinationMeasure posting.measure, posting.amount)) []
  if aggregateSignature candidateAggregates ≠ sourceAggregates then
    return ← reportFailure "locus × measure aggregate parity broken"
  record s!"whole-history parity: {txs.length} events, {effectKeys.length} effects, cardinality {sortedCardinality}, {dateDistribution.length} distinct dates, aggregates match"
  -- 9. CurrentQuantity parity through the production boundary.
  let emptyBasisCorrections : Loam.Core.QuantityBasisCorrectionMemory :=
    { corrections := [], idNodup := by simp }
  for coordinate in distinctView do
    let contribution := events.quantityAtRecorded coordinate.locus coordinate.measure
    match Loam.Application.BasisCut.inspectCurrentQuantityWithBasisCut?
        events eventCorrections bases emptyBasisCorrections basisCut
        coordinate.locus coordinate.measure with
    | none => return ← reportFailure "basis-cut evidence rejected unexpectedly"
    | some (Loam.Application.CurrentQuantityAnswer.current quantity) =>
        if quantity ≠ contribution then
          return ← reportFailure
            s!"current quantity differs from historical Event contribution at {coordinate.locus.token}"
    | some other =>
        return ← reportFailure
          s!"current quantity unavailable at {coordinate.locus.token}: {repr other}"
  record s!"current quantity parity: {distinctView.length} coordinates equal historical Event contribution under explicit zero bases"
  -- Negative specimen inside verify: zero basis is explicit evidence, not
  -- an optional file. Without any basis the production boundary fails closed.
  let emptyBases ←
    match Loam.Core.QuantityBasisMemory.ofBases? [] with
    | none => return ← reportFailure "internal: empty basis memory invalid"
    | some memory => pure memory
  for coordinate in distinctView do
    match Loam.Application.BasisCut.inspectCurrentQuantityWithBasisCut?
        events eventCorrections emptyBases emptyBasisCorrections basisCut
        coordinate.locus coordinate.measure with
    | some Loam.Application.CurrentQuantityAnswer.basisMissing => pure ()
    | _ =>
        return ← reportFailure
          s!"missing basis did not fail closed at {coordinate.locus.token}"
  record "missing-basis specimen: production boundary fails closed"
  let lines ← checks.get
  for line in lines do
    IO.println s!"PASS: {line}"
  IO.println "verify: sealed PREPARED candidate qualified (authority not transferred)"
  return 0

/-! ## command dispatch -/

def run (args : List String) : IO UInt32 := do
  match args with
  | ["prepare", source, destinationRoot, bundleDir, expectedSourceSha] =>
      prepare source destinationRoot bundleDir expectedSourceSha
  | ["verify", bundleDir, source, destinationRoot] =>
      verify bundleDir source destinationRoot
  | _ => usageFail

end Loam.Cli.HistoricalPrepareCli

def main (args : List String) : IO UInt32 :=
  Loam.Cli.HistoricalPrepareCli.run args
