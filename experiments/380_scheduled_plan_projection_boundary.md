# Observation 380: Scheduled Plan projection boundary

Status: **ACTIVE BOUNDED ALLOY OBSERVATION — NOT PRODUCTION AUTHORITY**

## Question

Recent household use exposed a recurring Scheduled-management ambiguity:

- an explicit current-open occurrence is retained household evidence;
- a monitoring rule such as “every two months” is a replaceable read-side rule;
- an expected month is derived from that rule;
- a missing month is an expected month with no current-open occurrence;
- an outside-pace occurrence is still explicit Scheduled evidence;
- completion, cancellation, retirement, or replacement can remove retained
  occurrences from the current-open projection without deleting their history.

The practical TUI now exposes these distinctions through Series Calendar,
replenishment, and Plan Detail. This observation asks whether those distinctions
need more canonical state, or whether the current projection boundary is enough.

The bounded structural question is:

> Can `on pace`, `outside pace`, `missing`, actionability, and the ordinary
> replenishment source be derived from retained lifecycle evidence plus a
> monitoring projection without storing those labels as new household facts?

## Why Alloy

The uncertainty here is structural, not arithmetic or interleaving-heavy.

The useful counterexamples are small:

- the same lifecycle evidence under two monitoring rules can produce different
  `missing` / `outside pace` labels;
- the same retained occurrences with different terminal evidence can produce a
  different current-open gap;
- a later explicit occurrence can exist after the first monitored gap, so
  “latest explicit occurrence” and “replenishment source before first gap” are
  not equivalent.

Alloy is therefore the smallest live instrument. TLA+ would be appropriate later
if the open question becomes operation ordering across repeated
replenish/cancel/replace histories. Lean would be appropriate only for a general
production law worth retaining after this bounded boundary is understood.

## Model

`experiments/380_scheduled_plan_projection_boundary.als` keeps only:

```text
retained Scheduled occurrence
terminal lifecycle evidence
current-open projection
monitoring expected months
derived on-pace / outside-pace / missing labels
first-gap replenishment source
```

The model deliberately assumes that the selected Plan Detail row has already
filtered one signed-Locus shape. It does **not** model amounts, exact day-of-month
generation, routing, or recurrence identity.

The monitoring relation is represented directly as a set of expected months.
This observation therefore tests the projection boundary once cadence expansion
has supplied those months; it does not re-prove the production cadence
arithmetic.

## Intended witnesses

The model asks Alloy for small worlds where:

1. identical lifecycle evidence under different monitoring rules changes only
   projection labels;
2. identical retained occurrences with different terminal evidence changes a
   gap;
3. an outside-pace explicit occurrence remains an action target;
4. a terminal occurrence in an expected month can leave that month missing from
   the current-open projection;
5. the latest explicit month lies after the first gap while the proper
   replenishment source is an earlier on-pace month;
6. replenishment adds a fresh occurrence at the first gap;
7. a monitoring-only change can relabel the view without rewriting lifecycle
   evidence.

## Intended laws

The bounded checks ask for counterexamples to these laws:

- equal current-open evidence plus equal monitoring determines the same Plan
  Detail projection;
- a missing month cannot itself be an explicit completion/cancel/replace target;
- terminal evidence is not a current-open action target;
- a replenishment source is an expected open month before the first gap;
- replenishment preserves all prior retained and terminal lifecycle evidence;
- replenishment fills the first gap rather than deleting or rewriting later
  explicit evidence;
- changing only monitoring preserves retained, terminal, and current-open
  lifecycle evidence.

For the checks, **UNSAT is the expected qualified result**. For the witness runs,
**SAT is expected**.

## Production interpretation if qualified

A successful bounded result would support the current practical split:

```text
canonical / retained
  Scheduled occurrence
  Scheduled terminal lifecycle evidence

replaceable projection input
  monitoring rule

derived presentation
  on pace
  outside pace
  missing

ordinary action boundary
  completion / cancel / replace -> explicit current-open occurrence only
  replenish                    -> first missing expected month
```

In particular, it would *not* justify storing `Gap`, `ExpectedSlot`, or
`OutsidePace` as new canonical household facts.

It would also support the current Plan Detail behavior of showing an
outside-pace occurrence without declaring it wrong or removing it
automatically.

## Limits

This is a bounded structural observation. It does not prove arbitrary-length
calendar behavior or all operation sequences.

It also does not decide whether the human interface is pleasant. The move from a
global Months screen to focused Plan Detail came from real use, not from Alloy.

If repeated operation ordering remains troublesome after this structural split,
the next distinct tool would be a small TLA+ model over
`replenish / cancel / replace / change monitoring`. Until that question is
concrete, no additional formal apparatus is earned.
