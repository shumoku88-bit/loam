# Observation 004 — Minimal Sufficient History

## Question

How little temporal information can survive while preserving every future distinction visible to a chosen operation vocabulary?

The vocabulary is deliberately narrow. It can ask only about one persistent Unit, `U0`:

1. is `U0` currently at `Target`?
2. has `U0` remained continuously at `Target` since observation began?

No claim is made that this is the right vocabulary for household budgeting. The experiment asks what follows once such a vocabulary has been chosen.

## Candidate summaries

The preceding observations already give a lower boundary:

- current placement alone is insufficient for a continuity-sensitive future operation;
- retaining all history would be sufficient but needlessly large.

Observation 004 compares two intermediate summaries:

1. `#Stayed`: how many Units have stayed continuously at `Target`;
2. `U0Stayed`: one Boolean saying whether `U0` has stayed continuously at `Target`.

## Alloy result — stayed count is insufficient

Alloy 6.2.0 / Sat4j found `countSummaryCollision` SAT with exactly 3 Times, 2 Purposes, and 2 persistent Units.

The concrete witness was:

```text
          Time 0   Time 1   Time 2
Left U0   Other    Target   Target
Left U1   Target   Target   Target

Right U0  Target   Target   Target
Right U1  Target   Other    Target
```

At the final Time, both histories have exactly the same complete placement:

```text
U0 -> Target
U1 -> Target
```

The full continuity sets are different:

```text
Left Stayed  = {U1}
Right Stayed = {U0}
```

but their cardinalities are identical:

```text
#Left Stayed  = 1
#Right Stayed = 1
```

Both histories also contain movement.

So a stayed-count summary cannot preserve the selected vocabulary. It forgets *which* Unit owns the continuity that a future operation may ask about.

The failure is therefore not merely "too little information" in the abstract. The summary is compressed along the wrong observational axis.

## TLA+ result — one targeted bit is sufficient for this vocabulary

The TLA+ model keeps two summaries in parallel:

- `stayed`, the full set of Units that have remained at `Target` continuously;
- `u0Stayed`, one Boolean.

Initial placement ranges over every `Units -> Purposes` function. Every step may choose any new complete placement. Both summaries are then updated incrementally.

TLC checks two invariants:

```text
u0Stayed = ("u0" \in stayed)
```

and that the actual TLA+ `ENABLED` status of the continuity-sensitive operation is identical when read from either representation.

TLC 2.19 generated 40 states, found 9 distinct reachable states, exhausted the state queue, and reported no error.

## Finding

For this fixed operation vocabulary:

```text
current placement only       insufficient
current + #Stayed            insufficient
current + U0Stayed (1 bit)   sufficient in the explored temporal model
full history                 unnecessary
```

Observation 003 established that zero retained history bits are insufficient once the future asks about `U0` continuity. Observation 004 shows that one targeted Boolean is sufficient for exactly that history-sensitive distinction. In that narrow sense, one retained bit is minimal for this vocabulary.

This is not a generally minimal state representation. Change the future vocabulary and the sufficient summary may change with it.

## Stronger interpretation

A useful state summary may not be the smallest generic compression of the past.

It may instead be the smallest information that preserves the distinctions the future is allowed to observe.

That suggests a different design question:

> Do we choose state first and then ask what operations it supports, or choose an operation vocabulary first and derive the state sufficient for it?

## Next question

Can the sufficient summary be *derived from an operation vocabulary* rather than proposed by hand?

That is a possible point where relational search may become useful. Before introducing another language, however, the next experiment should test whether the same idea survives a vocabulary with more than one independent history-sensitive question.
