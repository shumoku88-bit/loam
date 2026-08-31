# Observation 063 — Does Plan realization require explicit linkage?

## Question

Observations 013–015 already separated physical history from commitment-bearing information. Observation 062 then showed that representative bookkeeping shapes still do not force conventional `Account` identity into the neutral Event/Effect core.

A different pressure appears when an expected future fact later has an Actual counterpart.

A private household ledger used as source pressure contains Plans with stable identity and later Actual records that explicitly refer back to those Plans. In representative cases, the expected and Actual records need not be identical in observed time or quantity.

The public experiment copies **none** of the private descriptions, dates, quantities, account identities, or Plan identities. It keeps only the anonymized structural pressure.

The question is:

> If Plan and Actual Event records already retain their own identity and content, can their realization correspondence be inferred from those records, or must the correspondence itself survive as independent information?

This is deliberately narrower than asking whether a particular file should contain a `plan-id` field. An Event field that names a Plan and a standalone `Plan -> Event` relation are both relational encodings. Alloy can test whether the linkage carries independent information; it cannot by itself choose a source-file ownership convention.

## Why Alloy

The pressure is static and relational:

- keep the same Plan records;
- keep the same Actual Event records;
- vary only the realization relation;
- ask whether completion, provenance, and variance-like answers change.

No transition order is needed yet, so TLA+ and SPIN would add machinery without answering a different question. Lean should wait unless a reusable practical law is earned.

## Anonymous vocabulary

The bounded model retains:

```text
Plan identity
  + expected Time
  + expected Amount
  + expected Shape

Event identity
  + actual Time
  + actual Amount
  + actual Shape

realizes : Plan -> lone Event
```

Each Event can realize at most one Plan in this first model. This is a deliberate one-to-one partial-matching boundary, not a claim that split or merged realization is impossible. Many-to-many realization remains future pressure.

The model does not introduce a generic Transaction object, schedule hierarchy, Series, recurrence, lifecycle state, or household-specific names.

## Selected answers

From the explicit realization relation the model derives:

- which Plans are completed;
- which Events are realization Events;
- which completed Plans differ from their Actual Event in amount;
- which differ in time;
- which differ in structural Shape;
- which specific Event fulfilled which specific Plan.

## Pressures and observed result

Alloy 6.2.0 + Sat4j, exactly 3 Plans / 3 Events / 2 Times / 2 Shapes / 2 Worlds / 5-bit Ints:

```text
realizationCanLinkNonidenticalRecords          SAT
sameRecordsDifferentCompletion                 SAT
sameCompletionDifferentRealization             SAT
sameActualCanBePlannedOrUnplanned              SAT
exactContentCanBeAmbiguous                     SAT
PlanEventRecordsDetermineCompletion            SAT counterexample
CompletionSummaryDeterminesRealization         SAT counterexample
ExplicitRelationDeterminesSelectedAnswers      UNSAT counterexample
```

The complete expected result set passed in CI.

### 1. Explicit realization can survive non-identical expected and Actual records

A linked Plan/Event pair can keep the same broad Shape while differing in both time and amount.

Observed: **SAT**.

The correspondence therefore does not mean equality of every observed field.

### 2. Identical Plan/Event records do not determine completion

The Plan and Event atoms and all their fields are shared across `Left` and `Right`; only `World.realizes` varies.

Observed: **SAT** witness, and `PlanEventRecordsDetermineCompletion` has a **SAT counterexample**.

So Plan/Event content alone does not determine which Plan is completed.

### 3. Completion membership loses realization provenance

Two worlds can have exactly the same completed Plan set while disagreeing about which Actual Event fulfilled which Plan.

Observed: **SAT** witness, and `CompletionSummaryDeterminesRealization` has a **SAT counterexample**.

A set of completed Plan identities is therefore too coarse when later questions ask which Actual Event supplied the completion evidence.

### 4. Plannedness is not an intrinsic property of the Actual Event record

The same Actual Event can participate in realization in one world and remain unrelated to any Plan in another while all Event content stays fixed.

Observed: **SAT**.

### 5. Exact content matching can still be ambiguous

Alloy found a Plan with two Event candidates that agree on expected/actual time, amount, and Shape. Explicit realization selects one candidate and leaves the other unrelated.

Observed: **SAT**.

Stable identity plus explicit linkage preserves a distinction that exact content matching cannot recover.

### 6. Explicit realization determines the selected answers

When `Left.realizes = Right.realizes`, Alloy found no counterexample in which completion, realized-Event membership, or amount/time/Shape mismatch answers differ.

Observed check result: **UNSAT counterexample**.

## Finding

The bounded separation is:

```text
Plan record
    +
Actual Event record

        does not determine

which Event realizes which Plan
```

The realization correspondence therefore carries its own observable information.

This sharpens the earlier commitment observations without turning Plan into part of the physical Event core:

```text
physical / Actual facts
        !=
expectation facts
        !=
realization linkage between them
```

The relation is not recoverable from matching time, amount, or Shape, even when all three happen to match, because multiple identity-distinct Events may occupy the same observable coordinates.

That does **not** force realization to be a first-class practical fact with its own identity yet. Under the current one-to-one vocabulary it may be stored as a Plan-side field, Event-side field, or separate relation while preserving the same information.

The important semantic boundary is instead:

> Do not infer Plan realization from matching amount, date, account-like shape, or description when future questions need stable completion provenance.

This keeps the neutral Actual Event core free from planning semantics while allowing an application or overlay relation to connect expectation and actuality explicitly.

## Important boundaries

This observation does **not** establish:

- that `Plan` belongs in the Practical Lean Core;
- that every Event can realize at most one Plan in a final system;
- that every Plan can be realized by at most one Event forever;
- partial realization;
- one Plan realized by several Events;
- several Plans realized by one Event;
- supersession, cancellation, or recurrence semantics;
- Series identity;
- schedule generation;
- lifecycle transition order;
- whether realization itself needs stable identity or correction history;
- where a practical persistence format should physically store the relation;
- that expected and actual Shape should be one production type.

The one-to-one restriction is especially important. If real workflows require split or merged realization, a later observation should relax the cardinality rather than silently enlarging Observation 063.

## Next pressure

Explicit realization linkage is now independently observable, but persistence is not automatically earned.

A stronger pressure would be:

> Does one-to-one realization survive real workflows, or do partial/split/merged realizations force realization to become a richer relation with its own identity or lifecycle?

That would be a candidate Observation 064 only if concrete data or application behavior requires it.
