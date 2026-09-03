/-
Copyright (c) 2026 LOAM contributors. All rights reserved.
Released under Apache 2.0 license.
-/

import Loam.Core.Event
import Loam.Core.EventMemory
import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.QuantityBasisMemory
import Loam.ActualDate
import Loam.Persistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.QuantityBasisPersistence
import Loam.BalanceViewConfig
import Loam.Sha256

/-!
# Historical Actual prepare / verify qualification core

One-time historical-admission dry-run support. This module prepares an exact
production-format candidate image from the sealed HRA `actual.journal` authority
source and verifies a sealed PREPARED bundle read-only. It performs no canonical
publication, no writer locking, and no admission receipt: the receipt is commit
evidence of an operation that has not happened yet.

Boundaries carried over from Observations 129 and 135:

- Fresh destination identities are opaque tokens issued solely by the
  destination-side prepare operation. Content, date, description, hash, and
  source line number are never identity formulas.
- The single explicit durable source `event-id` is admitted by exact token reuse
  (Candidate A), after verifying the token is absent from the destination
  EventId namespace.
- The source snapshot is the exact immutable byte copy; its SHA-256 binds the
  prepared candidate.
- Independent prepare runs may issue different identities. Only a sealed
  PREPARED bundle is resumed without reissuance.
-/

namespace Loam.HistoricalPrepare

open Loam.Core

set_option autoImplicit false

/-! ## ASCII string utilities

The source wire syntax (dates, status marks, indentation, metadata separators)
is ASCII. These helpers stay explicit about character-level work instead of
depending on evolving byte-slice conveniences.
-/

/-- Drop trailing ASCII whitespace characters. -/
def rtrimAscii (text : String) : String :=
  String.ofList <| (text.toList.reverse.dropWhile fun c =>
    c == ' ' || c == '\t' || c == '\r').reverse

/-- Drop leading ASCII whitespace characters. -/
def ltrimAscii (text : String) : String :=
  String.ofList <| text.toList.dropWhile fun c =>
    c == ' ' || c == '\t' || c == '\r'

/-- Drop leading and trailing ASCII whitespace characters. -/
def trimAscii (text : String) : String :=
  ltrimAscii (rtrimAscii text)

/-- Take the first `count` characters. -/
def takeChars (text : String) (count : Nat) : String :=
  String.ofList (text.toList.take count)

/-- Drop the first `count` characters. -/
def dropChars (text : String) (count : Nat) : String :=
  String.ofList (text.toList.drop count)

/-! ## Source parsing -/

/-- One source posting before identity issuance. -/
structure SourcePosting where
  account : String
  amount : Int
  measure : String
deriving Repr

/-- One source transaction before identity issuance. -/
structure SourceTx where
  date : String
  statusMark : Option String
  description : String
  metadata : List (String × String)
  postings : List SourcePosting
deriving Repr

/-- Metadata keys admitted by the whole-actual lossless classification. -/
def supportedMetadataKeys : List String :=
  ["event-id", "plan-id", "tax", "biz", "income-budget", "series", "recur", "txn-id"]

/--
Qualified adapter-local correspondence from HRA balance-bearing account tokens
to the existing production balance-view loci. Other source account-looking
tokens remain neutral Locus tokens verbatim. This is a projection renaming, not
an Account primitive or identity formula.
-/
def destinationLocus : String → String
  | "assets:cash" => "cash"
  | "assets:paypay" => "paypay"
  | "assets:smbc" => "smbc"
  | "assets:ゆうちょ" => "yucho"
  | "assets:オルカン積立" => "all-country"
  | other => other

/-- Qualified source commodity to production Measure token correspondence. -/
def destinationMeasure : String → String
  | "JPY" => "jpy"
  | "ILS" => "ils"
  | other => other

/-- Parse one signed integer amount; commas are grouping only. -/
def parseAmount? (text : String) : Option Int := do
  if text.isEmpty then none
  let (negative, digits) :=
    if text.startsWith "-" then (true, dropChars text 1) else (false, text)
  if digits.isEmpty then none
  let clean := digits.replace "," ""
  if clean.isEmpty then none
  for c in clean.toList do
    if !c.isDigit then none
  let value ← clean.toInt?
  return if negative then -value else value

private def validMeasureLikeToken (token : String) : Bool :=
  !token.isEmpty &&
    token.toList.all fun c => c.isAlphanum || c == '_'

/-- Split one indented posting line into account / amount / measure. -/
def parsePostingLine? (line : String) : Option SourcePosting := do
  let tokens :=
    (line.split (fun c => c == ' ' || c == '\t')).toList.map (·.toString) |>.filter (!·.isEmpty)
  if tokens.length < 2 then none
  let amountToken ← tokens[tokens.length - 2]?
  let hasMeasure := tokens.length ≥ 3
  let measure ←
    if hasMeasure then
      let token ← tokens[tokens.length - 1]?
      if validMeasureLikeToken token then pure token else none
    else
      pure "JPY"
  let accountTokens := tokens.take (tokens.length - (if hasMeasure then 2 else 1))
  if accountTokens.isEmpty then none
  let account := " ".intercalate accountTokens
  if !Loam.Persistence.validToken account then none
  let amount ← parseAmount? amountToken
  return { account := account, amount := amount, measure := measure }

/-- Split one indented metadata comment line into key / value. -/
def parseMetadataLine? (line : String) : Option (String × String) := do
  let trimmed := trimAscii line
  if !trimmed.startsWith ";" then none
  let body := dropChars trimmed 1
  match body.splitOn ":" with
  | [] => none
  | parts =>
      let key ←
        match parts.head? with
        | none => none
        | some head => pure (trimAscii head)
      let value := trimAscii (":".intercalate (parts.drop 1))
      if key.isEmpty then none else some (key, value)

/-- Parse one transaction header line into date / status mark / description. -/
def parseHeaderLine? (line : String) : Except String (String × Option String × String) := do
  let chars := line.toList
  if chars.length < 10 then
    throw s!"malformed transaction header: {line}"
  let date := String.ofList (chars.take 10)
  if !Loam.ActualDate.validIsoDate date then
    throw s!"invalid source date in header: {line}"
  let rest := trimAscii (dropChars line 10)
  if rest == "*" then
    return (date, some "*", "")
  else if rest.startsWith "*" then
    let tail := dropChars rest 1
    if tail.startsWith " " then
      return (date, some "*", trimAscii (dropChars tail 1))
    else
      return (date, none, rest)
  else
    return (date, none, rest)

/--
Parse the exact source bytes (already decoded as one String) into source
transactions, failing closed on any unsupported construct.
-/
def parseJournal? (text : String) : Except String (List SourceTx) := do
  let mut txs : List SourceTx := []
  let mut current : Option SourceTx := none
  for rawLine in text.splitOn "\n" do
    let line := rtrimAscii rawLine
    if line.isEmpty || line.startsWith "include " then
      continue
    if line.startsWith " " || line.startsWith "\t" then
      match current with
      | none => throw s!"unexpected indented line before first header: {line}"
      | some tx =>
          let trimmed := trimAscii line
          if trimmed.startsWith ";" then
            match parseMetadataLine? trimmed with
            | none => throw s!"malformed metadata line: {line}"
            | some (key, value) =>
                if !supportedMetadataKeys.contains key then
                  throw s!"unsupported metadata key '{key}': {line}"
                current := some { tx with metadata := tx.metadata ++ [(key, value)] }
          else
            match parsePostingLine? line with
            | none => throw s!"malformed source posting: {line}"
            | some posting =>
                current := some { tx with postings := tx.postings ++ [posting] }
    else
      -- Flush the previous transaction.
      if let some tx := current then
        txs := txs ++ [tx]
      match parseHeaderLine? line with
      | Except.error message => throw message
      | Except.ok (date, statusMark, description) =>
          current := some {
            date := date
            statusMark := statusMark
            description := description
            metadata := []
            postings := []
          }
  if let some tx := current then
    txs := txs ++ [tx]
  -- Structural validation: zero balance per measure, metadata cardinalities.
  for tx in txs do
    let mut balances : List (String × Int) := []
    for posting in tx.postings do
      if balances.any (fun entry => entry.1 == posting.measure) then
        balances := balances.map fun entry =>
          if entry.1 == posting.measure then
            (entry.1, entry.2 + posting.amount)
          else
            entry
      else
        balances := balances ++ [(posting.measure, posting.amount)]
    for entry in balances do
      if entry.2 ≠ 0 then
        throw s!"unbalanced source event for {entry.1} (sum = {entry.2}) on {tx.date}"
    let eventIdRows := tx.metadata.filter fun entry => entry.1 == "event-id"
    if eventIdRows.length > 1 then
      throw s!"multiple event-id metadata entries on {tx.date}"
    let planIdRows := tx.metadata.filter fun entry => entry.1 == "plan-id"
    if planIdRows.length > 1 then
      throw s!"multiple plan-id metadata entries on {tx.date}"
    if tx.postings.isEmpty then
      throw s!"source event without postings on {tx.date}"
  return txs

/-- Source-side facts extracted during parse, before identity issuance. -/
structure SourceStats where
  eventCount : Nat
  effectCount : Nat
  completionCandidates : Nat
  explicitSourceEventIds : List String
deriving Repr

def sourceStats (txs : List SourceTx) : Except String SourceStats := do
  let mut seen : List String := []
  let mut explicit : List String := []
  let mut completions : Nat := 0
  for tx in txs do
    for entry in tx.metadata do
      if entry.1 == "event-id" then
        if seen.contains entry.2 then
          throw s!"duplicate source event-id: {entry.2}"
        seen := seen ++ [entry.2]
        explicit := explicit ++ [entry.2]
      if entry.1 == "plan-id" then
        completions := completions + 1
  return {
    eventCount := txs.length
    effectCount := (txs.map fun tx => tx.postings.length).foldl (· + ·) 0
    completionCandidates := completions
    explicitSourceEventIds := explicit
  }

/-! ## Opaque destination identity issuance -/

/-- One SplitMix64 step: returns (output, next state). -/
def splitmix64 (state : UInt64) : UInt64 × UInt64 :=
  let next := state + 0x9E3779B97F4A7C15
  let z1 := (next ^^^ (next >>> 30)) * 0xBF58476D1CE4E5B9
  let z2 := (z1 ^^^ (z1 >>> 27)) * 0x94D049BB133111EB
  (z2 ^^^ (z2 >>> 31), next)

private def hexDigit (n : UInt64) : Char :=
  if n < 10 then Char.ofNat (48 + n.toNat) else Char.ofNat (87 + n.toNat)

def hexOfUInt64 (value : UInt64) : String :=
  (List.range 16).foldl (fun out i =>
    let shift := (15 - i).toUInt64 * 4
    out.push (hexDigit ((value >>> shift) &&& 0xf))) ""

/--
Issue one opaque destination token and advance the generator state. Tokens are
32 random hex characters under a stable prefix and are never derived from
source content, date, description, hash, or line number.
-/
def nextOpaqueToken (stem : String) (state : UInt64) : String × UInt64 :=
  let (v1, s1) := splitmix64 state
  let (v2, s2) := splitmix64 s1
  (stem ++ hexOfUInt64 v1 ++ hexOfUInt64 v2, s2)

/-! ## Candidate construction -/

/-- The complete production-format candidate image prepared from one source read. -/
structure CandidateBundle where
  eventMemory : EventMemory
  validityHistory : ActualValidityHistory String
  descriptionMemory : EventDescriptionMemory
  basisMemory : QuantityBasisMemory
  explicitReusedTokens : List String

/--
Build the candidate image from parsed source transactions.

Fresh destination identities are issued from the seeded generator; the single
explicit source `event-id` is admitted by exact token reuse after collision
checking against `destinationEventTokens`.
-/
def buildCandidate
    (txs : List SourceTx)
    (destinationEventTokens : List String)
    (viewCoordinates : List EffectCoordinate)
    (seed : UInt64) : Except String CandidateBundle := do
  let mut rngState := seed
  let mut events : List Event := []
  let mut facts : List (ActualValidityFact String) := []
  let mut descriptions : List EventDescription := []
  let mut seenEventIds : List String := []
  let mut seenEffectKeys : List String := []
  let mut seenFactIds : List String := []
  let mut reused : List String := []
  for tx in txs do
    let eventIdToken ←
      match tx.metadata.find? (fun entry => entry.1 == "event-id") with
      | none =>
          let (token, nextState) := nextOpaqueToken "hpev-" rngState
          rngState := nextState
          pure token
      | some (_, token) =>
          if !Loam.Persistence.validToken token then
            throw s!"explicit source event-id is not a valid token: {token}"
          if destinationEventTokens.contains token then
            throw s!"explicit source event-id collides with destination EventId: {token}"
          reused := reused ++ [token]
          pure token
    if destinationEventTokens.contains eventIdToken then
      throw s!"candidate EventId collides with destination EventId: {eventIdToken}"
    if seenEventIds.contains eventIdToken then
      throw s!"duplicate candidate event identity: {eventIdToken}"
    seenEventIds := seenEventIds ++ [eventIdToken]
    let mut effects : List Effect := []
    for posting in tx.postings do
      let (effectKey, nextState) := nextOpaqueToken "hpef-" rngState
      rngState := nextState
      if seenEffectKeys.contains effectKey then
        throw s!"duplicate candidate effect identity: {effectKey}"
      seenEffectKeys := seenEffectKeys ++ [effectKey]
      effects := effects ++
        [Effect.ofQuantity ⟨effectKey⟩ ⟨destinationLocus posting.account⟩
          ⟨destinationMeasure posting.measure⟩ (Quantity.ofQuanta posting.amount)]
    match Event.ofEffects? ⟨eventIdToken⟩ effects with
    | none => throw "internal: repeated effect key inside one event"
    | some event => events := events ++ [event]
    let (factId, nextState) := nextOpaqueToken "hpvf-" rngState
    rngState := nextState
    if seenFactIds.contains factId then
      throw s!"duplicate validity fact identity: {factId}"
    seenFactIds := seenFactIds ++ [factId]
    facts := facts ++ [{ id := ⟨factId⟩, event := ⟨eventIdToken⟩, validOn := tx.date }]
    descriptions := descriptions ++ [{ event := ⟨eventIdToken⟩, text := tx.description }]
  -- Zero origin bases: one fresh generation-owned fact per balance-view
  -- coordinate, derived from the destination view config, not hardcoded.
  let mut bases : List QuantityBasis := []
  let mut basisCoordinates : List EffectCoordinate := []
  let mut seenBasisIds : List String := []
  for coordinate in viewCoordinates do
    if basisCoordinates.any (fun known => decide (known = coordinate)) then
      continue
    basisCoordinates := basisCoordinates ++ [coordinate]
    let (basisId, nextState) := nextOpaqueToken "hpb-" rngState
    rngState := nextState
    if seenBasisIds.contains basisId then
      throw s!"duplicate basis identity: {basisId}"
    seenBasisIds := seenBasisIds ++ [basisId]
    bases := bases ++
      [QuantityBasis.ofQuantity ⟨basisId⟩ coordinate.locus coordinate.measure
        Quantity.zero]
  let eventMemory ←
    match EventMemory.ofEvents? events with
    | none => throw "internal: repeated EventId across candidate"
    | some memory => pure memory
  let validityHistory ←
    match ActualValidityHistory.ofParts? facts [] with
    | none => throw "internal: invalid validity history"
    | some history => pure history
  let descriptionMemory ←
    match EventDescriptionMemory.ofEntries? descriptions with
    | none => throw "internal: repeated description EventId"
    | some memory => pure memory
  let basisMemory ←
    match QuantityBasisMemory.ofBases? bases with
    | none => throw "internal: invalid basis memory"
    | some memory => pure memory
  return {
    eventMemory := eventMemory
    validityHistory := validityHistory
    descriptionMemory := descriptionMemory
    basisMemory := basisMemory
    explicitReusedTokens := reused
  }

/-! ## Manifest -/

/-- Names of the destination base files fingerprinted into the manifest. -/
def destinationBaseFileNames : List String := [
  "memory.loam",
  "memory.loam.actual-validity",
  "memory.loam.descriptions",
  "corrections.loam",
  "basis.loam",
  "basis-cut.tsv",
  "basis-corrections.loam",
  "scheduled.loam",
  "scheduled.loam.completions",
  "balance-view.tsv"
]

def manifestHeader : String := "LOAM-HISTORICAL-PREPARE-MANIFEST\t1"

/-- One sealed PREPARED manifest. No admission receipt: the transfer has not happened. -/
structure Manifest where
  preparedAt : String
  sourcePath : String
  sourceSha256 : String
  sourceBytes : Nat
  sourceEventCount : Nat
  sourceEffectCount : Nat
  sourceCompletionCandidates : Nat
  explicitSourceEventId : Option String
  destinationRoot : String
  destBase : List (String × String × String)
  candidates : List (String × Nat × String)
deriving Repr

def encodeManifest (manifest : Manifest) : String :=
  let fixedLines := [
    manifestHeader,
    s!"PREPARED-AT\t{manifest.preparedAt}",
    s!"SOURCE-PATH\t{manifest.sourcePath}",
    s!"SOURCE-SHA256\t{manifest.sourceSha256}",
    s!"SOURCE-BYTES\t{manifest.sourceBytes}",
    s!"SOURCE-EVENT-COUNT\t{manifest.sourceEventCount}",
    s!"SOURCE-EFFECT-COUNT\t{manifest.sourceEffectCount}",
    s!"SOURCE-COMPLETION-CANDIDATES\t{manifest.sourceCompletionCandidates}",
    s!"EXPLICIT-SOURCE-EVENT-ID\t{manifest.explicitSourceEventId.getD "ABSENT"}",
    s!"DESTINATION-ROOT\t{manifest.destinationRoot}"
  ]
  let baseLines := manifest.destBase.map fun entry =>
    s!"DEST-BASE\t{entry.1}\t{entry.2.1}\t{entry.2.2}"
  let candidateLines := manifest.candidates.map fun entry =>
    s!"CANDIDATE\t{entry.1}\t{entry.2.1}\t{entry.2.2}"
  let diagnostic :=
    s!"EXPECTED-RECEIPT-INPUT-DIAGNOSTIC\tsource-sha256={manifest.sourceSha256};admitted-event-count={manifest.sourceEventCount}"
  "\n".intercalate (fixedLines ++ baseLines ++ candidateLines ++ [diagnostic]) ++ "\n"

private def parseNat? (text : String) : Option Nat :=
  if text.isEmpty || !text.toList.all Char.isDigit then none
  else String.toNat? text

/-- Parse a sealed manifest, failing closed on unknown or malformed rows. -/
def parseManifest? (input : String) : Except String Manifest := do
  match input.splitOn "\n" with
  | header :: rows =>
      if header ≠ manifestHeader then
        throw "manifest header mismatch"
      let rows := match rows.reverse with
        | "" :: rest => rest.reverse
        | other => other
      let mut preparedAt := ""
      let mut sourcePath := ""
      let mut sourceSha256 := ""
      let mut sourceBytes : Option Nat := none
      let mut eventCount : Option Nat := none
      let mut effectCount : Option Nat := none
      let mut completionCandidates : Option Nat := none
      let mut explicitId : Option String := none
      let mut destinationRoot := ""
      let mut destBase : List (String × String × String) := []
      let mut candidates : List (String × Nat × String) := []
      let mut sawPreparedAt := false
      let mut sawSourcePath := false
      let mut sawSha := false
      let mut sawDestinationRoot := false
      for row in rows do
        match row.splitOn "\t" with
        | ["PREPARED-AT", value] => preparedAt := value; sawPreparedAt := true
        | ["SOURCE-PATH", value] => sourcePath := value; sawSourcePath := true
        | ["SOURCE-SHA256", value] => sourceSha256 := value; sawSha := true
        | ["SOURCE-BYTES", value] =>
            sourceBytes := parseNat? value
        | ["SOURCE-EVENT-COUNT", value] =>
            eventCount := parseNat? value
        | ["SOURCE-EFFECT-COUNT", value] =>
            effectCount := parseNat? value
        | ["SOURCE-COMPLETION-CANDIDATES", value] =>
            completionCandidates := parseNat? value
        | ["EXPLICIT-SOURCE-EVENT-ID", value] =>
            explicitId := if value == "ABSENT" then none else some value
        | ["DESTINATION-ROOT", value] =>
            destinationRoot := value; sawDestinationRoot := true
        | ["DEST-BASE", name, sha, bytes] =>
            destBase := destBase ++ [(name, sha, bytes)]
        | ["CANDIDATE", path, bytes, sha] =>
            match parseNat? bytes with
            | none => throw s!"malformed CANDIDATE bytes: {row}"
            | some byteCount => candidates := candidates ++ [(path, byteCount, sha)]
        | ["EXPECTED-RECEIPT-INPUT-DIAGNOSTIC", _value] => pure ()
        | _ => throw s!"malformed or unknown manifest row: {row}"
      if !sawPreparedAt then throw "manifest missing PREPARED-AT"
      if !sawSourcePath then throw "manifest missing SOURCE-PATH"
      if !sawSha then throw "manifest missing SOURCE-SHA256"
      if !sawDestinationRoot then throw "manifest missing DESTINATION-ROOT"
      let byteCount ←
        match sourceBytes with
        | none => throw "manifest missing or malformed SOURCE-BYTES"
        | some value => pure value
      let eventValue ←
        match eventCount with
        | none => throw "manifest missing or malformed SOURCE-EVENT-COUNT"
        | some value => pure value
      let effectValue ←
        match effectCount with
        | none => throw "manifest missing or malformed SOURCE-EFFECT-COUNT"
        | some value => pure value
      let completionValue ←
        match completionCandidates with
        | none => throw "manifest missing or malformed SOURCE-COMPLETION-CANDIDATES"
        | some value => pure value
      if destBase.map (·.1) ≠ destinationBaseFileNames then
        throw "manifest DEST-BASE rows do not cover the exact destination base file set"
      if candidates.isEmpty then
        throw "manifest carries no CANDIDATE rows"
      return {
        preparedAt := preparedAt
        sourcePath := sourcePath
        sourceSha256 := sourceSha256
        sourceBytes := byteCount
        sourceEventCount := eventValue
        sourceEffectCount := effectValue
        sourceCompletionCandidates := completionValue
        explicitSourceEventId := explicitId
        destinationRoot := destinationRoot
        destBase := destBase
        candidates := candidates
      }
  | [] => throw "empty manifest"

/-! ## Small fingerprint and time helpers -/

/-- Read one file exactly once and fingerprint those exact bytes. -/
def fingerprintFile?
    (path : System.FilePath) : IO (Option (ByteArray × String)) := do
  if ← path.pathExists then
    let bytes ← IO.FS.readBinFile path
    return some (bytes, Loam.Sha256.hash bytes)
  else
    return none

/-- Render epoch seconds as a UTC date-time stamp (proleptic Gregorian). -/
def utcStampOfEpochSeconds (seconds : UInt64) : String :=
  let days : Nat := (seconds / 86400).toNat
  let rem : Nat := (seconds % 86400).toNat
  let hour := rem / 3600
  let minute := (rem % 3600) / 60
  let second := rem % 60
  -- Days since 1970-01-01 to calendar date via 400-year cycles.
  let z := days + 719468
  let era := z / 146097
  let doe := z % 146097
  let yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y := yoe + era * 400
  let doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp := (5 * doy + 2) / 153
  let d := doy - (153 * mp + 2) / 5 + 1
  let m := if mp < 10 then mp + 3 else mp - 9
  let year := if m ≤ 2 then y + 1 else y
  let pad2 (n : Nat) : String := if n < 10 then "0" ++ toString n else toString n
  s!"{year}-{pad2 m}-{pad2 d}T{pad2 hour}:{pad2 minute}:{pad2 second}Z"

end Loam.HistoricalPrepare
