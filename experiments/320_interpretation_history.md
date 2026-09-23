# Observation 320 — interpretation history without rewriting facts

Status: **QUALIFIED BOUNDED ALLOY OBSERVATION — DO NOT PROMOTE TO PRODUCTION YET**

Baseline: `2fc06056799d77f3fe78ecb960d82f8b3b8cadbe`

## Trigger

A practical household event can remain stable while its meaning changes later.

For example, one book purchase may later be seen as:

- ordinary desire;
- study;
- relief or distraction;
- some mixture that cannot be reduced to one cause.

The later interpretation may appear days after the purchase. It may also be
reconsidered again. Requiring a diary entry at transaction time would make the
system heavier and would incorrectly imply that the later interpretation was
already known then.

The question is therefore not "what was the true psychological cause?".

It is narrower:

> Can LOAM retain an event-like Fact, append later Reflection evidence without
> rewriting that Fact, preserve incompatible interpretations, and avoid
> pretending that timestamp order alone yields one canonical current view?

## Why Alloy

This is presently a structural distinguishability and possibility question.

There is no arithmetic theorem, production transition, or reusable Lean law yet.
The smallest useful instrument is therefore Alloy.

No real numbers or complex numbers are introduced in this probe. If a continuous
or directional structure survives later household pressure, it can earn a
separate experiment then.

## Model boundary

The model deliberately contains only:

```text
Fact
Reflection
Moment
Meaning
Stance
Snapshot
```

A `Fact` has an `occurredAt` coordinate.

A `Reflection` has:

- one Fact subject;
- one abstract Meaning;
- a Stance toward that Meaning;
- `recordedAt`, when the Reflection was actually retained;
- optional `attributedAt`, when the human says the remembered/interpreted
  perspective belonged.

`attributedAt` is not a Fact. In particular, recording on a later day that
"I now remember thinking this then" does not backdate the Reflection itself.

The model contains no:

- money or budget quantity;
- Attention integration;
- free-text semantics;
- inferred cause;
- mood or relationship ontology;
- confidence score;
- real / complex value;
- production persistence design.

## Candidate append law

A weak Reflection append says only:

```text
old reflections subset new reflections
and
at least one reflection is added
```

That is intentionally insufficient. The model asks whether Fact membership can
change at the same time.

The stronger candidate law adds an explicit Fact frame:

```text
before.facts = after.facts
```

This means:

> Adding interpretation evidence is not authority to rewrite what happened.

## Questions encoded

### 1. Retrospective interpretation

Can a Reflection be recorded later than the Fact it interprets?

Observed: **SAT**.

### 2. Reconsideration without deletion

Can an old Reflection remain retained while a newly appended Reflection takes
the opposite Stance toward the same Meaning and Fact?

Observed: **SAT**.

This is why the probe models Reflection **history**, not a single mutable
"current interpretation" field.

### 3. Remembered earlier perspective

Can a later Reflection explicitly attribute its perspective to the earlier
Fact time while keeping the later recording time?

Observed: **SAT**.

The two time coordinates remain distinct.

### 4. Timestamp order does not force one current view

Can two opposed Reflections be equally latest for one Fact?

Observed: **SAT**.

If this witness exists, a unique current interpretation is not derivable from
`recordedAt` alone. A future query would need an explicit selection policy, or
it should honestly return several current candidates.

### 5. Weak append is not enough

Can a weak Reflection append coincide with changed Fact membership?

Observed: **SAT**.

If so, any later temporal model must carry an explicit frame condition (or a
representation that makes Fact preservation structural). "We only added a
Reflection" is not by itself a formal preservation law.

## Assertion matrix

Qualified bounded result on GitHub Actions run `35887898679` (Alloy 6.2.0 / Sat4j):

```text
retrospectiveReflectionExists              SAT
opposedReflectionAppendExists              SAT
rememberedPastAttributionExists            SAT
ambiguousLatestReflectionExists            SAT
weakAppendCanRewriteFacts                   SAT

ReflectionAppendPreservesFacts              UNSAT counterexample
ReflectionAppendPreservesPriorReflections   UNSAT counterexample
ReflectionAppendKeepsSubjectsPresent        UNSAT counterexample
```

For `check` commands, UNSAT means Alloy found no counterexample in the selected
scope.

## What this qualified result earns

Only a small research conclusion:

1. Fact and later interpretation can be represented as distinct evidence.
2. Interpretation can be append-only without erasing earlier views.
3. A remembered "then" and the actual recording "now" need distinct coordinates.
4. Reflection time alone does not necessarily yield one canonical current view.
5. Fact preservation must be explicit in any state-transition model.

It does **not** earn:

- a production `Reflection` Core type;
- a new canonical file;
- mandatory diary input;
- psychological inference;
- automatic relation discovery;
- a singleton current interpretation;
- real-number or complex-number semantics.

## Next pressure

Do not implement production storage yet.

First ask one harder question:

> Is a retained Reflection history actually necessary for a household answer,
> or can the desired answers be reconstructed from existing Attention / Actual /
> Scheduled evidence plus optional human notes?

Only if independent household meaning survives that comparison should a
production primitive be considered.
