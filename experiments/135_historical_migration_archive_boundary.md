# Observation 135 — Minimal boundary for Historical Migration Archive

## Question

In the historical migration staging rehearsal, 544 non-canonical source evidence items (`status-mark`: 445, `tax`: 38, `biz`: 38, `series`: 9, `recur`: 6, `txn-id`: 5, `income-budget`: 3) were parsed into:

```text
EventId + source evidence key + exact value
```

This observation investigates whether persisting this evidence requires an independent parsed archive wire format (Candidate A), or whether an exact immutable source snapshot bound by an admission receipt (Candidate B) is sufficient and strictly smaller.

## Three Candidates Evaluated

### Candidate A: Parsed Evidence Archive
- **Structure**: Dedicated archive stream storing 544 records of `EventId + key + value`.
- **Pros**: Direct key/event inspection.
- **Cons**:
  - Requires inventing a new archive persistence format and encoder/decoder.
  - Loses source lexical structure (comments, formatting, whitespace, tag ordering).
  - Re-introduces a generic metadata schema on the archive side, bloating LOAM's boundary.

### Candidate B: Exact Source Snapshot Archive (Selected / Best)
- **Structure**:
  ```text
  <dataDir>/historical-admission/
    actual.journal.snapshot   (exact immutable byte copy)
    admission-receipt         (snapshot SHA-256, eventCount, timestamp)
  ```
- **Pros**:
  - **Bit-for-bit lossless**: 100% preserves exact source bytes, comments, formatting, and tag order without reinterpretation.
  - **Zero generic metadata**: LOAM Core and Persistence create zero generic metadata primitives.
  - **Clean canonical facts**: Active LOAM memory holds only earned typed facts (Event, Validity, Description, ScheduledCompletion).
  - **Self-contained**: Physically stored inside LOAM's data boundary; zero ongoing dependency on external Git repos.
  - **Zero-cost data diet**: Unneeded evidence is never admitted into canonical truth; retiring an item requires zero canonical schema migration.
  - **Future promotion ready**: If a typed overlay (e.g. Tax / Business Share) is earned later, it can be extracted deterministically from the snapshot.
- **Cons**: Archive is not indexed for O(1) household queries (which is correct, as daily queries should only touch canonical facts).

### Candidate C: Snapshot + Parsed Index
- **Structure**: Exact snapshot plus permanent parsed index.
- **Evaluation**: Unearned. In the absence of daily query demand, maintaining an on-disk index is redundant because any required projection can be derived deterministically on demand in milliseconds from a 100 KB snapshot.

## Seven Core Findings

### 1. Four Independent Authorities Separated
- **Canonical query authority**: Active household facts (`EventMemory`, `ActualValidityHistory`, `EventDescriptionMemory`, `ScheduledCompletionMemory`). Archive has zero authority here.
- **Immutable provenance**: Physical source snapshot bytes + receipt SHA-256 proving the historical origin.
- **Migration recovery aid**: Temporary `PREPARED` admission state (Observation 129), retired upon receipt commit.
- **Future semantic promotion source**: Raw evidence quiescent in the snapshot, awaiting formal overlay qualification.

### 2. Derived Extraction Is Deterministic (No Parsed Archive Needed)
`actual.journal` contains 558 transactions across ~2,800 lines (~100 KB). Any future extraction of `tax` (38 items) or `biz` (38 items) runs in <5 ms. Storing a parsed copy permanently adds zero information beyond the snapshot itself.

### 3. Canonical Data Diet by Construction
Rather than admitting 544 items into canonical truth and later executing complex "data diet migrations", Candidate B keeps canonical truth lean from day 1:
```text
[Day 1 Admission]
  Canonical facts: 558 Events, 558 Validities, 558 Descriptions, 20 Completions (Zero metadata bloat)
  Archive: actual.journal.snapshot (quiescent raw evidence)

[Future Necessity Qualified]
  immutable snapshot ──qualified extraction──> typed Tax/Biz overlay

[Future Necessity Rejected]
  No canonical schema change or data migration required (zero-cost diet).
```

### 4. Canonical Facts vs Immutable Provenance
```text
canonical LOAM facts  !=  immutable historical admission provenance
```
The snapshot is a sealed historical artifact of a completed authority transfer, not active double-entry records.

### 5. No Ongoing Dependency on External Repositories
Storing only an external Git commit SHA would make LOAM's provenance vulnerable to external repository availability, force-pushes, or access revocations. Physical inclusion of `actual.journal.snapshot` inside LOAM's data boundary guarantees complete, self-contained authority transfer.

### 6. Source Formatting Preservation
Exact byte preservation retains syntax, whitespace, and comments without needing additional observations to prove whether formatting was redundant.

### 7. Self-Contained Admission Unit (`actual.journal` Alone)
All 544 source evidence items reside entirely within `actual.journal`. The 20 `plan-id` references are fully represented as `ScheduledCompletion` in LOAM canonical memory. Archiving `actual.journal.snapshot` is completely self-contained; archiving the other 7 files of the external household repository is unearned.

## Formal Verification (Lean 4)

Formally verified in `Loam.Observations.Observation135`:
- `canonical_quantity_invariant_under_archive`: Core balance calculations are invariant under the presence or absence of the archive snapshot.
- `derived_evidence_uniquely_determined`: Given exact snapshot bytes, derived evidence projections are uniquely determined.
- `unpromoted_evidence_absent_from_canonical_query`: Unpromoted evidence is absent from canonical query projections by construction.

```text
lake build
✔ [48/51] Built Loam.Observations.Observation135
✔ [49/51] Built Loam.Observations
✔ [50/51] Built Loam
Build completed successfully (51 jobs).
```

## Conclusion

```text
========================================================================
 active canonical facts:          SMALL
   - EventMemory (558 Events, 1,157 Effects)
   - ActualValidityHistory (558 dates)
   - EventDescriptionMemory (558 descriptions)
   - ScheduledCompletionMemory (20 links)
   -> Zero generic metadata bloat

 historical admission provenance: LOSSLESS
   - actual.journal.snapshot (exact immutable bytes, 544 evidence items)
   - admission-receipt (SHA-256 fingerprint, event count, timestamp)
   -> 100% self-contained, zero external Git dependency

 future promotion source:         RETAINED
   - Deterministic extraction on demand when typed overlay is qualified

 generic metadata ontology:       ABSENT
   - No new generic metadata primitives or complex archive schemas
========================================================================
```

Candidate B (`exact immutable source snapshot + small admission receipt`) is the minimal, sound, and lossless boundary for the Historical Migration Archive.
