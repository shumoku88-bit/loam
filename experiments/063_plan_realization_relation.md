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

## Pressures

### 1. Can explicit realization survive non-identical expected and Actual records?

Require a linked Plan/Event pair with the same broad Shape but different time and amount.

Expected: **SAT**.

The correspondence therefore need not mean equality of every observed field.

### 2. Can identical Plan/Event records yield different completion answers when only realization linkage changes?

The Plan and Event atoms and all their fields are shared across `Left` and `Right`; only `World.realizes` varies.

Expected: **SAT**.

If so, Plan/Event content alone does not determine completion.

### 3. Can two worlds have exactly the same completed Plan set but disagree about which Actual Event fulfilled which Plan?

Expected: **SAT**.

This asks whether a completion summary loses provenance even when it preserves completion membership.

### 4. Can the same Actual Event be planned in one world and unplanned in another while all Event content remains identical?

Expected: **SAT**.

This tests whether plannedness is a property inferable from the Actual Event itself.

### 5. Can exact content matching still be ambiguous?

Allow one Plan to have two Event candidates with identical time, amount, and Shape, while explicit realization selects only one.

Expected: **SAT**.

Stable identity plus explicit linkage should preserve a distinction that content matching cannot recover.

### 6. Do Plan and Event records determine completion without realization linkage?

Expected check result: **SAT counterexample**.

### 7. Does the completed-Plan set determine realization provenance?

Expected check result: **SAT counterexample**.

### 8. Once explicit realization is fixed, are the selected answers fixed?

Expected check result: **UNSAT counterexample**.

## Interpretation if the expected results hold

The intended bounded conclusion is:

```text
Plan record
    +
Actual Event record

        does not determine

which Event realizes which Plan
```

The realization correspondence therefore carries its own observable information.

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

If explicit realization linkage is independently observable, the next natural question is not automatically persistence.

A stronger pressure would be:

> Does one-to-one realization survive real workflows, or do partial/split/merged realizations force realization to become a richer relation with its own identity or lifecycle?

That would be a candidate Observation 064 if concrete data or application behavior requires it.
