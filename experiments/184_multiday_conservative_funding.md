# Observation 184 — multi-day conservative funding from date boundaries

Status: Lean observation stacked on Observation 183.

## Pressure

Observation 183 established the exact conservative additional opening quantity for one fixed date when same-day inflow/outflow order is unknown:

```text
max(0, same-day outflow - opening)
```

That result intentionally stopped before multi-day composition.

The next practical question is:

```text
if several ScheduledDate buckets are known in date order,
how much one-time additional opening quantity is required before the whole
period starts so the selected balance coordinate cannot go negative?
```

The key distinction is that ordering is unknown **within** one date, but ordering **between** dates is already known from the date coordinate itself.

## Candidate recurrence

Let `day.net = inflow - outflow` and let `sameDayRequirement` be Observation 183's exact one-day requirement.

For one initial additional quantity that remains present throughout the horizon:

```text
R(opening, []) = max(0, -opening)

R(opening, day :: rest)
  = max(
      sameDayRequirement(opening, day),
      R(opening + day.net, rest)
    )
```

The completed signed net from an earlier date becomes part of the opening quantity for every later date.

No same-date inflow receives that privilege because there is still no evidence that it arrives before same-date outflow.

## Lean result

`Loam/Observations/Observation184.lean` defines period safety recursively over date-ordered buckets while retaining Observation 183's quantified unknown-order semantics inside each day.

For a well-formed period Lean proves:

```text
SafeForUnknownOrderPeriod opening additional days
iff
requiredPeriodAdditionalOpening opening days <= additional
```

So the recurrence gives both a sufficient and minimal one-time initial addition.

## Date-boundary witness

Compare these two presentations with opening zero:

```text
same date:
  inflow 10 / outflow 10

across dates:
  earlier date: inflow 10 / outflow 0
  later date:   inflow 0  / outflow 10
```

Both contain total inflow 10 and total outflow 10. Both have final net zero.

But the conservative requirements are:

```text
same date   -> 10
across dates -> 0
```

The earlier-date inflow is complete before the later-date outflow can occur, so it becomes usable opening quantity for the later bucket. The same-date inflow cannot be assumed to precede the same-date outflow.

Therefore:

```text
ScheduledDate boundary
-> usable order evidence for conservative funding
```

without introducing hour/minute timestamps or a hidden within-day event sequence.

## Earned boundary

Observation 184 supports only:

```text
one selected balance coordinate
+ one initial additional quantity
+ date-ordered directional Scheduled subtotals
+ unknown order inside each date
-> exact conservative whole-period requirement
```

It does **not** earn:

- a production funding command;
- a canonical TopUp/Funding event kind;
- later automatic top-ups;
- time-of-day;
- a hidden intra-day sequence;
- Backing topology;
- safe-to-spend authority;
- a claim that Scheduled will equal later Actual.

A practical projection, if later earned, would need directional same-day subtotals before net collapse plus the already-existing ScheduledDate ordering.
