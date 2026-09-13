# LOAM contrapuntal exploration

Status: direction checkpoint before the next research observations

Checkpoint main: `9c4989a9772f7da91a34ab9f6da0544c4f38209e`

## Why this document exists

Recent report and presentation work clarified an important distinction.

Improving labels, ordering, help text, or report layout can make LOAM easier to read, but that is not the same thing as making LOAM itself more expressive. The stronger goal is not to imitate the surface character of an admired work. It is to study LOAM's own material deeply enough that unusual and useful answers arise naturally from the structure already present.

The working analogy is musical rather than architectural:

- harmony exercise: ask which independent meanings can coexist and under what conditions;
- counterpoint exercise: ask how several projections of the same retained evidence move together without collapsing into one another;
- composition: expose a household answer only after the underlying relations have earned it.

This is not a proposal to add music vocabulary to production code. The technical criterion is **generative conceptual economy**:

> Prefer a small number of orthogonal retained meanings whose relations generate many useful answers.

A concept earns its place not merely because it is distinct, but because preserving that distinction changes or enables an answer.

## What changed in our view of LOAM

The question is no longer primarily:

> What feature or report should LOAM implement next?

The more useful question is:

> Which answers are already latent in the relations LOAM retains, but are not yet being asked?

Recent production work gives evidence that this direction is real rather than aesthetic preference:

- Balance Sheet, Net Worth, and Trial Balance can be projections of one RoleBalance answer instead of separate accounting engines.
- Income / Expense can be obtained by adding AccountingRole interpretation to an existing transaction-flow view instead of replaying Actual through a second semantic engine.
- Savings / investment routing did not require `SavingsPurpose`, `StockPurpose`, or a new authority; existing Purpose, AccountingRole, and routing relations were sufficient.
- Current quantity observations became another support family for current balances without redefining zero-origin or introducing a second balance engine.

These are examples of new answers emerging from relations among existing meanings.

## Anti-goals

This exploration must not become another reason to grow LOAM indiscriminately.

Do not begin by adding:

- another report domain;
- another persistent summary or cache;
- a generic relation graph;
- a universal event framework;
- a new Core primitive for every interesting observation;
- UI decoration intended to make existing behavior merely look novel;
- a theorem whose only purpose is to formalize an implementation detail already forced by construction.

The exercise is successful even when the result is "the proposed distinction adds no information" or "the interesting law does not survive current evidence boundaries".

## Exploration method

For each candidate sound:

```text
existing retained meanings
  -> identify two or more independently useful projections
  -> state a possible cross-projection law
  -> search for the smallest counterexample
  -> identify the exact conditions under which the law survives
  -> decide whether the surviving law answers a household question
  -> only then choose whether it deserves a Lean theorem, Alloy model,
     read-only projection, production surface, or no production change
```

Use the cheapest adequate instrument:

- direct algebra or existing Lean definitions when the law is already transparent;
- Alloy when alternative structures, missing conditions, or bounded counterexamples are the main question;
- Lean when a stable general law has been found and proof adds continuing value;
- real-data dogfood when the semantic law is sound but its usefulness is uncertain.

Do not create permanent observation infrastructure before the question earns it.

## First contrapuntal exercises

### C1. Scheduled realization counterpoint

This is the strongest first candidate because the constituent voices already exist in production.

Current coverage is composed from:

```text
Capacity -> Entitlement
Actual + validity + correction frontier + historical routing -> Consumption
open Scheduled + terminal relation + Scheduled routing / AccountingRole -> Commitment

Remaining = Entitlement - Consumption
Headroom  = Remaining - Commitment
```

Scheduled completion explicitly relates one Scheduled identity to an Actual Event identity.

Observation 113 previously qualified the bounded algebra:

```text
Headroom_after - Headroom_before
    = Scheduled_expected - Actual_realized
```

so, in the selected model:

```text
expected = actual  -> Headroom unchanged
actual < expected  -> Headroom increases by the difference
actual > expected  -> Headroom decreases by the difference
```

The new question is not to repeat Observation 113. It is to lift the law through the **current production semantics** and determine its exact preconditions.

Questions:

1. Must Scheduled and Actual route to the same Purpose at their independently effective coordinates?
2. What happens when the Scheduled movement is split across Loci?
3. What happens when the completion Actual differs only on a non-pressure Locus?
4. How do EventCorrection and ActualValidity changes affect the realization delta?
5. Does a correction after completion preserve the same law against the effective Actual frontier?
6. Does replacement of the Scheduled occurrence change which expected quantity belongs in the comparison?
7. Which parts of the law are per-Purpose, per-Measure, per-Locus, or global?
8. Can the result be stated without inventing a stored `Variance`, `Settlement`, or `Fulfillment` record?

Desired output, if earned: a derived statement of how expectation becomes actuality and which difference alone changes current capacity headroom.

### C2. Stock-flow / transaction-flow coherence

`StockFlowReview` and `TransactionsFlowReview` are different projections over correction-aware Actual evidence.

Candidate law:

> For the same explicit window, measure, and selected coordinates, the Stock-Flow net change should equal the sum of the corresponding transaction-flow net quantities.

Questions:

- Are the two projections selecting exactly the same effective Event frontier?
- Does either projection aggregate a different coordinate domain?
- What support/balance assumptions are required only by Stock-Flow reconstruction and not by transaction flow?
- Can the equality be split into a pure flow equality plus an independent opening/closing balance law?

The point is not to merge the reports. It is to test whether two independent voices are demonstrably singing the same underlying change.

### C3. Correction propagation

LOAM retains original and replacement Events and projects a correction frontier rather than rewriting history.

Candidate question:

> What changed in every existing household answer because this correction became effective?

Potential projections include:

- physical balance;
- Stock-Flow;
- Transactions Flow;
- Income / Expense;
- Purpose consumption;
- Remaining / Headroom;
- Net Worth.

The exercise is to find which deltas are forced to agree, which may legitimately differ, and which are unaffected. Do not create a generic `CorrectionImpact` object unless a non-derivable meaning appears.

### C4. Evidence / answerability monotonicity

LOAM distinguishes several support and interpretation families: zero-origin, opening support, current quantity anchor, AccountingRole, Actual routing, Scheduled routing, lifecycle evidence, and temporal coordinates.

Candidate question:

> When one independent piece of evidence is added, which previously blocked questions become answerable, and which already justified answers must remain unchanged?

This may reveal a useful information order, but no lattice vocabulary should be admitted merely because it is mathematically attractive. First find concrete household questions whose answerability forms a stable order.

### C5. Physical backing / assigned capacity conservation

`CycleFundingInspection` composes selected physical balances with current coverage and derives:

```text
residualBeforeUnresolved = budgetableBacking - remainingAssigned
```

A correctly routed Actual expense can reduce physical backing and remaining assigned capacity together.

Candidate question:

> Under which exact conditions does ordinary spending preserve the residual, and which events legitimately change it?

Likely counterexamples include transfers between selected/unselected backing coordinates, income, spending routed outside the current Purpose set, corrections, and future Capacity changes.

This is interesting only if the surviving law says something useful about household funding without inventing a new safe-to-spend authority.

## What counts as "LOAM's sound"

A promising result has most of these properties:

1. It arises from existing semantic distinctions rather than a newly invented feature taxonomy.
2. More than one independently useful projection participates.
3. The relation can fail, and LOAM can explain exactly why.
4. The result survives correction, time, routing, and open-world boundaries honestly rather than by assuming them away.
5. No duplicate retained state is required merely to make the answer convenient.
6. The final household answer is surprising or unusually clear even though the underlying rules remain small.

The strongest sign is not novelty of terminology. It is the experience:

> I recorded ordinary evidence, yet the system can now tell me something I did not explicitly store.

## Immediate next step

Begin with **C1: Scheduled realization counterpoint**.

First reconstruct Observation 113 against current production types and identify every condition that the old bounded model abstracted away. Do not modify production behavior yet. The initial artifact should be a counterexample map or a minimal executable/formal probe showing which variants preserve or break the headroom-delta law.

Only after that should we decide whether LOAM has earned a new theorem, review projection, or user-facing answer.
