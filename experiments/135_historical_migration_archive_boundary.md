# Observation 135 — Minimal boundary for Historical Migration Archive (Amended)

## Question

In the historical migration staging rehearsal, 544 non-canonical source evidence items (`status-mark`: 445, `tax`: 38, `biz`: 38, `series`: 9, `recur`: 6, `txn-id`: 5, `income-budget`: 3) were observed.

This observation examines whether persisting this evidence requires an independent parsed archive wire format (Candidate A), or whether an exact immutable source snapshot bound by an admission receipt (Candidate B) is sufficient:

> What is the minimal, sound boundary for historical source provenance that preserves all Actual-local evidence without prematurely bloating canonical LOAM facts or asserting unearned semantic self-containment?

## Three Candidates Evaluated

### Candidate A: Parsed Evidence Archive
- **Structure**: Dedicated archive stream storing 544 records of `EventId + key + value`.
- **Pros**: Direct key/event inspection.
- **Cons**:
  - Requires inventing a new archive persistence format and parser/encoder.
  - Loses source lexical structure (comments, formatting, whitespace, tag ordering).
  - Re-introduces a generic metadata schema on the archive side, bloating LOAM's boundary.

### Candidate B: Exact Source Snapshot Archive (Selected / Minimal)
- **Structure**:
  ```text
  <dataDir>/historical-admission/
    actual.journal.snapshot   (exact immutable byte copy)
    admission-receipt         (snapshot fingerprint, event count, timestamp)
  ```
- **Pros**:
  - **Bit-for-bit lexical preservation**: 100% preserves exact source bytes, comments, formatting, and tag order of Actual-local evidence.
  - **Zero generic metadata**: LOAM Core and Persistence create zero generic metadata primitives.
  - **Clean canonical facts**: Active LOAM memory holds only earned typed facts (Event, Validity, Description, ScheduledCompletion).
  - **Self-contained provenance**: Physically stored inside LOAM's data boundary; zero ongoing dependency on external Git repos.
  - **Zero-cost data diet**: Unneeded evidence is never admitted into canonical truth; retiring an item requires zero canonical schema migration.
- **Cons**: Archive is not indexed for O(1) household queries (which is correct, as daily queries should only touch canonical facts).

### Candidate C: Snapshot + Parsed Index
- **Structure**: Exact snapshot plus permanent parsed index.
- **Evaluation**: Unearned. In the absence of daily query demand, maintaining an on-disk index is redundant.

## Core Findings & Clarified Boundaries

### 1. Actual-Local Lexical Preservation vs Future Semantic Closure
We distinguish two very different claims:

```text
[Earned]
exact actual.journal snapshot
    => complete lexical preservation of Actual-local source evidence

[Not Earned / Currently Unknown]
exact actual.journal snapshot
    => every future semantic promotion is self-contained
```

The 544 key/value raw textual pairs originate within `actual.journal`. Preserving `actual.journal.snapshot` guarantees 100% lexical preservation of this Actual-local evidence.

However, if future household operations qualify typed semantic facts (e.g. promoting `tax`, `biz`, or `series`), interpreting their full semantic authority may require cross-file historical context (e.g. Plan definitions, historical business allocation rules, budget policies).

Therefore, Observation 135 establishes:
- **Actual-local provenance minimum**: `actual.journal` exact snapshot.
- **Future semantic promotion dependency closure**: Currently unknown. When (and if) an overlay is earned, its historical dependencies will be observed empirically. We do not prematurely swallow all 8 files of the external repository.

### 2. Distinct Roles of Snapshot Bytes vs Receipt Digest
A cryptographic digest cannot reconstruct source bytes. Their roles are strictly partitioned:
- `snapshot bytes`: The immutable physical material for future extraction.
- `SHA-256(snapshot bytes)`: The integrity and receipt binding evidence proving that the preserved snapshot matches the bytes admitted at migration time.

### 3. Binding Invariants of HistoricalAdmissionReceipt
To ensure the receipt is not an unconstrained, detached comment, the formal model binds the receipt to both the snapshot and the admitted canonical state:
```lean
structure HistoricalAdmissionReceipt (snapshot : ByteArray) (state : AdmittedHouseholdState) where
  snapshotFingerprint : Digest
  admittedEventCount : Nat
  receiptTimestamp : String
  fingerprintBound : snapshotFingerprint = fingerprint snapshot
  eventCountBound : admittedEventCount = state.events.events.length
```
This guarantees by construction that:
1. The fingerprint in the receipt strictly matches the recomputed fingerprint of the enclosed snapshot bytes.
2. The admitted event count in the receipt strictly equals the actual number of Events admitted into canonical `EventMemory`.

### 4. Separation of Four Authorities
```text
canonical query authority:        EventMemory, ActualValidityHistory, EventDescriptionMemory, ScheduledCompletionMemory
immutable provenance:             sealed snapshot bytes + bound receipt
migration recovery aid:           temporary PREPARED state (retired on receipt commit)
future semantic promotion source: raw evidence quiescent in the snapshot
```
Ordinary household queries observe strictly canonical state; they do not accept, require, or observe the archive package.

### 5. Parsed Archive Redundancy as a Design Finding
`actual.journal` contains 558 transactions (~100 KB). Storing a secondary parsed copy of the 544 evidence items adds zero source information beyond the snapshot itself, while creating an unwanted generic metadata schema in LOAM. Any future extraction can be performed deterministically on demand.

### 6. No Ongoing Dependency on External Repositories
Storing only an external Git commit SHA would leave LOAM's provenance vulnerable to external repository availability. Physical inclusion of `actual.journal.snapshot` inside LOAM's data boundary makes the retained Actual-local admission provenance self-contained and removes ongoing dependency on the external repository.

## Formal Verification (Lean 4)

Formally verified in `Loam.Observations.Observation135`:
- `canonical_quantity_invariant_under_archive`: Proves canonical quantity projections take strictly `AdmittedHouseholdState` and do not observe or depend upon the archive package.
- `receipt_strictly_binds_snapshot_and_state`: Proves that the archive's receipt strictly binds the fingerprint of the snapshot and the event count of the canonical state.
- `extractor_reproducible`: Proves that applying a deterministic extractor to identical snapshot bytes yields identical extracted evidence.

```text
lake build
✔ [48/51] Built Loam.Observations.Observation135
✔ [49/51] Built Loam.Observations
✔ [50/51] Built Loam
Build completed successfully (51 jobs).
```

## Checkpoint

```text
========================================================================
 active canonical facts:          SMALL
   - EventMemory (558 Events, 1,157 Effects)
   - ActualValidityHistory (558 dates)
   - EventDescriptionMemory (558 descriptions)
   - ScheduledCompletionMemory (20 links)

 historical admission provenance: LOSSLESS (Actual-local lexical)
   - actual.journal.snapshot (100% exact bytes, 544 evidence items)
   - admission-receipt (fingerprint strictly bound to snapshot, event count bound to state)
   - Semantic promotion closure: explicitly deferred / currently unknown

 future promotion source:         RETAINED
   - Raw source text available inside snapshot; zero canonical bloat

 generic metadata ontology:       ABSENT
   - No new generic metadata schemas in LOAM
========================================================================
```
