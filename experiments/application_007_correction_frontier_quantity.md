# Application 007: correction frontier quantity

## Question

Before LOAM exposes ordinary daily-use balances, can more than one correction
fact contribute to one current quantity without making correction-list order an
authority?

The current production Application boundary intentionally supports only zero or
one correction. Two or more correction facts return `frontierRequired`.

That refusal was the right first boundary, but the daily-use writer can already
produce harmless shapes such as:

```text
A -> B -> C

X -> Y

U
```

where the first relation is one linear correction chain, the second is an
independent chain, and `U` is untouched.

The question is narrower than implementing the final production frontier:

> If correction facts form a finite, referentially closed, acyclic forest with
> at most one outgoing correction per target Event, can the current quantity be
> obtained from remembered Events without choosing a winner by representation
> order?

## Why Lean

The relevant correction semantics were already observed structurally in earlier
Alloy/TLA+ work:

- a linear correction chain has one terminal interpretation;
- sibling corrections are an unresolved conflict rather than first/last-wins;
- arrival order need not become authority.

This application probe asks for a small executable candidate law before changing
production code. No new temporal hypothesis is being introduced, so Alloy or
TLA+ would mostly repeat earlier observations.

## Probe vocabulary

The probe deliberately compresses one already-selected locus/measure coordinate
to an integer Event contribution:

```text
EventContribution = EventId + quantity
Correction        = target EventId + replacement EventId
```

The frontier is admitted only when:

1. Event identity is unique;
2. every correction endpoint Event is present;
3. each target Event has at most one outgoing correction;
4. the correction relation is acyclic.

If those premises hold, the frontier Events are exactly remembered Events that
are **not correction targets**.

This works because replacement Events are already remembered facts. A
replacement must not be added again during projection.

## Representative specimen

Remembered Event contributions:

```text
a  +100
b   +80
c   +90
x   -20
y   -15
u    +5
```

Corrections:

```text
a -> b -> c
x -> y
```

The current frontier is therefore:

```text
c   +90
y   -15
u    +5
```

and the current quantity is:

```text
80
```

The probe checks all of the following:

- one linear chain, one independent chain, and one untouched Event coexist;
- the resulting effective quantity is `80`;
- reversing correction-list representation leaves the answer unchanged;
- sibling corrections are rejected;
- a correction cycle is rejected;
- a missing replacement endpoint is rejected.

## Interpretation

This is the smallest useful bridge from the current single-correction
Application boundary toward daily-use balances.

The candidate law is:

```text
admitted correction forest
          |
          v
remembered Events minus correction targets
          |
          v
current coordinate quantity
```

No chronology, list position, first-wins, or last-wins rule is required for the
admitted shape.

## Important boundaries

This probe does **not** yet establish:

- the final production representation of a correction frontier;
- conflict resolution for sibling corrections;
- EventResolution integration;
- whether all future correction graphs should be forests;
- a global balance concept across unlike loci or measures;
- accounting roles or double-entry accounting;
- a CLI/TUI presentation;
- persistence changes.

The next practical step, if this probe qualifies, is to connect the same
fail-closed frontier semantics to `Loam.Application.inspectQuantity` and then let
`loam effective` display multiple independent/linear correction chains.
