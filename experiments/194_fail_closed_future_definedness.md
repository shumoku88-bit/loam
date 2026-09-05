# Observation 194 — Fail-closed future definedness

## Question

Observation 193 established that two worlds with the same current
`CorrectionFrontier` quantity can become quantitatively distinguishable after the
same future `EventCorrection`.

Observation 194 asks a stricter question:

> Can the same future Correction make one currently equivalent world semantically
> unavailable while the other remains admissible?

## Witness

Both worlds retain exactly the same Event evidence:

```text
a  -10
b  +10
c  -10
d  +10
```

Their current Correction topology differs:

```text
left:  a -> b
right: c -> d
```

Both current correction-frontier wallet quantities are `10`.

Apply the same future relation to both:

```text
b -> a
```

The resulting shapes are:

```text
left:  a -> b -> a      cycle
right: c -> d   b -> a  disjoint finite paths
```

Existing `CorrectionFrontier` therefore yields:

```text
left  -> none
right -> some 0
```

## Finding

Current observational equivalence does not preserve future semantic definedness.
A future-context quotient must retain enough information to preserve whether a
selected semantic question remains admissible, not only what numeric answer it
returns when admissible.

The distinguishing information here is relation topology, not physical quantity:
`EventMemory` is identical in both worlds and remains unchanged by the future
Correction operation.

This is a fail-closed result. The cyclic relation does not acquire an arbitrary
winner, list-order interpretation, or stale fallback answer.

## Boundary

This observation is deliberately Correction-specific. It does not generalize the
transition vocabulary to `EventResolution`, ActualValidity correction, routing,
time, writer failure, or manifest authority. It changes no production code,
persistence format, CLI/TUI behavior, household data, or publication semantics,
and it claims no new mathematical theorem.
