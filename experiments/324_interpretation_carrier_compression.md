# Observation 324 — existing Event carrier cannot compress interpretation meaning losslessly

Status: **BOUNDED ALLOY PROBE — DO NOT PROMOTE YET**

Baseline: `993654ac0592d8e7e89410a0ad219aebbef2458e`

## Trigger

Observations 321–323 left a small surviving interpretation shape:

```text
interpretive text
  subject -> Fact
  recordedAt
  attributedAt
```

Before introducing a production `Reflection` primitive, ask whether existing LOAM
machinery can carry the same meaning without inventing a new semantic family.

The strongest obvious reuse candidate is:

```text
zero-effect Event
+ EventDescription
+ one ActualValidity-like time coordinate
```

`PersonalSemanticMemory` already demonstrates the first two pieces outside Core.

## Existing semantic boundaries

`EventDescription` is intentionally unqualified human-recognition text scoped to
one EventId. It does not carry a second Event reference, chronology, causation,
priority, or authority.

`ActualValidity.validOn` is explicitly the occurrence-valid coordinate of an Event.
It is not generic knowledge time.

This experiment therefore tests representational sufficiency before any semantic
reuse is authorized.

## Candidate carrier

The bounded candidate retains only:

```text
note text
one time coordinate
```

The single time is tried in both plausible modes:

```text
Mode A: validOn-like carrier time = recordedAt
Mode B: validOn-like carrier time = attributedAt
```

Event identity is intentionally opaque and is not used as a hidden encoding for
subject or time. EventDescription text is also not parsed to recover structure.

## Questions

### Mode A: carrier time means recordedAt

Can two worlds have the same retained carrier while differing in:

- subject attribution?
- attributedAt?

If yes, then Event + Description + one recording-time coordinate loses meaning.

### Mode B: carrier time means attributedAt

Can two worlds have the same retained carrier while differing in:

- subject attribution?
- recordedAt?

If yes, then Event + Description + one attributed-time coordinate also loses meaning.

## Expected matrix

```text
recordedCarrierLosesSubject          SAT
recordedCarrierLosesAttributedTime  SAT
attributedCarrierLosesSubject        SAT
attributedCarrierLosesRecordedTime   SAT

RecordedCarrierDeterminesFullMeaning   SAT counterexample
AttributedCarrierDeterminesFullMeaning SAT counterexample
```

## What this does and does not test

This does **not** prove that LOAM needs a `Reflection` type.

It tests only the obvious compression candidate using one zero-effect Event, one
EventDescription, and one time coordinate.

It also does not attempt these semantically suspicious encodings:

- putting the subject EventId inside opaque prose;
- deriving subject from EventId token syntax;
- treating `EventCorrection` as subject attribution;
- using ActualValidity revision history as two simultaneous interpretation times;
- treating quantity-bearing RelationUnit as a generic semantic edge.

Those tricks may carry bits, but they would import meanings that LOAM currently
keeps separate.

## Expected conclusion if qualified

The existing Event carrier can plausibly reuse:

```text
identity
text
```

but not, without additional explicit evidence:

```text
subject attribution
both temporal coordinates
```

So the next compression question becomes smaller:

> Can LOAM add only the missing subject/time evidence around an existing
> zero-effect Event + EventDescription, rather than introducing a whole new
> Reflection object?

That is the next experiment if this boundary qualifies.
