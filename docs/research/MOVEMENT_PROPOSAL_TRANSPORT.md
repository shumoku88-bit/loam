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

A future CSV or bank adapter can do the same transformation mechanically:

```text
bank / CSV / receipt / email / AI
             |
             v
   frontend-specific interpretation
             |
             v
LOAM-MOVEMENT-PROPOSAL v1
             |
             v
    MovementAdmission.Draft
```

This makes external connectivity incremental. Each source adapter owns only source interpretation; LOAM admission remains one shared semantic boundary.

## Next pressure

After this transport qualifies, the next useful experiment is not another transport format. It is one concrete source adapter, preferably a one-shot CSV reader, that produces this proposal format without claiming repeatable source identity.

Only after real duplicate pressure appears should the project reopen the Observation 075-077 question of stable source identity versus explicit reconciliation.
