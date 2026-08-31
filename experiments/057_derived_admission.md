# Observation 057: derived relation admission

## Question

Should referential admission itself become persisted canonical data, or should it remain a view derived from current `EventMemory` plus raw relation facts?

Observation 055 established fail-closed admission: a relation is semantically hidden while any explicitly referenced Event is missing. Observation 056 then established per-kind relation identity uniqueness independently of that referential rule.

This observation asks what happens when the inputs later grow append-only.

In particular:

1. Can an already-recorded relation become admissible only because a previously missing Event later appears?
2. If admission was stored when the relation was still hidden, can that stored admission become stale without another admission write?
3. Does a derived admission view remain closed, remain a subset of raw facts, and grow monotonically under append-only Event/relation inputs?
4. If a stored admission is required to be fresh, does it carry any information beyond the inputs from which it is derived?

## Model

The model deliberately uses one generic `Relation` with a non-empty set of Event references. That is enough for the present question: Correction target/replacement and Resolution parents/replacement differ in shape, but both are referentially admitted only when all explicit Event references are present.

Each `Snapshot` contains:

- `events`: currently visible Events;
- `raw`: raw relation facts;
- `storedAdmission`: a hypothetical independently persisted admitted set.

The actual semantic view is defined instead as:

```text
derivedAdmission(snapshot)
  = raw relations whose referenced Events are all present
```

`Before -> After` allows only append-only growth of Events and raw relations.

## Commands

Expected Alloy results:

- `storedAdmissionCanLag`: SAT
- `derivedViewCanRevealLateEndpoint`: SAT
- `DerivedAdmissionSubsetRaw`: UNSAT
- `DerivedAdmissionClosed`: UNSAT
- `DerivedAdmissionMonotoneUnderAppendOnlyInputs`: UNSAT
- `StoredAdmissionWithoutRewriteAlwaysTracksInputs`: SAT
- `FreshStoredAdmissionIsFunctionallyDetermined`: UNSAT

## Interpretation

A relation may already exist in raw memory while one of its Event references is temporarily absent. In `Before`, fail-closed admission correctly hides it. If the missing Event later appears, the same unchanged raw relation becomes admissible in `After`.

A derived view handles this automatically because admission is recomputed from the current inputs.

A separately stored admission does not. Alloy finds a witness where:

```text
Before:
  raw relation exists
  one referenced Event is missing
  stored admission is fresh and hides the relation

After:
  missing Event has been appended
  raw relation is unchanged
  stored admission is not rewritten
```

At that point the stored admission lags the current semantic view: the relation is now admissible, but the stored set still hides it.

This happens even with append-only inputs. No deletion, correction of the admission record, or adversarial mutation is needed.

The derived view has three useful properties in the bounded model:

- it contains only raw relation facts;
- every admitted relation is referentially closed against the current Event set;
- under append-only growth of Events and raw relations, the derived admitted set is monotone.

Finally, if a stored admission is required to be fresh, two snapshots with the same Events and raw relations must have the same admitted set. The admitted set is therefore functionally determined by those inputs; it contributes no independent semantic fact.

## Practical consequence

The useful boundary is:

```text
canonical facts
  EventMemory
  raw Correction / Resolution memories
        ↓
referential admission
  derived, fail-closed, recomputable
        ↓
semantic projection
```

So referential admission should remain a derived semantic view rather than a new canonical fact stream.

This does **not** prohibit caching an admitted view for performance. A future cache may be useful, but it should be treated as disposable/recomputable state and validated or rebuilt from canonical inputs rather than trusted as independent truth.

This observation does not yet choose:

- Correction / Resolution persistence format;
- one bundle versus multiple physical streams;
- cache invalidation machinery;
- time, authority, evidence, or origin semantics;
- a temporal model checker. The current two-snapshot question is adequately relational, so Alloy is sufficient here.
