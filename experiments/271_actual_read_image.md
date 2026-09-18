# Observation 271: Can normalized Actual carry its shared read admissions once?

Status: **EXPERIMENTAL LEAN PROBE**

Baseline:

```text
eb1dd2bdc54afec26453e0b8109ba237bdd0d822
refactor(read): share CurrentCoverage admission (#1044)
```

## Pressure

Canonical `actual.loam` decoding already performs the full fail-closed
`admitActualEvidence?` sequence before returning `ActualEvidence`.

Two of those derived views are then recomputed broadly by production readers:

```text
correctionFrontierMemory?
admittedActualValidityMemory?
```

Representative downstream repetition includes:

- ActualReview;
- BalanceReview;
- JournalExport;
- BudgetWindowReview;
- CurrentCoverageReview;
- RoleBalanceReview;
- daily/effective quantity paths.

The remaining normalized Actual checks, including Relation, Discharge, Merchant
reference closure and Reversal physical-inverse qualification, do not show the
same broad read-side repetition.

## Question

Can one read-side value carry only the two repeatedly reused Actual views:

```text
raw ActualEvidence
+ full Actual admission success
+ admitted current Event frontier
+ admitted current validity memory
```

without inventing another semantic authority?

## Probe

`Loam/Observations/Observation271.lean` defines an observation-local
`ReadImage` carrying:

```lean
evidence
currentEvents
currentValidities
proof currentEvents = correctionFrontierMemory?(...)
proof currentValidities = admittedActualValidityMemory?(...)
```

The probe checks:

1. a representative correction-bearing Actual world admits the image;
2. quantity from the carried current Event memory is exactly the existing
   correction-frontier quantity answer;
3. the carried validity view is exactly the existing validity admission result;
4. incomplete validity is rejected;
5. cyclic Correction is rejected.

## Boundary

This observation does not change:

- `ActualEvidence`;
- normalized persistence;
- ActualAuthority;
- any reader or writer;
- canonical household data.

It deliberately does not carry Relation, Discharge, Merchant, Reversal or
description invariants because no broad repeated production admission pressure
was found for those families.

## Promotion question

If the Lean probe succeeds, the smallest production candidate is not a giant
proof-carrying `ActualEvidence`.

It is a read image produced only after full normalized Actual admission. The
image carries that full-admission success together with the already-computed
current Event frontier and current validity memory.

Raw `ActualEvidence` should remain available to mutation/admission code because
writers create new candidates that must be requalified after change.

Potential production shape:

```text
decode actual.loam
  -> full Actual admission once
  -> Actual read image
       raw evidence
       current Event frontier
       current validity memory

readers
  -> consume carried views

writers
  -> mutate raw candidate
  -> re-admit candidate before publication
```

The production decision remains deferred until the probe builds and the exact
reader migration surface is audited.
