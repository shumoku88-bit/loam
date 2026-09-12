# Minimal Actual model — white-sheet audit

This experiment deliberately ignores today's physical Movement-family topology.
It asks what retained household evidence is required if canonical Actual is designed
from the observable semantics outward rather than from the existing codecs inward.

This is not a migration plan and does not authorize changing production data.

## Rule

Keep a distinction only when two admitted household histories can differ in that
distinction and some supported observation must still distinguish them.

Physical file boundaries, crash-staging artifacts, compatibility identities, and
historical implementation boundaries are not household semantics by themselves.

## Earned semantic distinctions

### Event identity — KEEP

`EventId` is referenced by correction, reversal, validity, discharge, routing/review
surfaces, and human selection. Two otherwise equal movements may remain distinct
historical events. Event identity is therefore base semantic identity.

### Physical effects — KEEP

`LocusId`, `MeasureId`, and exact signed quantity are base observed evidence.
Effect list order is not semantic.

### Effect identity — KEEP SPARSELY

An Effect needs stable independent identity only when retained evidence refers to
that exact Effect, currently `RelationUnit.sourceEffect`. Ordinary Effects need not
carry durable identity merely because the current in-memory `Effect` type does.
Position-derived identity is rejected because Event effect order is explicitly
non-semantic.

### Base occurrence date — INLINE

The base date has no identity independent of its Event. Production validity history
already identifies the base coordinate by `.root EventId`; only later revisions
receive independent identity. Therefore the base date belongs naturally in the
transaction record.

### Date revision identity — KEEP SPARSELY

A later date revision can be independently referenced by another correction, so
`ActualValidityRevisionId` remains earned. Under admitted validity topology each
revision has at most one predecessor and correction has no identity of its own.
The compact candidate can therefore retain one revision as:

```
DATE-REV <revision-id> <valid-on> REPLACES <root-event|revision-id>
```

rather than keeping a separate revision family plus correction-edge family.

### Description — INLINE OPTIONAL

Description is observable human-recognition evidence but has no identity independent
of EventId and production exposes zero or one description per Event. No independent
description-edit writer was found; corrected content is represented by a replacement
Event. Therefore description can be an optional field of the transaction without
losing its semantic orthogonality from quantity.

### Event correction — KEEP MEANING, INLINE EDGE

`EventCorrection` has no independent identity. Admitted correction topology is a
collection of disjoint finite paths: at most one successor per target and at most
one predecessor per replacement. The same relation can therefore be represented on
the replacement transaction:

```
REPLACES <target-event-id>
```

The original and replacement transactions both remain retained history.

### Actual reversal — KEEP MEANING, INLINE EDGE

`ActualReversal` has no independent identity and is functional in both directions.
Both transactions remain physical history. The relation can therefore be represented
on the reversal transaction:

```
REVERSAL-OF <target-event-id>
```

This keeps the non-derived answer to “which Actual does this inverse movement
reverse?” without a separate memory family.

### RelationUnit — KEEP AS IDENTIFIED SUBFACT

Relation identity is independently observable because later discharge evidence
references `RelationUnitId`; otherwise-equal relation units may coexist. Relation
identity therefore remains. Its source Event need not be duplicated if the relation
row is physically nested in that Event's transaction, but its stable source Effect
identity remains required:

```
RELATION <relation-id> SOURCE <effect-key> <debtor> <creditor> <quantity>
```

### RelationDischarge — KEEP MEANING, INLINE UNDER LATER EVENT

A discharge has no independent `DischargeId`. Current semantics normalize one exact
quantity per `(later Event, target RelationUnit)` pair. Nesting the row in the later
transaction removes duplicate EventId without losing evidence:

```
DISCHARGE <relation-id> <quantity>
```

## Candidate canonical Actual grammar

Conceptually, not final syntax:

```
TX <event-id> <base-valid-on> [description]
  [REPLACES <event-id>]
  [REVERSAL-OF <event-id>]

  EFFECT <locus> <measure> <quantity>
  KEYED-EFFECT <effect-key> <locus> <measure> <quantity>

  DATE-REV <revision-id> <valid-on> REPLACES <root-event|revision-id>

  RELATION <relation-id> SOURCE <effect-key> <debtor> <creditor> <quantity>
  DISCHARGE <relation-id> <quantity>
ENDTX
```

This is still many semantic concepts. The compression claim is only that they do
not require one physical top-level family each.

## Deliberately excluded from Actual

ActualRouting, AccountingRole, zero-origin coverage, Capacity, ScheduledRouting,
cycle funding, and presentation configuration answer policy/configuration questions
rather than “what happened in this Actual transaction?”. They remain outside this
model even if later stored in the same larger canonical stream container.

## Publication boundary

Open-reference states tolerated by current low-level persistence are not automatically
household semantics. If a generation switch publishes the whole admitted Actual
world atomically, interrupted staging need not force top-level canonical families to
remain independently addressable. A production migration must prove this boundary
rather than carrying old crash-staging shapes into the new schema by default.

## Acceptance questions

A compact model is acceptable only if all of these survive:

1. physical quantity and balance observations;
2. current Event correction frontier and complete correction history;
3. current occurrence date and complete date-revision provenance;
4. description lookup/presentation;
5. explicit reversal identity;
6. exact Relation source Event/Effect identity and quantity;
7. exact partial-discharge provenance and outstanding relation amount;
8. HOBS1 and current CycleBudget observations;
9. permutation-insensitivity of ordinary Effect representation;
10. fail-closed rejection of branching, merging, cycles, open references, or other
    unsupported topology at the admitted read boundary.

The accompanying Alloy experiment tests whether the functional/injective topology
laws make correction, reversal, date-correction, and discharge edges representable
as transaction-local subfacts without collapsing distinct admitted observations.
