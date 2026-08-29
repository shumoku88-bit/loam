# Observation 001 — A World Before Envelopes

## Question

If finite resource units are placed through time and purpose without assuming accounts, transactions, budgets, envelopes, months, or reports, does an envelope-like structure appear as something primitive, or only as a projection?

## Deliberate vocabulary

The first model admits only:

- `Time`
- `Purpose`
- persistent `Unit`
- placement of each Unit at one Purpose at each Time

`Unit` identity persists across the whole trace. Quantity is not primitive; it can be observed by counting Units.

## Deliberate absences

The model does not yet contain:

- Account
- Transaction
- Budget
- Envelope
- Month
- Report
- Income
- Expense
- balance arithmetic
- an operation named move or reallocate

A change of placement between adjacent Times is observable, but is not yet granted its own domain noun.

## Alloy lens

`model/001_resource_purpose.als` asks for a small world containing both:

- at least one Unit whose placement changes; and
- at least one Unit whose placement persists.

Because Units persist and every Unit has exactly one Purpose at every Time, conservation is represented structurally rather than by integer arithmetic.

The current `NoUnitDisappearsFromPlacement` assertion repeats a fact already imposed by the model. Its UNSAT check is therefore only an execution sanity check, not independent evidence for a discovered law.

## J lens

`j/001_observe.ijs` begins with a deliberately lossy `Time × Purpose` count matrix.

This forgets Unit identity and keeps only quantity per Purpose. It observes:

- total quantity through time;
- adjacent changes;
- the range of each Purpose's quantity; and
- which Purpose totals remain numerically stable.

This mismatch is part of the experiment, not glue debt to fix immediately. Alloy can retain distinctions that this first J projection cannot express.

## First executed witness

Alloy 6.2.0 with Sat4j produced a SAT witness for `mixedWorld` with three Times, three Purposes, and five persistent Units.

The placement was:

| Unit | Time 0 | Time 1 | Time 2 |
| --- | --- | --- | --- |
| Unit 0 | Purpose 2 | Purpose 0 | Purpose 2 |
| Unit 1 | Purpose 1 | Purpose 2 | Purpose 2 |
| Unit 2 | Purpose 1 | Purpose 2 | Purpose 1 |
| Unit 3 | Purpose 0 | Purpose 0 | Purpose 0 |
| Unit 4 | Purpose 1 | Purpose 1 | Purpose 2 |

`Unit 3` therefore persists at `Purpose 0` through the whole trace.

When the same witness is projected to counts and Unit identity is forgotten, J sees:

```text
1 3 1
2 1 2
1 1 3
```

The total is conserved as `5 5 5`, but no Purpose has a numerically stable count through the whole trace. In particular, `Purpose 0` has counts `1 2 1` even though `Unit 3` remains there throughout.

The J checks for this projection execute successfully.

## First finding

Persistent identity at a Purpose and stable quantity at a Purpose are not the same observation.

The first SAT witness already contains identity continuity without aggregate quantity stability.

A second, synthetic count-only contrast,

```text
2 2 1
2 1 2
2 1 2
```

has a stable count at `Purpose 0`, but the count projection alone cannot tell whether the same Units persisted there.

So an envelope-like notion of "staying the same" has at least two candidate meanings:

1. continuity of membership or identity; and
2. continuity of aggregate quantity.

Calling both simply "stable" would erase information.

This does not yet show that an Envelope is derivable, or that either notion should become an Envelope. It only shows that a future definition must choose which continuity it means, or explicitly relate both.

## Next question exposed by the witness

Can two distinct identity histories have exactly the same `Time × Purpose` count projection?

If Alloy can produce such a pair directly, the lossiness of the J projection becomes a witnessed property of the model rather than merely an argument about what counts fail to record.

That is a stronger next experiment than adding more household vocabulary.

## Not yet

Do not add TLA+, miniKanren, or Lean 4 yet. Observation 001 has exposed a representational question, not yet a temporal-liveness, reverse-search, or general-proof question.

Do not automate Alloy-to-J export yet. The first bridge remains manually inspected on purpose while we learn which information should survive projection.
