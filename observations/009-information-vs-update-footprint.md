# Observation 009 — Information versus update footprint

## Question

If two retained-state representations preserve the same history distinctions, must they expose the same coordinate-change footprint when state changes?

This observation deliberately uses only Alloy and J. The new default-core policy says to use the smallest useful subset and to introduce another tool only when it answers a distinct question that the current tools cannot.

## Encodings

The finite universe contains four Boolean states:

```text
00
10
01
11
```

The direct encoding stores:

```text
(u0, u1)
```

The alternative encoding stores:

```text
(u0, count(u0,u1))
```

which yields:

```text
00 -> (0,0)
10 -> (1,1)
01 -> (0,1)
11 -> (1,2)
```

Both encodings distinguish all four states and therefore induce the same collision classes in this universe.

## Alloy result

Alloy 6.2.0 + Sat4j executed two commands.

The assertion that the two encodings preserve the same information returned:

```text
check AlternativePreservesInformation  UNSAT
```

so Alloy found no counterexample in the exact four-state model.

The update-footprint predicate returned:

```text
run footprintWitness  SAT
```

with the witness pair:

```text
S00 -> S10
```

For that change, the direct representation changes only `u0`, while the alternative representation changes both `u0` and `count`.

## J result

J exhaustively measured Hamming coordinate changes for all 12 directed transitions between distinct states.

```text
profile:
  direct one-coordinate changes:       8
  direct two-coordinate changes:       4
  alternative one-coordinate changes:  6
  alternative two-coordinate changes:  6
  direct total changed coordinates:    16
  alternative total changed coordinates: 18
```

The `00 -> 10` witness is therefore not an isolated parsing artifact. Across this deliberately uniform enumeration of all directed state changes, the two information-equivalent coordinate systems expose different change-footprint shapes.

## Finding

**Informational equivalence does not imply equal update footprint.**

A retained-state representation can preserve exactly the distinctions needed by the chosen future vocabulary while arranging those distinctions into coordinates that react differently to change.

Observation 008 showed that sufficiency belongs to a decoding relationship rather than one privileged representation. Observation 009 adds a second axis: different sufficient coordinate systems can also distribute change differently across their stored coordinates.

So choosing a state representation may involve at least two independent questions:

1. what distinctions does it preserve?;
2. how do those coordinates move when the underlying state changes?

## Why Lean 4 is not added here

No further general theorem is needed to answer this observation's question. A concrete information-equivalent pair with unequal update footprint is already a counterexample to the claim that informational equivalence forces operationally identical coordinate changes.

Lean remains part of the default core, but the core is a toolbox rather than a mandatory three-language pipeline.

## Why TLA+ and miniKanren are not added

The question does not require temporal-path semantics or backwards relational synthesis. A finite structural witness plus exhaustive array observation is enough.

## Boundary

`changed coordinate count` is not runtime cost, write amplification, storage cost, energy use, or implementation complexity.

The J totals weight all 12 directed transitions equally. A real system may have a very different transition distribution, and different coordinates may have different implementation costs.

This observation establishes only that information-equivalent representations need not have the same coordinate-change geometry.
