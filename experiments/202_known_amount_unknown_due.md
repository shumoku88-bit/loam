# Observation 202 — Can exact amount be known before temporal placement?

Status: **F052 completed — COUNTEREXAMPLE / RESEARCH_ONLY**

## Question

F052 asks about a future household obligation whose exact amount is already known while its due date is still undetermined.

Current practical `ScheduledOccurrence` deliberately pairs one exact scheduled coordinate with one exact balanced movement. Observation 196 / F051 already showed the opposite epistemic pressure: an obligation may be known to exist before its exact amount is known.

Observation 202 asks the complementary information question:

> If all currently representable exact Scheduled evidence is held fixed, can two worlds still differ on whether one exact future amount is already known when its temporal placement is not yet determined?

A second probe asks whether equal exact amount knowledge can coexist with different temporal-placement knowledge.

## Current boundary under pressure

Current Scheduled evidence has the shape:

```text
stable Scheduled identity
+ exact scheduled coordinate
+ exact balanced movement / quantity
```

That remains a useful exact expectation. Observation 202 does not require it to become partial or nullable.

The candidate compression under attack was:

```text
all known exact future quantity
    =
quantity already attached to an exact Scheduled coordinate
```

## Relation to F051

Observation 196 established:

```text
known obligation existence
    !=
exact obligation quantity
```

Observation 202 now establishes the next bounded separation:

```text
exact obligation quantity knowledge
    !=
temporal placement knowledge
```

Together these are two adjacent separations around current exact Scheduled evidence:

```text
existence      != exact quantity        (F051)
exact quantity != temporal placement    (F052)
```

This still does not prove unrestricted three-way independence. In particular, Observation 202 does not test every possible state in which time is known before quantity.

## Observation-local vocabulary

The bounded Alloy model uses:

```text
Obligation
Amount
Due
World
```

Each world retains three experiment-local relations:

```text
exactScheduledAmount
exactScheduledDue
amountKnownDueUndetermined
```

`exactScheduledAmount` and `exactScheduledDue` abstract the information relevant from current exact Scheduled evidence. They always occur together for one subject.

`amountKnownDueUndetermined` means more than a missing date field: it explicitly represents the selected epistemic state "exact amount known; temporal placement undetermined". It is not a proposal for nullable `scheduledOn`, `Obligation`, `Bill`, `Claim`, `DueState`, or a new persistence stream.

The amount-undetermined evidence is disjoint from exact Scheduled evidence for the same subject inside one snapshot.

## Executed Alloy result

Alloy 6.2.0 + Sat4j produced exactly the selected matrix:

```text
representativeAmountKnownDueUndetermined        SAT
sameExactScheduledDifferentKnownAmount          SAT
sameKnownAmountDifferentTemporalPlacement       SAT
ExactScheduledDeterminesAllKnownAmount          SAT counterexample
KnownAmountDeterminesTemporalPlacement          SAT counterexample
ExplicitEvidenceDeterminesSelectedViews         UNSAT counterexample
AmountKnownDueUndeterminedHasNoExactDue         UNSAT counterexample
```

Dedicated Observation 202 CI completed SUCCESS on executable head:

```text
9a95f5d0577cebfe27765a9967b9b07319fbdccf
```

workflow run:

```text
34007935624
```

job:

```text
101418465799
```

## What the witnesses show

### Exact Scheduled evidence does not determine all known exact amount

`sameExactScheduledDifferentKnownAmount` is SAT and `ExactScheduledDeterminesAllKnownAmount` has a counterexample.

A concrete witness keeps exact Scheduled evidence empty and identical in both worlds:

```text
Left
  exact Scheduled       none
  exact amount Q        known
  due                    undetermined

Right
  exact Scheduled       none
  exact amount Q        not known
```

So:

```text
same exact Scheduled evidence
    +
different exact future-amount knowledge
```

is possible for the selected vocabulary.

### Exact amount does not determine temporal placement

`sameKnownAmountDifferentTemporalPlacement` is SAT and `KnownAmountDeterminesTemporalPlacement` has a counterexample.

The bounded witness is:

```text
Left
  known amount = Q
  due = undetermined

Right
  known amount = Q
  exact due = D
```

Therefore:

```text
same exact amount knowledge
    -/->
same temporal-placement knowledge
```

The amount can be known before an exact due coordinate is known.

### Explicit additional evidence closes the selected gap

`ExplicitEvidenceDeterminesSelectedViews` has no counterexample in scope.

Once current exact Scheduled evidence plus the experiment-local amount-known/due-undetermined evidence are fixed, the selected amount and temporal-knowledge views are fixed.

This is bounded sufficiency only. It does not establish that `amountKnownDueUndetermined` is the right production representation.

## Existing concepts deliberately not reused

### Attention

`AttentionDue.dueUndetermined` already preserves the useful distinction between "no due date" and "due not yet determined" for Attention. But Attention is a separate semantic family and carries no financial quantity. Reusing it as exact financial-obligation evidence would invent a correspondence not currently earned.

### OpenRelation

Current `RelationUnit` carries exact quantity, but it is anchored to an existing source Event/Effect. It does not by itself represent a future exact amount whose occurrence or temporal placement has not yet been established.

## Rebuild-pressure result

Observation 202 finds a real missing information distinction, but it does **not** find Core-shape failure.

Current classification:

```text
B  CONSERVATIVE EXTENSION PRESSURE
```

Why not C?

The existing exact `ScheduledOccurrence` meaning remains coherent:

```text
exact scheduled coordinate
+ exact balanced movement
```

The new witness only says that some legitimate knowledge can exist **before** that exact shape is available. Application 006 already permits a new independently typed fact family to live beside existing families while old projections remain unchanged unless they opt in.

So the current evidence supports:

```text
keep exact Scheduled exact

and test whether
F051 existence-only pressure
+ F052 amount-before-time pressure

can compress into one smaller pre-Scheduled identity / attachment boundary
```

before considering any change to `ScheduledOccurrence` itself.

That compression boundary is now worth testing. It is not yet a production concept.

## Finding

F052 closes as:

```text
Work     DONE
Finding  COUNTEREXAMPLE
Runtime  RESEARCH_ONLY
```

Qualified bounded separation:

```text
exact Scheduled evidence
    -/->
all known exact future amount

exact amount knowledge
    !=
temporal placement knowledge
```

## Deliberate boundaries

Observation 202 does not establish:

- a production `Obligation`, `Claim`, `Bill`, `Expectation`, or pre-Scheduled type;
- `Option Quantity` or `Option Time` inside `ScheduledOccurrence`;
- a generic partial-record framework;
- approximate/range quantity semantics (F049/F050);
- `noDueDate` financial meaning;
- transitions from unknown to known time;
- time-known / amount-unknown symmetry beyond the already qualified F051 question;
- recurrence generation;
- how partial knowledge contributes to Commitment, Remaining, Headroom, Capacity, or forecasts;
- persistence, CLI/TUI, notifications, or canonical household-data changes.

Production remains gated on real dogfood pressure.
