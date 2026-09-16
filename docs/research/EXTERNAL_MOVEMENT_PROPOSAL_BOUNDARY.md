# External Movement Proposal Boundary

Status: **implementation experiment on `feat/external-movement-proposal-seam`**

## Question

How should a human, AI, bank-statement adapter, receipt reader, CSV parser, or
other external frontend propose a household Movement without making the source
itself authoritative or creating another import ontology?

## Existing evidence

LOAM already has the needed semantic draft boundary:

```text
MovementAdmission.Draft
```

A draft contains the already-collected occurrence date, optional recognition
text, signed Effects, explicit relation/discharge drafts, and practical total.
It contains no durable EventId allocated by the operation and no persistence
contract.

`HouseholdCommand.record` is already the surface-neutral production command
entrance. It delegates final authority re-read, admission, identity allocation,
writer ownership, recovery, and persistence to the existing publisher path.

Observations 075–078 already constrain external identity:

- mutable source content or position cannot recover stable occurrence identity;
- an external identity aid must not silently become a permanent second authority;
- ambiguous source matching may be reconciled for one operation without creating
  a future source-to-LOAM mapping;
- run-local identity is safe only for queries proved invariant under identity
  renaming and must not be promoted into retained continuity.

Therefore a new `ExternalTransaction`, `ImportedMovement`, `BankEvent`, or generic
source-id Core primitive is not earned merely to let an external frontend propose
one ordinary Movement.

## Qualified candidate seam

```text
external observation
    -> frontend-specific interpretation
    -> MovementAdmission.Draft
    -> MovementDraftReview.check
         read current Actual
         read current Locus admission policy
         run MovementAdmission.admit?
         discard hypothetical admitted world and identity
         write nothing

explicit later acceptance
    -> HouseholdCommand.record
         writer-owned authoritative re-read
         MovementAdmission.admit?
         canonical publication
```

The review call answers only:

> Would this draft be admissible against the household world observed now?

It does **not** answer:

- whether the external source occurrence has stable identity;
- whether this row was imported before;
- whether two similar external rows are the same historical occurrence;
- whether a future publication will still succeed;
- whether any hypothetical EventId is reserved;
- whether the external source becomes household authority.

## CLI experiment

The current experiment adds:

```text
./tools/loam movement --dry-run [LOAM_DATA_DIR]
```

It intentionally reuses the ordinary Movement collector. Scripted or AI callers
may therefore use the same occurrence-date, signed posting, description,
relation, and discharge inputs as ordinary Movement recording.

On success the command reports only that the proposal is currently admissible.
It writes no LOAM persistence and exposes no hypothetical EventId.

On refusal it writes nothing.

A later ordinary `movement` publication still re-reads authority under writer
ownership and may refuse if the household world changed after the dry run.

## Why this helps AI and external connections

An AI may inspect a bank row, receipt, email, or other source and propose the
household interpretation without receiving publication authority merely because
it could parse the source.

This keeps three responsibilities separate:

```text
external adapter
    owns source parsing / interpretation

MovementDraftReview
    owns read-only current admissibility question

HouseholdCommand + publisher
    own explicit canonical admission and publication
```

A future CSV, OFX/QFX/CAMT, bank connector, or receipt adapter can terminate at
`MovementAdmission.Draft` without changing the Practical Core.

## Stop line

This experiment does not authorize repeatable import identity or automatic
deduplication.

The moment the product asks:

> Is this external occurrence the same one I saw on a previous run?

Observation 075 applies. Stable source-owned identity, retained continuity, or an
explicit reconciliation protocol is required. Content hashes, row position, or
the successful result of a previous dry run are not sufficient continuity
proofs.

That future C-level authority question stays separate from this B-level proposal
adapter seam.

## Qualification obligations

The seam qualifies only if:

1. the read-only review uses the same `MovementAdmission.admit?` semantics as
   publication;
2. it reads current Actual evidence and current Locus admission policy;
3. success writes no Actual or policy persistence;
4. refusal writes no Actual or policy persistence;
5. no hypothetical EventId escapes the review API or CLI;
6. real publication remains the existing writer-owned authoritative path;
7. no source-to-LOAM mapping, sidecar, or imported identity is introduced.
