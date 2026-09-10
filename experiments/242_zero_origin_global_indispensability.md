# Observation 242 — ZeroOriginCoverage global indispensability

## Question

When the current canonical basis is reconsidered as a whole, does
`ZeroOriginCoverage` still carry an independently observable distinction, or is
it only residue from an earlier representation?

## Witness shape

Keep every other selected input identical:

```text
EventMemory       = empty
EventCorrection   = empty
queried coordinate = cash / jpy
```

Vary only zero-origin evidence:

```text
world A: cash/jpy explicitly covered from zero
world B: cash/jpy not covered
```

The production `inspectZeroOriginQuantity` operation distinguishes the worlds:

```text
world A -> current 0
world B -> coverageMissing
```

The important distinction is epistemic, not arithmetic. Both worlds contain the
same Event activity and therefore the same recorded quantity `0`; only world A
has authority to interpret that recorded aggregate as a current quantity from a
known zero origin.

## Result

`ZeroOriginCoverage` has a direct Q-indispensability witness for the current
operation vocabulary.

Classification for the semantic basis:

```text
ZeroOriginCoverage: WITNESS / KEEP MEANING
```

This does not imply:

- one file per covered coordinate;
- one dedicated file for the coverage family;
- a generic Coverage ontology;
- that physical absence may mean empty coverage;
- that the current wire shape is minimal.

The witness protects the distinction only. Physical authority topology remains a
later #693 question.

## Lean owner

`Loam/Observations/Observation242.lean` constructs the two production-typed worlds
and proves that the current operation results differ.
