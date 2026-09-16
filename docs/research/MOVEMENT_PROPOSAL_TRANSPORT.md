# Machine-readable Movement proposal transport

Status: production-facing read-only adapter candidate

Baseline:

```text
main: fa6ef1d8dcf94b45c21bb73d6388ad279883d33e
PR #992 merged
```

## Question

PR #992 established the shared read-only proposal seam:

```text
MovementAdmission.Draft
  -> MovementDraftReview.check
  -> current-world admission question
  -> no persistence
```

The next question is narrower:

> What is the smallest machine-readable transport an AI, receipt reader, CSV adapter, bank adapter, or other external frontend can use to submit one proposal without inventing a second Movement semantics or imported identity scheme?

## Decision

The first transport is deliberately line-oriented and versioned rather than JSON-specific or bank-specific.

```text
LOAM-MOVEMENT-PROPOSAL<TAB>1
date<TAB>YYYY-MM-DD
description<TAB>optional recognition text
effect<TAB>-|EFFECT_KEY<TAB>LOCUS<TAB>MEASURE<TAB>SIGNED_QUANTA
relation<TAB>EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY
discharge<TAB>RELATION_ID<TAB>POSITIVE_QUANTITY
```

Example:

```text
LOAM-MOVEMENT-PROPOSAL	1
date	2026-09-16
description	book purchase
effect	-	paypay	jpy	-2470
effect	-	books	jpy	2470
```

The transport ends at the existing semantic draft:

```text
external observation
  -> frontend-specific interpretation
  -> proposal text
  -> MovementProposal.parse?
  -> MovementAdmission.Draft
  -> MovementDraftReview.check
  -> no write
```

It does not become a canonical journal format.

## Why the total is absent

`MovementAdmission.Draft.total` is an entrance validation value, but for a structured proposal it is uniquely derivable from the positive Effects.

Therefore version 1 does not repeat it in the transport.

```text
positive Effects
  -> derived total
```

A supplied `total` row is rejected instead of creating two independently mutable representations of one fact.

## Effect identity

`-` means an anonymous Effect.

That is the normal shape for ordinary external proposals. A stable EffectKey is accepted only when explicit relation evidence needs to refer to that Effect.

This does not create source continuity. An EffectKey retained because of LOAM relation evidence is internal identity within the admitted LOAM Event, not proof that a later bank or receipt row is the same external occurrence.

## What is intentionally absent

Version 1 has no field for:

- bank transaction id;
- CSV row id;
- receipt id;
- source file position;
- content hash;
- import batch id;
- source-to-LOAM mapping;
- deduplication decision.

Observations 075-078 already established that mutable content or presentation position cannot carry historical occurrence continuity in general. Adding a convenient `source-id` field before an explicit continuity contract exists would blur one-shot proposal transport with repeatable import authority.

The parser therefore rejects unknown rows such as:

```text
source-id<TAB>bank-row-7
```

## Publication boundary

`./tools/loam movement-proposal` is read-only:

```text
./tools/loam movement-proposal PROPOSAL_FILE [LOAM_DATA_DIR]
```

Success means only:

```text
this proposal
is admissible
against the household world read now
```

It does not mean:

- identity is reserved;
- publication is guaranteed later;
- the external source row has been remembered;
- a later snapshot can be deduplicated automatically.

Canonical publication remains separately owned by `HouseholdCommand.record`, which re-reads current authority under writer ownership.

## Why this helps AI first

An AI does not need a bank-specific parser to use this boundary. It can interpret a receipt, statement row, message, or user instruction and produce the small proposal transport directly.

A future CSV, bank, receipt, or email adapter can produce the same transport without changing Movement semantics:

```text
AI now
  |
  v
frontend-specific interpretation
  |
  v
LOAM-MOVEMENT-PROPOSAL v1

future external adapters
  |
  +-> the same transport boundary
```

The transport therefore stays source-neutral while product work can remain AI-first.

## Current product priority

The current product priority is deliberately narrower than the transport's possible producer set:

```text
AI reader / AI writer
    now

CSV / bank / receipt import
    deferred
```

No concrete external importer is currently earned. Keeping the transport independent of AI-specific syntax preserves that future extension point without building unused source machinery today.

The writer path should preserve the existing authority boundary:

```text
user observation
  -> AI interpretation
  -> LOAM-MOVEMENT-PROPOSAL v1
  -> MovementProposal.parse?
  -> MovementDraftReview.check
  -> human-visible proposal
  -> explicit acceptance
  -> HouseholdCommand.record
  -> MovementPublisher
  -> authoritative re-read + canonical publication
```

The earlier read-only review is not publication authority. Acceptance must not create a second publisher, reserve the hypothetical identity, or assume that a proposal accepted against an earlier world must still publish. The existing writer owns the authoritative re-read and may still refuse.

The reader direction should follow the same discipline from the opposite side: expose existing semantic read boundaries to AI rather than constructing a second AI-specific household model or asking the AI to infer semantics from raw persistence.

## Next pressure

After this transport qualifies, the next useful experiment is the smallest explicit-acceptance AI writer path that turns an already reviewed proposal into the existing `HouseholdCommand.record` request without adding another Movement semantics or publisher.

After that, inspect the existing application/read boundaries and identify the smallest AI reader surface that can answer household questions from canonical semantic projections.

External import remains intentionally deferred until concrete user demand earns a source-specific adapter. If repeatable source identity or duplicate handling ever becomes necessary, Observations 075-078 remain the authority boundary; those concerns must not leak into the current one-shot AI proposal path merely to keep future options open.
