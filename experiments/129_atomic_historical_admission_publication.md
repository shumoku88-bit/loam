# Observation 129 — Can one-time historical admission achieve crash-consistent publication under exclusive admission?

## Question

Observation 075 established that imported identity is retained continuity information, not something that can be recomputed from mutable content or source position. Observation 076 proved that under deliberate authority transfer, external identity mappings can retire because LOAM assumes autonomous continuity authority (`no needsSourceReattachment`).

A practical migration checkpoint over the canonical household ledger (`actual.journal`) now asks the operational question:

> If LOAM admits historical occurrences without source-owned identities by issuing fresh destination-side EventId / EffectKey values, can that admission be published across physically separate persistence streams without exposing partial, dangling, or false-complete states on crash or retry?

Specifically:

1. How are fresh destination identities bounded so they do not fake source provenance or traversal-order formulas?
2. How should the single explicit source `event-id` (Tx #490) be admitted relative to anonymous occurrences?
3. Can the Event-scope description overlay remain minimal (`EventId -> Text`) without inventing an unnecessary `ContextId`?
4. How are all non-quantity source constructs classified so that "lossless" is honest?
5. How does restart recovery know the exact candidate across crashes without reissuing fresh identities?
6. Under what execution boundary (exclusive admission) does the publication protocol hold, and what is its exact commit point?

## Boundaries

### A. Fresh LOAM Identity Issuance

- Fresh `EventId` and `EffectKey` values are issued solely by the destination-side LOAM admission operation.
- They do not represent a discovery or recovery of original HRA identities.
- Source line number, occurrence date, amount, description, and content hash are strictly forbidden as occurrence identity formulas.
- Source traversal order (e.g. `event-1`, `event-2`) is not a continuity contract; identities are opaque destination-side tokens.
- Once published, LOAM holds autonomous continuity authority. No automatic reattachment to the original HRA source is contracted (`no needsSourceReattachment`).

### B. Explicit Source EventId (Candidate A)

In `actual.journal`, exactly one transaction (Tx #490) carries an explicit durable `; event-id: <40-char-hex>`, which is also referenced by `issue-relations.tsv` (`realized-as`).

Candidate A (adopting the durable source token as the admitted LOAM `EventId`, while issuing fresh tokens for anonymous occurrences) is selected because:

- It adds zero new relation streams or metadata footprint (Candidate B would require an unearned `ORIGIN_ID` production primitive).
- It preserves external reference integrity directly (`target_id` matches `EventId.token`).
- It has no effect on the post-transfer identity law: LOAM holds continuity authority regardless.

**Precondition**: Identity correctness is not left to probability. Admission explicitly verifies that the source token does not already exist in the destination `EventId` namespace prior to candidate admission.

### C. Identity-Free Description Overlay

All 558 source transactions carry a header description; zero transactions carry posting-level inline descriptions.

An independent `ContextId` is only justified if context facts themselves become targets of relations (e.g. corrections or multi-context attachments per event). Under current source pressure:

```text
EventId -> Description text
```

This identity-free 1:1 overlay is sufficient. No `ContextId` primitive is earned.

### D. Whole-Actual Lossless Classification & Source Evidence Layer

Every source construct in `actual.journal` is assigned to one of four categories:

1. **Native LOAM fact**:
   - Posting quantities, Locus, Measure (1,157 postings -> `Event`, `Effect`)
   - Occurrence dates (558 records -> `ActualValidity`)
   - Plan completion links (20 records -> `ScheduledCompletion`)
   - Explicit source `event-id` (1 record -> `EventId`, with pre-verified uniqueness)
2. **Typed application overlay**:
   - Header descriptions (558 records -> `EventId -> Description`)
3. **Migration provenance / source evidence layer**:
   - Status mark `*` (445 records -> `EventId + "status-mark" + "*"`): Retained purely as symbolic source evidence without inferring settlement or naming it `ClearedStatus`.
   - Tax category flags (38 records -> `EventId + "tax" + value`)
   - Business share flags (38 records -> `EventId + "biz" + value`)
   - Income budget anchors (3 records -> `EventId + "income-budget" + value`)
   - Plan series tags (9 records -> `EventId + "series" + value`)
   - Recurrence classifications (6 records -> `EventId + "recur" + value`)
   - External detail IDs `txn-id` (5 records -> `EventId + "txn-id" + value`)
4. **Deliberate information loss**:
   - `include accounts.journal` (1 line): Syntax directive only; LOAM deliberately excludes an Account registry.

Zero transaction facts suffer deliberate information loss. Whole-history migration is honest and lossless.

### E. Exclusive Admission Boundary & Reader Model

The publication protocol updates multiple separate files via sequential staging and renaming. It does **not** claim filesystem-level multi-file atomic transactions.

Instead, the protocol operates under an **exclusive admission boundary**:

```text
exclusive admission lock (.loam-writer-lock)
+ crash-consistent publication order
+ fail-closed reader semantics
```

Concurrent writers are excluded by writer ownership. Readers operate under fail-closed semantics: auxiliary facts referencing unpublished EventIds are inert, while Events missing validity evidence fail closed.

### F. Durable Prepared State & Crash Recovery (Resolving the Recovery Gap)

If fresh identities were generated on every restart, a crash after `EventMemory` publication would be irrecoverable, because re-running admission would generate different identities and fail to recognize the committed state.

To solve this without adding permanent sidecars, the protocol introduces a **durable PREPARED admission state** (a temporary recovery aid following Observation 076):

```text
Prepare complete candidate in memory
    ↓
Durably retain PREPARED admission state (.loam-stage / prepared-admission)
    - source snapshot fingerprint
    - base destination state fingerprint
    - exact candidate bundle (events, validities, completions, overlays)
    ↓
Publish auxiliary streams (validities, completions, overlays)
    ↓
Publish EventMemory (Canonical Commit Point)
    ↓
Publish Admission Receipt (Idempotency Commit Point)
    ↓
Retire PREPARED admission state
```

#### Crash Transitions & Restart Invariants

The restart planner inspects only durable persistent state (`receipt`, `prepared`, `events`):

- **Case 1 (Crash before PREPARED)**: `prepared = none`, `receipt = false`. Destination unchanged; restarts fresh.
- **Case 2/3 (Crash during auxiliary or before EventMemory)**: `events = baseEvents`. Resumes publication from the durable prepared candidate without reissuing identities (`ResumePreparedAuxiliary`).
- **Case 4 (Crash after EventMemory before Receipt)**: `events = candidate.events`. Verifies exact match with prepared candidate; commits receipt only without allocating duplicate events (`RecoverReceiptOnly`).
- **Case 5 (Crash after Receipt before Retirement)**: `receipt = true`, `prepared = some`. Receipt is the completion authority; retires leftover prepared aid (`CleanupLeftoverPrepared`).
- **Case 6 (Inconsistent destination state)**: `events` matches neither base nor candidate. Refuses automatic repair and **fails closed** (`FailClosedInconsistent`).

## Formal Verification (Lean 4)

The protocol, durable prepared aid, and 6 crash recovery cases are formally verified in `Loam.Observations.Observation129`:

- `auxiliary_crash_inert`: Proves that crashing after auxiliary publication leaves candidate facts inert to readers.
- `event_commit_complete`: Proves that committing `EventMemory` immediately activates all candidate validity and completion evidence.
- `restart_case4_recovers_exact_candidate`: Proves that a crash after EventMemory commit uses the durable prepared candidate to recover receipt-only without duplicate ID issuance.
- `restart_case2_resumes_prepared_candidate`: Proves that an early crash resumes from the durable prepared candidate.
- `restart_case5_cleans_up_leftover_aid`: Proves that a post-receipt crash safely retires the temporary prepared aid.
- `restart_case6_fails_closed`: Proves that an inconsistent destination state fails closed.
- `receipt_guarantees_completeness`: Proves that a committed receipt implies all candidate events, validities, and completions exist on disk.

```text
lake build
✔ [43/46] Built Loam.Observations.Observation129
✔ [44/46] Built Loam.Observations
✔ [45/46] Built Loam
Build completed successfully (46 jobs).
```

## Checkpoint

```text
Observation 129:          amended and verified with Lean 4 (all 7 safety theorems proven)
Core additions:           0
Persistence additions:    0
Wire format additions:    0
Temporary recovery aid:   durable prepared candidate with explicit retirement condition
Canonical writer:         deliberately deferred to staging rehearsal
```

Observation 129 establishes that one-time historical admission with fresh destination identities, durable prepared staging, and exclusive publication achieves crash-consistent fail-closed safety.
