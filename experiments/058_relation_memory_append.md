# Observation 058: relation memory append admission

## Question

Once `EventCorrectionMemory` and `EventResolutionMemory` exist as raw per-kind fact collections, what should a future `add?` operation admit?

In particular:

1. Should `add?` enforce only the local collection law, namely per-kind relation identity uniqueness?
2. Or should `add?` also require every referenced `Event` to be present at the instant the relation is appended?
3. If referential closure is checked eagerly during append, can physical arrival order change which canonical raw facts survive?

This observation does not choose a persistence format and does not introduce a global `FactId`.

## Context

The practical Core already separates three concerns:

- `EventCorrectionMemory` / `EventResolutionMemory` enforce per-kind identity uniqueness.
- `RelationAdmission` derives a fail-closed referentially closed view against the current `EventMemory`.
- Observation 057 established that admission should remain derived rather than become an independently persisted fact stream.

`EventMemory.add?` likewise enforces the local memory invariant, repeated `EventId`, without assigning temporal or authority meaning to append position.

The remaining pressure is whether relation-memory append should stay similarly local or collapse referential admission back into mutation.

## Model

The Alloy model represents one practical relation kind at a time. `RelationId` is therefore analogous to either `EventCorrectionId` or `EventResolutionId`, not a cross-kind identity namespace.

Two append policies are compared:

### Identity-only raw append

```text
raw relation arrives
        |
        v
per-kind RelationId unique?
        |
      yes
        v
remember raw relation
```

Whether its referenced Events are currently present is deliberately not part of raw collection admission.

### Eager referential append

```text
raw relation arrives
        |
        v
RelationId unique
AND all referenced Events present now?
        |
      yes
        v
remember raw relation
```

Derived referential admission remains:

```text
current Event set + raw relation set
        |
        v
admitted relation view
```

## Commands

Expected Alloy results:

- `referentialAddCanDependOnArrivalState`: SAT
- `referentialPolicyCanMakeFinalFactsArrivalDependent`: SAT
- `identityOnlyKeepsEarlyRawRelationUntilAdmissible`: SAT
- `EventsPresentMakesPoliciesAgree`: UNSAT
- `IdentityOnlyRejectsDuplicateId`: UNSAT
- `IdentityOnlyDoesNotBypassDerivedAdmission`: UNSAT

## Interpretation

Eager referential append makes canonical raw fact retention depend on physical arrival order.

Suppose a relation already names two Events, but one Event has not yet arrived locally.

If the relation arrives first:

```text
Events:   E0
Relation: R -> {E0, E1}
                    ^ missing
```

an eager referential `add?` rejects `R`. If `E1` arrives later and the relation is not explicitly retried, the final raw relation memory still lacks `R`.

If the same facts arrive Events-first, the same eager policy accepts `R`.

So two executions containing the same eventual facts can leave different canonical raw relation sets merely because publication/arrival order differed. That would give physical arrival order semantic power that LOAM has repeatedly avoided.

Identity-only append behaves differently. It can retain `R` as a raw fact immediately, while the derived admitted view remains fail-closed and hides `R` until `E1` exists. When `E1` later appears, the same remembered relation becomes visible without rewriting or retrying the relation fact.

This keeps two laws separate:

> Raw relation-memory admission answers whether this relation identity can be remembered uniquely.

> Referential admission answers whether this remembered relation is currently semantically exposable against the current EventMemory.

When all referenced Events are already present, the two append policies agree. Therefore eager referential checking does not add a stronger fact-identity law; it only couples mutation success to current publication state.

## Practical consequence

A future practical `EventCorrectionMemory.add?` / `EventResolutionMemory.add?` should most likely mirror `EventMemory.add?`:

- append one complete raw relation representation;
- reject repeated per-kind relation identity;
- retain deterministic list representation only;
- do not infer chronology, priority, authority, or arrival-order semantics;
- do not require current `EventMemory` referential closure at raw append time.

After append, `RelationAdmission` remains the separate fail-closed derived boundary.

This observation does **not** yet require:

- implementing `add?`;
- Correction / Resolution persistence;
- automatic retry machinery;
- a relation publication protocol;
- concurrent writers;
- time, authority, evidence, or origin semantics.

## Tool choice

Alloy is sufficient here because the pressure is a small relational comparison between two append policies and two arrival states. If future work makes retries, concurrent writers, interleavings, or liveness part of the question, TLA+/Apalache or SPIN would become better candidates.
