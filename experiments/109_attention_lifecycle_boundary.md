# Observation 109: Can Scheduled and Attention share lifecycle shape without sharing lifecycle meaning?

## Question

The whole-household evidence graph leaves `Attention` / Issue as the largest practical HRA / h-kernel capability not yet structurally observed in LOAM.

At first glance it resembles Scheduled evidence:

```text
Scheduled
  stable identity
  future-oriented coordinate
  relation to later evidence
  eventually no longer open

Attention
  stable identity
  optional due meaning
  relation to Plan / Movement / later Attention
  eventually no longer open
```

That similarity creates an attractive compression pressure:

> Can Attention simply reuse the Scheduled lifecycle relation shape from Observation 105?

Current h-kernel reality pressure says this question is dangerous. An Issue relation such as `IssueRealizedAs Actual` or `IssueContinuedAs Issue` is append-only provenance, but recording that relation does **not** close the Issue by itself. Issue lifecycle is independent. h-kernel also distinguishes `Resolved` from `Dropped`, and distinguishes `NoDueDate` from `DueUndetermined`.

Observation 109 therefore tests structural reuse while actively seeking counterexamples to semantic collapse.

## Candidate shared structure

The model deliberately gives Scheduled and Attention the same relation record shape:

```text
RelationEvidence
  source
  target?
  knownOn
```

Source kind constrains the admissible target shape:

```text
Scheduled -> Movement    possible
Scheduled -> Scheduled   possible
Scheduled -> none        possible

Attention -> Movement    possible
Attention -> Attention   possible
```

For Scheduled, a visible relation is interpreted as terminal lifecycle evidence, following the pressure already explored by Observation 105.

For Attention, relation provenance is deliberately **not** lifecycle closure. Attention closure is separate:

```text
AttentionClosureEvidence
  attention
  knownOn
  kind = Resolved | Dropped
```

Attention due meaning is also separate:

```text
DueOn day
NoDueDate
DueUndetermined
```

## Probes

### 1. The same source-target record shape can appear on both planes

A Scheduled occurrence and an Attention item both point to a Movement through the same `RelationEvidence` shape.

The Scheduled occurrence is closed by its relation, while the Attention item remains open because it has no closure evidence.

Expected: **SAT**.

This would show that representation shape can be reused while lifecycle semantics remain source-specific.

### 2. Attention relation history does not determine Attention lifecycle

Two worlds retain exactly the same Attention / Scheduled relation evidence but differ in Attention closure evidence.

One therefore keeps an Attention item open while the other closes it.

Expected: **SAT**.

This is direct pressure against treating `IssueRealizedAs Movement` or `IssueContinuedAs Attention` as an automatic lifecycle transition.

### 3. Closed/open alone loses Resolved vs Dropped

Two worlds agree on which Attention items are closed but disagree on why one closed:

```text
Resolved
Dropped
```

Expected: **SAT**.

A generic boolean `closed` summary is therefore too small if the household UI preserves this distinction.

### 4. Optional date alone loses no-date vs unknown-date

Two worlds show no concrete due date for the same Attention item, but one explicitly says `NoDueDate` while the other says `DueUndetermined`.

Expected: **SAT**.

This pressures retention of the three-way due meaning already used in HRA / h-kernel rather than encoding due as only `Maybe Day`.

### 5. Movement realization provenance need not close Attention

An Attention item has a relation to a Movement and remains open.

Expected: **SAT**.

### 6. Continuation provenance need not close Attention

An earlier Attention item points to a later Attention item and still remains open.

Expected: **SAT**.

This follows current h-kernel semantics where relation reference admission is independent from Issue status.

## Checks

Expected results:

```text
GenericTargetRelationClosesAttention                         SAT counterexample
AttentionRelationsDetermineLifecycle                         SAT counterexample
ClosedAttentionDeterminesDisposition                         SAT counterexample
OptionalDueDateDeterminesDueMeaning                          SAT counterexample
ExplicitAttentionClosureAndDueDetermineAttentionView         UNSAT counterexample
ScheduledRelationTargetIsTerminal                            UNSAT counterexample
```

The first four are deliberately over-compressed candidates.

The fifth asks whether explicit Attention closure evidence plus explicit due meaning is sufficient for the selected lifecycle/due view. The sixth preserves the much narrower Scheduled interpretation inside this bounded model.

## Compression boundary sought

If the expected boundary survives Alloy, the useful result is not `Scheduled == Attention`.

It is closer to:

```text
shared structural helper for
  source / target / known-through relation evidence
        yes, potentially

one universal target-decoded lifecycle algebra
        no

Attention relation provenance
        independent from Attention closure

Attention closed boolean only
        too small

Attention optional due date only
        too small
```

That would make `Attention` a genuinely distinct semantic plane even if implementation scaffolding can be reused.

## Why this matters for compactness

A syntactically tiny design such as:

```text
Thing
  target?
  date?
  closed?
```

looks compact but erases distinctions that current household behavior actually observes.

The stronger compact design would instead reuse low-level mechanics only where the meanings agree:

```text
shared identity / relation / temporal machinery

Scheduled semantic rules
Attention semantic rules
```

This matches the pattern exposed by Observations 106 and 107: share algebra or history shape where possible, but keep the semantic partition that changes answers.

## Important boundaries

Observation 109 does not establish:

- a Practical Core Attention or Issue type;
- text/details storage;
- amount semantics for Attention;
- Plan-oriented relations such as `planned-as` / `planning-withdrawn`;
- funding provenance;
- whether continuation should normally close the earlier Attention item in a future LOAM UI;
- edit/correction identity for Attention;
- recurrence or notification behavior;
- generic relation persistence;
- whether the names `Resolved` and `Dropped` are final LOAM vocabulary.

It asks only what information must remain distinct for the selected lifecycle, relation, and due questions.

## Qualification status

The Alloy specimen is present but is **not yet solver-qualified** for the same environment reason currently affecting Observation 108: creation of a new GitHub Actions workflow was blocked by connector safety checks, and the available execution container cannot obtain the Alloy 6.2.0 distribution from external hosts.

Do not treat the expected SAT / UNSAT boundary as an established result until Alloy 6.2.0 + Sat4j has executed this exact model.

## Next pressure if the boundary survives

The remaining cross-capability question is then less about lifecycle and more about relation vocabulary:

> Which Issue / Attention relations are independently observable household facts, and which user-facing relation names can be derived from endpoint kinds without creating a universal relation ontology?

After that, the whole-household survey should be ready for a candidate minimum canonical vocabulary pass before practical Lean implementation.
