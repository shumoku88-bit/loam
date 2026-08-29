# Observation 002 — Same Projection, Different History

## Question

Can two distinct identity histories have exactly the same `Time × Purpose` count projection?

Observation 001 showed that persistent identity and stable aggregate quantity are different observations. Observation 002 asks for a stronger witness: two histories that become indistinguishable after Unit identity is forgotten.

## Alloy construction

`model/002_same_projection_distinct_history.als` creates two histories, `Left` and `Right`, over the same:

- three Times;
- two Purposes; and
- four persistent Units.

The requested witness must satisfy all of the following:

1. every Unit has exactly one Purpose at every Time in each history;
2. `Left` and `Right` have identical Unit counts for every `Time × Purpose` cell;
3. the identity histories are not equal;
4. at one Purpose, `Left` has a Unit that remains there through every Time while `Right` has no Unit that remains there through every Time; and
5. both histories contain movement.

The continuity condition matters because it rules out treating the result as only a cosmetic renaming of Unit labels. The two histories disagree on an identity-based property that survives arbitrary relabeling.

## Executed Alloy witness

Alloy 6.2.0 with Sat4j found the model SAT.

The concrete histories were:

### Left

| Time | Unit 0 | Unit 1 | Unit 2 | Unit 3 |
| --- | --- | --- | --- | --- |
| Time 0 | Purpose 0 | Purpose 1 | Purpose 0 | Purpose 1 |
| Time 1 | Purpose 1 | Purpose 1 | Purpose 0 | Purpose 0 |
| Time 2 | Purpose 0 | Purpose 1 | Purpose 0 | Purpose 0 |

`Unit 1` remains at `Purpose 1` through all three Times.

### Right

| Time | Unit 0 | Unit 1 | Unit 2 | Unit 3 |
| --- | --- | --- | --- | --- |
| Time 0 | Purpose 0 | Purpose 0 | Purpose 1 | Purpose 1 |
| Time 1 | Purpose 1 | Purpose 1 | Purpose 0 | Purpose 0 |
| Time 2 | Purpose 1 | Purpose 0 | Purpose 0 | Purpose 0 |

No Unit remains at `Purpose 1` through all three Times.

## J projection

`j/002_observe.ijs` stores those two identity-bearing histories as `Time × Unit` matrices and derives counts rather than entering the count matrix by hand.

Both histories project to exactly the same `Time × Purpose` matrix:

```text
2 2
2 2
3 1
```

The executable J checks also recover the different continuity observations:

```text
persistent at Purpose 1 / Left  = 0 1 0 0
persistent at Purpose 1 / Right = 0 0 0 0
```

So the same count projection corresponds to two histories with different identity continuity.

## Finding

The `Time × Purpose` quantity projection is many-to-one with respect to identity history.

This is stronger than saying that counts simply omit names. Two histories can agree at every observed count cell and still disagree on whether a Purpose contains any member that persisted there through the whole trace.

Therefore an envelope-like state represented only by aggregate quantity cannot, by itself, determine membership continuity or provenance continuity.

This does **not** imply that budgeting software must preserve per-unit identity. It only establishes the information boundary: if a future feature needs continuity or provenance, aggregate counts alone cannot reconstruct it.

## What this changes

Observation 001 exposed two candidate meanings of continuity:

- continuity of identity or membership;
- continuity of aggregate quantity.

Observation 002 now shows that the second cannot recover the first.

That suggests an eventual design should resist using one noun such as `Envelope` as if these observations were interchangeable.

## Next question

The next useful question is temporal rather than merely representational:

> If two states have the same quantity projection, can different hidden histories make different future operations legal, safe, or meaningful?

If the answer depends on operation order or reachable futures, that is the first point where TLA+ may become justified. If the question remains a finite structural one, Alloy should stay in charge.

Lean 4 and miniKanren are still premature: no general theorem needs promotion yet, and no reverse-search problem has been identified yet.
