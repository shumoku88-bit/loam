# Observation 130 — Does real historical admission pressure earn an Event-scoped descriptive evidence primitive?

## Question

Observation 072 established that human descriptive context (merchant, place, purpose, category, note) must not be overloaded onto Core `Locus` or `EventId`, and did not earn those domain primitives. Observation 073 established that Event-scoped context and Effect-scoped context are orthogonal and independently observable, without earning a generic Practical Core `Context` framework.

The rehearsal over all 558 canonical household transactions (`actual.journal`) introduces concrete operational pressure:

- All 558 historical events carry an Event-scoped header text (100%).
- Posting-level (Effect-scoped) descriptive text is exactly 0 (0%).
- Dropping this text loses human recognition of past transactions.

This observation examines:

> Does this real historical admission pressure earn an Event-scoped descriptive evidence primitive in LOAM, or is a migration archive sufficient? What is the minimal semantic shape, name, and authority of this evidence?

## Analysis of 558 Real Header Texts

An audit of the 558 actual header descriptions reveals an unqualified, multifaceted mixture of human recognition intents:

- **Merchant Category / Channel**: `コンビニ` (147 occurrences), `自動販売機` (50 occurrences)
- **Specific Merchant**: `三和` (18 occurrences), `東急ストア` (1 occurrence), `ダイソー` (1 occurrence)
- **Commodity / Item**: `缶コーヒー` (32 occurrences), `タバコ` (29 occurrences), `食品` (7 occurrences), `お菓子` (1 occurrence)
- **Transfer / Operation Memo**: `smbc→paypay` (21 occurrences), `assets:smbc→assets:paypay` (8 occurrences)
- **Obligation / Purpose**: `健康保険料(6月分)` (1 occurrence), `健康保険料(滞納分)` (1 occurrence), `pasmoチャージ` (19 occurrences)
- **Counterparty / Context**: `友人kから交通費精算` (5 occurrences)
- **Accounting Inception**: `Opening Balance` (2 occurrences), `借金開始残高...` (1 occurrence)

The text is neither a pure `Merchant`, nor a pure `Purpose`, nor a pure `Note`, nor an `Item`. It is an **unqualified human recognizer phrase** attached to the Event.

## Six Core Inquiries

### 1. Active Household Query vs Migration Archive

If this text were relegated solely to a migration archive outside LOAM canonical persistence:

- Identical-amount purchases on the same date at the same locus (e.g., three separate 160 JPY cash transactions on 2026-07-15) would become indistinguishable to the household.
- Daily household queries ("Did I pay the June health insurance?", "How much did I spend at Sanwa last month?", "What was this 160 JPY cash spend?") would fail closed or return uninterpretable numeric vectors.
- Therefore, this text is not mere archival provenance. It is **active retained evidence** that directly determines the answers to everyday household recognition, display, and query operations.

### 2. Sufficiency of `EventId -> String`

- In all 558 transactions, there is exactly one header string per transaction.
- There are zero delimiters, multi-attribute tuples, or structured sub-fields.
- Mathematically, an identity-free partial map `EventId -> String` (enforced via unique `EventId` within the collection) is minimal and sufficient.

### 3. ContextId Is Unearned

An independent `ContextId` is only earned if:
1. One Event holds multiple independent context facts.
2. Context facts themselves become targets of relations (corrections, resolution, replacements).
3. Context facts have independent lifecycle from Events.

Under current pressure, none of these conditions hold. Introducing `ContextId` would violate the principle of parsimony.

### 4. Effect-Scope Description Is Unearned

With 0 out of 1,157 postings carrying descriptive text, there is zero empirical pressure for Effect-scope text. Following Observation 073, Event-scope and Effect-scope remain orthogonal; Effect-scope description is deliberately omitted from production.

### 5. Candidate Naming Comparison

| Candidate | Semantic Implication | Evaluation |
| --- | --- | --- |
| **A. `EventDescription`** | Unqualified descriptive text attached to an Event | **Best fit**. Universally established in double-entry bookkeeping (ledger, hledger, beancount) for 30+ years without claiming specific Merchant/Purpose ontologies. Neutral when defined as unqualified text. |
| **B. `EventLabel`** | Tag or short category token | Misleading. Suggests taxonomy/category rather than full phrases like `借金開始残高（2026-06-19確認残高から返済2件を復元）` (55 chars). |
| **C. `EventAnnotation`** | Supplementary commentary / footnote | Subordinate tone contradicts the fact that this text is the primary human face of the transaction. |
| **D. Migration Archive Only** | External historical provenance | Fails inquiry #1 (leaves everyday household queries blind). |

**Conclusion**: `EventDescription { event : EventId, text : String }` is the minimal, honest name, provided its definition explicitly disclaims Merchant/Purpose qualification.

### 6. Historical Source Evidence (544 items) & The Canonical Data Diet

The remaining 544 source evidence items (`status-mark`: 445, `tax`: 38, `biz`: 38, `series`: 9, `recur`: 6, `txn-id`: 5, `income-budget`: 3) are treated differently:

- They are **NOT** promoted to generic metadata or canonical LOAM facts at admission.
- They are durably preserved as an **immutable migration archive bundle** (`historical source evidence retained from the admission snapshot`).
- This archive is not an ongoing reattachment to HRA, but an immutable provenance snapshot.
- They enter a strict one-way **Data Diet Path**:

```text
Lossless Archive (at admission)
    ↓
Observe Necessity in Real Household Usage (remove X vs retain X)
    ↓
Promote to Typed LOAM Fact  OR  Retire from Archive
```

Even hypotheses such as "Plan series is redundant because it reconstructs from Plan" must be verified against temporal corrections (e.g., if Plan is later corrected, does historical Actual retain its original evidence?). Data diet proceeds empirically after authority transfer.

## Formal Verification (Lean 4)

The minimal structure and its properties are formally verified in `Loam.Observations.Observation130`:

- `description_orthogonal_to_quantity`: Proves Core quantity projections are invariant under the presence or absence of description evidence.
- `description_distinguishes_identical_quantity_events`: Proves that two distinct Events with identical coordinates and amounts are distinguishable in household queries via `EventDescriptionMemory`.
- `event_id_uniquely_determines_description`: Proves that in a nodup collection, `EventId` uniquely determines the description text without any `ContextId`.

```text
lake build
✔ [44/47] Built Loam.Observations.Observation130
✔ [45/47] Built Loam.Observations
✔ [46/47] Built Loam
Build completed successfully (47 jobs).
```

## Checkpoint

```text
Observation 130:          admitted with Lean 4 proof (clean build, 0 warnings)
Branch:                   observation/130-event-description-pressure
Core additions:           0
Persistence additions:    0
Wire format additions:    0
Earned production type:   EventDescription { event : EventId, text : String }
Unearned / deferred:      ContextId (0), Effect-scope description (0), Generic Context (0)
Historical evidence (544): Lossless archive first -> Data Diet path
```

Observation 130 confirms that real historical admission earns a minimal Event-scoped descriptive evidence primitive (`EventDescription`), while keeping Core pure and deferring the remaining 544 items to an archival data-diet path.
