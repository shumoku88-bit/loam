# Generation 3 — Scheduled current-open read-order fanout

Status: **SHARED READ-ORDER EXPERIMENT**

## Question

When several frontends consume the same current-open Scheduled frontier, do they
observe one deterministic order or reconstruct ordering independently?

## Discovery

The current code had three observable ordering implementations:

```text
HraScheduled      date -> Scheduled id
Web Snapshot      date -> Scheduled id
OpenScheduled CLI date only
```

At the same time, `ScheduledReview.earliestCurrentOpenRecord` already used:

```text
retained scheduledOn
then ScheduledId.token
```

and `currentOpenBeforeDate` repeated the same ordering.

This means two surfaces could display same-date current-open Scheduled occurrences
in a different order even though they consumed the same shared frontier.

## Why this matters

Ordering is not Scheduled authority and does not imply priority. However, it is
observable:

- HraScheduled navigation has a first/next row;
- Web shows a bounded first page;
- CLI emits a sequential document;
- Home asks for the earliest current-open occurrence.

A same-date tie therefore needs one deterministic read-side convention if these
surfaces are to expose the same answer.

## Experiment

Add:

```text
ScheduledReview.orderedCurrentOpenRecords
```

with one rule:

```text
scheduledOn ascending
ScheduledId.token ascending as same-date tie-breaker
```

Then route:

- `earliestCurrentOpenRecord`;
- `currentOpenBeforeDate`;
- same-date/later similarity helpers;
- HraScheduled all-current browsing;
- Web Scheduled loading;
- OpenScheduled CLI

through the shared ordered frontier.

The Web renderer stops sorting on its own, and the CLI's separate date-only
insertion sort is removed.

A regression intentionally retains two same-date rows in reverse identity order
and checks both the full ordered frontier and `earliestCurrentOpenRecord`.

## Boundary

The shared order means only deterministic observation order.

It does **not** mean:

- priority;
- due precedence beyond the retained date coordinate;
- recurrence;
- series identity;
- publication order;
- canonical storage order.

## Tool choice

The divergence was found by cross-surface dependency/code search.

No Alloy/TLA+/SPIN model is required because no new temporal or domain law is
introduced. D2 records ownership; Lean builds and existing TUI/Web/CLI tests
qualify behavior.

## Decision rule

Keep the shared order only if all current Scheduled consumers remain green and
the same-date regression passes. If a future surface genuinely needs a different
presentation sort, it may reorder explicitly after consuming the shared read
answer, but must not redefine "earliest current-open" independently.
